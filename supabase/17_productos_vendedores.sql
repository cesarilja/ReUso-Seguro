-- =====================================================================
-- ReUso Seguro · 3 nuevos productos (3/3 fotos cada uno) con vendedores reales
--
-- ANTES DE EJECUTAR:
--   1. Asegúrate de que los 3 correos existan en Supabase → Authentication → Users:
--        · squijada@gmail.com  (Sebastian Quijada)
--        · marcelop@gmail.com  (Marcelo Piñeiro)
--        · lgomez@gmail.com    (Lucas Gomez)
--   2. Sube las 3 carpetas que están dentro de:
--        fotos_nuevas_para_subir/demo/
--      al almacén (Storage) «equipos», dentro de la carpeta «demo/».
--
-- Luego pega este script en Supabase → SQL Editor → New query → Run.
-- Se puede volver a ejecutar sin problemas: no duplica productos.
-- =====================================================================

do $$
declare
  v_sebastian uuid;
  v_marcelo   uuid;
  v_lucas     uuid;
begin
  select id into v_sebastian from auth.users where lower(email) = 'squijada@gmail.com' limit 1;
  select id into v_marcelo   from auth.users where lower(email) = 'marcelop@gmail.com' limit 1;
  select id into v_lucas     from auth.users where lower(email) = 'lgomez@gmail.com' limit 1;

  if v_sebastian is null then
    raise exception 'No se encontró la cuenta squijada@gmail.com en auth.users. Créala primero en Authentication → Users.';
  end if;
  if v_marcelo is null then
    raise exception 'No se encontró la cuenta marcelop@gmail.com en auth.users. Créala primero en Authentication → Users.';
  end if;
  if v_lucas is null then
    raise exception 'No se encontró la cuenta lgomez@gmail.com en auth.users. Créala primero en Authentication → Users.';
  end if;

  -- 1. Sebastian Quijada — Laptop Dell XPS 13 9370 (Detallada · Express)
  insert into public.equipos (
    vendedor_id, vendedor_nombre, titulo, descripcion, estado_declarado,
    precio, estado, categoria, plan_inspeccion, express, autoevaluacion,
    fotos, es_demo, creado_en
  )
  select
    v_sebastian,
    'Sebastian Quijada',
    'Laptop Dell XPS 13 9370',
    'Intel Core i7 de 8va generación, 16 GB de RAM y SSD NVMe de 512 GB. Pantalla Full HD de 13,3 pulgadas sin bordes. Incluye cargador USB-C original y funda de neopreno.',
    'Usado, muy bien cuidada. Batería dura unas 4 horas y tiene un rayón mínimo en la esquina.',
    420,
    'disponible',
    'Laptop',
    'detallada',
    true,
    '{"encendido": 4, "pantalla": 4, "teclado": 4, "bateria": 3, "puertos": 4, "chasis": 3}'::jsonb,
    array['demo/dell-xps-13/1.jpg', 'demo/dell-xps-13/2.jpg', 'demo/dell-xps-13/3.jpg'],
    false,
    now() - interval '5 minutes'
  where not exists (
    select 1 from public.equipos
    where vendedor_id = v_sebastian and titulo = 'Laptop Dell XPS 13 9370'
  );

  -- 2. Marcelo Piñeiro — iPhone 13 de 128 GB Azul Medianoche (Detallada · Express)
  insert into public.equipos (
    vendedor_id, vendedor_nombre, titulo, descripcion, estado_declarado,
    precio, estado, categoria, plan_inspeccion, express, autoevaluacion,
    fotos, es_demo, creado_en
  )
  select
    v_marcelo,
    'Marcelo Piñeiro',
    'iPhone 13 de 128 GB Azul Medianoche',
    'Liberado para todas las operadoras, 128 GB de almacenamiento, condición de batería en 87 %. Face ID y cámaras al 100 %. Incluye caja original, cable Lightning y dos forros.',
    'Usado, pantalla impecable con protector. Pequeño desgaste de pintura alrededor de los bordes de la cámara.',
    390,
    'disponible',
    'Teléfono',
    'detallada',
    true,
    '{"encendido": 4, "pantalla_tactil": 4, "bateria": 3, "camaras": 4, "sonido": 4, "botones_puertos": 4, "chasis": 3}'::jsonb,
    array['demo/iphone-13-128/1.jpg', 'demo/iphone-13-128/2.jpg', 'demo/iphone-13-128/3.jpg'],
    false,
    now() - interval '12 minutes'
  where not exists (
    select 1 from public.equipos
    where vendedor_id = v_marcelo and titulo = 'iPhone 13 de 128 GB Azul Medianoche'
  );

  -- 3. Lucas Gomez — Nintendo Switch OLED Blanca 64 GB (Detallada)
  insert into public.equipos (
    vendedor_id, vendedor_nombre, titulo, descripcion, estado_declarado,
    precio, estado, categoria, plan_inspeccion, express, autoevaluacion,
    fotos, es_demo, creado_en
  )
  select
    v_lucas,
    'Lucas Gomez',
    'Nintendo Switch OLED Blanca 64 GB',
    'Consola completa con dock blanco, par de Joy-Con blancos sin drift, cargador original, cable HDMI y estuche rígido de viaje. Pantalla con vidrio templado desde el primer día.',
    'Usado, excelente estado general. El dock tiene marcas leves de polvo y uso normal.',
    260,
    'disponible',
    'Consola',
    'detallada',
    false,
    '{"encendido": 4, "video": 4, "controles": 4, "ventilacion": 4, "puertos": 4, "chasis": 3}'::jsonb,
    array['demo/nintendo-switch-oled/1.jpg', 'demo/nintendo-switch-oled/2.jpg', 'demo/nintendo-switch-oled/3.jpg'],
    false,
    now() - interval '20 minutes'
  where not exists (
    select 1 from public.equipos
    where vendedor_id = v_lucas and titulo = 'Nintendo Switch OLED Blanca 64 GB'
  );
end $$;

-- Comprobación: ver los 3 equipos nuevos recién insertados.
select vendedor_nombre, titulo, categoria, plan_inspeccion, express, precio, cardinality(fotos) as fotos
from public.equipos
where es_demo = false
order by creado_en desc;
