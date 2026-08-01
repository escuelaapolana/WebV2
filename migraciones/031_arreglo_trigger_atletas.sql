-- El límite de "solo el entrenador puede cambiar ciertos campos" debe aplicarse
-- SOLO a usuarios del portal. Sin sesión (mantenimiento directo de la base o
-- procesos del club) no debe bloquear nada. La seguridad de verdad la da RLS,
-- que ya impide a un anónimo tocar la tabla.
create or replace function public.atletas_cambios_del_entrenador()
returns trigger language plpgsql security definer set search_path to 'public' as $fn$
declare
  permitidas text[] := array['grupo_id','estado','fecha_prueba_fin','observaciones','contexto_entrenador','updated_at'];
  viejo jsonb := to_jsonb(old);
  nuevo jsonb := to_jsonb(new);
  c text;
begin
  new.updated_at := now();

  -- Sin sesión de portal, o siendo administración: sin restricciones.
  if (auth.jwt() ->> 'email') is null or public.es_admin() then
    return new;
  end if;

  foreach c in array permitidas loop
    viejo := viejo - c;
    nuevo := nuevo - c;
  end loop;
  if viejo is distinct from nuevo then
    raise exception 'Un entrenador solo puede cambiar el grupo, el estado, el fin de la prueba y las observaciones de sus atletas.';
  end if;

  if new.grupo_id is distinct from old.grupo_id and new.grupo_id is not null then
    if not exists (select 1 from public.grupos g
                    where g.id = new.grupo_id and g.entrenador_id = public.mi_perfil_id()) then
      raise exception 'Solo puedes mover al atleta a un grupo que dirijas tú. Para pasarlo a otro entrenador, avisa a administración.';
    end if;
  end if;

  return new;
end; $fn$;
