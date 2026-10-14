-- 370 · Dinero v2 · pestañas (Resumen · Cuotas · Cobros únicos · Todos los pagos · Próximos · Al banco)
-- ---------------------------------------------------------------------------
-- admin/dinero/ pasa a pestañas por URL (?v=…), inspirada en SportMember y
-- aprobada por Andrés. La fuente sigue siendo UNA: dinero_movimientos() (312).
-- Aquí se le añade lo que la pantalla nueva necesita, sin tocar sus reglas:
--
--   dinero_movimientos()      se vuelve a aplicar TAL CUAL está en 312. OJO: en
--                             la base seguía la versión vieja SIN «municipal =
--                             remesa» (commit d58b3e1 no se llegó a aplicar):
--                             30 recibos municipales (9.600 €) salían en «Te
--                             deben». Con esta migración pasan a la remesa de Isa.
--   dinero_movimientos_v2()   las mismas filas + tipo (cubo · cuota · unico ·
--                             remesa), sección, fecha límite, fuera de plazo,
--                             mes de referencia, lote, qué aviso se puede mandar
--                             y si se puede marcar pagado en efectivo.
--   dinero_resumen_mes(mes)   la tabla del Resumen: por tipo, pagado · pendiente ·
--                             fuera de plazo (+ en camino SEPA e importados).
--   dinero_cuotas(mes)        El Cubo por precio y las cuotas domiciliadas.
--   dinero_proximos()         lo que se va a cobrar y cuándo.
--   dinero_marcar_efectivo()  «Marcar pagado (efectivo)» en bloque (solo recibos).
--
-- REGLAS (las de 312, no cambian)
--   · Remesa de Isa = informativa, no deuda. Importados no cuentan como «ha entrado».
--   · SEPA en_camino ≠ pagado.
--   · FUERA DE PLAZO = recibo pendiente con fecha límite < hoy, o cualquier cosa
--     «fallido» (Cubo impago, cuota impago, recibo impagado, alta devuelta).
--     La remesa nunca está fuera de plazo (no es deuda).
--   · MES DE REFERENCIA (mes_ref): pagado → mes del cobro real; con fecha límite →
--     su mes; sin fecha (Cubo con cobro abierto, cuota sin IBAN, en camino…) →
--     el mes actual (se debe ahora). Lo fuera de plazo se arrastra: en el mes M
--     salen los fuera de plazo con mes_ref <= M.
-- ---------------------------------------------------------------------------
begin;

-- 1 · dinero_movimientos() de 312, tal cual (con «municipal = remesa»)
create or replace function public.dinero_movimientos()
returns table (
  origen      text,         -- recibo · cubo · entreno · alta_socio · tienda · bono · online
  ref_id      uuid,
  persona     text,
  atleta_id   uuid,
  concepto    text,
  importe     numeric,      -- euros
  estado      text,         -- pagado · en_camino · pendiente · fallido · remesa · devuelto
  cobrado_en  date,         -- fecha REAL de cobro (solo pagado)
  fecha       timestamptz,  -- fecha para ordenar (cobro, firma o creación)
  metodo      text,
  importado   boolean,      -- registro/importación: no suma en «Ha entrado»
  aproximado  boolean,      -- importe deducido (Cubo antes del histórico)
  detalle     text,
  enlace      text          -- pantalla de detalle (relativa a la raíz de la web)
)
language plpgsql stable security definer set search_path to 'public' as $function$
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
      case when p.notas like 'stripe:in_%' and p.concepto ilike '%cubo%' then 'cubo'
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
      case when p.notas like 'stripe:in_%' and p.concepto ilike '%cubo%' then 'admin/cubo-altas/'
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
      'domiciliado'::text,
      false, false,
      case q.suscripcion_estado
        when 'en_camino' then 'Mandato SEPA firmado; el primer adeudo tarda ~5 días hábiles (hasta 14)'
        when 'impago'    then 'El adeudo falló o se devolvió'
        else 'Sin domiciliar: aún no ha metido su IBAN' end,
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
      case po.tipo when 'ropa' then 'tienda' when 'bono' then 'bono' else 'online' end,
      po.id,
      coalesce(nullif(nom.n,''), nullif(trim(coalesce(pf.nombre,'') || ' ' || coalesce(pf.apellidos,'')),''), 'Sin persona'),
      po.atleta_id,
      po.concepto,
      po.importe_centimos / 100.0,
      case when po.estado = 'pagado' then 'pagado' else 'devuelto' end,
      case when po.estado = 'pagado' then (po.pagado_en at time zone 'Europe/Madrid')::date end,
      coalesce(po.pagado_en, po.creado_en),
      'tarjeta'::text,
      false, false,
      case po.estado when 'reembolsado' then 'Devuelto (reembolso)' when 'fallido' then 'El pago falló' else null end,
      case po.tipo when 'ropa' then 'admin/pedidos/' else 'admin/pagos-online/' end
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
revoke all on function public.dinero_movimientos() from public, anon;
grant execute on function public.dinero_movimientos() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- dinero_movimientos_v2 · las mismas filas con lo que necesitan las pestañas
-- ---------------------------------------------------------------------------
create or replace function public.dinero_movimientos_v2()
returns table (
  origen        text,
  ref_id        uuid,
  persona       text,
  atleta_id     uuid,
  concepto      text,
  importe       numeric,
  estado        text,
  cobrado_en    date,
  fecha         timestamptz,
  metodo        text,
  importado     boolean,
  aproximado    boolean,
  detalle       text,
  enlace        text,
  tipo          text,     -- cubo · cuota · unico · remesa
  seccion       text,     -- escuela · cubo · natacion · escuela-natacion · competicion · running · socios · tienda · null
  fecha_limite  date,     -- fecha de vencimiento (recibos)
  fuera_plazo   boolean,
  mes_ref       date,     -- día 1 del mes al que pertenece
  grupo_clave   text,     -- para «Cobros únicos»: lote o concepto+periodo
  lote          uuid,
  periodo       text,
  numero_recibo text,
  aviso         text,     -- recibo-aviso · cubo-cobro-aviso · entreno-enlace · null
  puede_marcar  boolean,  -- «Marcar pagado (efectivo)»: solo recibos pendientes/impagados
  alta_id       uuid      -- El Cubo: a qué alta pertenece
)
language plpgsql stable security definer set search_path to 'public' as $function$
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
                   and z.p_notas not like 'stripe:%' then 'recibo-aviso'
              when z.origen = 'cubo' and z.ca_id is not null and z.estado = 'pendiente'
                   and z.ca_sus is null then 'cubo-cobro-aviso'
              when z.origen = 'entreno' and z.estado = 'pendiente' and z.q_sus = 'pendiente' then 'entreno-enlace'
         end,
         (z.origen = 'recibo' and z.estado in ('pendiente','fallido') and z.p_notas not like 'stripe:%'),
         case when z.origen = 'cubo' then coalesce(z.ca_id, z.cc_alta, z.ca_atleta) end
    from z;
end;
$function$;
revoke all on function public.dinero_movimientos_v2() from public, anon;
grant execute on function public.dinero_movimientos_v2() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- dinero_resumen_mes · la tabla del Resumen para un mes
-- ---------------------------------------------------------------------------
create or replace function public.dinero_resumen_mes(p_mes date default null)
returns jsonb
language plpgsql stable security definer set search_path to 'public' as $function$
declare
  v_hoy date := (now() at time zone 'Europe/Madrid')::date;
  v_act date := date_trunc('month', (now() at time zone 'Europe/Madrid'))::date;
  v_m   date := date_trunc('month', coalesce(p_mes, (now() at time zone 'Europe/Madrid')::date))::date;
  v_res jsonb;
begin
  if not public.dinero_puede_ver() then
    raise exception 'Solo administración, tesorería o contabilidad ven el dinero.' using errcode = '42501';
  end if;

  with m as (select * from public.dinero_movimientos_v2()),
  t(tipo, orden) as (values ('cubo',1),('cuota',2),('unico',3),('remesa',4)),
  f as (
    select t.tipo, t.orden,
      count(m.*) filter (where m.estado = 'pagado' and not m.importado and m.mes_ref = v_m)                    as pag_n,
      coalesce(sum(m.importe) filter (where m.estado = 'pagado' and not m.importado and m.mes_ref = v_m), 0)   as pag_e,
      count(m.*) filter (where m.estado in ('pendiente','remesa') and not m.fuera_plazo and m.mes_ref = v_m)   as pen_n,
      coalesce(sum(m.importe) filter (where m.estado in ('pendiente','remesa') and not m.fuera_plazo and m.mes_ref = v_m), 0) as pen_e,
      count(m.*) filter (where m.fuera_plazo and m.mes_ref <= v_m)                                            as fue_n,
      coalesce(sum(m.importe) filter (where m.fuera_plazo and m.mes_ref <= v_m), 0)                           as fue_e,
      count(m.*) filter (where m.estado = 'en_camino' and m.mes_ref = v_m)                                    as cam_n,
      coalesce(sum(m.importe) filter (where m.estado = 'en_camino' and m.mes_ref = v_m), 0)                   as cam_e
    from t left join m on m.tipo = t.tipo
    group by t.tipo, t.orden
  )
  select jsonb_build_object(
    'hoy', v_hoy,
    'mes', to_char(v_m, 'YYYY-MM'),
    'es_mes_actual', v_m = v_act,
    'filas', (select jsonb_agg(jsonb_build_object(
                 'tipo', f.tipo,
                 'pagado',    jsonb_build_object('n', f.pag_n, 'total', f.pag_e),
                 'pendiente', jsonb_build_object('n', f.pen_n, 'total', f.pen_e),
                 'fuera',     jsonb_build_object('n', f.fue_n, 'total', f.fue_e),
                 'en_camino', jsonb_build_object('n', f.cam_n, 'total', f.cam_e)) order by f.orden) from f),
    'total', (select jsonb_build_object(
                 'pagado',    jsonb_build_object('n', sum(pag_n), 'total', sum(pag_e)),
                 'pendiente', jsonb_build_object('n', sum(pen_n), 'total', sum(pen_e)),
                 'fuera',     jsonb_build_object('n', sum(fue_n), 'total', sum(fue_e)),
                 'en_camino', jsonb_build_object('n', sum(cam_n), 'total', sum(cam_e)))
                from f where f.tipo <> 'remesa'),
    'importados', jsonb_build_object(
        'n',     (select count(*) from m where m.estado = 'pagado' and m.importado and m.mes_ref = v_m),
        'total', coalesce((select sum(importe) from m where m.estado = 'pagado' and m.importado and m.mes_ref = v_m), 0)),
    'aproximado', coalesce((select sum(importe) from m where m.estado = 'pagado' and not m.importado and m.aproximado and m.mes_ref = v_m), 0),
    'meses', (select jsonb_agg(x.k order by x.k desc) from (
                select distinct to_char(mes_ref, 'YYYY-MM') k from m where mes_ref is not null
                union select to_char(v_act, 'YYYY-MM')) x)
  ) into v_res;
  return v_res;
end;
$function$;
revoke all on function public.dinero_resumen_mes(date) from public, anon;
grant execute on function public.dinero_resumen_mes(date) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- dinero_cuotas · las «cuotas del club» (recurrentes)
--   El Cubo por precio/días (reducido o general según la tarifa vigente) y las
--   cuotas domiciliadas por periodicidad, con su gente.
-- ---------------------------------------------------------------------------
create or replace function public.dinero_cuotas(p_mes date default null)
returns jsonb
language plpgsql stable security definer set search_path to 'public' as $function$
declare
  v_m   date := date_trunc('month', coalesce(p_mes, (now() at time zone 'Europe/Madrid')::date))::date;
  v_res jsonb;
begin
  if not public.dinero_puede_ver() then
    raise exception 'Solo administración, tesorería o contabilidad ven el dinero.' using errcode = '42501';
  end if;

  with m as (select * from public.dinero_movimientos_v2()),
  pag as (select alta_id, count(*) n, sum(importe) e from m
           where origen = 'cubo' and estado = 'pagado' and mes_ref = v_m and alta_id is not null group by alta_id),
  pen as (select alta_id, count(*) n, sum(importe) e from m
           where origen = 'cubo' and estado in ('pendiente','fallido') and alta_id is not null group by alta_id),
  al as (
    select ca.*,
      case when ca.precio_mes = public.cubo_precio(ca.dias, true)  then 'reducido'
           when ca.precio_mes = public.cubo_precio(ca.dias, false) then 'general'
           else 'otro' end as tarifa,
      exists (select 1 from public.cubo_pausas cp
               where cp.alta_id = ca.id and cp.estado = 'aprobada' and cp.mes = v_m) as pausa,
      pag.n as pag_n, pag.e as pag_e, pen.n as pen_n, pen.e as pen_e
    from public.cubo_altas ca
    left join pag on pag.alta_id = ca.id
    left join pen on pen.alta_id = ca.id
    where ca.estado = 'aprobada' and not coalesce(ca.lista_espera, false)
      and coalesce(ca.suscripcion_estado, '') <> 'cancelada'
  ),
  cubo as (
    select al.precio_mes, al.dias, al.tarifa,
      count(*) as gente,
      count(*) filter (where al.suscripcion_estado = 'activa')                                   as activas,
      count(*) filter (where al.suscripcion_estado is null and al.cobro_abierto and al.pago_externo is null) as abiertas,
      count(*) filter (where al.suscripcion_estado = 'impago')                                   as impago,
      count(*) filter (where al.pago_externo is not null)                                        as externo,
      count(*) filter (where al.suscripcion_estado is null and not al.cobro_abierto and al.pago_externo is null) as sin_cobro,
      count(*) filter (where al.pausa)                                                           as en_pausa,
      count(*) filter (where al.pag_n is not null)                                               as pag_n,
      coalesce(sum(al.pag_e), 0)                                                                 as pag_e,
      count(*) filter (where al.pen_n is not null)                                               as pen_n,
      coalesce(sum(al.pen_e), 0)                                                                 as pen_e
    from al group by al.precio_mes, al.dias, al.tarifa
  ),
  ce as (
    select q.*,
      (select count(*) from m where m.origen = 'entreno' and m.estado = 'pagado' and m.mes_ref = v_m and m.atleta_id = q.atleta_id) as pag_n,
      (select coalesce(sum(importe),0) from m where m.origen = 'entreno' and m.estado = 'pagado' and m.mes_ref = v_m and m.atleta_id = q.atleta_id) as pag_e
    from public.cuotas_entreno q
    where q.suscripcion_estado <> 'cancelada'
       or q.ultimo_cobro >= v_m
  )
  select jsonb_build_object(
    'mes', to_char(v_m, 'YYYY-MM'),
    'precios', public.cubo_precios(),
    'cubo', coalesce((select jsonb_agg(to_jsonb(c) order by c.dias desc, c.precio_mes desc) from cubo c), '[]'::jsonb),
    'cubo_sin_alta', (select count(*) from m where origen = 'cubo' and estado = 'pagado' and mes_ref = v_m and alta_id is null),
    'domiciliadas', coalesce((select jsonb_agg(jsonb_build_object(
        'periodicidad', g.periodicidad,
        'n', g.n, 'activa', g.activa, 'en_camino', g.en_camino, 'sin_iban', g.sin_iban,
        'impago', g.impago, 'cancelada', g.cancelada, 'importe_periodo', g.imp,
        'pagado', jsonb_build_object('n', g.pag_n, 'total', g.pag_e),
        'pendiente', jsonb_build_object('n', g.pen_n, 'total', g.pen_e),
        'personas', g.personas) order by g.periodicidad desc)
      from (
        select ce.periodicidad,
          count(*) n,
          count(*) filter (where ce.suscripcion_estado = 'activa')    activa,
          count(*) filter (where ce.suscripcion_estado = 'en_camino') en_camino,
          count(*) filter (where ce.suscripcion_estado = 'pendiente') sin_iban,
          count(*) filter (where ce.suscripcion_estado = 'impago')    impago,
          count(*) filter (where ce.suscripcion_estado = 'cancelada') cancelada,
          round(coalesce(sum(ce.importe_cent) filter (where ce.suscripcion_estado <> 'cancelada'), 0) / 100.0, 2) imp,
          sum(ce.pag_n) pag_n, sum(ce.pag_e) pag_e,
          count(*) filter (where ce.suscripcion_estado in ('pendiente','impago') and ce.cobro_abierto) pen_n,
          round(coalesce(sum(ce.importe_cent) filter (where ce.suscripcion_estado in ('pendiente','impago') and ce.cobro_abierto), 0) / 100.0, 2) pen_e,
          jsonb_agg(jsonb_build_object(
            'id', ce.id, 'persona', trim(coalesce(ce.nombre,'') || ' ' || coalesce(ce.apellidos,'')),
            'concepto', ce.concepto, 'importe', round(ce.importe_cent / 100.0, 2),
            'estado', ce.suscripcion_estado, 'cobro_abierto', ce.cobro_abierto,
            'proximo_cobro', (ce.proximo_cobro at time zone 'Europe/Madrid')::date,
            'ultimo_cobro', (ce.ultimo_cobro at time zone 'Europe/Madrid')::date,
            'fin', ce.fin, 'cancel_programado', ce.cancel_programado)
            order by ce.suscripcion_estado, ce.apellidos) personas
        from ce group by ce.periodicidad
      ) g), '[]'::jsonb)
  ) into v_res;
  return v_res;
end;
$function$;
revoke all on function public.dinero_cuotas(date) from public, anon;
grant execute on function public.dinero_cuotas(date) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- dinero_proximos · lo que se va a cobrar y cuándo
--   · El Cubo: suscripciones activas en su próximo cobro (proximo_cobro de
--     Stripe; si falta, el próximo día 5). Las de un mes en PAUSA aprobada
--     salen marcadas (pausa = true) y NO suman.
--   · Cuotas domiciliadas: activas o en camino, en su proximo_cobro (si no hay
--     fecha todavía, salen sin fecha: no se inventa).
--   · Recibos pendientes con fecha límite de hoy en adelante (la remesa de Isa,
--     marcada como tal).
-- ---------------------------------------------------------------------------
create or replace function public.dinero_proximos()
returns jsonb
language plpgsql stable security definer set search_path to 'public' as $function$
declare
  v_hoy  date := (now() at time zone 'Europe/Madrid')::date;
  v_mes  date := date_trunc('month', (now() at time zone 'Europe/Madrid'))::date;
  v_dia5 date;
  v_res  jsonb;
begin
  if not public.dinero_puede_ver() then
    raise exception 'Solo administración, tesorería o contabilidad ven el dinero.' using errcode = '42501';
  end if;
  v_dia5 := case when extract(day from v_hoy) < 5 then v_mes + 4
                 else (v_mes + interval '1 month')::date + 4 end;

  with cu as (
    select coalesce((ca.proximo_cobro at time zone 'Europe/Madrid')::date, v_dia5) as fecha, ca.*
      from public.cubo_altas ca
     where ca.estado = 'aprobada' and not coalesce(ca.lista_espera, false)
       and ca.suscripcion_estado = 'activa' and ca.pago_externo is null
  ),
  filas as (
    select cu.fecha, 'cubo'::text as tipo, trim(cu.nombre || ' ' || cu.apellidos) as persona,
           'Cuota El Cubo · ' || cu.dias || (case when cu.dias = 1 then ' día' else ' días' end) as concepto,
           cu.precio_mes::numeric as importe,
           exists (select 1 from public.cubo_pausas cp where cp.alta_id = cu.id and cp.estado = 'aprobada'
                    and cp.mes = date_trunc('month', cu.fecha)::date) as pausa,
           case when cu.baja_solicitada is not null then 'Ha pedido la baja' end as detalle,
           'admin/cubo-altas/'::text as enlace
      from cu
    union all
    select (q.proximo_cobro at time zone 'Europe/Madrid')::date, 'cuota',
           trim(coalesce(q.nombre,'') || ' ' || coalesce(q.apellidos,'')),
           q.concepto, round(q.importe_cent / 100.0, 2), false,
           concat_ws(' · ',
             case q.suscripcion_estado when 'en_camino' then 'Primer adeudo en camino' end,
             case when q.proximo_cobro is null then 'Stripe aún no ha dado la fecha' end,
             case when q.cancel_programado then 'Se cancela sola al terminar' end,
             case when q.fin is not null then 'Hasta el ' || to_char(q.fin, 'DD/MM/YYYY') end),
           'admin/cuotas-entreno/'
      from public.cuotas_entreno q
     where q.suscripcion_estado in ('activa','en_camino')
       and (q.fin is null or q.proximo_cobro is null or (q.proximo_cobro at time zone 'Europe/Madrid')::date <= q.fin)
    union all
    select p.fecha_vencimiento,
           case when p.metodo = 'domiciliado' or coalesce(p.notas,'') ilike '%remesa%'
                     or p.concepto ilike '%municipal%' then 'remesa' else 'unico' end,
           coalesce(nullif(trim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')),''), 'Sin persona'),
           p.concepto, p.importe::numeric, false,
           nullif(p.periodo, ''),
           'admin/cobros/'
      from public.pagos p
      left join public.atletas a on a.id = p.atleta_id
     where not p.anulado and p.estado = 'pendiente' and p.fecha_vencimiento >= v_hoy
  )
  select jsonb_build_object(
    'hoy', v_hoy,
    'filas', coalesce((select jsonb_agg(to_jsonb(f) order by f.fecha nulls last, f.tipo, f.persona) from filas f), '[]'::jsonb)
  ) into v_res;
  return v_res;
end;
$function$;
revoke all on function public.dinero_proximos() from public, anon;
grant execute on function public.dinero_proximos() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- dinero_marcar_efectivo · «Marcar pagado (efectivo)» en bloque
--   Solo recibos del libro (pagos) pendientes o impagados, no anulados y que
--   no vengan de Stripe. Pone metodo = 'efectivo' (así SÍ cuenta como «ha
--   entrado», no como importado) y la fecha de pago. El número de recibo lo pone
--   la base (pagos_numera) y, ya emitido, no se deshace: se anula.
--   La remesa de Isa NO se marca aquí (la marca ella en Cobros).
-- ---------------------------------------------------------------------------
create or replace function public.dinero_marcar_efectivo(p_ids uuid[], p_fecha date default null)
returns jsonb
language plpgsql security definer set search_path to 'public' as $function$
declare
  v_fecha date := coalesce(p_fecha, (now() at time zone 'Europe/Madrid')::date);
  v_n     int;
  v_total numeric;
  v_nums  jsonb;
begin
  if not (public.es_admin() or public.puede_girar()) then
    raise exception 'Solo administración, tesorería o contabilidad marcan cobros.' using errcode = '42501';
  end if;
  if p_ids is null or cardinality(p_ids) = 0 then
    return jsonb_build_object('marcados', 0, 'omitidos', 0, 'total', 0, 'recibos', '[]'::jsonb);
  end if;
  if v_fecha > (now() at time zone 'Europe/Madrid')::date then
    raise exception 'La fecha de cobro no puede ser futura.' using errcode = 'P0001';
  end if;

  with u as (
    update public.pagos p
       set estado = 'pagado', metodo = 'efectivo', fecha_pago = v_fecha
     where p.id = any(p_ids)
       and not p.anulado
       and p.estado in ('pendiente','impagado')
       and p.numero_recibo is null
       and coalesce(p.notas,'') not like 'stripe:%'
       and not (p.estado = 'pendiente' and (coalesce(p.metodo,'') = 'domiciliado' or coalesce(p.notas,'') ilike '%remesa%'
                                             or p.concepto ilike '%municipal%'))   -- remesa de Isa
    returning p.id, p.importe, p.numero_recibo
  )
  select count(*), coalesce(sum(importe), 0),
         coalesce(jsonb_agg(jsonb_build_object('id', id, 'numero_recibo', numero_recibo)), '[]'::jsonb)
    into v_n, v_total, v_nums from u;

  return jsonb_build_object('marcados', v_n,
                            'omitidos', cardinality(p_ids) - v_n,
                            'total', v_total,
                            'fecha', v_fecha,
                            'recibos', v_nums);
end;
$function$;
revoke all on function public.dinero_marcar_efectivo(uuid[], date) from public, anon;
grant execute on function public.dinero_marcar_efectivo(uuid[], date) to authenticated, service_role;

commit;
