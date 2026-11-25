-- ============================================================
-- 537 · Natación · correo del día 21 a todas las familias que pagan por la app
-- ------------------------------------------------------------
-- Andrés (19-nov-2026): «el 21 de cada mes debería llegarles un correo a los usuarios de
-- que el día 5 se cobra por la app». Decidido: a TODOS los que pagan.
--   · Cuota ya activada (suscripción de Stripe) cuyo próximo cobro es el día 5 que viene
--     → «el día 5 se cobra la cuota de natación de X: N €; no tienes que hacer nada».
--     Las trimestrales que no cobran ese día 5 no reciben nada ese mes.
--   · Enlace aún SIN ACTIVAR (y con plaza en natación) → «falta activar la cuota de X:
--     actívala antes del día 5» con el botón de su enlace.
-- Lo manda la Edge natacion-cobro-aviso con { aviso21: true } el día 21 a las 9:00.
-- cuotas_entreno.aviso21_mes guarda el mes del día 5 que ya se avisó (no se repite).
-- El aviso de 1-3 días antes de cada cobro (mig 429) sigue igual.
-- ============================================================
begin;

alter table public.cuotas_entreno add column if not exists aviso21_mes text;
comment on column public.cuotas_entreno.aviso21_mes is
  'Natación: mes (AAAA-MM) del cobro del día 5 que ya se avisó en el correo del día 21 (mig 537).';

-- Enlaces de natación sin activar de quien sigue teniendo plaza (lo lee la Edge).
create or replace function public.natacion_aviso21_pendientes()
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', ce.id,
           'nombre', ce.nombre, 'apellidos', ce.apellidos, 'email', ce.email,
           'importe_cent', ce.importe_cent, 'periodicidad', ce.periodicidad,
           'cargo_inicial_cent', ce.cargo_inicial_cent, 'cargo_inicial_concepto', ce.cargo_inicial_concepto,
           'token', ce.token, 'aviso21_mes', ce.aviso21_mes)
         order by ce.created_at), '[]'::jsonb)
    from public.cuotas_entreno ce
   where ce.origen = 'natacion' and ce.suscripcion_estado = 'pendiente'
     and coalesce(ce.cobro_abierto, true) and ce.token is not null
     and nullif(btrim(coalesce(ce.email, '')), '') is not null
     and coalesce(ce.metodo, '') <> 'mes_a_mes'
     and exists (select 1 from public.natacion_inscripciones i where i.activa and i.atleta_id = ce.atleta_id);
$$;
revoke all on function public.natacion_aviso21_pendientes() from public, anon, authenticated;
grant execute on function public.natacion_aviso21_pendientes() to service_role;

-- El día 21 de cada mes a las 9:00 (hora de Madrid, invierno y verano).
select cron.unschedule('apolana-natacion-aviso21') where exists (select 1 from cron.job where jobname = 'apolana-natacion-aviso21');
select cron.schedule('apolana-natacion-aviso21', '0 7,8 21 * *',
  $c$ select public.cron_llamar_edge('natacion-cobro-aviso', '{"aviso21": true}'::jsonb, 9) $c$);

commit;
