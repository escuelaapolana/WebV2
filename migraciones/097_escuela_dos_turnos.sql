-- ============================================================
-- 097 · LA ESCUELA ENTRENA DOS VECES: NUEVE NOMBRES, DIECIOCHO
--       GRUPOS DE VERDAD
-- ------------------------------------------------------------
-- QUÉ ESTABA MAL
--
-- La migración 095 montó la escuela por año de nacimiento: nueve grupos
-- de color, rojo 1 a verde 3. Los años están bien, pero faltaba la mitad
-- de la escuela. El club lo dijo así: «el lunes hay rojo 1, rojo 2…
-- hasta verde 3. Y el martes también. Los grupos de niños son
-- diferentes, pero los grupos se llaman igual».
--
-- O sea: cada color existe DOS VECES. Un turno entrena lunes y
-- miércoles y el otro martes y jueves. Misma edad, mismo contenido,
-- NIÑOS DISTINTOS. Son dieciocho grupos con nueve nombres.
--
-- Con nueve en la base, el entrenador que abre la lista del rojo 1 del
-- lunes se encuentra dentro a los niños del martes. Pasar lista así no
-- sirve para nada, y las faltas que salen de ahí tampoco.
--
-- EL NOMBRE NO SE TOCA. El club los llama «Azul 2», no «Azul 2 martes».
-- Cambiarles el nombre para distinguirlos sería inventarnos una manera
-- de hablar que en la pista nadie usa. Lo que los distingue es el turno,
-- y por eso el turno es un campo aparte: donde haga falta separarlos, se
-- lee «Azul 2 · martes y jueves», con el nombre intacto.
--
-- POR QUÉ UN CAMPO NUEVO Y NO EL HORARIO DE SIEMPRE
-- En `grupos` ya está `horario`, un texto libre («Martes y jueves
-- 18:30-20:00 · Pista»), del que la base saca las franjas de
-- `grupo_horarios`. Pero ese texto es para escribir el horario COMPLETO,
-- y el de la escuela todavía no se sabe: falta la hora y falta la sede.
-- Colgar de un texto a medio escribir la identidad de un grupo —saber
-- cuál de los dos «Azul 2» es este— es pedir que el día que alguien
-- corrija una tilde se mezclen los niños otra vez. El turno es un dato
-- corto y cerrado (uno de dos), así que se guarda como tal. El horario
-- sigue siendo del club: cuando diga la hora y la sede, las escribe en
-- Panel → Grupos y se suma a los días, sin pisar nada.
--
-- NI UNA HORA INVENTADA. Aquí solo se escriben los DÍAS, que es lo que
-- el club ha dicho. La hora y la sede se quedan en blanco a propósito:
-- una hora puesta a ojo manda a una familia a la pista cuando no toca, y
-- eso es peor que un hueco que se ve.
--
-- LOS NIÑOS QUE YA ESTABAN NO SE MUEVEN. Los que hay repartidos son
-- datos de demostración y no consta a qué turno va cada uno. Se quedan
-- todos en el turno de lunes y miércoles, que es lo que ya eran esos
-- nueve grupos. Es un reparto provisional Y SE NOTA que lo es: la
-- escuela los pasa al martes desde Panel → Atletas uno a uno. Repartirlos
-- por la mitad al azar habría dado un resultado con la misma pinta de
-- verdadero y sin serlo.
--
-- LOS GRUPOS DE MARTES NACEN COMO SU GEMELO. Si el de lunes está
-- encendido, el de martes también: el club ha dicho que existen los dos.
-- Los que están apagados por no tener a nadie (los rojos) nacen
-- apagados, igual que su pareja, y se encienden juntos cuando llegue el
-- primer niño.
--
-- Idempotente: el campo se añade solo si no está, el turno solo se
-- rellena donde está en blanco (si el club ya ha cambiado alguno, manda
-- lo suyo) y el gemelo se crea solo si no existe.
-- ============================================================


-- ------------------------------------------------------------
-- 1 · EL CAMPO QUE FALTABA: EN QUÉ TURNO ENTRENA EL GRUPO
-- ------------------------------------------------------------
-- Se guarda con palabras y no con un número («lunes-miercoles» y no 1)
-- para que quien abra la tabla dentro de tres años entienda qué está
-- leyendo sin buscar la tabla de equivalencias.
alter table public.grupos
  add column if not exists turno text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'grupos_turno_conocido'
  ) then
    -- Vacío es lo normal: casi ningún grupo del club se desdobla. Los
    -- que sí, solo pueden ser de uno de los dos turnos; cualquier otra
    -- cosa es un dedazo y se para aquí, no tres pantallas más allá.
    alter table public.grupos
      add constraint grupos_turno_conocido check (
        turno is null or turno in ('lunes-miercoles', 'martes-jueves')
      );
  end if;
end $$;

comment on column public.grupos.turno is
  'Para los grupos que existen dos veces con el mismo nombre y niños distintos (la escuela): «lunes-miercoles» o «martes-jueves». Vacío en los grupos que solo existen una vez.';


-- ------------------------------------------------------------
-- 2 · LOS NUEVE DE AHORA SON LOS DE LUNES Y MIÉRCOLES
-- ------------------------------------------------------------
-- Hay que elegir uno de los dos y no hay dato que decida: se elige el
-- primero de la semana. Solo se rellena lo que está en blanco, así que
-- volver a pasar la migración no deshace ninguna decisión posterior.
update public.grupos
   set turno = 'lunes-miercoles'
 where seccion = 'escuela'
   and turno is null
   and nacidos_desde is not null      -- los de color; el de competición no se desdobla
   and nombre in ('Rojo 1', 'Rojo 2', 'Rojo 3',
                  'Azul 1', 'Azul 2', 'Azul 3',
                  'Verde 1', 'Verde 2', 'Verde 3');


-- ------------------------------------------------------------
-- 3 · Y NACEN LOS NUEVE DE MARTES Y JUEVES
-- ------------------------------------------------------------
-- Cada uno se crea a imagen de su pareja: mismo nombre, mismo año de
-- nacimiento, misma descripción y mismas pruebas, porque es literalmente
-- el mismo grupo otro día. Lo único que cambia es el turno y quién va.
-- Sin entrenador: el club dirá quién lleva cada uno.
insert into public.grupos
       (nombre, seccion, turno, nacidos_desde, nacidos_hasta, descripcion, pruebas, activo)
select g.nombre, g.seccion, 'martes-jueves', g.nacidos_desde, g.nacidos_hasta,
       g.descripcion, g.pruebas, g.activo
  from public.grupos g
 where g.seccion = 'escuela'
   and g.turno = 'lunes-miercoles'
   and not exists (
     select 1
       from public.grupos t
      where t.seccion = 'escuela'
        and t.nombre  = g.nombre
        and t.turno   = 'martes-jueves'
   );


-- ------------------------------------------------------------
-- 4 · QUE NO PUEDAN SALIR TRES «AZUL 2»
-- ------------------------------------------------------------
-- Dos con el mismo nombre son los dos turnos y es lo correcto. Tres ya
-- es un grupo creado dos veces sin querer, y a partir de ahí nadie sabe
-- en cuál pasar lista. La base lo impide de raíz en vez de confiar en
-- que quien lo cree se dé cuenta.
create unique index if not exists ux_grupos_escuela_nombre_turno
  on public.grupos (nombre, turno)
  where seccion = 'escuela' and turno is not null;
