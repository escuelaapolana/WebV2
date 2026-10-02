-- 274_cubo_dias_semana.sql
-- El Cubo · qué DÍAS concretos viene cada persona (no solo cuántos).
-- Hasta ahora `dias` = nº de días y `horario` = el turno (los 2 días juntos),
-- así que el que venía 1 día no decía CUÁL (solo en la nota de texto) y en la
-- lista de Claudia contaba los dos días. Ahora `dias_semana` guarda los días
-- reales (1=lun … 7=dom): 2 días → los dos del turno; 1 día → el que elija.
-- La lista de Claudia cuenta POR DÍA usando esto (vacío/null = todos los del
-- turno, para no romper las altas viejas).

begin;

alter table public.cubo_altas add column if not exists dias_semana smallint[];

-- Relleno automático: los de 2 días a sus dos días del turno; las de fuerza
-- gratis a su único día. Los de 1 día quedan null (no se sabe cuál) hasta que
-- se marque; de momento siguen saliendo los dos días como hasta ahora.
update public.cubo_altas set dias_semana =
  case
    when horario ilike '%Viernes%' then array[5]::smallint[]
    when horario ilike '%Sábado%' or horario ilike '%Sabado%' then array[6]::smallint[]
    when horario ilike '%Domingo%' then array[7]::smallint[]
    when horario ilike '%L y X%' and dias = 2 then array[1,3]::smallint[]
    when horario ilike '%M y J%' and dias = 2 then array[2,4]::smallint[]
    else null
  end
where dias_semana is null;

commit;
