-- ============================================================
-- 056 · CONFIRMAR ASISTENCIA · «¿vas?» a un evento del calendario
-- ------------------------------------------------------------
-- QUÉ RESUELVE:
--   Hoy el club no sabe cuánta gente va a una carrera, a un
--   desplazamiento o a un entreno especial hasta que la gente
--   aparece. Se pregunta por WhatsApp y se pierde entre mensajes.
--
-- CÓMO QUEDA:
--   A cualquier actividad que ya exista en el calendario —un evento
--   del club (tabla «eventos») o una competición (tabla
--   «competiciones»)— se le puede colgar UNA petición de
--   confirmación. Desde ese momento, a quien corresponda le sale
--   «¿vas?» con tres respuestas y ya está:
--       Voy  ·  No voy  ·  Aún no lo sé
--   con su fecha tope, sus plazas (autobús, coches) y una nota
--   corta opcional («voy con mi coche, llevo 3 sitios»).
--
-- LO QUE NO SE DUPLICA:
--   · El evento NO se copia: se apunta al que ya está en el
--     calendario. Si se borra el evento, se borra su confirmación.
--   · La inscripción a una competición sigue donde estaba
--     (competicion_atleta). Esto es otra cosa: apuntarse es «quiero
--     competir»; confirmar es «cuento contigo ese día». De hecho una
--     petición puede preguntar SOLO a los ya inscritos.
--   · La lista de clase de El Cubo y su lista de espera siguen
--     siendo suyas (cubo_reservas). Aquí no se toca nada de eso.
--
-- ⚠️ MENORES:
--   La confirmación de un menor la hace SU FAMILIA, no él. Un
--   atleta menor de edad no puede contestar por sí mismo aunque
--   tenga cuenta. Si el menor todavía no tiene familia enlazada
--   (atletas.perfil_padre_id vacío), NADIE de casa puede contestar:
--   contesta el club desde el panel, y la pantalla del panel avisa
--   de cuántos están en esa situación para que se enlace la familia.
--
-- QUIÉN ENTRA (candados RLS):
--   · Visitante sin cuenta (anon)  → NADA. Ni leer.
--   · Atleta mayor de edad         → su propia respuesta.
--   · Familia                      → las respuestas de sus hijos.
--   · Entrenador / coordinación    → las de sus atletas y grupos.
--   · Administración               → todo.
--   Escribir una respuesta se hace SIEMPRE por la función
--   conf_responder(): es la que reparte plazas y mueve la lista de
--   espera sin que dos personas puedan coger la misma plaza a la vez.
--
-- Idempotente: se puede relanzar sin perder nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/056_confirmaciones.sql
-- ============================================================

begin;

-- ============================================================
-- 1 · LA PETICIÓN · «este evento pide confirmación»
-- ============================================================
create table if not exists public.confirmaciones (
  id uuid primary key default gen_random_uuid(),

  -- A qué actividad se engancha. Exactamente una de las dos:
  -- o un evento del calendario, o una competición.
  evento_id      uuid references public.eventos(id)       on delete cascade,
  competicion_id uuid references public.competiciones(id) on delete cascade,

  -- La pregunta, si se quiere afinar. Vacío = «¿Vas?».
  pregunta   text,
  -- Recado del club que se lee antes de contestar: hora de quedada,
  -- dónde se sale, qué llevar…
  nota_club  text,

  -- Hasta cuándo se puede contestar. Vacío = sin fecha tope.
  fecha_limite timestamptz,

  -- Plazas (autobús, coches compartidos). Vacío = sin límite.
  -- Cuando se llenan, quien dice «voy» entra en lista de espera y
  -- sube solo en cuanto alguien se cae.
  plazas integer check (plazas is null or plazas >= 0),

  -- A quién se pregunta:
  --   'club'      → todos los atletas que no están de baja
  --   'grupos'    → solo los grupos de la columna «grupos»
  --   'inscritos' → solo quien ya está apuntado a esa competición o evento
  publico text not null default 'club'
          check (publico in ('club', 'grupos', 'inscritos')),
  grupos  uuid[],

  -- ¿Deja escribir la nota corta al contestar?
  permite_nota boolean not null default true,

  -- Se apaga sin borrar: deja de pedirse, pero las respuestas se quedan.
  abierta boolean not null default true,

  creado_por uuid references public.perfiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint confirmaciones_una_fuente
    check ((evento_id is not null)::int + (competicion_id is not null)::int = 1)
);

comment on table public.confirmaciones is
  'Una petición de «¿vas?» colgada de un evento del calendario o de una competición: fecha tope, plazas y a quién se pregunta. Las respuestas están en confirmaciones_respuestas.';

-- Columnas, por si la tabla venía de una pasada anterior.
alter table public.confirmaciones add column if not exists pregunta     text;
alter table public.confirmaciones add column if not exists nota_club    text;
alter table public.confirmaciones add column if not exists fecha_limite timestamptz;
alter table public.confirmaciones add column if not exists plazas       integer;
alter table public.confirmaciones add column if not exists publico      text not null default 'club';
alter table public.confirmaciones add column if not exists grupos       uuid[];
alter table public.confirmaciones add column if not exists permite_nota boolean not null default true;
alter table public.confirmaciones add column if not exists abierta      boolean not null default true;
alter table public.confirmaciones add column if not exists creado_por   uuid;
alter table public.confirmaciones add column if not exists updated_at   timestamptz not null default now();

-- Una sola petición por actividad: si no, habría dos «¿vas?» del mismo día.
create unique index if not exists confirmaciones_evento_uniq
  on public.confirmaciones (evento_id) where evento_id is not null;
create unique index if not exists confirmaciones_competicion_uniq
  on public.confirmaciones (competicion_id) where competicion_id is not null;

-- ============================================================
-- 2 · LAS RESPUESTAS · una fila por atleta
-- ============================================================
create table if not exists public.confirmaciones_respuestas (
  id uuid primary key default gen_random_uuid(),

  confirmacion_id uuid not null references public.confirmaciones(id) on delete cascade,
  atleta_id       uuid not null references public.atletas(id)        on delete cascade,

  respuesta text not null check (respuesta in ('voy', 'no_voy', 'no_lo_se')),

  -- La nota corta: «voy con mi coche, llevo 3 sitios», «llego tarde».
  nota text check (nota is null or char_length(nota) <= 140),

  -- true = dijo «voy» pero las plazas estaban llenas. Sube solo.
  en_espera boolean not null default false,

  -- Quién contestó (la madre, el propio atleta, el entrenador) y cuándo.
  respondido_por uuid references public.perfiles(id),
  respondido_en  timestamptz not null default now(),
  created_at     timestamptz not null default now(),

  unique (confirmacion_id, atleta_id)
);

comment on table public.confirmaciones_respuestas is
  'Qué ha contestado cada atleta a un «¿vas?»: voy, no voy o aún no lo sé, con su nota corta y, si había plazas limitadas, si tiene plaza o está en lista de espera.';

alter table public.confirmaciones_respuestas add column if not exists nota           text;
alter table public.confirmaciones_respuestas add column if not exists en_espera      boolean not null default false;
alter table public.confirmaciones_respuestas add column if not exists respondido_por uuid;
alter table public.confirmaciones_respuestas add column if not exists respondido_en  timestamptz not null default now();

create index if not exists confirmaciones_resp_conf_idx
  on public.confirmaciones_respuestas (confirmacion_id);
create index if not exists confirmaciones_resp_atleta_idx
  on public.confirmaciones_respuestas (atleta_id);
-- La cola de espera se sirve por orden de llegada.
create index if not exists confirmaciones_resp_cola_idx
  on public.confirmaciones_respuestas (confirmacion_id, en_espera, respondido_en);

-- updated_at de la petición, al día
create or replace function public.confirmaciones_toca_updated()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists confirmaciones_updated_trg on public.confirmaciones;
create trigger confirmaciones_updated_trg
  before update on public.confirmaciones
  for each row execute function public.confirmaciones_toca_updated();

-- ============================================================
-- 3 · AYUDANTES · quién es menor, quién ve y quién puede contestar
-- ============================================================

-- ¿Es menor de edad? Sin fecha de nacimiento no podemos saberlo: se
-- trata como mayor (si no, nadie podría contestar por él).
create or replace function public.conf_es_menor(p_atleta uuid)
returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.atletas a
    where a.id = p_atleta
      and a.fecha_nacimiento is not null
      and a.fecha_nacimiento > (current_date - interval '18 years')
  );
$$;

-- ¿Quién tiene que contestar por este atleta?
--   'familia' → es menor y tiene familia enlazada
--   'club'    → es menor y NO tiene familia enlazada (lo hace el club)
--   'atleta'  → es mayor de edad, contesta él
create or replace function public.conf_quien_responde(p_atleta uuid)
returns text
language sql stable security definer set search_path to 'public' as $$
  select case
           when not public.conf_es_menor(p_atleta) then 'atleta'
           when exists (select 1 from public.atletas a
                        where a.id = p_atleta and a.perfil_padre_id is not null) then 'familia'
           else 'club'
         end;
$$;

-- ¿Puedo VER lo de este atleta? Mismo reparto que la tabla «atletas»:
-- el propio atleta, su familia, su entrenador (por ficha o por grupo),
-- la coordinación de su sección y la administración.
create or replace function public.conf_ve_atleta(p_atleta uuid)
returns boolean
language sql stable security definer set search_path to 'public' as $$
  select public.es_admin() or exists (
    select 1 from public.atletas a
    where a.id = p_atleta
      and (
        a.perfil_id       = public.mi_perfil_id()
        or a.perfil_padre_id = public.mi_perfil_id()
        or a.entrenador_id   = public.mi_perfil_id()
        or exists (select 1 from public.grupos g
                   where g.id = a.grupo_id and g.entrenador_id = public.mi_perfil_id())
        or exists (select 1 from public.perfiles p
                   where p.email = (auth.jwt() ->> 'email')
                     and p.rol = 'coordinador' and p.seccion is not null
                     and exists (select 1 from public.grupos g
                                 where g.id = a.grupo_id and g.seccion = p.seccion))
      )
  );
$$;

-- ¿Soy staff (entrenador, coordinación o admin) DE este atleta?
-- Es quien puede contestar en nombre de cualquiera y fuera de plazo.
create or replace function public.conf_soy_su_staff(p_atleta uuid)
returns boolean
language sql stable security definer set search_path to 'public' as $$
  select public.es_admin() or (public.es_staff() and public.conf_ve_atleta(p_atleta));
$$;

-- ¿Puedo CONTESTAR por este atleta?
--   · El club (su entrenador, coordinación, administración): siempre.
--   · Menor  → solo su familia enlazada.
--   · Mayor  → él mismo (y su familia, si la tiene enlazada).
create or replace function public.conf_puede_responder(p_atleta uuid)
returns boolean
language sql stable security definer set search_path to 'public' as $$
  select public.conf_soy_su_staff(p_atleta)
      or exists (
        select 1 from public.atletas a
        where a.id = p_atleta
          and (
            a.perfil_padre_id = public.mi_perfil_id()
            or (not public.conf_es_menor(p_atleta) and a.perfil_id = public.mi_perfil_id())
          )
      );
$$;

-- ¿Sigue en plazo? (abierta y sin pasarse de la fecha tope)
create or replace function public.conf_en_plazo(p_confirmacion uuid)
returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.confirmaciones c
    where c.id = p_confirmacion
      and c.abierta
      and (c.fecha_limite is null or c.fecha_limite > now())
  );
$$;

-- A quién se le pregunta: la lista de atletas de los que se espera
-- respuesta. Siempre incluye a quien ya haya contestado, para que
-- nadie desaparezca de la lista al cambiar el público.
create or replace function public.conf_publico(p_confirmacion uuid)
returns setof uuid
language sql stable security definer set search_path to 'public' as $$
  with c as (select * from public.confirmaciones where id = p_confirmacion)
  select a.id
    from public.atletas a, c
   where coalesce(a.estado, 'activo') <> 'baja'
     and (
       (c.publico = 'club')
       or (c.publico = 'grupos' and a.grupo_id = any (coalesce(c.grupos, '{}'::uuid[])))
       or (c.publico = 'inscritos' and (
             exists (select 1 from public.competicion_atleta ca
                      where ca.competicion_id = c.competicion_id
                        and ca.atleta_id = a.id
                        and coalesce(ca.estado, 'apuntado') <> 'cancelada')
          or exists (select 1 from public.inscripciones_eventos ie
                      where ie.evento_id = c.evento_id
                        and ie.atleta_id = a.id
                        and coalesce(ie.estado, 'apuntado') <> 'baja')
          ))
     )
  union
  select r.atleta_id from public.confirmaciones_respuestas r
   where r.confirmacion_id = p_confirmacion;
$$;

-- ============================================================
-- 4 · RECUENTOS · lo que ve todo el mundo (cifras, sin nombres)
-- ============================================================
create or replace function public.conf_resumen(p_confirmacion uuid)
returns jsonb
language sql stable security definer set search_path to 'public' as $$
  with c as (select * from public.confirmaciones where id = p_confirmacion),
       r as (select * from public.confirmaciones_respuestas where confirmacion_id = p_confirmacion),
       e as (select count(*)::int n from public.conf_publico(p_confirmacion))
  select jsonb_build_object(
    'id',            c.id,
    'abierta',       c.abierta,
    'en_plazo',      (c.abierta and (c.fecha_limite is null or c.fecha_limite > now())),
    'fecha_limite',  c.fecha_limite,
    'plazas',        c.plazas,
    'voy',           (select count(*) from r where r.respuesta = 'voy')::int,
    'con_plaza',     (select count(*) from r where r.respuesta = 'voy' and not r.en_espera)::int,
    'en_espera',     (select count(*) from r where r.respuesta = 'voy' and r.en_espera)::int,
    'no_voy',        (select count(*) from r where r.respuesta = 'no_voy')::int,
    'no_lo_se',      (select count(*) from r where r.respuesta = 'no_lo_se')::int,
    'contestados',   (select count(*) from r)::int,
    'esperados',     e.n,
    'faltan',        greatest(0, e.n - (select count(*) from r))::int,
    'libres',        case when c.plazas is null then null
                          else greatest(0, c.plazas - (select count(*) from r
                                                       where r.respuesta = 'voy' and not r.en_espera))::int end
  )
  from c, e;
$$;

-- ============================================================
-- 5 · LA LISTA CON NOMBRES · solo para el club
-- ============================================================
-- Quién va, quién no y quién falta por contestar. Un entrenador solo
-- ve a los suyos; la administración, a todos. Una familia no entra
-- aquí: ella ve sus respuestas leyendo la tabla directamente.
create or replace function public.conf_lista(p_confirmacion uuid)
returns table (
  atleta_id uuid,
  nombre text,
  apellidos text,
  categoria text,
  grupo text,
  respuesta text,
  nota text,
  en_espera boolean,
  respondido_en timestamptz,
  respondido_por text,
  quien_responde text,
  es_menor boolean,
  sin_familia boolean
)
language sql stable security definer set search_path to 'public' as $$
  select a.id,
         a.nombre,
         coalesce(a.apellidos, ''),
         a.categoria,
         g.nombre,
         r.respuesta,
         r.nota,
         coalesce(r.en_espera, false),
         r.respondido_en,
         nullif(trim(coalesce(p.nombre, '') || ' ' || coalesce(p.apellidos, '')), ''),
         public.conf_quien_responde(a.id),
         public.conf_es_menor(a.id),
         (public.conf_es_menor(a.id) and a.perfil_padre_id is null)
    from public.conf_publico(p_confirmacion) as pub(id)
    join public.atletas a on a.id = pub.id
    left join public.grupos g on g.id = a.grupo_id
    left join public.confirmaciones_respuestas r
           on r.confirmacion_id = p_confirmacion and r.atleta_id = a.id
    left join public.perfiles p on p.id = r.respondido_por
   where public.es_staff() and public.conf_ve_atleta(a.id)
   order by (r.respuesta is null) desc, a.apellidos, a.nombre;
$$;

-- ============================================================
-- 6 · CONTESTAR · la única puerta de escritura
-- ============================================================
-- Aquí es donde se reparte la plaza o se entra en la lista de espera,
-- y donde sube el primero de la cola en cuanto alguien se cae. Se hace
-- con la petición bloqueada (for update) para que dos móviles que
-- pulsan «Voy» a la vez no cojan la misma plaza.
create or replace function public.conf_responder(
  p_confirmacion uuid,
  p_atleta       uuid,
  p_respuesta    text,
  p_nota         text default null
)
returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  v_conf     public.confirmaciones;
  v_antes    public.confirmaciones_respuestas;
  v_espera   boolean := false;
  v_ocupadas int;
  v_nota     text;
  v_staff    boolean;
begin
  if p_respuesta not in ('voy', 'no_voy', 'no_lo_se') then
    raise exception 'Respuesta no válida: usa voy, no_voy o no_lo_se.' using errcode = 'P0001';
  end if;

  -- La petición, bloqueada mientras repartimos plazas.
  select * into v_conf from public.confirmaciones where id = p_confirmacion for update;
  if not found then
    raise exception 'Esa confirmación ya no existe.' using errcode = 'P0001';
  end if;

  -- ¿Puede contestar por este atleta? (menor → su familia)
  if not public.conf_puede_responder(p_atleta) then
    if public.conf_es_menor(p_atleta) then
      raise exception 'La confirmación de un menor la hace su familia.' using errcode = 'P0001';
    end if;
    raise exception 'No puedes contestar por ese atleta.' using errcode = 'P0001';
  end if;

  -- Plazo: el club puede apuntar respuestas fuera de plazo; las familias no.
  v_staff := public.conf_soy_su_staff(p_atleta);
  if not v_staff then
    if not v_conf.abierta then
      raise exception 'Esta confirmación ya está cerrada.' using errcode = 'P0001';
    end if;
    if v_conf.fecha_limite is not null and v_conf.fecha_limite <= now() then
      raise exception 'El plazo para contestar terminó.' using errcode = 'P0001';
    end if;
  end if;

  v_nota := nullif(btrim(coalesce(p_nota, '')), '');
  if not v_conf.permite_nota then v_nota := null; end if;
  if v_nota is not null and char_length(v_nota) > 140 then
    v_nota := left(v_nota, 140);
  end if;

  select * into v_antes
    from public.confirmaciones_respuestas
   where confirmacion_id = p_confirmacion and atleta_id = p_atleta;

  -- ¿Le toca plaza o lista de espera?
  if p_respuesta = 'voy' and v_conf.plazas is not null then
    if v_antes.id is not null and v_antes.respuesta = 'voy' and not v_antes.en_espera then
      v_espera := false;                       -- ya tenía plaza: se la queda
    else
      select count(*) into v_ocupadas
        from public.confirmaciones_respuestas
       where confirmacion_id = p_confirmacion
         and respuesta = 'voy' and not en_espera
         and atleta_id <> p_atleta;
      v_espera := (v_ocupadas >= v_conf.plazas);
    end if;
  end if;

  if v_antes.id is null then
    insert into public.confirmaciones_respuestas
      (confirmacion_id, atleta_id, respuesta, nota, en_espera, respondido_por, respondido_en)
    values
      (p_confirmacion, p_atleta, p_respuesta, v_nota, v_espera, public.mi_perfil_id(), now());
  else
    update public.confirmaciones_respuestas
       set respuesta      = p_respuesta,
           nota           = case when v_conf.permite_nota and p_nota is null then nota else v_nota end,
           en_espera      = v_espera,
           respondido_por = public.mi_perfil_id(),
           respondido_en  = now()
     where id = v_antes.id;
  end if;

  -- Si se ha liberado plaza (dejó de ir alguien que la tenía), sube el
  -- primero de la cola. Se hace en bucle por si el hueco da para varios.
  if v_conf.plazas is not null then
    loop
      select count(*) into v_ocupadas
        from public.confirmaciones_respuestas
       where confirmacion_id = p_confirmacion and respuesta = 'voy' and not en_espera;
      exit when v_ocupadas >= v_conf.plazas;

      update public.confirmaciones_respuestas
         set en_espera = false
       where id = (
         select id from public.confirmaciones_respuestas
          where confirmacion_id = p_confirmacion and respuesta = 'voy' and en_espera
          order by respondido_en, created_at
          limit 1
       );
      exit when not found;
    end loop;
  end if;

  return public.conf_resumen(p_confirmacion)
         || jsonb_build_object(
              'atleta_id', p_atleta,
              'respuesta', p_respuesta,
              'en_espera', (select en_espera from public.confirmaciones_respuestas
                             where confirmacion_id = p_confirmacion and atleta_id = p_atleta)
            );
end;
$$;

-- ============================================================
-- 7 · CANDADOS (RLS)
-- ============================================================
alter table public.confirmaciones             enable row level security;
alter table public.confirmaciones_respuestas  enable row level security;

-- --- La petición ---------------------------------------------------
-- La lee cualquiera que haya entrado con su cuenta (necesita saber la
-- fecha tope y si quedan plazas). El visitante sin cuenta, no.
drop policy if exists "confirmaciones lectura con cuenta" on public.confirmaciones;
create policy "confirmaciones lectura con cuenta"
  on public.confirmaciones for select
  to authenticated
  using (true);

-- Crearlas y cambiarlas: administración.
drop policy if exists "confirmaciones admin gestiona" on public.confirmaciones;
create policy "confirmaciones admin gestiona"
  on public.confirmaciones for all
  to authenticated
  using (es_admin())
  with check (es_admin());

-- --- Las respuestas ------------------------------------------------
-- Ver: la mía, la de mis hijos, las de mis atletas y grupos; admin, todas.
drop policy if exists "confirmaciones respuestas lectura" on public.confirmaciones_respuestas;
create policy "confirmaciones respuestas lectura"
  on public.confirmaciones_respuestas for select
  to authenticated
  using (conf_ve_atleta(atleta_id));

-- Escribir a mano: solo administración (para arreglar cosas desde el
-- panel). Todo lo demás pasa por conf_responder(), que es quien reparte
-- las plazas y mueve la lista de espera.
drop policy if exists "confirmaciones respuestas admin gestiona" on public.confirmaciones_respuestas;
create policy "confirmaciones respuestas admin gestiona"
  on public.confirmaciones_respuestas for all
  to authenticated
  using (es_admin())
  with check (es_admin());

-- ============================================================
-- 8 · PERMISOS · Supabase reparte de más; aquí se recorta
-- ------------------------------------------------------------
-- Supabase concede permisos automáticamente a «anon» y a
-- «authenticated» sobre las tablas nuevas del esquema public. En este
-- proyecto ya nos ha pasado dos veces: hay que quitarlos a mano.
-- ============================================================
revoke all on table public.confirmaciones            from anon, public;
revoke all on table public.confirmaciones_respuestas from anon, public;

grant select                         on public.confirmaciones            to authenticated;
grant insert, update, delete         on public.confirmaciones            to authenticated;
grant select                         on public.confirmaciones_respuestas to authenticated;
grant insert, update, delete         on public.confirmaciones_respuestas to authenticated;

-- Las funciones nacen con permiso para todo el mundo: se retira y se
-- da solo a quien ha entrado con su cuenta.
revoke all on function public.conf_es_menor(uuid)                     from public, anon;
revoke all on function public.conf_quien_responde(uuid)               from public, anon;
revoke all on function public.conf_ve_atleta(uuid)                    from public, anon;
revoke all on function public.conf_soy_su_staff(uuid)                 from public, anon;
revoke all on function public.conf_puede_responder(uuid)              from public, anon;
revoke all on function public.conf_en_plazo(uuid)                     from public, anon;
revoke all on function public.conf_publico(uuid)                      from public, anon;
revoke all on function public.conf_resumen(uuid)                      from public, anon;
revoke all on function public.conf_lista(uuid)                        from public, anon;
revoke all on function public.conf_responder(uuid, uuid, text, text)  from public, anon;
revoke all on function public.confirmaciones_toca_updated()           from public, anon;

grant execute on function public.conf_es_menor(uuid)                    to authenticated;
grant execute on function public.conf_quien_responde(uuid)              to authenticated;
grant execute on function public.conf_ve_atleta(uuid)                   to authenticated;
grant execute on function public.conf_soy_su_staff(uuid)                to authenticated;
grant execute on function public.conf_puede_responder(uuid)             to authenticated;
grant execute on function public.conf_en_plazo(uuid)                    to authenticated;
grant execute on function public.conf_publico(uuid)                     to authenticated;
grant execute on function public.conf_resumen(uuid)                     to authenticated;
grant execute on function public.conf_lista(uuid)                       to authenticated;
grant execute on function public.conf_responder(uuid, uuid, text, text) to authenticated;

commit;

-- ============================================================
-- CÓMO SE COMPRUEBA (copiar y pegar en psql; todo con ROLLBACK)
-- ------------------------------------------------------------
--   -- El visitante sin cuenta no puede ni mirar:
--   begin; set local role anon;
--   select * from public.confirmaciones;            -- permiso denegado
--   rollback;
--
--   -- Una familia contesta por su hijo menor:
--   begin; set local role authenticated;
--   set local request.jwt.claims to '{"email":"madre@ejemplo.com","role":"authenticated"}';
--   select public.conf_responder('<confirmacion>', '<atleta>', 'voy', 'vamos en mi coche');
--   rollback;
-- ============================================================
