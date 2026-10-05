-- 287 · El Cubo: marcar CÓMO PAGA cada persona (por la app, o fuera: efectivo /
-- transferencia). Quien paga fuera NO debe salir como «de prueba» ni tener el
-- botón de pagar en su portal. Caso disparador: Eva Valero paga en efectivo
-- trimestral. De paso se recrea general_resumen para dos ajustes (ver abajo).

-- 1 · Columna: cómo paga (null = por la app / Stripe, como hasta ahora).
alter table public.cubo_altas
  add column if not exists pago_externo text
  check (pago_externo is null or pago_externo in ('efectivo','transferencia','otro'));
comment on column public.cubo_altas.pago_externo is
  'Cómo paga fuera de la app: efectivo | transferencia | otro. NULL = paga por la app (Stripe).';

-- 2 · RPC para fijarlo desde el panel (no hay policy UPDATE directa en cubo_altas).
--     Al marcar un método externo, se cierra el cobro de la app (no paga por ahí).
create or replace function public.cubo_pago_externo_set(p_id uuid, p_metodo text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
begin
  if not (public.es_admin() or public.es_staff()) then
    raise exception 'Sin permiso';
  end if;
  if p_metodo is not null and p_metodo not in ('efectivo','transferencia','otro') then
    raise exception 'Método de pago no válido: %', p_metodo;
  end if;
  update public.cubo_altas
     set pago_externo = p_metodo,
         cobro_abierto = case when p_metodo is not null then false else cobro_abierto end
   where id = p_id;
end $$;
grant execute on function public.cubo_pago_externo_set(uuid, text) to authenticated;

-- 3 · Eva Marina Valero Pomares: paga en EFECTIVO (trimestral) → fuera de la app.
update public.cubo_altas
   set pago_externo = 'efectivo', cobro_abierto = false
 where id = 'ff4b4743-27b1-41cb-a39c-d92a872ac3ce';

-- 4 · general_resumen (avisos del Inicio), dos ajustes:
--   (a) las SOLICITUDES DE PRUEBA de la web ya van por WhatsApp al responsable;
--       se quedan de respaldo en el buzón pero NO cuentan en el aviso de Andrés.
--   (b) quien paga fuera de la app (pago_externo) NO cuenta como «de prueba del
--       Cubo» (no hay nada que decidirle).
create or replace function public.general_resumen()
returns jsonb
language sql stable security definer set search_path to 'public'
as $function$
  select case when not (public.es_admin() or public.es_staff()) then '{}'::jsonb
  else jsonb_build_object(
    'altas_socio',   (select count(*) from altas_socio   where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'altas_escuela', (select count(*) from altas_escuela where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_altas',    (select count(*) from cubo_altas    where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_prueba',   (select count(*) from cubo_prueba),
    'cubo_prueba_decidir', (
       select count(*) from cubo_altas
       where estado = 'aprobada'
         and suscripcion_estado is distinct from 'activa'
         and not coalesce(cobro_abierto, false)
         and not coalesce(lista_espera, false)
         and pago_externo is null
         and created_at <= now() - interval '7 days'),
    'buzon',         (select count(*) from buzon_bandeja where atendido is not true),
    'solicitudes',   (select count(*) from solicitudes_inscripcion
                       where atendida is not true
                         and coalesce(comentario,'') not ilike 'SOLICITUD DE PRUEBA%'),
    'liga_validar',  (select count(*) from liga_participaciones where estado = 'pendiente')
  ) end
$function$;

notify pgrst, 'reload schema';
