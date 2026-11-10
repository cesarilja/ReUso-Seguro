-- =====================================================================
-- ReUso Seguro · Prueba automática de ReUso Pay (pasarela simulada)
-- Ejecutar en Supabase: SQL Editor → New query → pegar → Run.
--
-- Hace pagos de prueba de verdad contra procesar_pago, como si fuera un
-- comprador, y AL FINAL LO DESHACE TODO: no deja pedidos, intentos ni
-- equipos reservados. Necesita al menos 2 cuentas creadas y 1 equipo
-- disponible que haya publicado una de ellas.
--
-- Todas las filas deben decir «OK».
-- =====================================================================
create or replace function pg_temp.probar_reuso_pay()
returns table (prueba text, esperado text, obtenido text, resultado text)
language plpgsql
as $$
declare
  v_equipo     public.equipos;
  v_comprador  uuid;
  v_pedido     uuid;
  v_r          jsonb;
  v_vence      text := to_char(now() + interval '1 year', 'MM/YY');
  v_ref        text := 'PRB' || floor(random() * 1000000000)::bigint || '7';
  v_pruebas    text[] := '{}';
  v_esperados  text[] := '{}';
  v_obtenidos  text[] := '{}';
begin
  select * into v_equipo from public.equipos
    where estado = 'disponible' and vendedor_id is not null
    limit 1;
  select id into v_comprador from auth.users
    where id is distinct from v_equipo.vendedor_id
    limit 1;
  if v_equipo.id is null or v_comprador is null then
    return query select 'Preparación'::text, 'un equipo disponible y otra cuenta'::text,
                        'no hay datos suficientes'::text, 'FALTA'::text;
    return;
  end if;

  begin
    -- Actúa como el comprador (igual que cuando entra desde la app).
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_comprador, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_comprador::text, true);

    v_pedido := (public.crear_pedido(v_equipo.id)).id;

    v_r := public.procesar_pago(v_pedido, 'tarjeta', jsonb_build_object(
      'numero', '4242 4242 4242 4241', 'vence', v_vence, 'cvv', '123'));
    v_pruebas := v_pruebas || 'CP-P1 · Tarjeta con número inválido (Luhn)'::text;
    v_esperados := v_esperados || 'NUMERO_INVALIDO'::text;
    v_obtenidos := v_obtenidos || (v_r ->> 'codigo');

    v_r := public.procesar_pago(v_pedido, 'tarjeta', jsonb_build_object(
      'numero', '4000 0000 0000 9995', 'vence', v_vence, 'cvv', '123'));
    v_pruebas := v_pruebas || 'CP-P2 · Tarjeta sin fondos'::text;
    v_esperados := v_esperados || 'FONDOS_INSUFICIENTES'::text;
    v_obtenidos := v_obtenidos || (v_r ->> 'codigo');

    v_r := public.procesar_pago(v_pedido, 'pago_movil', jsonb_build_object(
      'banco', 'Banesco', 'referencia', '12340000', 'monto', v_equipo.precio));
    v_pruebas := v_pruebas || 'CP-P3 · Pago Móvil con referencia que no existe'::text;
    v_esperados := v_esperados || 'PAGO_NO_ENCONTRADO'::text;
    v_obtenidos := v_obtenidos || (v_r ->> 'codigo');

    v_r := public.procesar_pago(v_pedido, 'zelle', jsonb_build_object(
      'referencia', v_ref, 'monto', v_equipo.precio - 1));
    v_pruebas := v_pruebas || 'CP-P4 · Zelle por un monto distinto'::text;
    v_esperados := v_esperados || 'MONTO_NO_COINCIDE'::text;
    v_obtenidos := v_obtenidos || (v_r ->> 'codigo');

    v_r := public.procesar_pago(v_pedido, 'zelle', jsonb_build_object(
      'referencia', v_ref, 'monto', v_equipo.precio));
    v_pruebas := v_pruebas || 'CP-P5 · Zelle con datos correctos'::text;
    v_esperados := v_esperados || 'APROBADO'::text;
    v_obtenidos := v_obtenidos || (v_r ->> 'codigo');

    v_pruebas := v_pruebas || 'CP-P6 · El pago quedó en custodia'::text;
    v_esperados := v_esperados || 'pago_en_custodia'::text;
    v_obtenidos := v_obtenidos || (v_r -> 'pedido' ->> 'estado');

    v_pruebas := v_pruebas || 'CP-P7 · El equipo quedó reservado'::text;
    v_esperados := v_esperados || 'reservado'::text;
    v_obtenidos := v_obtenidos ||
      (select estado from public.equipos where id = v_equipo.id);

    v_pruebas := v_pruebas || 'CP-P8 · Se guardaron los 5 intentos'::text;
    v_esperados := v_esperados || '5'::text;
    v_obtenidos := v_obtenidos ||
      (select count(*)::text from public.intentos_pago where pedido_id = v_pedido);

    -- Deshace todo lo de arriba (los resultados ya están guardados).
    raise exception 'DESHACER_PRUEBA';
  exception when others then
    if sqlerrm <> 'DESHACER_PRUEBA' then
      v_pruebas := v_pruebas || 'Error inesperado'::text;
      v_esperados := v_esperados || '-'::text;
      v_obtenidos := v_obtenidos || sqlerrm;
    end if;
  end;

  return query
    select p, e, o, case when e = o then 'OK' else 'FALLA' end
    from unnest(v_pruebas, v_esperados, v_obtenidos) as t(p, e, o);
end;
$$;

select * from pg_temp.probar_reuso_pay();
