-- =====================================================================
-- ReUso Seguro · Sprint 4: HU15 a HU19
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas. Requiere los scripts 01 al 14.
--
-- HU15: el checklist se califica del 1 al 4 (4 excelente, 3 bueno,
--       2 regular, 1 malo) o «No aplica». Una nota de 1 o 2 es una falla:
--       pide nota y foto, igual que antes. Se guarda el puntaje general.
-- HU16: el vendedor elige el plan de inspección al publicar:
--       Básica (4 %, mínimo $5 y máximo $30) o Detallada (8 %, mínimo $10
--       y máximo $60), y si quiere Express (+$8, menos de 24 h).
-- HU17: el vendedor paga la inspección (SIMULADO, con ReUso Pay) cuando
--       presiona «Ya entregué el equipo». No se devuelve si el equipo se
--       rechaza. La comisión por venta baja del 8 % al 5 %.
-- HU18: el plan y el puntaje se ven en el catálogo. Con la inspección
--       Detallada el comprador tiene 7 días para reclamar (en vez de 3).
-- HU19: el vendedor se califica al publicar; si en 2 o más puntos puso 2 o
--       más de lo que encontró el inspector, el dictamen queda marcado como
--       «Declaración inexacta».
--
-- No se mueve dinero real: ningún banco está conectado.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Nuevos datos del equipo (HU16, HU18 y HU19)
-- ---------------------------------------------------------------------
alter table public.equipos add column if not exists plan_inspeccion    text not null default 'basica';
alter table public.equipos add column if not exists express            boolean not null default false;
alter table public.equipos add column if not exists autoevaluacion     jsonb;
alter table public.equipos add column if not exists puntaje_inspeccion numeric(3, 2);

alter table public.equipos drop constraint if exists equipos_plan_inspeccion_check;
alter table public.equipos add constraint equipos_plan_inspeccion_check
  check (plan_inspeccion in ('basica', 'detallada'));

-- ---------------------------------------------------------------------
-- 2. HU16: lo que cuesta la inspección (debe coincidir con
--    lib/models/plan_inspeccion.dart)
-- ---------------------------------------------------------------------
create or replace function public.costo_inspeccion(
  p_precio  numeric,
  p_plan    text,
  p_express boolean default false
)
returns numeric
language sql immutable
as $$
  select round(
    case p_plan
      when 'detallada' then least(greatest(p_precio * 0.08, 10), 60)
      else                  least(greatest(p_precio * 0.04, 5), 30)
    end
    + case when coalesce(p_express, false) then 8 else 0 end, 2);
$$;
grant execute on function public.costo_inspeccion(numeric, text, boolean) to authenticated, anon;

-- La comisión por venta, en un solo lugar (antes 8 %, ahora 5 %).
create or replace function public.tasa_comision()
returns numeric language sql immutable as $$ select 0.05::numeric $$;

-- ---------------------------------------------------------------------
-- 3. HU19: la autoevaluación del vendedor. Califica del 1 al 4 los puntos
--    del checklist de su tipo de equipo; los opcionales (cámaras, lectora,
--    micrófono) los puede dejar sin calificar si su equipo no los tiene.
-- ---------------------------------------------------------------------
create or replace function public.autoevaluacion_valida(p_categoria text, p_datos jsonb)
returns boolean
language plpgsql immutable
as $$
declare
  v_clave text;
  v_valor jsonb;
begin
  if p_datos is null or jsonb_typeof(p_datos) <> 'object' then return false; end if;
  -- Solo puntos de su tipo de equipo, con notas del 1 al 4.
  for v_clave, v_valor in select * from jsonb_each(p_datos) loop
    if not v_clave = any (public.puntos_checklist(p_categoria)) then return false; end if;
    if jsonb_typeof(v_valor) <> 'number' or v_valor::text !~ '^[1-4]$' then return false; end if;
  end loop;
  -- Todos los puntos que no son opcionales tienen que estar calificados.
  foreach v_clave in array public.puntos_checklist(p_categoria) loop
    if not public.punto_opcional(v_clave) and not (p_datos ? v_clave) then return false; end if;
  end loop;
  return true;
end;
$$;

-- La misma regla de publicar de 03_publicar.sql, más la autoevaluación.
drop policy if exists "Cada vendedor publica lo suyo" on public.equipos;
create policy "Cada vendedor publica lo suyo"
  on public.equipos for insert to authenticated
  with check (
    auth.uid() = vendedor_id
    and es_demo = false
    and estado = 'disponible'
    and categoria is not null
    and char_length(trim(vendedor_nombre)) >= 3
    and char_length(trim(titulo)) between 5 and 80
    and char_length(trim(descripcion)) between 30 and 1000
    and char_length(trim(estado_declarado)) >= 15
    and precio between 1 and 10000
    and cardinality(fotos) between 3 and 6
    and not exists (
      select 1 from unnest(fotos) as ruta
      where split_part(ruta, '/', 1) <> auth.uid()::text
    )
    -- HU19: si manda su autoevaluación, tiene que estar completa.
    and (autoevaluacion is null or public.autoevaluacion_valida(categoria, autoevaluacion))
    -- El puntaje lo pone el servidor, nunca el vendedor.
    and puntaje_inspeccion is null
  );

-- HU16, escenario 5: cambiar el plan mientras el equipo no se haya vendido.
create or replace function public.cambiar_plan_inspeccion(
  p_equipo  uuid,
  p_plan    text,
  p_express boolean default false
)
returns public.equipos
language plpgsql security definer set search_path = public
as $$
declare
  v_equipo public.equipos;
begin
  if auth.uid() is null then raise exception 'SIN_SESION'; end if;
  if p_plan not in ('basica', 'detallada') then raise exception 'PLAN'; end if;
  update public.equipos
    set plan_inspeccion = p_plan, express = coalesce(p_express, false)
    where id = p_equipo and vendedor_id = auth.uid() and estado = 'disponible'
    returning * into v_equipo;
  if not found then raise exception 'NO_SE_PUEDE'; end if;
  return v_equipo;
end;
$$;
revoke all on function public.cambiar_plan_inspeccion(uuid, text, boolean) from public, anon;
grant execute on function public.cambiar_plan_inspeccion(uuid, text, boolean) to authenticated;

-- ---------------------------------------------------------------------
-- 4. HU17: el pago de la inspección queda en el pedido
-- ---------------------------------------------------------------------
-- Los pedidos que ya existían (y los de los scripts de prueba) no la
-- piden; los pedidos nuevos de la app sí (ver crear_pedido más abajo).
alter table public.pedidos add column if not exists inspeccion_requerida boolean not null default false;
alter table public.pedidos add column if not exists inspeccion_plan      text;
alter table public.pedidos add column if not exists inspeccion_express   boolean;
alter table public.pedidos add column if not exists inspeccion_monto     numeric(10, 2);
alter table public.pedidos add column if not exists inspeccion_pagada_en timestamptz;
alter table public.pedidos add column if not exists inspeccion_detalle   text;

-- Historial de intentos de pago de la inspección (como intentos_pago).
create table if not exists public.intentos_pago_inspeccion (
  id          bigint generated always as identity primary key,
  pedido_id   uuid not null references public.pedidos (id) on delete cascade,
  vendedor_id uuid not null references auth.users (id) on delete cascade,
  metodo      text not null,
  monto       numeric(10, 2) not null,
  aprobado    boolean not null,
  codigo      text not null,
  detalle     text,
  referencia  text,
  creado_en   timestamptz not null default now()
);
create unique index if not exists intentos_pago_inspeccion_referencia_unica
  on public.intentos_pago_inspeccion (metodo, referencia)
  where aprobado and referencia is not null;
alter table public.intentos_pago_inspeccion enable row level security;
grant select on public.intentos_pago_inspeccion to authenticated;

drop policy if exists "El vendedor ve sus pagos de inspección" on public.intentos_pago_inspeccion;
create policy "El vendedor ve sus pagos de inspección"
  on public.intentos_pago_inspeccion for select to authenticated
  using (vendedor_id = auth.uid() or public.es_admin());

-- Crear pedido (igual que en 10_pasarela_simulada.sql), pero ahora el
-- pedido nuevo pide pagar la inspección antes de entrarla al Hub.
create or replace function public.crear_pedido(p_equipo uuid)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_usuario uuid := auth.uid();
  v_equipo  public.equipos;
  v_pedido  public.pedidos;
begin
  if v_usuario is null then raise exception 'SIN_SESION'; end if;

  select * into v_equipo from public.equipos where id = p_equipo;
  if not found then raise exception 'NO_EXISTE'; end if;
  if v_equipo.vendedor_id = v_usuario then raise exception 'PROPIO'; end if;
  if v_equipo.estado <> 'disponible' then
    if exists (select 1 from public.pedidos
               where equipo_id = p_equipo and comprador_id = v_usuario
                 and estado not in ('pendiente_de_pago', 'cancelado', 'reembolsado')) then
      raise exception 'YA_COMPRADO';
    end if;
    raise exception 'RESERVADO';
  end if;

  update public.pedidos set estado = 'cancelado'
    where comprador_id = v_usuario and estado = 'pendiente_de_pago'
      and creado_en + make_interval(mins => public.minutos_para_pagar()) < now();

  select * into v_pedido from public.pedidos
    where equipo_id = p_equipo and comprador_id = v_usuario
      and estado = 'pendiente_de_pago'
    limit 1;
  if found then return v_pedido; end if;

  insert into public.pedidos (equipo_id, comprador_id, monto, inspeccion_requerida)
    values (p_equipo, v_usuario, v_equipo.precio, true)
    returning * into v_pedido;
  return v_pedido;
end;
$$;

-- HU17: «Ya entregué el equipo» ahora es pagar la inspección. Si el banco
-- aprueba, el pedido queda pagado y entregado en un solo paso.
-- Responde: { aprobado, codigo, monto, pedido }. No lanza error cuando el
-- banco rechaza, para poder guardar el intento.
create or replace function public.pagar_inspeccion(
  p_pedido uuid,
  p_metodo text,
  p_datos  jsonb
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_usuario uuid := auth.uid();
  v_pedido  public.pedidos;
  v_equipo  public.equipos;
  v_monto   numeric(10, 2);
  v_codigo  text;
  v_numero  text := regexp_replace(coalesce(p_datos ->> 'numero', ''), '\D', '', 'g');
  v_ref     text := upper(trim(coalesce(p_datos ->> 'referencia', '')));
  v_detalle text;
begin
  if v_usuario is null then raise exception 'SIN_SESION'; end if;
  if p_metodo not in ('tarjeta', 'pago_movil', 'zelle') then raise exception 'METODO'; end if;

  select p.* into v_pedido from public.pedidos p
    join public.equipos e on e.id = p.equipo_id
    where p.id = p_pedido and e.vendedor_id = v_usuario
    for update of p;
  if not found then raise exception 'NO_VENDEDOR'; end if;

  -- Ya estaba pagada: se devuelve tal cual (nunca se cobra dos veces).
  if v_pedido.inspeccion_pagada_en is not null then
    return jsonb_build_object('aprobado', true, 'codigo', 'APROBADO',
                              'monto', v_pedido.inspeccion_monto,
                              'pedido', to_jsonb(v_pedido));
  end if;
  -- Sin pago del comprador no hay envío (HU04, escenario 4).
  if v_pedido.estado <> 'pago_en_custodia' then raise exception 'ESTADO'; end if;

  select * into v_equipo from public.equipos where id = v_pedido.equipo_id;
  v_monto := public.costo_inspeccion(v_pedido.monto, v_equipo.plan_inspeccion, v_equipo.express);

  v_detalle := case p_metodo
    when 'tarjeta' then public.marca_tarjeta(v_numero) || ' •••• ' || right(v_numero, 4)
    when 'pago_movil' then coalesce(nullif(trim(p_datos ->> 'banco'), ''), 'Pago Móvil')
                           || ' · Ref. ' || v_ref
    else 'Zelle · Conf. ' || v_ref
  end;

  v_codigo := public.banco_simulado(p_metodo, p_datos, v_monto);
  -- Una referencia de Pago Móvil o Zelle sirve para un solo pago.
  if v_codigo is null and p_metodo <> 'tarjeta' and exists (
       select 1 from public.intentos_pago_inspeccion
       where metodo = p_metodo and referencia = v_ref and aprobado) then
    v_codigo := 'REFERENCIA_USADA';
  end if;

  insert into public.intentos_pago_inspeccion
      (pedido_id, vendedor_id, metodo, monto, aprobado, codigo, detalle, referencia)
    values (p_pedido, v_usuario, p_metodo, v_monto, v_codigo is null,
            coalesce(v_codigo, 'APROBADO'), v_detalle,
            case when p_metodo = 'tarjeta' then null else v_ref end);

  if v_codigo is not null then
    return jsonb_build_object('aprobado', false, 'codigo', v_codigo,
                              'monto', v_monto, 'pedido', to_jsonb(v_pedido));
  end if;

  update public.pedidos
    set inspeccion_plan      = v_equipo.plan_inspeccion,
        inspeccion_express   = v_equipo.express,
        inspeccion_monto     = v_monto,
        inspeccion_pagada_en = now(),
        inspeccion_detalle   = v_detalle,
        entregado_en         = coalesce(entregado_en, now())
    where id = p_pedido
    returning * into v_pedido;

  return jsonb_build_object('aprobado', true, 'codigo', 'APROBADO',
                            'monto', v_monto, 'pedido', to_jsonb(v_pedido));
end;
$$;
revoke all on function public.pagar_inspeccion(uuid, text, jsonb) from public, anon;
grant execute on function public.pagar_inspeccion(uuid, text, jsonb) to authenticated;

-- HU04 + HU17: «Ya entregué el equipo» sin pagar la inspección ya no se
-- puede en los pedidos nuevos.
create or replace function public.marcar_entregado(p_pedido uuid)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido public.pedidos;
begin
  if auth.uid() is null then raise exception 'SIN_SESION'; end if;
  select p.* into v_pedido from public.pedidos p
    join public.equipos e on e.id = p.equipo_id
    where p.id = p_pedido and e.vendedor_id = auth.uid()
    for update of p;
  if not found then raise exception 'NO_VENDEDOR'; end if;
  if v_pedido.estado <> 'pago_en_custodia' then raise exception 'ESTADO'; end if;
  if v_pedido.inspeccion_requerida and v_pedido.inspeccion_pagada_en is null then
    raise exception 'INSPECCION_SIN_PAGAR';
  end if;

  update public.pedidos set entregado_en = coalesce(entregado_en, now())
    where id = p_pedido
    returning * into v_pedido;
  return v_pedido;
end;
$$;
revoke all on function public.marcar_entregado(uuid) from public, anon;
grant execute on function public.marcar_entregado(uuid) to authenticated;

-- HU17, escenario 2: sin la inspección pagada, el Hub no registra la
-- llegada (el resto es igual que en 14_reclamos_y_avisos.sql).
create or replace function public.recibir_en_hub(
  p_pedido uuid,
  p_fotos  text[],
  p_nota   text default ''
)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido public.pedidos;
  v_foto   text;
begin
  if not public.es_inspector() then raise exception 'NO_INSPECTOR'; end if;
  if coalesce(array_length(p_fotos, 1), 0) not between 2 and 6 then
    raise exception 'FALTAN_FOTOS';
  end if;
  foreach v_foto in array p_fotos loop
    if v_foto not like p_pedido::text || '/recepcion-%' then
      raise exception 'FOTO_INVALIDA';
    end if;
  end loop;

  select * into v_pedido from public.pedidos where id = p_pedido for update;
  if not found or v_pedido.estado <> 'pago_en_custodia' then raise exception 'ESTADO'; end if;
  if v_pedido.inspeccion_requerida and v_pedido.inspeccion_pagada_en is null then
    raise exception 'INSPECCION_SIN_PAGAR';
  end if;

  update public.pedidos set estado = 'recibido_en_hub'
    where id = p_pedido
    returning * into v_pedido;

  insert into public.recepciones (pedido_id, inspector_id, fotos, nota)
    values (p_pedido, auth.uid(), p_fotos, trim(coalesce(p_nota, '')));
  return v_pedido;
end;
$$;
revoke all on function public.recibir_en_hub(uuid, text[], text) from public, anon;
grant execute on function public.recibir_en_hub(uuid, text[], text) to authenticated;

-- HU17, escenario 4: la liberación cobra ahora el 5 % (igual que en
-- 12_vendedor_y_liberacion.sql, solo cambia la comisión).
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

  v_comision := round(v_pedido.monto * public.tasa_comision(), 2);
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

-- ---------------------------------------------------------------------
-- 5. HU15: checklist con escala del 1 al 4
-- ---------------------------------------------------------------------
alter table public.inspecciones add column if not exists puntaje numeric(3, 2);

-- Cada punto: {"resultado": "ok" | "falla" | "no_aplica",
--              "calificacion": 1..4, "nota": "...", "evidencias": [...]}
-- 4 y 3 = «ok», 2 y 1 = «falla» (piden nota y foto). En la inspección
-- Detallada todos los puntos calificados llevan una nota.
create or replace function public.guardar_inspeccion(p_pedido uuid, p_puntos jsonb)
returns public.inspecciones
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido     public.pedidos;
  v_inspeccion public.inspecciones;
  v_clave      text;
  v_punto      jsonb;
  v_categoria  text;
  v_plan       text;
  v_nota       int;
  v_suma       int := 0;
  v_cuantos    int := 0;
begin
  if not public.es_inspector() then raise exception 'NO_INSPECTOR'; end if;

  select * into v_pedido from public.pedidos where id = p_pedido for update;
  if not found then raise exception 'NO_EXISTE'; end if;
  if v_pedido.estado not in ('recibido_en_hub', 'en_diagnostico') then
    raise exception 'ESTADO';
  end if;

  select categoria, plan_inspeccion into v_categoria, v_plan
    from public.equipos where id = v_pedido.equipo_id;

  foreach v_clave in array public.puntos_checklist(v_categoria)
  loop
    v_punto := p_puntos -> v_clave;
    if v_punto is null
       or coalesce(v_punto ->> 'resultado', '') not in ('ok', 'falla', 'no_aplica') then
      raise exception 'INCOMPLETO:%', v_clave;
    end if;

    if v_punto ->> 'resultado' = 'no_aplica' then
      if not public.punto_opcional(v_clave) then raise exception 'NO_APLICA:%', v_clave; end if;
      continue;
    end if;

    -- HU15: la nota del 1 al 4, coherente con el resultado.
    if coalesce(v_punto ->> 'calificacion', '') !~ '^[1-4]$' then
      raise exception 'SIN_CALIFICACION:%', v_clave;
    end if;
    v_nota := (v_punto ->> 'calificacion')::int;
    if (v_nota <= 2) <> (v_punto ->> 'resultado' = 'falla') then
      raise exception 'CALIFICACION:%', v_clave;
    end if;
    v_suma := v_suma + v_nota;
    v_cuantos := v_cuantos + 1;

    -- Nota 1 o 2 (falla): nota y al menos una foto de evidencia.
    if v_nota <= 2 then
      if char_length(trim(coalesce(v_punto ->> 'nota', ''))) < 10 then
        raise exception 'FALTA_NOTA:%', v_clave;
      end if;
      if jsonb_typeof(v_punto -> 'evidencias') is distinct from 'array'
         or jsonb_array_length(v_punto -> 'evidencias') < 1 then
        raise exception 'FALTA_EVIDENCIA:%', v_clave;
      end if;
    -- HU16: en la inspección Detallada cada punto lleva su observación.
    elsif v_plan = 'detallada'
          and char_length(trim(coalesce(v_punto ->> 'nota', ''))) < 10 then
      raise exception 'FALTA_OBSERVACION:%', v_clave;
    end if;
  end loop;

  insert into public.inspecciones (pedido_id, inspector_id, puntos, completa, puntaje)
    values (p_pedido, auth.uid(), p_puntos, true,
            case when v_cuantos > 0 then round(v_suma::numeric / v_cuantos, 2) end)
  on conflict (pedido_id) do update
    set inspector_id = excluded.inspector_id,
        puntos = excluded.puntos,
        completa = true,
        puntaje = excluded.puntaje,
        actualizado_en = now()
  returning * into v_inspeccion;

  update public.pedidos set estado = 'en_diagnostico' where id = p_pedido;
  return v_inspeccion;
end;
$$;
revoke all on function public.guardar_inspeccion(uuid, jsonb) from public, anon;
grant execute on function public.guardar_inspeccion(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 6. HU18 y HU19: al emitir el dictamen se guarda el puntaje en el equipo
--    (para el catálogo) y se compara con lo que declaró el vendedor.
-- ---------------------------------------------------------------------
alter table public.dictamenes add column if not exists declaracion_inexacta boolean not null default false;
alter table public.dictamenes add column if not exists puntos_inexactos     text[] not null default '{}';

-- Puntos donde el vendedor puso 2 o más de lo que encontró el inspector.
create or replace function public.puntos_inexactos(p_autoevaluacion jsonb, p_puntos jsonb)
returns text[]
language sql immutable
as $$
  select coalesce(array_agg(a.clave order by a.clave), '{}')
  from jsonb_each_text(coalesce(p_autoevaluacion, '{}'::jsonb)) as a(clave, valor)
  where a.valor ~ '^[1-4]$'
    and coalesce(p_puntos -> a.clave ->> 'calificacion', '') ~ '^[1-4]$'
    and a.valor::int - (p_puntos -> a.clave ->> 'calificacion')::int >= 2;
$$;

create or replace function public.comparar_al_dictaminar()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_equipo     uuid;
  v_auto       jsonb;
  v_inspeccion public.inspecciones;
begin
  select p.equipo_id, e.autoevaluacion into v_equipo, v_auto
    from public.pedidos p join public.equipos e on e.id = p.equipo_id
    where p.id = new.pedido_id;
  select * into v_inspeccion from public.inspecciones where pedido_id = new.pedido_id;

  new.puntos_inexactos := public.puntos_inexactos(v_auto, v_inspeccion.puntos);
  new.declaracion_inexacta := cardinality(new.puntos_inexactos) >= 2;

  update public.equipos set puntaje_inspeccion = v_inspeccion.puntaje where id = v_equipo;
  return new;
end;
$$;
revoke all on function public.comparar_al_dictaminar() from public, anon, authenticated;

drop trigger if exists comparar_al_dictaminar on public.dictamenes;
create trigger comparar_al_dictaminar
  before insert on public.dictamenes
  for each row execute function public.comparar_al_dictaminar();

-- ---------------------------------------------------------------------
-- 7. HU18: con la inspección Detallada hay 7 días para reclamar
-- ---------------------------------------------------------------------
create or replace function public.plazo_reclamo_de(p_pedido uuid)
returns int
language sql stable security definer set search_path = public
as $$
  -- El plan con el que se pagó la inspección; si no hay, el del equipo.
  select case when coalesce(p.inspeccion_plan, e.plan_inspeccion) = 'detallada'
              then 7 else public.plazo_reclamo_dias() end
  from public.pedidos p join public.equipos e on e.id = p.equipo_id
  where p.id = p_pedido;
$$;

create or replace function public.abrir_reclamo(p_pedido uuid, p_descripcion text)
returns public.reclamos
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido  public.pedidos;
  v_reclamo public.reclamos;
  v_texto   text := trim(coalesce(p_descripcion, ''));
begin
  if auth.uid() is null then raise exception 'SIN_SESION'; end if;
  select * into v_pedido from public.pedidos
    where id = p_pedido and comprador_id = auth.uid();
  if not found then raise exception 'NO_COMPRADOR'; end if;
  if v_pedido.estado not in ('pago_liberado', 'en_camino') then raise exception 'ESTADO'; end if;
  if v_pedido.recibido_comprador_en is null then raise exception 'SIN_RECIBIR'; end if;
  if now() > v_pedido.recibido_comprador_en
             + make_interval(days => public.plazo_reclamo_de(p_pedido)) then
    raise exception 'FUERA_DE_PLAZO';
  end if;
  if exists (select 1 from public.reclamos where pedido_id = p_pedido) then
    raise exception 'YA_RECLAMADO';
  end if;
  if char_length(v_texto) < 20 then raise exception 'FALTA_DESCRIPCION'; end if;

  insert into public.reclamos (pedido_id, comprador_id, descripcion)
    values (p_pedido, auth.uid(), v_texto)
    returning * into v_reclamo;
  return v_reclamo;
end;
$$;
revoke all on function public.abrir_reclamo(uuid, text) from public, anon;
grant execute on function public.abrir_reclamo(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 8. HU09 + HU17 + HU19: la bóveda muestra lo cobrado por inspecciones y
--    las declaraciones inexactas de cada vendedor. El dinero de las
--    inspecciones NO entra a custodia (lo paga el vendedor aparte), así
--    que el cuadre de la custodia no cambia.
-- ---------------------------------------------------------------------
create or replace function public.revisar_boveda(p_registrar boolean default true)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_descuadres jsonb;
  v_diferencia numeric(12, 2);
  v_cuadrada   boolean;
  v_ultimo     public.cuadres_boveda;
  v_revisado   timestamptz := now();
begin
  if not public.es_admin() then raise exception 'NO_ADMIN'; end if;

  with saldos as (
    select p.id, p.numero, p.estado, p.monto, e.titulo,
           public.custodia_esperada(p.estado, p.monto) as esperado,
           coalesce(sum(case when m.tipo = 'ingreso' then m.monto else -m.monto end), 0) as real
    from public.pedidos p
    join public.equipos e on e.id = p.equipo_id
    left join public.movimientos_boveda m on m.pedido_id = p.id
    group by p.id, e.titulo
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'pedido_id', id, 'numero', numero, 'titulo', titulo, 'estado', estado,
           'esperado', esperado, 'real', real, 'diferencia', real - esperado)
           order by numero), '[]'::jsonb),
         coalesce(sum(real - esperado), 0)
    into v_descuadres, v_diferencia
    from saldos
    where real <> esperado;

  v_cuadrada := jsonb_array_length(v_descuadres) = 0;

  select * into v_ultimo from public.cuadres_boveda order by id desc limit 1;
  if p_registrar
     or (not v_cuadrada and (v_ultimo.id is null or v_ultimo.pedidos is distinct from v_descuadres)) then
    insert into public.cuadres_boveda (revisado_en, cuadrada, diferencia_total, pedidos)
      values (v_revisado, v_cuadrada, v_diferencia, v_descuadres);
  end if;

  return jsonb_build_object(
    'revisado_en', v_revisado,
    'cuadrada', v_cuadrada,
    'diferencia_total', v_diferencia,
    'descuadres', v_descuadres,
    'totales', (
      select jsonb_build_object(
        'en_custodia', coalesce(sum(case when tipo = 'ingreso' then monto else -monto end), 0),
        'liberado', coalesce(sum(monto) filter (where tipo = 'liberacion'), 0),
        'reembolsado', coalesce(sum(monto) filter (where tipo = 'reembolso'), 0),
        'comisiones', coalesce(sum(monto) filter (where tipo = 'comision'), 0),
        'inspecciones', (select coalesce(sum(inspeccion_monto), 0) from public.pedidos
                         where inspeccion_pagada_en is not null))
      from public.movimientos_boveda),
    'por_estado', (
      select coalesce(jsonb_object_agg(estado, cuantos), '{}'::jsonb)
      from (select estado, count(*) as cuantos from public.pedidos
            where estado not in ('pendiente_de_pago', 'cancelado')
            group by estado) c),
    'liberaciones_pendientes', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'pedido_id', p.id, 'numero', p.numero, 'titulo', e.titulo,
               'vendedor', e.vendedor_nombre, 'monto', p.monto,
               'motivo', p.liberacion_motivo, 'intentos', p.liberacion_intentos,
               'ultimo_intento', p.liberacion_ultimo_intento)
               order by p.numero), '[]'::jsonb)
      from public.pedidos p join public.equipos e on e.id = p.equipo_id
      where p.estado = 'liberacion_pendiente'),
    'descuadres_registrados', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'revisado_en', c.revisado_en, 'diferencia_total', c.diferencia_total,
               'pedidos', jsonb_array_length(c.pedidos))
               order by c.id desc), '[]'::jsonb)
      from (select * from public.cuadres_boveda where not cuadrada
            order by id desc limit 5) c),
    'declaraciones_inexactas', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'vendedor', v.vendedor, 'cuantas', v.cuantas, 'ultima', v.ultima)
               order by v.cuantas desc, v.vendedor), '[]'::jsonb)
      from (select e.vendedor_nombre as vendedor, count(*) as cuantas,
                   max(d.creado_en) as ultima
            from public.dictamenes d
            join public.pedidos p on p.id = d.pedido_id
            join public.equipos e on e.id = p.equipo_id
            where d.declaracion_inexacta
            group by e.vendedor_id, e.vendedor_nombre) v)
  );
end;
$$;
revoke all on function public.revisar_boveda(boolean) from public, anon;
grant execute on function public.revisar_boveda(boolean) to authenticated;
