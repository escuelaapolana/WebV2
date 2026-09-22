-- 202 · «Cambiar la contraseña» sin depender del redirect del correo
-- Problema: pasar la intención por la URL (?recuperar=1) obligaba a cambiar el
-- redirect_to del enlace, y si esa URL no está en la lista de redirecciones
-- permitidas de Supabase, el correo NO se manda. Solución: el enlace vuelve
-- SIEMPRE a la dirección de siempre (que sí funciona) y la intención viaja por
-- la base: acceso-enlace apunta aquí que esta persona pidió cambiar la clave;
-- al entrar, la app pregunta y, si es que sí, enseña «Ponte una contraseña».
create table if not exists public.cambio_clave_pedido (
  email     text primary key,
  pedido_en timestamptz not null default now()
);

-- Lo apunta acceso-enlace (con la llave de servicio) cuando pulsan
-- «no me acuerdo de mi contraseña».
create or replace function public.marcar_cambio_clave(p_email text)
 returns void
 language sql security definer set search_path to 'public'
as $$
  insert into public.cambio_clave_pedido (email, pedido_en)
  values (lower(p_email), now())
  on conflict (email) do update set pedido_en = now();
$$;

-- Lo pregunta la app al entrar. Si hay una petición reciente (20 min), la gasta
-- (la borra) y devuelve true → sale «Ponte una contraseña».
create or replace function public.debo_cambiar_clave()
 returns boolean
 language plpgsql security definer set search_path to 'public'
as $$
declare
  v_email text := lower(auth.jwt() ->> 'email');
  v_hit   boolean := false;
begin
  if v_email is null then return false; end if;
  delete from public.cambio_clave_pedido
   where email = v_email and pedido_en > now() - interval '20 minutes'
   returning true into v_hit;
  -- limpieza de peticiones viejas
  delete from public.cambio_clave_pedido where pedido_en <= now() - interval '20 minutes';
  return coalesce(v_hit, false);
end; $$;

grant execute on function public.marcar_cambio_clave(text) to service_role, authenticated;
grant execute on function public.debo_cambiar_clave() to authenticated;
