-- 462 · Academia AC98 · base mínima para las vistas Semana y Hoy
-- ---------------------------------------------------------------------------
-- Andrés (28-oct-2026, revisado con ChatGPT): primera versión funcional del mundo
-- «Academia AC98» (docs/mundo-academia.md). Esta migración solo prepara datos:
--   1) academia_grupos: qué grupos son «de Academia» (el real y uno de PRUEBA con
--      atletas ficticios) y el plazo del feedback (configurable; 22:00 propuesta).
--   2) Permiso: academia_puede(grupo) = admin o entrenador de ese grupo (los mismos
--      permisos de hoy; no se amplía nada sobre otros grupos).
--   3) sesiones: clase_dia (entreno · descanso · ausencia = solo antiguas «No asiste»
--      cuyo plan no se conservó), momento (unica · manana · tarde · sin_especificar),
--      objetivo, exigencia prevista (general / neuromuscular / metabólica) y
--      sustituye_a. Relleno prudente de lo antiguo, SIN crear versiones nuevas.
--   4) ausencias: motivo tipificado, quién la registra y nota (la ausencia NO borra
--      la sesión prevista).
--   5) registros_sesion: revisado_en / revisado_por (feedback revisado por el
--      entrenador; el atleta no puede tocarlo).
--   6) grupos_trabajo (+ miembros): los decide el entrenador cada día; por sesión o
--      por bloque. Cada atleta conserva su prescripción y su registro.
--   7) sesiones_revisiones: cambios propuestos a una sesión YA publicada; al
--      aplicarlos se comprueba la versión y se crea una versión nueva de la MISMA
--      sesión (sin duplicar).
--   8) mis_mundos(): añade el mundo «academia».
-- ---------------------------------------------------------------------------
begin;

-- 1 · Grupos de Academia y ajustes -----------------------------------------------
create table public.academia_grupos (
  grupo_id             uuid primary key references public.grupos(id) on delete cascade,
  es_prueba            boolean not null default false,
  feedback_hora_limite time not null default '22:00',
  feedback_dias        integer not null default 0 check (feedback_dias between 0 and 7),
  creado_en            timestamptz not null default now()
);
insert into public.academia_grupos (grupo_id) values ('c288b979-cd00-4abb-96da-30fa997ef297');

-- 2 · Permisos -----------------------------------------------------------------
create or replace function public.academia_puede(p_grupo uuid) returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from public.academia_grupos ag where ag.grupo_id = p_grupo)
     and (public.es_admin() or public.soy_admin_de_verdad()
          or exists (select 1 from public.grupos g where g.id = p_grupo and g.entrenador_id = public.mi_perfil_id()));
$$;

create or replace function public.academia_mis_grupos()
returns table (grupo_id uuid, nombre text, es_prueba boolean, feedback_hora_limite time, feedback_dias integer)
language sql stable security definer set search_path to 'public' as $$
  select ag.grupo_id, g.nombre, ag.es_prueba, ag.feedback_hora_limite, ag.feedback_dias
    from public.academia_grupos ag join public.grupos g on g.id = ag.grupo_id
   where public.academia_puede(ag.grupo_id)
   order by ag.es_prueba, g.nombre;
$$;

-- 3 · Sesiones: tipo de día, momento, intención, sustitución -----------------------
alter table public.sesiones
  add column clase_dia text not null default 'entreno' check (clase_dia in ('entreno','descanso','ausencia')),
  add column momento text not null default 'unica' check (momento in ('unica','manana','tarde','sin_especificar')),
  add column objetivo text check (objetivo is null or length(objetivo) <= 80),
  add column exigencia text check (exigencia in ('baja','media','alta')),
  add column exigencia_neuro text check (exigencia_neuro in ('baja','media','alta')),
  add column exigencia_meta text check (exigencia_meta in ('baja','media','alta')),
  add column sustituye_a uuid references public.sesiones(id) on delete set null;

-- Relleno de lo antiguo sin disparar versiones (es un dato derivado, no un cambio
-- del plan). Reglas prudentes: lo dudoso queda «sin_especificar».
set local session_replication_role = replica;
update public.sesiones set clase_dia = 'descanso'
 where titulo ~* '^\s*(descanso|no entrena)';
update public.sesiones set clase_dia = 'ausencia'
 where titulo ~* '^\s*no asiste';
with c as (
  select s.id, s.hora,
         count(*) over (partition by coalesce(s.atletas_ids[1]::text, 'g:' || s.grupo_id::text), s.fecha) as n
    from public.sesiones s
   where s.archivada_en is null and s.clase_dia = 'entreno')
update public.sesiones s
   set momento = case when c.n = 1 then 'unica'
                      when c.hora is null then 'sin_especificar'
                      when c.hora < '14:00' then 'manana' else 'tarde' end
  from c where c.id = s.id;
set local session_replication_role = origin;

-- Las marcas internas nuevas no deben crear versión por sí solas: igual que antes,
-- solo cuentan los cambios reales. (objetivo y exigencia SÍ son parte del plan.)

-- 4 · Ausencias tipificadas -------------------------------------------------------
alter table public.ausencias
  add column motivo_tipo text check (motivo_tipo in ('viaje','estudios','trabajo','enfermedad','lesion','otro')),
  add column registrado_por uuid,
  add column nota text check (nota is null or length(nota) <= 300);

-- 5 · Feedback revisado -------------------------------------------------------
alter table public.registros_sesion
  add column revisado_en timestamptz,
  add column revisado_por uuid;

create or replace function public.registros_proteger_revision() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  -- Solo el entrenador del atleta o un admin marcan «revisado».
  if (new.revisado_en is distinct from old.revisado_en or new.revisado_por is distinct from old.revisado_por)
     and not (public.es_admin() or public.soy_admin_de_verdad() or public.soy_entrenador_de(new.atleta_id)
              or (auth.jwt() ->> 'email') is null) then
    new.revisado_en := old.revisado_en; new.revisado_por := old.revisado_por;
  end if;
  return new;
end $$;
create trigger trg_registros_b_revision before update on public.registros_sesion
  for each row execute function public.registros_proteger_revision();

-- La revisión del entrenador no es una corrección del feedback.
create or replace function public.registros_guardar_anterior() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  v_cambios text[];
  v_n       int;
begin
  if coalesce(current_setting('apolana.purga', true), '') = '1' then
    return null;
  end if;
  if tg_op = 'UPDATE' then
    select array_agg(k order by k) into v_cambios
      from jsonb_each(to_jsonb(new)) n(k, val)
     where k not in ('corregido_en','corregido_veces','revisado_en','revisado_por')
       and val is distinct from (to_jsonb(old) -> k);
    if v_cambios is null then return null; end if;
  end if;
  select coalesce(max(n), 0) + 1 into v_n from public.registros_sesion_versiones where registro_id = old.id;
  insert into public.registros_sesion_versiones
    (registro_id, atleta_id, sesion_id, sesion_version_id, n, evento, datos, cambios, autor_perfil_id, via)
  values (old.id, old.atleta_id, old.sesion_id, old.sesion_version_id, v_n,
          case when tg_op = 'DELETE' then 'borrado' else 'correccion' end,
          to_jsonb(old), v_cambios, public.mi_perfil_id(), public._historial_via());
  return null;
end $$;

create or replace function public.academia_marcar_revisado(p_registro uuid, p_revisado boolean default true)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_at uuid; v_grupo uuid;
begin
  select r.atleta_id, s.grupo_id into v_at, v_grupo
    from public.registros_sesion r join public.sesiones s on s.id = r.sesion_id where r.id = p_registro;
  if v_at is null then raise exception 'Ese registro no existe.'; end if;
  if not public.academia_puede(v_grupo) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  update public.registros_sesion
     set revisado_en = case when p_revisado then now() end,
         revisado_por = case when p_revisado then public.mi_perfil_id() end
   where id = p_registro;
end $$;

-- 6 · Grupos de trabajo (los decide el entrenador) -----------------------------------
create table public.grupos_trabajo (
  id         uuid primary key default gen_random_uuid(),
  grupo_id   uuid not null references public.grupos(id) on delete cascade,
  fecha      date not null,
  nombre     text not null check (length(nombre) between 1 and 60),
  orden      integer not null default 0,
  nota       text check (nota is null or length(nota) <= 300),
  creado_por uuid,
  creado_en  timestamptz not null default now()
);
create index grupos_trabajo_dia on public.grupos_trabajo (grupo_id, fecha);
create table public.grupos_trabajo_miembros (
  id               uuid primary key default gen_random_uuid(),
  grupo_trabajo_id uuid not null references public.grupos_trabajo(id) on delete cascade,
  sesion_id        uuid not null references public.sesiones(id) on delete cascade,
  bloque           text,                 -- null = la sesión entera; si no, la etiqueta del bloque compartido
  orden            integer not null default 0
);
create unique index grupos_trabajo_miembros_uno on public.grupos_trabajo_miembros (grupo_trabajo_id, sesion_id, coalesce(bloque, ''));

-- 7 · Revisiones de sesiones publicadas ----------------------------------------------
create table public.sesiones_revisiones (
  id              uuid primary key default gen_random_uuid(),
  sesion_id       uuid not null references public.sesiones(id) on delete cascade,
  version_base    integer not null,
  propuesta       jsonb not null,         -- solo los campos que cambian
  motivo          text check (motivo is null or length(motivo) <= 300),
  estado          text not null default 'pendiente' check (estado in ('pendiente','aplicada','descartada')),
  autor_perfil_id uuid,
  via             text not null default 'app',
  creada_en       timestamptz not null default now(),
  resuelta_en     timestamptz,
  resuelta_por    uuid,
  resultado       text
);
create index sesiones_revisiones_ses on public.sesiones_revisiones (sesion_id, estado);

create or replace function public.academia_revision_crear(p_sesion uuid, p_version_base integer, p_propuesta jsonb, p_motivo text default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_s public.sesiones%rowtype; v_id uuid;
begin
  select * into v_s from public.sesiones where id = p_sesion;
  if v_s.id is null then raise exception 'Esa sesión no existe.'; end if;
  if not public.academia_puede(v_s.grupo_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if v_s.version <> p_version_base then
    raise exception 'La sesión ya va por la versión % (la propuesta parte de la %).', v_s.version, p_version_base;
  end if;
  insert into public.sesiones_revisiones (sesion_id, version_base, propuesta, motivo, autor_perfil_id, via)
  values (p_sesion, p_version_base, p_propuesta, p_motivo, public.mi_perfil_id(), public._historial_via())
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.academia_revision_resolver(p_revision uuid, p_aplicar boolean, p_motivo text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_r public.sesiones_revisiones%rowtype; v_s public.sesiones%rowtype; p jsonb;
begin
  select * into v_r from public.sesiones_revisiones where id = p_revision for update;
  if v_r.id is null then raise exception 'Esa revisión no existe.'; end if;
  if v_r.estado <> 'pendiente' then raise exception 'Esa revisión ya está %.', v_r.estado; end if;
  select * into v_s from public.sesiones where id = v_r.sesion_id for update;
  if not public.academia_puede(v_s.grupo_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if not p_aplicar then
    update public.sesiones_revisiones set estado = 'descartada', resuelta_en = now(), resuelta_por = public.mi_perfil_id(),
           resultado = coalesce(p_motivo, 'Descartada') where id = p_revision;
    return jsonb_build_object('ok', true, 'estado', 'descartada');
  end if;
  if v_s.version <> v_r.version_base then
    return jsonb_build_object('ok', false, 'motivo', 'La sesión cambió desde que se propuso la revisión (versión ' || v_r.version_base || ' → ' || v_s.version || '). No se aplica.');
  end if;
  p := v_r.propuesta;
  update public.sesiones set
    titulo            = case when p ? 'titulo' then p->>'titulo' else titulo end,
    bloques           = case when p ? 'bloques' then p->'bloques' else bloques end,
    objetivo          = case when p ? 'objetivo' then nullif(p->>'objetivo','') else objetivo end,
    exigencia         = case when p ? 'exigencia' then nullif(p->>'exigencia','') else exigencia end,
    exigencia_neuro   = case when p ? 'exigencia_neuro' then nullif(p->>'exigencia_neuro','') else exigencia_neuro end,
    exigencia_meta    = case when p ? 'exigencia_meta' then nullif(p->>'exigencia_meta','') else exigencia_meta end,
    nota_razonamiento = case when p ? 'nota_razonamiento' then p->>'nota_razonamiento' else nota_razonamiento end,
    hora              = case when p ? 'hora' then nullif(p->>'hora','')::time else hora end,
    momento           = case when p ? 'momento' then p->>'momento' else momento end,
    duracion_min      = case when p ? 'duracion_min' then nullif(p->>'duracion_min','')::int else duracion_min end
  where id = v_s.id;
  update public.sesiones_revisiones set estado = 'aplicada', resuelta_en = now(), resuelta_por = public.mi_perfil_id(),
         resultado = 'Aplicada como versión ' || (select version from public.sesiones where id = v_s.id) where id = p_revision;
  return jsonb_build_object('ok', true, 'estado', 'aplicada', 'version', (select version from public.sesiones where id = v_s.id));
end $$;

-- 8 · Permisos de las tablas nuevas ------------------------------------------------
alter table public.academia_grupos enable row level security;
alter table public.grupos_trabajo enable row level security;
alter table public.grupos_trabajo_miembros enable row level security;
alter table public.sesiones_revisiones enable row level security;
revoke all on public.academia_grupos, public.grupos_trabajo, public.grupos_trabajo_miembros, public.sesiones_revisiones from public, anon, authenticated;
grant select on public.academia_grupos, public.sesiones_revisiones to authenticated;
grant select, insert, update, delete on public.grupos_trabajo, public.grupos_trabajo_miembros to authenticated;
grant all on public.academia_grupos, public.grupos_trabajo, public.grupos_trabajo_miembros, public.sesiones_revisiones to service_role;

create policy "academia ve sus grupos" on public.academia_grupos for select to authenticated
  using (public.academia_puede(grupo_id));
create policy "academia gestiona grupos de trabajo" on public.grupos_trabajo for all to authenticated
  using (public.academia_puede(grupo_id)) with check (public.academia_puede(grupo_id));
create policy "academia gestiona miembros" on public.grupos_trabajo_miembros for all to authenticated
  using (exists (select 1 from public.grupos_trabajo gt where gt.id = grupo_trabajo_id and public.academia_puede(gt.grupo_id)))
  with check (exists (select 1 from public.grupos_trabajo gt where gt.id = grupo_trabajo_id and public.academia_puede(gt.grupo_id)));
create policy "academia ve revisiones" on public.sesiones_revisiones for select to authenticated
  using (exists (select 1 from public.sesiones s where s.id = sesion_id and public.academia_puede(s.grupo_id)));

revoke all on function public.academia_puede(uuid), public.academia_mis_grupos(), public.academia_marcar_revisado(uuid, boolean),
  public.academia_revision_crear(uuid, integer, jsonb, text), public.academia_revision_resolver(uuid, boolean, text),
  public.registros_proteger_revision() from public, anon;
grant execute on function public.academia_puede(uuid), public.academia_mis_grupos(), public.academia_marcar_revisado(uuid, boolean),
  public.academia_revision_crear(uuid, integer, jsonb, text), public.academia_revision_resolver(uuid, boolean, text) to authenticated, service_role;

-- 9 · El mundo «academia» ------------------------------------------------------------
create or replace function public.mis_mundos()
 returns text[] language sql stable security definer set search_path to 'public' as $function$
  select case
    when public.es_admin() or public.soy_admin_de_verdad()
      then array['general','natacion','escuela-nat','cubo','pista','academia','escuela-atl','running','comunicacion']
    else coalesce((
      select array_agg(distinct w order by w)
      from (
        select case sec
          when 'natacion'          then 'natacion'
          when 'escuela-natacion'  then 'escuela-nat'
          when 'cubo'              then 'cubo'
          when 'pista'             then 'pista'
          when 'competicion'       then 'pista'
          when 'escuela'           then 'escuela-atl'
          when 'escuela-atletismo' then 'escuela-atl'
          when 'running'           then 'running'
          when 'comunicacion'      then 'comunicacion'
          else null
        end as w
        from public.mis_secciones_responsable() as sec
        union
        -- (mig 462) el entrenador de un grupo de Academia ve su mundo
        select 'academia' where exists (select 1 from public.academia_grupos ag join public.grupos g on g.id = ag.grupo_id
                                         where g.entrenador_id = public.mi_perfil_id())
      ) m
      where w is not null
    ), '{}'::text[])
  end
$function$;

commit;
