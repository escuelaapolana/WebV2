-- 449 · Natación · COMPETICIONES DE LA ESCUELA (para Paloma Solera)
-- ---------------------------------------------------------------------------
-- Mario (27-oct-2026): «Paloma me organiza las competiciones de la escuela.
-- Para dar de alta en licencias y convocar a controles necesitaría acceso a los
-- datos personales y la relación de niños por edad en cada momento (hay altas
-- y bajas)… trabaja con una hoja de cálculo; ¿se podría incorporar a la web?».
-- Andrés: «sí, constrúyela con datos reales» (maqueta v3 aprobada).
--
-- Piezas:
--   · Datos de licencia que faltaban en la ficha (atletas): sip, foto_carnet,
--     dni_tutor. SIN permiso de columna para authenticated: solo se leen y
--     escriben por las funciones de aquí (que comprueban el permiso).
--   · natacion_comp_acceso: quién entra a esta pantalla sin ser gestor de
--     natación (Paloma). Gestores de natación y admin entran siempre.
--   · natacion_comp_categorias (por años de nacimiento y temporada),
--     natacion_comp_jornadas, natacion_comp_convocados (convocado, pruebas,
--     autorización), natacion_licencias (licencia de la temporada) y
--     natacion_comp_cambios (registro de cada cambio de datos personales).
--   · Niños = los de la Escuela de natación ACTIVOS (franja activa de tipo
--     Escuela y ficha no de baja), calculado en cada momento.
-- ---------------------------------------------------------------------------
begin;

-- 1 · Datos de licencia en la ficha (sin permiso de columna: solo por RPC)
alter table public.atletas add column if not exists sip text;
alter table public.atletas add column if not exists foto_carnet text;
alter table public.atletas add column if not exists dni_tutor text;
comment on column public.atletas.sip is '449 · SIP / tarjeta sanitaria (licencia de natación). Solo por natacion_comp_*.';
comment on column public.atletas.foto_carnet is '449 · Enlace a la foto carnet (formulario de inscripción). Solo por natacion_comp_*.';
comment on column public.atletas.dni_tutor is '449 · DNI/NIE del padre, madre o tutor. Solo por natacion_comp_*.';
revoke select (sip, foto_carnet, dni_tutor), insert (sip, foto_carnet, dni_tutor), update (sip, foto_carnet, dni_tutor)
  on public.atletas from anon, authenticated;

-- 2 · Quién entra
create table if not exists public.natacion_comp_acceso (
  perfil_id uuid primary key references public.perfiles(id) on delete cascade,
  nota      text,
  creado_en timestamptz not null default now()
);
alter table public.natacion_comp_acceso enable row level security;
revoke all on public.natacion_comp_acceso from anon, authenticated;

create or replace function public.natacion_comp_puede()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select public.natacion_cuotas_puede()
      or exists (select 1 from public.natacion_comp_acceso a where a.perfil_id = public.mi_perfil_id());
$$;
revoke all on function public.natacion_comp_puede() from public, anon;
grant execute on function public.natacion_comp_puede() to authenticated;

-- 3 · Tablas
create table if not exists public.natacion_comp_categorias (
  clave      text not null,
  temporada  text not null default '2026/27',
  nombre     text not null,
  desde_anio int  not null,
  hasta_anio int  not null,
  orden      int  not null default 0,
  primary key (clave, temporada)
);
create table if not exists public.natacion_comp_jornadas (
  id         uuid primary key default gen_random_uuid(),
  temporada  text not null default '2026/27',
  fecha      date not null,
  hora       text,
  lugar      text not null,
  nombre     text,
  categorias text[] not null default '{}',
  convoca    text,
  notas      text,
  creado_por uuid references public.perfiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.natacion_comp_convocados (
  jornada_id  uuid not null references public.natacion_comp_jornadas(id) on delete cascade,
  atleta_id   uuid not null references public.atletas(id) on delete cascade,
  convocado   boolean not null default true,
  pruebas     text,
  autorizado  boolean not null default false,
  nota        text,
  updated_por uuid references public.perfiles(id) on delete set null,
  updated_at  timestamptz not null default now(),
  primary key (jornada_id, atleta_id)
);
create table if not exists public.natacion_licencias (
  atleta_id   uuid not null references public.atletas(id) on delete cascade,
  temporada   text not null default '2026/27',
  tramitada   boolean not null default false,
  numero      text,
  updated_por uuid references public.perfiles(id) on delete set null,
  updated_at  timestamptz not null default now(),
  primary key (atleta_id, temporada)
);
create table if not exists public.natacion_comp_cambios (
  id        bigserial primary key,
  atleta_id uuid,
  campo     text not null,
  antes     text,
  despues   text,
  por       uuid,
  cuando    timestamptz not null default now()
);
do $$ declare t text; begin
  foreach t in array array['natacion_comp_categorias','natacion_comp_jornadas','natacion_comp_convocados','natacion_licencias','natacion_comp_cambios'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $$;

insert into public.natacion_comp_categorias (clave, nombre, desde_anio, hasta_anio, orden) values
  ('benjamin', 'Benjamín', 2016, 2017, 1),
  ('alevin',   'Alevín',   2014, 2015, 2),
  ('infantil', 'Infantil', 2012, 2013, 3),
  ('mayores',  'Mayores',  1990, 2011, 4)
on conflict do nothing;

-- 4 · Los niños de la escuela, hoy (activos)
create or replace function public._natacion_comp_ninos()
returns setof uuid language sql stable security definer set search_path to 'public' as $$
  select distinct a.id
    from public.atletas a
    join public.natacion_inscripciones i on i.atleta_id = a.id and i.activa and i.tipo = 'Escuela'
   where coalesce(a.estado, 'activo') <> 'baja' and a.anonimizado_en is null;
$$;
revoke all on function public._natacion_comp_ninos() from public, anon, authenticated;

create or replace function public._natacion_comp_falta(a public.atletas)
returns text[] language sql immutable as $$
  select array_remove(array[
    case when nullif(nullif(btrim(coalesce(a.dni,'')),''),'0') is null then 'DNI' end,
    case when nullif(btrim(coalesce(a.sip,'')),'') is null then 'SIP' end,
    case when nullif(btrim(coalesce(a.foto_carnet,'')),'') is null then 'foto' end,
    case when a.fecha_nacimiento is null then 'fecha de nacimiento' end], null);
$$;
revoke all on function public._natacion_comp_falta(public.atletas) from public, anon, authenticated;

-- 5 · Lista de jornadas (con lo que hay que revisar)
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
        'sin_datos', (select count(*) from public.natacion_comp_convocados x join public.atletas a on a.id = x.atleta_id
                      where x.jornada_id = j.id and x.convocado and cardinality(public._natacion_comp_falta(a)) > 0))
      order by j.fecha, j.hora nulls first, j.lugar)
      from public.natacion_comp_jornadas j where j.temporada = '2026/27'), '[]')
  ) into v;
  return v;
end $$;

-- 6 · Una jornada: los niños de sus categorías (hoy) + los convocados que ya no están
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
        'falta', to_jsonb(public._natacion_comp_falta(n::public.atletas)),
        'licencia', coalesce((select l.tramitada from public.natacion_licencias l where l.atleta_id = n.id and l.temporada = j.temporada), false),
        'convocado', coalesce(x.convocado, false), 'pruebas', x.pruebas, 'autorizado', coalesce(x.autorizado, false), 'nota', x.nota)
      order by n.nombre, n.apellidos), '[]')
  ) into v
  from ninos n
  left join public.natacion_comp_convocados x on x.jornada_id = j.id and x.atleta_id = n.id;
  return v;
end $$;

-- 7 · Crear / cambiar / borrar una jornada
create or replace function public.natacion_comp_jornada_guardar(p_id uuid, p_datos jsonb)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_id uuid := p_id; v_cats text[];
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if nullif(btrim(coalesce(p_datos->>'lugar','')),'') is null or nullif(p_datos->>'fecha','') is null then
    raise exception 'Falta la fecha o el lugar.' using errcode = 'P0001'; end if;
  select coalesce(array_agg(c), '{}') into v_cats from jsonb_array_elements_text(coalesce(p_datos->'categorias','[]')) c
   where c in (select clave from public.natacion_comp_categorias);
  if cardinality(v_cats) = 0 then raise exception 'Elige al menos una categoría.' using errcode = 'P0001'; end if;
  if v_id is null then
    insert into public.natacion_comp_jornadas (fecha, hora, lugar, nombre, categorias, convoca, notas, creado_por)
    values ((p_datos->>'fecha')::date, nullif(btrim(p_datos->>'hora'),''), btrim(p_datos->>'lugar'), nullif(btrim(p_datos->>'nombre'),''),
            v_cats, nullif(btrim(p_datos->>'convoca'),''), nullif(btrim(p_datos->>'notas'),''), public.mi_perfil_id())
    returning id into v_id;
  else
    update public.natacion_comp_jornadas set fecha = (p_datos->>'fecha')::date, hora = nullif(btrim(p_datos->>'hora'),''), lugar = btrim(p_datos->>'lugar'),
           nombre = nullif(btrim(p_datos->>'nombre'),''), categorias = v_cats, convoca = nullif(btrim(p_datos->>'convoca'),''),
           notas = nullif(btrim(p_datos->>'notas'),''), updated_at = now()
     where id = v_id;
  end if;
  return v_id;
end $$;

create or replace function public.natacion_comp_jornada_borrar(p_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  delete from public.natacion_comp_jornadas where id = p_id;
end $$;

-- 8 · Convocar / pruebas / autorización (un niño en una jornada)
create or replace function public.natacion_comp_marcar(p_jornada uuid, p_atleta uuid, p_datos jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare r public.natacion_comp_convocados;
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  insert into public.natacion_comp_convocados (jornada_id, atleta_id, convocado, pruebas, autorizado, nota, updated_por)
  values (p_jornada, p_atleta, coalesce((p_datos->>'convocado')::boolean, true), nullif(btrim(p_datos->>'pruebas'),''),
          coalesce((p_datos->>'autorizado')::boolean, false), nullif(btrim(p_datos->>'nota'),''), public.mi_perfil_id())
  on conflict (jornada_id, atleta_id) do update set
    convocado  = case when p_datos ? 'convocado'  then (p_datos->>'convocado')::boolean else natacion_comp_convocados.convocado end,
    pruebas    = case when p_datos ? 'pruebas'    then nullif(btrim(p_datos->>'pruebas'),'') else natacion_comp_convocados.pruebas end,
    autorizado = case when p_datos ? 'autorizado' then (p_datos->>'autorizado')::boolean else natacion_comp_convocados.autorizado end,
    nota       = case when p_datos ? 'nota'       then nullif(btrim(p_datos->>'nota'),'') else natacion_comp_convocados.nota end,
    updated_por = public.mi_perfil_id(), updated_at = now()
  returning * into r;
  return to_jsonb(r);
end $$;

-- 9 · Ficha del niño (datos de licencia y de la familia) y guardarla con registro
create or replace function public.natacion_comp_ficha(p_atleta uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare a public.atletas;
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into a from public.atletas where id = p_atleta;
  if not found then raise exception 'No encuentro a ese nadador.' using errcode = 'P0001'; end if;
  return jsonb_build_object('id', a.id, 'nombre', a.nombre, 'apellidos', a.apellidos, 'fecha_nacimiento', a.fecha_nacimiento, 'sexo', a.sexo,
    'dni', a.dni, 'sip', a.sip, 'foto_carnet', a.foto_carnet, 'nombre_tutor', a.nombre_tutor, 'dni_tutor', a.dni_tutor,
    'telefono_tutor', a.telefono_tutor, 'email_tutor', a.email_tutor, 'direccion', a.direccion, 'estado', a.estado,
    'licencia', coalesce((select jsonb_build_object('tramitada', l.tramitada, 'numero', l.numero) from public.natacion_licencias l where l.atleta_id = a.id and l.temporada = '2026/27'),
                         jsonb_build_object('tramitada', false)),
    'jornadas', coalesce((select jsonb_agg(jsonb_build_object('fecha', j.fecha, 'lugar', j.lugar, 'pruebas', x.pruebas) order by j.fecha)
                            from public.natacion_comp_convocados x join public.natacion_comp_jornadas j on j.id = x.jornada_id
                           where x.atleta_id = a.id and x.convocado), '[]'));
end $$;

create or replace function public.natacion_comp_ficha_guardar(p_atleta uuid, p_datos jsonb)
returns void language plpgsql security definer set search_path to 'public' as $$
declare a public.atletas; k text; v_nuevo text; v_viejo text;
  campos text[] := array['dni','sip','foto_carnet','fecha_nacimiento','sexo','nombre_tutor','dni_tutor','telefono_tutor','email_tutor','direccion'];
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
  if p_datos ? 'licencia' then
    insert into public.natacion_licencias (atleta_id, tramitada, numero, updated_por)
    values (p_atleta, coalesce((p_datos->'licencia'->>'tramitada')::boolean, false), nullif(btrim(p_datos->'licencia'->>'numero'),''), public.mi_perfil_id())
    on conflict (atleta_id, temporada) do update set tramitada = excluded.tramitada, numero = excluded.numero, updated_por = excluded.updated_por, updated_at = now();
  end if;
end $$;

-- 10 · Excel de licencias: los datos de los convocados de una jornada
create or replace function public.natacion_comp_excel(p_jornada uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('nombre', a.nombre, 'apellidos', a.apellidos, 'sexo', a.sexo, 'fecha_nacimiento', a.fecha_nacimiento,
      'dni', a.dni, 'sip', a.sip, 'foto_carnet', a.foto_carnet, 'nombre_tutor', a.nombre_tutor, 'dni_tutor', a.dni_tutor,
      'telefono_tutor', a.telefono_tutor, 'email_tutor', a.email_tutor, 'direccion', a.direccion,
      'pruebas', x.pruebas, 'autorizado', x.autorizado, 'licencia', coalesce(l.tramitada, false)) order by a.apellidos, a.nombre)
    from public.natacion_comp_convocados x join public.atletas a on a.id = x.atleta_id
    left join public.natacion_licencias l on l.atleta_id = a.id and l.temporada = '2026/27'
    where x.jornada_id = p_jornada and x.convocado), '[]');
end $$;

do $$ declare f text; begin
  foreach f in array array['natacion_comp_listar()','natacion_comp_jornada(uuid)','natacion_comp_jornada_guardar(uuid,jsonb)','natacion_comp_jornada_borrar(uuid)',
                           'natacion_comp_marcar(uuid,uuid,jsonb)','natacion_comp_ficha(uuid)','natacion_comp_ficha_guardar(uuid,jsonb)','natacion_comp_excel(uuid)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

commit;
