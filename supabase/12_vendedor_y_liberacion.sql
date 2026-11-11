-- =====================================================================
-- ReUso Seguro · HU04 Confirmación de fondos + HU06 (la transferencia falla)
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas. Requiere los scripts 04 al 11.
--
-- HU04: el vendedor sabe cuándo le compraron (ventas nuevas sin ver),
--       recibe instrucciones para llevar el equipo al Hub y avisa con
--       «Ya entregué el equipo». Solo el vendedor del pedido puede hacerlo.
-- HU06: la transferencia al vendedor puede fallar (SIMULADO). Para cobrar,
--       el vendedor registra su cuenta (Pago Móvil). Si no tiene cuenta o
--       su banco rechaza la transferencia, el pedido queda en «Liberación
--       pendiente» y el dinero SIGUE EN CUSTODIA. Cuando el vendedor
--       registra o corrige su cuenta, el sistema reintenta solo.
--       Dato de prueba: una cuenta con teléfono terminado en 0000 hace que
--       el banco rechace la transferencia.
-- =====================================================================

-- 1. Nuevos datos del pedido
alter table public.pedidos add column if not exists vendedor_vio_en           timestamptz;
alter table public.pedidos add column if not exists entregado_en              timestamptz;
alter table public.pedidos add column if not exists liberacion_motivo         text;
alter table public.pedidos add column if not exists liberacion_intentos       int not null default 0;
alter table public.pedidos add column if not exists liberacion_ultimo_intento timestamptz;

-- Las ventas que ya existían se dan por vistas (no son «nuevas»).
update public.pedidos set vendedor_vio_en = coalesce(pagado_en, now())
  where vendedor_vio_en is null and estado not in ('pendiente_de_pago', 'cancelado');

-- 2. Nuevo estado del pedido: «liberacion_pendiente»
do $$
declare
  v_regla text;
begin
  for v_regla in
    select conname from pg_constraint
    where conrelid = 'public.pedidos'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%pendiente_de_pago%'
  loop
    execute format('alter table public.pedidos drop constraint %I', v_regla);
  end loop;
end;
$$;
alter table public.pedidos add constraint pedidos_estado_check
  check (estado in ('pendiente_de_pago', 'pago_en_custodia', 'recibido_en_hub',
                    'en_diagnostico', 'aprobado', 'liberacion_pendiente',
                    'pago_liberado', 'en_camino', 'rechazado', 'reembolsado',
                    'cancelado'));

-- 3. HU06: cuenta del vendedor para cobrar (Pago Móvil, SIMULADO)
create table if not exists public.cuentas_cobro (
  vendedor_id    uuid primary key references auth.users (id) on delete cascade,
  banco          text not null,
  telefono       text not null,
  cedula         text not null,
  titular        text not null,
  actualizado_en timestamptz not null default now()
);
alter table public.cuentas_cobro enable row level security;

drop policy if exists "Cada vendedor ve su cuenta de cobro" on public.cuentas_cobro;
create policy "Cada vendedor ve su cuenta de cobro"
  on public.cuentas_cobro for select to authenticated
  using (vendedor_id = auth.uid());
-- Sin insert/update/delete: solo la función guardar_cuenta_cobro escribe.

-- 4. El «banco» del vendedor (SIMULADO): null si la transferencia sale bien,
--    o el motivo si falla.
create or replace function public.transferencia_simulada(p_vendedor uuid)
returns text
language plpgsql stable security definer set search_path = public
as $$
declare
  v_cuenta public.cuentas_cobro;
begin
  select * into v_cuenta from public.cuentas_cobro where vendedor_id = p_vendedor;
  if not found then return 'SIN_CUENTA'; end if;
  -- Dato de prueba: el banco rechaza las cuentas con teléfono terminado en 0000.
  if v_cuenta.telefono like '%0000' then return 'CUENTA_RECHAZADA'; end if;
  return null;
end;
$$;
revoke all on function public.transferencia_simulada(uuid) from public, anon, authenticated;

-- 5. HU06: la liberación ahora puede quedar pendiente.
--    La sigue llamando el disparador del dictamen (07_liberacion_pago.sql).
create or replace function public.liberar_pago(p_pedido uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido   public.pedidos;
  v_vendedor uuid;
  v_motivo   text;
begin
  select * into v_pedido from public.pedidos
    where id = p_pedido and estado in ('aprobado', 'liberacion_pendiente')
    for update;
  if not found then return; end if;

  select vendedor_id into v_vendedor from public.equipos where id = v_pedido.equipo_id;
  v_motivo := public.transferencia_simulada(v_vendedor);

  if v_motivo is not null then
    -- La transferencia falló: el dinero se queda en custodia.
    update public.pedidos
      set estado                    = 'liberacion_pendiente',
          liberacion_motivo         = v_motivo,
          liberacion_intentos       = liberacion_intentos + 1,
          liberacion_ultimo_intento = now()
      where id = p_pedido;
    return;
  end if;

  update public.pedidos
    set estado                    = 'pago_liberado',
        comision                  = round(monto * 0.08, 2),
        monto_vendedor            = monto - round(monto * 0.08, 2),
        liberado_en               = now(),
        liberacion_motivo         = null,
        liberacion_intentos       = liberacion_intentos + 1,
        liberacion_ultimo_intento = now()
    where id = p_pedido;
end;
$$;
revoke all on function public.liberar_pago(uuid) from public, anon, authenticated;

-- Reintenta todas las liberaciones pendientes de un vendedor.
create or replace function public.reintentar_liberaciones_de(p_vendedor uuid)
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido uuid;
  v_liberados int := 0;
begin
  for v_pedido in
    select p.id from public.pedidos p
    join public.equipos e on e.id = p.equipo_id
    where e.vendedor_id = p_vendedor and p.estado = 'liberacion_pendiente'
  loop
    perform public.liberar_pago(v_pedido);
    if exists (select 1 from public.pedidos where id = v_pedido and estado = 'pago_liberado') then
      v_liberados := v_liberados + 1;
    end if;
  end loop;
  return v_liberados;
end;
$$;
revoke all on function public.reintentar_liberaciones_de(uuid) from public, anon, authenticated;

-- 6. HU06: el vendedor registra o corrige su cuenta. Se reintenta solo.
create or replace function public.guardar_cuenta_cobro(
  p_banco    text,
  p_telefono text,
  p_cedula   text,
  p_titular  text
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_usuario  uuid := auth.uid();
  v_telefono text := regexp_replace(coalesce(p_telefono, ''), '\D', '', 'g');
  v_cedula   text := upper(regexp_replace(coalesce(p_cedula, ''), '[\s.\-]', '', 'g'));
  v_titular  text := trim(coalesce(p_titular, ''));
  v_cuenta   public.cuentas_cobro;
begin
  if v_usuario is null then raise exception 'SIN_SESION'; end if;
  if trim(coalesce(p_banco, '')) = '' then raise exception 'FALTA_BANCO'; end if;
  if v_telefono !~ '^04(12|14|16|24|26)[0-9]{7}$' then raise exception 'TELEFONO'; end if;
  if v_cedula !~ '^[VE][0-9]{6,9}$' then raise exception 'CEDULA'; end if;
  if char_length(v_titular) < 5 then raise exception 'TITULAR'; end if;

  insert into public.cuentas_cobro (vendedor_id, banco, telefono, cedula, titular)
    values (v_usuario, trim(p_banco), v_telefono, v_cedula, v_titular)
  on conflict (vendedor_id) do update
    set banco = excluded.banco, telefono = excluded.telefono,
        cedula = excluded.cedula, titular = excluded.titular,
        actualizado_en = now()
  returning * into v_cuenta;

  return jsonb_build_object(
    'cuenta', to_jsonb(v_cuenta),
    'liberados', public.reintentar_liberaciones_de(v_usuario));
end;
$$;
revoke all on function public.guardar_cuenta_cobro(text, text, text, text) from public, anon;
grant execute on function public.guardar_cuenta_cobro(text, text, text, text) to authenticated;

-- 7. HU06: el vendedor pide reintentar el cobro de una venta.
create or replace function public.reintentar_liberacion(p_pedido uuid)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido public.pedidos;
begin
  if auth.uid() is null then raise exception 'SIN_SESION'; end if;
  select p.* into v_pedido from public.pedidos p
    join public.equipos e on e.id = p.equipo_id
    where p.id = p_pedido and e.vendedor_id = auth.uid();
  if not found then raise exception 'NO_VENDEDOR'; end if;
  if v_pedido.estado <> 'liberacion_pendiente' then raise exception 'ESTADO'; end if;

  perform public.liberar_pago(p_pedido);
  select * into v_pedido from public.pedidos where id = p_pedido;
  return v_pedido;
end;
$$;
revoke all on function public.reintentar_liberacion(uuid) from public, anon;
grant execute on function public.reintentar_liberacion(uuid) to authenticated;

-- 8. HU04: «Ya entregué el equipo». Solo el vendedor de ese pedido, y solo
--    cuando el pago ya está en custodia.
create or replace function public.marcar_entregado(p_pedido uuid)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido public.pedidos;
begin
  if auth.uid() is null then raise exception 'SIN_SESION'; end if;
  select p.* into v_pedido from public.pedidos p
    join public.equipos e on e.id = p.equipo_id
    where p.id = p_pedido and e.vendedor_id = auth.uid()
    for update of p;
  if not found then raise exception 'NO_VENDEDOR'; end if;
  -- Sin pago no hay envío (HU04, escenario 4).
  if v_pedido.estado <> 'pago_en_custodia' then raise exception 'ESTADO'; end if;

  update public.pedidos set entregado_en = coalesce(entregado_en, now())
    where id = p_pedido
    returning * into v_pedido;
  return v_pedido;
end;
$$;
revoke all on function public.marcar_entregado(uuid) from public, anon;
grant execute on function public.marcar_entregado(uuid) to authenticated;

-- 9. HU04: el vendedor abrió «Mis ventas»: sus ventas dejan de ser nuevas.
create or replace function public.marcar_ventas_vistas()
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_cuantas int;
begin
  if auth.uid() is null then raise exception 'SIN_SESION'; end if;
  update public.pedidos p set vendedor_vio_en = now()
    from public.equipos e
    where e.id = p.equipo_id and e.vendedor_id = auth.uid()
      and p.vendedor_vio_en is null
      and p.estado not in ('pendiente_de_pago', 'cancelado');
  get diagnostics v_cuantas = row_count;
  return v_cuantas;
end;
$$;
revoke all on function public.marcar_ventas_vistas() from public, anon;
grant execute on function public.marcar_ventas_vistas() to authenticated;
