-- Un maratón son ~12.900 segundos y no cabía en la columna (numeric(6,2) = máx 9.999,99).
-- Se amplía para admitir pruebas largas (maratón, ultras, travesías).
alter table public.marcas_atleta alter column tiempo_segundos type numeric(10,2);
