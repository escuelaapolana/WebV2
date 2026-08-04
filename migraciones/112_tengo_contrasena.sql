-- ============================================================
-- ¿TENGO CONTRASEÑA?
-- ------------------------------------------------------------
-- Desde ahora la gente entra con su correo y su contraseña. El enlace
-- por correo sigue existiendo, pero solo para dos cosas: darse de alta
-- la primera vez y salir del apuro cuando uno no se acuerda.
--
-- Al entrar por ese enlace hay que decidir una cosa: ¿le pedimos que se
-- ponga una contraseña, o ya tiene una y sería marearle?
--
-- Hasta ahora eso se adivinaba con una marca que se guardaba en la
-- propia cuenta al ponerla. Funciona para quien la pone desde la web
-- —que en septiembre serán todos—, pero no para las poquísimas cuentas
-- a las que el club les puso una contraseña a mano desde Supabase: esas
-- no llevan la marca, así que se les ofrecería ponerse una que ya
-- tienen. No es grave, pero es adivinar teniendo el dato al lado.
--
-- Esta función lo pregunta donde está de verdad. Y solo contesta por
-- quien pregunta: no sirve para averiguar nada de nadie más.
-- ============================================================

create or replace function public.tengo_contrasena()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    (select u.encrypted_password is not null and u.encrypted_password <> ''
       from auth.users u
      where u.id = auth.uid()),
    false
  );
$$;

comment on function public.tengo_contrasena() is
  'Dice si la cuenta de quien pregunta tiene contraseña puesta. Solo la suya: '
  'se ata a auth.uid() y no acepta que se le pase el correo de otro. Sirve para '
  'que, al entrar por el enlace, no se le pida una contraseña a quien ya tiene.';

-- Las funciones nacen cerradas (migración 090), así que hay que abrirla
-- a mano. A quien no ha entrado no se le abre: si no hay sesión, no hay
-- nada que preguntar.
revoke all on function public.tengo_contrasena() from public, anon;
grant execute on function public.tengo_contrasena() to authenticated;
