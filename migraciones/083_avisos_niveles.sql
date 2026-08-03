-- ============================================================
-- 083 · AVISOS CON TRES NIVELES · informativo, importante, grave
-- ------------------------------------------------------------
-- (El 082 lo ocupa 082_mis_avisos.sql. Este es el siguiente libre.)
--
-- QUÉ RESUELVE, EN CRISTIANO
--   Hasta hoy todos los avisos se veían igual. Si «mañana no hay
--   entreno» y «se suspende la temporada por temporal» llegan con la
--   misma cara, en dos semanas nadie mira los avisos. La maqueta del
--   diseñador («4 · Avisos y pagos», apartado A) ordena tres niveles:
--
--     · informativo → novedades y crónicas. La mayoría.
--     · importante  → cambia tu plan de esta semana. El de diario.
--     · grave       → seguridad y nada más.
--
--   Y el color nunca va solo: siempre lleva la palabra escrita, porque
--   una parte de los socios no distingue bien el ámbar del rojo. Eso es
--   de la pantalla; aquí abajo va lo que la pantalla necesita saber.
--
-- LO QUE SE AÑADE
--   1 · `avisos_enviados.nivel`             el nivel del aviso.
--   2 · `avisos_enviados.caduca_el`         hasta cuándo vale. Sin este
--       dato no se puede escribir «Ya pasó» y hay que tacharlo a mano.
--   3 · `avisos_enviados.al_movil`          si además sonó en el móvil.
--   4 · `avisos_enviados.grupos_excluidos`  los grupos que se quitaron.
--   5 · `avisos_leidos`                     quién ha leído qué.
--   6 · `avisos_puede_enviar()`             quién puede mandar avisos.
--   7 · `mis_avisos()` devuelve nivel, caducado, leído y remitente.
--   8 · `avisos_marcar_leido()`             marcar uno o todos.
--
-- DOS DECISIONES DEL CLUB QUE ESTÁN AQUÍ DENTRO
--   · MANDAR AVISOS ES DE ADMINISTRACIÓN Y TESORERÍA. De los tres
--     niveles, incluido el informativo. Los entrenadores no mandan
--     avisos. La barrera está en la base (`avisos_puede_enviar`), no
--     en esconder el botón: esconderlo es cortesía, no seguridad.
--   · LA PREFERENCIA DE CADA PERSONA MANDA SIEMPRE. Quien apagó una
--     categoría no recibe nada de esa categoría, tampoco si es grave.
--     Eso ya lo hace `avisos_quiere()` (054) y aquí no se toca: lo
--     único que se añade es poder QUITAR grupos de un aviso grave.
--
-- ⚠️ SUPABASE REPARTE PERMISOS DE SERIE en todo lo nuevo: EXECUTE a
--   PUBLIC en cada función y los GRANT de tabla a `anon` y
--   `authenticated`. No basta con no conceder: hay que QUITAR y luego
--   conceder solo a quien toca. Van seis incidentes por esto.
--
-- Idempotente: se puede relanzar sin perder nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/083_avisos_niveles.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LAS CASILLAS NUEVAS DEL AVISO
-- ------------------------------------------------------------
alter table public.avisos_enviados
  add column if not exists nivel            text        not null default 'informativo',
  add column if not exists caduca_el        date,
  add column if not exists al_movil         boolean     not null default true,
  add column if not exists grupos_excluidos uuid[]      not null default '{}';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'avisos_enviados_nivel_check') then
    alter table public.avisos_enviados
      add constraint avisos_enviados_nivel_check
      check (nivel in ('informativo','importante','grave'));
  end if;
end $$;

comment on column public.avisos_enviados.nivel is
  'informativo (por defecto) | importante | grave. Decide el color de la banda Y la palabra escrita. El color nunca va solo.';
comment on column public.avisos_enviados.caduca_el is
  'Último día en que el aviso sigue valiendo. Pasado ese día la app lo enseña tachado y con «Ya pasó» delante, pero NO lo borra: borrarlo hace dudar de si lo leíste o te lo inventaste.';
comment on column public.avisos_enviados.al_movil is
  'true = además se intentó hacerlo sonar en el móvil. false = solo queda en la app. Lo elige quien escribe, aviso a aviso; en los graves va siempre a true.';
comment on column public.avisos_enviados.grupos_excluidos is
  'Grupos a los que NO va, aunque el aviso sea para todo el club. Es el reparto al revés de los avisos graves: se parte de todos y se descartan los que no aplican.';

-- Los avisos que ya existen se quedan como estaban: informativos, sin
-- caducidad y con el móvil marcado (que es lo que de hecho pasó).
update public.avisos_enviados set nivel = 'informativo' where nivel is null;

create index if not exists avisos_enviados_nivel_idx on public.avisos_enviados (nivel);


-- ------------------------------------------------------------
-- 2 · QUIÉN HA LEÍDO QUÉ
-- ------------------------------------------------------------
-- Una fila por persona y aviso. No hay «no leído» guardado: no leído es
-- no tener fila. Así nadie tiene que crear filas al mandar el aviso.
create table if not exists public.avisos_leidos (
  aviso_id  uuid        not null references public.avisos_enviados(id) on delete cascade,
  perfil_id uuid        not null references public.perfiles(id)        on delete cascade,
  leido_el  timestamptz not null default now(),
  primary key (aviso_id, perfil_id)
);

comment on table public.avisos_leidos is
  'Qué avisos ha abierto cada persona. Solo se escribe desde avisos_marcar_leido(); nadie la toca directamente desde el navegador.';

create index if not exists avisos_leidos_perfil_idx on public.avisos_leidos (perfil_id);

alter table public.avisos_leidos enable row level security;

-- ⚠️ Aquí está el fallo que ya ha vuelto seis veces. Supabase concede
-- de serie a `anon` y `authenticated` sobre cada tabla nueva. Se quita
-- TODO y no se devuelve nada: a esta tabla solo llegan las funciones
-- de abajo, que van con `security definer` y saben de quién es cada
-- fila. Sin RLS que dejar pasar y sin GRANT, no hay puerta.
revoke all on table public.avisos_leidos from public;
revoke all on table public.avisos_leidos from anon;
revoke all on table public.avisos_leidos from authenticated;

-- Y sin ninguna política: con RLS encendida y cero políticas, la tabla
-- está cerrada para todo el mundo menos para su dueño (postgres), que
-- es quien ejecuta las funciones `security definer`.


-- ------------------------------------------------------------
-- 3 · QUIÉN PUEDE MANDAR AVISOS
-- ------------------------------------------------------------
-- Decisión del club: administración y tesorería. Nadie más, y de
-- ningún nivel. Se mira el papel con el que la persona está actuando
-- ahora mismo (`rol_activo`), igual que `es_admin()` (migración 071):
-- quien es entrenador y además tesorero tiene que estar EN tesorería
-- para poder mandar.
create or replace function public.avisos_puede_enviar()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.perfiles p
     where p.email = (auth.jwt() ->> 'email')
       and coalesce(p.activo, true)
       and coalesce(p.rol_activo, p.rol) in ('admin','tesoreria')
  );
$function$;

comment on function public.avisos_puede_enviar() is
  'true si quien llama puede mandar avisos al club: administración o tesorería, y con ese papel puesto. Los entrenadores no mandan avisos.';

revoke all on function public.avisos_puede_enviar() from public;
revoke all on function public.avisos_puede_enviar() from anon;
grant execute on function public.avisos_puede_enviar() to authenticated;


-- ------------------------------------------------------------
-- 4 · LOS GRUPOS DE UNA PERSONA
-- ------------------------------------------------------------
-- Hace falta para poder QUITAR grupos de un aviso: entrena en montaña,
-- su hijo está en la escuela, entrena al grupo de pista…
create or replace function public.avisos_grupos_de(p_perfil uuid)
returns setof uuid
language sql
stable
security definer
set search_path to 'public'
as $function$
  select a.grupo_id from public.atletas a
   where a.grupo_id is not null
     and (a.perfil_id = p_perfil or a.perfil_padre_id = p_perfil)
  union
  select g.id from public.grupos g where g.entrenador_id = p_perfil;
$function$;

comment on function public.avisos_grupos_de(uuid) is
  'Los grupos con los que una persona tiene algo que ver: donde entrena, donde entrena su hijo, o los que entrena ella.';

revoke all on function public.avisos_grupos_de(uuid) from public;
revoke all on function public.avisos_grupos_de(uuid) from anon;
revoke all on function public.avisos_grupos_de(uuid) from authenticated;
grant execute on function public.avisos_grupos_de(uuid) to service_role;


-- ------------------------------------------------------------
-- 5 · A QUIÉN VA, DESCONTANDO LOS GRUPOS QUITADOS
-- ------------------------------------------------------------
-- Los avisos graves se reparten al revés: van a todo el club y se
-- quitan los grupos a los que no aplica («se cierra la piscina» no le
-- importa a los de montaña).
--
-- LA REGLA, QUE TIENE MIGA: solo se descarta a quien está ÚNICAMENTE
-- en grupos quitados. El chaval que hace pista y montaña sigue
-- recibiéndolo si se quitó montaña, porque lo suyo de pista sigue en
-- pie. Y quien no tiene grupo (administración, socios sueltos) nunca
-- se descarta: no se le puede quitar de un sitio en el que no está.
create or replace function public.avisos_destino_perfiles(
  p_publico text,
  p_grupo   uuid,
  p_rol     text,
  p_perfil  uuid,
  p_excluir uuid[] default '{}'
)
returns setof uuid
language sql
stable
security definer
set search_path to 'public'
as $function$
  select d
    from public.avisos_perfiles_destino(p_publico, p_grupo, p_rol, p_perfil) d
   where coalesce(array_length(p_excluir, 1), 0) = 0
      or not (
           exists (select 1 from public.avisos_grupos_de(d) g)
       and not exists (
             select 1 from public.avisos_grupos_de(d) g
              where not (g = any(p_excluir)))
      );
$function$;

comment on function public.avisos_destino_perfiles(text, uuid, text, uuid, uuid[]) is
  'A quién va un aviso, ya descontados los grupos que se hayan quitado. Solo se descarta a quien está únicamente en grupos quitados.';

revoke all on function public.avisos_destino_perfiles(text, uuid, text, uuid, uuid[]) from public;
revoke all on function public.avisos_destino_perfiles(text, uuid, text, uuid, uuid[]) from anon;
revoke all on function public.avisos_destino_perfiles(text, uuid, text, uuid, uuid[]) from authenticated;
grant execute on function public.avisos_destino_perfiles(text, uuid, text, uuid, uuid[]) to service_role;


-- ------------------------------------------------------------
-- 6 · A CUÁNTOS MÓVILES LLEGA · y a cuántas personas
-- ------------------------------------------------------------
-- Se rehacen las dos de siempre para que acepten los grupos quitados.
-- Se BORRAN las de cinco parámetros: si se dejaran, una llamada con
-- cinco nombres sería ambigua y Postgres se negaría a elegir.
--
-- El recuento cuenta SOLO a quien de verdad lo va a recibir: ya
-- descontados los que tienen esa categoría apagada. Decir «llegará a
-- 120» y que lo reciban 40 es peor que no decir nada.
drop function if exists public.avisos_alcance(text, text, uuid, text, uuid);
drop function if exists public.avisos_destinatarios(text, text, uuid, text, uuid);

create function public.avisos_alcance(
  p_publico   text,
  p_categoria text,
  p_grupo     uuid,
  p_rol       text,
  p_perfil    uuid,
  p_excluir   uuid[] default '{}'
)
returns integer
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare v_n integer;
begin
  if not public.avisos_puede_enviar() then
    raise exception 'Solo administración y tesorería pueden mandar avisos.' using errcode = 'P0001';
  end if;

  select count(*) into v_n
    from public.avisos_suscripciones s
   where s.perfil_id in (
           select public.avisos_destino_perfiles(p_publico, p_grupo, p_rol, p_perfil, p_excluir))
     and public.avisos_quiere(s.perfil_id, p_categoria);

  return coalesce(v_n, 0);
end;
$function$;

comment on function public.avisos_alcance(text, text, uuid, text, uuid, uuid[]) is
  'Cuántos MÓVILES recibirían el aviso ahora mismo, ya descontados los grupos quitados y quien tenga esa categoría apagada.';

revoke all on function public.avisos_alcance(text, text, uuid, text, uuid, uuid[]) from public;
revoke all on function public.avisos_alcance(text, text, uuid, text, uuid, uuid[]) from anon;
grant execute on function public.avisos_alcance(text, text, uuid, text, uuid, uuid[]) to authenticated;


-- Cuántas PERSONAS lo verán en la app, que no es lo mismo: el aviso
-- queda en la app aunque no suene en ningún móvil.
create or replace function public.avisos_personas(
  p_publico   text,
  p_categoria text,
  p_grupo     uuid,
  p_rol       text,
  p_perfil    uuid,
  p_excluir   uuid[] default '{}'
)
returns integer
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare v_n integer;
begin
  if not public.avisos_puede_enviar() then
    raise exception 'Solo administración y tesorería pueden mandar avisos.' using errcode = 'P0001';
  end if;

  select count(*) into v_n
    from public.avisos_destino_perfiles(p_publico, p_grupo, p_rol, p_perfil, p_excluir) d
   where public.avisos_quiere(d, p_categoria);

  return coalesce(v_n, 0);
end;
$function$;

comment on function public.avisos_personas(text, text, uuid, text, uuid, uuid[]) is
  'Cuántas PERSONAS verán el aviso en la app, tengan móvil dado de alta o no.';

revoke all on function public.avisos_personas(text, text, uuid, text, uuid, uuid[]) from public;
revoke all on function public.avisos_personas(text, text, uuid, text, uuid, uuid[]) from anon;
grant execute on function public.avisos_personas(text, text, uuid, text, uuid, uuid[]) to authenticated;


-- Los buzones a los que hay que entregar. Solo la llave de servicio.
create function public.avisos_destinatarios(
  p_publico   text,
  p_categoria text,
  p_grupo     uuid,
  p_rol       text,
  p_perfil    uuid,
  p_excluir   uuid[] default '{}'
)
returns table (id uuid, endpoint text, p256dh text, auth text)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select s.id, s.endpoint, s.p256dh, s.auth
    from public.avisos_suscripciones s
   where s.perfil_id in (
           select public.avisos_destino_perfiles(p_publico, p_grupo, p_rol, p_perfil, p_excluir))
     and public.avisos_quiere(s.perfil_id, p_categoria);
$function$;

comment on function public.avisos_destinatarios(text, text, uuid, text, uuid, uuid[]) is
  'Los buzones de móvil a los que entregar el aviso. Respeta lo que cada persona ha elegido recibir, sin excepción: tampoco los graves se saltan esa preferencia.';

revoke all on function public.avisos_destinatarios(text, text, uuid, text, uuid, uuid[]) from public;
revoke all on function public.avisos_destinatarios(text, text, uuid, text, uuid, uuid[]) from anon;
revoke all on function public.avisos_destinatarios(text, text, uuid, text, uuid, uuid[]) from authenticated;
grant execute on function public.avisos_destinatarios(text, text, uuid, text, uuid, uuid[]) to service_role;


-- ------------------------------------------------------------
-- 7 · MIS AVISOS · ahora con nivel, caducidad y leído
-- ------------------------------------------------------------
-- `p_meses` es la ventana que se ve. La pantalla enseña tres meses y
-- ofrece «Ver los de meses anteriores», que pide doce. Más de un año
-- no se enseña nunca: los avisos se archivan al año.
drop function if exists public.mis_avisos(uuid, integer);
drop function if exists public.mis_avisos(uuid, integer, integer);

create function public.mis_avisos(
  p_id     uuid    default null,
  p_limite integer default 30,
  p_meses  integer default 3
)
returns table (
  id            uuid,
  titulo        text,
  cuerpo        text,
  url           text,
  categoria     text,
  nivel         text,
  caduca_el     date,
  caducado      boolean,
  leido         boolean,
  publico_texto text,
  remitente     text,
  personas      integer,
  created_at    timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_perfil uuid;
  v_meses  integer := greatest(least(coalesce(p_meses, 3), 12), 1);
begin
  -- Sin ficha del club no hay avisos que enseñar. Vacío, que es
  -- distinto de fallar: la pantalla ya lo cuenta a su manera.
  v_perfil := public.mi_perfil_id();
  if v_perfil is null then
    return;
  end if;

  return query
    select a.id,
           a.titulo,
           a.cuerpo,
           a.url,
           a.categoria,
           a.nivel,
           a.caduca_el,
           (a.caduca_el is not null and a.caduca_el < current_date)      as caducado,
           exists (select 1 from public.avisos_leidos l
                    where l.aviso_id = a.id and l.perfil_id = v_perfil)  as leido,
           a.publico_texto,
           -- El remitente es contexto para leer: «Marta Segura» dice
           -- más que «el club». Solo el nombre, nada de correo.
           nullif(btrim(coalesce(q.nombre,'') || ' ' || coalesce(q.apellidos,'')), '') as remitente,
           -- A cuántas personas se mandó solo se cuenta en el aviso
           -- abierto: en la lista sería una cuenta por fila para nada.
           case when p_id is null then null::integer else (
             select count(*)::integer
               from public.avisos_destino_perfiles(
                      a.publico, a.grupo_id, a.rol, a.perfil_destino, a.grupos_excluidos) d
              where public.avisos_quiere(d, a.categoria))
           end as personas,
           a.created_at
      from public.avisos_enviados a
      left join public.perfiles q on q.id = a.creado_por
     where (p_id is null or a.id = p_id)
       and a.created_at >= now() - (v_meses || ' months')::interval
       and public.avisos_quiere(v_perfil, a.categoria)
       and exists (
             select 1
               from public.avisos_destino_perfiles(
                      a.publico, a.grupo_id, a.rol, a.perfil_destino, a.grupos_excluidos) d
              where d = v_perfil)
     order by a.created_at desc
     limit greatest(least(coalesce(p_limite, 30), 60), 1);
end;
$function$;

comment on function public.mis_avisos(uuid, integer, integer) is
  'Los avisos que le tocaron a QUIEN LLAMA, con su nivel, si ya pasó y si lo ha leído. No enseña los de otros, ni a cuántos móviles llegó, ni a quién más.';

revoke all on function public.mis_avisos(uuid, integer, integer) from public;
revoke all on function public.mis_avisos(uuid, integer, integer) from anon;
grant execute on function public.mis_avisos(uuid, integer, integer) to authenticated;


-- ------------------------------------------------------------
-- 8 · MARCARLO COMO LEÍDO
-- ------------------------------------------------------------
-- Sin `p_id` marca todos los que tenga sin leer («Marcar leídos»).
-- Solo puede marcar LOS SUYOS: el filtro es el mismo de `mis_avisos`,
-- así que un aviso de otra persona no se puede ni tocar.
create or replace function public.avisos_marcar_leido(p_id uuid default null)
returns integer
language plpgsql
volatile
security definer
set search_path to 'public'
as $function$
declare
  v_perfil uuid;
  v_n      integer;
begin
  v_perfil := public.mi_perfil_id();
  if v_perfil is null then
    return 0;
  end if;

  with mios as (
    select a.id
      from public.avisos_enviados a
     where (p_id is null or a.id = p_id)
       and a.created_at >= now() - interval '12 months'
       and public.avisos_quiere(v_perfil, a.categoria)
       and exists (
             select 1
               from public.avisos_destino_perfiles(
                      a.publico, a.grupo_id, a.rol, a.perfil_destino, a.grupos_excluidos) d
              where d = v_perfil)
  )
  insert into public.avisos_leidos (aviso_id, perfil_id)
  select m.id, v_perfil from mios m
  on conflict (aviso_id, perfil_id) do nothing;

  get diagnostics v_n = row_count;
  return coalesce(v_n, 0);
end;
$function$;

comment on function public.avisos_marcar_leido(uuid) is
  'Marca como leído un aviso propio, o todos los propios sin leer si no se dice cuál. Devuelve cuántos ha marcado. No puede tocar los de otra persona.';

revoke all on function public.avisos_marcar_leido(uuid) from public;
revoke all on function public.avisos_marcar_leido(uuid) from anon;
grant execute on function public.avisos_marcar_leido(uuid) to authenticated;


-- ------------------------------------------------------------
-- 9 · APUNTAR EL AVISO EN EL HISTORIAL · con el nivel
-- ------------------------------------------------------------
-- Se borra la de trece parámetros y se pone esta, con los cuatro datos
-- nuevos por defecto. Así una versión antigua de `aviso-enviar` que
-- todavía no se haya redesplegado sigue funcionando: manda sus trece
-- nombres y los cuatro nuevos se rellenan solos.
drop function if exists public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid);

create function public.avisos_registrar(
  p_titulo    text,
  p_cuerpo    text,
  p_url       text,
  p_publico   text,
  p_categoria text,
  p_grupo     uuid,
  p_rol       text,
  p_perfil    uuid,
  p_texto     text,
  p_enviados  integer,
  p_fallidos  integer,
  p_autor     uuid,
  p_id        uuid    default null,
  p_nivel     text    default 'informativo',
  p_caduca    date    default null,
  p_movil     boolean default true,
  p_excluir   uuid[]  default '{}'
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_id    uuid;
  v_nivel text := lower(btrim(coalesce(p_nivel, 'informativo')));
begin
  if v_nivel not in ('informativo','importante','grave') then
    v_nivel := 'informativo';
  end if;

  insert into public.avisos_enviados
    (id, titulo, cuerpo, url, publico, categoria, grupo_id, rol, perfil_destino,
     publico_texto, enviados, fallidos, creado_por,
     nivel, caduca_el, al_movil, grupos_excluidos)
  values
    (coalesce(p_id, gen_random_uuid()),
     p_titulo, p_cuerpo, nullif(btrim(coalesce(p_url,'')), ''), p_publico, p_categoria,
     p_grupo, p_rol, p_perfil, p_texto,
     greatest(coalesce(p_enviados,0),0), greatest(coalesce(p_fallidos,0),0), p_autor,
     v_nivel, p_caduca, coalesce(p_movil, true), coalesce(p_excluir, '{}'))
  returning id into v_id;
  return v_id;
end;
$function$;

comment on function public.avisos_registrar(text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid, text, date, boolean, uuid[]) is
  'Apunta en el historial un aviso ya mandado, con su nivel y su caducidad. Solo la llave de servicio: si no, los números de «llegó a» se podrían maquillar desde un navegador.';

revoke all on function public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid, text, date, boolean, uuid[])
  from public;
revoke all on function public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid, text, date, boolean, uuid[])
  from anon;
revoke all on function public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid, text, date, boolean, uuid[])
  from authenticated;
grant execute on function public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid, text, date, boolean, uuid[])
  to service_role;


-- ------------------------------------------------------------
-- 10 · EL HISTORIAL DEL PANEL · sigue siendo del equipo del club
-- ------------------------------------------------------------
-- `avisos_enviados` ya tenía su política de lectura para el equipo.
-- Se vuelven a cerrar los GRANT a mano por las columnas nuevas: se
-- heredan de la tabla, sí, pero no se fía a eso.
revoke insert, update, delete, truncate, references, trigger on public.avisos_enviados from anon;
revoke insert, update, delete, truncate, references, trigger on public.avisos_enviados from authenticated;
revoke select on public.avisos_enviados from anon;
grant  select on public.avisos_enviados to authenticated;   -- con la RLS delante (solo staff)

commit;


-- ============================================================
-- 11 · COMPROBACIÓN · quién puede llamar a qué
-- ------------------------------------------------------------
-- Se mira la lista REAL de permisos, no las políticas: son dos cosas
-- distintas y el fallo de siempre está en la primera.
-- ============================================================
select p.proname as funcion,
       coalesce(array_to_string(p.proacl, E'\n'), '(sin lista: lo puede llamar cualquiera ⚠️)') as quien_puede
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('mis_avisos','avisos_registrar','avisos_marcar_leido',
                     'avisos_puede_enviar','avisos_alcance','avisos_personas',
                     'avisos_destinatarios','avisos_destino_perfiles','avisos_grupos_de')
 order by p.proname;

select c.relname as tabla,
       coalesce(array_to_string(c.relacl, E'\n'), '(sin lista)') as quien_puede,
       c.relrowsecurity as rls_encendida
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relname in ('avisos_leidos','avisos_enviados');
