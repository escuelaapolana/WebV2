-- 277 · Natación: marcar qué franjas admiten MÁSTER para recuperar.
-- Mario (2-oct-2026): el lunes 19:30 (Perfeccionamiento) es solo para
-- avanzados de la escuela, NO para adultos. En general, la recuperación
-- del máster solo debe ofrecer franjas de máster, nunca las de «Escuela».
--
-- Antes, natacion_master_disponibles ofrecía CUALQUIER franja activa del día
-- con calle libre, así que colaba sesiones de escuela/perfeccionamiento.
-- Ahora cada franja lleva un flag admite_master y la función lo respeta.

alter table public.natacion_franjas
  add column if not exists admite_master boolean not null default true;

-- Backfill por el nombre del grupo: admite máster solo si lo dice el grupo
-- (Máster, Escuela + Máster, Perfeccionamiento / Máster). Las de «Escuela» y
-- «Perfeccionamiento» (a secas) quedan en false.
update public.natacion_franjas
set admite_master = (grupo ilike '%máster%' or grupo ilike '%master%');

-- La función de sesiones disponibles para recuperar: solo franjas de máster.
create or replace function public.natacion_master_disponibles(p_fecha date)
 returns table(franja_id uuid, hora time without time zone, grupo text, calle text, huecos integer)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare v_calle int;
begin
  select calle_num into v_calle from public.natacion_master_yo();
  if v_calle is null then return; end if;
  return query
  select f.id, f.hora, f.grupo, hc.calle, hc.huecos
  from public.natacion_franjas f
  join lateral (
    select h.calle, h.huecos
    from public.natacion_huecos_calle(f.id, p_fecha) h
    where public._num_calle(h.calle) <= v_calle and h.huecos > 0
    order by public._num_calle(h.calle) desc   -- la más alta a la que llega
    limit 1
  ) hc on true
  where coalesce(f.activa, true)
    and f.admite_master
    and f.dia = extract(isodow from p_fecha)::smallint
  order by f.hora;
end $function$;
