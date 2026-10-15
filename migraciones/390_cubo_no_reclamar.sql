-- 390 · El Cubo: «no reclamar el pago hasta que venga» pasa de nota a DATO
-- ---------------------------------------------------------------------------
-- Andrés (15-oct): escribió uno a uno por WhatsApp a los del Cubo que no
-- habían pagado octubre. Ahora hay un botón «Recordar a los que no han
-- pagado (N)» en admin/cubo-altas (pestaña Personas) que manda el correo
-- con la Edge `cubo-cobro-aviso` en modo recordatorio.
--
-- Hay excepciones: hoy Marta García Rodríguez tenía en `nota_cobro`
-- «NO reclamar el pago hasta que venga al menos 1 día». Eso ahora es un dato:
--   · no_reclamar_hasta_asistir  → el recordatorio la salta
--   · no_reclamar_desde          → desde cuándo. En cuanto tenga UNA
--     asistencia (asistencia.presente) con fecha >= ese día, deja de
--     saltarse SOLA (se calcula al vuelo en el panel y en la Edge; no hace
--     falta desmarcarla).
--   · cobro_recordado_en         → último recordatorio enviado (el botón
--     también sella cobro_avisado_en, como siempre). Sirve además para que
--     el viejo «Reenviar corrección a los avisados hoy» no cuente a los que
--     solo han recibido el recordatorio.
--
-- Se marca/desmarca desde la ficha del Cubo con la RPC cubo_no_reclamar_set
-- (mismo permiso que el resto de pasos del Cubo: cubo_es_gestor()).
-- ---------------------------------------------------------------------------
begin;

alter table public.cubo_altas
  add column if not exists no_reclamar_hasta_asistir boolean not null default false,
  add column if not exists no_reclamar_desde timestamptz,
  add column if not exists cobro_recordado_en timestamptz;

comment on column public.cubo_altas.no_reclamar_hasta_asistir is
  'No reclamar el pago (recordatorio) hasta que venga al menos 1 día después de no_reclamar_desde. Se apaga solo al tener una asistencia presente posterior.';
comment on column public.cubo_altas.no_reclamar_desde is
  'Cuándo se marcó «no reclamar hasta que venga». Cuenta la asistencia con fecha >= este día (hora de Madrid).';
comment on column public.cubo_altas.cobro_recordado_en is
  'Último correo de RECORDATORIO de pago (botón «Recordar a los que no han pagado»).';

-- Marcar / desmarcar desde la ficha del Cubo.
create or replace function public.cubo_no_reclamar_set(p_id uuid, p_on boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not public.cubo_es_gestor() then
    return jsonb_build_object('ok', false, 'error', 'Sin permiso');
  end if;
  update public.cubo_altas
     set no_reclamar_hasta_asistir = coalesce(p_on, false),
         no_reclamar_desde = case when coalesce(p_on, false) then now() else null end
   where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no encontrada');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
revoke execute on function public.cubo_no_reclamar_set(uuid, boolean) from public, anon;
grant  execute on function public.cubo_no_reclamar_set(uuid, boolean) to authenticated, service_role;

-- La excepción de hoy: Marta García Rodríguez (pedido por Andrés el 15-oct).
-- Desde el 15-oct a las 00:00 de Madrid: si viene ese mismo día, ya cuenta.
-- De la nota se quita la orden (ya es un dato) pero se conserva el contexto.
-- OJO: la parte de nota_cobro tras « · » es interna; la Edge solo manda el
-- primer trozo al correo.
update public.cubo_altas
   set no_reclamar_hasta_asistir = true,
       no_reclamar_desde = coalesce(no_reclamar_desde, timestamptz '2026-10-15 00:00:00 Europe/Madrid'),
       nota_cobro = replace(nota_cobro,
         'NO reclamar el pago hasta que venga al menos 1 día (15-oct, Andrés): quiere seguir, ha tenido trabajo',
         '15-oct (Andrés): quiere seguir, ha tenido trabajo · no reclamar hasta que venga (marcado en la ficha)')
 where id = '3547987a-49a9-4bd4-b339-2058b6355793';

commit;
