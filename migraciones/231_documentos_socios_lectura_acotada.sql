-- 231 · BAJO · El bucket privado documentos-socios lo podía leer CUALQUIER
-- cuenta (policy USING(bucket_id='documentos-socios')), saltándose la RLS de la
-- tabla documentos: un usuario que supiera/adivinara una ruta podía pedir una
-- signed URL de cualquier fichero. Se acota: solo se puede leer un objeto si
-- existe una fila `documentos` que apunte a él Y el usuario tiene derecho a verla
-- (mismo criterio que la RLS de documentos: público/socios, o su grupo).
-- (admin sigue con acceso total por su policy ALL; entrenador por la suya.)

drop policy if exists "Documentos de socios: lectura con cuenta" on storage.objects;
create policy "Documentos de socios: lectura con cuenta" on storage.objects for select to authenticated
using (
  bucket_id = 'documentos-socios'
  and exists (
    select 1 from public.documentos d
    where d.activo
      and d.archivo_url = storage.objects.name
      and (
        d.visibilidad in ('publico', 'socios')
        or (d.visibilidad = 'grupo' and (
              d.grupo_id in (select public.mis_grupos_de_entreno())
           or d.grupo_id in (select public.mis_grupos_de_familia())
           or exists (select 1 from public.grupos g where g.id = d.grupo_id and g.entrenador_id = public.mi_perfil_id())
        ))
      )
  )
);
