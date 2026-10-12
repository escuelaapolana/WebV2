-- 305 · Las incorporaciones del día en «compañeros de la sesión»
-- Mario: cuando un nadador ve su sesión, salen sus compañeros (apellidos
-- enmascarados por privacidad). Deben salir TAMBIÉN los que se apuntan ese día
-- por bono/cambio (natacion_reservas), marcados aparte. Antes «compañeros» se
-- armaba solo del cupo fijo (natacion_inscripciones).
--
-- Se añade a las dos funciones que ya dan los compañeros (natacion_mis_plazas
-- para el portal del atleta/familia/calendario; natacion_mi_plaza para el
-- enlace público «mi-plaza» por código) un array `incorporaciones` por franja,
-- con el nombre ENMASCARADO igual que los compañeros (menores) y su fecha.
-- Son reservas de aquí en adelante; el front filtra por la fecha que pinta.
-- Mismo security-definer y mismo acotado por persona: solo las incorporaciones
-- a TUS franjas (o las de tus hijos). No toca tablas ni datos.

-- 1) Portal (atleta / familia / calendario): natacion_mis_plazas con incorporaciones.
create or replace function public.natacion_mis_plazas()
returns jsonb
language sql stable security definer set search_path = 'public' as $$
  with mias as (
    select i.id as ins_id, i.franja_id, i.calle, i.nivel, i.tipo, i.acceso_id,
           coalesce(i.atleta_id, ac.atleta_id) as atleta_id
    from public.natacion_inscripciones i
    left join public.natacion_accesos ac on ac.id = i.acceso_id
    left join public.atletas a on a.id = coalesce(i.atleta_id, ac.atleta_id)
    where i.activa
      and (
        (a.id is not null and (a.perfil_id = public.mi_perfil_id()
                            or a.perfil_padre_id = public.mi_perfil_id()))
        or i.perfil_id = public.mi_perfil_id()
      )
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'franja_id', f.id,
      'dia',       f.dia,
      'hora',      to_char(f.hora, 'HH24:MI'),
      'grupo',     f.grupo,
      'calle',     m.calle,
      'nivel',     m.nivel,
      'tipo',      m.tipo,
      'atleta_id', m.atleta_id,
      'de',        (select btrim(a2.nombre || ' ' || coalesce(a2.apellidos, ''))
                      from public.atletas a2 where a2.id = m.atleta_id),
      -- Compañeros de esa franja, con los apellidos en asteriscos (nombre entero).
      'companeros', coalesce((
        select jsonb_agg(masc order by masc) from (
          select (select string_agg(case when o = 1 or length(w) <= 2 then w else left(w, 3) || '***' end, ' ' order by o)
                  from unnest(regexp_split_to_array(btrim(i2.nombre), '\s+')) with ordinality as u(w, o)) as masc
          from public.natacion_inscripciones i2
          where i2.franja_id = f.id and i2.activa and i2.id <> m.ins_id
            and (m.acceso_id is null or i2.acceso_id is distinct from m.acceso_id)
        ) z), '[]'::jsonb),
      -- Faltas ya avisadas de aquí en adelante (para pintarlas marcadas).
      'ausencias', coalesce((
        select jsonb_agg(a3.fecha order by a3.fecha)
        from public.natacion_ausencias a3
        where a3.acceso_id = m.acceso_id and a3.franja_id = f.id and a3.fecha >= current_date), '[]'::jsonb),
      -- Incorporaciones (bono/cambio) a esa franja, por fecha, nombre enmascarado.
      'incorporaciones', coalesce((
        select jsonb_agg(jsonb_build_object(
            'fecha', r.fecha,
            'nombre', (select string_agg(case when o = 1 or length(w) <= 2 then w else left(w, 3) || '***' end, ' ' order by o)
                       from unnest(regexp_split_to_array(btrim(r.nombre), '\s+')) with ordinality as u(w, o)),
            'calle', r.calle
          ) order by r.fecha)
        from public.natacion_reservas r
        where r.franja_id = f.id and r.estado = 'reservada' and r.fecha >= current_date), '[]'::jsonb)
    ) order by f.dia, f.hora), '[]'::jsonb)
  from mias m
  join public.natacion_franjas f on f.id = m.franja_id;
$$;
revoke all on function public.natacion_mis_plazas() from public, anon;
grant execute on function public.natacion_mis_plazas() to authenticated;

-- 2) Enlace público «mi-plaza» por código: natacion_mi_plaza con incorporaciones.
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
        ), '[]'::jsonb),
        'incorporaciones', coalesce((
          select jsonb_agg(jsonb_build_object(
              'fecha', r.fecha,
              'nombre', (select string_agg(case when o = 1 or length(w) <= 2 then w else left(w, 3) || '***' end, ' ' order by o)
                         from unnest(regexp_split_to_array(btrim(r.nombre), '\s+')) with ordinality as u(w, o)),
              'calle', r.calle
            ) order by r.fecha)
          from public.natacion_reservas r
          where r.franja_id = f.id and r.estado = 'reservada' and r.fecha >= current_date), '[]'::jsonb)
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
revoke all on function public.natacion_mi_plaza(text) from public, anon;
grant execute on function public.natacion_mi_plaza(text) to anon, authenticated;
