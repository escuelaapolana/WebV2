-- ============================================================
-- 078 · Récords y palmarés: el nombre de los menores, de verdad
-- ------------------------------------------------------------
-- La casilla «nombre_publico» de la 075 recorta el nombre DENTRO
-- de las vistas `records_club_publico` / `palmares_publico`, pero
-- las tablas base tenían una política `lectura publica USING(true)`
-- y anon podía leerlas EN CRUDO, saltándose la vista y la casilla.
--
-- Una auditoría hostil lo confirmó: como anónimo, `select atleta
-- from records_club` devuelve «Sergio Redondo del Río · Sub-18»,
-- un menor, con nombre y apellidos completos. En vivo, ahora mismo.
--
-- Arreglo: la web pública lee SOLO las vistas `*_publico` (que son
-- de postgres y recortan el nombre); las tablas base dejan de ser
-- legibles para el público. Solo administración las lee en crudo
-- (para editarlas). Así la protección no depende de una casilla
-- con valor por defecto, sino de que nadie de fuera toca la tabla.
-- Idempotente.
-- ============================================================

-- Fuera la lectura pública en crudo de las dos tablas.
drop policy if exists "lectura publica" on public.records_club;
drop policy if exists "lectura publica" on public.palmares;

-- Solo administración lee las tablas base (para el panel de edición).
-- La web pública NO las toca: usa las vistas `*_publico`, que son de
-- postgres y por eso siguen funcionando para cualquiera aunque anon
-- ya no tenga acceso a la tabla.
drop policy if exists "records base solo admin" on public.records_club;
create policy "records base solo admin" on public.records_club
  for select to authenticated using (public.es_admin());

drop policy if exists "palmares base solo admin" on public.palmares;
create policy "palmares base solo admin" on public.palmares
  for select to authenticated using (public.es_admin());

-- Y por si el GRANT de SELECT a anon fuera la vía: se retira de las
-- tablas base (las vistas no lo necesitan, corren como postgres).
revoke select on public.records_club from anon;
revoke select on public.palmares     from anon;
