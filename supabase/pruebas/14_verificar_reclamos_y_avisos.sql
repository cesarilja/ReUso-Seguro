-- =====================================================================
-- ReUso Seguro · Prueba de HU05 (respaldo ante reclamos) y HU10 (avisos)
-- Ejecutar en Supabase: SQL Editor → New query → pegar → Run.
--
-- Crea una venta de prueba, la recibe en el Hub con fotos, la libera, el
-- comprador confirma que la recibió y reclama; revisa el plazo de 3 días,
-- que las fotos de recepción no se puedan cambiar y que los avisos se
-- creen y se marquen como vistos. AL FINAL LO DESHACE TODO.
-- Necesita 3 cuentas que NO sean inspectores ni administradores
-- (vendedor, comprador y una persona ajena) y al menos un inspector.
--
-- Todas las filas deben decir «OK».
-- =====================================================================
create or replace function pg_temp.probar_reclamos_y_avisos()
returns table (prueba text, esperado text, obtenido text, resultado text)
language plpgsql
as $$
declare
  v_cuentas    uuid[];
  v_inspector  uuid;
  v_equipo     uuid;
  v_pedido     public.pedidos;
  v_texto      text;
  v_contar     int;
  v_ids        bigint[];
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
    insert into public.cuentas_cobro (vendedor_id, banco, telefono, cedula, titular)
      values (v_cuentas[1], 'Banesco', '04141234567', 'V12345678', 'Vendedor Prueba')
      on conflict (vendedor_id) do update set telefono = '04141234567';
    insert into public.equipos (vendedor_id, vendedor_nombre, titulo, descripcion,
                                estado_declarado, precio, categoria, estado)
      values (v_cuentas[1], 'Vendedor de prueba', 'Equipo de prueba HU05',
              'Equipo creado por el script de prueba, se borra solo al final.',
              'Usado, en buen estado general', 120, 'Laptop', 'reservado')
      returning id into v_equipo;
    insert into public.pedidos (equipo_id, comprador_id, monto)
      values (v_equipo, v_cuentas[2], 120)
      returning * into v_pedido;
    update public.pedidos set estado = 'pago_en_custodia', pagado_en = now()
      where id = v_pedido.id;

    -- HU10: el pago crea un aviso para el comprador y el vendedor.
    select count(*) into v_contar from public.avisos
      where pedido_id = v_pedido.id and estado = 'pago_en_custodia';
    v_pruebas := v_pruebas || 'CP-A1 · Al pagar se crea el aviso'::text;
    v_esperados := v_esperados || '1'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    -- HU05 escenario 1: sin 2 fotos no se recibe.
    perform set_config('request.jwt.claim.sub', v_inspector::text, true);
    begin
      perform public.recibir_en_hub(v_pedido.id, array[v_pedido.id::text || '/recepcion-1.jpg'], '');
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-R1 · Con 1 sola foto no se puede recibir'::text;
    v_esperados := v_esperados || 'FALTAN_FOTOS'::text;
    v_obtenidos := v_obtenidos || v_texto;

    perform public.recibir_en_hub(v_pedido.id,
      array[v_pedido.id::text || '/recepcion-1.jpg', v_pedido.id::text || '/recepcion-2.jpg'],
      'Llegó con una marca leve en la tapa');
    select count(*) into v_contar from public.recepciones where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-R2 · Con 2 fotos se registra la recepción'::text;
    v_esperados := v_esperados || '1'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    -- HU05 escenario 5: la recepción no se puede borrar ni cambiar.
    begin
      update public.recepciones set fotos = array['x/recepcion-a.jpg', 'x/recepcion-b.jpg']
        where pedido_id = v_pedido.id;
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-R3 · Las fotos de recepción no se cambian'::text;
    v_esperados := v_esperados || 'RECEPCION_INMUTABLE'::text;
    v_obtenidos := v_obtenidos || v_texto;

    begin
      delete from public.recepciones where pedido_id = v_pedido.id;
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-R4 · Las fotos de recepción no se borran'::text;
    v_esperados := v_esperados || 'RECEPCION_INMUTABLE'::text;
    v_obtenidos := v_obtenidos || v_texto;

    -- Se aprueba y se libera (con la cuenta de cobro del vendedor).
    update public.pedidos set estado = 'aprobado' where id = v_pedido.id;
    perform public.liberar_pago(v_pedido.id);

    -- HU05 escenario 3: el comprador confirma que lo recibió y reclama.
    perform set_config('request.jwt.claim.sub', v_cuentas[2]::text, true);
    perform public.confirmar_recibido(v_pedido.id);
    begin
      perform public.abrir_reclamo(v_pedido.id, 'corto');
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-R5 · El reclamo necesita una descripción'::text;
    v_esperados := v_esperados || 'FALTA_DESCRIPCION'::text;
    v_obtenidos := v_obtenidos || v_texto;

    perform public.abrir_reclamo(v_pedido.id,
      'La batería dura menos de lo que dijo el vendedor.');
    select count(*) into v_contar from public.reclamos where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-R6 · Dentro del plazo el reclamo se registra'::text;
    v_esperados := v_esperados || '1'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    -- HU05 escenario 4: fuera de plazo (recibido hace 4 días) no se permite.
    delete from public.reclamos where pedido_id = v_pedido.id;
    update public.pedidos set recibido_comprador_en = now() - interval '4 days'
      where id = v_pedido.id;
    begin
      perform public.abrir_reclamo(v_pedido.id,
        'La batería dura menos de lo que dijo el vendedor.');
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-R7 · Después de 3 días no se puede reclamar'::text;
    v_esperados := v_esperados || 'FUERA_DE_PLAZO'::text;
    v_obtenidos := v_obtenidos || v_texto;

    -- HU10: hay un aviso por cada fase (custodia, Hub, liberado).
    select count(*) into v_contar from public.avisos where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-A2 · Un aviso por cada cambio de estado'::text;
    v_esperados := v_esperados || '3'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    -- HU10 escenario 2: el comprador ve sus avisos y quedan marcados.
    select array_agg(id) into v_ids from public.avisos where pedido_id = v_pedido.id;
    perform public.marcar_avisos_vistos(v_ids);
    select count(*) into v_contar from public.avisos
      where pedido_id = v_pedido.id and comprador_visto_en is not null and vendedor_visto_en is null;
    v_pruebas := v_pruebas || 'CP-A3 · El comprador marca como vistos solo los suyos'::text;
    v_esperados := v_esperados || '3'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    -- Una persona ajena no lee los avisos de ese pedido.
    set local role authenticated;
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_cuentas[3], 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_cuentas[3]::text, true);
    select count(*) into v_contar from public.avisos where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-A4 · Una persona ajena NO ve los avisos'::text;
    v_esperados := v_esperados || '0'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

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

select * from pg_temp.probar_reclamos_y_avisos();
