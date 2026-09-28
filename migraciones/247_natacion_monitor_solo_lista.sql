-- 247 · Monitores de natación: leen y pasan lista, pero NO cambian nada
-- ---------------------------------------------------------------------------
-- Leo y Lorena son monitores: tienen que ver sus franjas y PASAR LISTA, pero
-- NO tocar franjas, cupos, abonos, reservas ni mover nadadores (eso lo llevan
-- Mario/admin). Hoy todos los responsables tienen «ALL» sobre las tablas de
-- natación, así que también editan. Se separa:
--   · LEER franjas/inscripciones/accesos → cualquier responsable (incl. monitor)
--   · PASAR LISTA (ausencias) → cualquier responsable (incl. monitor)
--   · CAMBIAR (franjas, cupos, inscripciones, abonos, reservas) → solo GESTOR
-- Un «gestor» es un responsable con responsable_seccion.gestor = true (Mario y
-- los de siempre), o admin/staff. Los monitores llevan gestor = false.
-- ---------------------------------------------------------------------------
begin;

-- 1) Marca de gestor (por defecto sí, para no quitar permiso a nadie de antes)
alter table public.responsable_seccion add column if not exists gestor boolean not null default true;

-- Leo, Lorena y el entrenador de prueba: monitores (no gestores)
update public.responsable_seccion set gestor = false
 where perfil_id in (
   select id from public.perfiles
    where lower(email) in ('guevaralagaticleo@gmail.com','lalorelay2017@gmail.com','prueba.entrenador@apolana.club')
 );

-- 2) ¿Soy gestor de natación? (admin/staff, o responsable con gestor=true)
create or replace function public.soy_gestor_natacion()
returns boolean language sql stable security definer set search_path = 'public' as $$
  select public.es_admin() or public.es_staff() or exists (
    select 1 from public.responsable_seccion rs
    join public.perfiles p on p.id = rs.perfil_id
    where p.email = (auth.jwt() ->> 'email') and coalesce(p.activo, true)
      and rs.seccion in ('natacion','escuela-natacion') and coalesce(rs.gestor, true)
  );
$$;
revoke all on function public.soy_gestor_natacion() from public, anon;
grant execute on function public.soy_gestor_natacion() to authenticated;

-- 3) franjas / inscripciones / accesos: LEER responsable, CAMBIAR solo gestor.
--    La política «ALL» pasa a exigir gestor (cubre escritura); se añade una de
--    SELECT abierta a responsable para que el monitor pueda ver y pasar lista.
do $$
declare t text;
begin
  foreach t in array array['natacion_franjas','natacion_inscripciones','natacion_accesos']
  loop
    execute format('drop policy if exists %I on public.%I', 'natacion '||replace(t,'natacion_','')||' staff', t);
    execute format($f$create policy "nat %1$s escribir gestor" on public.%2$I
                     for all to authenticated
                     using (public.soy_gestor_natacion())
                     with check (public.soy_gestor_natacion())$f$, replace(t,'natacion_',''), t);
    execute format($f$create policy "nat %1$s leer responsable" on public.%2$I
                     for select to authenticated
                     using (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))$f$,
                     replace(t,'natacion_',''), t);
  end loop;
end $$;

-- 4) abonos / reservas: solo gestor (los monitores no los tocan ni ven; el
--    autoservicio del nadador irá por funciones security-definer aparte).
drop policy if exists "abonos los lleva natacion" on public.natacion_abonos;
create policy "abonos los lleva gestor" on public.natacion_abonos
  for all to authenticated using (public.soy_gestor_natacion()) with check (public.soy_gestor_natacion());

drop policy if exists "reservas las lleva natacion" on public.natacion_reservas;
create policy "reservas las lleva gestor" on public.natacion_reservas
  for all to authenticated using (public.soy_gestor_natacion()) with check (public.soy_gestor_natacion());

-- 5) ausencias (pasar lista): SIN cambios — cualquier responsable (incl. monitor)
--    puede marcar/quitar. La política «natacion ausencias staff» se mantiene.

commit;
