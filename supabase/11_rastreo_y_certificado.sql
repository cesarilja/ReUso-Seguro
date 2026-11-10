-- =====================================================================
-- ReUso Seguro · HU02 Rastreo del estado + HU03 Certificado técnico
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas. Requiere los scripts 04 al 10.
--
-- HU02: el servidor anota la fecha y hora en que el pedido entra a cada
--       fase (recibido en el Hub, en diagnóstico). Las demás fechas ya
--       existían: pagado_en, la del dictamen, liberado_en y reembolsado_en.
-- HU03: el dictamen guarda el nombre del inspector que lo firmó, para
--       mostrarlo en el certificado. El comprador no puede leer las
--       cuentas de usuario, por eso se copia aquí.
--       Quién puede ver el certificado ya lo controlan las reglas RLS de
--       06_dictamen.sql: solo el comprador, el vendedor y los inspectores.
-- =====================================================================

-- 1. HU02: fecha de cada fase
alter table public.pedidos add column if not exists recibido_en    timestamptz;
alter table public.pedidos add column if not exists diagnostico_en timestamptz;

create or replace function public.anotar_fase_del_pedido()
returns trigger
language plpgsql
as $$
begin
  if new.estado is distinct from old.estado then
    if new.estado = 'recibido_en_hub' then
      new.recibido_en := coalesce(new.recibido_en, now());
    elsif new.estado = 'en_diagnostico' then
      new.diagnostico_en := coalesce(new.diagnostico_en, now());
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists anotar_fase on public.pedidos;
create trigger anotar_fase
  before update of estado on public.pedidos
  for each row execute function public.anotar_fase_del_pedido();

-- Pedidos viejos: el diagnóstico se toma de cuando se guardó el checklist.
update public.pedidos p
  set diagnostico_en = i.actualizado_en
  from public.inspecciones i
  where i.pedido_id = p.id and p.diagnostico_en is null;

-- 2. HU03: nombre del inspector en el dictamen
alter table public.dictamenes add column if not exists inspector_nombre text;

create or replace function public.firmar_dictamen()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  select coalesce(nullif(trim(u.raw_user_meta_data ->> 'nombre'), ''),
                  'Inspector técnico del Hub')
    into new.inspector_nombre
    from auth.users u
    where u.id = new.inspector_id;
  new.inspector_nombre := coalesce(new.inspector_nombre, 'Inspector técnico del Hub');
  return new;
end;
$$;
revoke all on function public.firmar_dictamen() from public, anon, authenticated;

drop trigger if exists firmar_dictamen on public.dictamenes;
create trigger firmar_dictamen
  before insert on public.dictamenes
  for each row execute function public.firmar_dictamen();

-- Dictámenes viejos
update public.dictamenes d
  set inspector_nombre = coalesce(nullif(trim(u.raw_user_meta_data ->> 'nombre'), ''),
                                  'Inspector técnico del Hub')
  from auth.users u
  where u.id = d.inspector_id and d.inspector_nombre is null;
