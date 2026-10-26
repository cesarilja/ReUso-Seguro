-- =====================================================================
-- ReUso Seguro · Fotos reales de los 7 equipos de demostración
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Antes, subir las fotos al almacén «equipos» en demo/<carpeta>/1.jpg...
-- Las descripciones se corrigieron para que coincidan con las fotos.
-- =====================================================================

update public.equipos set
  fotos = '{demo/iphone-11/1.jpg,demo/iphone-11/2.jpg,demo/iphone-11/3.jpg}',
  descripcion = 'Color blanco, liberado para cualquier operadora. Con forro.'
where titulo = 'iPhone 11 de 64 GB' and es_demo;

update public.equipos set
  fotos = '{demo/ipad-6/1.jpg,demo/ipad-6/2.jpg,demo/ipad-6/3.jpg}',
  estado_declarado = 'Usado, pantalla sin rayones y marcas leves en el marco.'
where titulo = 'iPad de 6ta generación' and es_demo;

update public.equipos set
  fotos = '{demo/macbook-air-2017/1.jpg,demo/macbook-air-2017/2.jpg,demo/macbook-air-2017/3.jpg}',
  descripcion = 'Core i5, 8 GB de RAM y SSD de 128 GB. Teclado en inglés (distribución británica).'
where titulo = 'MacBook Air 2017' and es_demo;

update public.equipos set
  fotos = '{demo/galaxy-a52/1.jpg,demo/galaxy-a52/2.jpg,demo/galaxy-a52/3.jpg}',
  titulo = 'Samsung Galaxy A52 5G',
  descripcion = '128 GB de almacenamiento y 6 GB de RAM. Incluye caja, cargador, cable USB-C y audífonos.'
where titulo in ('Samsung Galaxy A52', 'Samsung Galaxy A52 5G') and es_demo;

update public.equipos set
  fotos = '{demo/ps4-slim/1.jpg,demo/ps4-slim/2.jpg,demo/ps4-slim/3.jpg}',
  descripcion = 'Incluye un control, cable de corriente, cable HDMI y cable USB para cargar el control.'
where titulo = 'PlayStation 4 Slim de 500 GB' and es_demo;

update public.equipos set
  fotos = '{demo/hp-pavilion-15/1.jpg,demo/hp-pavilion-15/2.jpg,demo/hp-pavilion-15/3.jpg}',
  descripcion = 'Pantalla de 15,6 pulgadas, teclado numérico y parlantes B&O.',
  estado_declarado = 'Usado, en buen estado, con marcas leves en la tapa.'
where titulo = 'Laptop HP Pavilion 15' and es_demo;

update public.equipos set
  fotos = '{demo/sony-wh-ch710n/1.jpg,demo/sony-wh-ch710n/2.jpg,demo/sony-wh-ch710n/3.jpg}',
  descripcion = 'Inalámbricos, con cancelación de ruido. Incluye caja, manuales y cable de audio de 3,5 mm.',
  estado_declarado = 'Usado, almohadillas en buen estado con arrugas leves de uso.'
where titulo = 'Audífonos Sony WH-CH710N' and es_demo;

-- Comprobación: los 8 equipos deben tener 3 fotos.
select titulo, cardinality(fotos) as fotos from public.equipos where es_demo order by creado_en desc;
