-- 217 · Asistencia de la PRUEBA GRATIS del Cubo (fuerza gratis de octubre)
--
-- Los apuntados a la prueba gratis (tabla cubo_prueba) NO son atletas ni tienen
-- cuenta en la app: son solo una lista. Pero Claudia (rol cubo-lista) necesita
-- poder pasar lista de quién viene a cada turno gratuito. Como no hay atleta_id,
-- la asistencia normal (tabla `asistencia`, indexada por atleta_id + grupo_id)
-- no sirve. Esta tabla registra la asistencia por PERSONA DE LA PRUEBA
-- (prueba_id) + turno + fecha. No crea atletas ni da acceso a nadie a la app.
create table if not exists public.cubo_prueba_asistencia (
  prueba_id      uuid not null references public.cubo_prueba(id) on delete cascade,
  turno          text not null,               -- 'viernes' | 'sabado' | 'domingo'
  fecha          date not null,
  presente       boolean not null default true,
  registrado_por uuid,                        -- perfil que marcó (Claudia o admin)
  created_at     timestamptz not null default now(),
  primary key (prueba_id, turno, fecha)
);

alter table public.cubo_prueba_asistencia enable row level security;

-- Solo el admin y quien pasa lista del Cubo (Claudia) leen y marcan. Igual que
-- la puerta de la propia tabla cubo_prueba (migración 212).
drop policy if exists cubo_prueba_asis_gestion on public.cubo_prueba_asistencia;
create policy cubo_prueba_asis_gestion on public.cubo_prueba_asistencia for all to authenticated
  using      (public.es_admin() or public.es_cubo_lista())
  with check (public.es_admin() or public.es_cubo_lista());

grant select, insert, update, delete on public.cubo_prueba_asistencia to authenticated;
