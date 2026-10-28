-- =====================================================================
-- ReUso Seguro · HU07 Checklist de inspección en el Hub
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas.
--
-- Solo los inspectores técnicos pueden ver el panel del Hub y guardar
-- inspecciones. El checklist se revisa en el servidor: no se guarda si
-- falta algún punto de su tipo de equipo o si una falla no tiene nota y
-- foto de evidencia.
-- =====================================================================

-- 1. Quién es inspector técnico (cuentas internas del Hub, RNF2)
create table if not exists public.inspectores (
  usuario_id uuid primary key references auth.users (id) on delete cascade,
  creado_en  timestamptz not null default now()
);
alter table public.inspectores enable row level security;
-- Sin políticas: nadie la lee ni la cambia desde la app. Se usa así:

create or replace function public.es_inspector()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.inspectores where usuario_id = auth.uid());
$$;
revoke all on function public.es_inspector() from public, anon;
grant execute on function public.es_inspector() to authenticated;

-- 2. El inspector ve todos los pedidos que pasan por el Hub
drop policy if exists "El inspector ve los pedidos del Hub" on public.pedidos;
create policy "El inspector ve los pedidos del Hub"
  on public.pedidos for select to authenticated
  using (public.es_inspector());

-- 3. Inspecciones: un checklist por pedido («entity» Inspeccion)
create table if not exists public.inspecciones (
  pedido_id      uuid primary key references public.pedidos (id) on delete cascade,
  inspector_id   uuid not null references auth.users (id),
  -- {"encendido": {"resultado": "ok"}, "pantalla": {"resultado": "falla",
  --   "nota": "...", "evidencias": ["<pedido>/pantalla-1.jpg"]}, ...}
  puntos         jsonb not null,
  completa       boolean not null default false,
  actualizado_en timestamptz not null default now()
);
alter table public.inspecciones enable row level security;

drop policy if exists "El inspector ve las inspecciones" on public.inspecciones;
create policy "El inspector ve las inspecciones"
  on public.inspecciones for select to authenticated
  using (public.es_inspector());
-- El comprador y el vendedor la verán con el dictamen (HU08).

-- 4. Fotos de evidencia de las fallas
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('evidencias', 'evidencias', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "El inspector sube evidencias" on storage.objects;
create policy "El inspector sube evidencias"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'evidencias' and public.es_inspector());

drop policy if exists "El inspector borra evidencias" on storage.objects;
create policy "El inspector borra evidencias"
  on storage.objects for delete to authenticated
  using (bucket_id = 'evidencias' and public.es_inspector());

-- 5. Registrar que el equipo llegó al Hub (versión mínima de la HU05)
create or replace function public.recibir_en_hub(p_pedido uuid)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido public.pedidos;
begin
  if not public.es_inspector() then raise exception 'NO_INSPECTOR'; end if;

  update public.pedidos set estado = 'recibido_en_hub'
    where id = p_pedido and estado = 'pago_en_custodia'
    returning * into v_pedido;
  if not found then raise exception 'ESTADO'; end if;
  return v_pedido;
end;
$$;

-- 6. Qué puntos se revisan según el tipo de equipo. Unos audífonos no
--    tienen pantalla; una consola necesita probar controles y lectora.
--    (Debe coincidir con lib/models/inspeccion.dart.)
create or replace function public.puntos_checklist(p_categoria text)
returns text[]
language sql immutable
as $$
  select case p_categoria
    when 'Laptop'   then array['encendido', 'pantalla', 'teclado', 'bateria', 'puertos', 'chasis']
    when 'Teléfono' then array['encendido', 'pantalla_tactil', 'bateria', 'camaras', 'sonido', 'botones_puertos', 'chasis']
    when 'Tablet'   then array['encendido', 'pantalla_tactil', 'bateria', 'camaras', 'botones_puertos', 'chasis']
    when 'Consola'  then array['encendido', 'video', 'controles', 'lectora', 'ventilacion', 'puertos', 'chasis']
    when 'Audio'    then array['encendido', 'sonido_lados', 'microfono', 'funciones', 'bateria', 'estructura']
    else                 array['encendido', 'funcion', 'puertos', 'chasis']
  end;
$$;

-- Puntos que se pueden marcar «No aplica» (no todos los equipos los tienen).
create or replace function public.punto_opcional(p_clave text)
returns boolean
language sql immutable
as $$ select p_clave in ('camaras', 'lectora', 'microfono'); $$;

-- 7. HU07: guardar el checklist completo
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
begin
  if not public.es_inspector() then raise exception 'NO_INSPECTOR'; end if;

  select * into v_pedido from public.pedidos where id = p_pedido for update;
  if not found then raise exception 'NO_EXISTE'; end if;
  if v_pedido.estado not in ('recibido_en_hub', 'en_diagnostico') then
    raise exception 'ESTADO';
  end if;

  select categoria into v_categoria from public.equipos where id = v_pedido.equipo_id;

  -- Todos los puntos de su tipo de equipo son obligatorios.
  foreach v_clave in array public.puntos_checklist(v_categoria)
  loop
    v_punto := p_puntos -> v_clave;
    if v_punto is null
       or coalesce(v_punto ->> 'resultado', '') not in ('ok', 'falla', 'no_aplica') then
      raise exception 'INCOMPLETO:%', v_clave;
    end if;
    if v_punto ->> 'resultado' = 'no_aplica' and not public.punto_opcional(v_clave) then
      raise exception 'NO_APLICA:%', v_clave;
    end if;
    -- Cada falla necesita una nota y al menos una foto de evidencia.
    if v_punto ->> 'resultado' = 'falla' then
      if char_length(trim(coalesce(v_punto ->> 'nota', ''))) < 10 then
        raise exception 'FALTA_NOTA:%', v_clave;
      end if;
      if jsonb_typeof(v_punto -> 'evidencias') is distinct from 'array'
         or jsonb_array_length(v_punto -> 'evidencias') < 1 then
        raise exception 'FALTA_EVIDENCIA:%', v_clave;
      end if;
    end if;
  end loop;

  insert into public.inspecciones (pedido_id, inspector_id, puntos, completa)
    values (p_pedido, auth.uid(), p_puntos, true)
  on conflict (pedido_id) do update
    set inspector_id = excluded.inspector_id,
        puntos = excluded.puntos,
        completa = true,
        actualizado_en = now()
  returning * into v_inspeccion;

  update public.pedidos set estado = 'en_diagnostico' where id = p_pedido;
  return v_inspeccion;
end;
$$;

revoke all on function public.recibir_en_hub(uuid) from public, anon;
revoke all on function public.guardar_inspeccion(uuid, jsonb) from public, anon;
grant execute on function public.recibir_en_hub(uuid) to authenticated;
grant execute on function public.guardar_inspeccion(uuid, jsonb) to authenticated;

-- 8. Para que una cuenta sea inspector, cambia el correo y ejecuta:
--    insert into public.inspectores (usuario_id)
--      select id from auth.users where email = 'inspector@gmail.com'
--    on conflict do nothing;
