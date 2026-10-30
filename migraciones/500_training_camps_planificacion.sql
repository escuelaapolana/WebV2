-- ===========================================================================
-- 500 · Training Camps · tanda 2: disponibilidad por niveles, plan de
--       sesiones y ocupación externa (Concejalía), para AVISAR de coincidencias
-- ---------------------------------------------------------------------------
--   · Disponibilidad: sin revisar → aparente → pendiente de confirmar →
--     confirmada. «Confirmada» es la de siempre (disponibilidad_ok_en): con la
--     señal cobrada, confirma la reserva.
--   · camp_sesiones: el plan de cada concentración (día, horas, recurso, zona,
--     subgrupo, atletas). De aquí salen los avisos de coincidencia.
--   · camp_ocupacion_externa: lo que ocupa la instalación fuera de las
--     concentraciones. Pensada para el calendario de reservas de la
--     Concejalía, SIN CONECTAR: de momento se puede apuntar a mano; cuando se
--     integre, cada fila llevará su referencia (fuente + referencia_externa).
--   · camp_cubo_grupos(): horarios de los grupos del club en El Cubo con sus
--     inscritos, para sumar al aforo.
-- Los avisos NUNCA bloquean: dos grupos pueden compartir pista en zonas
-- distintas. Decide el club (y la Concejalía cuando corresponda).
-- ===========================================================================
begin;

-- 1 · Disponibilidad por niveles
alter table public.camp_solicitudes
  add column disponibilidad_estado text not null default 'sin_revisar'
    check (disponibilidad_estado in ('sin_revisar','aparente','pendiente','confirmada'));
update public.camp_solicitudes set disponibilidad_estado = 'confirmada' where disponibilidad_ok_en is not null;

create or replace function public.camp_disponibilidad_nivel(p_id uuid, p_nivel text, p_nota text default null) returns public.camp_solicitudes
language plpgsql security definer set search_path to 'public' as $$
declare s public.camp_solicitudes; v_txt text;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if p_nivel not in ('sin_revisar','aparente','pendiente','confirmada') then raise exception 'Nivel no válido.'; end if;
  update public.camp_solicitudes set
         disponibilidad_estado = p_nivel,
         disponibilidad_ok_en = case when p_nivel = 'confirmada' then coalesce(disponibilidad_ok_en, now()) end,
         disponibilidad_ok_por = case when p_nivel = 'confirmada' then coalesce(disponibilidad_ok_por, auth.uid()) end,
         disponibilidad_nota = nullif(btrim(coalesce(p_nota, '')), '')
   where id = p_id returning * into s;
  if s.id is null then raise exception 'Ese expediente no existe.'; end if;
  v_txt := case p_nivel when 'sin_revisar' then 'Disponibilidad: sin revisar' when 'aparente' then 'Disponibilidad APARENTE (sin coincidencias a la vista, sin confirmar)'
                        when 'pendiente' then 'Disponibilidad PENDIENTE DE CONFIRMAR (consultado al estadio / Concejalía)' else 'Disponibilidad CONFIRMADA' end;
  insert into public.camp_registro (solicitud_id, tipo, texto) values (s.id, 'sistema', v_txt || coalesce(' · ' || s.disponibilidad_nota, ''));
  if p_nivel = 'confirmada' then
    update public.camp_tareas set hecha_en = now(), hecha_por = auth.uid() where solicitud_id = s.id and auto = 'disponibilidad' and hecha_en is null;
    perform public.camp_revisar(s.id);
  end if;
  select * into s from public.camp_solicitudes where id = p_id;
  return s;
end $$;

-- La de la tanda 1 sigue valiendo (aprobar = confirmada; retirar = pendiente).
create or replace function public.camp_disponibilidad(p_id uuid, p_ok boolean, p_nota text default null) returns public.camp_solicitudes
language sql security definer set search_path to 'public' as $$
  select public.camp_disponibilidad_nivel(p_id, case when p_ok then 'confirmada' else 'pendiente' end, p_nota)
$$;

-- 2 · Plan de sesiones
create table public.camp_sesiones (
  id           uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.camp_solicitudes(id) on delete cascade,
  fecha        date not null,
  hora_inicio  time not null,
  hora_fin     time not null check (hora_fin > hora_inicio),
  recurso      text not null check (recurso in ('pista','cubo','playa','montana','otro')),
  zona         text,          -- p. ej. «rectas», «foso de longitud», «jaula»: dos grupos pueden compartir pista en zonas distintas
  subgrupo     text,
  n_atletas    int check (n_atletas between 0 and 1000),
  nota         text,
  origen       text not null default 'manual' check (origen in ('solicitud','manual')),
  creado_por   uuid default auth.uid(),
  creado_en    timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create index camp_sesiones_fecha on public.camp_sesiones (fecha);
create index camp_sesiones_solicitud on public.camp_sesiones (solicitud_id);

-- 3 · Ocupación externa (Concejalía): estructura sin conectar
create table public.camp_ocupacion_externa (
  id                 uuid primary key default gen_random_uuid(),
  fuente             text not null default 'concejalia' check (fuente in ('concejalia','club','otro')),
  fecha              date not null,
  hora_inicio        time not null,
  hora_fin           time not null check (hora_fin > hora_inicio),
  recurso            text not null default 'pista' check (recurso in ('pista','cubo','otro')),
  zona               text,
  titulo             text not null check (btrim(titulo) <> ''),
  detalle            text,
  referencia_externa text,          -- el id en el sistema de origen, cuando se conecte
  manual             boolean not null default true,
  importado_en       timestamptz,
  creado_por         uuid default auth.uid(),
  creado_en          timestamptz not null default now()
);
create index camp_ocupacion_externa_fecha on public.camp_ocupacion_externa (fecha);
create unique index camp_ocupacion_externa_ref on public.camp_ocupacion_externa (fuente, referencia_externa) where referencia_externa is not null;
comment on table public.camp_ocupacion_externa is 'Ocupación de la instalación ajena a las concentraciones (reservas de la Concejalía…). Sin conectar todavía: filas a mano. Solo sirve para avisar, nunca bloquea.';

-- 4 · Grupos del club en El Cubo (horario + inscritos), para el aforo
create or replace function public.camp_cubo_grupos() returns table (grupo text, dia_semana smallint, hora_inicio time, hora_fin time, inscritos int)
language sql stable security definer set search_path to 'public' as $$
  select g.nombre, h.dia_semana, h.hora_inicio, coalesce(h.hora_fin, h.hora_inicio + interval '1 hour')::time,
         (select count(*) from public.atleta_grupos ag where ag.grupo_id = g.id)::int
    from public.grupo_horarios h join public.grupos g on g.id = h.grupo_id
   where public.es_admin() and g.seccion = 'cubo' and h.activo
   order by h.dia_semana, h.hora_inicio
$$;

-- Permisos
alter table public.camp_sesiones enable row level security;
alter table public.camp_ocupacion_externa enable row level security;
revoke all on public.camp_sesiones, public.camp_ocupacion_externa from public, anon, authenticated;
grant select, insert, update, delete on public.camp_sesiones, public.camp_ocupacion_externa to authenticated;
create policy "camp: admin" on public.camp_sesiones for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy "camp: admin" on public.camp_ocupacion_externa for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
revoke execute on function public.camp_disponibilidad_nivel(uuid, text, text), public.camp_cubo_grupos() from public, anon;
grant execute on function public.camp_disponibilidad_nivel(uuid, text, text), public.camp_cubo_grupos() to authenticated;

commit;
