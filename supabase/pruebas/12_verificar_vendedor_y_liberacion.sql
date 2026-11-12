-- =====================================================================
-- ReUso Seguro · Prueba de HU04 (confirmación de fondos) y HU06 (la
-- transferencia falla)
-- Ejecutar en Supabase: SQL Editor → New query → pegar → Run.
--
-- Crea una venta de prueba, la marca como entregada, la aprueba y prueba
-- la liberación sin cuenta, con una cuenta que el banco rechaza y con
-- una cuenta válida. AL FINAL LO DESHACE TODO (también la cuenta).
-- Necesita 2 cuentas que NO sean inspectores (vendedor y comprador) y
-- que exista al menos un inspector.
--
-- Todas las filas deben decir «OK».
-- =====================================================================
create or replace function pg_temp.probar_vendedor_y_liberacion()
returns table (prueba text, esperado text, obtenido text, resultado text)
language plpgsql
as $$
declare
  v_cuentas    uuid[];
  v_inspector  uuid;
  v_equipo     uuid;
  v_pedido     public.pedidos;
  v_texto      text;
  v_pruebas    text[] := '{}';
  v_esperados  text[] := '{}';
  v_obtenidos  text[] := '{}';
begin
  select array_agg(id) into v_cuentas from (
    select u.id from auth.users u
    where not exists (select 1 from public.inspectores i where i.usuario_id = u.id)
    limit 2) c;
  select usuario_id into v_inspector from public.inspectores limit 1;
  if coalesce(array_length(v_cuentas, 1), 0) < 2 or v_inspector is null then
    return query select 'Preparación'::text, '2 cuentas normales y 1 inspector'::text,
                        'no hay cuentas suficientes'::text, 'FALTA'::text;
    return;
  end if;

  begin
    -- El vendedor (cuenta 1) empieza sin cuenta de cobro.
    delete from public.cuentas_cobro where vendedor_id = v_cuentas[1];
    insert into public.equipos (vendedor_id, vendedor_nombre, titulo, descripcion,
                                estado_declarado, precio, categoria, estado)
      values (v_cuentas[1], 'Vendedor de prueba', 'Equipo de prueba HU04',
              'Equipo creado por el script de prueba, se borra solo al final.',
              'Usado, en buen estado general', 200, 'Laptop', 'reservado')
      returning id into v_equipo;
    insert into public.pedidos (equipo_id, comprador_id, monto, estado, metodo_pago, pagado_en)
      values (v_equipo, v_cuentas[2], 200, 'pago_en_custodia', 'tarjeta', now())
      returning * into v_pedido;

    -- HU04 escenario 1: la venta cuenta como nueva hasta que se ve.
    perform set_config('request.jwt.claim.sub', v_cuentas[1]::text, true);
    perform public.marcar_ventas_vistas();
    select * into v_pedido from public.pedidos where id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-V1 · La venta nueva se marca como vista'::text;
    v_esperados := v_esperados || 'vista'::text;
    v_obtenidos := v_obtenidos ||
      (case when v_pedido.vendedor_vio_en is null then 'sin ver' else 'vista' end);

    -- HU04 escenario 3: solo el vendedor marca «Ya entregué».
    perform set_config('request.jwt.claim.sub', v_cuentas[2]::text, true);
    begin
      perform public.marcar_entregado(v_pedido.id);
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-V2 · El comprador NO puede marcarlo entregado'::text;
    v_esperados := v_esperados || 'NO_VENDEDOR'::text;
    v_obtenidos := v_obtenidos || v_texto;

    perform set_config('request.jwt.claim.sub', v_cuentas[1]::text, true);
    v_pedido := public.marcar_entregado(v_pedido.id);
    v_pruebas := v_pruebas || 'CP-V3 · El vendedor lo marca entregado'::text;
    v_esperados := v_esperados || 'con fecha'::text;
    v_obtenidos := v_obtenidos ||
      (case when v_pedido.entregado_en is null then 'sin fecha' else 'con fecha' end);

    -- HU06 escenario 1: se aprueba sin cuenta de cobro → pendiente.
    update public.pedidos set estado = 'aprobado' where id = v_pedido.id;
    insert into public.dictamenes (pedido_id, inspector_id, resultado, motivo)
      values (v_pedido.id, v_inspector, 'aprobado', '');
    select * into v_pedido from public.pedidos where id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-L1 · Sin cuenta: la liberación queda pendiente'::text;
    v_esperados := v_esperados || 'liberacion_pendiente/SIN_CUENTA'::text;
    v_obtenidos := v_obtenidos || (v_pedido.estado || '/' || coalesce(v_pedido.liberacion_motivo, '-'));

    v_pruebas := v_pruebas || 'CP-L2 · El dinero sigue en custodia'::text;
    v_esperados := v_esperados || 'no liberado'::text;
    v_obtenidos := v_obtenidos ||
      (case when v_pedido.liberado_en is null and v_pedido.monto_vendedor is null
            then 'no liberado' else 'liberado' end);

    -- Cuenta que el banco rechaza (teléfono terminado en 0000).
    perform public.guardar_cuenta_cobro('Banesco', '0414 000 0000', 'V12345678', 'Vendedor Prueba');
    select * into v_pedido from public.pedidos where id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-L3 · El banco rechaza la transferencia'::text;
    v_esperados := v_esperados || 'liberacion_pendiente/CUENTA_RECHAZADA'::text;
    v_obtenidos := v_obtenidos || (v_pedido.estado || '/' || coalesce(v_pedido.liberacion_motivo, '-'));

    -- HU06 escenario 2: con una cuenta válida se reintenta y se libera.
    perform public.guardar_cuenta_cobro('Banesco', '0414 123 4567', 'V12345678', 'Vendedor Prueba');
    select * into v_pedido from public.pedidos where id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-L4 · Al corregir la cuenta se reintenta y se libera'::text;
    v_esperados := v_esperados || 'pago_liberado'::text;
    v_obtenidos := v_obtenidos || v_pedido.estado;

    v_pruebas := v_pruebas || 'CP-L5 · Recibe el monto menos el 8 %'::text;
    v_esperados := v_esperados || '184.00'::text;
    v_obtenidos := v_obtenidos || v_pedido.monto_vendedor::text;

    v_pruebas := v_pruebas || 'CP-L6 · Se cuentan los intentos de liberación'::text;
    v_esperados := v_esperados || '3'::text;
    v_obtenidos := v_obtenidos || v_pedido.liberacion_intentos::text;

    -- Validación de la cuenta de cobro.
    begin
      perform public.guardar_cuenta_cobro('Banesco', '0212 123 4567', 'V12345678', 'Vendedor Prueba');
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-L7 · No acepta un teléfono que no es móvil'::text;
    v_esperados := v_esperados || 'TELEFONO'::text;
    v_obtenidos := v_obtenidos || v_texto;

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

select * from pg_temp.probar_vendedor_y_liberacion();
