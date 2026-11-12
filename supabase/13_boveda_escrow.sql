-- =====================================================================
-- ReUso Seguro · HU09 Gestión de la bóveda escrow (SIMULADA)
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas. Requiere los scripts 04 al 12.
--
-- 1. Crea el rol de ADMINISTRADOR (como el de inspector en 05).
-- 2. Cada movimiento de dinero queda registrado solo, con un disparador:
--    entra a custodia, se libera al vendedor, se cobra la comisión o se
--    reembolsa al comprador. Nadie los escribe a mano.
-- 3. El cuadre compara, pedido por pedido, lo que DEBERÍA estar en
--    custodia según su estado con lo que dicen los movimientos. Si algo
--    no coincide (por ejemplo, un pago liberado dos veces), lo informa
--    con los pedidos afectados y la diferencia, y lo deja registrado.
--
-- Para dar acceso de administrador a una cuenta (cambia el correo):
--   insert into public.administradores (usuario_id)
--   select id from auth.users where email = 'correo@ejemplo.com'
--   on conflict do nothing;
-- =====================================================================

-- 1. Administradores
create table if not exists public.administradores (
  usuario_id uuid primary key references auth.users (id) on delete cascade,
  creado_en  timestamptz not null default now()
);
alter table public.administradores enable row level security;
-- Sin políticas: nadie la lee ni la escribe desde la app.

create or replace function public.es_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.administradores where usuario_id = auth.uid());
$$;
revoke all on function public.es_admin() from public, anon;
grant execute on function public.es_admin() to authenticated;

-- El administrador ve todos los pedidos (y recibe sus cambios en vivo).
drop policy if exists "El administrador ve todos los pedidos" on public.pedidos;
create policy "El administrador ve todos los pedidos"
  on public.pedidos for select to authenticated
  using (public.es_admin());

-- 2. Libro de movimientos de la bóveda
create table if not exists public.movimientos_boveda (
  id        bigint generated always as identity primary key,
  pedido_id uuid not null references public.pedidos (id) on delete cascade,
  -- ingreso: el pago entra a custodia (+)
  -- liberacion: sale al vendedor (−) · comision: sale para la plataforma (−)
  -- reembolso: vuelve al comprador (−)
  tipo      text not null check (tipo in ('ingreso', 'liberacion', 'comision', 'reembolso')),
  monto     numeric(10, 2) not null check (monto >= 0),
  creado_en timestamptz not null default now()
);
create index if not exists movimientos_boveda_pedido on public.movimientos_boveda (pedido_id);
alter table public.movimientos_boveda enable row level security;

drop policy if exists "Solo el administrador ve los movimientos" on public.movimientos_boveda;
create policy "Solo el administrador ve los movimientos"
  on public.movimientos_boveda for select to authenticated
  using (public.es_admin());
-- Sin insert/update/delete: solo el disparador de abajo escribe.

-- 3. Registro de cuadres (cada revisión, y siempre que haya descuadre)
create table if not exists public.cuadres_boveda (
  id               bigint generated always as identity primary key,
  revisado_en      timestamptz not null default now(),
  cuadrada         boolean not null,
  diferencia_total numeric(12, 2) not null default 0,
  pedidos          jsonb not null default '[]'
);
alter table public.cuadres_boveda enable row level security;

drop policy if exists "Solo el administrador ve los cuadres" on public.cuadres_boveda;
create policy "Solo el administrador ve los cuadres"
  on public.cuadres_boveda for select to authenticated
  using (public.es_admin());

-- Permiso de lectura (las reglas RLS de arriba deciden quién ve qué filas).
grant select on public.movimientos_boveda, public.cuadres_boveda to authenticated;

-- 4. El disparador que anota cada movimiento
create or replace function public.anotar_movimiento_boveda()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then return new; end if;

  if new.estado = 'pago_en_custodia' and old.estado = 'pendiente_de_pago' then
    insert into public.movimientos_boveda (pedido_id, tipo, monto)
      values (new.id, 'ingreso', new.monto);
  elsif new.estado = 'pago_liberado' then
    insert into public.movimientos_boveda (pedido_id, tipo, monto)
      values (new.id, 'liberacion', coalesce(new.monto_vendedor, 0)),
             (new.id, 'comision', coalesce(new.comision, 0));
  elsif new.estado = 'reembolsado' then
    insert into public.movimientos_boveda (pedido_id, tipo, monto)
      values (new.id, 'reembolso', coalesce(new.monto_reembolsado, new.monto));
  end if;
  return new;
end;
$$;
revoke all on function public.anotar_movimiento_boveda() from public, anon, authenticated;

drop trigger if exists anotar_movimiento_boveda on public.pedidos;
create trigger anotar_movimiento_boveda
  after update of estado on public.pedidos
  for each row execute function public.anotar_movimiento_boveda();

-- Pedidos que ya existían: se anotan sus movimientos una sola vez.
insert into public.movimientos_boveda (pedido_id, tipo, monto, creado_en)
  select p.id, 'ingreso', p.monto, coalesce(p.pagado_en, p.creado_en)
  from public.pedidos p
  where p.estado not in ('pendiente_de_pago', 'cancelado')
    and not exists (select 1 from public.movimientos_boveda m where m.pedido_id = p.id);

insert into public.movimientos_boveda (pedido_id, tipo, monto, creado_en)
  select p.id, t.tipo, t.monto, coalesce(p.liberado_en, now())
  from public.pedidos p
  cross join lateral (values ('liberacion', coalesce(p.monto_vendedor, 0)),
                             ('comision', coalesce(p.comision, 0))) as t(tipo, monto)
  where p.estado in ('pago_liberado', 'en_camino')
    and not exists (select 1 from public.movimientos_boveda m
                    where m.pedido_id = p.id and m.tipo <> 'ingreso');

insert into public.movimientos_boveda (pedido_id, tipo, monto, creado_en)
  select p.id, 'reembolso', coalesce(p.monto_reembolsado, p.monto), coalesce(p.reembolsado_en, now())
  from public.pedidos p
  where p.estado = 'reembolsado'
    and not exists (select 1 from public.movimientos_boveda m
                    where m.pedido_id = p.id and m.tipo <> 'ingreso');

-- 5. Lo que debería estar en custodia según el estado del pedido.
create or replace function public.custodia_esperada(p_estado text, p_monto numeric)
returns numeric
language sql immutable
as $$
  select case
    when p_estado in ('pago_en_custodia', 'recibido_en_hub', 'en_diagnostico',
                      'aprobado', 'liberacion_pendiente', 'rechazado')
      then p_monto
    else 0
  end;
$$;

-- 6. HU09: revisar la bóveda. Solo el administrador.
--    Devuelve los totales, si cuadra, los pedidos con descuadre, las
--    liberaciones pendientes (HU06) y cuántos pedidos hay en cada estado.
--    p_registrar = true guarda la revisión; los descuadres se guardan
--    siempre (una vez por cada descuadre distinto).
create or replace function public.revisar_boveda(p_registrar boolean default true)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_descuadres jsonb;
  v_diferencia numeric(12, 2);
  v_cuadrada   boolean;
  v_ultimo     public.cuadres_boveda;
  v_revisado   timestamptz := now();
begin
  if not public.es_admin() then raise exception 'NO_ADMIN'; end if;

  with saldos as (
    select p.id, p.numero, p.estado, p.monto, e.titulo,
           public.custodia_esperada(p.estado, p.monto) as esperado,
           coalesce(sum(case when m.tipo = 'ingreso' then m.monto else -m.monto end), 0) as real
    from public.pedidos p
    join public.equipos e on e.id = p.equipo_id
    left join public.movimientos_boveda m on m.pedido_id = p.id
    group by p.id, e.titulo
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'pedido_id', id, 'numero', numero, 'titulo', titulo, 'estado', estado,
           'esperado', esperado, 'real', real, 'diferencia', real - esperado)
           order by numero), '[]'::jsonb),
         coalesce(sum(real - esperado), 0)
    into v_descuadres, v_diferencia
    from saldos
    where real <> esperado;

  v_cuadrada := jsonb_array_length(v_descuadres) = 0;

  select * into v_ultimo from public.cuadres_boveda order by id desc limit 1;
  if p_registrar
     or (not v_cuadrada and (v_ultimo.id is null or v_ultimo.pedidos is distinct from v_descuadres)) then
    insert into public.cuadres_boveda (revisado_en, cuadrada, diferencia_total, pedidos)
      values (v_revisado, v_cuadrada, v_diferencia, v_descuadres);
  end if;

  return jsonb_build_object(
    'revisado_en', v_revisado,
    'cuadrada', v_cuadrada,
    'diferencia_total', v_diferencia,
    'descuadres', v_descuadres,
    'totales', (
      select jsonb_build_object(
        'en_custodia', coalesce(sum(case when tipo = 'ingreso' then monto else -monto end), 0),
        'liberado', coalesce(sum(monto) filter (where tipo = 'liberacion'), 0),
        'reembolsado', coalesce(sum(monto) filter (where tipo = 'reembolso'), 0),
        'comisiones', coalesce(sum(monto) filter (where tipo = 'comision'), 0))
      from public.movimientos_boveda),
    'por_estado', (
      select coalesce(jsonb_object_agg(estado, cuantos), '{}'::jsonb)
      from (select estado, count(*) as cuantos from public.pedidos
            where estado not in ('pendiente_de_pago', 'cancelado')
            group by estado) c),
    'liberaciones_pendientes', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'pedido_id', p.id, 'numero', p.numero, 'titulo', e.titulo,
               'vendedor', e.vendedor_nombre, 'monto', p.monto,
               'motivo', p.liberacion_motivo, 'intentos', p.liberacion_intentos,
               'ultimo_intento', p.liberacion_ultimo_intento)
               order by p.numero), '[]'::jsonb)
      from public.pedidos p join public.equipos e on e.id = p.equipo_id
      where p.estado = 'liberacion_pendiente'),
    'descuadres_registrados', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'revisado_en', c.revisado_en, 'diferencia_total', c.diferencia_total,
               'pedidos', jsonb_array_length(c.pedidos))
               order by c.id desc), '[]'::jsonb)
      from (select * from public.cuadres_boveda where not cuadrada
            order by id desc limit 5) c)
  );
end;
$$;
revoke all on function public.revisar_boveda(boolean) from public, anon;
grant execute on function public.revisar_boveda(boolean) to authenticated;
