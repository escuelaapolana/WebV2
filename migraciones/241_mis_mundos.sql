-- 241_mis_mundos.sql
-- Acceso por «mundos»: qué mundos ve/entra cada persona (para el conmutador
-- de la barra lateral, assets/js/mundos.js).
--   · admin          -> todos los mundos (el «mundo superior»).
--   · el resto        -> los mundos de sus secciones de responsable
--                        (responsable_seccion, vía mis_secciones_responsable()).
-- La junta NO ve todos por serlo: quien deba verlo todo, se pone admin; y a
-- cada responsable se le dan sus secciones. Devuelve las CLAVES de mundo que
-- usa el front (natacion, escuela-nat, cubo…).

create or replace function public.mis_mundos()
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.es_admin()
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
$$;

grant execute on function public.mis_mundos() to authenticated, service_role;
