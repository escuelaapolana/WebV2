-- 544 · Natación: RESUMEN de los lunes (Mario y Adriana) y aviso previo al día 21 (Andrés)
-- ---------------------------------------------------------------------------
-- Andrés (26-nov-2026): «correo semanal a mario.apolana@ y garsaladri@» con lo
-- que hay que revisar, y «avisar antes de cada día 21 para ver si el aviso está
-- bien». Lo manda natacion-cobro-aviso:
--   · { semanal: true }  (cron lunes 9:00)  → resumen con natacion_resumen_semanal()
--   · { pre21: true }    (cron día 19 9:00) → a Andrés: a quién le saldrá el
--     correo del 21 y con qué importe, más un ejemplo de cada correo.
-- natacion_resumen_semanal() reúne, con el teléfono y el enlace de cada uno:
--   · revisar: situaciones abiertas con revisión esta semana (o pasada) y bajas
--     médicas de más de 2 meses;
--   · impagos: cobros rechazados en Stripe;
--   · recibos: recibos «mes a mes» / transferencia vencidos sin pagar
--     (nivel de mensaje 1-2-3 según el criterio: día 8 / 15 / 25, o 2+ meses = 3);
--   · sin_activar: enlaces sin activar de nadadores con plaza (más de 3 días).
-- ---------------------------------------------------------------------------
begin;

-- Teléfono de contacto de un nadador: Escuela → el del tutor primero.
create or replace function public._natacion_tel(p_atleta uuid)
returns text
language sql stable security definer
set search_path to 'public'
as $$
  select case when i.tipo = 'Escuela' then coalesce(nullif(btrim(a.telefono_tutor), ''), nullif(btrim(a.telefono), ''))
              else coalesce(nullif(btrim(a.telefono), ''), nullif(btrim(a.telefono_tutor), '')) end
    from public.atletas a
    left join lateral (select x.tipo from public.natacion_inscripciones x where x.atleta_id = a.id order by x.activa desc limit 1) i on true
   where a.id = p_atleta;
$$;
revoke all on function public._natacion_tel(uuid) from public, anon, authenticated;
grant execute on function public._natacion_tel(uuid) to service_role;

create or replace function public.natacion_resumen_semanal(p_hoy date default null)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
declare
  v_hoy   date := coalesce(p_hoy, (now() at time zone 'Europe/Madrid')::date);
  v_dia   int  := extract(day from coalesce(p_hoy, (now() at time zone 'Europe/Madrid')::date))::int;
  v_nivel int;
  v_rev   jsonb;
  v_imp   jsonb;
  v_rec   jsonb;
  v_sin   jsonb;
begin
  v_nivel := case when v_dia >= 25 then 3 when v_dia >= 15 then 2 else 1 end;

  select coalesce(jsonb_agg(jsonb_build_object(
           'nombre', initcap(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')), 'tipo', s.tipo, 'motivo', s.motivo,
           'revisar_el', s.revisar_el, 'desde', s.desde, 'sin_cobro', s.sin_cobro, 'cobro_hasta', s.cobro_hasta,
           'guarda_plaza', s.guarda_plaza, 'mas_de_2_meses', (s.tipo = 'baja_medica' and s.desde < v_hoy - 60))
         order by s.revisar_el nulls last), '[]'::jsonb)
    into v_rev
    from public.natacion_situaciones s join public.atletas a on a.id = s.atleta_id
   where s.estado = 'abierta'
     and ((s.revisar_el is not null and s.revisar_el <= v_hoy + 6) or (s.tipo = 'baja_medica' and s.desde < v_hoy - 60));

  select coalesce(jsonb_agg(jsonb_build_object(
           'nombre', initcap(coalesce(q.nombre, '') || ' ' || coalesce(q.apellidos, '')), 'tel', t.tel, 'email', q.email,
           'importe', round(q.importe_cent / 100.0, 2), 'periodicidad', q.periodicidad, 'desde', (q.impago_avisado_en at time zone 'Europe/Madrid')::date,
           'enlace', 'https://atletismoapolana.com/entreno/cuota/?t=' || q.token || case when q.periodicidad = 'mensual' then '&m=1' else '' end,
           'nivel', v_nivel) order by q.nombre), '[]'::jsonb)
    into v_imp
    from public.cuotas_entreno q left join lateral (select public._natacion_tel(q.atleta_id) tel) t on true
   where q.origen = 'natacion' and q.suscripcion_estado = 'impago';

  select coalesce(jsonb_agg(r order by r->>'nombre'), '[]'::jsonb) into v_rec
    from (
      select jsonb_build_object(
               'nombre', initcap(coalesce(q.nombre, '') || ' ' || coalesce(q.apellidos, '')), 'tel', max(t.tel), 'email', q.email,
               'transferencia', q.transferencia, 'n', count(*), 'total', sum(p.importe),
               'meses', string_agg(p.periodo, ',' order by p.periodo),
               'enlace', 'https://atletismoapolana.com/pagar/?t=' || (array_agg(p.token_pago order by p.periodo))[1],
               'vence', min(p.fecha_vencimiento),
               'nivel', case when count(*) >= 2 then 3 else v_nivel end) r
        from public.pagos p
        join public.cuotas_entreno q on q.id = p.cuota_entreno_id and q.origen = 'natacion'
        left join lateral (select public._natacion_tel(q.atleta_id) tel) t on true
       where not p.anulado and p.estado in ('pendiente', 'impagado') and p.fecha_vencimiento < v_hoy
         and q.suscripcion_estado <> 'cancelada'
       group by q.id, q.nombre, q.apellidos, q.email, q.transferencia
    ) x;

  select coalesce(jsonb_agg(jsonb_build_object(
           'nombre', initcap(coalesce(q.nombre, '') || ' ' || coalesce(q.apellidos, '')), 'tel', t.tel, 'email', q.email,
           'importe', round(q.importe_cent / 100.0, 2), 'periodicidad', q.periodicidad, 'creado', (q.created_at at time zone 'Europe/Madrid')::date,
           'enlace', 'https://atletismoapolana.com/entreno/cuota/?t=' || q.token || case when q.periodicidad = 'mensual' then '&m=1' else '' end)
         order by q.created_at), '[]'::jsonb)
    into v_sin
    from public.cuotas_entreno q left join lateral (select public._natacion_tel(q.atleta_id) tel) t on true
   where q.origen = 'natacion' and q.suscripcion_estado = 'pendiente' and q.stripe_subscription_id is null
     and coalesce(q.metodo, '') <> 'mes_a_mes' and coalesce(q.cobro_abierto, true) and q.token is not null
     and q.created_at < now() - interval '3 days'
     and exists (select 1 from public.natacion_inscripciones i where i.activa and i.atleta_id = q.atleta_id)
     and not exists (select 1 from public.natacion_situaciones s where s.estado = 'abierta' and s.sin_cobro and s.cuota_id = q.id);

  return jsonb_build_object('hoy', v_hoy, 'nivel_del_mes', v_nivel,
                            'revisar', v_rev, 'impagos', v_imp, 'recibos', v_rec, 'sin_activar', v_sin);
end;
$$;
revoke all on function public.natacion_resumen_semanal(date) from public, anon, authenticated;
grant execute on function public.natacion_resumen_semanal(date) to service_role;

commit;

-- Tareas programadas (como las demás: a las 7 y 8 UTC, y cron_llamar_edge solo actúa a las 9 de Madrid).
select cron.unschedule(jobid) from cron.job where jobname in ('apolana-natacion-resumen-lunes', 'apolana-natacion-pre21');
select cron.schedule('apolana-natacion-resumen-lunes', '0 7,8 * * 1',
  $$select public.cron_llamar_edge('natacion-cobro-aviso', '{"semanal": true}'::jsonb, 9)$$);
select cron.schedule('apolana-natacion-pre21', '0 7,8 19 * *',
  $$select public.cron_llamar_edge('natacion-cobro-aviso', '{"pre21": true}'::jsonb, 9)$$);
