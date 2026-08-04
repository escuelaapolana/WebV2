-- ============================================================
-- INVITAR A ALGUIEN DEL EQUIPO
-- ------------------------------------------------------------
-- Isabel lleva los socios del club y necesitaba entrar. Al ir a darla
-- de alta apareció una pescadilla que se muerde la cola:
--
--   · para entrar, tu correo tiene que estar en `perfiles`
--   · pero una fila de `perfiles` no puede existir sin cuenta, porque
--     comparte identificador con ella
--
-- O sea: quien no es atleta ni familia de un atleta no tiene por dónde
-- entrar. Isabel es el primer caso, pero le pasa igual a cualquier
-- entrenador nuevo, a un monitor de El Cubo o a quien entre en la junta.
-- Hasta ahora eso se resolvía a mano y por detrás, con la llave de
-- servicio, que es justo lo que no queremos que haga falta.
--
-- Esto lo arregla por delante: administración deja apuntado el correo de
-- esa persona y con qué papel entra. Cuando ella pide su enlace, la
-- cuenta nace, el perfil se crea solo y le pone el papel que se dejó
-- dicho. Sin contraseñas provisionales que repartir por WhatsApp ni
-- cuentas creadas por detrás.
--
-- La invitación NO es una cuenta: es un permiso para que la cuenta
-- pueda nacer. Mientras no entre, no hay nada suyo en el club.
-- ============================================================

create table if not exists public.invitaciones_equipo (
  email        text primary key,
  nombre       text not null default '',
  apellidos    text not null default '',
  rol          text not null,
  roles        text[],
  invitado_por uuid references public.perfiles(id),
  creado_en    timestamptz not null default now(),
  usado_en     timestamptz,
  constraint invitaciones_rol_valido check (
    rol = any (array['admin','coordinador','entrenador','atleta','padre',
                     'tesoreria','contabilidad','junta','cubo'])
  ),
  constraint invitaciones_roles_validos check (
    roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre',
                                    'tesoreria','contabilidad','junta','cubo']
  )
);

comment on table public.invitaciones_equipo is
  'Correos a los que administración ha dado permiso para entrar antes de que '
  'tengan cuenta. No es una cuenta: es la llave para que pueda nacer. Se '
  'consume sola la primera vez que la persona entra.';

-- El correo se guarda siempre en minúsculas y sin espacios: si no, la
-- misma persona escrita de dos maneras no se reconoce a sí misma.
create or replace function public.invitacion_normaliza()
returns trigger language plpgsql as $$
begin
  new.email := lower(btrim(new.email));
  return new;
end;
$$;

drop trigger if exists invitaciones_normaliza on public.invitaciones_equipo;
create trigger invitaciones_normaliza
  before insert or update on public.invitaciones_equipo
  for each row execute function public.invitacion_normaliza();

-- ------------------------------------------------------------
-- Quién puede invitar: solo administración. Dar entrada al club no es
-- una tarea de gestión corriente.
-- ------------------------------------------------------------
alter table public.invitaciones_equipo enable row level security;

drop policy if exists "admin gestiona invitaciones" on public.invitaciones_equipo;
create policy "admin gestiona invitaciones" on public.invitaciones_equipo
  for all using (public.es_admin()) with check (public.es_admin());

revoke all on public.invitaciones_equipo from anon, authenticated;
grant select, insert, update, delete on public.invitaciones_equipo to authenticated;

-- ------------------------------------------------------------
-- La puerta reconoce ahora también a los invitados.
--
-- Sigue contestando lo mismo exista o no el correo: quien pruebe correos
-- a ver cuáles son del club no averigua nada por aquí.
-- ------------------------------------------------------------
create or replace function public.acceso_puede_entrar(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1 from public.perfiles
       where lower(email) = lower(btrim(p_email))
         and coalesce(activo, true)
    )
    or exists (
      select 1 from public.atletas
       where email is not null
         and lower(email) = lower(btrim(p_email))
         and coalesce(estado, 'activo') <> 'baja'
    )
    or exists (
      select 1 from public.atletas
       where email_tutor is not null
         and lower(email_tutor) = lower(btrim(p_email))
         and coalesce(estado, 'activo') <> 'baja'
    )
    -- Invitada por administración y todavía sin usar.
    or exists (
      select 1 from public.invitaciones_equipo
       where email = lower(btrim(p_email))
         and usado_en is null
    );
$$;

-- ------------------------------------------------------------
-- Y al nacer la cuenta, el perfil se crea con el papel que se dejó
-- dicho, no con el de atleta por defecto.
--
-- Si no hay invitación, todo sigue exactamente igual que antes: nace
-- como atleta y `acceso_enganchar` le pone su nombre si tiene ficha.
-- ------------------------------------------------------------
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare inv public.invitaciones_equipo%rowtype;
begin
  select * into inv
    from public.invitaciones_equipo
   where email = lower(btrim(new.email))
     and usado_en is null;

  insert into public.perfiles (id, email, nombre, apellidos, rol, roles, activo)
  values (
    new.id,
    new.email,
    -- El nombre provisional es el trozo del correo antes de la arroba.
    -- `acceso_enganchar` lo cambia por el de verdad si hay ficha.
    coalesce(nullif(inv.nombre, ''), split_part(new.email, '@', 1)),
    coalesce(inv.apellidos, ''),
    coalesce(inv.rol, 'atleta'),
    coalesce(inv.roles, array[coalesce(inv.rol, 'atleta')]),
    true
  )
  on conflict (id) do nothing;

  -- La invitación se marca como usada, no se borra: así queda dicho
  -- quién dio entrada a quién y cuándo.
  if inv.email is not null then
    update public.invitaciones_equipo set usado_en = now() where email = inv.email;
  end if;

  begin
    perform public.acceso_enganchar(new.id, new.email);
  exception when others then
    null;  -- si el enganche falla, la cuenta se crea igual
  end;

  return new;
end;
$$;

comment on function public.crear_perfil_nuevo_usuario() is
  'Crea la ficha de una cuenta recién nacida. Si administración había dejado '
  'una invitación para ese correo, la ficha nace con el nombre y el papel que '
  'se dejaron dichos; si no, nace como atleta, igual que siempre.';
