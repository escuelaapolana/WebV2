-- ============================================================
-- 164 · Renombrar los grupos de atletismo en pista
-- ------------------------------------------------------------
-- Reordenación de la sección de pista pedida por el club:
--   · «Grupo A» → «Academia AC98»  (el alto rendimiento, con su
--      propia página /academia/; se plantea como una academia,
--      no como un grupo más).
--   · «Grupo B» → «Velocidad».
--
-- Solo cambia el nombre que se muestra. Los atletas siguen ligados
-- a su grupo por el id, así que nadie se descoloca. Se apunta por
-- id Y por nombre a la vez, para que si ya se hubiera tocado, no
-- renombre otra cosa por error.
--
-- Cómo aplicarlo (una de las dos):
--   a) Panel → Grupos → cambiar el nombre de cada uno.
--   b) Supabase → SQL Editor → pegar esto → Run.
-- ============================================================
update public.grupos
   set nombre = 'Academia AC98'
 where id = 'c288b979-cd00-4abb-96da-30fa997ef297'
   and nombre = 'Grupo A';

update public.grupos
   set nombre = 'Velocidad'
 where id = 'bb5d15ee-f96e-44ee-9b4f-86b60ca466c6'
   and nombre = 'Grupo B';

-- El PRECIO lleva su propio texto (el «concepto» de la tarifa), aparte del
-- nombre del grupo. Se renombra a juego para que la tabla de precios de pista
-- diga «Velocidad» y no «Grupo B». (La tarifa de la Academia, `pista-velocidad-a`,
-- no se toca: ya no se muestra en la web pública.)
update public.tarifas
   set concepto = 'Pista · Velocidad'
 where clave = 'pista-velocidad-b'
   and concepto = 'Pista · Grupo B';

-- «Fondo-Mediofondo» YA existía, pero estaba archivado en la sección «escuela»
-- (por eso no aparecía en atletismo en pista) y sin horario. No hay ningún
-- atleta dentro ahora mismo, así que moverlo es seguro. Se pasa a «competicion»
-- para que salga en pista junto a Velocidad, y se le pone el horario que dio
-- el club: de lunes a viernes, 18:30-20:00. El texto va en el formato que sabe
-- leer la parrilla (días enumerados y « · sede» detrás), igual que los demás.
update public.grupos
   set seccion = 'competicion',
       horario = 'Lunes, martes, miércoles, jueves y viernes 18:30-20:00 · Estadio Joaquín Villar'
 where id = 'ae475335-f97c-4178-9022-014c257d0218'
   and nombre = 'Fondo-Mediofondo';
