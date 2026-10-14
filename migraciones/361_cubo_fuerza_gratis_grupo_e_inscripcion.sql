-- 361 · Fuerza gratis: grupo e inscripción siempre a la par
-- ---------------------------------------------------------------------------
-- La Fuerza gratis vive en DOS sitios: la inscripción (`cubo_prueba.turnos`,
-- de ahí salen la lista de Claudia y los apuntados del calendario) y los
-- grupos «El Cubo · Fuerza gratis · Viernes/Sábado/Domingo» (`atleta_grupos`).
-- Andrés quitó a Roberto del grupo del sábado desde Personas y seguía saliendo
-- el sábado (14-oct). Ahora se mantienen solos:
--   · Sacar a alguien de un grupo de Fuerza gratis → se le quita ese día de la
--     inscripción; si se queda sin días, la inscripción pasa a «cancelado».
--   · «Cancelar» en El Cubo › Fuerza gratis → sale de esos grupos.
--   · «Deshacer» (vuelve a «apuntado») → vuelve a entrar en sus grupos.
-- Un guardia (pg_trigger_depth) evita que un disparador despierte al otro.
-- ---------------------------------------------------------------------------
begin;

-- Día de la semana ('viernes'|'sabado'|'domingo') de un grupo de Fuerza gratis; NULL si no lo es.
create or replace function public._fuerza_gratis_dia(p_grupo uuid)
returns text language sql stable set search_path to 'public' as $$
  select case
           when lower(g.nombre) like '%viernes%' then 'viernes'
           when lower(translate(g.nombre, 'áÁ', 'aA')) like '%sabado%' then 'sabado'
           when lower(g.nombre) like '%domingo%' then 'domingo'
         end
    from public.grupos g
   where g.id = p_grupo and g.seccion = 'cubo' and g.nombre ilike 'El Cubo · Fuerza gratis%';
$$;

-- 1) Sale del grupo → fuera ese día de la inscripción
create or replace function public.trg_fuerza_gratis_sale_del_grupo()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_dia text;
begin
  if pg_trigger_depth() > 1 then return old; end if;
  v_dia := public._fuerza_gratis_dia(old.grupo_id);
  if v_dia is null then return old; end if;
  update public.cubo_prueba p
     set turnos = array_remove(p.turnos, v_dia),
         estado = case when array_remove(p.turnos, v_dia) = '{}'::text[] then 'cancelado' else p.estado end
   where p.atleta_id = old.atleta_id and p.estado <> 'cancelado' and v_dia = any(p.turnos);
  return old;
end $$;

drop trigger if exists trg_fuerza_gratis_sale_del_grupo on public.atleta_grupos;
create trigger trg_fuerza_gratis_sale_del_grupo
  after delete on public.atleta_grupos
  for each row execute function public.trg_fuerza_gratis_sale_del_grupo();

-- 2) Cancelar / deshacer en la inscripción → grupos a la par
create or replace function public.trg_fuerza_gratis_inscripcion_estado()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if pg_trigger_depth() > 1 or new.atleta_id is null or new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado = 'cancelado' then
    delete from public.atleta_grupos ag
     where ag.atleta_id = new.atleta_id
       and public._fuerza_gratis_dia(ag.grupo_id) = any(new.turnos);
  elsif old.estado = 'cancelado' then
    insert into public.atleta_grupos (atleta_id, grupo_id, principal)
    select new.atleta_id, g.id, false
      from public.grupos g
     where g.seccion = 'cubo' and g.nombre ilike 'El Cubo · Fuerza gratis%'
       and public._fuerza_gratis_dia(g.id) = any(new.turnos)
    on conflict do nothing;
  end if;
  return new;
end $$;

drop trigger if exists trg_fuerza_gratis_inscripcion_estado on public.cubo_prueba;
create trigger trg_fuerza_gratis_inscripcion_estado
  after update of estado on public.cubo_prueba
  for each row execute function public.trg_fuerza_gratis_inscripcion_estado();

commit;
