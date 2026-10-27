-- 451 · Natación · competiciones: la RESPUESTA de la familia (no un sí/no de autorización)
-- ---------------------------------------------------------------------------
-- En la hoja de Paloma, «Autorización padres» es la respuesta de la familia con
-- su nota: «OK / coche Lorena», «No pueden ese día», «No quiere la niña»… Se
-- cambia autorizado (sí/no) por respuesta: pendiente | si (va) | no (no va), y la
-- nota guarda el resto. (Tabla vacía: aún no hay datos.)
-- ---------------------------------------------------------------------------
begin;
alter table public.natacion_comp_convocados add column if not exists respuesta text not null default 'pendiente';
alter table public.natacion_comp_convocados drop constraint if exists natacion_comp_convocados_respuesta_chk;
alter table public.natacion_comp_convocados add constraint natacion_comp_convocados_respuesta_chk check (respuesta in ('pendiente','si','no'));

create or replace function public.natacion_comp_listar()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select jsonb_build_object(
    'categorias', coalesce((select jsonb_agg(jsonb_build_object('clave', c.clave, 'nombre', c.nombre, 'desde', c.desde_anio, 'hasta', c.hasta_anio,
        'ninos', (select count(*) from public.atletas a where a.id in (select public._natacion_comp_ninos())
                    and extract(year from a.fecha_nacimiento) between c.desde_anio and c.hasta_anio)) order by c.orden)
      from public.natacion_comp_categorias c where c.temporada = '2026/27'), '[]'),
    'jornadas', coalesce((select jsonb_agg(jsonb_build_object('id', j.id, 'fecha', j.fecha, 'hora', j.hora, 'lugar', j.lugar, 'nombre', j.nombre,
        'categorias', j.categorias, 'convoca', j.convoca,
        'convocados', (select count(*) from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado),
        'van', (select count(*) from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado and x.respuesta = 'si'),
        'sin_respuesta', (select count(*) from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado and x.respuesta = 'pendiente'),
        'de_baja', (select count(*) from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado
                      and x.atleta_id not in (select public._natacion_comp_ninos())),
        'sin_datos', (select count(*) from public.natacion_comp_convocados x 
                      where x.jornada_id = j.id and x.convocado and cardinality(public._natacion_comp_falta(x.atleta_id)) > 0))
      order by j.fecha, j.hora nulls first, j.lugar)
      from public.natacion_comp_jornadas j where j.temporada = '2026/27'), '[]')
  ) into v;
  return v;
end $$;

create or replace function public.natacion_comp_jornada(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare j public.natacion_comp_jornadas; v jsonb;
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into j from public.natacion_comp_jornadas where id = p_id;
  if not found then raise exception 'Esa jornada ya no existe.' using errcode = 'P0001'; end if;
  with cats as (select * from public.natacion_comp_categorias c where c.temporada = j.temporada and c.clave = any(j.categorias)),
  ninos as (
    select a.*, true as activo from public.atletas a
     where a.id in (select public._natacion_comp_ninos())
       and exists (select 1 from cats c where extract(year from a.fecha_nacimiento) between c.desde_anio and c.hasta_anio)
    union
    select a.*, false from public.atletas a
     where a.id in (select x.atleta_id from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado)
       and a.id not in (select public._natacion_comp_ninos())
  )
  select jsonb_build_object(
    'jornada', to_jsonb(j),
    'categorias', (select jsonb_agg(jsonb_build_object('clave', c.clave, 'nombre', c.nombre, 'desde', c.desde_anio, 'hasta', c.hasta_anio) order by c.orden) from cats c),
    'ninos', coalesce(jsonb_agg(jsonb_build_object(
        'id', n.id, 'nombre', btrim(coalesce(n.nombre,'') || ' ' || coalesce(n.apellidos,'')), 'anio', extract(year from n.fecha_nacimiento)::int,
        'sexo', n.sexo, 'activo', n.activo, 'baja_en', n.fecha_baja,
        'nivel', (select string_agg(distinct i.nivel, ', ') from public.natacion_inscripciones i where i.atleta_id = n.id and i.activa),
        'falta', to_jsonb(public._natacion_comp_falta(n.id)),
        'licencia', coalesce((select l.tramitada from public.natacion_licencias l where l.atleta_id = n.id and l.temporada = j.temporada), false),
        'convocado', coalesce(x.convocado, false), 'pruebas', x.pruebas, 'respuesta', coalesce(x.respuesta, 'pendiente'), 'nota', x.nota)
      order by n.nombre, n.apellidos), '[]')
  ) into v
  from ninos n
  left join public.natacion_comp_convocados x on x.jornada_id = j.id and x.atleta_id = n.id;
  return v;
end $$;

create or replace function public.natacion_comp_marcar(p_jornada uuid, p_atleta uuid, p_datos jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare r public.natacion_comp_convocados;
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if p_datos ? 'respuesta' and coalesce(p_datos->>'respuesta','') not in ('pendiente','si','no') then
    raise exception 'Respuesta: pendiente, si o no.' using errcode = 'P0001'; end if;
  insert into public.natacion_comp_convocados (jornada_id, atleta_id, convocado, pruebas, respuesta, nota, updated_por)
  values (p_jornada, p_atleta, coalesce((p_datos->>'convocado')::boolean, true), nullif(btrim(p_datos->>'pruebas'),''),
          coalesce(p_datos->>'respuesta', 'pendiente'), nullif(btrim(p_datos->>'nota'),''), public.mi_perfil_id())
  on conflict (jornada_id, atleta_id) do update set
    convocado  = case when p_datos ? 'convocado'  then (p_datos->>'convocado')::boolean else natacion_comp_convocados.convocado end,
    pruebas    = case when p_datos ? 'pruebas'    then nullif(btrim(p_datos->>'pruebas'),'') else natacion_comp_convocados.pruebas end,
    respuesta  = case when p_datos ? 'respuesta'  then p_datos->>'respuesta' else natacion_comp_convocados.respuesta end,
    nota       = case when p_datos ? 'nota'       then nullif(btrim(p_datos->>'nota'),'') else natacion_comp_convocados.nota end,
    updated_por = public.mi_perfil_id(), updated_at = now()
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.natacion_comp_excel(p_jornada uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('nombre', a.nombre, 'apellidos', a.apellidos, 'sexo', a.sexo, 'fecha_nacimiento', a.fecha_nacimiento,
      'dni', a.dni, 'sip', fl.sip, 'foto_carnet', fl.foto_carnet, 'nombre_tutor', a.nombre_tutor, 'dni_tutor', fl.dni_tutor,
      'telefono_tutor', a.telefono_tutor, 'email_tutor', a.email_tutor, 'direccion', a.direccion,
      'pruebas', x.pruebas, 'respuesta', x.respuesta, 'nota', x.nota, 'licencia', coalesce(l.tramitada, false)) order by a.apellidos, a.nombre)
    from public.natacion_comp_convocados x join public.atletas a on a.id = x.atleta_id
    left join public.natacion_licencias l on l.atleta_id = a.id and l.temporada = '2026/27'
    left join public.natacion_ficha_licencia fl on fl.atleta_id = a.id
    where x.jornada_id = p_jornada and x.convocado), '[]');
end $$;

alter table public.natacion_comp_convocados drop column if exists autorizado;
commit;
