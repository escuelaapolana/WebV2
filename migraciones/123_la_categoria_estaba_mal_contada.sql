-- ============================================================
-- 123 · La categoría estaba mal contada, y siempre por el mismo lado
-- ------------------------------------------------------------
-- EL FALLO, EN UNA FRASE
-- La cuenta que dice en qué categoría está un atleta se equivocaba
-- con LA MITAD DE CADA CATEGORÍA: a todos los del año mayor de cada
-- tramo los subía al tramo siguiente.
--
-- Un ejemplo de los de verdad: un niño nacido en 2015 es Sub-12, y
-- la app decía Sub-14. Uno de 2011 es Sub-16, y decía Sub-18. Y así
-- en los seis tramos.
--
-- POR QUÉ PASABA
-- La cuenta iba por AÑOS CUMPLIDOS y los tramos van por AÑO DE
-- NACIMIENTO. Cada categoría junta dos años seguidos, así que en un
-- año natural conviven dos edades: los Sub-12 de 2026 son quienes
-- cumplen 10 y quienes cumplen 11. La cuenta cortaba en 10, así que
-- los de 11 se escapaban al tramo de arriba.
--
-- POR QUÉ SE ARREGLA HOY Y NO EN OCTUBRE
-- Porque hoy no hay ni una ficha de una persona real: las 207 que
-- hay en la base son de demostración y de pruebas. En septiembre
-- entran las de verdad, y a partir de ahí arreglar esto sería
-- repasar cuatrocientas fichas a mano.
--
-- ------------------------------------------------------------
-- LA TABLA DE LA FEDERACIÓN · NO BORRAR
-- ------------------------------------------------------------
-- Esto es el Anexo 2 de la normativa de licencias de la RFEA para la
-- temporada 2026, copiado tal cual. Se deja escrito aquí para que
-- dentro de tres años nadie «corrija» esta cuenta pensando que sobra
-- un año:
--
--     MÁSTER    desde el día en que cumple 35 años
--     SÉNIOR    nacidos en 2003 o años anteriores
--     SUB-23    nacidos en 2004, 2005 y 2006
--     SUB-20    nacidos en 2007 y 2008
--     SUB-18    nacidos en 2009 y 2010
--     SUB-16    nacidos en 2011 y 2012
--     SUB-14    nacidos en 2013 y 2014
--     SUB-12    nacidos en 2015 y 2016
--     SUB-10    nacidos en 2017 y 2018
--     SUB-8     nacidos en 2019 o años posteriores
--
-- Cómo se lee: cada categoría son DOS años de nacimiento seguidos
-- (Sub-23 son tres), y la escalera entera se desplaza un año cada
-- temporada. Por eso la cuenta no puede escribir los años a mano:
-- resta el año de nacimiento del año en curso y mira cuántos cumple.
--
-- Y de ahí sale el número de cada corte, que es lo que se arregla:
--
--     Sub-12  →  cumple 10 u 11  →  edad <= 11   (antes: <= 10)
--     Sub-14  →  cumple 12 o 13  →  edad <= 13   (antes: <= 12)
--     Sub-16  →  cumple 14 o 15  →  edad <= 15   (antes: <= 14)
--     Sub-18  →  cumple 16 o 17  →  edad <= 17   (antes: <= 16)
--     Sub-20  →  cumple 18 o 19  →  edad <= 19   (antes: <= 18)
--     Sub-23  →  cumple 20, 21 o 22  →  edad <= 22   (antes: <= 21)
--
-- ------------------------------------------------------------
-- DOS COSAS QUE NO SE TOCAN, Y HAY QUE SABER POR QUÉ
--
-- 1 · «ESCUELA INICIACIÓN» SE QUEDA DONDE ESTÁ.
-- Ese tramo NO EXISTE en la federación: se lo inventó el club para
-- los más pequeños, y dónde acaba lo decide el club y no esta
-- cuenta. Sigue cortando en los 8 años cumplidos, igual que hasta
-- hoy.
--
-- Consecuencia que conviene tener delante: la escalera del club no
-- tiene Sub-10 ni Sub-8. Los de 9 y 10 años, que en la federación
-- son Sub-10, aquí caen en Sub-12 porque no hay otro sitio donde
-- ponerlos. Eso ya pasaba antes de esta migración y se deja igual:
-- añadir un Sub-10 es una decisión del club, no un arreglo.
--
-- 2 · MÁSTER SIGUE CONTÁNDOSE POR AÑOS Y NO POR EL DÍA.
-- La federación dice «desde el día en que cumple 35 años»; aquí se
-- pasa a máster el 1 de enero del año en que los cumple. Es una
-- aproximación conocida y NO es el mismo fallo que el de arriba: los
-- tramos Sub- van por año de nacimiento a propósito y este va por el
-- cumpleaños a propósito. Cambiarlo es otra conversación —y además
-- la federación deja no ser máster si se pide—, así que se deja
-- dicho y no se toca.
--
-- ------------------------------------------------------------
-- NADA PERSONAL AQUÍ DENTRO
-- Ni un nombre, ni una fecha de nacimiento de nadie. Este archivo
-- queda en el histórico para siempre y el repositorio es público.
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta. No borra ni una ficha.
-- ============================================================

begin;

-- ============================================================
-- 1 · LA CUENTA, BIEN HECHA
-- ------------------------------------------------------------
-- Es la misma función de la 121 con los seis cortes corregidos. La
-- pantalla de Atletas, la de Importar y la de crear fichas desde un
-- alta hacen esta misma cuenta en el navegador, y las tres leen la
-- escalera del mismo sitio (`assets/js/categorias.js`) para que no
-- vuelva a haber dos criterios sueltos por ahí.
-- ============================================================
create or replace function public.categoria_por_nacimiento(p_fecha date)
returns text
language sql
stable
set search_path to 'public'
as $$
  select case
           when p_fecha is null then null
           else (
             select case
                      -- Tramo del club, no de la federación. No se toca.
                      when e <=  8 then 'Escuela iniciación'
                      -- De aquí abajo, la tabla de la RFEA del encabezado.
                      -- Cada tramo son dos años de nacimiento, así que en
                      -- un año natural conviven DOS edades. Ese es el
                      -- fallo que se arregla aquí.
                      when e <= 11 then 'Sub-12'   -- cumple 10 u 11
                      when e <= 13 then 'Sub-14'   -- cumple 12 o 13
                      when e <= 15 then 'Sub-16'   -- cumple 14 o 15
                      when e <= 17 then 'Sub-18'   -- cumple 16 o 17
                      when e <= 19 then 'Sub-20'   -- cumple 18 o 19
                      when e <= 22 then 'Sub-23'   -- cumple 20, 21 o 22
                      when e <= 34 then 'Absoluto' -- la RFEA lo llama sénior
                      else 'Máster'                -- aquí, por año; ver arriba
                    end
             from (select extract(year from current_date)::int
                          - extract(year from p_fecha)::int as e) t
           )
         end;
$$;

comment on function public.categoria_por_nacimiento(date) is
  'La categoría por el AÑO de nacimiento, según la tabla de licencias de la '
  'RFEA: cada tramo junta dos años seguidos, así que en un año natural '
  'conviven dos edades. «Escuela iniciación» es del club y no de la '
  'federación. La misma cuenta que hace el panel en assets/js/categorias.js.';


-- ============================================================
-- 2 · LAS FICHAS QUE YA ESTABAN MAL CLASIFICADAS
-- ------------------------------------------------------------
-- Se corrigen SOLO las fichas cuya categoría guardada es exactamente
-- lo que decía la cuenta vieja. Es decir: las que rellenó la máquina
-- equivocándose.
--
-- Lo que NO se toca, y es la parte importante: si alguien puso la
-- categoría A MANO y no coincide con ninguna de las dos cuentas, se
-- deja como está. Un entrenador que sube a un crío de categoría a
-- propósito tiene sus razones, y una migración no puede borrarlas de
-- madrugada.
--
-- Se puede volver a lanzar sin miedo: a la segunda pasada la
-- categoría guardada ya es la buena, deja de coincidir con la vieja
-- y no se toca ninguna fila.
-- ============================================================
with vieja as (
  select a.id,
         a.categoria as guardada,
         (extract(year from current_date)::int
          - extract(year from a.fecha_nacimiento)::int) as e
    from public.atletas a
   where a.fecha_nacimiento is not null
), calculada as (
  select v.id, v.guardada,
         -- La cuenta VIEJA, la que se equivocaba. Está aquí escrita a
         -- propósito: es la única forma de reconocer qué fichas rellenó
         -- ella y cuáles puso una persona.
         case
           when e <=  8 then 'Escuela iniciación'
           when e <= 10 then 'Sub-12'
           when e <= 12 then 'Sub-14'
           when e <= 14 then 'Sub-16'
           when e <= 16 then 'Sub-18'
           when e <= 18 then 'Sub-20'
           when e <= 21 then 'Sub-23'
           when e <= 34 then 'Absoluto'
           else 'Máster'
         end as antes,
         case
           when e <=  8 then 'Escuela iniciación'
           when e <= 11 then 'Sub-12'
           when e <= 13 then 'Sub-14'
           when e <= 15 then 'Sub-16'
           when e <= 17 then 'Sub-18'
           when e <= 19 then 'Sub-20'
           when e <= 22 then 'Sub-23'
           when e <= 34 then 'Absoluto'
           else 'Máster'
         end as ahora
    from vieja v
)
update public.atletas a
   set categoria = c.ahora,
       updated_at = now()
  from calculada c
 where a.id = c.id
   and c.guardada = c.antes      -- la rellenó la cuenta vieja
   and c.antes <> c.ahora;       -- y la nueva dice otra cosa

commit;

-- Que la API se entere de la función nueva sin esperar a que se le
-- ocurra sola.
notify pgrst, 'reload schema';
