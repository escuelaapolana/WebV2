-- 273_natacion_vacantes_id.sql
-- Natación · exponer el franja_id en la vista pública natacion_vacantes, para
-- poder apuntarse a la lista de espera de una franja concreta desde /natacion.
-- Se añade `id` al FINAL (así vale CREATE OR REPLACE). Es un uuid, no es dato
-- sensible. El resto de la vista no cambia.
create or replace view public.natacion_vacantes as
  select dia, hora, orden, grupo, calles, tiene_vaso, semaforo, admite_niveles, criterio, id
  from public.natacion_franjas
  where activa
  order by dia, hora;
