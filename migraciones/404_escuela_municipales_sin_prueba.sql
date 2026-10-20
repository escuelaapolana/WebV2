-- 404 · Andrés (20-oct-2026): «los de escuela municipal son directamente altas».
-- Los municipales que la 401 creó «de prueba» (sin verde en BUENA ISA) pasan a activos.
begin;
update public.atletas set estado = 'activo'
 where tipo_membresia = 'municipal' and estado = 'prueba' and origen = 'cuadre-municipal-2026-10-20';
commit;
