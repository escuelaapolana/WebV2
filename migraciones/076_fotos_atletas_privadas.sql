-- ============================================================
-- 076 · Las fotos de atletas, fuera de la lectura pública (otra vez)
-- ------------------------------------------------------------
-- La migración 061 ya sacó `fotos-atletas` de la política de
-- lectura pública, pero ha vuelto a colarse en algún momento
-- posterior. Una auditoría hostil lo ha detectado: la política
-- «Lectura publica imagenes» vuelve a incluir `fotos-atletas`,
-- así que la primera foto de un menor que suba Secretaría
-- quedaría legible desde Internet con la clave pública del
-- frontend.
--
-- Hoy el cubo está vacío (0 objetos), así que no hay exposición
-- real todavía, pero es exactamente el escenario que no puede
-- pasar en un club con menores. Se cierra de forma definitiva y
-- con un comentario para que no vuelva a reaparecer.
--
-- El acceso legítimo (solo el equipo técnico) ya lo dan dos
-- políticas aparte con es_staff(); esas no se tocan.
-- Idempotente.
-- ============================================================

drop policy if exists "Lectura publica imagenes" on storage.objects;
create policy "Lectura publica imagenes"
  on storage.objects for select to public
  using (bucket_id in ('imagenes-club', 'productos-tienda',
                       'Imagenes-club', 'Productos-tienda'));
-- OJO: `fotos-atletas` NO va en esta lista. Nunca. Son menores.
