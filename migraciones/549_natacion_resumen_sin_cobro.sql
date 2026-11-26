-- 549 · Natación: el resumen de los lunes añade «CON PLAZA Y SIN COBRO»
-- ---------------------------------------------------------------------------
-- Andrés (26-nov-2026): Alieksa (alta el 29-oct) e Isaac Esclapes tenían plaza
-- y cuota en la ficha, pero nadie les creó el enlace de pago: «Dar de alta»
-- decía «Cuota apuntada» y parecía hecho. Ahora el alta dice «Falta crear su
-- enlace de pago» con botón, y el lunes avisa de quien siga sin cobro.
-- Solo cuenta a quien tiene cuota en la ficha (> 0 €): los que pagan por otra
-- vía y no la tienen apuntada no salen.
-- ---------------------------------------------------------------------------
begin;

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
  v_dej   jsonb;
  v_sco   jsonb;
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

  -- 546 · HAN DEJADO DE VENIR: plaza activa (alta hace más de 14 días), sin
  -- situación abierta, y en las últimas 3 semanas no ha venido a ninguna de
  -- las clases con lista pasada (al menos 2); o tiene plaza en horarios en los
  -- que nunca se le ha pasado lista (ficha duplicada o plaza olvidada).
  with ins as (
    select i.atleta_id, min(i.acceso_id::text)::uuid acceso_id, min(i.nombre) nombre, min(i.created_at)::date alta,
           string_agg(case f.dia when 1 then 'lun' when 2 then 'mar' when 3 then 'mié' when 4 then 'jue' when 5 then 'vie' when 6 then 'sáb' else '?' end
                      || ' ' || to_char(f.hora, 'HH24:MI'), ', ' order by f.dia, f.hora) horario,
           array_agg(i.franja_id) franjas
      from public.natacion_inscripciones i join public.natacion_franjas f on f.id = i.franja_id
     where i.activa and i.atleta_id is not null
     group by i.atleta_id),
  cla as (
    select s.atleta_id,
           count(*) filter (where l.fecha >= v_hoy - 21 and l.fecha >= s.alta) listas21,
           count(*) filter (where l.fecha >= v_hoy - 21 and l.fecha >= s.alta and not aus.falta) vino21,
           count(*) filter (where l.fecha >= s.alta) listas,
           max(l.fecha) filter (where l.fecha >= s.alta and not aus.falta) ultima
      from ins s
      join public.natacion_lista l on l.franja_id = any(s.franjas)
      cross join lateral (select exists (select 1 from public.natacion_ausencias a where a.acceso_id = s.acceso_id and a.fecha = l.fecha
                                          and (a.franja_id = l.franja_id or a.franja_id is null)) falta) aus
     group by s.atleta_id)
  select coalesce(jsonb_agg(jsonb_build_object(
           'nombre', initcap(s.nombre), 'tel', public._natacion_tel(s.atleta_id), 'horario', s.horario, 'alta', s.alta,
           'ultima', c.ultima, 'listas21', coalesce(c.listas21, 0), 'vino21', coalesce(c.vino21, 0), 'sin_listas', coalesce(c.listas, 0) = 0,
           'cuota', exists (select 1 from public.cuotas_entreno q where q.atleta_id = s.atleta_id and q.origen = 'natacion' and q.suscripcion_estado <> 'cancelada'))
         order by c.ultima nulls first, s.nombre), '[]'::jsonb)
    into v_dej
    from ins s left join cla c on c.atleta_id = s.atleta_id
   where s.alta < v_hoy - 14
     and not exists (select 1 from public.natacion_situaciones st where st.atleta_id = s.atleta_id and st.estado = 'abierta')
     and ((coalesce(c.listas21, 0) >= 2 and coalesce(c.vino21, 0) = 0) or (coalesce(c.listas, 0) = 0 and s.alta < v_hoy - 21));

  -- 549 · CON PLAZA Y SIN COBRO: plaza activa desde hace más de 3 días y ninguna
  -- cuota de natación viva (ni enlace, ni suscripción, ni mes a mes), sin
  -- situación abierta. Pasó con Alieksa e Isaac: el alta apuntaba la cuota en
  -- la ficha pero nadie creó el enlace.
  select coalesce(jsonb_agg(jsonb_build_object(
           'nombre', initcap(btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, ''))), 'tel', public._natacion_tel(a.id),
           'tipo', x.tipo, 'horario', x.horario, 'alta', x.alta, 'cuota_ficha', a.cuota_importe,
           'enlace', 'https://atletismoapolana.com/portal/natacion-cuotas/?crear=' || a.id)
         order by x.alta), '[]'::jsonb)
    into v_sco
    from (select i.atleta_id, min(i.tipo) tipo, min(i.created_at)::date alta,
                 string_agg(case f.dia when 1 then 'lun' when 2 then 'mar' when 3 then 'mié' when 4 then 'jue' when 5 then 'vie' when 6 then 'sáb' else '?' end
                            || ' ' || to_char(f.hora, 'HH24:MI'), ', ' order by f.dia, f.hora) horario
            from public.natacion_inscripciones i join public.natacion_franjas f on f.id = i.franja_id
           where i.activa and i.atleta_id is not null group by i.atleta_id) x
    join public.atletas a on a.id = x.atleta_id
   where x.alta < v_hoy - 3
     and coalesce(a.cuota_importe, 0) > 0
     and not exists (select 1 from public.cuotas_entreno q where q.atleta_id = a.id and q.origen = 'natacion' and q.suscripcion_estado <> 'cancelada')
     and not exists (select 1 from public.natacion_situaciones st where st.atleta_id = a.id and st.estado = 'abierta');

  return jsonb_build_object('hoy', v_hoy, 'nivel_del_mes', v_nivel,
                            'revisar', v_rev, 'impagos', v_imp, 'recibos', v_rec, 'sin_activar', v_sin, 'dejaron', v_dej, 'sin_cobro', v_sco);
end;
$$;
revoke all on function public.natacion_resumen_semanal(date) from public, anon, authenticated;
grant execute on function public.natacion_resumen_semanal(date) to service_role;

commit;
