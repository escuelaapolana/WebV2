-- ============================================================
-- 118 · Quien lleva el grupo ve lo del grupo
-- ------------------------------------------------------------
-- DE DÓNDE VIENE ESTO
-- La 116 dejó que una persona entrene en dos grupos. La 117 dejó
-- que el entrenador del segundo grupo le pase lista. Al mirarlo de
-- cerca aparecieron dos agujeros que dejaban lo anterior a medias,
-- y los dos van del mismo hilo: hay cosas que son DEL GRUPO y que
-- seguían atadas a quién figura en la ficha del atleta.
--
-- ------------------------------------------------------------
-- AGUJERO 1 · EL «HOY NO VIENE» NO LO VEÍA CASI NADIE
-- Cuando una familia avisa de que su hijo no va a ir, eso se
-- guarda en `ausencias`. Y de ahí solo podían leerlo
-- administración, la propia familia y el entrenador ESCRITO EN LA
-- FICHA. Cualquier otro entrenador —incluido el del grupo donde el
-- crío entrena de verdad— pasaba lista sin enterarse.
--
-- Lo que eso significa en la pista: la madre avisa por la mañana,
-- el entrenador no lo ve por ninguna parte y le pone falta. Al
-- crío le queda una falta sin justificar por haber avisado bien.
-- Pasar lista sin ver quién ha avisado es peor que no pasarla.
--
-- ⚠️ Y AQUÍ HAY UNA LÍNEA QUE NO SE CRUZA
-- El motivo de una falta es a menudo salud: «está malo», «tiene
-- fiebre», «va al médico». Eso NO es del grupo, es de la familia y
-- de quien lleva a ese chaval. Así que se parte en dos:
--
--   · QUE no viene   → lo ve el entrenador del grupo. Es lo que
--                      necesita para no ponerle falta.
--   · POR QUÉ no viene y quién avisó → solo quien ya podía leerlo:
--                      administración y el entrenador de su ficha.
--
-- Por eso esto NO se arregla abriendo la tabla: abrir la tabla
-- abre también el motivo, y con él la salud de un menor. Se hace
-- con una función que devuelve lo uno y calla lo otro, y la tabla
-- se queda cerrada exactamente como estaba.
--
-- ------------------------------------------------------------
-- AGUJERO 2 · APUNTAR A ALGUIEN AL ENTRENAMIENTO
-- Es el hermano gemelo de pasar lista: decidir quién va al
-- entrenamiento de tu grupo es la misma clase de decisión que
-- decir quién ha venido. Y estaba con la puerta de siempre, así
-- que el entrenador del grupo no podía apuntar a los suyos.
-- Se le pone el mismo criterio y el mismo alcance que a la lista.
--
-- ------------------------------------------------------------
-- LO QUE SIGUE SIN TOCARSE, A PROPÓSITO
-- ESCRIBIR una ausencia a nombre de otro (que es lo que hace el
-- portal cuando el entrenador pasa un entrenamiento a otro día)
-- sigue pidiendo ser el entrenador de la ficha. Ver no es
-- escribir, y este cambio es solo de ver. Igual que las notas del
-- atleta, las lesiones, las notas para la familia, el contacto de
-- la familia, apuntar a alguien en un grupo, los bonos, las
-- inscripciones a competiciones y el perfil de juego: todo eso se
-- queda donde estaba.
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta. No borra ni una fila.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LAS FALTAS AVISADAS DE MIS GRUPOS
-- ------------------------------------------------------------
-- Se le pide por los grupos que uno lleva y por un día. De cada
-- grupo que sea mío devuelve quién ha avisado de que no va. De los
-- que no son míos, nada: ni una fila, sin dar error, porque
-- preguntar por un grupo ajeno no es un fallo, es que no te toca.
--
-- El motivo y el nombre de quien avisó salen SOLO si quien
-- pregunta ya podía leerlos por la vía normal. Al entrenador del
-- grupo le llegan vacíos, y su pantalla dirá «no viene» y punto.
-- Con eso no le pone falta a quien avisó, que es todo lo que hace
-- falta para pasar bien la lista.
--
-- Sale también el grupo en cada fila: quien entrena en dos de mis
-- grupos aparece dos veces, una por lista, que es como se pasan.
--
-- ⚠️ `security definer` con `search_path` clavado (migraciones 090
-- y 106): es lo que le deja mirar la tabla de ausencias, que está
-- cerrada, para enseñar solo el trozo que corresponde.
create or replace function public.apo_faltas_avisadas(
  p_grupos uuid[],
  p_fecha  date
)
returns table (
  atleta_id          uuid,
  grupo_id           uuid,
  motivo             text,
  avisado_por_nombre text
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select au.atleta_id,
         g.id as grupo_id,
         case when public.soy_staff_de_atleta(au.atleta_id) then au.motivo             end,
         case when public.soy_staff_de_atleta(au.atleta_id) then au.avisado_por_nombre end
    from public.grupos g
    join public.ausencias au
      on au.fecha = p_fecha
     and g.id in (select public.grupos_del_atleta(au.atleta_id))
   where g.id = any (coalesce(p_grupos, array[]::uuid[]))
     and (public.es_admin() or g.entrenador_id = public.mi_perfil_id());
$$;

comment on function public.apo_faltas_avisadas(uuid[], date) is
  'Quién ha avisado de que no va a venir, por grupo y día, para el entrenador '
  'que lleva ese grupo. Dice QUE no viene —lo que hace falta para no ponerle '
  'falta a quien avisó— pero calla POR QUÉ salvo a quien ya podía leerlo: el '
  'motivo suele ser salud y eso no es del grupo.';

-- ⚠️ EL PERMISO NO VIENE SOLO (migración 090): en esta base las
-- funciones nacen cerradas.
revoke execute on function public.apo_faltas_avisadas(uuid[], date) from public, anon;
grant  execute on function public.apo_faltas_avisadas(uuid[], date) to authenticated;

-- La tabla `ausencias` NO se toca. Ni una regla, ni un permiso. Se
-- deja dicho aquí para que quede claro que es una decisión y no un
-- olvido: abrirla habría abierto el motivo con ella.

-- ------------------------------------------------------------
-- 2 · APUNTAR A LOS MÍOS AL ENTRENAMIENTO DE MI GRUPO
-- ------------------------------------------------------------
-- Misma forma que `puedo_pasar_lista` (migración 117): la puerta de
-- siempre, o LAS DOS cosas a la vez —el entrenamiento es de un
-- grupo que dirijo yo, y esa persona entrena de verdad en ese
-- grupo—. Con solo la primera, un entrenador podría meter en su
-- entrenamiento a cualquiera del club; con solo la segunda,
-- cualquiera podría tocar la lista de otro.
create or replace function public.puedo_apuntar_al_entreno(p_atleta uuid, p_sesion uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.soy_staff_de_atleta(p_atleta)
      or exists (
        select 1
          from public.sesiones s
          join public.grupos  g on g.id = s.grupo_id
         where s.id = p_sesion
           and g.entrenador_id = public.mi_perfil_id()
           and s.grupo_id in (select public.grupos_del_atleta(p_atleta))
      );
$$;

comment on function public.puedo_apuntar_al_entreno(uuid, uuid) is
  'Si puedo apuntar o quitar a esta persona de ESTE entrenamiento. Vale la '
  'puerta de siempre y además el entrenador del grupo del entrenamiento, '
  'siempre que la persona entrene de verdad en ese grupo. Mismo criterio que '
  'para pasar lista: quien dirige el grupo decide quién va a lo suyo.';

revoke execute on function public.puedo_apuntar_al_entreno(uuid, uuid) from public, anon;
grant  execute on function public.puedo_apuntar_al_entreno(uuid, uuid) to authenticated;

-- La regla del equipo técnico sobre los apuntados, y solo esa. Las
-- otras tres de esta tabla —administración, apuntarme yo, quitarme
-- yo— se quedan como estaban.
drop policy if exists "staff gestiona apuntados" on public.sesion_inscripciones;
create policy "staff gestiona apuntados"
  on public.sesion_inscripciones for all to authenticated
  using      (public.puedo_apuntar_al_entreno(atleta_id, sesion_id))
  with check (public.puedo_apuntar_al_entreno(atleta_id, sesion_id));

-- ------------------------------------------------------------
-- 3 · Y UN CANDADO QUE MIRABA UNA SOLA CASILLA
-- ------------------------------------------------------------
-- Apareció al probar lo de arriba, y sin esto lo de arriba no
-- llega a servir. Cuando un entrenamiento se abre «solo para
-- running» o «solo para El Cubo» (migración 025), la base
-- comprobaba de qué sección es esa persona mirando el grupo de su
-- FICHA y nada más.
--
-- O sea: el crío que hace running en La Tribu y además va a El
-- Cubo no podía apuntarse a un entrenamiento abierto a El Cubo,
-- porque su ficha dice «running». La base le decía que ese
-- entrenamiento no era para él, en el grupo donde entrena.
--
-- Se cambia UNA cosa: en vez de la casilla, todos sus grupos. Lo
-- demás de este candado —que esté publicado, abierto, que no haya
-- pasado ya y que queden plazas— se queda exactamente igual.
create or replace function public.sesion_inscripciones_control()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_sesion    public.sesiones;
  v_apuntados integer;
begin
  -- Cerrojo por sesión: dos personas a la vez no cogen la misma plaza.
  perform pg_advisory_xact_lock(hashtextextended(NEW.sesion_id::text, 0));

  select * into v_sesion from public.sesiones where id = NEW.sesion_id;
  if not found then
    raise exception 'Ese entrenamiento ya no existe.' using errcode = 'P0001';
  end if;

  if not coalesce(v_sesion.publicada, false) or not coalesce(v_sesion.abierta_inscripcion, false) then
    raise exception 'Ese entrenamiento no está abierto para apuntarse.' using errcode = 'P0001';
  end if;

  if v_sesion.fecha < current_date then
    raise exception 'Ese entrenamiento ya ha pasado.' using errcode = 'P0001';
  end if;

  -- LO QUE CAMBIA. Antes: «la sección del grupo de su ficha». Ahora: «la
  -- sección de CUALQUIERA de sus grupos». Basta con que entrene en un grupo
  -- de la sección a la que está abierto el entrenamiento.
  if v_sesion.abierta_a is not null then
    if not exists (
      select 1
        from public.grupos g
       where g.id in (select public.grupos_del_atleta(NEW.atleta_id))
         and g.seccion = any (v_sesion.abierta_a)
    ) then
      raise exception 'Ese entrenamiento es solo para: %.', array_to_string(v_sesion.abierta_a, ', ')
        using errcode = 'P0001';
    end if;
  end if;

  if v_sesion.plazas is not null then
    select count(*) into v_apuntados
      from public.sesion_inscripciones i
     where i.sesion_id = NEW.sesion_id
       and i.id <> NEW.id;

    if v_apuntados >= v_sesion.plazas then
      raise exception 'Ese entrenamiento está completo: ya no quedan plazas.'
        using errcode = 'P0001';
    end if;
  end if;

  return NEW;
end;
$$;

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- la tabla de ausencias sigue cerrada: nadie nuevo entra por ahí
--   select policyname, cmd, qual from pg_policies
--    where schemaname = 'public' and tablename = 'ausencias';
--
--   -- y con los papeles puestos, en una transacción que se deshace:
--   begin; set local role authenticated;
--     set local request.jwt.claims to '{"email":"…","role":"authenticated"}';
--     select * from apo_faltas_avisadas(array['<grupo>']::uuid[], current_date);
--   rollback;
-- ------------------------------------------------------------
