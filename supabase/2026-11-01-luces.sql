-- Luces: la reacción de la comunidad con cinco luces (web/js/51-luces.js y la app).
-- Una persona deja una sola luz por publicación: vela (te acompaño), farol (me iluminó),
-- estrella (te admiro), luna (te entiendo) o sol (¡celebremos!). Convive con el impulso y los climas.
create table if not exists public.post_luces (
  post_id    uuid not null references public.posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  luz        text not null check (luz in ('vela', 'farol', 'estrella', 'luna', 'sol')),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists post_luces_post on public.post_luces(post_id);
alter table public.post_luces enable row level security;

drop policy if exists "ver luces" on public.post_luces;
create policy "ver luces" on public.post_luces for select using (
  exists (select 1 from public.posts p where p.id = post_id and public.puede_ver(p)));
drop policy if exists "dar luz" on public.post_luces;
create policy "dar luz" on public.post_luces for insert with check (user_id = public.yo());
drop policy if exists "cambiar luz" on public.post_luces;
create policy "cambiar luz" on public.post_luces for update using (user_id = public.yo()) with check (user_id = public.yo());
drop policy if exists "quitar luz" on public.post_luces;
create policy "quitar luz" on public.post_luces for delete using (user_id = public.yo());
