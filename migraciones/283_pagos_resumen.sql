-- 283 · Panel de pagos (resumen). Opción A: previsto + cobrado, crece con el uso.
-- Reúne lo que SÍ pasa por la app: suscripciones del Cubo (cubo_altas), cobros
-- online de Stripe (pagos_online) y recibos (pagos). Las cuotas de socio van
-- por banco (Isa), fuera de la app, así que solo se cuenta el nº de socios.
-- Solo admin/staff.

create or replace function public.pagos_resumen()
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $function$
declare r jsonb;
begin
  if not (public.es_admin() or public.es_staff()) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;

  select jsonb_build_object(
    'ok', true,
    'cubo', (
      select jsonb_build_object(
        'activas',       count(*),
        'mensual_eur',   round(coalesce(sum(coalesce(precio_mes,0)),0)::numeric, 2),
        'ultimo_cobro',  max(ultimo_cobro)::date,
        'proximo_cobro', min(proximo_cobro)::date,
        'bajas',         count(*) filter (where baja_solicitada is not null)
      ) from public.cubo_altas where suscripcion_estado = 'activa'
    ),
    'online', (
      select coalesce(jsonb_agg(q.x order by q.tipo, q.estado), '[]'::jsonb) from (
        select tipo, estado,
               jsonb_build_object('tipo',tipo,'estado',estado,'n',count(*),
                                  'eur', round(sum(importe_centimos)/100.0, 2)) as x
        from public.pagos_online group by tipo, estado
      ) q
    ),
    'recibos', (
      select jsonb_build_object(
        'pagado_n',     count(*) filter (where estado='pagado'),
        'pagado_eur',   round(coalesce(sum(importe) filter (where estado='pagado'),0)::numeric,2),
        'pendiente_n',  count(*) filter (where estado='pendiente'),
        'pendiente_eur',round(coalesce(sum(importe) filter (where estado='pendiente'),0)::numeric,2),
        'impagado_n',   count(*) filter (where estado='impagado' or (estado='pendiente' and fecha_vencimiento < current_date)),
        'impagado_eur', round(coalesce(sum(importe) filter (where estado='impagado' or (estado='pendiente' and fecha_vencimiento < current_date)),0)::numeric,2)
      ) from public.pagos where not coalesce(anulado, false)
    ),
    'socios', (select count(*) filter (where tipo_membresia='socio' or numero_socio is not null) from public.atletas),
    'precio_alta_socio_eur', (select round(coalesce(precio_alta_socio_cent,0)/100.0,2) from public.pagos_config limit 1)
  ) into r;

  return r;
end $function$;

grant execute on function public.pagos_resumen() to authenticated;
