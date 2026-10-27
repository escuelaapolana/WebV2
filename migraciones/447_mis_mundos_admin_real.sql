-- 447 · El admin de verdad ve SIEMPRE el mundo General en la barra
-- ---------------------------------------------------------------------------
-- Andrés (27-oct-2026): «desde Comunicación no veo el mundo General». Su cuenta
-- iba con la vista «Atleta» (rol_activo = atleta). es_admin() mira rol_activo,
-- así que mis_mundos() le devolvía solo los mundos de responsable (los 7 sin
-- General). Ahora, quien es admin de verdad (soy_admin_de_verdad, mig 421:
-- tiene el papel admin aunque vaya con otra vista) recibe todos los mundos.
-- Al ir a General con otra vista, la barra (assets/js/mundos.js) le devuelve
-- antes a la vista de admin, porque los datos de General los protege es_admin.
-- ---------------------------------------------------------------------------
begin;

CREATE OR REPLACE FUNCTION public.mis_mundos()
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case
    when public.es_admin() or public.soy_admin_de_verdad()
      then array['general','natacion','escuela-nat','cubo','pista','escuela-atl','running','comunicacion']
    else coalesce((
      select array_agg(distinct w order by w)
      from (
        select case sec
          when 'natacion'          then 'natacion'
          when 'escuela-natacion'  then 'escuela-nat'
          when 'cubo'              then 'cubo'
          when 'pista'             then 'pista'
          when 'competicion'       then 'pista'
          when 'escuela'           then 'escuela-atl'
          when 'escuela-atletismo' then 'escuela-atl'
          when 'running'           then 'running'
          when 'comunicacion'      then 'comunicacion'
          else null
        end as w
        from public.mis_secciones_responsable() as sec
      ) m
      where w is not null
    ), '{}'::text[])
  end
$function$;

commit;
