-- 253 · «Dar un mundo» añade solo el papel 'responsable' (y quitarlo lo retira)
-- ---------------------------------------------------------------------------
-- La página «Acceso a los mundos» inserta/borra en responsable_seccion, pero
-- NO tocaba los roles del perfil. Sin 'responsable' en los roles, el conmutador
-- de vistas no ofrece «Responsable» y la persona no puede entrar a su mundo
-- (caso José Luis). Aquí se sincroniza SOLO con un trigger: cuando alguien tiene
-- alguna sección como responsable, sus roles incluyen 'responsable'; cuando se
-- queda sin ninguna, se le quita (y se limpia su vista de entrada si era esa).
-- Vale para la página, para psql y para cualquier futuro. Ver [[mundos-responsable-engancha]].
-- ---------------------------------------------------------------------------
begin;

create or replace function public.rs_sincroniza_papel_responsable()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare v_perfil uuid;
begin
  v_perfil := coalesce(NEW.perfil_id, OLD.perfil_id);
  if v_perfil is null then return null; end if;

  if exists (select 1 from public.responsable_seccion where perfil_id = v_perfil) then
    -- Tiene al menos un mundo → asegurar 'responsable' en sus roles.
    update public.perfiles
       set roles = (select array_agg(distinct r) from unnest(coalesce(roles, array[rol]) || array['responsable']) r)
     where id = v_perfil and not ('responsable' = any (coalesce(roles, '{}')));
  else
    -- Se quedó sin mundos → quitar 'responsable' y limpiar la vista de entrada.
    update public.perfiles
       set roles = (select coalesce(array_agg(r), '{}') from unnest(coalesce(roles, '{}')) r where r <> 'responsable'),
           papel_al_entrar = nullif(papel_al_entrar, 'responsable'),
           rol_activo      = nullif(rol_activo, 'responsable')
     where id = v_perfil and 'responsable' = any (coalesce(roles, '{}'));
  end if;
  return null;
end $$;

drop trigger if exists trg_rs_papel_responsable on public.responsable_seccion;
create trigger trg_rs_papel_responsable
  after insert or delete on public.responsable_seccion
  for each row execute function public.rs_sincroniza_papel_responsable();

-- Sincronización de una vez para los que YA tienen mundos pero les falta el papel.
update public.perfiles p
   set roles = (select array_agg(distinct r) from unnest(coalesce(p.roles, array[p.rol]) || array['responsable']) r)
 where exists (select 1 from public.responsable_seccion rs where rs.perfil_id = p.id)
   and not ('responsable' = any (coalesce(p.roles, '{}')));

commit;
