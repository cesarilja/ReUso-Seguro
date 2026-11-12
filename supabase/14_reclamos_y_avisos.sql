-- =====================================================================
-- ReUso Seguro · HU05 Respaldo ante reclamos + HU10 Monitor de avisos
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas. Requiere los scripts 04 al 13.
--
-- HU05: al recibir un equipo en el Hub, el inspector DEBE subir de 2 a 6
--       fotos de cómo llegó. Esas fotos y su registro no se pueden borrar
--       ni cambiar (respaldo imparcial). El comprador confirma que recibió
--       su equipo y tiene 3 días para abrir un reclamo.
-- HU10: cada cambio de estado de un pedido crea un aviso para el comprador
--       y el vendedor. Se guarda cuándo lo vio cada uno, y el
--       administrador lo sigue en el «Monitor de avisos».
-- =====================================================================

-- ---------------------------------------------------------------------
-- HU05 · 1. Recepción en el Hub con fotos (inmutable)
-- ---------------------------------------------------------------------
create table if not exists public.recepciones (
  pedido_id    uuid primary key references public.pedidos (id) on delete cascade,
  inspector_id uuid not null references auth.users (id),
  fotos        text[] not null check (array_length(fotos, 1) between 2 and 6),
  nota         text not null default '',
  creado_en    timestamptz not null default now()
);
alter table public.recepciones enable row level security;
grant select on public.recepciones to authenticated;

drop policy if exists "Ven la recepción el Hub, el comprador y el vendedor" on public.recepciones;
create policy "Ven la recepción el Hub, el comprador y el vendedor"
  on public.recepciones for select to authenticated
  using (
    public.es_inspector() or public.es_admin()
    or exists (
      select 1 from public.pedidos p join public.equipos e on e.id = p.equipo_id
      where p.id = pedido_id and (p.comprador_id = auth.uid() or e.vendedor_id = auth.uid()))
  );
-- Sin insert/update/delete: solo recibir_en_hub escribe.

-- Nadie puede cambiar ni borrar una recepción (ni siquiera desde el servidor).
create or replace function public.proteger_recepcion()
returns trigger
language plpgsql
as $$
begin
  raise exception 'RECEPCION_INMUTABLE';
end;
$$;

drop trigger if exists proteger_recepcion on public.recepciones;
create trigger proteger_recepcion
  before update or delete on public.recepciones
  for each row execute function public.proteger_recepcion();

-- Las fotos de recepción tampoco se pueden borrar del almacén.
-- (No hay permiso de «update», así que tampoco se pueden reemplazar.)
drop policy if exists "El inspector borra evidencias" on storage.objects;
create policy "El inspector borra evidencias"
  on storage.objects for delete to authenticated
  using (bucket_id = 'evidencias' and public.es_inspector()
         and name not like '%/recepcion-%');

-- HU05 · 2. Registrar la llegada: ahora exige de 2 a 6 fotos.
drop function if exists public.recibir_en_hub(uuid);
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

  update public.pedidos set estado = 'recibido_en_hub'
    where id = p_pedido and estado = 'pago_en_custodia'
    returning * into v_pedido;
  if not found then raise exception 'ESTADO'; end if;

  insert into public.recepciones (pedido_id, inspector_id, fotos, nota)
    values (p_pedido, auth.uid(), p_fotos, trim(coalesce(p_nota, '')));
  return v_pedido;
end;
$$;
revoke all on function public.recibir_en_hub(uuid, text[], text) from public, anon;
grant execute on function public.recibir_en_hub(uuid, text[], text) to authenticated;

-- ---------------------------------------------------------------------
-- HU05 · 3. El comprador confirma que recibió el equipo
-- ---------------------------------------------------------------------
alter table public.pedidos add column if not exists recibido_comprador_en timestamptz;

create or replace function public.confirmar_recibido(p_pedido uuid)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido public.pedidos;
begin
  if auth.uid() is null then raise exception 'SIN_SESION'; end if;
  update public.pedidos
    set recibido_comprador_en = coalesce(recibido_comprador_en, now())
    where id = p_pedido and comprador_id = auth.uid()
      and estado in ('pago_liberado', 'en_camino')
    returning * into v_pedido;
  if not found then raise exception 'ESTADO'; end if;
  return v_pedido;
end;
$$;
revoke all on function public.confirmar_recibido(uuid) from public, anon;
grant execute on function public.confirmar_recibido(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- HU05 · 4. Reclamos (plazo de 3 días desde que lo recibió)
-- ---------------------------------------------------------------------
create table if not exists public.reclamos (
  id           bigint generated always as identity primary key,
  pedido_id    uuid not null unique references public.pedidos (id) on delete cascade,
  comprador_id uuid not null references auth.users (id),
  descripcion  text not null check (char_length(descripcion) >= 20),
  estado       text not null default 'abierto' check (estado in ('abierto', 'resuelto')),
  creado_en    timestamptz not null default now()
);
alter table public.reclamos enable row level security;
grant select on public.reclamos to authenticated;

drop policy if exists "Ven el reclamo el comprador, el vendedor y el Hub" on public.reclamos;
create policy "Ven el reclamo el comprador, el vendedor y el Hub"
  on public.reclamos for select to authenticated
  using (
    public.es_inspector() or public.es_admin()
    or exists (
      select 1 from public.pedidos p join public.equipos e on e.id = p.equipo_id
      where p.id = pedido_id and (p.comprador_id = auth.uid() or e.vendedor_id = auth.uid()))
  );

create or replace function public.plazo_reclamo_dias()
returns int language sql immutable as $$ select 3 $$;

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
  if now() > v_pedido.recibido_comprador_en + make_interval(days => public.plazo_reclamo_dias()) then
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
-- HU10 · 5. Avisos de cada cambio de estado
-- ---------------------------------------------------------------------
create table if not exists public.avisos (
  id                 bigint generated always as identity primary key,
  pedido_id          uuid not null references public.pedidos (id) on delete cascade,
  estado             text not null,
  mensaje_comprador  text not null,
  mensaje_vendedor   text not null,
  creado_en          timestamptz not null default now(),
  comprador_visto_en timestamptz,
  vendedor_visto_en  timestamptz
);
create index if not exists avisos_pedido on public.avisos (pedido_id);
alter table public.avisos enable row level security;
grant select on public.avisos to authenticated;

drop policy if exists "Ven el aviso el comprador, el vendedor y el administrador" on public.avisos;
create policy "Ven el aviso el comprador, el vendedor y el administrador"
  on public.avisos for select to authenticated
  using (
    public.es_admin()
    or exists (
      select 1 from public.pedidos p join public.equipos e on e.id = p.equipo_id
      where p.id = pedido_id and (p.comprador_id = auth.uid() or e.vendedor_id = auth.uid()))
  );

create or replace function public.crear_aviso_de_estado()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_titulo text;
  v_monto  text;
  v_c      text;
  v_v      text;
begin
  if new.estado is not distinct from old.estado then return new; end if;
  select titulo into v_titulo from public.equipos where id = new.equipo_id;
  v_titulo := '«' || coalesce(v_titulo, 'tu equipo') || '»';

  case new.estado
    when 'pago_en_custodia' then
      v_c := 'Tu pago de ' || v_titulo || ' quedó en custodia.';
      v_v := 'Te compraron ' || v_titulo || '. El pago está en custodia: ya puedes llevarlo al Hub.';
    when 'recibido_en_hub' then
      v_c := 'Tu equipo ' || v_titulo || ' pasó a: Recibido en el Hub.';
      v_v := 'El Hub recibió ' || v_titulo || ' y guardó las fotos de cómo llegó.';
    when 'en_diagnostico' then
      v_c := 'Tu equipo ' || v_titulo || ' pasó a: En diagnóstico.';
      v_v := 'El inspector está revisando ' || v_titulo || '.';
    when 'pago_liberado' then
      v_monto := '$' || replace(to_char(coalesce(new.monto_vendedor, 0), 'FM999999990.00'), '.', ',');
      v_c := 'Tu equipo ' || v_titulo || ' pasó la inspección. Te lo enviaremos.';
      v_v := 'Te liberamos el pago de ' || v_titulo || ': recibes ' || v_monto || '.';
    when 'liberacion_pendiente' then
      v_c := 'Tu equipo ' || v_titulo || ' pasó la inspección. Te lo enviaremos.';
      v_v := 'No pudimos transferirte el pago de ' || v_titulo || '. Revisa «Mis ventas».';
    when 'reembolsado' then
      v_monto := '$' || replace(to_char(coalesce(new.monto_reembolsado, new.monto), 'FM999999990.00'), '.', ',');
      v_c := v_titulo || ' no pasó la inspección: te devolvimos ' || v_monto || ' (el 100 %).';
      v_v := v_titulo || ' no pasó la inspección. El comprador recibió su reembolso.';
    else
      -- «aprobado» y «rechazado» duran un instante (pasan solos a liberado
      -- o reembolsado); «cancelado» no necesita aviso.
      return new;
  end case;

  insert into public.avisos (pedido_id, estado, mensaje_comprador, mensaje_vendedor)
    values (new.id, new.estado, v_c, v_v);
  return new;
end;
$$;
revoke all on function public.crear_aviso_de_estado() from public, anon, authenticated;

drop trigger if exists crear_aviso_de_estado on public.pedidos;
create trigger crear_aviso_de_estado
  after update of estado on public.pedidos
  for each row execute function public.crear_aviso_de_estado();

-- HU10 · 6. Marcar avisos como vistos (cada uno marca lo suyo).
create or replace function public.marcar_avisos_vistos(p_avisos bigint[])
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_usuario uuid := auth.uid();
  v_c int;
  v_v int;
begin
  if v_usuario is null then raise exception 'SIN_SESION'; end if;

  update public.avisos a set comprador_visto_en = now()
    from public.pedidos p
    where a.id = any (p_avisos) and p.id = a.pedido_id
      and p.comprador_id = v_usuario and a.comprador_visto_en is null;
  get diagnostics v_c = row_count;

  update public.avisos a set vendedor_visto_en = now()
    from public.pedidos p join public.equipos e on e.id = p.equipo_id
    where a.id = any (p_avisos) and p.id = a.pedido_id
      and e.vendedor_id = v_usuario and a.vendedor_visto_en is null;
  get diagnostics v_v = row_count;

  return v_c + v_v;
end;
$$;
revoke all on function public.marcar_avisos_vistos(bigint[]) from public, anon;
grant execute on function public.marcar_avisos_vistos(bigint[]) to authenticated;

-- 7. Tiempo real para las tablas nuevas.
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['avisos', 'recepciones', 'reclamos']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', v_tabla);
    exception when duplicate_object then
      null;
    end;
  end loop;
end;
$$;
