-- =====================================================================
-- ReUso Seguro · Prueba de la HU20 (reputación del vendedor)
-- Ejecutar en Supabase: SQL Editor → New query → pegar → Run.
--
-- Un vendedor sin historial hace 4 ventas:
--   · las 3 primeras se aprueban: pasa de «nuevo» a «confiable», y la
--     tercera ya se libera con el 4 % de comisión;
--   · la cuarta se rechaza con declaración inexacta: baja a «vendedor».
-- AL FINAL LO DESHACE TODO.
-- Necesita 2 cuentas que NO sean inspectores ni administradores (la que
-- vende no puede tener equipos publicados) y al menos un inspector.
--
-- Todas las filas deben decir «OK».
-- =====================================================================
create or replace function pg_temp.probar_reputacion()
returns table (prueba text, esperado text, obtenido text, resultado text)
language plpgsql
as $$
declare
  v_vendedor   uuid;
  v_comprador  uuid;
  v_inspector  uuid;
  v_equipo     uuid;
  v_pedido     public.pedidos;
  v_r          jsonb;
  v_i          int;
  v_bien       jsonb := '{
    "encendido":{"resultado":"ok","calificacion":4},
    "funcion":{"resultado":"ok","calificacion":4},
    "puertos":{"resultado":"ok","calificacion":3},
    "chasis":{"resultado":"ok","calificacion":3}}';
  v_mal        jsonb := '{
    "encendido":{"resultado":"falla","calificacion":1,"nota":"No enciende nunca","evidencias":["x/1.jpg"]},
    "funcion":{"resultado":"falla","calificacion":1,"nota":"No cumple su función","evidencias":["x/2.jpg"]},
    "puertos":{"resultado":"ok","calificacion":3},
    "chasis":{"resultado":"ok","calificacion":3}}';
  v_pruebas    text[] := '{}';
  v_esperados  text[] := '{}';
  v_obtenidos  text[] := '{}';
begin
  select u.id into v_vendedor from auth.users u
    where not exists (select 1 from public.inspectores i where i.usuario_id = u.id)
      and not exists (select 1 from public.administradores a where a.usuario_id = u.id)
      and not exists (select 1 from public.equipos e where e.vendedor_id = u.id)
    limit 1;
  select u.id into v_comprador from auth.users u
    where u.id is distinct from v_vendedor
      and not exists (select 1 from public.inspectores i where i.usuario_id = u.id)
    limit 1;
  select usuario_id into v_inspector from public.inspectores limit 1;
  if v_vendedor is null or v_comprador is null or v_inspector is null then
    return query select 'Preparación'::text,
                        'un vendedor sin equipos, un comprador y un inspector'::text,
                        'no hay cuentas suficientes'::text, 'FALTA'::text;
    return;
  end if;

  begin
    insert into public.cuentas_cobro (vendedor_id, banco, telefono, cedula, titular)
      values (v_vendedor, 'Banesco', '04141234567', 'V12345678', 'Vendedor Prueba')
      on conflict (vendedor_id) do update set telefono = '04141234567';

    v_r := public.reputacion_vendedor(v_vendedor);
    v_pruebas := v_pruebas || 'CP-R1 · Sin ventas es «nuevo»'::text;
    v_esperados := v_esperados || 'nuevo/0'::text;
    v_obtenidos := v_obtenidos || ((v_r ->> 'nivel') || '/' || (v_r ->> 'ventas'));

    for v_i in 1..4 loop
      -- El vendedor declara todo en 4. Las primeras 3 son ciertas.
      insert into public.equipos (vendedor_id, vendedor_nombre, titulo, descripcion,
                                  estado_declarado, precio, categoria, estado, autoevaluacion)
        values (v_vendedor, 'Vendedor de prueba', 'Equipo de prueba HU20 ' || v_i,
                'Equipo creado por el script de prueba, se borra solo al final.',
                'Como nuevo, todo funciona', 200, 'Otro', 'reservado',
                '{"encendido":4,"funcion":4,"puertos":3,"chasis":3}')
        returning id into v_equipo;
      insert into public.pedidos (equipo_id, comprador_id, monto, estado, metodo_pago,
                                  pagado_en, entregado_en)
        values (v_equipo, v_comprador, 200, 'pago_en_custodia', 'tarjeta',
                now() - interval '2 days', now() - interval '1 day')
        returning * into v_pedido;

      perform set_config('request.jwt.claim.sub', v_inspector::text, true);
      perform public.recibir_en_hub(v_pedido.id,
        array[v_pedido.id::text || '/recepcion-1.jpg', v_pedido.id::text || '/recepcion-2.jpg'], '');
      if v_i <= 3 then
        perform public.guardar_inspeccion(v_pedido.id, v_bien);
        perform public.emitir_dictamen(v_pedido.id, 'aprobado', '');
      else
        perform public.guardar_inspeccion(v_pedido.id, v_mal);
        perform public.emitir_dictamen(v_pedido.id, 'rechazado',
          'No enciende ni cumple su función, no coincide con lo declarado.');
      end if;
      select * into v_pedido from public.pedidos where id = v_pedido.id;

      if v_i = 1 then
        v_pruebas := v_pruebas || 'CP-R2 · Primera venta: sigue «nuevo» y paga el 5 %'::text;
        v_esperados := v_esperados || 'nuevo/10.00'::text;
        v_obtenidos := v_obtenidos ||
          ((public.reputacion_vendedor(v_vendedor) ->> 'nivel') || '/' || coalesce(v_pedido.comision::text, '-'));
      elsif v_i = 3 then
        v_r := public.reputacion_vendedor(v_vendedor);
        v_pruebas := v_pruebas || 'CP-R3 · Con 3 ventas aprobadas pasa a «confiable»'::text;
        v_esperados := v_esperados || 'confiable/3/3'::text;
        v_obtenidos := v_obtenidos ||
          ((v_r ->> 'nivel') || '/' || (v_r ->> 'ventas') || '/' || (v_r ->> 'aprobadas'));

        v_pruebas := v_pruebas || 'CP-R4 · Siendo confiable paga el 4 % (recibe $192)'::text;
        v_esperados := v_esperados || 'pago_liberado/8.00/192.00'::text;
        v_obtenidos := v_obtenidos || (v_pedido.estado || '/' || v_pedido.comision::text
                                       || '/' || v_pedido.monto_vendedor::text);

        v_pruebas := v_pruebas || 'CP-R5 · Días promedio de entrega'::text;
        v_esperados := v_esperados || '1.0'::text;
        v_obtenidos := v_obtenidos || coalesce(v_r ->> 'dias_entrega', '-');
      end if;
    end loop;

    -- La cuarta: rechazada y con declaración inexacta.
    v_r := public.reputacion_vendedor(v_vendedor);
    v_pruebas := v_pruebas || 'CP-R6 · Una declaración inexacta le quita el nivel'::text;
    v_esperados := v_esperados || 'vendedor/1'::text;
    v_obtenidos := v_obtenidos || ((v_r ->> 'nivel') || '/' || (v_r ->> 'inexactas_recientes'));

    v_pruebas := v_pruebas || 'CP-R7 · Sin el nivel vuelve a pagar el 5 %'::text;
    v_esperados := v_esperados || '0.05'::text;
    v_obtenidos := v_obtenidos || public.tasa_comision_de(v_vendedor)::text;

    -- Cualquiera puede ver la reputación (también sin sesión).
    perform set_config('request.jwt.claim.sub', '', true);
    v_pruebas := v_pruebas || 'CP-R8 · La lista pública incluye al vendedor'::text;
    v_esperados := v_esperados || 'sí'::text;
    v_obtenidos := v_obtenidos ||
      (case when exists (select 1 from public.reputaciones_vendedores() r
                         where r ->> 'vendedor_id' = v_vendedor::text)
            then 'sí' else 'no' end);

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

select * from pg_temp.probar_reputacion();
