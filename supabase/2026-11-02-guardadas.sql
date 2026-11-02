-- SuRoute · La mochila en la cuenta (2026-11-02)
--
-- Las publicaciones que una persona guarda («Me lo llevo › Guardar en mi mochila») viven en su cuenta:
-- las ve igual en el teléfono y en la web. Antes quedaban solo en cada teléfono o navegador; la primera
-- vez que se abre la mochila, lo guardado en cada lado se sube solo.
--
-- Ejecutar una vez en Supabase › SQL Editor (se puede repetir sin problema).

create table if not exists public.guardadas (
  user_id    uuid not null references public.profiles(id) on delete cascade default public.yo(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create index if not exists guardadas_mias on public.guardadas (user_id, created_at desc);
alter table public.guardadas enable row level security;

drop policy if exists "ver mi mochila" on public.guardadas;
create policy "ver mi mochila" on public.guardadas for select using (user_id = public.yo());
drop policy if exists "guardar en mi mochila" on public.guardadas;
create policy "guardar en mi mochila" on public.guardadas for insert with check (user_id = public.yo());
drop policy if exists "cambiar mi mochila" on public.guardadas;
create policy "cambiar mi mochila" on public.guardadas for update using (user_id = public.yo()) with check (user_id = public.yo());
drop policy if exists "sacar de mi mochila" on public.guardadas;
create policy "sacar de mi mochila" on public.guardadas for delete using (user_id = public.yo());
