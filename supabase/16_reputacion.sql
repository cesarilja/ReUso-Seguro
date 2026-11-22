-- =====================================================================
-- ReUso Seguro · Sprint 4: HU20 Reputación del vendedor
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas. Requiere los scripts 01 al 15.
--
-- La reputación sale de las inspecciones del Hub, no de reseñas:
--   · ventas inspeccionadas (las que tienen dictamen);
--   · porcentaje de equipos aprobados;
--   · declaraciones inexactas en las últimas 5 ventas (HU19);
--   · días promedio entre el pago del comprador y la entrega en el Hub.
--
-- Niveles (deben coincidir con lib/models/reputacion.dart):
--   nuevo      menos de 3 ventas inspeccionadas
--   vendedor   3 o más, pero todavía no llega a confiable
--   confiable  3 o más, 90 % o más aprobadas y ninguna declaración
--              inexacta en las últimas 5
--   destacado  lo de confiable, más 10 o más ventas, 95 % o más aprobadas
--              y entrega en 2 días o menos en promedio
--
-- Confiable y destacado pagan 4 % de comisión en vez de 5 %.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. La reputación de un vendedor
-- ---------------------------------------------------------------------
create or replace function public.reputacion_vendedor(p_vendedor uuid)
returns jsonb
language sql stable security definer set search_path = public
as $$
  with ventas as (
    select d.resultado, d.declaracion_inexacta, d.creado_en,
           p.pagado_en, p.entregado_en
    from public.dictamenes d
    join public.pedidos p on p.id = d.pedido_id
    join public.equipos e on e.id = p.equipo_id
    where e.vendedor_id = p_vendedor
  ),
  datos as (
    select
      count(*)::int as ventas,
      count(*) filter (where resultado = 'aprobado')::int as aprobadas,
      (select count(*) from (select declaracion_inexacta from ventas
                             order by creado_en desc limit 5) u
       where u.declaracion_inexacta)::int as inexactas_recientes,
      round((avg(extract(epoch from (entregado_en - pagado_en)) / 86400.0)
               filter (where entregado_en is not null and pagado_en is not null))::numeric, 1)
        as dias_entrega
    from ventas
  )
  select jsonb_build_object(
    'vendedor_id', p_vendedor,
    'ventas', ventas,
    'aprobadas', aprobadas,
    'inexactas_recientes', inexactas_recientes,
    'dias_entrega', dias_entrega,
    'nivel', case
      when ventas < 3 then 'nuevo'
      when ventas >= 10 and aprobadas * 100 >= ventas * 95 and inexactas_recientes = 0
           and dias_entrega is not null and dias_entrega <= 2 then 'destacado'
      when aprobadas * 100 >= ventas * 90 and inexactas_recientes = 0 then 'confiable'
      else 'vendedor'
    end)
  from datos;
$$;
revoke all on function public.reputacion_vendedor(uuid) from public;
-- Es información pública: la ve cualquiera en el catálogo.
grant execute on function public.reputacion_vendedor(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. La reputación de todos los vendedores con al menos un equipo, de una
--    vez (el catálogo la pide una sola vez, no una por tarjeta).
-- ---------------------------------------------------------------------
create or replace function public.reputaciones_vendedores()
returns setof jsonb
language sql stable security definer set search_path = public
as $$
  select public.reputacion_vendedor(v.vendedor_id)
  from (select distinct vendedor_id from public.equipos
        where vendedor_id is not null) v;
$$;
revoke all on function public.reputaciones_vendedores() from public;
grant execute on function public.reputaciones_vendedores() to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. La comisión según el nivel
-- ---------------------------------------------------------------------
create or replace function public.tasa_comision_de(p_vendedor uuid)
returns numeric
language sql stable security definer set search_path = public
as $$
  select case when public.reputacion_vendedor(p_vendedor) ->> 'nivel'
                   in ('confiable', 'destacado')
              then 0.04 else public.tasa_comision() end;
$$;
revoke all on function public.tasa_comision_de(uuid) from public;
grant execute on function public.tasa_comision_de(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. La liberación cobra la comisión del nivel (igual que en
--    15_planes_y_escala.sql, solo cambia la comisión).
-- ---------------------------------------------------------------------
create or replace function public.liberar_pago(p_pedido uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido   public.pedidos;
  v_vendedor uuid;
  v_motivo   text;
  v_comision numeric(10, 2);
begin
  select * into v_pedido from public.pedidos
    where id = p_pedido and estado in ('aprobado', 'liberacion_pendiente')
    for update;
  if not found then return; end if;

  select vendedor_id into v_vendedor from public.equipos where id = v_pedido.equipo_id;
  v_motivo := public.transferencia_simulada(v_vendedor);

  if v_motivo is not null then
    update public.pedidos
      set estado                    = 'liberacion_pendiente',
          liberacion_motivo         = v_motivo,
          liberacion_intentos       = liberacion_intentos + 1,
          liberacion_ultimo_intento = now()
      where id = p_pedido;
    return;
  end if;

  -- HU20: 4 % para los vendedores Confiable y Destacado, 5 % para el resto.
  v_comision := round(v_pedido.monto * public.tasa_comision_de(v_vendedor), 2);
  update public.pedidos
    set estado                    = 'pago_liberado',
        comision                  = v_comision,
        monto_vendedor            = monto - v_comision,
        liberado_en               = now(),
        liberacion_motivo         = null,
        liberacion_intentos       = liberacion_intentos + 1,
        liberacion_ultimo_intento = now()
    where id = p_pedido;
end;
$$;
revoke all on function public.liberar_pago(uuid) from public, anon, authenticated;
