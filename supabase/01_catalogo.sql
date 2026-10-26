-- =====================================================================
-- ReUso Seguro · Catálogo en Supabase (tabla, fotos y permisos)
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas: no duplica nada.
-- =====================================================================

-- 1. Tabla de equipos publicados («entity» Equipo del diagrama de clases)
create table if not exists public.equipos (
  id               uuid primary key default gen_random_uuid(),
  vendedor_id      uuid references auth.users (id) on delete set null,
  vendedor_nombre  text not null,
  titulo           text not null check (char_length(titulo) between 3 and 80),
  descripcion      text not null,
  estado_declarado text not null,
  precio           numeric(10, 2) not null check (precio > 0),
  estado           text not null default 'disponible'
                   check (estado in ('disponible', 'reservado')),
  -- Rutas de las fotos dentro del almacén «equipos» (datos no estructurados)
  fotos            text[] not null default '{}',
  -- Ilustración de respaldo (solo para los equipos de demostración)
  ilustracion      text,
  es_demo          boolean not null default false,
  creado_en        timestamptz not null default now()
);

-- 2. Seguridad por fila (RLS)
alter table public.equipos enable row level security;

drop policy if exists "El catálogo es público" on public.equipos;
create policy "El catálogo es público"
  on public.equipos for select
  using (true);

-- Solo un usuario con sesión puede publicar, y solo a su nombre (HU11).
drop policy if exists "Cada vendedor publica lo suyo" on public.equipos;
create policy "Cada vendedor publica lo suyo"
  on public.equipos for insert to authenticated
  with check (auth.uid() = vendedor_id);
-- Nadie puede cambiar el estado desde el navegador: «reservado» lo pondrá
-- el servidor cuando se pague (regla de la arquitectura).

-- 3. Almacén de fotos
insert into storage.buckets (id, name, public)
values ('equipos', 'equipos', true)
on conflict (id) do nothing;

-- El almacén es público: cualquiera ve una foto si conoce su dirección.
-- No se crea un permiso de lectura (select) porque dejaría que cualquiera
-- liste todos los archivos del almacén (aviso de seguridad de Supabase).
drop policy if exists "Las fotos se ven públicamente" on storage.objects;

-- Cada usuario sube fotos solo dentro de su propia carpeta: <su id>/...
drop policy if exists "Cada usuario sube a su carpeta" on storage.objects;
create policy "Cada usuario sube a su carpeta"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'equipos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4. Equipos de demostración (los 8 del catálogo actual)
--    Se borran todos con:  delete from public.equipos where es_demo;
delete from public.equipos where es_demo;

insert into public.equipos
  (vendedor_nombre, titulo, descripcion, estado_declarado, precio, estado,
   fotos, ilustracion, es_demo, creado_en)
values
  ('Andrea Rivas', 'Laptop Lenovo ThinkPad T480',
   'Core i5 de 8va generación, 8 GB de RAM y SSD de 256 GB. Incluye cargador original.',
   'Usado, en buen estado. Batería con 2 horas de duración.', 180, 'disponible',
   '{demo/thinkpad-t480/1.jpg,demo/thinkpad-t480/2.jpg,demo/thinkpad-t480/3.jpg}',
   'assets/images/equipos/thinkpad.png', true, now() - interval '1 minute'),
  ('Luis Paredes', 'iPhone 11 de 64 GB',
   'Color blanco, liberado para cualquier operadora. Con forro.',
   'Usado, con detalles leves en el marco.', 210, 'disponible',
   '{demo/iphone-11/1.jpg,demo/iphone-11/2.jpg,demo/iphone-11/3.jpg}', 'assets/images/equipos/iphone.png', true, now() - interval '2 minutes'),
  ('Mariana Colmenares', 'iPad de 6ta generación',
   'Pantalla de 9,7 pulgadas, 32 GB, solo WiFi.',
   'Usado, pantalla sin rayones y marcas leves en el marco.', 150, 'reservado',
   '{demo/ipad-6/1.jpg,demo/ipad-6/2.jpg,demo/ipad-6/3.jpg}', 'assets/images/equipos/ipad.png', true, now() - interval '3 minutes'),
  ('Andrea Rivas', 'MacBook Air 2017',
   'Core i5, 8 GB de RAM y SSD de 128 GB. Teclado en inglés (distribución británica).',
   'Usado, con marcas de uso en la tapa.', 320, 'disponible',
   '{demo/macbook-air-2017/1.jpg,demo/macbook-air-2017/2.jpg,demo/macbook-air-2017/3.jpg}', 'assets/images/equipos/macbook.png', true, now() - interval '4 minutes'),
  ('José Graterol', 'Samsung Galaxy A52 5G',
   '128 GB de almacenamiento y 6 GB de RAM. Incluye caja, cargador, cable USB-C y audífonos.',
   'Usado, funciona todo.', 120, 'disponible',
   '{demo/galaxy-a52/1.jpg,demo/galaxy-a52/2.jpg,demo/galaxy-a52/3.jpg}', 'assets/images/equipos/galaxy.png', true, now() - interval '5 minutes'),
  ('Luis Paredes', 'PlayStation 4 Slim de 500 GB',
   'Incluye un control, cable de corriente, cable HDMI y cable USB para cargar el control.',
   'Usado, el control tiene desgaste en las palancas.', 160, 'disponible',
   '{demo/ps4-slim/1.jpg,demo/ps4-slim/2.jpg,demo/ps4-slim/3.jpg}', 'assets/images/equipos/ps4.png', true, now() - interval '6 minutes'),
  ('Mariana Colmenares', 'Laptop HP Pavilion 15',
   'Pantalla de 15,6 pulgadas, teclado numérico y parlantes B&O.',
   'Usado, en buen estado, con marcas leves en la tapa.', 240, 'reservado',
   '{demo/hp-pavilion-15/1.jpg,demo/hp-pavilion-15/2.jpg,demo/hp-pavilion-15/3.jpg}', 'assets/images/equipos/hp.png', true, now() - interval '7 minutes'),
  ('José Graterol', 'Audífonos Sony WH-CH710N',
   'Inalámbricos, con cancelación de ruido. Incluye caja, manuales y cable de audio de 3,5 mm.',
   'Usado, almohadillas en buen estado con arrugas leves de uso.', 45, 'disponible',
   '{demo/sony-wh-ch710n/1.jpg,demo/sony-wh-ch710n/2.jpg,demo/sony-wh-ch710n/3.jpg}', 'assets/images/equipos/audifonos.png', true, now() - interval '8 minutes');
