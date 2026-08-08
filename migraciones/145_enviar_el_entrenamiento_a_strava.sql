-- ============================================================
-- 145 · Llevar a Strava lo que se apunta aquí
-- ------------------------------------------------------------
-- QUÉ SE QUIERE
-- «Que el atleta suba su entrenamiento a la app de Apolana y ya se
--  ponga en Strava solo, no al revés.»
--
-- Y UNA COSA QUE CAMBIA EL DISEÑO ENTERO
-- El club entrena con Garmin, y el reloj YA sube la actividad a Strava
-- por su cuenta. Si Apolana creara otra, cada día habría DOS: la del
-- reloj —con su GPS, sus vueltas y su mapa— y una manual sin nada.
-- Limpiar duplicados a mano es lo que hace que alguien desconecte una
-- integración a la semana de ponerla.
--
-- Así que Apolana NO CREA: ENRIQUECE. Busca la actividad que ya subió
-- el reloj ese día y le pone el título del entrenamiento y, en la
-- descripción, lo que se hizo de verdad: las series, los kilos, el
-- esfuerzo y las sensaciones. Que es justo lo que el reloj no sabe.
--
-- ------------------------------------------------------------
-- LO QUE SE GUARDA AQUÍ, Y POR QUÉ DA MIEDO
-- ------------------------------------------------------------
-- Para escribir en Strava en nombre de alguien hacen falta sus llaves
-- (`access_token` y `refresh_token`). Con esas llaves se puede leer y
-- MODIFICAR todo su Strava. No son un dato del club: son la cuenta de
-- otra persona en otro sitio.
--
-- Por eso esta tabla es la única del proyecto que NO tiene ni una
-- regla de lectura para el navegador. Ni para el dueño de la fila.
-- Está con RLS activado y sin una sola política que abra el `select`,
-- así que desde la web —con la clave pública, que está a la vista de
-- cualquiera— no sale nada de aquí. Las llaves solo las toca la
-- función del servidor, que va con la clave de servicio.
--
-- ⚠️ SI ALGÚN DÍA ALGUIEN AÑADE UNA POLÍTICA DE LECTURA A ESTA TABLA
--    «PARA QUE EL PORTAL SEPA SI ESTÁ CONECTADO», estará publicando
--    las llaves de la cuenta de Strava de la gente. Para eso está
--    `strava_estoy_conectado()`, que devuelve un sí o un no y nada más.
--
-- ⚠️ NINGÚN DATO PERSONAL SE ESCRIBE EN ESTE ARCHIVO. Este repositorio
--    es PÚBLICO. Aquí va el molde; las llaves las escribe la función.
--
-- Idempotente: se puede relanzar sin romper nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/145_enviar_el_entrenamiento_a_strava.sql
-- ============================================================

begin;

create table if not exists public.strava_cuentas (
  perfil_id      uuid primary key references public.perfiles(id) on delete cascade,
  strava_id      bigint,
  access_token   text not null,
  refresh_token  text not null,
  -- Cuándo caduca el token de acceso. Strava los da para seis horas, así
  -- que casi siempre habrá que renovarlo antes de usarlo.
  expira_en      timestamptz not null,
  -- Los permisos que concedió. Se guarda para poder DECIRLE que le faltan
  -- en vez de fallar con un 401 que no explica nada.
  scope          text,
  atleta_nombre  text,
  conectado_en   timestamptz not null default now(),
  ultimo_envio   timestamptz,
  ultimo_error   text
);

comment on table public.strava_cuentas is
  'Las llaves de Strava de quien ha conectado su cuenta. NO SE LEE DESDE EL NAVEGADOR: RLS activado y sin ninguna política de select, a propósito. Solo la función `strava` (clave de servicio) las toca. Migración 145.';
comment on column public.strava_cuentas.ultimo_error is
  'Lo último que contestó Strava cuando falló. Es para poder decirle a la persona qué pasó; se borra en cuanto un envío sale bien.';

alter table public.strava_cuentas enable row level security;

/* Y aquí NO va ninguna política. No es un olvido: es la medida de
   seguridad. Con RLS activado y cero políticas, la clave pública no
   saca ni una fila de esta tabla. */

-- ------------------------------------------------------------
-- LO ÚNICO QUE EL PORTAL PUEDE PREGUNTAR
-- ------------------------------------------------------------
-- «¿Estoy conectado?» y, como mucho, con qué nombre y desde cuándo.
-- Nada de llaves. Es una función con `security definer` justamente
-- para poder mirar una tabla que quien pregunta no puede leer.
create or replace function public.strava_estoy_conectado()
returns table (conectado boolean, atleta_nombre text, conectado_en timestamptz, ultimo_envio timestamptz, ultimo_error text)
language sql
stable
security definer
set search_path = public
as $$
  select true, c.atleta_nombre, c.conectado_en, c.ultimo_envio, c.ultimo_error
    from public.strava_cuentas c
   where c.perfil_id = public.mi_perfil_id()
  union all
  select false, null::text, null::timestamptz, null::timestamptz, null::text
   where not exists (select 1 from public.strava_cuentas c2 where c2.perfil_id = public.mi_perfil_id())
  limit 1;
$$;

comment on function public.strava_estoy_conectado() is
  'Si esta persona tiene Strava conectado, y cuándo fue el último envío. NUNCA devuelve las llaves. Es lo único que el portal puede preguntar sobre esta tabla.';

-- Desconectar SÍ puede hacerlo uno mismo, y sin pasar por el servidor:
-- soltar tu propia cuenta tiene que ser tan fácil como conectarla, y si
-- dependiera de que la función del servidor esté viva, un día de fallo
-- no podrías salir.
--
-- ⚠️ ESTO BORRA LAS LLAVES DE AQUÍ, PERO NO REVOCA EL PERMISO EN STRAVA.
--    Eso se hace en la propia Strava (Ajustes → Mis aplicaciones), y la
--    pantalla del portal lo dice. Prometer que se revoca cuando solo se
--    borra sería la peor clase de mentira en algo de permisos.
create or replace function public.strava_desconectar()
returns boolean
language sql
volatile
security definer
set search_path = public
as $$
  delete from public.strava_cuentas where perfil_id = public.mi_perfil_id();
  select true;
$$;

comment on function public.strava_desconectar() is
  'Borra las llaves de Strava de quien lo pide. NO revoca el permiso en Strava: eso se hace desde Strava. Migración 145.';

revoke all on function public.strava_estoy_conectado() from public, anon, authenticated;
revoke all on function public.strava_desconectar()     from public, anon, authenticated;
grant execute on function public.strava_estoy_conectado() to authenticated;
grant execute on function public.strava_desconectar()     to authenticated;

commit;

-- ============================================================
-- LO QUE FALTA FUERA DE LA BASE
-- ------------------------------------------------------------
--   · Una aplicación en strava.com/settings/api, con el dominio de
--     vuelta puesto en `escuelaapolana.github.io`.
--   · Sus dos valores como secretos de la función:
--       supabase secrets set STRAVA_CLIENT_ID=... STRAVA_CLIENT_SECRET=...
--     El secreto NO va en este repositorio, que es público.
--   · La función `supabase/functions/strava`, que es quien tiene la
--     clave de servicio y la única que toca esta tabla.
--
-- LO QUE ESTO NO HACE
--   · No crea actividades en Strava, solo enriquece las que ya están.
--     Si un día se quiere lo otro —para gimnasio y piscina, donde el
--     reloj no aporta— hace falta decidir antes qué pasa los días en
--     que el reloj sí subió algo.
--   · No hay reintento automático: no hay `pg_cron` en este proyecto.
--     Si la actividad del reloj todavía no ha llegado a Strava, se
--     dice y queda el botón para volver a intentarlo.
-- ============================================================
