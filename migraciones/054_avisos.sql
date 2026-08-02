-- ============================================================
-- 054 · AVISOS AL MÓVIL · la fontanería
-- ------------------------------------------------------------
-- QUÉ RESUELVE
--   Hoy el club no tiene forma de avisar de nada. Si mañana no hay
--   entreno por lluvia, si sale la convocatoria de un cross, si a
--   alguien le vuelve el recibo… la gente se entera si entra a
--   mirar. Con esto, el aviso le llega al móvil como le llega un
--   mensaje: aunque la app esté cerrada.
--
--   Esto NO es un chat ni un correo. Es un aviso corto que se toca
--   y lleva a la pantalla que toca. Nada más.
--
-- ⚠️ NACE APAGADO
--   `avisos_config.activo = false` y sin clave pública puesta.
--   Mientras esté así:
--     · el módulo del navegador no enseña el botón «Avisarme»,
--     · la pantalla del panel no enseña el botón de enviar,
--     · y la función del servidor contesta «todavía no está activado»
--       con buenos modales, sin reventar.
--   Se enciende cuando el club genere sus claves. Guía para el dueño:
--   `docs/avisos-al-movil.md`.
--
-- ⚠️ AQUÍ NO HAY NI UNA CLAVE SECRETA
--   El sistema usa dos claves (VAPID): una pública y una privada.
--     · La PRIVADA vive SOLO en las variables de entorno de Supabase.
--       Ni en esta tabla, ni en este archivo, ni en el repositorio.
--     · La PÚBLICA es pública por diseño (se la manda el navegador a
--       Google/Apple en cada suscripción, como la clave de Supabase
--       que ya va en `assets/js/db.js`). Se guarda en
--       `avisos_config.clave_publica` para que el dueño la pegue una
--       vez desde el panel y NO haya que escribirla en el repositorio.
--
-- LO IMPORTANTE DE TODO EL ARCHIVO · CUATRO CANDADOS
--   1) Las suscripciones son datos personales de verdad: con el
--      endpoint y las dos claves se le puede mandar un aviso a ese
--      móvil. Por eso NADIE las lee desde el navegador, ni siquiera
--      el administrador. Solo la llave de servicio, y solo a través
--      de `avisos_destinatarios()`.
--   2) Cada uno gestiona LAS SUYAS y SUS preferencias. Nada más.
--   3) Solo admin/staff manda avisos y ve el historial.
--   4) Las preferencias se respetan SIEMPRE, también desde el
--      servidor: quien apagó «noticias del club» no recibe noticias
--      aunque el aviso vaya a todo el club.
--
-- Idempotente: se puede relanzar sin perder nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/054_avisos.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · CONFIGURACIÓN · una sola fila, el interruptor general
-- ------------------------------------------------------------
create table if not exists public.avisos_config (
  -- Una fila y solo una: el `check (id = 1)` lo impide de raíz.
  id             smallint primary key default 1 check (id = 1),

  -- El interruptor. FALSE hasta que el club tenga sus claves.
  activo         boolean not null default false,

  -- La clave PÚBLICA VAPID (no es un secreto: el navegador la enseña
  -- a Google/Apple en cada suscripción). Se guarda aquí y no en el
  -- repositorio para que el dueño la pegue una vez y ya está.
  -- La PRIVADA no está aquí ni puede estarlo: va en Supabase.
  clave_publica  text,

  -- A quién escribe Google/Apple si hay un problema con los envíos.
  -- Es obligatorio por el estándar. Un correo del club.
  contacto       text,

  updated_at     timestamptz not null default now()
);

comment on table public.avisos_config is
  'Interruptor de los avisos al móvil (una sola fila). Guarda la clave PÚBLICA VAPID, que no es secreta. La privada va en las variables de entorno de Supabase.';
comment on column public.avisos_config.activo is
  'Con false no se manda ni un aviso y ninguna pantalla enseña botones.';
comment on column public.avisos_config.clave_publica is
  'Clave pública VAPID. Pública por diseño: viaja al navegador. La privada NUNCA se guarda aquí.';

-- Columnas por si la tabla ya existía de una pasada anterior.
alter table public.avisos_config add column if not exists activo        boolean not null default false;
alter table public.avisos_config add column if not exists clave_publica text;
alter table public.avisos_config add column if not exists contacto      text;
alter table public.avisos_config add column if not exists updated_at    timestamptz not null default now();

-- La fila única. `do nothing`: si ya está, no se pisa lo que haya puesto el club.
insert into public.avisos_config (id) values (1) on conflict (id) do nothing;

drop trigger if exists avisos_config_updated_at on public.avisos_config;
create trigger avisos_config_updated_at
  before update on public.avisos_config
  for each row execute function public.handle_updated_at();


-- ------------------------------------------------------------
-- 2 · SUSCRIPCIONES · un móvil (o un navegador) que ha dicho que sí
-- ------------------------------------------------------------
-- Una persona puede tener varias: el móvil, la tablet, el portátil.
-- Cada aparato es una fila. El `endpoint` es la dirección que da
-- Google/Apple para llegar a ESE aparato, y es único.
create table if not exists public.avisos_suscripciones (
  id           uuid primary key default gen_random_uuid(),

  perfil_id    uuid not null references public.perfiles(id) on delete cascade,

  -- La dirección del buzón de ese aparato, la da el navegador.
  endpoint     text not null unique,

  -- Las dos claves con las que se cifra el aviso para que solo ese
  -- aparato pueda leerlo. Ni Google ni Apple ven el texto.
  p256dh       text not null,
  auth         text not null,

  -- Para que la persona reconozca sus aparatos en su lista:
  -- «iPhone · app instalada», «Chrome en Windows»…
  dispositivo  text,

  created_at   timestamptz not null default now(),

  -- Cuándo se le mandó algo por última vez con éxito. Sirve para
  -- limpiar las que llevan meses muertas.
  ultimo_uso   timestamptz
);

comment on table public.avisos_suscripciones is
  'Aparatos que han aceptado recibir avisos. DATO SENSIBLE: con el endpoint y las claves se le manda un aviso a ese móvil. No se leen desde el navegador, ni siquiera siendo administrador.';

alter table public.avisos_suscripciones add column if not exists dispositivo text;
alter table public.avisos_suscripciones add column if not exists ultimo_uso  timestamptz;

create index if not exists avisos_suscripciones_perfil_idx
  on public.avisos_suscripciones (perfil_id, created_at desc);


-- ------------------------------------------------------------
-- 3 · PREFERENCIAS · los interruptores de cada persona
-- ------------------------------------------------------------
-- En cristiano y pocos. Si son quince nadie los mira, y si son dos
-- la gente apaga todo porque le llega lo que no le interesa.
--
-- Todos encendidos de fábrica MENOS «noticias del club»: las noticias
-- no son urgentes y son las que más cansan. Quien las quiera, las
-- enciende.
create table if not exists public.avisos_preferencias (
  perfil_id     uuid primary key references public.perfiles(id) on delete cascade,

  entrenos      boolean not null default true,   -- entrenos y cambios de última hora
  competiciones boolean not null default true,   -- competiciones y convocatorias
  pagos         boolean not null default true,   -- pagos y recibos
  noticias      boolean not null default false,  -- noticias del club   ← apagado de fábrica
  retos         boolean not null default true,   -- retos y logros

  updated_at    timestamptz not null default now()
);

comment on table public.avisos_preferencias is
  'Qué avisos quiere cada persona. Todos encendidos de fábrica salvo las noticias del club. Si alguien no tiene fila, valen estos mismos valores por defecto.';

alter table public.avisos_preferencias add column if not exists entrenos      boolean not null default true;
alter table public.avisos_preferencias add column if not exists competiciones boolean not null default true;
alter table public.avisos_preferencias add column if not exists pagos         boolean not null default true;
alter table public.avisos_preferencias add column if not exists noticias      boolean not null default false;
alter table public.avisos_preferencias add column if not exists retos         boolean not null default true;
alter table public.avisos_preferencias add column if not exists updated_at    timestamptz not null default now();

drop trigger if exists avisos_preferencias_updated_at on public.avisos_preferencias;
create trigger avisos_preferencias_updated_at
  before update on public.avisos_preferencias
  for each row execute function public.handle_updated_at();


-- ------------------------------------------------------------
-- 4 · LO ENVIADO · el historial
-- ------------------------------------------------------------
create table if not exists public.avisos_enviados (
  id              uuid primary key default gen_random_uuid(),

  titulo          text not null,
  cuerpo          text not null,
  -- A dónde lleva al tocarlo. Siempre una dirección de la propia web.
  url             text,

  -- A QUIÉN iba: todo el club, un grupo, un rol o una persona.
  publico         text not null default 'todos'
                  check (publico in ('todos','grupo','rol','persona')),
  grupo_id        uuid references public.grupos(id)   on delete set null,
  rol             text,
  perfil_destino  uuid references public.perfiles(id) on delete set null,
  -- Escrito en cristiano para el historial: «Grupo Velocidad A».
  -- Se guarda por si el grupo se borra o se le cambia el nombre.
  publico_texto   text,

  -- De qué tipo era, para respetar las preferencias de cada uno.
  categoria       text not null default 'entrenos'
                  check (categoria in ('entrenos','competiciones','pagos','noticias','retos')),

  enviados        integer not null default 0,
  fallidos        integer not null default 0,

  creado_por      uuid references public.perfiles(id) on delete set null,
  created_at      timestamptz not null default now()
);

comment on table public.avisos_enviados is
  'Historial de avisos mandados, con a cuántos aparatos llegó y a cuántos no. Lo escribe la función del servidor, nunca el navegador.';

alter table public.avisos_enviados add column if not exists publico_texto text;
alter table public.avisos_enviados add column if not exists categoria     text not null default 'entrenos';

create index if not exists avisos_enviados_fecha_idx
  on public.avisos_enviados (created_at desc);


-- ------------------------------------------------------------
-- 5 · LAS FUNCIONES
-- ------------------------------------------------------------

-- 5.1 ¿Está encendido? Un sí/no, sin enseñar nada más. Lo puede
--     preguntar cualquiera para no pintar un botón que no funciona.
create or replace function public.avisos_disponible()
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select coalesce((
    select c.activo and coalesce(length(btrim(c.clave_publica)), 0) > 20
      from public.avisos_config c where c.id = 1
  ), false);
$function$;

grant execute on function public.avisos_disponible() to anon, authenticated;


-- 5.2 La clave PÚBLICA, que es la que necesita el navegador para
--     suscribirse. Devuelve null si está apagado: así el módulo del
--     navegador se calla solo y no enseña nada.
create or replace function public.avisos_clave_publica()
returns text
language sql stable security definer set search_path to 'public'
as $function$
  select case when public.avisos_disponible()
              then (select btrim(c.clave_publica) from public.avisos_config c where c.id = 1)
         end;
$function$;

grant execute on function public.avisos_clave_publica() to authenticated;


-- 5.3 ¿Esta persona quiere avisos de este tipo?
--     Sin fila de preferencias valen los valores de fábrica, que son
--     los mismos que los `default` de la tabla.
create or replace function public.avisos_quiere(p_perfil uuid, p_categoria text)
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select case p_categoria
    when 'entrenos'      then coalesce((select p.entrenos      from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    when 'competiciones' then coalesce((select p.competiciones from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    when 'pagos'         then coalesce((select p.pagos         from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    when 'noticias'      then coalesce((select p.noticias      from public.avisos_preferencias p where p.perfil_id = p_perfil), false)
    when 'retos'         then coalesce((select p.retos         from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    else false
  end;
$function$;


-- 5.4 A qué PERSONAS va un aviso, antes de mirar preferencias.
--     · todos   → todo el club con la cuenta activa
--     · grupo   → los atletas de ese grupo, sus padres/madres y el
--                 entrenador que lo lleva (si mañana no hay entreno,
--                 el entrenador también quiere enterarse)
--     · rol     → todos los que tienen ese papel en el club
--     · persona → una sola
create or replace function public.avisos_perfiles_destino(
  p_publico text,
  p_grupo   uuid default null,
  p_rol     text default null,
  p_perfil  uuid default null
)
returns setof uuid
language sql stable security definer set search_path to 'public'
as $function$
  select p.id
    from public.perfiles p
   where coalesce(p.activo, true)
     and (
       (p_publico = 'todos')
       or (p_publico = 'rol'     and p_rol    is not null and p.rol = p_rol)
       or (p_publico = 'persona' and p_perfil is not null and p.id  = p_perfil)
       or (p_publico = 'grupo'   and p_grupo  is not null and (
             exists (select 1 from public.atletas a
                      where a.grupo_id = p_grupo
                        and (a.perfil_id = p.id or a.perfil_padre_id = p.id))
             or exists (select 1 from public.grupos g
                         where g.id = p_grupo and g.entrenador_id = p.id)
           ))
     );
$function$;


-- 5.5 A CUÁNTOS APARATOS va a llegar de verdad.
--     Ya con las preferencias aplicadas: es el número honesto que se
--     enseña en el panel antes de mandar nada.
--     La puede llamar admin/staff, y solo devuelve un número: ni un
--     endpoint ni una clave salen de aquí.
create or replace function public.avisos_alcance(
  p_publico   text,
  p_categoria text default 'entrenos',
  p_grupo     uuid default null,
  p_rol       text default null,
  p_perfil    uuid default null
)
returns integer
language plpgsql stable security definer set search_path to 'public'
as $function$
declare v_n integer;
begin
  if not public.es_staff() then
    raise exception 'Solo el equipo del club puede mandar avisos.' using errcode = 'P0001';
  end if;

  select count(*) into v_n
    from public.avisos_suscripciones s
   where s.perfil_id in (
           select public.avisos_perfiles_destino(p_publico, p_grupo, p_rol, p_perfil))
     and public.avisos_quiere(s.perfil_id, p_categoria);

  return coalesce(v_n, 0);
end;
$function$;

grant execute on function public.avisos_alcance(text, text, uuid, text, uuid) to authenticated;


-- 5.6 LOS DESTINATARIOS DE VERDAD, con endpoint y claves.
--     ESTA ES LA FUNCIÓN SENSIBLE del archivo. Solo la llave de
--     servicio (la función `aviso-enviar`) puede llamarla. Ni el
--     navegador de un socio ni el de un administrador llegan a ella.
create or replace function public.avisos_destinatarios(
  p_publico   text,
  p_categoria text default 'entrenos',
  p_grupo     uuid default null,
  p_rol       text default null,
  p_perfil    uuid default null
)
returns table (id uuid, endpoint text, p256dh text, auth text)
language sql stable security definer set search_path to 'public'
as $function$
  select s.id, s.endpoint, s.p256dh, s.auth
    from public.avisos_suscripciones s
   where s.perfil_id in (
           select public.avisos_perfiles_destino(p_publico, p_grupo, p_rol, p_perfil))
     and public.avisos_quiere(s.perfil_id, p_categoria);
$function$;


-- 5.7 Dar de baja un aparato que ya no existe.
--     Google y Apple contestan 404 o 410 cuando alguien ha
--     desinstalado la app o ha borrado los datos del navegador. Esa
--     suscripción está muerta y se quita, o el número de «fallidos»
--     crecería para siempre.
create or replace function public.avisos_baja_endpoint(p_endpoint text)
returns integer
language plpgsql security definer set search_path to 'public'
as $function$
declare v_n integer;
begin
  delete from public.avisos_suscripciones where endpoint = p_endpoint;
  get diagnostics v_n = row_count;
  return v_n;
end;
$function$;


-- 5.8 Marcar que a esos aparatos les llegó bien.
create or replace function public.avisos_marcar_uso(p_ids uuid[])
returns integer
language plpgsql security definer set search_path to 'public'
as $function$
declare v_n integer;
begin
  update public.avisos_suscripciones
     set ultimo_uso = now()
   where id = any(p_ids);
  get diagnostics v_n = row_count;
  return v_n;
end;
$function$;


-- 5.9 Apuntar en el historial lo que se acaba de mandar.
create or replace function public.avisos_registrar(
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
  p_autor     uuid
)
returns uuid
language plpgsql security definer set search_path to 'public'
as $function$
declare v_id uuid;
begin
  insert into public.avisos_enviados
    (titulo, cuerpo, url, publico, categoria, grupo_id, rol, perfil_destino,
     publico_texto, enviados, fallidos, creado_por)
  values
    (p_titulo, p_cuerpo, nullif(btrim(coalesce(p_url,'')), ''), p_publico, p_categoria,
     p_grupo, p_rol, p_perfil, p_texto,
     greatest(coalesce(p_enviados,0),0), greatest(coalesce(p_fallidos,0),0), p_autor)
  returning id into v_id;
  return v_id;
end;
$function$;


-- Las cuatro de arriba tocan datos sensibles o escriben el historial:
-- SOLO la llave de servicio. Ni anónimo, ni con sesión, ni admin.
revoke all on function public.avisos_destinatarios(text, text, uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.avisos_baja_endpoint(text)                          from public, anon, authenticated;
revoke all on function public.avisos_marcar_uso(uuid[])                           from public, anon, authenticated;
revoke all on function public.avisos_registrar(text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid)
                                                                                  from public, anon, authenticated;
revoke all on function public.avisos_perfiles_destino(text, uuid, text, uuid)     from public, anon, authenticated;
revoke all on function public.avisos_quiere(uuid, text)                            from public, anon, authenticated;

grant execute on function public.avisos_destinatarios(text, text, uuid, text, uuid) to service_role;
grant execute on function public.avisos_baja_endpoint(text)                          to service_role;
grant execute on function public.avisos_marcar_uso(uuid[])                           to service_role;
grant execute on function public.avisos_registrar(text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid)
                                                                                     to service_role;
grant execute on function public.avisos_perfiles_destino(text, uuid, text, uuid)     to service_role;
grant execute on function public.avisos_quiere(uuid, text)                            to service_role;


-- ------------------------------------------------------------
-- 6 · CANDADOS (RLS)
-- ------------------------------------------------------------
-- ⚠️ RECORDATORIO: Supabase reparte por su cuenta permiso TOTAL a
-- `anon` y a `authenticated` sobre cualquier tabla nueva del esquema
-- public. No basta con «no conceder»: hay que QUITAR primero y
-- conceder después solo lo justo.

-- 6.1 SUSCRIPCIONES · cada uno, LAS SUYAS. Nadie más, ni el admin.
alter table public.avisos_suscripciones enable row level security;

drop policy if exists "ver mis suscripciones de avisos"      on public.avisos_suscripciones;
drop policy if exists "crear mis suscripciones de avisos"    on public.avisos_suscripciones;
drop policy if exists "cambiar mis suscripciones de avisos"  on public.avisos_suscripciones;
drop policy if exists "borrar mis suscripciones de avisos"   on public.avisos_suscripciones;

create policy "ver mis suscripciones de avisos"
  on public.avisos_suscripciones for select to authenticated
  using (perfil_id = public.mi_perfil_id());

create policy "crear mis suscripciones de avisos"
  on public.avisos_suscripciones for insert to authenticated
  with check (perfil_id = public.mi_perfil_id());

create policy "cambiar mis suscripciones de avisos"
  on public.avisos_suscripciones for update to authenticated
  using (perfil_id = public.mi_perfil_id())
  with check (perfil_id = public.mi_perfil_id());

create policy "borrar mis suscripciones de avisos"
  on public.avisos_suscripciones for delete to authenticated
  using (perfil_id = public.mi_perfil_id());

-- Ni una policy para admin a propósito: un administrador no tiene por
-- qué poder leer los buzones de los móviles de los socios. Manda
-- avisos a través de la función del servidor, que es la única que ve
-- los endpoints y no se los enseña a nadie.
revoke all on public.avisos_suscripciones from anon;
revoke all on public.avisos_suscripciones from authenticated;
revoke all on public.avisos_suscripciones from public;
grant select, insert, update, delete on public.avisos_suscripciones to authenticated;


-- 6.2 PREFERENCIAS · cada uno, LAS SUYAS.
alter table public.avisos_preferencias enable row level security;

drop policy if exists "ver mis preferencias de avisos"     on public.avisos_preferencias;
drop policy if exists "crear mis preferencias de avisos"   on public.avisos_preferencias;
drop policy if exists "cambiar mis preferencias de avisos" on public.avisos_preferencias;

create policy "ver mis preferencias de avisos"
  on public.avisos_preferencias for select to authenticated
  using (perfil_id = public.mi_perfil_id());

create policy "crear mis preferencias de avisos"
  on public.avisos_preferencias for insert to authenticated
  with check (perfil_id = public.mi_perfil_id());

create policy "cambiar mis preferencias de avisos"
  on public.avisos_preferencias for update to authenticated
  using (perfil_id = public.mi_perfil_id())
  with check (perfil_id = public.mi_perfil_id());

revoke all on public.avisos_preferencias from anon;
revoke all on public.avisos_preferencias from authenticated;
revoke all on public.avisos_preferencias from public;
-- Sin delete: para no recibir nada se apagan los interruptores o se
-- quita la suscripción; borrar la fila devolvería los valores de
-- fábrica y volverían a llegar avisos sin que nadie lo pidiera.
grant select, insert, update on public.avisos_preferencias to authenticated;


-- 6.3 HISTORIAL · lo ve el equipo del club. Escribirlo, solo el servidor.
alter table public.avisos_enviados enable row level security;

drop policy if exists "staff ve los avisos enviados" on public.avisos_enviados;
create policy "staff ve los avisos enviados"
  on public.avisos_enviados for select to authenticated
  using (public.es_staff());

-- Fíjate en lo que NO hay: ni insert, ni update, ni delete. El
-- historial lo escribe `avisos_registrar()` con la llave de servicio,
-- así que el número de «enviados» no se puede maquillar desde el
-- navegador.
revoke all on public.avisos_enviados from anon;
revoke all on public.avisos_enviados from authenticated;
revoke all on public.avisos_enviados from public;
grant select on public.avisos_enviados to authenticated;


-- 6.4 CONFIGURACIÓN · la lee quien tiene sesión, la cambia el admin.
alter table public.avisos_config enable row level security;

drop policy if exists "lectura avisos_config con sesion" on public.avisos_config;
create policy "lectura avisos_config con sesion"
  on public.avisos_config for select to authenticated using (true);

drop policy if exists "admin cambia avisos_config" on public.avisos_config;
create policy "admin cambia avisos_config"
  on public.avisos_config for update to authenticated
  using (public.es_admin()) with check (public.es_admin());

revoke all on public.avisos_config from anon;
revoke all on public.avisos_config from authenticated;
revoke all on public.avisos_config from public;
-- Ni insert ni delete: la fila es una y no se toca.
grant select, update on public.avisos_config to authenticated;

commit;


-- ============================================================
-- 7 · COMPROBACIÓN RÁPIDA
-- ============================================================
select 'config'      as que, activo::text as valor_1,
       case when clave_publica is null then 'sin clave' else 'con clave' end as valor_2
  from public.avisos_config
union all
select 'disponible', public.avisos_disponible()::text, '(false = todo apagado, como debe estar)';

-- Quién puede tocar los avisos. Aquí NO debe salir «anon» por ningún
-- lado, y sobre `avisos_enviados` «authenticated» solo puede tener SELECT.
select table_name, grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema = 'public'
   and table_name in ('avisos_suscripciones','avisos_preferencias','avisos_enviados','avisos_config')
 order by table_name, grantee, privilege_type;
