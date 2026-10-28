-- =====================================================================
-- ReUso Seguro · HU06 Liberación automática del pago (SIMULADA)
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas. Requiere 06_dictamen.sql.
--
-- Cuando el inspector aprueba el equipo, el pago en custodia se libera
-- solo al vendedor, descontando la comisión de la plataforma (8 %).
-- Nadie lo hace a mano y el navegador no puede hacerlo: lo hace un
-- disparador (trigger) en el servidor. No se mueve dinero real.
-- =====================================================================

-- 1. Datos de la liberación en el pedido
alter table public.pedidos add column if not exists comision       numeric(10, 2);
alter table public.pedidos add column if not exists monto_vendedor numeric(10, 2);
alter table public.pedidos add column if not exists liberado_en    timestamptz;

-- 2. La liberación
create or replace function public.liberar_pago(p_pedido uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update public.pedidos
    set estado         = 'pago_liberado',
        comision       = round(monto * 0.08, 2),
        monto_vendedor = monto - round(monto * 0.08, 2),
        liberado_en    = now()
    where id = p_pedido and estado = 'aprobado';
end;
$$;
-- Solo la usa el disparador de abajo, nunca la app.
revoke all on function public.liberar_pago(uuid) from public, anon, authenticated;

-- 3. HU06: se dispara sola cuando se guarda un dictamen aprobado
create or replace function public.al_emitir_dictamen()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.resultado = 'aprobado' then
    perform public.liberar_pago(new.pedido_id);
  end if;
  return new;
end;
$$;

drop trigger if exists liberar_pago_al_aprobar on public.dictamenes;
create trigger liberar_pago_al_aprobar
  after insert on public.dictamenes
  for each row execute function public.al_emitir_dictamen();

-- 4. Equipos que ya se aprobaron antes de esta historia
update public.pedidos p
  set estado         = 'pago_liberado',
      comision       = round(p.monto * 0.08, 2),
      monto_vendedor = p.monto - round(p.monto * 0.08, 2),
      liberado_en    = now()
  where p.estado = 'aprobado'
    and exists (select 1 from public.dictamenes d
                where d.pedido_id = p.id and d.resultado = 'aprobado');
