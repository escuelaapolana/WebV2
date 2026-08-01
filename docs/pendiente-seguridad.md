# Pendiente de seguridad (para la ronda de arreglos)

Se corrige TODO junto cuando terminen las dos auditorías de ataque
(`docs/auditoria-seguridad.md` y `docs/auditoria-seguridad-anonimo.md`).

## Ya arreglado
- Escalada de privilegios: un atleta podía hacerse admin (`update perfiles set rol='admin'`).
  Tapado con el trigger `trg_perfiles_protege_rol`. Verificado.
- Buckets de Storage: todos privados salvo `imagenes` (contenido público).
- GitHub Pages: `_config.yml` excluye migraciones/, docs/, herramientas/, maquetas/.

## Pendiente
- **Documentos "solo socios" en bucket público.** Hoy no hay ninguno (0 archivos en
  imagenes/documentos/), así que no hay fuga real todavía. PERO `/admin/documentos/`
  sube al bucket PÚBLICO `imagenes`, así que un documento con visibilidad='socios'
  sería descargable por su URL directa saltándose la RLS de la fila.
  ARREGLO: subir los de visibilidad 'socios' a un bucket PRIVADO y servirlos con
  URL firmada (signed URL) temporal desde el portal. Hacerlo ANTES de subir ningún
  documento privado real.
- Revisar el resto de hallazgos de las dos auditorías cuando estén.
