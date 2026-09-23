-- 213 · Aforo público de la prueba gratis del Cubo
-- El formulario es público (sin sesión) y necesita saber cuántas plazas quedan
-- en cada turno para marcar «Completo». La tabla cubo_prueba es privada (RLS),
-- así que se expone SOLO el recuento por turno (no datos de nadie) con una
-- función SECURITY DEFINER que puede llamar cualquiera.
create or replace function public.cubo_prueba_aforo()
returns table(turno text, ocupadas integer, plazas integer)
language sql security definer set search_path to 'public' stable as $$
  select t.turno,
         coalesce(count(p.id), 0)::int as ocupadas,
         20 as plazas
  from (values ('viernes'), ('sabado'), ('domingo')) as t(turno)
  left join public.cubo_prueba p
    on p.estado <> 'cancelado' and t.turno = any(p.turnos)
  group by t.turno;
$$;
grant execute on function public.cubo_prueba_aforo() to anon, authenticated;
