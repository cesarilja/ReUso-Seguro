-- =====================================================================
-- ReUso Seguro · ReUso Pay: pasarela de pago SIMULADA (HU01 mejorada)
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas. Requiere 04_pago_protegido.sql
-- (y conviene haber ejecutado 09_reembolso.sql antes).
--
-- Reemplaza el interruptor «Simular pago rechazado». Ahora el servidor se
-- comporta como un banco: revisa los datos que manda el comprador y
-- aprueba o rechaza con un motivo real (fondos insuficientes, referencia
-- no encontrada, monto distinto…). La app no decide nada.
--
-- No se mueve dinero real: ningún banco está conectado. Los rechazos se
-- provocan con DATOS DE PRUEBA, como en el modo de prueba de las pasarelas
-- reales (ver README → «Datos de prueba de ReUso Pay»).
-- =====================================================================

-- 1. Datos del pago que se guardan en el pedido.
--    De una tarjeta solo se guarda la marca y los últimos 4 dígitos.
alter table public.pedidos add column if not exists pago_detalle     text;
alter table public.pedidos add column if not exists referencia_banco text;
create unique index if not exists pedidos_referencia_banco_unica
  on public.pedidos (metodo_pago, referencia_banco)
  where referencia_banco is not null;

-- 2. Historial de intentos de pago (como el registro de una pasarela).
create table if not exists public.intentos_pago (
  id           bigint generated always as identity primary key,
  pedido_id    uuid not null references public.pedidos (id) on delete cascade,
  comprador_id uuid not null references auth.users (id) on delete cascade,
  metodo       text not null,
  aprobado     boolean not null,
  codigo       text not null,
  detalle      text,
  creado_en    timestamptz not null default now()
);
alter table public.intentos_pago enable row level security;

drop policy if exists "El comprador ve sus intentos de pago" on public.intentos_pago;
create policy "El comprador ve sus intentos de pago"
  on public.intentos_pago for select to authenticated
  using (comprador_id = auth.uid());
-- Sin insert, update ni delete: solo la función de abajo escribe aquí.

-- 3. Reglas de la pasarela (ajustables en un solo lugar)
create or replace function public.minutos_para_pagar()
returns int language sql immutable as $$ select 15 $$;

create or replace function public.maximo_rechazos()
returns int language sql immutable as $$ select 5 $$;

-- Algoritmo de Luhn: el dígito de control de todas las tarjetas reales.
create or replace function public.luhn_valido(p_numero text)
returns boolean
language plpgsql immutable
as $$
declare
  v_suma  int := 0;
  v_digito int;
  v_largo int := char_length(p_numero);
begin
  if p_numero !~ '^[0-9]{13,19}$' then return false; end if;
  for i in 0 .. v_largo - 1 loop
    v_digito := substr(p_numero, v_largo - i, 1)::int;
    if i % 2 = 1 then
      v_digito := v_digito * 2;
      if v_digito > 9 then v_digito := v_digito - 9; end if;
    end if;
    v_suma := v_suma + v_digito;
  end loop;
  return v_suma % 10 = 0;
end;
$$;

create or replace function public.marca_tarjeta(p_numero text)
returns text
language sql immutable
as $$
  select case
    when p_numero ~ '^4' then 'Visa'
    when p_numero ~ '^(5[1-5]|2(2[2-9]|[3-6][0-9]|7[01]|720))' then 'Mastercard'
    when p_numero ~ '^3[47]' then 'American Express'
    else 'Tarjeta'
  end;
$$;

-- 4. El «banco» simulado: decide si aprueba o rechaza, y por qué.
--    Devuelve el código de rechazo, o null si se aprueba.
create or replace function public.banco_simulado(
  p_metodo text,
  p_datos  jsonb,
  p_monto  numeric
)
returns text
language plpgsql stable security definer set search_path = public
as $$
declare
  v_numero     text := regexp_replace(coalesce(p_datos ->> 'numero', ''), '\D', '', 'g');
  v_vence      text := coalesce(p_datos ->> 'vence', '');
  v_cvv        text := coalesce(p_datos ->> 'cvv', '');
  v_referencia text := upper(trim(coalesce(p_datos ->> 'referencia', '')));
  v_monto      numeric;
  v_mes        int;
  v_anio       int;
begin
  if p_metodo = 'tarjeta' then
    if not public.luhn_valido(v_numero) then return 'NUMERO_INVALIDO'; end if;
    if v_cvv !~ '^[0-9]{3,4}$' then return 'DATOS_INVALIDOS'; end if;
    if v_vence !~ '^(0[1-9]|1[0-2])/[0-9]{2}$' then return 'DATOS_INVALIDOS'; end if;
    v_mes  := split_part(v_vence, '/', 1)::int;
    v_anio := 2000 + split_part(v_vence, '/', 2)::int;
    -- Vence el último día de ese mes.
    if make_date(v_anio, v_mes, 1) + interval '1 month' <= current_date then
      return 'TARJETA_VENCIDA';
    end if;
    -- Tarjetas de prueba (las mismas que usa Stripe en modo de prueba).
    return case v_numero
      when '4000000000000002' then 'TARJETA_RECHAZADA'
      when '4000000000009995' then 'FONDOS_INSUFICIENTES'
      when '4000000000000069' then 'TARJETA_VENCIDA'
      when '4000000000000127' then 'CVV_INCORRECTO'
      else null
    end;
  end if;

  -- Pago Móvil y Zelle: el comprador transfiere desde su banco y confirma
  -- con la referencia. El servidor «concilia»: busca ese pago en el banco.
  if v_referencia !~ '^[A-Z0-9]{6,20}$' then return 'DATOS_INVALIDOS'; end if;
  begin
    v_monto := round((p_datos ->> 'monto')::numeric, 2);
  exception when others then
    return 'DATOS_INVALIDOS';
  end;
  if v_monto is null then return 'DATOS_INVALIDOS'; end if;

  -- Una referencia solo se puede usar una vez (evita reusar un pago viejo).
  if exists (select 1 from public.pedidos
             where metodo_pago = p_metodo and referencia_banco = v_referencia) then
    return 'REFERENCIA_USADA';
  end if;
  -- Dato de prueba: si la referencia termina en 0000, el banco no la encuentra.
  if v_referencia like '%0000' then return 'PAGO_NO_ENCONTRADO'; end if;
  if v_monto <> p_monto then return 'MONTO_NO_COINCIDE'; end if;
  return null;
end;
$$;
revoke all on function public.banco_simulado(text, jsonb, numeric) from public, anon, authenticated;

-- 5. Crear pedido: si el comprador tenía uno pendiente pero ya venció, se
--    cancela y se crea uno nuevo con el reloj en cero.
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

  insert into public.pedidos (equipo_id, comprador_id, monto)
    values (p_equipo, v_usuario, v_equipo.precio)
    returning * into v_pedido;
  return v_pedido;
end;
$$;

-- 6. ReUso Pay: procesar el pago.
--    Responde un JSON: { aprobado, codigo, intentos_restantes, pedido }.
--    No lanza error cuando el banco rechaza, para poder guardar el intento.
create or replace function public.procesar_pago(
  p_pedido uuid,
  p_metodo text,
  p_datos  jsonb
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_usuario  uuid := auth.uid();
  v_pedido   public.pedidos;
  v_equipo   public.equipos;
  v_codigo   text;
  v_rechazos int;
  v_numero   text := regexp_replace(coalesce(p_datos ->> 'numero', ''), '\D', '', 'g');
  v_ref      text := upper(trim(coalesce(p_datos ->> 'referencia', '')));
  v_detalle  text;
begin
  if v_usuario is null then raise exception 'SIN_SESION'; end if;
  if p_metodo not in ('tarjeta', 'pago_movil', 'zelle') then raise exception 'METODO'; end if;

  -- «for update»: si dos compradores pagan a la vez, solo uno lo logra.
  select * into v_pedido from public.pedidos
    where id = p_pedido and comprador_id = v_usuario
    for update;
  if not found then raise exception 'NO_EXISTE'; end if;

  -- Ya estaba pagado: se devuelve tal cual (nunca se cobra dos veces).
  if v_pedido.estado <> 'pendiente_de_pago' then
    if v_pedido.estado = 'cancelado' then raise exception 'CANCELADO'; end if;
    return jsonb_build_object('aprobado', true, 'codigo', 'APROBADO',
                              'pedido', to_jsonb(v_pedido));
  end if;

  -- Se acabó el tiempo para pagar: el pedido se cancela solo.
  if v_pedido.creado_en + make_interval(mins => public.minutos_para_pagar()) < now() then
    update public.pedidos set estado = 'cancelado' where id = p_pedido
      returning * into v_pedido;
    return jsonb_build_object('aprobado', false, 'codigo', 'VENCIDO',
                              'intentos_restantes', 0, 'pedido', to_jsonb(v_pedido));
  end if;

  -- Lo que se guarda del pago (nunca el número completo de la tarjeta).
  v_detalle := case p_metodo
    when 'tarjeta' then public.marca_tarjeta(v_numero) || ' •••• ' || right(v_numero, 4)
    when 'pago_movil' then coalesce(nullif(trim(p_datos ->> 'banco'), ''), 'Pago Móvil')
                           || ' · Ref. ' || v_ref
    else 'Zelle · Conf. ' || v_ref
  end;

  v_codigo := public.banco_simulado(p_metodo, p_datos, v_pedido.monto);

  if v_codigo is null then
    select * into v_equipo from public.equipos where id = v_pedido.equipo_id for update;
    if v_equipo.estado <> 'disponible' then v_codigo := 'RESERVADO'; end if;
  end if;

  if v_codigo is not null then
    insert into public.intentos_pago (pedido_id, comprador_id, metodo, aprobado, codigo, detalle)
      values (p_pedido, v_usuario, p_metodo, false, v_codigo, v_detalle);
    select count(*) into v_rechazos from public.intentos_pago
      where pedido_id = p_pedido and not aprobado;

    -- Por seguridad, después de muchos rechazos el pedido se cancela.
    if v_rechazos >= public.maximo_rechazos() or v_codigo = 'RESERVADO' then
      update public.pedidos set estado = 'cancelado' where id = p_pedido
        returning * into v_pedido;
      if v_codigo <> 'RESERVADO' then v_codigo := 'DEMASIADOS_INTENTOS'; end if;
    end if;

    return jsonb_build_object(
      'aprobado', false,
      'codigo', v_codigo,
      'intentos_restantes', greatest(public.maximo_rechazos() - v_rechazos, 0),
      'pedido', to_jsonb(v_pedido));
  end if;

  -- Aprobado: el dinero queda en custodia y el equipo se reserva.
  update public.equipos set estado = 'reservado' where id = v_equipo.id;
  update public.pedidos
    set estado           = 'pago_en_custodia',
        metodo_pago      = p_metodo,
        referencia       = 'RS-' || to_char(now(), 'YYMMDD') || '-' || numero,
        pagado_en        = now(),
        pago_detalle     = v_detalle,
        referencia_banco = case when p_metodo = 'tarjeta' then null else v_ref end
    where id = p_pedido
    returning * into v_pedido;

  insert into public.intentos_pago (pedido_id, comprador_id, metodo, aprobado, codigo, detalle)
    values (p_pedido, v_usuario, p_metodo, true, 'APROBADO', v_detalle);

  return jsonb_build_object('aprobado', true, 'codigo', 'APROBADO',
                            'pedido', to_jsonb(v_pedido));
end;
$$;

revoke all on function public.procesar_pago(uuid, text, jsonb) from public, anon;
grant execute on function public.procesar_pago(uuid, text, jsonb) to authenticated;

-- 7. Se elimina el pago viejo con el interruptor de simulación, para que
--    nadie pueda pagar saltándose la verificación de ReUso Pay.
drop function if exists public.pagar_pedido(uuid, text, boolean);
