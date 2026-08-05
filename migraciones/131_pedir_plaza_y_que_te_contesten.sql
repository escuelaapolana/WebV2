-- ============================================================
-- 131 · Pedir plaza en una actividad, y que alguien conteste
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Hoy una actividad del calendario solo tiene dos posturas: o se
-- apunta quien quiera, o no se apunta nadie. No hay término medio, y
-- el término medio es justo lo que pasa de verdad en el club: una
-- salida a la montaña, un entrenamiento con la pista medio ocupada,
-- una tirada larga con doce sitios y veinte interesados. Ahí quien
-- la ha montado quiere mirar la lista y decir quién va.
--
-- LO QUE SE AÑADE
-- Un tercer estado. Los tres, con el nombre que ve la gente:
--
--     Cerrada ............... es de su grupo y punto
--     Abierta ............... te apuntas y ya está
--     Hay que pedir plaza ... lo pides y contestan
--
-- «Hay que pedir plaza» dice las dos cosas que hacen falta: que tu
-- toque no te mete, y que hay alguien al otro lado. «Opcional» no
-- valía porque no dice quién decide, y ese es todo el asunto.
--
-- ------------------------------------------------------------
-- LO QUE YA HABÍA Y NO SE ROMPE
-- ------------------------------------------------------------
-- La columna de siempre, `abierta_inscripcion`, se queda donde está
-- y sigue significando lo mismo: «esto sale en el calendario del
-- club». La leen la vista `sesiones_agenda`, el calendario del
-- portal y la pantalla del entrenador, y ninguna se entera de nada.
--
-- Las dos columnas se mantienen cuadradas solas, con un disparador:
--
--     cerrada ............ abierta_inscripcion = no
--     abierta ............ abierta_inscripcion = sí
--     hay que pedir plaza  abierta_inscripcion = sí
--
-- Y en los dos sentidos: quien guarde con la forma antigua —marcar
-- la casilla «¿Abierto para apuntarse?» sin saber que existe un
-- tercer estado— deja la actividad en «Abierta», que es lo que esa
-- casilla ha querido decir siempre. Esto importa porque el editor de
-- entrenamientos todavía no conoce el estado nuevo: hasta que lo
-- conozca, sigue funcionando exactamente igual que ayer.
--
-- Con una excepción a propósito: si la actividad ya está en «hay que
-- pedir plaza» y se vuelve a guardar desde el editor viejo con la
-- casilla marcada, se queda como estaba. El editor viejo no sabe de
-- este estado, así que no puede borrarlo sin querer.
--
-- LAS INSCRIPCIONES DE HOY SON «ACEPTADAS» DE TODA LA VIDA
-- La columna nueva de `sesion_inscripciones` nace valiendo
-- «aceptada». Quien estaba apuntado sigue apuntado, con su plaza y
-- sin tener que pedir nada. No hay ni una fila que se quede en el
-- aire.
--
-- ------------------------------------------------------------
-- LAS PLAZAS · LO PENDIENTE NO OCUPA SITIO
-- ------------------------------------------------------------
-- Decisión, y es la que más se nota: en una actividad de «hay que
-- pedir plaza», las peticiones sin contestar NO gastan plaza. El
-- tope solo cuenta a los aceptados.
--
-- Por qué. Si lo pendiente ocupara sitio, las diez primeras personas
-- que tocasen el botón llenarían el cupo y la número once no podría
-- ni pedirlo. Eso convierte en una carrera de dedos justo lo que se
-- ha montado para que lo decida una persona: quien puso el tope de
-- diez lo puso para elegir diez, no para premiar a quien mira el
-- móvil más rápido. Con esta regla, quien la lleva ve las quince
-- peticiones juntas y reparte.
--
-- Lo que el tope sí hace: no se puede aceptar por encima de él. Al
-- llegar a diez aceptados, el botón de aceptar deja de funcionar y
-- lo dice. Las que queden pendientes siguen ahí, se pueden rechazar
-- o esperar por si alguien se cae.
--
-- Y en una actividad «abierta» no cambia nada de nada: todo el que
-- entra entra como aceptado, y el tope se comporta igual que ayer.
--
-- Por eso el calendario, cuando hay tope, tiene que decir las dos
-- cifras: «6 de 10 plazas · 9 esperando respuesta». Con una sola,
-- alguien se cree que hay cuatro sitios libres para él.
--
-- ------------------------------------------------------------
-- QUIÉN DECIDE
-- ------------------------------------------------------------
-- Las sesiones sí guardan quién las creó (`creado_por`), pero está
-- vacío en las que genera el horario solo, que son la mayoría. Así
-- que quien decide es, por este orden y sin exclusiva:
--
--   1. quien creó la actividad (`sesiones.creado_por`)
--   2. el entrenador del grupo al que pertenece
--   3. administración
--
-- Los dos primeros son la respuesta a los dos casos que no son lo
-- mismo: el entrenamiento de un grupo lo decide su entrenador
-- aunque lo generase el horario, y una salida al monte la decide
-- quien la montó, tenga grupo o no.
--
-- Y de aquí en adelante `creado_por` se rellena solo al crear una
-- sesión, con quien esté delante. Así una actividad suelta, sin
-- grupo, siempre tiene dueño desde el primer día.
--
-- ------------------------------------------------------------
-- RECHAZAR ES DARLE UNA MALA NOTICIA A UN CRÍO
-- ------------------------------------------------------------
-- Se puede escribir el porqué, y viaja con la respuesta. Cuando no
-- se escribe nada, el texto que sale por defecto no da un portazo:
-- dice que esta vez no ha podido ser y deja la puerta abierta a
-- preguntar. Y una decisión se puede cambiar: un «no» de hace dos
-- días se convierte en un «sí» si se cae alguien.
--
-- ------------------------------------------------------------
-- QUE SE ENTEREN LOS DOS LADOS
-- ------------------------------------------------------------
-- No se monta ningún sistema de avisos nuevo. Se usan los avisos
-- del club de siempre (migraciones 054, 083 y 120) y, para no hacer
-- ruido, LA MISMA REGLA de las altas: un aviso por bandeja, ninguno
-- más hasta que la bandeja se vacíe, se insiste una vez a las doce
-- horas y de noche no suena nada. Literalmente las mismas dos
-- funciones —`novedades_decide` y `novedades_hora_decente`—, sin
-- copiarlas ni reescribirlas. Lo único distinto es que aquí la
-- bandeja es de una persona y no del club entero, porque las
-- peticiones de una actividad son de quien la lleva.
--
-- Los dos avisos:
--   · a quien decide ... «Te han pedido plaza», categoría gestión,
--                        con la regla del ruido puesta.
--   · a quien pidió .... «Tienes plaza» o «No ha podido ser»,
--                        categoría entrenamientos, siempre, sin
--                        regla de ruido: es una respuesta, no una
--                        bandeja, y llega una sola vez.
--
-- Si el atleta es menor y su ficha cuelga de la cuenta de un padre,
-- el aviso va a las dos cuentas. Un crío de catorce puede no entrar
-- en la app en tres días; su padre sí.
--
-- SI EL AVISO FALLA, LA PETICIÓN NO SE PIERDE
-- Los dos avisos van envueltos: si algo revienta al escribirlos, se
-- traga el fallo y la petición (o la respuesta) se guarda igual. Un
-- problema del buzón no puede deshacer lo que alguien acaba de
-- pedir. Es lo mismo que se hizo en la migración 120.
--
-- ------------------------------------------------------------
-- COMPROBADO CONTRA LA BASE, SIMULANDO LOS PAPELES
-- ------------------------------------------------------------
-- Las comprobaciones van en el informe, con los números delante. La
-- primera de todas, la que hay que demostrar antes que ninguna: un
-- atleta no puede aceptarse a sí mismo.
--
-- Todo el fichero se puede volver a pasar las veces que haga falta.
-- ============================================================

begin;

-- ============================================================
-- 1 · EL TERCER ESTADO, EN LA ACTIVIDAD
-- ============================================================

alter table public.sesiones
  add column if not exists inscripcion text not null default 'cerrada';

-- Se rellena a partir de lo que ya había ANTES de poner la regla, o
-- las que estén abiertas hoy no pasarían el corte.
update public.sesiones
   set inscripcion = case when coalesce(abierta_inscripcion, false) then 'abierta' else 'cerrada' end
 where inscripcion not in ('abierta', 'con_permiso')
    or inscripcion is null;

alter table public.sesiones drop constraint if exists sesiones_inscripcion_check;
alter table public.sesiones add constraint sesiones_inscripcion_check
  check (inscripcion in ('cerrada', 'abierta', 'con_permiso'));

comment on column public.sesiones.inscripcion is
  'Quién puede entrar: cerrada (solo su grupo), abierta (se apunta quien quiera) o con_permiso (se pide plaza y contesta quien la lleva).';

-- ------------------------------------------------------------
-- 1.b · Las dos columnas, siempre cuadradas
-- ------------------------------------------------------------
-- `abierta_inscripcion` la leen media docena de pantallas y la vista
-- de la agenda. En vez de cambiarlas todas, se deja que la calcule
-- la base: así ninguna se entera de que existe un tercer estado y
-- ninguna se rompe.
create or replace function public.sesiones_inscripcion_encaja()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if TG_OP = 'INSERT' then
    -- Al crear, quien manda es el estado nuevo si lo han puesto. Si
    -- viene en «cerrada» —que es el valor de fábrica— es que quien
    -- guarda no sabe que existe, y entonces manda la casilla vieja.
    if NEW.inscripcion is null or NEW.inscripcion = 'cerrada' then
      NEW.inscripcion := case when coalesce(NEW.abierta_inscripcion, false) then 'abierta' else 'cerrada' end;
    end if;

    -- Toda actividad nace con dueño: quien la está creando. Si la
    -- genera sola el horario del grupo no hay nadie delante y se
    -- queda vacío, que para eso está el entrenador del grupo.
    NEW.creado_por := coalesce(NEW.creado_por, public.mi_perfil_id());

  else
    -- Al guardar cambios: si han tocado el estado nuevo, manda él.
    -- Si no lo han tocado pero han movido la casilla vieja, manda la
    -- casilla. Y si no han tocado ninguna de las dos, se queda como
    -- estaba: esto es lo que impide que el editor de siempre, que
    -- manda la casilla marcada en cada guardado, convierta un «hay
    -- que pedir plaza» en un «abierta» sin querer.
    if NEW.inscripcion is not distinct from OLD.inscripcion
       and coalesce(NEW.abierta_inscripcion, false) is distinct from coalesce(OLD.abierta_inscripcion, false) then
      NEW.inscripcion := case when coalesce(NEW.abierta_inscripcion, false) then 'abierta' else 'cerrada' end;
    end if;
  end if;

  -- Y la casilla vieja siempre sale de aquí, nunca al revés.
  NEW.abierta_inscripcion := (NEW.inscripcion <> 'cerrada');
  return NEW;
end;
$$;

comment on function public.sesiones_inscripcion_encaja() is
  'Mantiene cuadradas la casilla de siempre y el estado nuevo, en los dos sentidos, para que las pantallas que solo conocen la casilla sigan funcionando.';

drop trigger if exists trg_sesiones_inscripcion on public.sesiones;
create trigger trg_sesiones_inscripcion
  before insert or update on public.sesiones
  for each row execute function public.sesiones_inscripcion_encaja();

-- ============================================================
-- 2 · EL ESTADO DE CADA PETICIÓN
-- ============================================================
-- Nace en «aceptada» a propósito: las inscripciones que ya existen
-- son gente que YA tiene su plaza, y al añadir la columna se quedan
-- exactamente igual que estaban.
alter table public.sesion_inscripciones
  add column if not exists estado       text not null default 'aceptada',
  add column if not exists motivo       text,
  add column if not exists decidida_en  timestamptz,
  add column if not exists decidida_por uuid references public.perfiles(id);

alter table public.sesion_inscripciones drop constraint if exists sesion_inscripciones_estado_check;
alter table public.sesion_inscripciones add constraint sesion_inscripciones_estado_check
  check (estado in ('pendiente', 'aceptada', 'rechazada'));

comment on column public.sesion_inscripciones.estado is
  'pendiente (pedida y sin contestar), aceptada (tiene plaza) o rechazada. Lo de antes de esta migración es aceptada.';
comment on column public.sesion_inscripciones.motivo is
  'Lo que quien decide le escribe a quien pidió la plaza. Se ve tal cual en el aviso.';

-- Buscar lo pendiente es lo que más se va a hacer, y siempre por
-- sesión.
create index if not exists idx_sesion_inscripciones_estado
  on public.sesion_inscripciones (sesion_id, estado);

-- ============================================================
-- 3 · QUIÉN DECIDE
-- ============================================================

-- Los perfiles que pueden contestar a las peticiones de una
-- actividad. Devuelve personas, no permisos: la usan los avisos para
-- saber a quién escribir.
create or replace function public.quien_decide_sesion(p_sesion uuid)
returns setof uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select distinct x from (
    select s.creado_por as x
      from public.sesiones s
     where s.id = p_sesion
    union
    select g.entrenador_id
      from public.sesiones s
      join public.grupos g on g.id = s.grupo_id
     where s.id = p_sesion
  ) t
  where x is not null;
$$;

comment on function public.quien_decide_sesion(uuid) is
  'Quién puede contestar a las peticiones de esa actividad: quien la creó y el entrenador de su grupo.';

-- ¿Puedo contestar YO a las peticiones de esta actividad? Es la
-- pregunta que se hacen los permisos y las pantallas.
create or replace function public.puede_decidir_sesion(p_sesion uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.es_admin()
      or (public.mi_perfil_id() is not null
          and public.mi_perfil_id() in (select public.quien_decide_sesion(p_sesion)));
$$;

comment on function public.puede_decidir_sesion(uuid) is
  'Sí o no: si quien está delante puede aceptar o rechazar las peticiones de esa actividad.';

-- Las funciones nacen cerradas (migración 090). Esta hay que abrirla a
-- quien tiene cuenta porque la usan los permisos de la tabla, y los
-- permisos se miran con el nombre de quien está delante, no con el de
-- la función. `quien_decide_sesion` se queda cerrada: solo la llaman
-- funciones de dentro, y devuelve una lista de personas.
grant execute on function public.puede_decidir_sesion(uuid) to authenticated;

-- ============================================================
-- 4 · CONTAR PLAZAS · SOLO CUENTAN LAS ACEPTADAS
-- ============================================================
-- Aquí es donde vive la decisión de las plazas. Se cambia en un solo
-- sitio y lo hereda todo lo demás: la vista de la agenda, el
-- calendario y el aviso de «completo».
create or replace function public.sesion_num_apuntados(p_sesion uuid)
returns integer
language sql
stable
security definer
set search_path to 'public'
as $$
  select count(*)::integer
    from public.sesion_inscripciones i
   where i.sesion_id = p_sesion
     and i.estado = 'aceptada';
$$;

comment on function public.sesion_num_apuntados(uuid) is
  'Cuánta gente tiene plaza de verdad. Lo pendiente de contestar no cuenta: si contase, los primeros dedos llenarían el cupo y nadie más podría ni pedirla.';

-- Y la otra mitad de la verdad, para poder decir las dos cifras.
create or replace function public.sesion_num_pendientes(p_sesion uuid)
returns integer
language sql
stable
security definer
set search_path to 'public'
as $$
  select count(*)::integer
    from public.sesion_inscripciones i
   where i.sesion_id = p_sesion
     and i.estado = 'pendiente';
$$;

comment on function public.sesion_num_pendientes(uuid) is
  'Cuántas peticiones esperan respuesta. Sin esta cifra el calendario diría «4 plazas libres» a quince personas a la vez.';

grant execute on function public.sesion_num_pendientes(uuid) to anon, authenticated;

-- La agenda del club, con las dos cifras y el estado nuevo.
drop view if exists public.sesiones_agenda;
create view public.sesiones_agenda as
  select s.id as sesion_id,
         s.fecha,
         s.hora,
         s.titulo,
         s.tipo,
         s.rol,
         s.lugar,
         s.grupo_id,
         g.nombre as grupo,
         g.seccion,
         coalesce(s.abierta_inscripcion, false) as abierta_inscripcion,
         s.inscripcion,
         s.abierta_a,
         s.plazas,
         public.sesion_num_apuntados(s.id)  as apuntados,
         public.sesion_num_pendientes(s.id) as pendientes,
         case when s.plazas is null then null::integer
              else greatest(0, s.plazas - public.sesion_num_apuntados(s.id))
         end as libres,
         s.deporte,
         s.deporte_2,
         s.papel_dia
    from public.sesiones s
    left join public.grupos g on g.id = s.grupo_id
   where coalesce(s.publicada, false)
     and (s.atletas_ids is null or coalesce(s.abierta_inscripcion, false));

grant select on public.sesiones_agenda to anon, authenticated;

-- ============================================================
-- 5 · ¿PUEDO PEDIR SITIO EN ESTA ACTIVIDAD?
-- ============================================================
-- La misma comprobación de siempre —publicada, en el futuro y de mi
-- sección—, con una sola diferencia: ahora vale tanto la actividad
-- abierta como la de pedir plaza. Lo que cambia entre las dos no es
-- si puedes llamar a la puerta, es qué pasa después.
create or replace function public.sesion_abierta_para(p_sesion uuid, p_atleta uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1
      from public.sesiones s
     where s.id = p_sesion
       and coalesce(s.publicada, false)
       and s.inscripcion in ('abierta', 'con_permiso')
       and s.fecha >= current_date
       and (
         s.abierta_a is null
         or exists (
           select 1 from public.grupos g
            where g.id in (select public.grupos_del_atleta(p_atleta))
              and g.seccion = any (s.abierta_a)
         )
       )
  );
$$;

comment on function public.sesion_abierta_para(uuid, uuid) is
  'Si ese atleta puede al menos pedir sitio: publicada, en el futuro y de una sección a la que esté abierta. Que se lo den o no es otra cosa.';

-- ============================================================
-- 6 · EL CONTROL AL APUNTARSE · EL ESTADO NO LO ELIGE QUIEN PIDE
-- ============================================================
-- Esto es lo que hace que un atleta no pueda darse la plaza a sí
-- mismo. La columna `estado` se puede escribir desde el navegador
-- como cualquier otra, así que aquí se pisa con lo que dice la
-- actividad, sin mirar lo que haya mandado nadie.
create or replace function public.sesion_inscripciones_control()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_sesion    public.sesiones;
  v_aceptadas integer;
  v_manda     boolean;
begin
  -- Cerrojo por sesión: dos personas a la vez no cogen la misma plaza.
  perform pg_advisory_xact_lock(hashtextextended(NEW.sesion_id::text, 0));

  select * into v_sesion from public.sesiones where id = NEW.sesion_id;
  if not found then
    raise exception 'Esa actividad ya no existe.' using errcode = 'P0001';
  end if;

  v_manda := public.puede_decidir_sesion(NEW.sesion_id);

  if TG_OP = 'INSERT' then
    if not coalesce(v_sesion.publicada, false) or v_sesion.inscripcion = 'cerrada' then
      raise exception 'Esa actividad no está abierta para apuntarse.' using errcode = 'P0001';
    end if;

    if v_sesion.fecha < current_date then
      raise exception 'Esa actividad ya ha pasado.' using errcode = 'P0001';
    end if;

    -- Basta con entrenar en UN grupo de la sección a la que está
    -- abierta (migración 111).
    if v_sesion.abierta_a is not null then
      if not exists (
        select 1
          from public.grupos g
         where g.id in (select public.grupos_del_atleta(NEW.atleta_id))
           and g.seccion = any (v_sesion.abierta_a)
      ) then
        raise exception 'Esa actividad es solo para: %.', array_to_string(v_sesion.abierta_a, ', ')
          using errcode = 'P0001';
      end if;
    end if;

    -- EL ESTADO LO PONE LA ACTIVIDAD, NO QUIEN SE APUNTA.
    -- Quien lleva la actividad sí puede meter a alguien ya aceptado:
    -- es su decisión, y la está tomando.
    if not v_manda then
      NEW.estado := case when v_sesion.inscripcion = 'con_permiso' then 'pendiente' else 'aceptada' end;
      NEW.motivo       := null;
      NEW.decidida_en  := null;
      NEW.decidida_por := null;
    end if;

  else
    -- Cambiar una decisión ya tomada solo lo hace quien puede
    -- decidir. El atleta no tiene permiso de cambio ninguno, pero
    -- esto lo deja dicho también aquí, que es donde se mira.
    if not v_manda and NEW.estado is distinct from OLD.estado then
      raise exception 'Solo puede aceptar o rechazar quien lleva la actividad.' using errcode = 'P0001';
    end if;
  end if;

  -- EL TOPE · solo cuenta a los que tienen plaza. Lo pendiente no
  -- ocupa sitio, así que quince pueden pedir diez plazas.
  if NEW.estado = 'aceptada'
     and v_sesion.plazas is not null
     and (TG_OP = 'INSERT' or OLD.estado is distinct from 'aceptada') then
    select count(*) into v_aceptadas
      from public.sesion_inscripciones i
     where i.sesion_id = NEW.sesion_id
       and i.estado = 'aceptada'
       and i.id <> NEW.id;

    if v_aceptadas >= v_sesion.plazas then
      raise exception 'Esa actividad está completa: ya no quedan plazas.'
        using errcode = 'P0001';
    end if;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_sesion_inscripciones_control on public.sesion_inscripciones;
create trigger trg_sesion_inscripciones_control
  before insert or update on public.sesion_inscripciones
  for each row execute function public.sesion_inscripciones_control();

-- ============================================================
-- 7 · PERMISOS
-- ============================================================

-- Quien lleva la actividad ve TODAS sus peticiones, también las de
-- atletas de otros entrenadores. Es inevitable: para decir que sí o
-- que no a alguien hay que saber quién es. Lo que no se abre es la
-- ficha del atleta: los nombres salen por la puerta del punto 8,
-- que devuelve el nombre y nada más.
drop policy if exists "quien lleva la actividad ve sus peticiones" on public.sesion_inscripciones;
create policy "quien lleva la actividad ve sus peticiones" on public.sesion_inscripciones
for select to authenticated
using (public.puede_decidir_sesion(sesion_id));

-- Quitarse: lo pendiente y lo aceptado, sí. Lo rechazado no se
-- borra. Si se pudiera, bastaría con borrarlo para volver a pedir lo
-- mismo una y otra vez, y quien decide acabaría contestando cinco
-- veces al mismo. Si el «no» fue un error, quien lleva la actividad
-- lo cambia a «sí» desde su pantalla.
drop policy if exists "quitarme de un entreno" on public.sesion_inscripciones;
create policy "quitarme de un entreno" on public.sesion_inscripciones
for delete to authenticated
using (
  atleta_id in (select public.mis_atletas())
  and estado in ('pendiente', 'aceptada')
  and exists (
    select 1 from public.sesiones s
     where s.id = sesion_inscripciones.sesion_id
       and s.fecha >= current_date
  )
);

-- ============================================================
-- 8 · LA LISTA DE PETICIONES, PARA QUIEN DECIDE
-- ============================================================
-- Una sola puerta y cerrada con llave: devuelve solo las peticiones
-- de actividades que quien pregunta puede decidir, y de cada persona
-- solo su nombre y su grupo. Ni teléfono, ni correo, ni fecha de
-- nacimiento. Lo justo para poner cara a quien te está pidiendo ir.
create or replace function public.sesion_solicitudes(p_desde date default null)
returns table (
  id            uuid,
  sesion_id     uuid,
  fecha         date,
  hora          time,
  titulo        text,
  lugar         text,
  grupo         text,
  inscripcion   text,
  plazas        integer,
  aceptadas     integer,
  pendientes    integer,
  atleta_id     uuid,
  atleta        text,
  atleta_grupo  text,
  estado        text,
  motivo        text,
  pedida_en     timestamptz,
  decidida_en   timestamptz,
  decidida_por  text
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select i.id,
         s.id,
         s.fecha,
         s.hora,
         coalesce(nullif(btrim(s.titulo), ''), 'Actividad'),
         s.lugar,
         g.nombre,
         s.inscripcion,
         s.plazas,
         public.sesion_num_apuntados(s.id),
         public.sesion_num_pendientes(s.id),
         a.id,
         btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')),
         ga.nombre,
         i.estado,
         i.motivo,
         i.created_at,
         i.decidida_en,
         p.nombre
    from public.sesion_inscripciones i
    join public.sesiones s  on s.id = i.sesion_id
    join public.atletas   a  on a.id = i.atleta_id
    left join public.grupos g  on g.id = s.grupo_id
    left join public.grupos ga on ga.id = a.grupo_id
    left join public.perfiles p on p.id = i.decidida_por
   where s.inscripcion = 'con_permiso'
     and s.fecha >= coalesce(p_desde, current_date)
     and public.puede_decidir_sesion(s.id)
   order by (i.estado = 'pendiente') desc, s.fecha, s.hora, i.created_at;
$$;

comment on function public.sesion_solicitudes(date) is
  'Las peticiones de plaza de las actividades que llevas. De cada persona, su nombre y su grupo: lo justo para decidir, y nada más.';

revoke all on function public.sesion_solicitudes(date) from public, anon;
grant execute on function public.sesion_solicitudes(date) to authenticated;

-- ============================================================
-- 9 · LA REGLA DEL RUIDO, PERO POR PERSONA
-- ============================================================
-- Las bandejas de la migración 120 son del club: «hay altas sin
-- revisar» le vale igual a cualquiera de administración. Esta es de
-- una persona: las peticiones de mi actividad son mías y no de mi
-- compañero. Por eso hace falta una fila por persona.
--
-- Lo que NO cambia es la regla, que es lo que costó pensar: se
-- llaman las mismas dos funciones de la 120, sin copiar ni una
-- línea. Si algún día se decide que sean nueve horas en vez de doce,
-- se toca en un sitio y cambia en los dos.
create table if not exists public.avisos_novedades_persona (
  tipo        text not null check (tipo in ('solicitud_plaza')),
  perfil_id   uuid not null references public.perfiles(id) on delete cascade,
  avisado_en  timestamptz,
  primary key (tipo, perfil_id)
);

comment on table public.avisos_novedades_persona is
  'Cuándo se avisó por última vez a cada persona de su bandeja. Que treinta peticiones en una tarde no sean treinta avisos.';

alter table public.avisos_novedades_persona enable row level security;

-- Nadie escribe aquí desde el navegador: lo lleva el disparador de
-- más abajo, que entra por dentro. Se deja mirar la propia fila para
-- poder comprobar que los avisos salen.
drop policy if exists "veo cuando me avisaron" on public.avisos_novedades_persona;
create policy "veo cuando me avisaron" on public.avisos_novedades_persona
for select to authenticated
using (perfil_id = public.mi_perfil_id());

-- Cuántas peticiones esperan respuesta de esta persona, y de cuándo
-- es la más vieja. Las dos juntas porque la regla necesita las dos.
create or replace function public.solicitudes_sin_contestar(p_perfil uuid)
returns table (cuantas integer, la_mas_vieja timestamptz)
language sql
stable
security definer
set search_path to 'public'
as $$
  select count(*)::integer, min(i.created_at)
    from public.sesion_inscripciones i
    join public.sesiones s on s.id = i.sesion_id
    left join public.grupos g on g.id = s.grupo_id
   where i.estado = 'pendiente'
     and s.fecha >= current_date
     and (s.creado_por = p_perfil or g.entrenador_id = p_perfil);
$$;

comment on function public.solicitudes_sin_contestar(uuid) is
  'Cuántas peticiones esperan a esa persona y de cuándo es la más antigua. Es lo que decide si toca avisar o sería ruido.';

-- La misma mecánica del punto 4 de la migración 120: se coge la fila
-- de esa persona, se le pregunta a la regla de siempre y, si dice
-- que sí, se deja apuntado que se avisó. Todo dentro del mismo
-- cerrojo, para que dos peticiones a la vez no manden dos avisos.
create or replace function public.solicitudes_toca_avisar(p_perfil uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path to 'public'
as $$
declare
  v_avisado   timestamptz;
  v_cuantas   integer;
  v_mas_vieja timestamptz;
begin
  if p_perfil is null then
    return false;
  end if;

  -- De noche no, y se mira lo primero: se sale sin tocar nada, el
  -- aviso no se gasta y sale con el primer movimiento de la mañana.
  if not public.novedades_hora_decente(now()) then
    return false;
  end if;

  insert into public.avisos_novedades_persona (tipo, perfil_id)
  values ('solicitud_plaza', p_perfil)
  on conflict (tipo, perfil_id) do nothing;

  select avisado_en into v_avisado
    from public.avisos_novedades_persona
   where tipo = 'solicitud_plaza' and perfil_id = p_perfil
     for update;

  select cuantas, la_mas_vieja into v_cuantas, v_mas_vieja
    from public.solicitudes_sin_contestar(p_perfil);

  -- No queda nada esperando: se borra la marca para que la siguiente
  -- avise sin esperar a nada.
  if coalesce(v_cuantas, 0) = 0 then
    update public.avisos_novedades_persona
       set avisado_en = null
     where tipo = 'solicitud_plaza' and perfil_id = p_perfil;
    return false;
  end if;

  if public.novedades_decide(v_avisado, v_cuantas, v_mas_vieja, now()) then
    update public.avisos_novedades_persona
       set avisado_en = now()
     where tipo = 'solicitud_plaza' and perfil_id = p_perfil;
    return true;
  end if;

  return false;
end;
$$;

comment on function public.solicitudes_toca_avisar(uuid) is
  'Sí o no, con la regla de las altas: un aviso, ninguno más hasta vaciar la bandeja o pasar doce horas, y nunca de noche.';

revoke all on function public.solicitudes_toca_avisar(uuid) from public, anon, authenticated;

-- ============================================================
-- 10 · LOS AVISOS DE «GESTIÓN» TAMBIÉN VALEN PARA ESTO
-- ============================================================
-- El interruptor «gestión» nació en la 120 para las altas y los
-- pedidos. Esto es lo mismo: trabajo del club que espera a que
-- alguien lo mire. Se reutiliza en vez de inventar un sexto tema que
-- nadie sabría distinguir del quinto.
--
-- El historial de avisos no lo aceptaba porque nació con cinco temas
-- y «gestión» se añadió después solo a las preferencias. Se abre.
alter table public.avisos_enviados drop constraint if exists avisos_enviados_categoria_check;
alter table public.avisos_enviados add constraint avisos_enviados_categoria_check
  check (categoria in ('entrenos', 'competiciones', 'pagos', 'noticias', 'retos', 'gestion'));

-- ============================================================
-- 11 · EL AVISO A QUIEN DECIDE, AL ENTRAR UNA PETICIÓN
-- ============================================================
-- Va DESPUÉS de guardar y envuelto: si el buzón falla, la petición
-- ya está guardada y no se deshace. Lo mismo que se hizo con las
-- altas en la 120: un fallo del aviso no puede parecer que lo que
-- has pedido no se ha guardado.
create or replace function public.sesion_solicitud_avisa()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_perfil uuid;
begin
  if NEW.estado <> 'pendiente' then
    return null;
  end if;

  begin
    for v_perfil in select public.quien_decide_sesion(NEW.sesion_id) loop
      if public.solicitudes_toca_avisar(v_perfil) then
        perform public.avisos_registrar(
          'Te han pedido plaza',
          'Tienes peticiones sin contestar en tus actividades.',
          'portal/solicitudes/',
          'persona', 'gestion',
          null, null, v_perfil,
          'Solo para ti',
          0, 0, null, null, 'informativo', null, true, '{}'
        );
      end if;
    end loop;
  exception when others then
    -- Ni una palabra: la plaza pedida está guardada, que es lo que
    -- importa. El número de verdad lo dice la pantalla al entrar.
    null;
  end;

  return null;
end;
$$;

comment on function public.sesion_solicitud_avisa() is
  'Avisa a quien lleva la actividad de que le han pedido plaza, con la regla del ruido puesta y sin poder romper lo que se acaba de guardar.';

drop trigger if exists trg_sesion_solicitud_avisa on public.sesion_inscripciones;
create trigger trg_sesion_solicitud_avisa
  after insert on public.sesion_inscripciones
  for each row execute function public.sesion_solicitud_avisa();

-- ============================================================
-- 12 · ACEPTAR O RECHAZAR
-- ============================================================
-- La única puerta para cambiar una decisión. El «quién» y el
-- «cuándo» los pone la base a partir de quien está delante, no el
-- navegador: así no hay forma de firmar una decisión con el nombre
-- de otro.
create or replace function public.sesion_solicitud_decidir(
  p_id     uuid,
  p_estado text,
  p_motivo text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path to 'public'
as $$
declare
  v_fila    public.sesion_inscripciones;
  v_sesion  public.sesiones;
  v_yo      uuid := public.mi_perfil_id();
  v_motivo  text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_titulo  text;
  v_cuerpo  text;
  v_perfil  uuid;
begin
  if p_estado not in ('aceptada', 'rechazada', 'pendiente') then
    raise exception 'Eso no es una respuesta.' using errcode = 'P0001';
  end if;

  select * into v_fila from public.sesion_inscripciones where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'Esa petición ya no está.');
  end if;

  -- ESTO ES LO PRIMERO QUE HAY QUE DEMOSTRAR: quien no lleva la
  -- actividad no decide, y da igual que la petición sea suya.
  if not public.puede_decidir_sesion(v_fila.sesion_id) then
    raise exception 'Esta actividad no la llevas tú: no puedes contestar a sus peticiones.'
      using errcode = 'P0001';
  end if;

  select * into v_sesion from public.sesiones where id = v_fila.sesion_id;

  update public.sesion_inscripciones
     set estado       = p_estado,
         motivo       = case when p_estado = 'pendiente' then null else v_motivo end,
         decidida_en  = case when p_estado = 'pendiente' then null else now() end,
         decidida_por = case when p_estado = 'pendiente' then null else v_yo end
   where id = p_id;
  -- Si se pasa del tope, el control del punto 6 corta aquí mismo y
  -- la respuesta no se guarda. Es a propósito: mejor un mensaje de
  -- «está completa» que once personas con plaza en diez sitios.

  -- El aviso a quien pidió la plaza. Envuelto, por lo de siempre:
  -- la decisión ya está tomada y no se deshace porque falle el buzón.
  if p_estado <> 'pendiente' then
    begin
      if p_estado = 'aceptada' then
        v_titulo := 'Tienes plaza';
        v_cuerpo := 'Te han dado plaza en «' || coalesce(nullif(btrim(v_sesion.titulo), ''), 'la actividad') ||
                    '» del ' || to_char(v_sesion.fecha, 'DD/MM') ||
                    coalesce('. ' || v_motivo, '');
      else
        v_titulo := 'No ha podido ser';
        -- El texto de por defecto no da un portazo: dice que fue esta
        -- vez y deja abierta la puerta de preguntar.
        v_cuerpo := 'Esta vez no ha salido la plaza en «' || coalesce(nullif(btrim(v_sesion.titulo), ''), 'la actividad') ||
                    '» del ' || to_char(v_sesion.fecha, 'DD/MM') || '. ' ||
                    coalesce(v_motivo, 'Habrá más días: pregunta a tu entrenador y buscamos otro.');
      end if;

      -- A su cuenta y a la de su familia. Un crío de catorce puede
      -- tardar tres días en abrir la app; su padre no.
      for v_perfil in
        select x from (
          select a.perfil_id as x from public.atletas a where a.id = v_fila.atleta_id
          union
          select a.perfil_padre_id from public.atletas a where a.id = v_fila.atleta_id
        ) t where x is not null
      loop
        perform public.avisos_registrar(
          v_titulo, v_cuerpo, 'portal/calendario/',
          'persona', 'entrenos',
          null, null, v_perfil,
          'Solo para ti',
          0, 0, v_yo, null, 'informativo', null, true, '{}'
        );
      end loop;
    exception when others then
      null;
    end;
  end if;

  return jsonb_build_object('ok', true, 'estado', p_estado);
end;
$$;

comment on function public.sesion_solicitud_decidir(uuid, text, text) is
  'Aceptar, rechazar o volver a dejar pendiente una petición de plaza, y avisar a quien la pidió. Solo la puede llamar quien lleva la actividad.';

revoke all on function public.sesion_solicitud_decidir(uuid, text, text) from public, anon;
grant execute on function public.sesion_solicitud_decidir(uuid, text, text) to authenticated;

-- Cuántas peticiones tengo yo sin contestar. Es el número de la
-- pastilla del portal: se pide suelto porque se pide en pantallas
-- que no cargan la lista entera.
create or replace function public.mis_solicitudes_sin_contestar()
returns integer
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce((select cuantas from public.solicitudes_sin_contestar(public.mi_perfil_id())), 0);
$$;

comment on function public.mis_solicitudes_sin_contestar() is
  'Cuántas peticiones de plaza esperan respuesta mía. Para la cifra que se ve al entrar al portal.';

revoke all on function public.mis_solicitudes_sin_contestar() from public, anon;
grant execute on function public.mis_solicitudes_sin_contestar() to authenticated;

commit;
