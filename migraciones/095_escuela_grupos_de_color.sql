-- ============================================================
-- 095 · LA ESCUELA, COMO ES DE VERDAD: NUEVE COLORES Y UN GRUPO
--       DE COMPETICIÓN
-- ------------------------------------------------------------
-- QUÉ ESTABA MAL
--
-- En la base, la escuela eran cuatro grupos inventados para la demo
-- —«Escuela Grupo 1», «Escuela Grupo 2», «Escuela · Benjamines» y
-- «Escuela · Sub-16»— que no se parecen a cómo entrena el club. La
-- escuela real es la PRIMERA HORA y se reparte por año de nacimiento en
-- nueve grupos de color: rojo 1, 2 y 3; azul 1, 2 y 3; verde 1, 2 y 3.
-- Rojo 1 son los más pequeños y verde 3 los más mayores.
--
-- Y de entre todos ellos sale un grupo de competición, también a
-- primera hora, con los Sub-14 de primer año, los Sub-12 y los Sub-10.
-- No es un grupo por edad: es una elección del club entre varias
-- edades, así que se queda sin año de nacimiento a propósito.
--
-- LOS AÑOS SON LOS DE LA TEMPORADA 2026-27, tal y como los dijo el
-- club: rojo 1 es el de 2023 (los de tres años), y de ahí para atrás.
-- En septiembre suben todos una posición con la función
-- `grupos_avanza_temporada` de la migración 093; no hay que volver a
-- tocar esto nunca.
--
-- NI HORARIOS NI PRECIOS. Aquí no se escribe una sola hora. La primera
-- hora empieza a la misma hora para todos, pero el club no ha dicho
-- cuál, y una hora inventada en la web es peor que un hueco: la gente
-- se planta en la pista a la hora equivocada. Los rellena el club en
-- Panel → Grupos. Las cuotas ya están en `tarifas` por tramos de año de
-- nacimiento y no se tocan.
--
-- LOS GRUPOS SIN NADIE NACEN APAGADOS. Los nueve colores se crean, pero
-- solo se encienden los que tienen niños. Un grupo vacío y encendido
-- sale en la web como si existiera, sin horario y sin precio, y eso es
-- prometer algo que no hay. El club lo enciende desde Panel → Grupos en
-- cuanto se apunta el primero.
--
-- QUÉ PASA CON LOS NIÑOS DE LOS GRUPOS VIEJOS
-- Ninguno se queda sin grupo. Cada uno se pasa al color que le toca por
-- su año de nacimiento. Los que ya son mayores para los colores (2014 y
-- antes) van al grupo de competición de primera hora, que es lo más
-- cercano; el club los recoloca desde Panel → Atletas si alguno ya es
-- de segunda hora. Los cuatro grupos viejos NO se borran: se apagan.
-- Borrarlos se llevaría por delante el historial de asistencias y
-- sesiones que cuelga de ellos.
--
-- Idempotente: se puede volver a pasar. Los grupos se crean solo si no
-- están, y el traslado de niños solo se hace si queda alguien por
-- mover.
-- ============================================================


-- ------------------------------------------------------------
-- 1 · LOS NUEVE COLORES Y EL GRUPO DE COMPETICIÓN
-- ------------------------------------------------------------
-- `activo` se decide en el momento de crearlo, mirando si hay algún
-- niño de ese año en la escuela. Al volver a pasar la migración el
-- grupo ya existe y no se toca: si el club lo ha encendido a mano,
-- sigue encendido.
insert into public.grupos (nombre, seccion, nacidos_desde, nacidos_hasta, activo)
select v.nombre, 'escuela', v.ano, v.ano,
       exists (
         select 1
           from public.atletas a
           join public.grupos gv on gv.id = a.grupo_id
          where gv.seccion = 'escuela'
            and a.fecha_nacimiento is not null
            and extract(year from a.fecha_nacimiento)::int = v.ano
       )
  from (values
          ('Rojo 1',  2023),
          ('Rojo 2',  2022),
          ('Rojo 3',  2021),
          ('Azul 1',  2020),
          ('Azul 2',  2019),
          ('Azul 3',  2018),
          ('Verde 1', 2017),
          ('Verde 2', 2016),
          ('Verde 3', 2015)
       ) as v(nombre, ano)
 where not exists (
   select 1 from public.grupos g
    where g.nombre = v.nombre and g.seccion = 'escuela'
 );

-- El de competición de primera hora. Sin año: se forma eligiendo niños
-- de varias edades, y por eso la descripción dice de dónde salen.
insert into public.grupos (nombre, seccion, descripcion, activo)
select 'Grupo de competición', 'escuela',
       'Sale de los grupos de color: Sub-14 de primer año, Sub-12 y Sub-10. Entrena a primera hora, como el resto de la escuela.',
       true
 where not exists (
   select 1 from public.grupos g
    where g.nombre = 'Grupo de competición' and g.seccion = 'escuela'
 );


-- ------------------------------------------------------------
-- 2 · CADA NIÑO, A SU COLOR
-- ------------------------------------------------------------
-- Solo se hace si queda alguien en los grupos viejos: así, al volver a
-- pasar la migración, no se deshace ninguna recolocación posterior del
-- club.
do $$
declare v_viejos uuid[];
begin
  select array_agg(id) into v_viejos
    from public.grupos
   where seccion = 'escuela'
     and nombre in ('Escuela Grupo 1', 'Escuela Grupo 2', 'Escuela · Benjamines', 'Escuela · Sub-16');

  if v_viejos is null then
    return;                              -- ya no existen: nada que hacer
  end if;

  if not exists (select 1 from public.atletas where grupo_id = any(v_viejos)) then
    return;                              -- ya están todos movidos
  end if;

  -- 2.1 · Los que caben en un color, por su año de nacimiento.
  update public.atletas a
     set grupo_id = destino.id
    from public.grupos destino
   where a.grupo_id = any(v_viejos)
     and a.fecha_nacimiento is not null
     and destino.seccion = 'escuela'
     and destino.nacidos_desde is not null
     and extract(year from a.fecha_nacimiento)::int
         between destino.nacidos_desde and coalesce(destino.nacidos_hasta, destino.nacidos_desde);

  -- 2.2 · Los que ya son mayores para los colores (o no tienen fecha de
  -- nacimiento apuntada) van al grupo de competición de primera hora,
  -- que es lo más parecido. Nadie se queda sin grupo, y el club los
  -- recoloca a mano desde Panel → Atletas.
  update public.atletas a
     set grupo_id = destino.id
    from public.grupos destino
   where a.grupo_id = any(v_viejos)
     and destino.seccion = 'escuela'
     and destino.nombre = 'Grupo de competición';

  -- 2.3 · Los grupos de la demo se apagan, ya vacíos. No se borran: de
  -- ellos cuelgan asistencias y sesiones que son el historial del club.
  update public.grupos
     set activo = false
   where id = any(v_viejos);
end $$;
