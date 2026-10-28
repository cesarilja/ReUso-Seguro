-- =====================================================================
-- ReUso Seguro · Actualizaciones en tiempo real (Supabase Realtime)
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas.
--
-- Activa el aviso de cambios de estas tablas para que la app se actualice
-- sola (catálogo, Mis compras, Mis ventas y Panel del Hub) sin recargar la
-- página. Cada persona solo recibe los cambios que tiene permiso de ver
-- (las mismas reglas RLS).
-- =====================================================================
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['equipos', 'pedidos', 'inspecciones', 'dictamenes']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', v_tabla);
    exception when duplicate_object then
      null; -- ya estaba activada
    end;
  end loop;
end;
$$;

-- Comprobación: deben salir las 4 tablas.
select tablename from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'public'
order by tablename;
