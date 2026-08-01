-- ============================================================
-- 037 · USUARIOS Y PERMISOS
-- ------------------------------------------------------------
-- Da soporte a la pantalla /admin/usuarios/ (personas, roles y
-- enlace de cada persona con su ficha de atleta o la de sus hijos).
--
-- Contiene tres cosas:
--
--   1) estado_cuentas()  · función SECURITY DEFINER, solo admin,
--      que dice si cada perfil tiene de verdad cuenta de acceso.
--      La web NO puede leer auth.users con la clave pública, y
--      tampoco debe: esta función devuelve únicamente el id del
--      perfil y tres síes/noes. Ni correos de auth, ni contraseñas,
--      ni tokens, ni fechas de sesión.
--
--   2) Un candado para que nadie se ascienda a sí mismo. La
--      política «escritura_propia» de `perfiles` deja que cada
--      persona edite SU fila (para cambiarse el teléfono), pero
--      no tiene WITH CHECK, así que hoy un atleta puede ponerse
--      rol='admin'. Comprobado con psql. Se arregla con un
--      disparador que conserva rol, sección, activo, correo e id
--      salvo que quien edita sea administración.
--
--   3) NINGUNA política nueva sobre `perfiles`: ya existe
--      «admin_gestiona_perfiles» (ALL, using es_admin(), with
--      check es_admin()) además de «admin gestiona todo». Se ha
--      verificado antes de escribir esta migración; crear otra
--      sería ruido.
-- ============================================================


-- ============================================================
-- 1 · ¿QUIÉN TIENE CUENTA DE ACCESO DE VERDAD?
-- ------------------------------------------------------------
-- `perfiles.id` apunta a auth.users, así que toda fila de
-- perfiles tiene "usuario". Pero eso no significa que la persona
-- pueda entrar: hay usuarios sin contraseña y sin correo
-- confirmado (los que se crearon para las pruebas o desde SQL).
-- Lo que interesa al club es esto:
--   tiene_contrasena   · puede entrar con correo y contraseña
--   correo_confirmado  · ha validado el correo
--   ha_entrado         · ha iniciado sesión alguna vez
-- ============================================================

create or replace function public.estado_cuentas()
returns table (
  perfil_id         uuid,
  tiene_contrasena  boolean,
  correo_confirmado boolean,
  ha_entrado        boolean
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select p.id,
         (u.encrypted_password is not null and u.encrypted_password <> ''),
         (u.email_confirmed_at is not null),
         (u.last_sign_in_at is not null)
    from public.perfiles p
    join auth.users u on u.id = p.id
   where public.es_admin();
$$;

comment on function public.estado_cuentas() is
  'Solo administración. Dice, por perfil, si esa persona puede entrar de verdad. No expone datos de auth.';

revoke all on function public.estado_cuentas() from public;
revoke all on function public.estado_cuentas() from anon;
grant execute on function public.estado_cuentas() to authenticated;


-- ============================================================
-- 2 · NADIE SE CAMBIA SU PROPIO ROL
-- ------------------------------------------------------------
-- El disparador solo actúa cuando la petición viene de una
-- persona identificada (auth.uid() no nulo) y esa persona no es
-- administración. Los cambios hechos desde psql o desde la clave
-- de servicio (sin JWT) siguen funcionando igual que hasta ahora.
-- ============================================================

create or replace function public.perfiles_protege_rol()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.es_admin() then
    new.id      := old.id;
    new.email   := old.email;
    new.rol     := old.rol;
    new.seccion := old.seccion;
    new.activo  := old.activo;
  end if;
  return new;
end;
$$;

comment on function public.perfiles_protege_rol() is
  'Impide que alguien que no sea administración se cambie el rol, la sección o el estado de su propio perfil.';

drop trigger if exists trg_perfiles_protege_rol on public.perfiles;
create trigger trg_perfiles_protege_rol
  before update on public.perfiles
  for each row execute function public.perfiles_protege_rol();


-- ============================================================
-- 3 · ÍNDICES PARA CASAR PERSONAS CON FICHAS
-- ------------------------------------------------------------
-- La pantalla busca constantemente «atletas sin cuenta enlazada»
-- y «perfiles sin ficha».
-- ============================================================

create index if not exists idx_atletas_perfil_id       on public.atletas (perfil_id);
create index if not exists idx_atletas_perfil_padre_id on public.atletas (perfil_padre_id);


-- ============================================================
-- 4 · COMPROBACIONES (para ejecutar a mano, con ROLLBACK)
-- ------------------------------------------------------------
-- begin;
--   set local role authenticated;
--   set local request.jwt.claims = '{"sub":"<id del atleta>","email":"atleta.prueba@apolana.test","role":"authenticated"}';
--   select count(*) from public.perfiles;                 -- debe ser 1 (solo el suyo)
--   update public.perfiles set rol='admin' where id='<id del atleta>';
--   select rol from public.perfiles where id='<id del atleta>';  -- debe seguir siendo 'atleta'
--   select * from public.estado_cuentas();                -- debe devolver 0 filas
-- rollback;
-- ============================================================
