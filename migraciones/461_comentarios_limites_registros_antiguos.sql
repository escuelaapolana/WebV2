-- 461 · Límites de los registros antiguos, escritos EN la base (solo comentarios)
-- ---------------------------------------------------------------------------
-- Para que cualquier análisis futuro (panel, informes, un asistente) lea en el
-- propio esquema que los registros anteriores al historial NO son exactos.
-- Detalle en docs/historial-entrenos.md.
-- ---------------------------------------------------------------------------
begin;
comment on column public.registros_sesion.sesion_version_id is
  'Versión de la sesión a la que responde este registro (migs 458/460). Solo es fiable si version_garantia = ''exacta''.';
comment on column public.registros_sesion.version_garantia is
  'exacta = la versión que el atleta tenía en pantalla (app desde 28-oct-2026). vigente_al_enviar = la app no dijo qué versión vio; se ata a la vigente al enviar. sin_garantia = registro anterior al historial (31-ago a 27-oct-2026): enlazado al estado de la sesión el 28-oct, que puede no ser lo que vio. sobrescrita = anterior al historial y con pruebas de que la sesión cambió después: el plan respondido se perdió. NO tratar sin_garantia/sobrescrita como plan exacto.';
comment on column public.registros_sesion.version_nota is
  'Explicación legible de version_garantia (y de las correcciones anteriores al historial, cuyos valores previos no se guardaron).';
comment on column public.registros_sesion.corregido_veces is
  'Nº de correcciones. Desde el 28-oct-2026 los valores anteriores están en registros_sesion_versiones; antes, solo existe este contador.';
comment on column public.registros_sesion.tiempos_reales is
  'Lo apuntado por fila: clave = id de la fila del plan (bloques[].filas[].id) de la versión respondida. Registros antiguos pueden usar claves de bloque (p. ej. cc, mov, tec) que no casan con filas concretas.';
comment on table public.sesiones_versiones is
  'Historial inmutable de cada sesión (mig 458). La versión «inicial» es el estado al activar el historial (28-oct-2026); lo anterior no se guardó.';
comment on table public.registros_sesion_versiones is
  'Valores ANTERIORES de cada corrección o borrado de un registro (mig 458). Solo desde el 28-oct-2026.';
commit;
