-- ============================================================
-- 096 · LA SEGUNDA HORA: CUATRO GRUPOS, NI UNO MÁS
-- ------------------------------------------------------------
-- QUÉ ESTABA MAL
--
-- La sección de pista tenía diez grupos en la base —vallistas, saltos,
-- lanzamientos, marcha, fondistas, velocistas sub-16, velocidad
-- sub-20…— que venían de los datos de demostración. El club no entrena
-- así. A segunda hora hay CUATRO grupos y nada más:
--
--   · Velocidad A — la lleva Andrés Clavero. Cinco días, sin opción.
--   · Velocidad B — la lleva Cristian. Tres o cinco días, y el precio
--     cambia según cuál se elija.
--   · Fondo y medio fondo — también tres o cinco días, con el mismo
--     cambio de precio.
--   · Grupo recreativo — tres días como mucho. Hay quien entrena dos
--     (lunes y miércoles, o martes y jueves) y puede añadir el viernes.
--
-- Los tres primeros ya estaban. El recreativo no existía como grupo,
-- aunque su tarifa («Pista · Grupo recreativo») llevaba ahí desde la
-- migración 022 y la página de la sección lo lleva contando desde
-- siempre: era el grupo que faltaba, no una tarifa huérfana.
--
-- NI HORARIOS NI IMPORTES NUEVOS. Los tres grupos que ya estaban se
-- quedan con el horario que tienen; el recreativo nace sin horario,
-- porque el club no ha dicho a qué hora entrena y una hora inventada
-- manda a la gente a la pista el día que no es. Los importes de las
-- tarifas no se tocan: lo único que se corrige es en cuántos días se
-- puede entrenar, que sí lo ha dicho el club.
--
-- QUÉ PASA CON LOS ATLETAS DE LOS GRUPOS QUE SOBRAN
-- Ninguno se queda sin grupo. Los de fondo y marcha pasan a «Fondo y
-- medio fondo»; los de velocidad, vallas, saltos y lanzamientos, a
-- «Velocidad B», que es la puerta de entrada normal de la sección; el
-- único de sub-20 (el de más nivel) a «Velocidad A». Son datos de
-- demostración, así que «Velocidad B» se queda cargado: el club los
-- reparte desde Panel → Atletas, que es donde se cambia a alguien de
-- grupo. Los grupos que sobran NO se borran, se apagan: de ellos
-- cuelgan asistencias, sesiones y microciclos.
--
-- Idempotente: el grupo se crea solo si no está, los atletas se mueven
-- solo si queda alguno por mover, y las tarifas solo se corrigen si
-- siguen diciendo lo que decían (si el club ya las ha editado, se
-- respeta lo suyo).
-- ============================================================


-- ------------------------------------------------------------
-- 1 · EL GRUPO QUE FALTABA
-- ------------------------------------------------------------
insert into public.grupos (nombre, seccion, descripcion, activo)
select 'Grupo recreativo', 'competicion',
       'Atletismo en pista sin la exigencia de competir: el mismo trabajo técnico, a ritmo adaptado. Dos días (lunes y miércoles, o martes y jueves) y se le puede añadir el viernes.',
       true
 where not exists (
   select 1 from public.grupos g
    where g.nombre = 'Grupo recreativo' and g.seccion = 'competicion'
 );


-- ------------------------------------------------------------
-- 2 · LOS ATLETAS DE LOS GRUPOS QUE SOBRAN, A SU SITIO
-- ------------------------------------------------------------
do $$
declare v_sobran uuid[];
begin
  select array_agg(id) into v_sobran
    from public.grupos
   where seccion = 'competicion'
     and nombre in ('Fondistas', 'Marcha', 'Vallistas', 'Saltos',
                    'Lanzamientos', 'Velocistas · Sub-16', 'Velocidad · Sub-20');

  if v_sobran is null then
    return;
  end if;

  if not exists (select 1 from public.atletas where grupo_id = any(v_sobran)) then
    return;                              -- ya están todos movidos
  end if;

  -- Fondo y marcha son resistencia: al grupo de fondo.
  update public.atletas a
     set grupo_id = (select id from public.grupos
                      where seccion = 'competicion' and nombre = 'Fondo y medio fondo' limit 1)
   where a.grupo_id in (select id from public.grupos
                         where seccion = 'competicion' and nombre in ('Fondistas', 'Marcha'));

  -- El de sub-20 es el de más nivel: al grupo de rendimiento.
  update public.atletas a
     set grupo_id = (select id from public.grupos
                      where seccion = 'competicion' and nombre = 'Velocidad A' limit 1)
   where a.grupo_id in (select id from public.grupos
                         where seccion = 'competicion' and nombre = 'Velocidad · Sub-20');

  -- Lo demás (vallas, saltos, lanzamientos y la cantera de velocidad)
  -- a Velocidad B, que es por donde se entra a la sección.
  update public.atletas a
     set grupo_id = (select id from public.grupos
                      where seccion = 'competicion' and nombre = 'Velocidad B' limit 1)
   where a.grupo_id = any(v_sobran);

  -- Ya vacíos, se apagan: dejan de salir en la web y en los horarios,
  -- pero su historial sigue donde estaba.
  update public.grupos
     set activo = false
   where id = any(v_sobran);
end $$;


-- ------------------------------------------------------------
-- 3 · CADA TARIFA, COLGADA DE SU GRUPO
-- ------------------------------------------------------------
-- Las cuatro tarifas de pista existían sueltas, atadas a la sección
-- pero no al grupo. Colgarlas del grupo es lo que hace que el panel
-- pueda decir «esto afecta a la ficha del grupo tal» en vez de dejarlo
-- a que los nombres cuadren de milagro. Solo se rellena si está vacío:
-- si alguien lo ha atado a mano, manda lo suyo.
update public.tarifas t
   set grupo_id = g.id
  from public.grupos g
 where t.grupo_id is null
   and g.seccion = 'competicion'
   and (t.clave, g.nombre) in (
     ('pista-velocidad-a',       'Velocidad A'),
     ('pista-velocidad-b',       'Velocidad B'),
     ('pista-fondo-medio-fondo', 'Fondo y medio fondo'),
     ('pista-recreativo',        'Grupo recreativo')
   );


-- ------------------------------------------------------------
-- 4 · LOS DÍAS QUE ENTRENA CADA GRUPO
-- ------------------------------------------------------------
-- Esto sí lo ha dicho el club y estaba mal escrito. Velocidad B no son
-- tres días: son tres o cinco, y el precio cambia. El recreativo no son
-- tres fijos: son dos, con el viernes opcional.
--
-- Los IMPORTES no se tocan. Fondo ya tiene los dos (40-55 €); el de
-- cinco días de Velocidad B no lo sabemos, y poner un número a ojo en
-- algo que pagan las familias no se hace. Queda dicho en la nota para
-- que el club lo rellene en Panel → Tarifas.
--
-- Solo se cambia si la fila sigue diciendo lo que decía: si el club ya
-- la ha editado, no se le pisa.
update public.tarifas
   set dias  = '3 o 5 días',
       notas = 'Se puede entrenar 3 o 5 días y el precio cambia. El importe de 5 días está pendiente de publicar.'
 where clave = 'pista-velocidad-b'
   and dias  = '3 días'
   and coalesce(notas, '') = '';

update public.tarifas
   set dias  = '2 o 3 días',
       notas = 'Dos días fijos (lunes y miércoles, o martes y jueves) y el viernes opcional. Tres días como máximo.'
 where clave = 'pista-recreativo'
   and dias  = '3 días'
   and coalesce(notas, '') = '';

-- Velocidad A no tiene elección: son cinco días. La tarifa ya lo dice
-- («5 días»), así que aquí solo se deja escrito el porqué en la nota,
-- sin tocar el importe ni pisar lo que ya hubiera escrito el club.
update public.tarifas
   set notas = 'Acceso restringido, por decisión del club. Se entrena 5 días, sin opción de menos.'
 where clave = 'pista-velocidad-a'
   and notas = 'Acceso restringido, por decisión del club.';
