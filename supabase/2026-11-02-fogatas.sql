-- SuRoute · Fogatas en vivo (2026-11-02)
--
-- Una fogata es una transmisión en vivo con intención: quien la enciende dice el tema y el eje,
-- quienes miran reaccionan con las luces y, al salir, escriben qué se llevan para su paso de mañana.
-- El video viaja por LiveKit; aquí solo vive el registro de cada fogata y lo que cada persona se llevó.
-- Las escrituras de fogatas pasan por la función "fogata" (supabase/functions/fogata), que también
-- entrega el permiso de LiveKit. Por ahora encienden fogatas los moderadores y los coaches verificados.
--
-- Ejecutar una vez en Supabase › SQL Editor (se puede repetir sin problema).

create table if not exists public.fogatas (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  titulo      text not null check (char_length(titulo) between 3 and 90),
  eje         text check (eje in ('VOL','MAE','VOZ','VAL','EVO','TRA','CAM')),
  estado      text not null default 'EN_VIVO' check (estado in ('EN_VIVO','TERMINADA','CORTADA')),
  sala        text not null unique default ('fogata-' || replace(gen_random_uuid()::text, '-', '')),
  empezo_at   timestamptz not null default now(),
  latido_at   timestamptz not null default now(),   -- quien transmite avisa cada minuto que sigue ahí
  termino_at  timestamptz,
  pico        int not null default 0,               -- cuántas personas hubo al tiempo, como máximo
  created_at  timestamptz not null default now()
);
create index if not exists fogatas_vivas on public.fogatas (estado, latido_at desc);
alter table public.fogatas enable row level security;

drop policy if exists "ver fogatas" on public.fogatas;
create policy "ver fogatas" on public.fogatas for select
  using (public.yo() is not null and (estado <> 'CORTADA' or user_id = public.yo() or public.es_moderador()));
-- Sin políticas de escritura: encender, apagar y cortar pasan por la función "fogata".

-- Lo que cada persona se lleva de una fogata para su paso de mañana.
-- Lo ve quien lo escribió y quien encendió la fogata (así sabe qué dejó en su gente).
create table if not exists public.fogata_llevo (
  fogata_id  uuid not null references public.fogatas(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade default public.yo(),
  texto      text not null check (char_length(texto) between 1 and 280),
  created_at timestamptz not null default now(),
  primary key (fogata_id, user_id)
);
alter table public.fogata_llevo enable row level security;
drop policy if exists "ver lo que me llevo" on public.fogata_llevo;
create policy "ver lo que me llevo" on public.fogata_llevo for select
  using (user_id = public.yo() or exists (select 1 from public.fogatas f where f.id = fogata_id and f.user_id = public.yo()));
drop policy if exists "llevarme algo" on public.fogata_llevo;
create policy "llevarme algo" on public.fogata_llevo for insert with check (user_id = public.yo());
drop policy if exists "cambiar lo que me llevo" on public.fogata_llevo;
create policy "cambiar lo que me llevo" on public.fogata_llevo for update using (user_id = public.yo()) with check (user_id = public.yo());
do $$ begin
  if exists (select 1 from pg_proc where proname = 'no_suspendido') then
    drop trigger if exists sin_suspension on public.fogata_llevo;
    create trigger sin_suspension before insert on public.fogata_llevo for each row execute function public.no_suspendido();
  end if;
end $$;

-- ¿Puede esta cuenta encender una fogata? Moderadores y coaches verificados, sin suspensión vigente.
create or replace function public.puede_encender(p_usuario uuid default null) returns boolean
language sql stable security definer set search_path = public as $$
  select (exists (select 1 from public.moderadores m where m.user_id = coalesce(p_usuario, public.yo()))
       or exists (select 1 from public.coaches c where c.user_id = coalesce(p_usuario, public.yo()) and c.verificado and c.activo))
     and not exists (select 1 from public.suspensiones s where s.user_id = coalesce(p_usuario, public.yo()) and s.hasta > now())
$$;
grant execute on function public.puede_encender(uuid) to authenticated;

-- Al encender una fogata, quienes siguen a esa persona reciben un aviso.
create or replace function public.aviso_fogata() returns trigger
language plpgsql security definer set search_path = public as $$
declare quien text;
begin
  select coalesce(nullif(p.nombre, ''), p.username) into quien from public.profiles p where p.id = new.user_id;
  insert into public.notificaciones (user_id, actor_id, tipo, texto)
    select f.follower_id, new.user_id, 'SISTEMA', coalesce(quien, 'Alguien') || ' encendió una fogata en vivo: «' || new.titulo || '»'
    from public.follows f where f.followed_id = new.user_id;
  return new;
end $$;
drop trigger if exists aviso_fogata on public.fogatas;
create trigger aviso_fogata after insert on public.fogatas for each row execute function public.aviso_fogata();
