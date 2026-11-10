-- =====================================================================
-- ReUso Seguro · HU13 Reembolso por equipo rechazado (SIMULADO)
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas. Requiere 06_dictamen.sql y
-- 07_liberacion_pago.sql.
--
-- Cuando el inspector rechaza el equipo, el comprador recupera el 100 %
-- de lo que pagó y la plataforma no cobra comisión. Igual que la
-- liberación (HU06), lo hace un disparador en el servidor: nadie lo hace
-- a mano y el navegador no puede hacerlo. No se mueve dinero real.
-- =====================================================================

-- 1. Datos del reembolso en el pedido
alter table public.pedidos add column if not exists monto_reembolsado    numeric(10, 2);
alter table public.pedidos add column if not exists reembolsado_en       timestamptz;
alter table public.pedidos add column if not exists referencia_reembolso text unique;

-- 2. Un equipo rechazado vuelve a estar «disponible» en el catálogo.
--    (Si se ejecutó una versión anterior de este script que lo marcaba
--    «devuelto», aquí se corrige y se deja solo disponible/reservado.)
update public.equipos set estado = 'disponible' where estado = 'devuelto';
do $$
declare
  v_regla text;
begin
  for v_regla in
    select conname from pg_constraint
    where conrelid = 'public.equipos'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%estado%'
      and pg_get_constraintdef(oid) not ilike '%estado_declarado%'
  loop
    execute format('alter table public.equipos drop constraint %I', v_regla);
  end loop;
end;
$$;
alter table public.equipos add constraint equipos_estado_check
  check (estado in ('disponible', 'reservado'));

-- 3. El reembolso
create or replace function public.reembolsar_pedido(p_pedido uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_equipo uuid;
begin
  -- Solo un pedido rechazado se reembolsa, y una sola vez: si ya está
  -- «reembolsado», el «where» no encuentra nada y no pasa nada.
  update public.pedidos
    set estado               = 'reembolsado',
        monto_reembolsado    = monto,          -- 100 % de lo que pagó
        comision             = 0,              -- sin comisión
        monto_vendedor       = 0,              -- el vendedor no cobra
        reembolsado_en       = now(),
        referencia_reembolso = 'RE-' || to_char(now(), 'YYMMDD') || '-' || numero
    where id = p_pedido and estado = 'rechazado'
    returning equipo_id into v_equipo;

  if v_equipo is not null then
    -- Se libera la reserva: otro comprador lo puede comprar.
    update public.equipos set estado = 'disponible' where id = v_equipo;
  end if;
end;
$$;
-- Solo la usa el disparador de abajo, nunca la app.
revoke all on function public.reembolsar_pedido(uuid) from public, anon, authenticated;

-- 4. HU13: se dispara sola cuando se guarda un dictamen rechazado
create or replace function public.al_rechazar_dictamen()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.resultado = 'rechazado' then
    perform public.reembolsar_pedido(new.pedido_id);
  end if;
  return new;
end;
$$;

drop trigger if exists reembolsar_al_rechazar on public.dictamenes;
create trigger reembolsar_al_rechazar
  after insert on public.dictamenes
  for each row execute function public.al_rechazar_dictamen();

-- 5. Equipos que ya se rechazaron antes de esta historia
do $$
declare
  v_pedido uuid;
begin
  for v_pedido in
    select p.id from public.pedidos p
    join public.dictamenes d on d.pedido_id = p.id and d.resultado = 'rechazado'
    where p.estado = 'rechazado'
  loop
    perform public.reembolsar_pedido(v_pedido);
  end loop;
end;
$$;
