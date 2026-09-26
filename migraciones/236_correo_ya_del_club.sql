-- 236 · Verificación por enlace en las altas públicas (pentest, MEDIO)
--
-- Las altas públicas (socio-cuenta, cubo-alta, cubo-prueba-alta, acceso-grupo,
-- entrenador-alta) creaban una cuenta con email_confirm:true y CONTRASEÑA elegida
-- por quien llama, para CUALQUIER correo. Con el trigger acceso_enganchar, quien
-- conociera el correo de un miembro importado que aún no ha entrado podía ocupar
-- su cuenta. La defensa: si el correo YA es del club (tiene ficha o perfil), no se
-- crea cuenta con contraseña; se manda un enlace mágico al correo real (como
-- acceso-enlace) y solo el dueño del buzón entra. Los correos NUEVOS de verdad
-- siguen con acceso instantáneo. Este helper dice si un correo ya es del club.

create or replace function public.correo_ya_del_club(p_email text)
returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.perfiles p where lower(p.email) = lower(btrim(p_email))
  ) or exists (
    select 1 from public.atletas a
     where lower(a.email) = lower(btrim(p_email))
        or lower(a.email_tutor) = lower(btrim(p_email))
  );
$$;

revoke all on function public.correo_ya_del_club(text) from public;
grant execute on function public.correo_ya_del_club(text) to service_role;
