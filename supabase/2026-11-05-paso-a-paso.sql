-- Paso a paso: mostrar en la comunidad cómo se logró una meta o un propósito, paso a paso.
-- Correr una vez en Supabase (SQL Editor). Mientras no se corra, la web y la app publican igual,
-- solo que sin el recorrido.
--   pasos = {"meta": "Correr mi primera media maratón", "pasos": [{"t": "Caminé 20 min diarios", "f": "2026-01", "d": "detalle"}]}
alter table public.posts add column if not exists pasos jsonb;
do $$ begin
  alter table public.posts add constraint posts_pasos_tamano check (pasos is null or pg_column_size(pasos) < 8000);
exception when duplicate_object then null; end $$;
