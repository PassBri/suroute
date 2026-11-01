-- Luces: la reacción de la comunidad (web/js/51-luces.js y la app, ui/components/LucesIconos.kt).
-- Reemplaza al impulso y a los climas de las publicaciones. Cada luz ES un impulso con su matiz:
-- vive en la misma tabla votes, en la columna luz, para que los milímetros de la expedición,
-- los avisos y «Para ti» sigan contando igual.
--   vela = te acompaño · fogata = me motivó · farol = me iluminó · estrella = te admiro · luna = te entiendo · sol = ¡celebremos!
-- Los impulsos que ya existían quedan como «sol». Los climas que la gente dejó en las publicaciones
-- pasan a la luz más parecida (la tabla post_climas se conserva, ya no se usa).
-- Se puede correr más de una vez.

alter table public.votes add column if not exists luz text not null default 'sol';
alter table public.votes drop constraint if exists votes_luz_valida;
alter table public.votes add constraint votes_luz_valida check (luz in ('vela', 'fogata', 'farol', 'estrella', 'luna', 'sol'));

-- Cambiar de luz (de vela a estrella, por ejemplo) es actualizar el propio voto
drop policy if exists "cambiar impulso" on public.votes;
create policy "cambiar impulso" on public.votes for update using (user_id = public.yo()) with check (user_id = public.yo());
-- Una cuenta suspendida tampoco puede cambiar su luz
drop trigger if exists sin_suspension_update on public.votes;
create trigger sin_suspension_update before update on public.votes for each row execute function public.no_suspendido();

-- El aviso dice qué luz te dieron («Diana te dio una estrella: Te admiro»)
create or replace function public.aviso_impulso() returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.notificar((select user_id from public.posts where id = new.post_id), new.user_id, 'IMPULSO', new.post_id, null, coalesce(new.luz, 'sol'));
  return new;
end $$;

-- Los climas de las publicaciones pasan a luces, sin enviar avisos viejos
do $$ begin
  if to_regclass('public.post_climas') is not null then
    alter table public.votes disable trigger aviso_impulso;
    insert into public.votes (post_id, user_id, luz, created_at)
    select c.post_id, c.user_id,
           case c.clima when 'sol' then 'sol' when 'cumbre' then 'sol' when 'tormenta' then 'fogata'
                        when 'niebla' then 'luna' when 'valle' then 'vela' else 'sol' end,
           c.created_at
      from public.post_climas c
    on conflict (post_id, user_id) do nothing;
    alter table public.votes enable trigger aviso_impulso;
  end if;
end $$;

-- Si alguien alcanzó a correr la primera versión (tabla post_luces), sus luces también pasan a votes
do $$ begin
  if to_regclass('public.post_luces') is not null then
    alter table public.votes disable trigger aviso_impulso;
    insert into public.votes (post_id, user_id, luz, created_at)
    select post_id, user_id, luz, created_at from public.post_luces
    on conflict (post_id, user_id) do update set luz = excluded.luz;
    alter table public.votes enable trigger aviso_impulso;
    drop table public.post_luces;
  end if;
end $$;
