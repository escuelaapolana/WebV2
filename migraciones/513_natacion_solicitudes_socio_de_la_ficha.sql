-- ============================================================
-- 513 · Natación · Solicitudes: «socio» sale también de la ficha
-- ------------------------------------------------------------
-- 4-nov-2026. El formulario Máster no pregunta si eres socio, así que la
-- solicitud se queda con socio = null y el mensaje de «¿se queda?» ponía los dos
-- precios («45 € … si eres socio del club (si no, 60 € …)») aunque la ficha ya
-- diga que lo es (caso de Elvira, socia nº 573). Ahora, si la ficha del nadador
-- dice socio (tipo_membresia 'socio' o con nº de socio, la misma regla que
-- natacion_alta_cuota y Cuotas y cobros), vale como socio. Si la ficha no lo dice,
-- se queda lo que pusiera el formulario (una ficha recién creada no es prueba de
-- «no socio»). No se guarda nada en la solicitud: se mira cada vez.
--
-- 1. _nat_ficha_socio(atleta): true si la ficha dice socio.
-- 2. natacion_solicitudes_socios(): para la pantalla de Solicitudes (quien gestiona
--    natación no lee la tabla atletas): los atleta_id de solicitudes cuya ficha
--    dice socio.
-- 3. natacion_solicitudes_correo: igual que en la 510, con el socio de la ficha
--    (así el correo de la mañana lo coge sin redesplegar la Edge).
-- ============================================================

create or replace function public._nat_ficha_socio(p_atleta uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select coalesce((select a.tipo_membresia = 'socio' or a.numero_socio is not null
                     from public.atletas a where a.id = p_atleta), false);
$function$;

revoke all on function public._nat_ficha_socio(uuid) from public, anon, authenticated;
grant execute on function public._nat_ficha_socio(uuid) to service_role;

create or replace function public.natacion_solicitudes_socios()
 returns setof uuid
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select distinct s.atleta_id
    from public.natacion_solicitudes s
    join public.atletas a on a.id = s.atleta_id
   where (select public.soy_gestor_natacion())
     and (a.tipo_membresia = 'socio' or a.numero_socio is not null);
$function$;

revoke all on function public.natacion_solicitudes_socios() from public, anon;
grant execute on function public.natacion_solicitudes_socios() to authenticated, service_role;

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
             'nombre_pila', x.nombre, 'tutor', x.tutor, 'socio', case when public._nat_ficha_socio(x.atleta_id) then true else x.socio end, 'nivel', x.nivel,
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
