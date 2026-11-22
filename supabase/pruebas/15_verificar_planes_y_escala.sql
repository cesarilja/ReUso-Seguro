-- =====================================================================
-- ReUso Seguro · Prueba de HU15 a HU19 (escala, planes de inspección,
-- cobro de la inspección, sello/plazo y declarado vs encontrado)
-- Ejecutar en Supabase: SQL Editor → New query → pegar → Run.
--
-- Crea dos ventas de prueba:
--   · una laptop con inspección Detallada que el vendedor paga al entregar,
--     el inspector califica del 1 al 4 y RECHAZA (con declaración inexacta);
--   · un teléfono con inspección Básica que se APRUEBA y se libera con la
--     comisión nueva del 5 %.
-- AL FINAL LO DESHACE TODO.
-- Necesita 3 cuentas que NO sean inspectores ni administradores
-- (vendedor, comprador y una que hará de administradora solo durante la
-- prueba) y al menos un inspector.
--
-- Todas las filas deben decir «OK».
-- =====================================================================
create or replace function pg_temp.probar_planes_y_escala()
returns table (prueba text, esperado text, obtenido text, resultado text)
language plpgsql
as $$
declare
  v_cuentas    uuid[];
  v_inspector  uuid;
  v_laptop     uuid;
  v_telefono   uuid;
  v_pedido     public.pedidos;
  v_pedido2    public.pedidos;
  v_r          jsonb;
  v_texto      text;
  v_puntos     jsonb;
  v_pruebas    text[] := '{}';
  v_esperados  text[] := '{}';
  v_obtenidos  text[] := '{}';
begin
  select array_agg(id) into v_cuentas from (
    select u.id from auth.users u
    where not exists (select 1 from public.inspectores i where i.usuario_id = u.id)
      and not exists (select 1 from public.administradores a where a.usuario_id = u.id)
    limit 3) c;
  select usuario_id into v_inspector from public.inspectores limit 1;
  if coalesce(array_length(v_cuentas, 1), 0) < 3 or v_inspector is null then
    return query select 'Preparación'::text, '3 cuentas normales y 1 inspector'::text,
                        'no hay cuentas suficientes'::text, 'FALTA'::text;
    return;
  end if;

  begin
    -- Cuenta 1 vende, cuenta 2 compra, cuenta 3 es administradora solo
    -- durante la prueba.
    insert into public.administradores (usuario_id) values (v_cuentas[3]);
    insert into public.cuentas_cobro (vendedor_id, banco, telefono, cedula, titular)
      values (v_cuentas[1], 'Banesco', '04141234567', 'V12345678', 'Vendedor Prueba')
      on conflict (vendedor_id) do update set telefono = '04141234567';

    -- HU16: precio de la inspección.
    v_pruebas := v_pruebas || 'CP-P1 · Básica de $200 cuesta el 4 %'::text;
    v_esperados := v_esperados || '8.00'::text;
    v_obtenidos := v_obtenidos || public.costo_inspeccion(200, 'basica', false)::text;

    v_pruebas := v_pruebas || 'CP-P2 · Mínimo $5 y máximo $30 en la Básica'::text;
    v_esperados := v_esperados || '5.00/30.00'::text;
    v_obtenidos := v_obtenidos || (public.costo_inspeccion(50, 'basica', false)::text
                                   || '/' || public.costo_inspeccion(1000, 'basica', false)::text);

    v_pruebas := v_pruebas || 'CP-P3 · Detallada de $200 con Express'::text;
    v_esperados := v_esperados || '24.00'::text;
    v_obtenidos := v_obtenidos || public.costo_inspeccion(200, 'detallada', true)::text;

    -- HU19: el vendedor se califica al publicar (todo en 4: «perfecto»).
    insert into public.equipos (vendedor_id, vendedor_nombre, titulo, descripcion,
                                estado_declarado, precio, categoria, estado,
                                plan_inspeccion, autoevaluacion)
      values (v_cuentas[1], 'Vendedor de prueba', 'Laptop de prueba HU15',
              'Equipo creado por el script de prueba, se borra solo al final.',
              'Como nuevo, todo funciona perfecto', 200, 'Laptop', 'disponible',
              'detallada', '{"encendido":4,"pantalla":4,"teclado":4,"bateria":4,"puertos":4,"chasis":4}')
      returning id into v_laptop;
    insert into public.equipos (vendedor_id, vendedor_nombre, titulo, descripcion,
                                estado_declarado, precio, categoria, estado)
      values (v_cuentas[1], 'Vendedor de prueba', 'Teléfono de prueba HU17',
              'Equipo creado por el script de prueba, se borra solo al final.',
              'Usado, en buen estado general', 200, 'Teléfono', 'disponible')
      returning id into v_telefono;

    v_pruebas := v_pruebas || 'CP-A1 · La autoevaluación incompleta no es válida'::text;
    v_esperados := v_esperados || 'false'::text;
    v_obtenidos := v_obtenidos || public.autoevaluacion_valida('Laptop', '{"encendido":4}')::text;

    -- El comprador compra la laptop desde la app (crear_pedido) y paga.
    perform set_config('request.jwt.claim.sub', v_cuentas[2]::text, true);
    v_pedido := public.crear_pedido(v_laptop);
    v_pruebas := v_pruebas || 'CP-P4 · El pedido nuevo pide pagar la inspección'::text;
    v_esperados := v_esperados || 'true'::text;
    v_obtenidos := v_obtenidos || v_pedido.inspeccion_requerida::text;
    v_r := public.procesar_pago(v_pedido.id, 'tarjeta',
      '{"numero":"4242424242424242","vence":"12/39","cvv":"123","titular":"Comprador Prueba"}');

    -- HU17, escenario 2: sin pagar la inspección no se entrega ni se recibe.
    perform set_config('request.jwt.claim.sub', v_cuentas[1]::text, true);
    begin
      perform public.marcar_entregado(v_pedido.id);
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-P5 · Sin pagar la inspección no se marca entregado'::text;
    v_esperados := v_esperados || 'INSPECCION_SIN_PAGAR'::text;
    v_obtenidos := v_obtenidos || v_texto;

    perform set_config('request.jwt.claim.sub', v_inspector::text, true);
    begin
      perform public.recibir_en_hub(v_pedido.id,
        array[v_pedido.id::text || '/recepcion-1.jpg', v_pedido.id::text || '/recepcion-2.jpg'], '');
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-P6 · Sin pagar la inspección el Hub no la recibe'::text;
    v_esperados := v_esperados || 'INSPECCION_SIN_PAGAR'::text;
    v_obtenidos := v_obtenidos || v_texto;

    -- HU17, escenario 1: el vendedor paga. Primero con una tarjeta rechazada.
    perform set_config('request.jwt.claim.sub', v_cuentas[1]::text, true);
    v_r := public.pagar_inspeccion(v_pedido.id, 'tarjeta',
      '{"numero":"4000000000000002","vence":"12/39","cvv":"123"}');
    v_pruebas := v_pruebas || 'CP-P7 · Tarjeta rechazada: no se paga'::text;
    v_esperados := v_esperados || 'false/TARJETA_RECHAZADA'::text;
    v_obtenidos := v_obtenidos || ((v_r ->> 'aprobado') || '/' || (v_r ->> 'codigo'));

    v_r := public.pagar_inspeccion(v_pedido.id, 'tarjeta',
      '{"numero":"4242424242424242","vence":"12/39","cvv":"123"}');
    select * into v_pedido from public.pedidos where id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-P8 · Se paga la Detallada (8 % de $200) y queda entregado'::text;
    v_esperados := v_esperados || 'true/16.00/entregado'::text;
    v_obtenidos := v_obtenidos || ((v_r ->> 'aprobado') || '/' || v_pedido.inspeccion_monto::text
                                   || '/' || case when v_pedido.entregado_en is null
                                                  then 'sin entregar' else 'entregado' end);

    v_r := public.pagar_inspeccion(v_pedido.id, 'tarjeta',
      '{"numero":"4242424242424242","vence":"12/39","cvv":"123"}');
    select count(*)::text into v_texto from public.intentos_pago_inspeccion
      where pedido_id = v_pedido.id and aprobado;
    v_pruebas := v_pruebas || 'CP-P9 · Nunca se cobra dos veces'::text;
    v_esperados := v_esperados || '1'::text;
    v_obtenidos := v_obtenidos || v_texto;

    -- Ya pagada, el Hub la recibe.
    perform set_config('request.jwt.claim.sub', v_inspector::text, true);
    perform public.recibir_en_hub(v_pedido.id,
      array[v_pedido.id::text || '/recepcion-1.jpg', v_pedido.id::text || '/recepcion-2.jpg'], '');

    -- HU15: el checklist con escala.
    v_puntos := '{"encendido":{"resultado":"ok"},"pantalla":{"resultado":"ok","calificacion":4},
                  "teclado":{"resultado":"ok","calificacion":4},"bateria":{"resultado":"ok","calificacion":4},
                  "puertos":{"resultado":"ok","calificacion":4},"chasis":{"resultado":"ok","calificacion":4}}';
    begin
      perform public.guardar_inspeccion(v_pedido.id, v_puntos);
      v_texto := 'lo permitió';
    exception when others then
      v_texto := split_part(sqlerrm, ':', 1);
    end;
    v_pruebas := v_pruebas || 'CP-E1 · Cada punto necesita su nota del 1 al 4'::text;
    v_esperados := v_esperados || 'SIN_CALIFICACION'::text;
    v_obtenidos := v_obtenidos || v_texto;

    v_puntos := jsonb_set(v_puntos, '{encendido}', '{"resultado":"ok","calificacion":2}');
    begin
      perform public.guardar_inspeccion(v_pedido.id, v_puntos);
      v_texto := 'lo permitió';
    exception when others then
      v_texto := split_part(sqlerrm, ':', 1);
    end;
    v_pruebas := v_pruebas || 'CP-E2 · Un 2 no puede quedar como «funciona bien»'::text;
    v_esperados := v_esperados || 'CALIFICACION'::text;
    v_obtenidos := v_obtenidos || v_texto;

    v_puntos := jsonb_set(v_puntos, '{encendido}', '{"resultado":"ok","calificacion":4}');
    begin
      perform public.guardar_inspeccion(v_pedido.id, v_puntos);
      v_texto := 'lo permitió';
    exception when others then
      v_texto := split_part(sqlerrm, ':', 1);
    end;
    v_pruebas := v_pruebas || 'CP-E3 · La Detallada pide una observación en cada punto'::text;
    v_esperados := v_esperados || 'FALTA_OBSERVACION'::text;
    v_obtenidos := v_obtenidos || v_texto;

    -- Inspección completa: la batería (1) y el chasis (2) fallan.
    v_puntos := '{
      "encendido":{"resultado":"ok","calificacion":4,"nota":"Enciende rápido y sin errores"},
      "pantalla":{"resultado":"ok","calificacion":3,"nota":"Un rayón muy leve en la esquina"},
      "teclado":{"resultado":"ok","calificacion":4,"nota":"Todas las teclas responden bien"},
      "bateria":{"resultado":"falla","calificacion":1,"nota":"La batería está inflada","evidencias":["x/bateria-1.jpg"]},
      "puertos":{"resultado":"ok","calificacion":3,"nota":"Un USB está algo flojo"},
      "chasis":{"resultado":"falla","calificacion":2,"nota":"Bisagra izquierda floja","evidencias":["x/chasis-1.jpg"]}}';
    perform public.guardar_inspeccion(v_pedido.id, v_puntos);
    select puntaje::text into v_texto from public.inspecciones where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-E4 · Se guarda el puntaje general (17 / 6)'::text;
    v_esperados := v_esperados || '2.83'::text;
    v_obtenidos := v_obtenidos || coalesce(v_texto, 'sin puntaje');

    -- HU19: el inspector rechaza; el vendedor había puesto 4 en todo.
    perform public.emitir_dictamen(v_pedido.id, 'rechazado',
      'La batería está inflada y la bisagra floja, no coincide con lo declarado.');
    select (declaracion_inexacta::text || '/' || array_to_string(puntos_inexactos, ','))
      into v_texto from public.dictamenes where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-D1 · Declaración inexacta en batería y chasis'::text;
    v_esperados := v_esperados || 'true/bateria,chasis'::text;
    v_obtenidos := v_obtenidos || v_texto;

    select puntaje_inspeccion::text into v_texto from public.equipos where id = v_laptop;
    v_pruebas := v_pruebas || 'CP-S1 · El puntaje queda en el equipo (catálogo)'::text;
    v_esperados := v_esperados || '2.83'::text;
    v_obtenidos := v_obtenidos || coalesce(v_texto, 'sin puntaje');

    -- HU17, escenario 3: al comprador se le devuelve todo; la inspección no.
    select * into v_pedido from public.pedidos where id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-P10 · Rechazado: reembolso del 100 % y la inspección no se devuelve'::text;
    v_esperados := v_esperados || 'reembolsado/200.00/16.00'::text;
    v_obtenidos := v_obtenidos || (v_pedido.estado || '/' || v_pedido.monto_reembolsado::text
                                   || '/' || coalesce(v_pedido.inspeccion_monto::text, 'sin cobro'));

    -- HU18: con la Detallada el plazo para reclamar es de 7 días.
    v_pruebas := v_pruebas || 'CP-S2 · Plazo de reclamo: 7 días (Detallada)'::text;
    v_esperados := v_esperados || '7'::text;
    v_obtenidos := v_obtenidos || public.plazo_reclamo_de(v_pedido.id)::text;

    -- HU17, escenario 4: el teléfono se aprueba y se libera con el 5 %.
    perform set_config('request.jwt.claim.sub', v_cuentas[2]::text, true);
    v_pedido2 := public.crear_pedido(v_telefono);
    v_r := public.procesar_pago(v_pedido2.id, 'tarjeta',
      '{"numero":"4242424242424242","vence":"12/39","cvv":"123","titular":"Comprador Prueba"}');
    perform set_config('request.jwt.claim.sub', v_cuentas[1]::text, true);
    v_r := public.pagar_inspeccion(v_pedido2.id, 'pago_movil',
      '{"banco":"Banesco","referencia":"PRUEBA15A1","monto":"8.00"}');
    perform set_config('request.jwt.claim.sub', v_inspector::text, true);
    perform public.recibir_en_hub(v_pedido2.id,
      array[v_pedido2.id::text || '/recepcion-1.jpg', v_pedido2.id::text || '/recepcion-2.jpg'], '');
    perform public.guardar_inspeccion(v_pedido2.id, '{
      "encendido":{"resultado":"ok","calificacion":4},
      "pantalla_tactil":{"resultado":"ok","calificacion":4},
      "bateria":{"resultado":"ok","calificacion":3},
      "camaras":{"resultado":"no_aplica"},
      "sonido":{"resultado":"ok","calificacion":4},
      "botones_puertos":{"resultado":"ok","calificacion":3},
      "chasis":{"resultado":"ok","calificacion":3}}');
    perform public.emitir_dictamen(v_pedido2.id, 'aprobado', '');
    select * into v_pedido2 from public.pedidos where id = v_pedido2.id;
    -- 5 %, o 4 % si el vendedor ya es Confiable (HU20, script 16).
    v_pruebas := v_pruebas || 'CP-C1 · Liberado con la comisión de su nivel (5 % o 4 %)'::text;
    v_esperados := v_esperados || ('pago_liberado/'
      || round(200 * public.tasa_comision_de(v_cuentas[1]), 2)::text || '/'
      || (200 - round(200 * public.tasa_comision_de(v_cuentas[1]), 2))::text);
    v_obtenidos := v_obtenidos || (v_pedido2.estado || '/' || v_pedido2.comision::text
                                   || '/' || v_pedido2.monto_vendedor::text);

    v_pruebas := v_pruebas || 'CP-S3 · Plazo de reclamo: 3 días (Básica)'::text;
    v_esperados := v_esperados || '3'::text;
    v_obtenidos := v_obtenidos || public.plazo_reclamo_de(v_pedido2.id)::text;

    -- Una referencia de Pago Móvil sirve para un solo pago de inspección.
    perform set_config('request.jwt.claim.sub', v_cuentas[1]::text, true);
    select count(*)::text into v_texto from public.intentos_pago_inspeccion
      where referencia = 'PRUEBA15A1' and aprobado;
    v_pruebas := v_pruebas || 'CP-P11 · Pago Móvil de la inspección aprobado una vez'::text;
    v_esperados := v_esperados || '1'::text;
    v_obtenidos := v_obtenidos || v_texto;

    -- HU09 + HU17 + HU19: la bóveda lo muestra (como administrador).
    perform set_config('request.jwt.claim.sub', v_cuentas[3]::text, true);
    v_r := public.revisar_boveda(false);
    v_pruebas := v_pruebas || 'CP-B1 · La bóveda suma lo cobrado por inspecciones'::text;
    v_esperados := v_esperados || 'sí'::text;
    v_obtenidos := v_obtenidos ||
      (case when (v_r -> 'totales' ->> 'inspecciones')::numeric >= 24 then 'sí' else 'no' end);

    v_pruebas := v_pruebas || 'CP-B2 · La bóveda lista las declaraciones inexactas'::text;
    v_esperados := v_esperados || 'sí'::text;
    v_obtenidos := v_obtenidos ||
      (case when exists (select 1 from jsonb_array_elements(v_r -> 'declaraciones_inexactas') d
                         where d ->> 'vendedor' = 'Vendedor de prueba')
            then 'sí' else 'no' end);

    v_pruebas := v_pruebas || 'CP-B3 · Las ventas de prueba no descuadran la custodia'::text;
    v_esperados := v_esperados || 'sin descuadre'::text;
    v_obtenidos := v_obtenidos ||
      (case when exists (select 1 from jsonb_array_elements(v_r -> 'descuadres') d
                         where d ->> 'pedido_id' in (v_pedido.id::text, v_pedido2.id::text))
            then 'con descuadre' else 'sin descuadre' end);

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

select * from pg_temp.probar_planes_y_escala();
