-- Especialidades del atleta: lista de pruebas que hace (multidisciplina).
alter table public.atletas add column if not exists especialidades text[];
