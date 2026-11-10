-- =====================================================================
-- ReUso Seguro · Prueba de la HU13 (reembolso por equipo rechazado)
-- Ejecutar en Supabase: SQL Editor → New query → pegar → Run.
-- Solo LEE datos: no cambia nada.
--
-- Cómo usarla:
--   1. Con la app, rechaza un equipo desde el Panel del Hub (dictamen).
--   2. Ejecuta este script. Las cinco filas deben decir «OK».
-- =====================================================================
with rechazados as (
  select p.*, e.estado as estado_equipo
  from public.pedidos p
  join public.dictamenes d on d.pedido_id = p.id and d.resultado = 'rechazado'
  join public.equipos e on e.id = p.equipo_id
)
select 'P1 · Todo pedido rechazado quedó «reembolsado»' as prueba,
       case when count(*) filter (where estado <> 'reembolsado') = 0
            then 'OK' else 'FALLA' end as resultado,
       count(*) as pedidos_revisados
  from rechazados
union all
select 'P2 · Se devolvió el 100 % del monto',
       case when count(*) filter (where monto_reembolsado is distinct from monto) = 0
            then 'OK' else 'FALLA' end,
       count(*)
  from rechazados
union all
select 'P3 · Comisión 0 y el vendedor no cobra',
       case when count(*) filter (where comision <> 0 or monto_vendedor <> 0
                                     or liberado_en is not null) = 0
            then 'OK' else 'FALLA' end,
       count(*)
  from rechazados
union all
select 'P4 · Cada reembolso tiene referencia y fecha',
       case when count(*) filter (where referencia_reembolso is null
                                     or reembolsado_en is null) = 0
            then 'OK' else 'FALLA' end,
       count(*)
  from rechazados
union all
select 'P5 · El equipo volvió a estar disponible',
       -- Si otro comprador ya lo volvió a pagar, estar «reservado» es correcto.
       case when count(*) filter (where estado_equipo <> 'disponible'
              and not exists (select 1 from public.pedidos otro
                              where otro.equipo_id = rechazados.equipo_id
                                and otro.id <> rechazados.id
                                and otro.estado not in ('pendiente_de_pago',
                                  'cancelado', 'reembolsado'))) = 0
            then 'OK' else 'FALLA' end,
       count(*)
  from rechazados;

-- Si «pedidos_revisados» sale en 0, todavía no has rechazado ningún equipo:
-- haz el paso 1 y vuelve a ejecutarlo.
