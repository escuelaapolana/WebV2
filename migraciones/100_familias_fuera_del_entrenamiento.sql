-- ============================================================
-- 100 · Las familias, fuera del entrenamiento y del feedback
-- ------------------------------------------------------------
-- LO QUE HA DECIDIDO EL CLUB
--   «Las familias no tienen que ver qué hacen de entrenamiento sus
--    hijos, ni el feedback.»
--
-- LO QUE PASABA HASTA AHORA, Y ERA PEOR DE LO QUE PARECÍA
-- El permiso de un padre se calcula con `mis_atletas()`, que devuelve
-- los atletas de quien pregunta por tres caminos: es él mismo, es su
-- hijo (`perfil_padre_id`) o es su entrenador. Como el padre entra por
-- el segundo camino, la base lo trataba EXACTAMENTE IGUAL que al
-- propio atleta. De ahí salían dos cosas:
--
--   1. La pantalla de familia pedía a `sesiones` los campos `bloques` y
--      `nota_razonamiento`: el entrenamiento entero, ejercicio por
--      ejercicio, y la nota del entrenador.
--   2. Y el feedback (`registros_sesion`: esfuerzo, sensaciones,
--      tiempos por serie, molestias, sueño, peso) estaba abierto al
--      padre aunque la pantalla no lo pidiera nunca. Es decir: no se
--      veía, pero se podía leer. Esconderlo de la pantalla no habría
--      arreglado nada, porque el dato salía igual de la base.
--
-- Y había una promesa que el código no cumplía: en la zona de familia
-- pone «a partir de los 14 años tiene su propia cuenta… lo que hable
-- con su entrenador (su feedback) es suyo». Esa frontera no existía en
-- ningún sitio: era una frase, no una regla.
--
-- LO QUE SE HACE
-- Una segunda función, hermana de `mis_atletas()`, con los mismos
-- caminos MENOS el del padre. Y se usa solo en los dos sitios que
-- tratan del entrenamiento. Todo lo demás se queda como estaba.
--
-- LO QUE LA FAMILIA SIGUE VIENDO (no se toca ni una de estas reglas):
--   pagos · pagos_online · ausencias (y avisar de una falta) ·
--   notas_familia · marcas_atleta · competicion_atleta ·
--   inscripciones_eventos · pedidos · cubo_bonos y sus movimientos ·
--   documentos · avisos del club.
--
-- Y el calendario de cuándo entrena su hijo tampoco se pierde: eso no
-- sale de `sesiones` sino de la vista `sesiones_agenda`, que solo
-- expone fecha, hora, título, tipo, lugar y grupo —nunca `bloques` ni
-- `nota_razonamiento`— y que ya usa el calendario público del club.
-- Sin esto, avisar de una falta (lo que más hace un padre) se habría
-- quedado sin saber a qué día se refiere.
--
-- POR QUÉ TAMBIÉN SE CAMBIA `tengo_registro_en` (de la 099)
-- Esa función abre el historial a quien tenga registro propio, y por
-- dentro usaba `mis_atletas()`. Si se dejara así, el padre volvería a
-- entrar por la puerta de atrás: vería los entrenamientos en los que
-- su hijo apuntó algo. Pasa a usar la función nueva.
--
-- LO QUE NO SE TOCA, A PROPÓSITO
-- El permiso de ESCRITURA de `registros_sesion` («atleta registra su
-- sesion», INSERT). Escribir no es ver, la pantalla de familia no
-- escribe ahí, y cerrarlo dejaría sin salida el caso de los pequeños
-- de la escuela si el club decide más adelante que un padre pueda
-- apuntar por un niño de cinco años. El de UPDATE sí se cierra: al
-- modificar se pueden pedir de vuelta las filas modificadas, y eso es
-- leer.
--
-- COMPROBADO CONTRA LA BASE, SIMULANDO PAPELES
-- Dentro de una transacción que después se deshizo, se hizo padre a una
-- cuenta de un atleta del grupo de Natación · Perfeccionamiento (57
-- entrenamientos, 43 registros suyos) y se preguntó haciéndose pasar
-- por ella:
--
--   ANTES                                          DESPUÉS
--     entrenamientos del hijo que ve ...... 57  ->  0
--     de esos, con el contenido entero ....  7  ->  0
--     feedback del hijo que ve ............ 43  ->  0
--
--   Y lo que la familia conserva, en la misma prueba:
--     calendario del hijo (sesiones_agenda) ....... 57
--     marcas del hijo ..............................  6
--     notas que le escribe el entrenador ...........  1
--   (pagos, ausencias y competiciones dieron 0 porque ese atleta no
--    tiene ninguna en la base, no porque se le cierre el paso: sus
--    reglas no se tocan.)
--
--   Y nadie más pierde nada:
--     el propio atleta ........ 57 entrenamientos · 43 de feedback
--     su entrenador ........... 125 entrenamientos · 76 de feedback
--
-- Todo el fichero se puede volver a pasar las veces que haga falta.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · Los atletas de quien pregunta, SIN el camino del padre
-- ------------------------------------------------------------
create or replace function public.mis_atletas_entreno()
returns setof uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select id from public.atletas
   where perfil_id = public.mi_perfil_id()
      or entrenador_id = public.mi_perfil_id();
$$;

comment on function public.mis_atletas_entreno() is
  'Como mis_atletas(), pero sin los hijos: el atleta y, si eres entrenador, los tuyos. Para lo que una familia no debe ver: el entrenamiento y el feedback.';

revoke all on function public.mis_atletas_entreno() from public;
revoke all on function public.mis_atletas_entreno() from anon;
grant execute on function public.mis_atletas_entreno() to authenticated;

-- ------------------------------------------------------------
-- 2 · La puerta de atrás del historial, también cerrada
-- ------------------------------------------------------------
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
       and r.atleta_id in (select public.mis_atletas_entreno())
  );
$$;

-- ------------------------------------------------------------
-- 3 · El entrenamiento: solo el atleta y su entrenador
-- ------------------------------------------------------------
-- Igual que la 099, cambiando `mis_atletas()` por la función nueva.
drop policy if exists "ver sesiones de mi grupo" on public.sesiones;
create policy "ver sesiones de mi grupo" on public.sesiones
for select to authenticated
using (
  publicada = true
  and (
    (atletas_ids is null and grupo_id in (select grupo_id from public.atletas where id in (select mis_atletas_entreno())))
    or (atletas_ids is not null and exists (select 1 from unnest(atletas_ids) x where x in (select mis_atletas_entreno())))
    or public.tengo_registro_en(id)
  )
);

-- ------------------------------------------------------------
-- 4 · El feedback: lo que el atleta le cuenta a su entrenador
-- ------------------------------------------------------------
drop policy if exists "ver datos de mis atletas" on public.registros_sesion;
create policy "ver datos de mis atletas" on public.registros_sesion
for select to authenticated
using (atleta_id in (select mis_atletas_entreno()));

drop policy if exists "atleta actualiza su registro" on public.registros_sesion;
create policy "atleta actualiza su registro" on public.registros_sesion
for update to authenticated
using (atleta_id in (select mis_atletas_entreno()))
with check (atleta_id in (select mis_atletas_entreno()));

commit;
