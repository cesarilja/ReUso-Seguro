-- =====================================================================
-- ReUso Seguro · Prueba de la HU09 (bóveda escrow)
-- Ejecutar en Supabase: SQL Editor → New query → pegar → Run.
--
-- Crea una venta de prueba, la paga y la libera, y revisa que los
-- movimientos se anoten solos. Después provoca A PROPÓSITO un descuadre
-- (un pago liberado dos veces) y comprueba que la bóveda lo detecte y lo
-- registre. También revisa que alguien que no es administrador no pueda
-- leer la bóveda. AL FINAL LO DESHACE TODO.
-- Necesita 3 cuentas creadas (no hace falta ser administrador: el script
-- le da el rol a una de ellas solo durante la prueba).
--
-- Todas las filas deben decir «OK».
-- =====================================================================
create or replace function pg_temp.probar_boveda()
returns table (prueba text, esperado text, obtenido text, resultado text)
language plpgsql
as $$
declare
  v_cuentas    uuid[];
  v_equipo     uuid;
  v_pedido     public.pedidos;
  v_r          jsonb;
  v_texto      text;
  v_contar     int;
  v_cuadres    int;
  v_pruebas    text[] := '{}';
  v_esperados  text[] := '{}';
  v_obtenidos  text[] := '{}';
begin
  select array_agg(id) into v_cuentas from (
    select u.id from auth.users u
    where not exists (select 1 from public.administradores a where a.usuario_id = u.id)
    limit 3) c;
  if coalesce(array_length(v_cuentas, 1), 0) < 3 then
    return query select 'Preparación'::text, '3 cuentas que no sean administradoras'::text,
                        'no hay cuentas suficientes'::text, 'FALTA'::text;
    return;
  end if;

  begin
    -- Cuenta 1 vende (con su cuenta de cobro), cuenta 2 compra, cuenta 3 es
    -- administradora solo durante la prueba.
    insert into public.administradores (usuario_id) values (v_cuentas[3]);
    insert into public.cuentas_cobro (vendedor_id, banco, telefono, cedula, titular)
      values (v_cuentas[1], 'Banesco', '04141234567', 'V12345678', 'Vendedor Prueba')
      on conflict (vendedor_id) do update set telefono = '04141234567';
    insert into public.equipos (vendedor_id, vendedor_nombre, titulo, descripcion,
                                estado_declarado, precio, categoria, estado)
      values (v_cuentas[1], 'Vendedor de prueba', 'Equipo de prueba HU09',
              'Equipo creado por el script de prueba, se borra solo al final.',
              'Usado, en buen estado general', 300, 'Laptop', 'reservado')
      returning id into v_equipo;
    insert into public.pedidos (equipo_id, comprador_id, monto)
      values (v_equipo, v_cuentas[2], 300)
      returning * into v_pedido;

    -- El pago entra a custodia: se anota el ingreso solo.
    update public.pedidos set estado = 'pago_en_custodia', pagado_en = now()
      where id = v_pedido.id;
    select count(*) into v_contar from public.movimientos_boveda
      where pedido_id = v_pedido.id and tipo = 'ingreso' and monto = 300;
    v_pruebas := v_pruebas || 'CP-B1 · Al pagar se anota el ingreso a custodia'::text;
    v_esperados := v_esperados || '1'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    -- Se aprueba y se libera: liberación (276) + comisión (24).
    update public.pedidos set estado = 'aprobado' where id = v_pedido.id;
    perform public.liberar_pago(v_pedido.id);
    select coalesce(sum(monto), 0)::text into v_texto from public.movimientos_boveda
      where pedido_id = v_pedido.id and tipo in ('liberacion', 'comision');
    v_pruebas := v_pruebas || 'CP-B2 · Al liberar sale el monto completo (vendedor + comisión)'::text;
    v_esperados := v_esperados || '300.00'::text;
    v_obtenidos := v_obtenidos || v_texto;

    -- Escenario 4: alguien que no es administrador no puede.
    set local role authenticated;
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_cuentas[2], 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_cuentas[2]::text, true);
    begin
      perform public.revisar_boveda(false);
      v_texto := 'lo permitió';
    exception when others then
      v_texto := sqlerrm;
    end;
    v_pruebas := v_pruebas || 'CP-B3 · Un comprador NO puede revisar la bóveda'::text;
    v_esperados := v_esperados || 'NO_ADMIN'::text;
    v_obtenidos := v_obtenidos || v_texto;

    select count(*) into v_contar from public.movimientos_boveda where pedido_id = v_pedido.id;
    v_pruebas := v_pruebas || 'CP-B4 · Un comprador NO lee los movimientos'::text;
    v_esperados := v_esperados || '0'::text;
    v_obtenidos := v_obtenidos || v_contar::text;

    -- Escenario 2: como administrador, la venta de prueba cuadra.
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_cuentas[3], 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_cuentas[3]::text, true);
    v_r := public.revisar_boveda(false);
    v_pruebas := v_pruebas || 'CP-B5 · La venta de prueba cuadra'::text;
    v_esperados := v_esperados || 'sin descuadre'::text;
    v_obtenidos := v_obtenidos ||
      (case when exists (select 1 from jsonb_array_elements(v_r -> 'descuadres') d
                         where d ->> 'pedido_id' = v_pedido.id::text)
            then 'con descuadre' else 'sin descuadre' end);

    -- Escenario 3: se provoca un descuadre (el pago se libera dos veces).
    reset role;
    insert into public.movimientos_boveda (pedido_id, tipo, monto)
      values (v_pedido.id, 'liberacion', 276);
    select count(*) into v_cuadres from public.cuadres_boveda;
    set local role authenticated;

    v_r := public.revisar_boveda(false);
    select d ->> 'diferencia' into v_texto
      from jsonb_array_elements(v_r -> 'descuadres') d
      where d ->> 'pedido_id' = v_pedido.id::text;
    v_pruebas := v_pruebas || 'CP-B6 · Detecta el pago liberado dos veces y su diferencia'::text;
    v_esperados := v_esperados || '-276.00'::text;
    v_obtenidos := v_obtenidos || coalesce(v_texto, 'no lo detectó');

    v_pruebas := v_pruebas || 'CP-B7 · La bóveda deja de estar cuadrada'::text;
    v_esperados := v_esperados || 'false'::text;
    v_obtenidos := v_obtenidos || (v_r ->> 'cuadrada');

    reset role;
    v_pruebas := v_pruebas || 'CP-B8 · El descuadre queda registrado con su fecha'::text;
    v_esperados := v_esperados || 'registrado'::text;
    v_obtenidos := v_obtenidos ||
      (case when (select count(*) from public.cuadres_boveda) > v_cuadres
                 and (select not cuadrada from public.cuadres_boveda order by id desc limit 1)
            then 'registrado' else 'no registrado' end);

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

select * from pg_temp.probar_boveda();
