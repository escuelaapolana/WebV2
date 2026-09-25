-- 224 · Vista PÚBLICA de vacantes de natación
--
-- Las tablas base son privadas (hay menores). Para la web solo se expone lo
-- AGREGADO y no personal: por franja, el semáforo de admisión, los niveles que
-- admite y el criterio de Mario. NUNCA nombres ni monitores.
--
-- La vista corre con los privilegios de su dueño (no security_invoker), así que
-- salta la RLS de la tabla base y solo muestra estas columnas. Se concede SELECT
-- a anon/authenticated (la clave publishable del front).

create or replace view public.natacion_vacantes as
select
  dia,
  hora,
  orden,
  grupo,
  calles,
  tiene_vaso,
  semaforo,
  admite_niveles,
  criterio
from public.natacion_franjas
where activa
order by dia, hora;

grant select on public.natacion_vacantes to anon, authenticated;
