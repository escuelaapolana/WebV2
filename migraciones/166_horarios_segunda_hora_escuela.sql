-- Horarios de SEGUNDA HORA de la escuela (los mayores).
-- Andrés (sep 2026): faltaban. Dos turnos, ambos con viernes:
--   L-X 18:30-20:00 + Viernes 17:30-19:00
--   M-J 18:30-20:00 + Viernes 17:30-19:00
-- Se ponen en los grupos de Recreación (que llevan el turno) y se limpia
-- el horario suelto de "A partir de Sub-14" para no duplicar la tarjeta.

UPDATE grupos
   SET horario = 'Lunes y miércoles 18:30-20:00 · Viernes 17:30-19:00 · Estadio Joaquín Villar'
 WHERE id IN ('8767f538-ab4d-48c2-b4be-71d6452330d8',
              'f16fee73-09ac-427e-a406-8d5d709cf8a2');

UPDATE grupos
   SET horario = 'Martes y jueves 18:30-20:00 · Viernes 17:30-19:00 · Estadio Joaquín Villar'
 WHERE id IN ('da18da3f-de49-4461-a249-5dc7cf6ee86b',
              'e28cb6d8-156f-4d55-b25a-9a8ff3559431');

UPDATE grupos
   SET horario = NULL
 WHERE id = '1edde0f9-0931-4131-9b68-267ff978813c';
