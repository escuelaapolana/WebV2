-- 312 · Dinero · UNA fuente para la pantalla admin/dinero/
-- ------------------------------------------------------------------
-- Andrés: «nunca sé dónde están los pagos». El dinero vive en 6 tablas
-- (pagos, cubo_altas, cubo_cobros, cuotas_entreno, altas_socio,
-- pagos_online). Aquí se juntan en UNA lista de movimientos con UN estado
-- claro, y las cifras de arriba salen de esa misma lista (no de cálculos
-- sueltos en el navegador).
--
--   dinero_movimientos()  → una fila por cosa que es dinero (cobrado o por cobrar)
--   dinero_resumen()      → las cifras: te deben · ha entrado este mes ·
--                           en camino (SEPA) · previsto por remesa de Isa ·
--                           pendiente por origen · «ojo»
--
-- ESTADOS (los que ve la pantalla)
--   pagado     el dinero ha entrado (fecha real de cobro en cobrado_en)
--   en_camino  mandato SEPA firmado, el adeudo aún no se ha liquidado
--   pendiente  lo debe y se puede cobrar por la app / Stripe   → «Te deben»
--   fallido    falló o se devolvió el adeudo / impago          → «Te deben» + «Ojo»
--   remesa     recibo domiciliado que pasa Isa por el banco    → informativo
--   devuelto   se cobró y se reembolsó (tienda/bonos)          → solo «Ojo»
--
-- CRITERIOS (para no engañar)
--   · REMESA = recibo pendiente con metodo 'domiciliado', con «remesa» en las notas
--     o de escuela MUNICIPAL (las cobra Isa también). Antes: metodo 'domiciliado' o con «remesa» en las
--     notas (así se importaron los 219 de la escuela: «se confirma con la remesa
--     de Isa»). NO se usa `cuenta`: `cuenta` es a qué banco va el dinero
--     (escuela/club), la llevan TODOS los recibos, y con ella todo saldría remesa.
--   · IMPORTADO = recibo «pagado» SIN forma de cobro (metodo vacío) y que no
--     viene de Stripe. Son registros/importaciones, no cobros vistos por la app:
--     los 173 «Cuota de socio 2026 ya pagada (registro…)» y las 3 altas nº
--     617-619 (fecha 5-oct = día de la importación) y los 19 municipales
--     marcados hoy sin forma de cobro. Salen en el buscador como «Pagado
--     (registro)», pero NO suman en «Ha entrado este mes». En cuanto se les pone
--     la forma de cobro en Cobros, cuentan.
--   · CUBO antes del histórico: si una suscripción activa tiene `ultimo_cobro`
--     y aún no hay su fila de Stripe en `pagos`, se enseña ese último cobro con
--     importe DEDUCIDO (día 5 = cuota del mes; otro día = primer pago). Si no se
--     puede deducir, no se inventa: no sale.
-- ------------------------------------------------------------------
begin;

create or replace function public.dinero_puede_ver()
returns boolean language sql stable security definer set search_path to 'public' as $$
  -- Igual que la RLS de `pagos` (admin + ve_dinero = tesorería o contabilidad).
  -- Junta NO: ve_dinero() no la incluye, y esta vista no debe ver más que la RLS.
  select public.es_admin() or public.ve_dinero();
$$;
revoke all on function public.dinero_puede_ver() from public, anon;
grant execute on function public.dinero_puede_ver() to authenticated, service_role;

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

-- ------------------------------------------------------------------
-- Las cifras de arriba + «pendiente por origen» + «ojo»
-- ------------------------------------------------------------------
create or replace function public.dinero_resumen()
returns jsonb
language plpgsql stable security definer set search_path to 'public' as $function$
declare
  v_hoy   date := (now() at time zone 'Europe/Madrid')::date;
  v_mes   date := date_trunc('month', (now() at time zone 'Europe/Madrid'))::date;
  v_res   jsonb;
begin
  if not public.dinero_puede_ver() then
    raise exception 'Solo administración, tesorería o contabilidad ven el dinero.' using errcode = '42501';
  end if;

  with m as (select * from public.dinero_movimientos()),
  ojo as (
    -- 1 · Intentos de pago con tarjeta atascados o fallidos (30 días) de algo
    --     que sigue sin pagarse. Se agrupan: «4 intentos» y no 4 líneas.
    select 'intento'::text as tipo,
           coalesce(nullif(trim(coalesce(at.nombre,'') || ' ' || coalesce(at.apellidos,'')),''), 'Sin persona') as persona,
           max(po.concepto) as concepto,
           max(po.importe_centimos) / 100.0 as importe,
           count(*)::int as n,
           max(po.creado_en) as fecha,
           count(*) || case when count(*) = 1 then ' intento' else ' intentos' end
             || ' de pago sin terminar (el último, ' || to_char(max(po.creado_en) at time zone 'Europe/Madrid', 'DD/MM HH24:MI') || ')' as texto,
           'admin/pagos-online/'::text as enlace
      from public.pagos_online po
      left join public.pagos pg on pg.id = nullif(po.metadatos ->> 'pago_id','')::uuid
      left join public.atletas at on at.id = coalesce(po.atleta_id, pg.atleta_id)
     where po.tipo = 'recibo'
       and po.estado in ('iniciado','fallido')
       and po.creado_en > now() - interval '30 days'
       and po.creado_en < now() - interval '1 hour'
       and pg.id is not null and pg.estado <> 'pagado' and not pg.anulado
     group by pg.id, at.nombre, at.apellidos
    union all
    -- 2 · Fallidos y devueltos (todo lo que está en estado «fallido»)
    select 'fallido', m.persona, m.concepto, m.importe, 1, m.fecha,
           coalesce(m.detalle, 'Falló el cobro'), m.enlace
      from m where m.estado in ('fallido','devuelto')
    union all
    -- 3 · SEPA «en camino» de más de 10 días: lo normal son ~5 días hábiles;
    --     a partir de 14 conviene mirarlo en Stripe.
    select 'sepa_lento', m.persona, m.concepto, m.importe, 1, m.fecha,
           'Lleva ' || (v_hoy - (m.fecha at time zone 'Europe/Madrid')::date) || ' días en camino: míralo en Stripe',
           m.enlace
      from m where m.estado = 'en_camino' and m.fecha < now() - interval '10 days'
  )
  select jsonb_build_object(
    'hoy', v_hoy,
    'mes', to_char(v_mes, 'YYYY-MM'),
    'te_deben', jsonb_build_object(
        'total', coalesce((select sum(importe) from m where estado in ('pendiente','fallido')), 0),
        'n',     (select count(*) from m where estado in ('pendiente','fallido'))),
    'entrado_mes', jsonb_build_object(
        'total', coalesce((select sum(importe) from m where estado = 'pagado' and not importado and cobrado_en >= v_mes), 0),
        'n',     (select count(*) from m where estado = 'pagado' and not importado and cobrado_en >= v_mes),
        'aproximado', coalesce((select sum(importe) from m where estado = 'pagado' and not importado and aproximado and cobrado_en >= v_mes), 0),
        'por_origen', coalesce((select jsonb_agg(jsonb_build_object('origen', origen, 'total', t, 'n', n) order by t desc)
                                  from (select origen, sum(importe) t, count(*) n from m
                                         where estado = 'pagado' and not importado and cobrado_en >= v_mes
                                         group by origen) x), '[]'::jsonb),
        'importado_total', coalesce((select sum(importe) from m where estado = 'pagado' and importado and cobrado_en >= v_mes), 0),
        'importado_n',     (select count(*) from m where estado = 'pagado' and importado and cobrado_en >= v_mes)),
    'en_camino', jsonb_build_object(
        'total', coalesce((select sum(importe) from m where estado = 'en_camino'), 0),
        'n',     (select count(*) from m where estado = 'en_camino')),
    'remesa', jsonb_build_object(
        'total', coalesce((select sum(importe) from m where estado = 'remesa'), 0),
        'n',     (select count(*) from m where estado = 'remesa')),
    'por_origen', coalesce((select jsonb_agg(jsonb_build_object('origen', origen, 'enlace', enlace, 'total', t, 'n', n) order by t desc)
                              from (select origen, min(enlace) enlace, sum(importe) t, count(*) n from m
                                     where estado in ('pendiente','fallido')
                                     group by origen) x), '[]'::jsonb),
    'ojo', coalesce((select jsonb_agg(to_jsonb(o) order by o.fecha desc) from ojo o), '[]'::jsonb)
  ) into v_res;

  return v_res;
end;
$function$;
revoke all on function public.dinero_resumen() from public, anon;
grant execute on function public.dinero_resumen() to authenticated, service_role;

commit;
