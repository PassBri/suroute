-- SuRoute · Reportes de respuestas del coach de IA (política de IA generativa de Google Play)
-- Ejecutar en Supabase › SQL Editor. Se puede ejecutar más de una vez.

create table if not exists public.coach_reportes (
  id         uuid primary key default gen_random_uuid(),
  quien      uuid not null default public.yo() references public.profiles(id) on delete cascade,
  motivo     text not null check (motivo in ('ofensiva', 'peligrosa', 'equivocada', 'otra')),
  detalle    text not null default '' check (char_length(detalle) <= 1000),
  pregunta   text not null default '' check (char_length(pregunta) <= 2000),
  respuesta  text not null check (char_length(respuesta) <= 8000),
  tema       text not null default '' check (char_length(tema) <= 20),
  revisado   boolean not null default false,
  creado     timestamptz not null default now()
);
create index if not exists coach_reportes_creado on public.coach_reportes (creado desc);

alter table public.coach_reportes enable row level security;
drop policy if exists "reportar respuesta del coach" on public.coach_reportes;
create policy "reportar respuesta del coach" on public.coach_reportes for insert with check (quien = public.yo());
drop policy if exists "moderación ve reportes del coach" on public.coach_reportes;
create policy "moderación ve reportes del coach" on public.coach_reportes for select using (public.es_moderador());
drop policy if exists "moderación marca reportes del coach" on public.coach_reportes;
create policy "moderación marca reportes del coach" on public.coach_reportes for update using (public.es_moderador()) with check (public.es_moderador());
drop policy if exists "moderación borra reportes del coach" on public.coach_reportes;
create policy "moderación borra reportes del coach" on public.coach_reportes for delete using (public.es_moderador());
grant select, insert, update, delete on public.coach_reportes to authenticated;
