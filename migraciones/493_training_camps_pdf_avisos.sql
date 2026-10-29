-- ===========================================================================
-- 493 · Training Camps · datos del presupuesto para el PDF y aviso de cobro
-- ---------------------------------------------------------------------------
--   · camp_propuesta_json(id): lo que ve el cliente de un presupuesto (sin
--     costes ni notas internas). La usan el enlace del cliente (por token) y el
--     panel (por id, para ver el PDF de un borrador antes de enviarlo).
--   · camp_pagos.avisado_cobro_en: el correo de «pago recibido» sale una vez.
-- ===========================================================================
begin;

alter table public.camp_pagos add column avisado_cobro_en timestamptz;

create or replace function public.camp_propuesta_json(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
declare e public.camp_presupuestos; s public.camp_solicitudes; g public.camp_config; v_actual text;
begin
  select * into e from public.camp_presupuestos where id = p_id;
  if e.id is null then return null; end if;
  select * into s from public.camp_solicitudes where id = e.solicitud_id;
  select * into g from public.camp_config where id = 1;
  select token into v_actual from public.camp_presupuestos
   where solicitud_id = e.solicitud_id and estado in ('enviado','aceptado') and id <> e.id and token is not null
   order by version desc limit 1;
  return jsonb_build_object(
    'numero', e.numero, 'version', e.version, 'estado', e.estado, 'idioma', e.idioma, 'fecha', e.fecha,
    'valido_hasta', e.valido_hasta, 'caducado', e.estado = 'enviado' and e.valido_hasta is not null and e.valido_hasta < public.camp_hoy(),
    'titulo', e.titulo, 'llegada', e.llegada, 'salida', e.salida, 'participantes', e.participantes,
    'lineas', (select coalesce(jsonb_agg(l - 'coste' - 'id'), '[]') from jsonb_array_elements(e.lineas) l),
    'base', e.base, 'impuestos', e.impuestos, 'total', e.total, 'senal', e.senal, 'saldo', e.saldo,
    'senal_tipo', e.senal_tipo, 'senal_valor', e.senal_valor, 'saldo_vence', e.saldo_vence, 'desglose', e.desglose,
    'notas_cliente', e.notas_cliente,
    'condiciones_version', coalesce(e.aceptado_condiciones, e.condiciones_version, (select version from public.camp_condiciones_vigente())),
    'aceptado_en', e.aceptado_en, 'aceptado_nombre', e.aceptado_nombre, 'aceptado_por', e.aceptado_por,
    'sustituido_por', case when e.estado = 'sustituido' then v_actual end,
    'expediente', jsonb_build_object('codigo', s.codigo, 'entidad', s.entidad, 'contacto', s.contacto, 'pais', s.pais,
                                     'email', s.email, 'cancelado', s.estado = 'cancelada'),
    'emisor', g.emisor, 'nota_impuestos', case when e.idioma = 'es' then g.nota_impuestos_es else g.nota_impuestos_en end,
    'formas_pago', case when e.idioma = 'es' then g.formas_pago_es else g.formas_pago_en end,
    'pagos', (select coalesce(jsonb_agg(jsonb_build_object('tipo', cp.tipo, 'concepto', cp.concepto, 'importe', cp.importe,
                'vence', cp.vence, 'pagado', p.estado = 'pagado', 'fecha_pago', p.fecha_pago,
                'token', case when p.estado <> 'pagado' then cp.token end) order by cp.creado_en), '[]')
              from public.camp_pagos cp join public.pagos p on p.id = cp.pago_id
             where cp.presupuesto_id = e.id and cp.anulado_en is null));
end $$;

create or replace function public.camp_propuesta_publica(p_token text) returns jsonb
language sql stable security definer set search_path to 'public' as $$
  select public.camp_propuesta_json(id) from public.camp_presupuestos
   where length(coalesce(p_token, '')) >= 40 and token = p_token
$$;

create or replace function public.camp_propuesta_admin(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  return public.camp_propuesta_json(p_id);
end $$;

-- Marca el aviso de cobro (devuelve true solo la primera vez: así el correo sale una vez).
create or replace function public.camp_pago_avisar(p_token text) returns boolean
language plpgsql security definer set search_path to 'public' as $$
declare v int;
begin
  update public.camp_pagos cp set avisado_cobro_en = now()
   where cp.token = p_token and cp.avisado_cobro_en is null
     and exists (select 1 from public.pagos p where p.id = cp.pago_id and p.estado = 'pagado');
  get diagnostics v = row_count;
  return v > 0;
end $$;

revoke execute on function public.camp_propuesta_json(uuid), public.camp_propuesta_admin(uuid), public.camp_pago_avisar(text)
  from public, anon, authenticated;
grant execute on function public.camp_propuesta_admin(uuid) to authenticated;
grant execute on function public.camp_pago_avisar(text) to service_role;

commit;
