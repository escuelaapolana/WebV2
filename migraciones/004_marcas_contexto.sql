-- Distinguir marcas hechas en competición oficial vs. en entrenamiento.
alter table public.marcas_atleta add column if not exists contexto text;
alter table public.marcas_atleta drop constraint if exists marcas_atleta_contexto_check;
alter table public.marcas_atleta add constraint marcas_atleta_contexto_check
  check (contexto is null or contexto in ('competicion','entreno'));

-- Demo: las dos primeras marcas fueron en competición; las de progresión, en entreno.
update public.marcas_atleta set contexto='competicion'
  where atleta_id='99987ae7-0485-4063-a516-42b928dc3bda' and fecha in ('2026-02-15','2026-05-20');
update public.marcas_atleta set contexto='entreno'
  where atleta_id='99987ae7-0485-4063-a516-42b928dc3bda' and contexto is null;
