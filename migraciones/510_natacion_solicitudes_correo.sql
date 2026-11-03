-- ============================================================
-- 510 · Natación · Solicitudes: el correo trae la agenda de pruebas y los mensajes
-- ------------------------------------------------------------
-- 3-nov-2026. Los mensajes a las familias se mandan desde OTRO WhatsApp (no el
-- del móvil de Andrés), así que el correo de la mañana tiene que traerlo todo:
--   · quién viene a probar y qué día (para avisar a los monitores),
--   · y el mensaje para cada familia, ya escrito, para copiarlo.
--
-- 1. natacion_solicitudes_revisar: «vino» y «faltó» solo cuentan las listas desde
--    el DÍA DE LA PRUEBA. Antes contaba cualquier lista pasada después del alta: a
--    Elvira (prueba el miércoles 4) la marcó «faltó el lunes 2» porque el lunes
--    también es su día y aún no sabía nada. (Y si el monitor hubiera dado a todos
--    por presentes, la habría pasado a «vino».)
-- 2. natacion_solicitudes_correo(p_todo): lo que necesita el correo, en una sola
--    llamada (solo service_role):
--      · avisos: lo que Andrés aún no sabe (como natacion_solicitudes_avisos, más
--        «falto»: faltó a su clase de prueba) con los datos para escribir el
--        mensaje (tutor, socio, días, franjas con su monitor…). p_todo = true:
--        todo lo pendiente aunque ya se avisara (para el correo de muestra);
--      · agenda: quién viene a probar de hoy en adelante, con día, hora, calle y
--        monitor;
--      · tarifas: las cuotas de escuela y máster (para el mensaje de «¿se queda?»).
-- ============================================================

create or replace function public.natacion_solicitudes_revisar()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  s       record;
  v_vino  date;
  v_falto date;
  v_desde date;
  n_vino  int := 0;
  n_alta  int := 0;
  n_fuera int := 0;
begin
  for s in select * from public.natacion_solicitudes
            where estado in ('prueba', 'probo', 'formaliza') and acceso_id is not null loop
    -- ya tiene cuota de natación hecha después del alta → alta (fin del circuito)
    if s.atleta_id is not null and exists (
         select 1 from public.cuotas_entreno c
          where c.atleta_id = s.atleta_id and c.origen = 'natacion'
            and c.created_at >= coalesce(s.alta_en, s.creado_en)) then
      update public.natacion_solicitudes set estado = 'alta', avisado = 'alta', actualizado_en = now() where id = s.id;
      n_alta := n_alta + 1; continue;
    end if;
    -- ya no está en ninguna franja (lo quitaron a mano) → no sigue
    if not exists (select 1 from public.natacion_inscripciones i where i.acceso_id = s.acceso_id and i.activa) then
      update public.natacion_solicitudes
         set estado = 'no_sigue', motivo = 'Ya no está en ninguna franja.', avisado = 'no_sigue', actualizado_en = now()
       where id = s.id;
      n_fuera := n_fuera + 1; continue;
    end if;
    if s.estado <> 'prueba' then continue; end if;
    -- solo cuentan las clases desde el día de la prueba (no las de antes de avisarle)
    v_desde := coalesce(s.fecha_prueba, (coalesce(s.alta_en, s.creado_en) at time zone 'Europe/Madrid')::date);
    -- vino: lista de su franja pasada DESPUÉS del alta, desde el día de la prueba y sin falta suya
    select min(l.fecha) into v_vino
      from public.natacion_lista l
     where l.franja_id in (select i.franja_id from public.natacion_inscripciones i where i.acceso_id = s.acceso_id and i.activa)
       and l.pasada_en > coalesce(s.alta_en, s.creado_en)
       and l.fecha >= v_desde
       and not exists (select 1 from public.natacion_ausencias a
                        where a.acceso_id = s.acceso_id and a.franja_id = l.franja_id and a.fecha = l.fecha);
    if v_vino is not null then
      update public.natacion_solicitudes set estado = 'probo', vino_el = v_vino, actualizado_en = now() where id = s.id;
      n_vino := n_vino + 1;
    else
      select max(a.fecha) into v_falto
        from public.natacion_ausencias a
        join public.natacion_lista l on l.franja_id = a.franja_id and l.fecha = a.fecha
       where a.acceso_id = s.acceso_id and l.pasada_en > coalesce(s.alta_en, s.creado_en)
         and a.fecha >= v_desde;
      if v_falto is distinct from s.falto_el then
        update public.natacion_solicitudes set falto_el = v_falto, actualizado_en = now() where id = s.id;
      end if;
    end if;
  end loop;
  return jsonb_build_object('vinieron', n_vino, 'con_cuota', n_alta, 'fuera', n_fuera);
end $function$;


create or replace function public.natacion_solicitudes_correo(p_todo boolean default false)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  with hoy as (select (now() at time zone 'Europe/Madrid')::date as d),
  fr as (   -- franjas con su monitor
    select f.id, f.dia, to_char(f.hora, 'HH24:MI') as hora, f.monitores from public.natacion_franjas f
  ),
  x as (
    select s.*,
           case when s.estado = 'prueba' and s.falto_el is not null then 'falto'
                when s.estado in ('revisar', 'prueba', 'probo') then s.estado
                when s.estado = 'espera' and s.espera_hasta <= (select d from hoy) then 'plazo' end as k
      from public.natacion_solicitudes s
  ),
  av as (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', x.id, 'que', x.k, 'origen', x.origen,
             'nombre', btrim(x.nombre || ' ' || coalesce(x.apellidos, '')),
             'nombre_pila', x.nombre, 'tutor', x.tutor, 'socio', x.socio, 'nivel', x.nivel,
             'nacimiento', x.fecha_nac, 'pide', x.pide, 'motivo', x.motivo, 'observaciones', x.observaciones,
             'fecha_prueba', x.fecha_prueba, 'vino_el', x.vino_el, 'falto_el', x.falto_el, 'espera_hasta', x.espera_hasta,
             'dias', (select count(*) from public.natacion_inscripciones i where i.acceso_id = x.acceso_id and i.activa),
             'franjas', (select string_agg((array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'])[fr.dia]
                                           || ' ' || fr.hora, ', ' order by fr.dia, fr.hora)
                           from unnest(x.franjas) u join fr on fr.id = u),
             'franjas_det', (select coalesce(jsonb_agg(jsonb_build_object('dia', fr.dia, 'hora', fr.hora, 'monitores', fr.monitores)
                                                       order by fr.dia, fr.hora), '[]'::jsonb)
                               from unnest(case when coalesce(array_length(x.franjas, 1), 0) > 0 then x.franjas else x.franjas_pedidas end) u
                               join fr on fr.id = u))
             order by x.k, x.creado_en), '[]'::jsonb) as j
      from x
     where x.k is not null and (p_todo or x.k is distinct from x.avisado)
  ),
  ag as (   -- quién viene a probar, de hoy en adelante (la franja del día de la prueba)
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', s.id, 'origen', s.origen, 'nombre', btrim(s.nombre || ' ' || coalesce(s.apellidos, '')),
             'nacimiento', s.fecha_nac, 'nivel', s.nivel, 'observaciones', s.observaciones,
             'fecha', s.fecha_prueba, 'dia', p.dia, 'hora', p.hora, 'monitores', p.monitores, 'calle', p.calle)
             order by s.fecha_prueba, p.hora, s.nombre), '[]'::jsonb) as j
      from public.natacion_solicitudes s
      left join lateral (
        select fr.dia, fr.hora, fr.monitores,
               (select i.calle from public.natacion_inscripciones i
                 where i.acceso_id = s.acceso_id and i.franja_id = fr.id and i.activa limit 1) as calle
          from unnest(s.franjas) u join fr on fr.id = u
         order by (fr.dia = extract(isodow from s.fecha_prueba)::int) desc, fr.dia, fr.hora
         limit 1) p on true
     where s.estado = 'prueba' and s.fecha_prueba >= (select d from hoy)
  ),
  ta as (   -- cuotas por nº de días (las mismas que natacion_alta_cuota)
    select jsonb_object_agg(t.tipo, t.j) as j
      from (
        select tipo, coalesce(jsonb_agg(jsonb_build_object('dias', x.n, 'socio', x.importe_socio, 'no_socio', x.importe_no_socio)
                                        order by x.n), '[]'::jsonb) as j
          from (values ('Escuela', 'escuela-natacion'), ('Máster', 'natacion')) v(tipo, seccion)
          left join lateral (
            select distinct on (substring(t.dias from '^\s*(\d+)')::int)
                   substring(t.dias from '^\s*(\d+)')::int as n, t.importe_socio, t.importe_no_socio
              from public.tarifas t
             where t.activo and t.seccion = v.seccion
               and t.vigente_desde <= (select d from hoy)
               and (t.vigente_hasta is null or t.vigente_hasta >= (select d from hoy))
               and substring(t.dias from '^\s*(\d+)') is not null
             order by substring(t.dias from '^\s*(\d+)')::int, t.vigente_desde desc, t.orden) x on true
         where x.n is not null
         group by tipo) t
  )
  select jsonb_build_object('avisos', (select j from av), 'agenda', (select j from ag),
                            'tarifas', coalesce((select j from ta), '{}'::jsonb));
$function$;

revoke all on function public.natacion_solicitudes_correo(boolean) from public, anon, authenticated;
grant execute on function public.natacion_solicitudes_correo(boolean) to service_role;

-- recalcula «faltó» con la regla nueva (a Elvira le quita el «faltó el 2-nov»)
select public.natacion_solicitudes_revisar();
