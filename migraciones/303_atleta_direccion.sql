-- 303 · Dirección (opcional) en la ficha del atleta
-- Mario pasa la dirección al dar de alta; Andrés quiere poder guardarla, pero
-- SIN que sea obligatoria. Columna propia (hasta ahora iba apretujada en
-- `observaciones`) + RPC para fijarla desde el alta y desde la ficha editable.

alter table public.atletas add column if not exists direccion text;

create or replace function public.natacion_set_direccion(p_atleta uuid, p_direccion text)
returns boolean
language plpgsql security definer set search_path to 'public' as $$
begin
  if not (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion')) then
    raise exception 'Sin permiso para editar la ficha.' using errcode = '42501';
  end if;
  if p_atleta is null then return false; end if;
  update public.atletas
     set direccion = nullif(btrim(coalesce(p_direccion, '')), ''),
         updated_at = now()
   where id = p_atleta;
  return found;
end $$;

grant execute on function public.natacion_set_direccion(uuid, text) to authenticated;

-- Leer la dirección (la RLS de atletas no deja al gestor leerla directa).
create or replace function public.natacion_get_direccion(p_atleta uuid)
returns text
language sql stable security definer set search_path to 'public' as $$
  select a.direccion from public.atletas a
  where a.id = p_atleta
    and (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'));
$$;

grant execute on function public.natacion_get_direccion(uuid) to authenticated;
