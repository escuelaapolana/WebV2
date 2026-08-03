-- ============================================================
-- 099 · Que el historial del atleta no se reescriba solo
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Un atleta que cambia de grupo pierde de golpe los entrenamientos
-- que SÍ hizo, y empieza a ver los del grupo nuevo, que NO hizo.
--
-- POR QUÉ PASA
-- La regla que deja a un atleta leer un entrenamiento («ver sesiones
-- de mi grupo», migración 018) mira el grupo en el que está HOY:
--
--     grupo_id in (select grupo_id from atletas where id in (select mis_atletas()))
--
-- Y la tabla `atletas` solo guarda `grupo_id`, el actual. No hay
-- ningún sitio donde quede escrito en qué grupo estaba alguien en
-- mayo. Así que el pasado no se consulta: se deduce del presente, y
-- cambia cuando cambia el presente.
--
-- Hoy no se nota porque nadie se ha movido de grupo y todos los datos
-- son de los últimos tres meses. En septiembre sí: los grupos de la
-- escuela se renumeran cada temporada y los chavales suben de grupo.
-- El día que eso pase, el historial de cada uno se falsea solo, sin
-- que nadie borre nada y sin que salte ningún aviso.
--
-- LO QUE SE HACE AQUÍ
-- Se añade una segunda razón para poder ver un entrenamiento, además
-- de «es de mi grupo»:
--
--     ...o yo apunté cómo me fue ese día.
--
-- Cuando un atleta rellena «¿Cómo ha ido?» se guarda una fila en
-- `registros_sesion` con SU identificador y el del entrenamiento. Esa
-- fila es la prueba de que ese entrenamiento fue suyo, y no depende
-- del grupo: es un hecho, con fecha, que ya no cambia. Con 1.185
-- filas guardadas, es el rastro más fiable que hay de qué hizo cada
-- uno (`asistencia` está vacía: hoy nadie pasa lista).
--
-- POR QUÉ ESTO NO ABRE NADA QUE NO FUERA SUYO
-- Tres candados, y ninguno se toca:
--
--   1. Sigue haciendo falta que el entrenamiento esté PUBLICADO. La
--      condición `publicada = true` se queda fuera del paréntesis, o
--      sea que se aplica también a lo nuevo: un borrador no se lee
--      nunca, ni aunque hubiera un registro (por ejemplo, si el
--      entrenador despublica algo después).
--   2. Solo cuenta el registro PROPIO. `mis_atletas()` devuelve los
--      atletas de quien pregunta: uno mismo, los hijos si eres padre,
--      y los tuyos si eres su entrenador. Nadie puede apoyarse en el
--      registro de otro.
--   3. Nadie puede fabricarse el permiso. Escribir en
--      `registros_sesion` ya exige, por su propia regla, que la fila
--      sea de uno de tus atletas; y para saber que un entrenamiento
--      existe hay que haberlo podido ver antes.
--
-- Es decir: esta regla no enseña ni un entrenamiento nuevo. Solo
-- impide que se dejen de ver los que ya se vieron y se hicieron.
--
-- EFECTO SECUNDARIO, Y ES BUENO
-- El entrenador ya podía leer el feedback de sus atletas (RPE,
-- sensaciones, tiempos) aunque fuera de un entrenamiento de otro
-- grupo, pero NO podía leer el entrenamiento al que ese feedback se
-- refería: veía «RPE 8/10» sin saber de qué. Con esto lo ve entero.
--
-- POR QUÉ UNA FUNCIÓN Y NO LA CONSULTA METIDA EN LA REGLA
-- Una regla de acceso que consulta otra tabla arrastra también las
-- reglas de ESA tabla, y eso se enreda enseguida. Se usa el mismo
-- patrón que ya hay en el proyecto (`es_admin`, `mi_perfil_id`,
-- `mis_atletas`): una función pequeña, STABLE y SECURITY DEFINER, que
-- responde sí o no. Y nace cerrada, como manda la migración 090: solo
-- se le da permiso de ejecución a quien ha entrado con su cuenta.
--
-- COMPROBADO CONTRA LA BASE, SIMULANDO PAPELES
-- Se montó la escena de septiembre dentro de una transacción que
-- después se deshizo: se cambió de grupo a un atleta de prueba con 43
-- entrenamientos apuntados y se preguntó a la base haciéndose pasar
-- por él (`request.jwt.claims` + `set role`).
--
--   ANTES (como está hoy)
--     de sus 43 entrenamientos, los que puede ver ......  0
--     de sus 43, los que ha perdido ....................  43
--     entrenamientos del grupo nuevo que ve, sin haberlos
--     hecho ............................................  64
--
--   DESPUÉS (con esta migración)
--     de sus 43, los que puede ver .....................  43
--     de sus 43, los que ha perdido ....................   0
--     borradores que se cuelan .........................   0
--     ve algo que no debería (de más) ..................   0
--     no ve algo que sí debería (de menos) .............   0
--
--   Y desde otras cuentas:
--     otro atleta, apoyándose en los registros del primero  0
--     quien no ha entrado (sin cuenta), entrenamientos .... 0
--
-- «De más» y «de menos» se midieron contra el conjunto exacto que la
-- regla tiene que dejar ver, no contra un total aproximado.
--
-- Todo el fichero se puede volver a pasar las veces que haga falta.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · ¿Apunté yo cómo me fue este entrenamiento?
-- ------------------------------------------------------------
-- Responde sí o no para el entrenamiento que se le pase, mirando solo
-- los registros de los atletas de quien pregunta.
create or replace function public.tengo_registro_en(p_sesion uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1
      from public.registros_sesion r
     where r.sesion_id = p_sesion
       and r.atleta_id in (select public.mis_atletas())
  );
$$;

comment on function public.tengo_registro_en(uuid) is
  'Cierto si alguno de los atletas de quien pregunta apuntó sus sensaciones en ese entrenamiento. Sirve para que el historial no dependa del grupo en el que se esté hoy.';

-- Nace cerrada (migración 090) y se abre solo a quien tiene cuenta.
revoke all on function public.tengo_registro_en(uuid) from public;
revoke all on function public.tengo_registro_en(uuid) from anon;
grant execute on function public.tengo_registro_en(uuid) to authenticated;

-- ------------------------------------------------------------
-- 2 · La regla de lectura, con la razón que faltaba
-- ------------------------------------------------------------
-- Igual que la de la migración 018, palabra por palabra, más la
-- tercera línea. `publicada = true` sigue mandando sobre las tres.
drop policy if exists "ver sesiones de mi grupo" on public.sesiones;
create policy "ver sesiones de mi grupo" on public.sesiones
for select to authenticated
using (
  publicada = true
  and (
    -- a) es de mi grupo y va para todo el grupo
    (atletas_ids is null and grupo_id in (select grupo_id from public.atletas where id in (select mis_atletas())))
    -- b) va dirigido a unos atletas concretos y estoy entre ellos
    or (atletas_ids is not null and exists (select 1 from unnest(atletas_ids) x where x in (select mis_atletas())))
    -- c) lo hice: apunté cómo me fue. Aunque hoy esté en otro grupo.
    or public.tengo_registro_en(id)
  )
);

commit;
