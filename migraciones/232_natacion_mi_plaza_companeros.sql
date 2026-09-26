-- 232 · La familia, en su enlace de "mi plaza", puede ver los COMPAÑEROS de la
-- franja de su hijo/a, pero con los APELLIDOS ENMASCARADOS (nombre de pila +
-- 3 letras + ***), p.ej. "Andrés Cla*** Gime***". Así ve quién está en su grupo
-- sin exponer los datos completos de otros menores.

create or replace function public.natacion_mi_plaza(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_acc public.natacion_accesos; v jsonb;
begin
  select * into v_acc from public.natacion_accesos where codigo = p_codigo and activo;
  if not found then return null; end if;
  select jsonb_build_object(
    'nombre', v_acc.nombre,
    'franjas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'franja_id', f.id, 'dia', f.dia, 'hora', to_char(f.hora,'HH24:MI'),
        'grupo', f.grupo, 'calle', i.calle, 'nivel', i.nivel,
        'companeros', coalesce((
          select jsonb_agg(masc order by masc)
          from (
            select (
              select string_agg(case when o = 1 or length(w) <= 2 then w else left(w, 3) || '***' end, ' ' order by o)
              from unnest(regexp_split_to_array(btrim(i2.nombre), '\s+')) with ordinality as u(w, o)
            ) as masc
            from public.natacion_inscripciones i2
            where i2.franja_id = f.id and i2.activa
              and i2.acceso_id is distinct from v_acc.id
          ) z
        ), '[]'::jsonb)
      ) order by f.dia, f.hora)
      from public.natacion_inscripciones i
      join public.natacion_franjas f on f.id = i.franja_id
      where i.acceso_id = v_acc.id and i.activa), '[]'::jsonb),
    'ausencias', coalesce((
      select jsonb_agg(jsonb_build_object('franja_id', a.franja_id, 'fecha', a.fecha) order by a.fecha)
      from public.natacion_ausencias a
      where a.acceso_id = v_acc.id and a.fecha >= current_date), '[]'::jsonb)
  ) into v;
  return v;
end $$;
