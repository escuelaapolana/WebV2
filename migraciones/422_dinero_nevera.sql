-- 422 · Dinero: las ventas de la nevera (pagos_online tipo 'nevera', cobradas en el Stripe de Ítaka)
-- salen con su propio origen «nevera» y sección «Nevera», enlazando a admin/nevera, en vez de como
-- «Pago con tarjeta · Sin persona». Andrés, 21-oct-2026: «que salgan en pagos de la app».
begin;
CREATE OR REPLACE FUNCTION public.dinero_movimientos()
 RETURNS TABLE(origen text, ref_id uuid, persona text, atleta_id uuid, concepto text, importe numeric, estado text, cobrado_en date, fecha timestamp with time zone, metodo text, importado boolean, aproximado boolean, detalle text, enlace text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.dinero_puede_ver() then
    raise exception 'Solo administración, tesorería o contabilidad ven el dinero.' using errcode = '42501';
  end if;

  return query
  with
  nom as (
    select a.id, trim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')) as n from public.atletas a
  ),
  cfg as (select coalesce((select precio_alta_socio_cent from public.pagos_config where id = 1), 3500) as alta_cent),

  -- A · Recibos del libro de cobros (y las filas que deja Stripe: stripe:in_…)
  r as (
    select
      case when p.notas like 'stripe:in_%' and p.concepto like 'Cuota El Cubo ·%'   -- 380: lo que escribe el webhook del Cubo
                and not exists (select 1 from public.cuotas_entreno qa where qa.origen = 'asistente' and qa.atleta_id = p.atleta_id
                                   and p.concepto like qa.concepto || ' · %') then 'cubo'
           when p.notas like 'stripe:in_%' then 'entreno'
           else 'recibo' end                                         as origen,
      p.id                                                           as ref_id,
      coalesce(nullif(nom.n,''), 'Sin persona')                      as persona,
      p.atleta_id,
      p.concepto,
      p.importe::numeric                                             as importe,
      case when p.estado = 'pagado' then 'pagado'
           when p.estado = 'impagado' then 'fallido'
           when p.metodo = 'domiciliado' or coalesce(p.notas,'') ilike '%remesa%'
                or p.concepto ilike '%municipal%' then 'remesa'   -- las municipales también las pasa Isa (Andrés, 13-oct)
           else 'pendiente' end                                      as estado,
      case when p.estado = 'pagado' then p.fecha_pago end            as cobrado_en,
      coalesce(p.fecha_pago::timestamptz, p.fecha_vencimiento::timestamptz, p.created_at) as fecha,
      p.metodo,
      (p.estado = 'pagado' and p.metodo is null and coalesce(p.notas,'') not like 'stripe:%') as importado,
      false                                                          as aproximado,
      case when p.estado = 'pagado' and p.metodo is null and coalesce(p.notas,'') not like 'stripe:%'
             then 'Registro sin forma de cobro (importación o marcado a mano)'
           when p.notas like 'stripe:in_%' then 'Cobrado por Stripe'
           when p.estado = 'impagado' then 'Impagado / devuelto'
           when p.estado = 'pendiente' and p.fecha_vencimiento is not null
             then 'Vence el ' || to_char(p.fecha_vencimiento, 'DD/MM/YYYY')
           else nullif(p.notas,'') end                               as detalle,
      case when p.notas like 'stripe:in_%' and p.concepto like 'Cuota El Cubo ·%'   -- 380: lo que escribe el webhook del Cubo
                and not exists (select 1 from public.cuotas_entreno qa where qa.origen = 'asistente' and qa.atleta_id = p.atleta_id
                                   and p.concepto like qa.concepto || ' · %') then 'admin/cubo-altas/'
           when p.notas like 'stripe:in_%' then 'admin/cuotas-entreno/'
           else 'admin/cobros/' end                                  as enlace
    from public.pagos p
    left join nom on nom.id = p.atleta_id
    where not p.anulado
  ),

  -- B · El Cubo: cuota mensual (suscripción de Stripe)
  cu as (
    select
      'cubo'::text, ca.id,
      trim(ca.nombre || ' ' || ca.apellidos),
      ca.atleta_id,
      case when ca.suscripcion_estado = 'impago' then 'Cuota El Cubo · recibo fallido'
           else 'Cuota El Cubo · primer pago' end,
      case when ca.suscripcion_estado = 'impago' then ca.precio_mes::numeric
           else coalesce(ca.primer_pago_cent / 100.0, ca.precio_mes::numeric) end,
      case when ca.suscripcion_estado = 'impago' then 'fallido' else 'pendiente' end,
      null::date,
      coalesce(ca.cobro_avisado_en, ca.created_at),
      'tarjeta'::text,
      false, false,
      case when ca.suscripcion_estado = 'impago' then 'Stripe no pudo cobrar el recibo mensual'
           when ca.cobro_avisado_en is not null
             then 'Cobro abierto, sin pagar · avisado el ' || to_char(ca.cobro_avisado_en at time zone 'Europe/Madrid', 'DD/MM')
           else 'Cobro abierto, sin pagar' end,
      'admin/cubo-altas/'::text
    from public.cubo_altas ca
    where ca.estado = 'aprobada'
      and not coalesce(ca.lista_espera, false)
      and ca.pago_externo is null
      and ( ca.suscripcion_estado = 'impago'
         or (coalesce(ca.cobro_abierto, false) and ca.suscripcion_estado is null) )
  ),
  -- B2 · El Cubo: último cobro de Stripe que aún no tiene su fila en `pagos`
  cu_ult as (
    select
      'cubo'::text, ca.id,
      trim(ca.nombre || ' ' || ca.apellidos),
      ca.atleta_id,
      'Cuota El Cubo · ' || (array['enero','febrero','marzo','abril','mayo','junio','julio','agosto',
                                  'septiembre','octubre','noviembre','diciembre'])
                                 [extract(month from ca.ultimo_cobro at time zone 'Europe/Madrid')::int]
                           || ' ' || extract(year from ca.ultimo_cobro at time zone 'Europe/Madrid')::int,
      x.imp,
      'pagado'::text,
      (ca.ultimo_cobro at time zone 'Europe/Madrid')::date,
      ca.ultimo_cobro,
      'tarjeta'::text,
      false, true,
      'Último cobro según Stripe (importe deducido)'::text,
      'admin/cubo-altas/'::text
    from public.cubo_altas ca
    cross join lateral (
      select case
        when extract(day from ca.ultimo_cobro at time zone 'Europe/Madrid') = 5 then ca.precio_mes::numeric
        when ca.primer_pago_cent is not null then ca.primer_pago_cent / 100.0
        else null end as imp
    ) x
    where ca.ultimo_cobro is not null
      and x.imp is not null
      and not exists (
        select 1 from public.pagos p
         where p.notas like 'stripe:in_%'
           and p.atleta_id = ca.atleta_id
           and p.fecha_pago = (ca.ultimo_cobro at time zone 'Europe/Madrid')::date
           and not p.anulado)
  ),
  -- C · Cobros puntuales del Cubo («ponle un pago»)
  cc as (
    select
      'cubo'::text, c.id,
      coalesce(trim(ca.nombre || ' ' || ca.apellidos), 'Sin persona'),
      ca.atleta_id,
      c.concepto,
      c.importe_cent / 100.0,
      case when c.estado = 'pagado' then 'pagado' else 'pendiente' end,
      case when c.estado = 'pagado' then (c.pagado_en at time zone 'Europe/Madrid')::date end,
      coalesce(c.pagado_en, c.created_at),
      'tarjeta'::text,
      false, false,
      'Cobro puntual del Cubo'::text,
      'admin/cubo-altas/'::text
    from public.cubo_cobros c
    left join public.cubo_altas ca on ca.id = c.alta_id
    where c.estado in ('pendiente','pagado')
  ),
  -- D · Cuotas de entreno (suscripción SEPA trimestral)
  ce as (
    select
      'entreno'::text, q.id,
      trim(coalesce(q.nombre,'') || ' ' || coalesce(q.apellidos,'')),
      q.atleta_id,
      q.concepto,
      q.importe_cent / 100.0,
      case q.suscripcion_estado when 'en_camino' then 'en_camino'
                                when 'impago'    then 'fallido'
                                else 'pendiente' end,
      null::date,
      coalesce(q.factura_fecha, q.created_at),
      case when q.metodo = 'tarjeta' then 'tarjeta' else 'domiciliado' end,   -- 380
      false, false,
      case q.suscripcion_estado
        when 'en_camino' then 'Mandato SEPA firmado; el primer adeudo tarda ~5 días hábiles (hasta 14)'
        when 'impago'    then case when q.metodo = 'tarjeta' then 'El cobro con tarjeta falló'      -- 380
                               else 'El adeudo falló o se devolvió' end
        else case when q.metodo = 'tarjeta' then 'Sin pagar: aún no ha metido su tarjeta'          -- 380
                  else 'Sin domiciliar: aún no ha metido su IBAN' end end,
      'admin/cuotas-entreno/'::text
    from public.cuotas_entreno q
    where q.suscripcion_estado in ('pendiente','en_camino','impago')
      and (q.cobro_abierto or q.suscripcion_estado <> 'pendiente')
  ),
  -- E · Altas de socio (35 € por SEPA en la pasarela)
  so as (
    select
      'alta_socio'::text, a.id,
      trim(a.nombre || ' ' || coalesce(a.apellidos,'')),
      a.atleta_id,
      'Alta de socio · ' || a.referencia,
      coalesce(po.importe_centimos, (select alta_cent from cfg)) / 100.0,
      case a.pago_estado when 'pagado' then 'pagado'
                         when 'en_camino' then 'en_camino'
                         when 'fallido' then 'fallido'
                         when 'devuelto' then 'fallido'
                         else 'pendiente' end,
      case when a.pago_estado = 'pagado'
           then (coalesce(po.pagado_en, a.pagado_en) at time zone 'Europe/Madrid')::date end,
      coalesce(case when a.pago_estado = 'pagado' then coalesce(po.pagado_en, a.pagado_en) end,
               a.mandato_firmado_en, a.created_at),
      coalesce(po.metadatos ->> 'metodo', 'domiciliado'),
      false, false,
      case a.pago_estado
        when 'en_camino' then 'Mandato SEPA firmado el ' || to_char(a.mandato_firmado_en at time zone 'Europe/Madrid', 'DD/MM')
                              || '; el primer adeudo tarda ~5 días hábiles (hasta 14)'
        when 'fallido'   then 'El adeudo SEPA falló'
        when 'devuelto'  then 'El adeudo SEPA se devolvió'
        when 'pagado'    then nullif(po.metadatos ->> 'nota','')
        else case when a.stripe_session_id is not null then 'Empezó a pagar y no terminó' else 'Aún no ha pagado' end end,
      'admin/altas/?tipo=socio'::text
    from public.altas_socio a
    left join public.pagos_online po on po.referencia = 'socio-' || a.id::text
    where a.estado <> 'rechazada'
  ),
  -- F · Pagos online sueltos (tienda, bonos…). Los de recibo y alta de socio ya
  --     cuentan arriba (A y E): aquí no, para no contarlos dos veces.
  po as (
    select
      case po.tipo when 'ropa' then 'tienda' when 'bono' then 'bono' when 'nevera' then 'nevera' else 'online' end,
      po.id,
      case when po.tipo = 'nevera' then 'Nevera (venta con QR)' else coalesce(nullif(nom.n,''), nullif(trim(coalesce(pf.nombre,'') || ' ' || coalesce(pf.apellidos,'')),''), 'Sin persona') end,
      po.atleta_id,
      po.concepto,
      po.importe_centimos / 100.0,
      case when po.estado = 'pagado' then 'pagado' else 'devuelto' end,
      case when po.estado = 'pagado' then (po.pagado_en at time zone 'Europe/Madrid')::date end,
      coalesce(po.pagado_en, po.creado_en),
      'tarjeta'::text,
      false, false,
      case po.estado when 'reembolsado' then 'Devuelto (reembolso)' when 'fallido' then 'El pago falló' else null end,
      case po.tipo when 'ropa' then 'admin/pedidos/' when 'nevera' then 'admin/nevera/' else 'admin/pagos-online/' end
    from public.pagos_online po
    left join nom on nom.id = po.atleta_id
    left join public.perfiles pf on pf.id = po.perfil_id
    where po.tipo not in ('recibo','alta_socio')
      and po.estado in ('pagado','reembolsado')
  )
  select u.origen, u.ref_id, u.persona, u.atleta_id, u.concepto,
         round(u.importe, 2), u.estado, u.cobrado_en, u.fecha, u.metodo,
         u.importado, u.aproximado, u.detalle, u.enlace
    from (
            select * from r
  union all select * from cu
  union all select * from cu_ult
  union all select * from cc
  union all select * from ce
  union all select * from so
  union all select * from po
    ) u;
end;
$function$;

CREATE OR REPLACE FUNCTION public.dinero_movimientos_v2()
 RETURNS TABLE(origen text, ref_id uuid, persona text, atleta_id uuid, concepto text, importe numeric, estado text, cobrado_en date, fecha timestamp with time zone, metodo text, importado boolean, aproximado boolean, detalle text, enlace text, tipo text, seccion text, fecha_limite date, fuera_plazo boolean, mes_ref date, grupo_clave text, lote uuid, periodo text, numero_recibo text, aviso text, puede_marcar boolean, alta_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_hoy date := (now() at time zone 'Europe/Madrid')::date;
  v_mes date := date_trunc('month', (now() at time zone 'Europe/Madrid'))::date;
begin
  if not public.dinero_puede_ver() then
    raise exception 'Solo administración, tesorería o contabilidad ven el dinero.' using errcode = '42501';
  end if;

  return query
  with m as (select * from public.dinero_movimientos()),
  x as (
    select m.*,
           p.fecha_vencimiento as p_venc, p.lote as p_lote, p.periodo as p_periodo,
           p.numero_recibo as p_num, p.metodo as p_metodo, coalesce(p.notas,'') as p_notas,
           ca.id as ca_id, ca.suscripcion_estado as ca_sus,
           cc.alta_id as cc_alta,
           q.suscripcion_estado as q_sus,
           (select ca2.id from public.cubo_altas ca2
             where m.origen = 'cubo' and ca2.atleta_id = m.atleta_id and ca2.estado = 'aprobada'
             order by ca2.created_at desc limit 1) as ca_atleta,
           (select g.seccion from public.atleta_grupos ag join public.grupos g on g.id = ag.grupo_id
             where ag.atleta_id = m.atleta_id
             order by ag.principal desc, ag.desde limit 1) as g_sec,
           a.tipo_membresia
      from m
      left join public.pagos          p  on p.id  = m.ref_id and m.origen in ('recibo','cubo','entreno')
      left join public.cubo_altas     ca on ca.id = m.ref_id and m.origen = 'cubo'
      left join public.cubo_cobros    cc on cc.id = m.ref_id and m.origen = 'cubo'
      left join public.cuotas_entreno q  on q.id  = m.ref_id and m.origen = 'entreno'
      left join public.atletas        a  on a.id  = m.atleta_id
  ),
  y as (
    select x.*,
      case when x.estado = 'remesa' then 'remesa'
           when x.origen = 'recibo' and x.estado = 'pagado' and x.p_metodo = 'domiciliado' then 'remesa'
           when x.origen = 'cubo' then 'cubo'
           when x.origen = 'entreno' then 'cuota'
           else 'unico' end as c_tipo,
      case when x.origen = 'recibo' then x.p_venc end as c_lim
    from x
  ),
  z as (
    select y.*,
      (y.estado = 'fallido' or (y.estado = 'pendiente' and y.c_lim is not null and y.c_lim < v_hoy)) as c_fuera
    from y
  )
  select z.origen, z.ref_id, z.persona, z.atleta_id, z.concepto, z.importe, z.estado,
         z.cobrado_en, z.fecha, z.metodo, z.importado, z.aproximado, z.detalle, z.enlace,
         z.c_tipo,
         case when z.origen = 'cubo' then 'cubo'
              when z.origen = 'alta_socio' then 'socios'
              when z.origen = 'tienda' then 'tienda'
              when z.origen = 'nevera' then 'nevera'
              when z.origen = 'entreno' and z.concepto ilike '%nataci%' then 'natacion'
              else coalesce(z.g_sec,
                     case z.tipo_membresia when 'socio' then 'socios' when 'cubo' then 'cubo'
                                           when 'escuela' then 'escuela' when 'municipal' then 'escuela' end)
         end,
         z.c_lim,
         z.c_fuera,
         case when z.estado = 'pagado' then date_trunc('month', coalesce(z.cobrado_en, (z.fecha at time zone 'Europe/Madrid')::date))::date
              when z.c_lim is not null then date_trunc('month', z.c_lim)::date
              when z.estado = 'devuelto' then date_trunc('month', (z.fecha at time zone 'Europe/Madrid')::date)::date
              else v_mes end,
         case when z.origen = 'recibo'
              then coalesce('lote:' || z.p_lote::text,
                            'c:' || lower(btrim(z.concepto)) || '|' || coalesce(z.p_periodo,''))
              else z.origen end,
         z.p_lote, z.p_periodo, z.p_num,
         case when z.origen = 'recibo' and z.estado = 'pendiente' and z.atleta_id is not null
                   and z.p_notas not like 'stripe:%'
                   and coalesce(z.p_metodo, '') <> 'efectivo' then 'recibo-aviso'   -- 380: el efectivo no se «paga con tarjeta»
              when z.origen = 'cubo' and z.ca_id is not null and z.estado = 'pendiente'
                   and z.ca_sus is null then 'cubo-cobro-aviso'
              when z.origen = 'entreno' and z.estado = 'pendiente' and z.q_sus = 'pendiente' then 'entreno-enlace'
         end,
         (z.origen = 'recibo' and z.estado in ('pendiente','fallido') and z.p_notas not like 'stripe:%'),
         case when z.origen = 'cubo' then coalesce(z.ca_id, z.cc_alta, z.ca_atleta) end
    from z;
end;
$function$;
commit;
