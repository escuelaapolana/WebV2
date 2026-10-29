-- ===========================================================================
-- 491 · Academia · Carga y contenidos (primera versión, solo grupo PRUEBA)
-- ---------------------------------------------------------------------------
--   1) plan_filas_estructura: la lectura de una fila del plan que el entrenador
--      ha revisado o corregido (cantidad, posición, objetivo, medio…), atada a
--      la versión de la sesión y con historial. Lo que propone la app NO se
--      guarda: se vuelve a leer del texto y queda como «propuesta».
--      Escribir, de momento, solo en grupos de prueba (es_prueba).
--   2) El plazo del feedback se configura por grupo (día y hora). Nunca vence
--      antes de acabar la sesión: eso lo aplica la pantalla con la hora y la
--      duración de cada sesión.
-- Numerada aparte (49x) porque otra sesión usa 475-477 para natación.
-- ===========================================================================
begin;

create table public.plan_filas_estructura (
  id              uuid primary key default gen_random_uuid(),
  grupo_id        uuid not null references public.grupos(id) on delete cascade,
  sesion_id       uuid not null references public.sesiones(id) on delete cascade,
  sesion_version  int not null,
  fila_id         text not null,
  huella          text not null,          -- el texto de la fila que se leyó
  estructura      jsonb not null check (jsonb_typeof(estructura) = 'object'),
  estado          text not null check (estado in ('revisada','manual')),
  nota            text,
  version         int not null default 1,
  autor_perfil_id uuid,
  creado_en       timestamptz not null default now(),
  actualizado_por uuid,
  actualizado_en  timestamptz not null default now(),
  historial       jsonb not null default '[]',
  unique (sesion_id, sesion_version, fila_id)
);
create index plan_filas_estructura_grupo on public.plan_filas_estructura (grupo_id);
comment on table public.plan_filas_estructura is 'Lectura revisada por el entrenador de una fila del plan (versión concreta). Las propuestas de la app no se guardan.';
create trigger trg_plan_filas_estructura_historial before insert or update on public.plan_filas_estructura
  for each row execute function public.academia_ficha_historial();

create or replace function public.academia_estructura_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare s public.sesiones%rowtype; e public.plan_filas_estructura%rowtype; v_ver int := nullif(p->>'sesion_version','')::int;
begin
  select * into s from public.sesiones where id = nullif(p->>'sesion_id','')::uuid;
  if s.id is null then raise exception 'Esa sesión no existe.'; end if;
  if not public.academia_puede(s.grupo_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  -- Primera versión: solo con datos de prueba.
  if not exists (select 1 from public.academia_grupos where grupo_id = s.grupo_id and es_prueba) then
    raise exception 'De momento solo con el grupo de prueba.';
  end if;
  if v_ver is null or nullif(p->>'fila_id','') is null or jsonb_typeof(p->'estructura') <> 'object' then raise exception 'Faltan datos de la fila.'; end if;
  if coalesce(p->>'estado','revisada') not in ('revisada','manual') then raise exception 'Estado no válido.'; end if;
  select * into e from public.plan_filas_estructura where sesion_id = s.id and sesion_version = v_ver and fila_id = p->>'fila_id' for update;
  if e.id is null then
    insert into public.plan_filas_estructura (grupo_id, sesion_id, sesion_version, fila_id, huella, estructura, estado, nota)
    values (s.grupo_id, s.id, v_ver, p->>'fila_id', coalesce(p->>'huella',''), p->'estructura', coalesce(p->>'estado','revisada'), nullif(btrim(coalesce(p->>'nota','')),''))
    returning * into e;
  else
    if nullif(p->>'version_base','')::int is distinct from e.version then
      return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado la lectura de esta fila: vuelve a abrirla. No se ha pisado nada.');
    end if;
    update public.plan_filas_estructura set huella = coalesce(p->>'huella', huella), estructura = p->'estructura', estado = coalesce(p->>'estado','revisada'),
           nota = nullif(btrim(coalesce(p->>'nota','')),'')
     where id = e.id returning * into e;
  end if;
  return jsonb_build_object('ok', true, 'estructura', to_jsonb(e));
end $$;

-- Plazo del feedback del grupo (día de margen y hora límite).
create or replace function public.academia_plazo_guardar(p_grupo uuid, p_hora time, p_dias int) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.academia_puede(p_grupo) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if p_hora is null or p_dias is null or p_dias < 0 or p_dias > 7 then raise exception 'Revisa la hora y los días (de 0 a 7).'; end if;
  update public.academia_grupos set feedback_hora_limite = p_hora, feedback_dias = p_dias where grupo_id = p_grupo;
  return jsonb_build_object('ok', true);
end $$;

alter table public.plan_filas_estructura enable row level security;
revoke all on public.plan_filas_estructura from public, anon, authenticated;
grant select on public.plan_filas_estructura to authenticated;
create policy "estructuras: Academia de su grupo" on public.plan_filas_estructura for select to authenticated using (public.academia_puede(grupo_id));
revoke execute on function public.academia_estructura_guardar(jsonb), public.academia_plazo_guardar(uuid, time, int) from public, anon;
grant execute on function public.academia_estructura_guardar(jsonb), public.academia_plazo_guardar(uuid, time, int) to authenticated;

commit;
