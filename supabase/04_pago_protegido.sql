-- =====================================================================
-- ReUso Seguro · HU12 + HU01 Pedidos y pago protegido (SIMULADO)
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas.
--
-- Regla de la arquitectura: el estado del pago y la reserva del equipo
-- NUNCA los cambia el navegador. Por eso los pedidos no tienen permisos de
-- escritura: solo se crean, pagan o cancelan con las funciones de abajo,
-- que corren en el servidor y revisan cada regla.
-- En el MVP no se mueve dinero real ni se usa una pasarela de pago.
-- =====================================================================

-- 1. Tabla de pedidos («entity» Pedido)
create sequence if not exists public.pedidos_numero_seq start 1001;

create table if not exists public.pedidos (
  id            uuid primary key default gen_random_uuid(),
  numero        bigint not null unique default nextval('public.pedidos_numero_seq'),
  equipo_id     uuid not null references public.equipos (id) on delete restrict,
  comprador_id  uuid not null references auth.users (id) on delete cascade,
  -- El monto lo copia el servidor desde el precio publicado.
  monto         numeric(10, 2) not null check (monto > 0),
  estado        text not null default 'pendiente_de_pago'
                check (estado in ('pendiente_de_pago', 'pago_en_custodia',
                  'recibido_en_hub', 'en_diagnostico', 'aprobado',
                  'pago_liberado', 'en_camino', 'rechazado', 'reembolsado',
                  'cancelado')),
  metodo_pago   text check (metodo_pago in ('tarjeta', 'pago_movil', 'zelle')),
  referencia    text unique,
  creado_en     timestamptz not null default now(),
  pagado_en     timestamptz
);

-- 2. Seguridad por fila: cada comprador ve solo sus pedidos, y el vendedor
--    ve los pedidos de sus equipos (para saber cuándo enviarlo al Hub).
alter table public.pedidos enable row level security;

drop policy if exists "El comprador ve sus pedidos" on public.pedidos;
create policy "El comprador ve sus pedidos"
  on public.pedidos for select to authenticated
  using (auth.uid() = comprador_id);

drop policy if exists "El vendedor ve los pedidos de sus equipos" on public.pedidos;
create policy "El vendedor ve los pedidos de sus equipos"
  on public.pedidos for select to authenticated
  using (exists (
    select 1 from public.equipos e
    where e.id = equipo_id and e.vendedor_id = auth.uid()
  ));
-- Sin políticas de insert, update ni delete: solo las funciones escriben.

-- 3. HU12: crear el pedido en «Pendiente de pago»
create or replace function public.crear_pedido(p_equipo uuid)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_usuario uuid := auth.uid();
  v_equipo  public.equipos;
  v_pedido  public.pedidos;
begin
  if v_usuario is null then raise exception 'SIN_SESION'; end if;

  select * into v_equipo from public.equipos where id = p_equipo;
  if not found then raise exception 'NO_EXISTE'; end if;
  if v_equipo.vendedor_id = v_usuario then raise exception 'PROPIO'; end if;
  if v_equipo.estado <> 'disponible' then
    -- Si quien lo reservó es esta misma persona, se le dice.
    if exists (select 1 from public.pedidos
               where equipo_id = p_equipo and comprador_id = v_usuario
                 and estado not in ('pendiente_de_pago', 'cancelado')) then
      raise exception 'YA_COMPRADO';
    end if;
    raise exception 'RESERVADO';
  end if;

  -- Si ya tenía un pedido pendiente de este equipo, se reutiliza.
  select * into v_pedido from public.pedidos
    where equipo_id = p_equipo and comprador_id = v_usuario
      and estado = 'pendiente_de_pago'
    limit 1;
  if found then return v_pedido; end if;

  insert into public.pedidos (equipo_id, comprador_id, monto)
    values (p_equipo, v_usuario, v_equipo.precio)
    returning * into v_pedido;
  return v_pedido;
end;
$$;

-- 4. HU01: pago SIMULADO. El dinero queda en custodia y el equipo se
--    reserva en el mismo paso, para que nadie más lo pueda pagar.
create or replace function public.pagar_pedido(
  p_pedido uuid,
  p_metodo text,
  p_simular_rechazo boolean default false
)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_usuario uuid := auth.uid();
  v_pedido  public.pedidos;
  v_equipo  public.equipos;
begin
  if v_usuario is null then raise exception 'SIN_SESION'; end if;

  -- «for update» bloquea el pedido y el equipo mientras se paga: si dos
  -- compradores pagan a la vez, solo uno lo logra.
  select * into v_pedido from public.pedidos
    where id = p_pedido and comprador_id = v_usuario
    for update;
  if not found then raise exception 'NO_EXISTE'; end if;

  -- Si ya estaba pagado, se devuelve tal cual (no se cobra dos veces).
  if v_pedido.estado <> 'pendiente_de_pago' then
    if v_pedido.estado = 'cancelado' then raise exception 'CANCELADO'; end if;
    return v_pedido;
  end if;

  if p_metodo not in ('tarjeta', 'pago_movil', 'zelle') then
    raise exception 'METODO';
  end if;
  if p_simular_rechazo then raise exception 'RECHAZADO'; end if;

  select * into v_equipo from public.equipos
    where id = v_pedido.equipo_id
    for update;
  if v_equipo.estado <> 'disponible' then raise exception 'RESERVADO'; end if;

  update public.equipos set estado = 'reservado' where id = v_equipo.id;

  update public.pedidos
    set estado      = 'pago_en_custodia',
        metodo_pago = p_metodo,
        referencia  = 'RS-' || to_char(now(), 'YYMMDD') || '-' || numero,
        pagado_en   = now()
    where id = p_pedido
    returning * into v_pedido;
  return v_pedido;
end;
$$;

-- 5. Cancelar un pedido que todavía no se ha pagado (heurística 3:
--    «salida de emergencia» si se tocó «Comprar» por error).
create or replace function public.cancelar_pedido(p_pedido uuid)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido public.pedidos;
begin
  update public.pedidos set estado = 'cancelado'
    where id = p_pedido and comprador_id = auth.uid()
      and estado = 'pendiente_de_pago'
    returning * into v_pedido;
  if not found then raise exception 'NO_CANCELABLE'; end if;
  return v_pedido;
end;
$$;

-- Solo las personas con sesión pueden usar estas funciones.
revoke all on function public.crear_pedido(uuid) from public, anon;
revoke all on function public.pagar_pedido(uuid, text, boolean) from public, anon;
revoke all on function public.cancelar_pedido(uuid) from public, anon;
grant execute on function public.crear_pedido(uuid) to authenticated;
grant execute on function public.pagar_pedido(uuid, text, boolean) to authenticated;
grant execute on function public.cancelar_pedido(uuid) to authenticated;
