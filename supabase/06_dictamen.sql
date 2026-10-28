-- =====================================================================
-- ReUso Seguro · HU08 Dictamen técnico
-- Ejecutar UNA vez en Supabase: SQL Editor → New query → pegar → Run.
-- Se puede volver a ejecutar sin problemas.
--
-- Después del checklist (HU07), el inspector técnico aprueba o rechaza el
-- equipo. El dictamen es definitivo y lo ven el comprador y el vendedor.
-- =====================================================================

-- 1. Dictámenes: uno por pedido («entity» Dictamen)
create table if not exists public.dictamenes (
  pedido_id    uuid primary key references public.pedidos (id) on delete cascade,
  inspector_id uuid not null references auth.users (id),
  resultado    text not null check (resultado in ('aprobado', 'rechazado')),
  -- Motivo del rechazo, o justificación si se aprueba un equipo con fallas.
  motivo       text not null default '',
  creado_en    timestamptz not null default now()
);
alter table public.dictamenes enable row level security;

-- Lo ven el inspector, el comprador del pedido y el vendedor del equipo.
drop policy if exists "Ven el dictamen el inspector, el comprador y el vendedor" on public.dictamenes;
create policy "Ven el dictamen el inspector, el comprador y el vendedor"
  on public.dictamenes for select to authenticated
  using (
    public.es_inspector()
    or exists (
      select 1 from public.pedidos p
      join public.equipos e on e.id = p.equipo_id
      where p.id = pedido_id
        and (p.comprador_id = auth.uid() or e.vendedor_id = auth.uid())
    )
  );

-- Transparencia: el comprador y el vendedor también ven el checklist.
drop policy if exists "El comprador y el vendedor ven el checklist" on public.inspecciones;
create policy "El comprador y el vendedor ven el checklist"
  on public.inspecciones for select to authenticated
  using (exists (
    select 1 from public.pedidos p
    join public.equipos e on e.id = p.equipo_id
    where p.id = pedido_id
      and (p.comprador_id = auth.uid() or e.vendedor_id = auth.uid())
  ));

-- 2. HU08: emitir el dictamen
create or replace function public.emitir_dictamen(
  p_pedido    uuid,
  p_resultado text,
  p_motivo    text default ''
)
returns public.dictamenes
language plpgsql security definer set search_path = public
as $$
declare
  v_pedido     public.pedidos;
  v_inspeccion public.inspecciones;
  v_dictamen   public.dictamenes;
  v_fallas     int;
  v_motivo     text := trim(coalesce(p_motivo, ''));
begin
  if not public.es_inspector() then raise exception 'NO_INSPECTOR'; end if;
  if p_resultado not in ('aprobado', 'rechazado') then raise exception 'RESULTADO'; end if;

  select * into v_pedido from public.pedidos where id = p_pedido for update;
  if not found then raise exception 'NO_EXISTE'; end if;
  if exists (select 1 from public.dictamenes where pedido_id = p_pedido) then
    raise exception 'YA_EMITIDO';
  end if;
  if v_pedido.estado <> 'en_diagnostico' then raise exception 'ESTADO'; end if;

  -- Sin checklist completo no hay dictamen.
  select * into v_inspeccion from public.inspecciones where pedido_id = p_pedido;
  if not found or not v_inspeccion.completa then raise exception 'SIN_CHECKLIST'; end if;

  select count(*) into v_fallas
    from jsonb_each(v_inspeccion.puntos) as punto(clave, valor)
    where valor ->> 'resultado' = 'falla';

  if p_resultado = 'rechazado' and char_length(v_motivo) < 15 then
    raise exception 'FALTA_MOTIVO';
  end if;
  -- Aprobar un equipo con fallas se puede (por ejemplo, un rayón que el
  -- vendedor declaró), pero hay que explicar por qué.
  if p_resultado = 'aprobado' and v_fallas > 0 and char_length(v_motivo) < 15 then
    raise exception 'FALTA_JUSTIFICACION';
  end if;

  -- Primero cambia el pedido y después se guarda el dictamen (así la
  -- liberación automática de la HU06 puede actuar sobre el estado final).
  update public.pedidos set estado = p_resultado where id = p_pedido;

  insert into public.dictamenes (pedido_id, inspector_id, resultado, motivo)
    values (p_pedido, auth.uid(), p_resultado, v_motivo)
    returning * into v_dictamen;
  return v_dictamen;
end;
$$;

revoke all on function public.emitir_dictamen(uuid, text, text) from public, anon;
grant execute on function public.emitir_dictamen(uuid, text, text) to authenticated;
