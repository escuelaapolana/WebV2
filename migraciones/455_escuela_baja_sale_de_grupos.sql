-- 455 · Escuela: quien pasa a BAJA sale solo de sus grupos de la escuela
-- ---------------------------------------------------------------------------
-- Andrés (27-oct-2026): «automatiza que se vaya actualizando al igual que los
-- nuevos». La sincronización con BUENO ISA y el botón «Dar de baja» de
-- admin/escuela-grupos ya sacaban al niño de sus grupos, pero cada uno por su
-- cuenta: si la baja entraba por otro sitio (la ficha, a mano…) el niño se
-- quedaba apuntado. Pasó con Inés Martín, Blanca Escolano y Aleksandr Gubenkov
-- (de baja desde el 23-oct y todavía en Azul 2, Azul 1 y Recreativo).
--   · Ahora lo hace la base: al pasar la ficha a 'baja', fuera de los grupos de
--     sección 'escuela' (los de otras secciones no se tocan). Al borrar la fila,
--     ficha_desde_atleta_grupos ya cuadra grupo_id y entrenador de la ficha.
--   · «Deshacer» del panel sigue valiendo: guarda los grupos ANTES de la baja y
--     al deshacer primero devuelve el estado y luego los vuelve a meter.
--   · Se arreglan los 3 que se habían quedado.
-- ---------------------------------------------------------------------------
begin;

create or replace function public.atletas_baja_sale_de_grupos()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  -- security definer: quien da la baja puede tocar la ficha pero quizá no las
  -- filas de grupos (RLS); el borrado se limita a ESTE niño y a la escuela.
  delete from public.atleta_grupos ag
   using public.grupos g
   where ag.atleta_id = new.id
     and g.id = ag.grupo_id
     and g.seccion = 'escuela';
  return null;
end $function$;

drop trigger if exists trg_atletas_baja_sale_de_grupos on public.atletas;
create trigger trg_atletas_baja_sale_de_grupos
  after update of estado on public.atletas
  for each row
  when (new.estado = 'baja' and old.estado is distinct from 'baja')
  execute function public.atletas_baja_sale_de_grupos();

-- Los que ya estaban de baja y seguían en un grupo de la escuela.
delete from public.atleta_grupos ag
 using public.grupos g, public.atletas a
 where g.id = ag.grupo_id and g.seccion = 'escuela'
   and a.id = ag.atleta_id and a.estado = 'baja';

commit;
