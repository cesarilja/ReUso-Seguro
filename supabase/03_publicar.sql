-- =====================================================================
-- ReUso Seguro · HU11 Publicar un equipo
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas.
--
-- Los datos obligatorios se revisan dos veces: en el formulario (para
-- explicarle al vendedor qué corregir) y aquí en la base de datos (para
-- que nadie pueda saltarse las reglas desde fuera de la app).
-- =====================================================================

-- 1. Nuevo dato: el tipo de equipo (servirá para filtrar el catálogo)
alter table public.equipos
  add column if not exists categoria text;

alter table public.equipos drop constraint if exists equipos_categoria_check;
alter table public.equipos add constraint equipos_categoria_check
  check (categoria is null or categoria in
    ('Laptop', 'Teléfono', 'Tablet', 'Consola', 'Audio', 'Otro'));

-- Los equipos de demostración también reciben su tipo.
update public.equipos set categoria = case
    when titulo ilike '%laptop%' or titulo ilike '%macbook%' then 'Laptop'
    when titulo ilike '%iphone%' or titulo ilike '%galaxy%'  then 'Teléfono'
    when titulo ilike '%ipad%'                               then 'Tablet'
    when titulo ilike '%playstation%'                        then 'Consola'
    when titulo ilike '%audífonos%'                          then 'Audio'
    else 'Otro' end
where es_demo and categoria is null;

-- 2. Regla para publicar: solo con sesión, a su propio nombre y con TODOS
--    los datos completos. Un equipo nuevo siempre entra como «disponible».
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
    -- Las fotos tienen que estar en la carpeta del propio vendedor.
    and not exists (
      select 1 from unnest(fotos) as ruta
      where split_part(ruta, '/', 1) <> auth.uid()::text
    )
  );

-- 3. Almacén de fotos: solo imágenes y como máximo 5 MB cada una.
update storage.buckets
  set file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
  where id = 'equipos';

-- Si la publicación falla a mitad de camino, la app borra las fotos que
-- alcanzó a subir. Para eso cada usuario puede borrar SOLO su carpeta.
drop policy if exists "Cada usuario borra en su carpeta" on storage.objects;
create policy "Cada usuario borra en su carpeta"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'equipos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
