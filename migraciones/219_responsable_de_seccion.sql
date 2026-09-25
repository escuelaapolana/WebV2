-- 219 · Responsable de sección: editar los HORARIOS de su sección sin ser admin
--
-- Una persona (con papel 'junta') puede ser "responsable" de una o varias
-- secciones y editar SOLO los horarios de los grupos de esas secciones. No es
-- admin: no ve dinero ni personas, y no toca otras secciones. Primer caso: Mario
-- responsable de 'natacion' y 'escuela-natacion'.
--
-- (La edición EN VIVO de las páginas web —textos/fotos— se trata aparte: hoy el
--  editor solo se activa para admin en el navegador; eso es un cambio de front.)

create table if not exists public.responsable_seccion (
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  seccion   text not null,
  primary key (perfil_id, seccion)
);
alter table public.responsable_seccion enable row level security;

-- Solo administración reparte responsabilidades.
drop policy if exists "responsables los lleva el admin" on public.responsable_seccion;
create policy "responsables los lleva el admin" on public.responsable_seccion for all to authenticated
  using (public.es_admin()) with check (public.es_admin());
-- Cada quien puede LEER de qué es responsable (para que el panel lo sepa).
drop policy if exists "veo mis responsabilidades" on public.responsable_seccion;
create policy "veo mis responsabilidades" on public.responsable_seccion for select to authenticated
  using (perfil_id = public.mi_perfil_id());

grant select, insert, update, delete on public.responsable_seccion to authenticated;

-- ¿La persona logueada es responsable de esta sección?
create or replace function public.soy_responsable(p_seccion text)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1
    from public.responsable_seccion rs
    join public.perfiles p on p.id = rs.perfil_id
    where p.email = (auth.jwt() ->> 'email')
      and coalesce(p.activo, true)
      and rs.seccion = p_seccion
  );
$$;
revoke all on function public.soy_responsable(text) from public, anon;
grant execute on function public.soy_responsable(text) to authenticated;

-- HORARIOS: el responsable edita los horarios de los grupos de SU sección.
drop policy if exists "responsable gestiona horarios de su seccion" on public.grupo_horarios;
create policy "responsable gestiona horarios de su seccion" on public.grupo_horarios for all to authenticated
  using (exists (
    select 1 from public.grupos g
    where g.id = grupo_horarios.grupo_id and public.soy_responsable(g.seccion)
  ))
  with check (exists (
    select 1 from public.grupos g
    where g.id = grupo_horarios.grupo_id and public.soy_responsable(g.seccion)
  ));
