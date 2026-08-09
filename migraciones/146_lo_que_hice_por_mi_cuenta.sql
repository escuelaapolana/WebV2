-- ============================================================
-- 146 · Apuntar lo que hiciste por tu cuenta
-- ------------------------------------------------------------
-- EL PROBLEMA, DICHO POR UN ATLETA
-- «Si hoy salgo con la bici aunque no lo tenga planificado, como
--  recuperación activa, ¿lo puedo añadir de alguna manera?»
--
-- No se podía. Un atleta solo puede añadir un ejercicio DENTRO de un
-- entrenamiento que ya existe; si ese día no hay nada puesto, no hay
-- dónde. Y no era un olvido de la pantalla: los permisos de `sesiones`
-- solo dejan crear al entrenador del grupo y a administración, y el
-- feedback cuelga siempre de una sesión. O sea que lo único que se
-- puede apuntar en toda la app es lo que alguien te mandó antes.
--
-- Y justo lo que se queda fuera —la salida de bici del domingo, el
-- rodaje suelto, la sesión de piscina por tu cuenta— es la mitad de lo
-- que hace la gente. En los kilómetros del mes, en la carga y en lo que
-- ve el entrenador, ese trabajo sencillamente no existía.
--
-- ------------------------------------------------------------
-- LO QUE SE HACE AQUÍ, Y POR QUÉ NO UNA TABLA NUEVA
-- ------------------------------------------------------------
-- Una sesión más, creada por el propio atleta y marcada como suya.
-- Podría haber sido una tabla aparte —`actividades_libres`— y habría
-- sido peor: no saldría en la tira de la semana, no contaría en las
-- estadísticas, no entraría en la hoja de imprimir, no la vería el
-- entrenador y no se le podría poner feedback. Habría que rehacer las
-- seis cosas, y la sexta se olvidaría.
--
-- Siendo una sesión, todo eso llega solo.
--
-- ⚠️ PERO TIENE QUE NOTARSE QUE NO ES DEL PLAN.
-- Para el entrenador NO es lo mismo que hayas hecho lo que te puso, a
-- que hayas salido con la bici por tu cuenta: lo segundo también es
-- información —a veces la más útil—, pero solo si se distingue. Si se
-- mezclara, la semana del atleta parecería cumplida cuando no lo está,
-- y el entrenador estaría leyendo su propio plan donde no lo hay.
-- De eso se encarga `origen`.
--
-- ⚠️ NINGÚN DATO PERSONAL SE ESCRIBE EN ESTE ARCHIVO.
--
-- Idempotente: se puede relanzar sin romper nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/146_lo_que_hice_por_mi_cuenta.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · DE DÓNDE SALE UNA SESIÓN
-- ------------------------------------------------------------
alter table public.sesiones
  add column if not exists origen text not null default 'club';

alter table public.sesiones drop constraint if exists sesiones_origen_check;
alter table public.sesiones add constraint sesiones_origen_check
  check (origen in ('club', 'atleta'));

comment on column public.sesiones.origen is
  'Quién puso este entrenamiento: ''club'' si lo planificó el entrenador (todo lo de siempre), ''atleta'' si se lo apuntó el propio atleta por su cuenta. Se enseña en las dos pantallas: mezclar lo planificado con lo que uno hizo por su cuenta haría que una semana pareciera cumplida sin serlo.';

create index if not exists ix_sesiones_origen_atleta on public.sesiones (fecha)
  where origen = 'atleta';

-- ------------------------------------------------------------
-- 2 · DEPORTES QUE ANTES NO CABÍAN
-- ------------------------------------------------------------
-- La lista era atletismo, natación, fuerza y El Cubo, porque es lo que
-- planifica el club. Lo que uno hace por su cuenta no tiene por qué
-- estar en esa lista: la bici es el ejemplo que lo destapó.
--
-- Solo se AÑADEN valores a una lista que ya existía, así que ninguna
-- fila guardada deja de cumplir la condición.
--
-- `otro` está a propósito y no es pereza: sin él, quien va a remo o a
-- escalar tendría que mentir eligiendo el deporte más parecido, y un
-- dato falso ensucia más que un dato genérico.
alter table public.sesiones drop constraint if exists sesiones_deporte_check;
alter table public.sesiones add constraint sesiones_deporte_check
  check (deporte is null or deporte in ('atletismo','natacion','fuerza','cubo','bici','otro'));

-- El segundo deporte de un día doble se queda como estaba: eso lo
-- planifica el club, y ahí la lista corta es la buena.

-- ------------------------------------------------------------
-- 3 · QUIÉN PUEDE CREARLA
-- ------------------------------------------------------------
-- Las tres reglas que ya había no se tocan. Esta se SUMA, y es
-- estrecha a propósito: cada condición cierra una puerta concreta.
--
--   · origen = 'atleta'      · no puede colar algo que parezca del plan
--   · creado_por = yo        · queda su firma, y no puede fingir otra
--   · atletas_ids = [yo]     · SOLO PARA ÉL. Sin esto, un atleta podría
--                              crear un entrenamiento y dirigírselo a
--                              todo el grupo, que es mandar sobre los
--                              demás desde el portal del atleta.
--   · publicada = true       · si naciera sin publicar, ni él la vería:
--                              la regla de lectura exige `publicada`.
--   · sin inscripción        · no es un evento al que apuntarse.
--
-- `grupo_id` se deja libre —puede ir vacío—: hay socios sin grupo de
-- entrenamiento, y son justamente los que más van a usar esto.
drop policy if exists "el atleta apunta lo suyo" on public.sesiones;
create policy "el atleta apunta lo suyo" on public.sesiones
  for insert with check (
    origen = 'atleta'
    and publicada = true
    and creado_por = public.mi_perfil_id()
    and coalesce(abierta_inscripcion, false) = false
    and atletas_ids is not null
    and array_length(atletas_ids, 1) = 1
    and atletas_ids[1] in (select public.mis_atletas_entreno())
  );

-- Corregirla y borrarla: lo suyo y solo lo suyo. Un entrenamiento que
-- apuntaste mal tiene que poder arreglarse sin pedirle permiso a nadie,
-- igual que se corrige el feedback.
--
-- La condición se repite en el `with check` para que no pueda cambiarle
-- el `origen` a 'club' ni pasárselo a otro por el camino.
drop policy if exists "el atleta corrige lo suyo" on public.sesiones;
create policy "el atleta corrige lo suyo" on public.sesiones
  for update using (
    origen = 'atleta' and creado_por = public.mi_perfil_id()
  ) with check (
    origen = 'atleta'
    and creado_por = public.mi_perfil_id()
    and atletas_ids is not null
    and array_length(atletas_ids, 1) = 1
    and atletas_ids[1] in (select public.mis_atletas_entreno())
  );

drop policy if exists "el atleta borra lo suyo" on public.sesiones;
create policy "el atleta borra lo suyo" on public.sesiones
  for delete using (
    origen = 'atleta' and creado_por = public.mi_perfil_id()
  );

commit;

-- ============================================================
-- LO QUE ESTO NO ABRE
-- ------------------------------------------------------------
--   · No deja tocar NADA del plan del club. Las tres políticas nuevas
--     exigen `origen = 'atleta'` en el `using`, así que una sesión del
--     entrenador no entra por ninguna de ellas ni para leer de más, ni
--     para corregir, ni para borrar.
--   · No deja dirigir un entrenamiento a otra persona: `atletas_ids`
--     tiene que ser exactamente uno, y uno de los suyos.
--   · No cuenta como entrenamiento del club. Lo que decide si una
--     semana está cumplida sigue siendo lo que planificó el entrenador;
--     esto va al lado, marcado.
--
-- LO QUE FALTA, Y SE SABE
--   · Un atleta puede apuntarse una sesión en una fecha futura. No se
--     prohíbe porque «apuntar mañana la salida de mañana» es un uso
--     razonable, pero si algún día molesta, el sitio es el `with check`.
-- ============================================================
