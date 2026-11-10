-- =====================================================================
-- ReUso Seguro · Prueba de HU02 (rastreo) y HU03 (certificado técnico)
-- Ejecutar en Supabase: SQL Editor → New query → pegar → Run.
--
-- Crea un pedido de prueba, lo pasa por las fases, emite un dictamen y
-- revisa quién puede leer el certificado. AL FINAL LO DESHACE TODO.
-- Necesita 3 cuentas que NO sean inspectores (vendedor, comprador y una
-- persona ajena) y que exista al menos un inspector.
--
-- Todas las filas deben decir «OK».
-- =====================================================================
create or replace function pg_temp.probar_rastreo_certificado()
returns table (prueba text, esperado text, obtenido text, resultado text)
language plpgsql
as $$
declare
  v_cuentas    uuid[];
  v_inspector  uuid;
  v_equipo     uuid;
  v_pedido     public.pedidos;
  v_dictamen   public.dictamenes;
  v_contar     int;
  v_pruebas    text[] := '{}';
  v_esperados  text[] := '{}';
  v_obtenidos  text[] := '{}';
begin
  select array_agg(id) into v_cuentas from (
    select u.id from auth.users u
    where not exists (select 1 from public.inspectores i where i.usuario_id = u.id)
    limit 3) c;
  select usuario_id into v_inspector from public.inspectores limit 1;
  if coalesce(array_length(v_cuentas, 1), 0) < 3 or v_inspector is null then
    return query select 'Preparación'::text, '3 cuentas normales y 1 inspector'::text,
                        'no hay cuentas suficientes'::text, 'FALTA'::text;
    return;
  end if;

  begin
    -- Equipo del vendedor (cuenta 1) y pedido pagado del comprador (cuenta 2).
    insert into public.equipos (vendedor_id, vendedor_nombre, titulo, descripcion,
                                estado_declarado, precio, categoria, estado)
      values (v_cuentas[1], 'Vendedor de prueba', 'Equipo de prueba HU02',
              'Equipo creado por el script de prueba, se borra solo al final.',
              'Usado, en buen estado general', 100, 'Laptop', 'reservado')
      returning id into v_equipo;
    insert into public.pedidos (equipo_id, comprador_id, monto, estado, metodo_pago, pagado_en)
      values (v_equipo, v_cuentas[2], 100, 'pago_en_custodia', 'tarjeta', now())
      returning * into v_pedido;

    -- HU02: cada cambio de fase anota su fecha.
    update public.pedidos set estado = 'recibido_en_hub' where id = v_pedido.id
      returning * into v_pedido;
    v_pruebas := v_pruebas || 'CP-R1 · Al recibirlo en el Hub se anota la fecha'::text;
    v_esperados := v_esperados || 'con fecha'::text;
    v_obtenidos := v_obtenidos ||
      (case when v_pedido.recibido_en is null then 'sin fecha' else 'con fecha' end);

    update public.pedidos set estado = 'en_diagnostico' where id = v_pedido.id
      returning * into v_pedido;
    v_pruebas := v_pruebas || 'CP-R2 · Al pasar a diagnóstico se anota la fecha'::text;
    v_esperados := v_esperados || 'con fecha'::text;
    v_obtenidos := v_obtenidos ||
      (case when v_pedido.diagnostico_en is null then 'sin fecha' else 'con fecha' end);

    v_pruebas := v_pruebas || 'CP-R3 · La fecha de recepción no se pierde'::text;
    v_esperados := v_esperados || 'con fecha'::text;
    v_obtenidos := v_obtenidos ||
      (case when v_pedido.recibido_en is null then 'sin fecha' else 'con fecha' end);

    -- HU03: el dictamen queda firmado con el nombre del inspector.
    insert into public.inspecciones (pedido_id, inspector_id, puntos, completa)
      values (v_pedido.id, v_inspector, '{"encendido": {"resultado": "ok"}}', true);
    update public.pedidos set estado = 'aprobado' where id = v_pedido.id;
    insert into public.dictamenes (pedido_id, inspector_id, resultado, motivo)
      values (v_pedido.id, v_inspector, 'aprobado', '')
      returning * into v_dictamen;
    v_pruebas := v_pruebas || 'CP-C1 · El dictamen guarda el nombre del inspector'::text;
    v_esperados := v_esperados || 'con nombre'::text;
    v_obtenidos := v_obtenidos ||
      (case when coalesce(v_dictamen.inspector_nombre, '') = '' then 'sin nombre' else 'con nombre' end);

    -- HU03 escenario 5: solo el comprador y el vendedor ven el certificado.
    set local role authenticated;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_cuentas[2], 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_cuentas[2]::text, true);
    select count(*) into v_contar from public.dictamenes where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-C2 · El comprador ve el certificado'::text;
    v_esperados := v_esperados || '1'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_cuentas[1], 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_cuentas[1]::text, true);
    select count(*) into v_contar from public.inspecciones where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-C3 · El vendedor ve el checklist'::text;
    v_esperados := v_esperados || '1'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_cuentas[3], 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_cuentas[3]::text, true);
    select count(*) into v_contar from public.dictamenes where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-C4 · Una persona ajena NO ve el dictamen'::text;
    v_esperados := v_esperados || '0'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    select count(*) into v_contar from public.inspecciones where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-C5 · Una persona ajena NO ve el checklist'::text;
    v_esperados := v_esperados || '0'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

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

select * from pg_temp.probar_rastreo_certificado();
