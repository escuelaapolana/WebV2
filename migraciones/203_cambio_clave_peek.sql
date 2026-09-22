-- 203 · «¿Debo cambiar la clave?» separa MIRAR de GASTAR
-- El enlace del correo puede aterrizar en la home (no en el portal) porque
-- Supabase manda a la URL del sitio. La home mira si hay cambio de clave
-- pendiente y reenvía al portal; el portal también lo mira. Si la primera
-- lectura ya borrase el flag, el portal no lo vería. Por eso ahora:
--   · debo_cambiar_clave()  → solo MIRA (no borra). La pueden llamar varias
--     páginas (home y portal) sin gastarlo.
--   · cambio_clave_hecho()  → lo BORRA, y se llama una vez puesta la clave.
create or replace function public.debo_cambiar_clave()
 returns boolean
 language sql security definer set search_path to 'public'
as $$
  select exists (
    select 1 from public.cambio_clave_pedido
     where email = lower(auth.jwt() ->> 'email')
       and pedido_en > now() - interval '20 minutes'
  );
$$;

create or replace function public.cambio_clave_hecho()
 returns void
 language sql security definer set search_path to 'public'
as $$
  delete from public.cambio_clave_pedido where email = lower(auth.jwt() ->> 'email');
$$;

grant execute on function public.debo_cambiar_clave() to authenticated;
grant execute on function public.cambio_clave_hecho() to authenticated;
