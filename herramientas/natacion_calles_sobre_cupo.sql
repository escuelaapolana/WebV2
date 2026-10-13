-- Natación · calles con MÁS nadadores fijos que su cupo (para revisar con Mario).
-- Solo LEE. No cambia nada. Uso:  bash .secrets/psql.sh -f herramientas/natacion_calles_sobre_cupo.sql
-- Cuenta solo fijos (inscripciones activas), igual que el semáforo de la web.
-- «sin cupo» = hay gente en una calle que no está en los cupos de la franja.
-- (Misma regla que natacion_ocupacion de la mig 330, escrita a mano para que
--  funcione también antes de aplicarla.)
with cup as (
  select f.id, e.key as calle, e.value::int as cupo
    from natacion_franjas f, jsonb_each_text(f.cupos) e(key, value)
   where f.activa
),
ins as (
  select i.franja_id, i.calle, count(*) as fijos
    from natacion_inscripciones i
   where i.activa
   group by 1, 2
)
select case f.dia when 1 then 'Lunes' when 2 then 'Martes' when 3 then 'Miércoles'
                  when 4 then 'Jueves' when 5 then 'Viernes' when 6 then 'Sábado' end as dia,
       to_char(f.hora, 'HH24:MI') as hora,
       f.grupo,
       ins.calle,
       coalesce(cup.cupo::text, 'sin cupo') as cupo,
       ins.fijos,
       ins.fijos - coalesce(cup.cupo, 0) as de_mas,
       f.semaforo_forzado as semaforo_forzado
  from ins
  join natacion_franjas f on f.id = ins.franja_id and f.activa
  left join cup on cup.id = ins.franja_id and cup.calle = ins.calle
 where cup.cupo is null or ins.fijos > cup.cupo
 order by f.dia, f.hora, ins.calle;
