-- =====================================================================
-- ReUso Seguro · Verificación de identidad del vendedor (cédula)
-- Ejecutar UNA vez en Supabase: SQL Editor -> New query -> pegar -> Run.
-- =====================================================================

create table if not exists public.verificaciones_vendedor (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  cedula_numero text not null,
  foto_cedula_ruta text not null,
  verificado_en timestamptz not null default now()
);

alter table public.verificaciones_vendedor enable row level security;

drop policy if exists "verificacion_propia_select" on public.verificaciones_vendedor;
create policy "verificacion_propia_select"
  on public.verificaciones_vendedor
  for select
  to authenticated
  using (auth.uid() = usuario_id);

drop policy if exists "verificacion_propia_insert" on public.verificaciones_vendedor;
create policy "verificacion_propia_insert"
  on public.verificaciones_vendedor
  for insert
  to authenticated
  with check (auth.uid() = usuario_id);

drop policy if exists "verificacion_propia_update" on public.verificaciones_vendedor;
create policy "verificacion_propia_update"
  on public.verificaciones_vendedor
  for update
  to authenticated
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);
