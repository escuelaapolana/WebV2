-- 452 · Competiciones de natación: el admin de verdad entra aunque vaya con otra vista
-- (como el mundo General, mig 447: es_admin() mira rol_activo).
begin;
create or replace function public.natacion_comp_puede()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select public.natacion_cuotas_puede() or public.soy_admin_de_verdad()
      or exists (select 1 from public.natacion_comp_acceso a where a.perfil_id = public.mi_perfil_id());
$$;
commit;
