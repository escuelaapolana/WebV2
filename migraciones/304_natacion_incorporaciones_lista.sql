-- 304 · Incorporaciones del día en «pasar lista» + vacantes para monitores
-- Mario (natación): en pasar lista (y en los recuentos) deben salir también los
-- que se apuntaron ESE día por bono/cambio de horario, que viven en
-- natacion_reservas. Dos cosas que resuelve esta migración:
--  1) natacion_reservas solo la lee un GESTOR (RLS de 247); los MONITORES que
--     pasan lista no la ven. Se expone por un RPC SECURITY DEFINER con el mismo
--     permiso que pasar lista (admin / responsable de natación o escuela-natación).
--  2) natacion_huecos (244) solo lo veían admin/staff/responsable('natacion');
--     se amplía a responsable('escuela-natacion') porque pasar lista sirve a los
--     dos mundos. Misma fórmula, solo cambia el guard.
-- No toca tablas ni datos; solo funciones. Re-aplicable con psql.

-- Reservas (incorporaciones por bono/cambio) de un día, por franja, para quien
-- pasa lista (incluye monitores, que por RLS no pueden leer la tabla directa).
create or replace function public.natacion_reservas_dia(p_fecha date)
returns table(id uuid, franja_id uuid, acceso_id uuid, nombre text, calle text)
language sql stable security definer set search_path = public as $$
  select r.id, r.franja_id, r.acceso_id, r.nombre, r.calle
  from public.natacion_reservas r
  join public.natacion_franjas f on f.id = r.franja_id
  where r.fecha = p_fecha and r.estado = 'reservada'
    and coalesce(f.activa, true)
    and (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
  order by r.calle, r.nombre;
$$;

grant execute on function public.natacion_reservas_dia(date) to authenticated, service_role;

-- natacion_huecos: misma fórmula que 244, ampliando el guard a escuela-natación.
create or replace function public.natacion_huecos(p_fecha date)
returns table(franja_id uuid, dia smallint, hora time, grupo text, cupo int, fijos int, bajas int, reservas int, huecos int)
language sql stable security definer set search_path = public as $$
  select f.id, f.dia, f.hora, f.grupo,
    coalesce(nullif((select sum((v)::int) from jsonb_each_text(f.cupos) e(k,v)),0), coalesce(f.calles,3)*8) as cupo,
    (select count(*) from natacion_inscripciones i where i.franja_id=f.id and i.activa)::int as fijos,
    (select count(*) from natacion_ausencias a where a.franja_id=f.id and a.fecha=p_fecha)::int as bajas,
    (select count(*) from natacion_reservas r where r.franja_id=f.id and r.fecha=p_fecha and r.estado='reservada')::int as reservas,
    (coalesce(nullif((select sum((v)::int) from jsonb_each_text(f.cupos) e(k,v)),0), coalesce(f.calles,3)*8)
      - ((select count(*) from natacion_inscripciones i where i.franja_id=f.id and i.activa)
         - (select count(*) from natacion_ausencias a where a.franja_id=f.id and a.fecha=p_fecha))
      - (select count(*) from natacion_reservas r where r.franja_id=f.id and r.fecha=p_fecha and r.estado='reservada'))::int as huecos
  from natacion_franjas f
  where (public.es_admin() or public.es_staff() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
    and coalesce(f.activa,true) and f.dia = extract(isodow from p_fecha)::smallint
  order by f.hora;
$$;

grant execute on function public.natacion_huecos(date) to authenticated, service_role;
