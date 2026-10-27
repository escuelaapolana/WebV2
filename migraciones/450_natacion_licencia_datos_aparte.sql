-- 450 · Natación · competiciones: los datos sensibles de licencia, en TABLA APARTE
-- ---------------------------------------------------------------------------
-- En la 449 se pusieron sip, foto_carnet y dni_tutor como columnas de atletas,
-- pero atletas tiene permiso de SELECT/UPDATE a nivel de TABLA para
-- authenticated (lo filtra la RLS por filas), así que el «revoke» por columna no
-- servía: se habrían podido leer con el mismo alcance que el resto de la ficha.
-- Se quitan (estaban vacías) y van a natacion_ficha_licencia, sin ningún permiso
-- directo: solo se leen y escriben desde natacion_comp_* (que comprueban quién).
-- ---------------------------------------------------------------------------
begin;

alter table public.atletas drop column if exists sip;
alter table public.atletas drop column if exists foto_carnet;
alter table public.atletas drop column if exists dni_tutor;

create table if not exists public.natacion_ficha_licencia (
  atleta_id   uuid primary key references public.atletas(id) on delete cascade,
  sip         text,
  foto_carnet text,
  dni_tutor   text,
  updated_por uuid references public.perfiles(id) on delete set null,
  updated_at  timestamptz not null default now()
);
comment on table public.natacion_ficha_licencia is '450 · SIP, foto carnet y DNI del tutor (licencias de natación). Sin permisos directos: solo natacion_comp_*.';
alter table public.natacion_ficha_licencia enable row level security;
revoke all on public.natacion_ficha_licencia from anon, authenticated;

drop function if exists public._natacion_comp_falta(public.atletas);
create or replace function public._natacion_comp_falta(p_atleta uuid)
returns text[] language sql stable security definer set search_path to 'public' as $$
  select array_remove(array[
    case when nullif(nullif(btrim(coalesce(a.dni,'')),''),'0') is null then 'DNI' end,
    case when nullif(btrim(coalesce(f.sip,'')),'') is null then 'SIP' end,
    case when nullif(btrim(coalesce(f.foto_carnet,'')),'') is null then 'foto' end,
    case when a.fecha_nacimiento is null then 'fecha de nacimiento' end], null)
  from public.atletas a left join public.natacion_ficha_licencia f on f.atleta_id = a.id where a.id = p_atleta;
$$;
revoke all on function public._natacion_comp_falta(uuid) from public, anon, authenticated;

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
        'sin_autorizar', (select count(*) from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado and not x.autorizado),
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
        'convocado', coalesce(x.convocado, false), 'pruebas', x.pruebas, 'autorizado', coalesce(x.autorizado, false), 'nota', x.nota)
      order by n.nombre, n.apellidos), '[]')
  ) into v
  from ninos n
  left join public.natacion_comp_convocados x on x.jornada_id = j.id and x.atleta_id = n.id;
  return v;
end $$;

create or replace function public.natacion_comp_ficha(p_atleta uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare a public.atletas; f public.natacion_ficha_licencia;
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into a from public.atletas where id = p_atleta;
  if not found then raise exception 'No encuentro a ese nadador.' using errcode = 'P0001'; end if;
  select * into f from public.natacion_ficha_licencia where atleta_id = p_atleta;
  return jsonb_build_object('id', a.id, 'nombre', a.nombre, 'apellidos', a.apellidos, 'fecha_nacimiento', a.fecha_nacimiento, 'sexo', a.sexo,
    'dni', a.dni, 'sip', f.sip, 'foto_carnet', f.foto_carnet, 'nombre_tutor', a.nombre_tutor, 'dni_tutor', f.dni_tutor,
    'telefono_tutor', a.telefono_tutor, 'email_tutor', a.email_tutor, 'direccion', a.direccion, 'estado', a.estado,
    'licencia', coalesce((select jsonb_build_object('tramitada', l.tramitada, 'numero', l.numero) from public.natacion_licencias l where l.atleta_id = a.id and l.temporada = '2026/27'),
                         jsonb_build_object('tramitada', false)),
    'jornadas', coalesce((select jsonb_agg(jsonb_build_object('fecha', j.fecha, 'lugar', j.lugar, 'pruebas', x.pruebas) order by j.fecha)
                            from public.natacion_comp_convocados x join public.natacion_comp_jornadas j on j.id = x.jornada_id
                           where x.atleta_id = a.id and x.convocado), '[]'));
end $$;

create or replace function public.natacion_comp_ficha_guardar(p_atleta uuid, p_datos jsonb)
returns void language plpgsql security definer set search_path to 'public' as $$
declare a public.atletas; f public.natacion_ficha_licencia; k text; v_nuevo text; v_viejo text;
  campos  text[] := array['dni','fecha_nacimiento','sexo','nombre_tutor','telefono_tutor','email_tutor','direccion'];
  aparte  text[] := array['sip','foto_carnet','dni_tutor'];
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into a from public.atletas where id = p_atleta for update;
  if not found then raise exception 'No encuentro a ese nadador.' using errcode = 'P0001'; end if;
  foreach k in array campos loop
    continue when not (p_datos ? k);
    v_nuevo := nullif(btrim(coalesce(p_datos->>k, '')), '');
    execute format('select ($1).%I::text', k) into v_viejo using a;
    continue when v_nuevo is not distinct from v_viejo;
    if k = 'fecha_nacimiento' then
      update public.atletas set fecha_nacimiento = v_nuevo::date, updated_at = now() where id = p_atleta;
    elsif k = 'sexo' and v_nuevo is not null and v_nuevo not in ('hombre','mujer') then
      raise exception 'Sexo: hombre o mujer.' using errcode = 'P0001';
    else
      execute format('update public.atletas set %I = $1, updated_at = now() where id = $2', k) using v_nuevo, p_atleta;
    end if;
    insert into public.natacion_comp_cambios (atleta_id, campo, antes, despues, por) values (p_atleta, k, v_viejo, v_nuevo, public.mi_perfil_id());
  end loop;
  insert into public.natacion_ficha_licencia (atleta_id) values (p_atleta) on conflict do nothing;
  select * into f from public.natacion_ficha_licencia where atleta_id = p_atleta for update;
  foreach k in array aparte loop
    continue when not (p_datos ? k);
    v_nuevo := nullif(btrim(coalesce(p_datos->>k, '')), '');
    execute format('select ($1).%I::text', k) into v_viejo using f;
    continue when v_nuevo is not distinct from v_viejo;
    execute format('update public.natacion_ficha_licencia set %I = $1, updated_por = $2, updated_at = now() where atleta_id = $3', k) using v_nuevo, public.mi_perfil_id(), p_atleta;
    insert into public.natacion_comp_cambios (atleta_id, campo, antes, despues, por) values (p_atleta, k, v_viejo, v_nuevo, public.mi_perfil_id());
  end loop;
  if p_datos ? 'licencia' then
    insert into public.natacion_licencias (atleta_id, tramitada, numero, updated_por)
    values (p_atleta, coalesce((p_datos->'licencia'->>'tramitada')::boolean, false), nullif(btrim(p_datos->'licencia'->>'numero'),''), public.mi_perfil_id())
    on conflict (atleta_id, temporada) do update set tramitada = excluded.tramitada, numero = excluded.numero, updated_por = excluded.updated_por, updated_at = now();
  end if;
end $$;

create or replace function public.natacion_comp_excel(p_jornada uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('nombre', a.nombre, 'apellidos', a.apellidos, 'sexo', a.sexo, 'fecha_nacimiento', a.fecha_nacimiento,
      'dni', a.dni, 'sip', fl.sip, 'foto_carnet', fl.foto_carnet, 'nombre_tutor', a.nombre_tutor, 'dni_tutor', fl.dni_tutor,
      'telefono_tutor', a.telefono_tutor, 'email_tutor', a.email_tutor, 'direccion', a.direccion,
      'pruebas', x.pruebas, 'autorizado', x.autorizado, 'licencia', coalesce(l.tramitada, false)) order by a.apellidos, a.nombre)
    from public.natacion_comp_convocados x join public.atletas a on a.id = x.atleta_id
    left join public.natacion_licencias l on l.atleta_id = a.id and l.temporada = '2026/27'
    left join public.natacion_ficha_licencia fl on fl.atleta_id = a.id
    where x.jornada_id = p_jornada and x.convocado), '[]');
end $$;

commit;
