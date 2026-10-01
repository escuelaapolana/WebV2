-- 265 · Al cambiar de grupo, el atleta HEREDA el entrenador del grupo.
-- `mis_atletas()` decide quién ve a quién por `entrenador_id`, NO por el grupo.
-- Al mover a alguien de grupo se actualizaba `grupo_id` y `atleta_grupos`, pero
-- NO `entrenador_id` → el atleta se quedaba con el entrenador viejo y el del
-- grupo nuevo no lo veía (caso Bella Marshall: movida a Academia pero seguía
-- con el entrenador de Velocidad; Miguel Rua: en Academia y sin entrenador).
-- Se añade la sincronización del entrenador al disparador que ya pone `grupo_id`
-- desde el grupo principal, y se cuadran los que ya estaban desfasados.
-- Si el grupo no tiene entrenador asignado, NO se le quita el que tuviera (para
-- no dejar a nadie sin que lo vea nadie por un grupo aún sin entrenador).
begin;

create or replace function public.ficha_desde_atleta_grupos()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_ent uuid;
begin
  if tg_op = 'DELETE' then
    if not exists (select 1 from public.atletas a where a.id = old.atleta_id) then
      return old;
    end if;
    -- Al sacar del grupo que salía en la ficha, se pasa al más antiguo que le
    -- quede (o vacío), y el entrenador se cuadra con ESE grupo.
    update public.atletas a
       set grupo_id = ng.gid,
           entrenador_id = coalesce(
             (select g.entrenador_id from public.grupos g where g.id = ng.gid),
             a.entrenador_id)
      from (
        select (select ag.grupo_id
                  from public.atleta_grupos ag
                 where ag.atleta_id = old.atleta_id
                 order by ag.principal desc, ag.desde, ag.grupo_id
                 limit 1) as gid
      ) ng
     where a.id = old.atleta_id and a.grupo_id = old.grupo_id;
    return old;
  end if;

  -- Se ha marcado un principal: la ficha se pone a ese grupo Y a su entrenador.
  if new.principal then
    select g.entrenador_id into v_ent from public.grupos g where g.id = new.grupo_id;
    update public.atletas a
       set grupo_id = new.grupo_id,
           entrenador_id = coalesce(v_ent, a.entrenador_id)
     where a.id = new.atleta_id
       and (a.grupo_id is distinct from new.grupo_id
            or a.entrenador_id is distinct from coalesce(v_ent, a.entrenador_id));
  end if;

  return new;
end;
$function$;

-- Cuadrar los que ya estaban desfasados: entrenador = el del grupo principal
-- (solo si el grupo tiene entrenador). Hoy son 2: Bella Marshall y Miguel Rua.
update public.atletas a
   set entrenador_id = g.entrenador_id, updated_at = now()
  from public.grupos g
 where g.id = a.grupo_id
   and g.entrenador_id is not null
   and a.entrenador_id is distinct from g.entrenador_id;

commit;
