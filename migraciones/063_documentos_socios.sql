-- ============================================================
-- 063 · Cubo privado para los documentos reservados a socios
-- ------------------------------------------------------------
-- En el panel se elige si un documento es público o «solo
-- socios», pero el archivo se subía SIEMPRE al cubo `imagenes`,
-- que es público, y se guardaba su enlace permanente. La
-- etiqueta «solo socios» solo escondía la fila del listado: el
-- archivo lo descargaba cualquiera que tuviese el enlace.
--
-- Hoy no hay daño (los tres documentos que existen son públicos
-- de verdad), pero el día que se suba un acta o un listado de
-- socios quedaría colgado en Internet para siempre, porque los
-- enlaces de Supabase no caducan.
--
-- Aquí se crea el cubo privado. El cambio en las pantallas va
-- aparte: subir ahí cuando la visibilidad sea «socios» y generar
-- un enlace temporal en el momento de descargarlo.
-- Idempotente.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('documentos-socios', 'documentos-socios', false)
on conflict (id) do update set public = false;

-- Lo lee cualquiera que tenga cuenta del club; sin cuenta, nada
drop policy if exists "Documentos de socios: lectura con cuenta" on storage.objects;
create policy "Documentos de socios: lectura con cuenta"
  on storage.objects for select to authenticated
  using (bucket_id = 'documentos-socios');

-- Los sube, cambia y quita solo administración
drop policy if exists "Documentos de socios: los gestiona admin" on storage.objects;
create policy "Documentos de socios: los gestiona admin"
  on storage.objects for all to authenticated
  using      (bucket_id = 'documentos-socios' and public.es_admin())
  with check (bucket_id = 'documentos-socios' and public.es_admin());
