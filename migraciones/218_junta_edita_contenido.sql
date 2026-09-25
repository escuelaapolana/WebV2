-- 218 · La junta edita CONTENIDO (calendario, noticias y ediciones de Liga)
--
-- El papel 'junta' ("el club, sin el dinero") ya entra al panel y ya gestiona la
-- Liga del día a día (por es_staff). Le faltaba poder escribir el CALENDARIO
-- (tabla eventos), las NOTICIAS y las EDICIONES de Liga, que exigían admin. Se
-- añaden políticas para que 'junta' (además de admin) pueda gestionarlas.
-- NO abre nada de dinero ni de personas: esas siguen en es_admin()/ve_dinero().

-- Calendario
drop policy if exists "junta gestiona eventos" on public.eventos;
create policy "junta gestiona eventos" on public.eventos
  for all to authenticated using (public.es_junta()) with check (public.es_junta());

-- Noticias
drop policy if exists "junta gestiona noticias" on public.noticias;
create policy "junta gestiona noticias" on public.noticias
  for all to authenticated using (public.es_junta()) with check (public.es_junta());

-- Ediciones de Liga (el resto de tablas liga_* ya las abre es_staff)
drop policy if exists "junta gestiona ediciones de liga" on public.liga_ediciones;
create policy "junta gestiona ediciones de liga" on public.liga_ediciones
  for all to authenticated using (public.es_junta()) with check (public.es_junta());
