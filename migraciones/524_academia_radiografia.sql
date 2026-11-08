-- 524 · Academia · Radiografía de cada atleta
-- ---------------------------------------------------------------------------
-- Andrés (8-nov-2026): «un apartado en Academia dentro de la app, que solo pueda
-- ver yo». Valoración privada de cada atleta: lo bueno, a mejorar, técnica, qué
-- haría y a qué estar atento. El texto vive SOLO en esta tabla (el repo es público).
--
-- Lectura: solo el entrenador del grupo del atleta. Sin política para admin ni
-- para el atleta: un administrador NO la lee aunque entre en Academia.
-- Sin políticas de escritura: de momento se rellena desde la base.
-- ---------------------------------------------------------------------------
create table if not exists public.academia_radiografia (
  atleta_id      uuid primary key references public.atletas(id) on delete cascade,
  lo_bueno       text[] not null default '{}',
  a_mejorar      text[] not null default '{}',
  tecnica        text[] not null default '{}',
  que_haria      text[] not null default '{}',
  ojo            text[] not null default '{}',
  actualizado_en timestamptz not null default now()
);

alter table public.academia_radiografia enable row level security;

drop policy if exists "radiografia: solo su entrenador" on public.academia_radiografia;
create policy "radiografia: solo su entrenador" on public.academia_radiografia
  for select to authenticated
  using (exists (
    select 1 from public.atletas a join public.grupos g on g.id = a.grupo_id
     where a.id = atleta_id and g.entrenador_id = (select public.mi_perfil_id())
  ));

revoke all on public.academia_radiografia from anon, authenticated;
grant select on public.academia_radiografia to authenticated;
