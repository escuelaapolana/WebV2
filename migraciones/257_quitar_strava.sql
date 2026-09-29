-- ============================================================
-- (número por asignar) · Quitar Strava del todo
-- ------------------------------------------------------------
-- POR QUÉ
-- La integración con Strava (migración 145 + Edge Function `strava`)
-- se retira: se decide dejar de mantenerla en vez de arreglar el CSRF
-- que tenía pendiente. Nadie la llegó a usar —`strava_cuentas` estaba
-- a CERO filas y CERO envíos cuando esto se escribió—, así que al
-- borrarla no se pierde ningún dato de ninguna persona.
--
-- QUÉ CREÓ LA 145 Y QUÉ SE DESHACE AQUÍ (todo lo suyo, y solo lo suyo)
--   · tabla    public.strava_cuentas          (las llaves de cada quien)
--   · función  public.strava_estoy_conectado()
--   · función  public.strava_desconectar()
-- Se comprobó que NINGUNA vista ni función depende de estos objetos, así
-- que no hace falta CASCADE: se caen limpios. Los grants y el RLS de la
-- tabla se van solos con cada objeto; no hay política que borrar (la 145
-- dejó la tabla con RLS activado y CERO políticas a propósito).
--
-- El orden no importa para la seguridad del despliegue: si esto se aplica
-- ANTES de subir el front nuevo, el front viejo llama a
-- `strava_estoy_conectado` y, al no existir, recibe un error que ya está
-- capturado (la tarjeta simplemente no se enseña); si el front va antes,
-- esta migración borra objetos que ya no llama nadie.
--
-- LO QUE ESTA MIGRACIÓN NO HACE (lo hace administración, fuera de la BD):
--   · Borrar la Edge Function:
--       supabase functions delete strava --project-ref icaxokjsvhlreuwpyxeb
--   · Quitar de Supabase los secretos STRAVA_CLIENT_ID y
--     STRAVA_CLIENT_SECRET (OJO: ACCESO_URL_BASE y ACCESO_ORIGENES se
--     QUEDAN, que los usan otras funciones).
--   · En strava.com/settings/api, retirar/borrar la aplicación del club.
--
-- Idempotente: se puede relanzar sin romper nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/NNN_quitar_strava.sql
-- ============================================================

begin;

drop function if exists public.strava_estoy_conectado();
drop function if exists public.strava_desconectar();
drop table    if exists public.strava_cuentas;

commit;
