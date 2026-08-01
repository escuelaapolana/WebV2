-- =====================================================================
-- 038 · IMPORTAR PERSONAS DESDE UNA HOJA DE CÁLCULO (CSV)
-- ---------------------------------------------------------------------
-- El club tiene hoy sus ~180 atletas en Excel y en formularios de Google.
-- Meterlos a mano uno a uno no es realista, así que esta migración
-- prepara la base de datos para poder subirlos de golpe desde la
-- pantalla /admin/importar/.
--
-- Hay tres cosas que resolver:
--
-- 1) DÓNDE GUARDAR EL CORREO Y EL TELÉFONO.
--    La tabla `atletas` no tenía ninguna columna de contacto: el correo
--    y el teléfono viven en `perfiles`. Pero `perfiles.id` apunta a
--    `auth.users`, o sea que NO se puede crear un perfil sin crear antes
--    una cuenta de acceso (con su contraseña, su correo de invitación,
--    etc.). Importar 180 personas no puede implicar crear 180 cuentas.
--    Solución: el contacto se guarda en la propia ficha del atleta
--    (columnas nuevas de abajo). Cuando esa persona se cree la cuenta
--    con ese mismo correo, la ficha se enlaza sola (ver punto 3).
--
-- 2) DE QUÉ IMPORTACIÓN VIENE CADA FICHA.
--    Cada ficha guarda la fecha de importación y el identificador de la
--    tanda. Así se sabe siempre qué entró en cada subida y se puede
--    deshacer una importación entera sin tocar nada más.
--
-- 3) ENLAZAR LA FICHA CON LA CUENTA CUANDO SE CREE.
--    Se amplía el disparador que crea el perfil al darse de alta un
--    usuario, para que busque una ficha de atleta con ese mismo correo
--    (o con ese correo como correo del tutor) y las enlace.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/038_importacion.sql
-- =====================================================================

begin;

-- =====================================================================
-- 1 · CONTACTO Y RASTRO DE IMPORTACIÓN EN LA FICHA DEL ATLETA
-- =====================================================================

alter table public.atletas add column if not exists dni             text;
alter table public.atletas add column if not exists sexo            text;
alter table public.atletas add column if not exists email           text;
alter table public.atletas add column if not exists telefono        text;
alter table public.atletas add column if not exists nombre_tutor    text;
alter table public.atletas add column if not exists email_tutor     text;
alter table public.atletas add column if not exists telefono_tutor  text;
alter table public.atletas add column if not exists importado_en    timestamptz;
alter table public.atletas add column if not exists importacion_id  uuid;

comment on column public.atletas.dni            is 'DNI/NIE del atleta, tal y como viene en los formularios del club. Sirve además como clave para no duplicar a nadie al importar.';
comment on column public.atletas.sexo           is 'hombre / mujer / otro. Lo piden los formularios de alta y hace falta para las categorías federadas.';
comment on column public.atletas.email          is 'Correo de contacto del atleta. NO es una cuenta de acceso: es el correo que el club tiene apuntado. Cuando esa persona se registre con este mismo correo, su ficha se enlaza sola con su perfil.';
comment on column public.atletas.telefono       is 'Teléfono de contacto del atleta.';
comment on column public.atletas.nombre_tutor   is 'Nombre del padre, madre o tutor (menores).';
comment on column public.atletas.email_tutor    is 'Correo del padre, madre o tutor. Mismo funcionamiento que el del atleta: al registrarse con él, queda enlazado como familia.';
comment on column public.atletas.telefono_tutor is 'Teléfono del padre, madre o tutor.';
comment on column public.atletas.importado_en   is 'Cuándo entró esta ficha por la pantalla de importación. Vacío = se creó a mano.';
comment on column public.atletas.importacion_id is 'De qué tanda de importación viene la ficha. Permite deshacer una importación entera.';

-- El sexo, si viene, solo puede ser uno de estos tres.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'atletas_sexo_check') then
    alter table public.atletas add constraint atletas_sexo_check
      check (sexo is null or sexo in ('hombre','mujer','otro'));
  end if;
end $$;

-- Búsquedas rápidas al enlazar cuentas y al buscar duplicados.
create index if not exists idx_atletas_email       on public.atletas (lower(email));
create index if not exists idx_atletas_email_tutor on public.atletas (lower(email_tutor));
create index if not exists idx_atletas_dni         on public.atletas (upper(dni));
create index if not exists idx_atletas_importacion on public.atletas (importacion_id);


-- =====================================================================
-- 2 · REGISTRO DE IMPORTACIONES
-- =====================================================================
-- Una fila por cada subida de fichero. Guarda el recuento y, en
-- `deshacer`, lo justo para poder volver atrás: qué fichas se crearon
-- y, de las que se actualizaron, cómo estaban antes.

create table if not exists public.importaciones (
  id            uuid primary key default gen_random_uuid(),
  creado_en     timestamptz not null default now(),
  creado_por    uuid references public.perfiles(id),
  fichero       text,
  total         integer not null default 0,
  nuevos        integer not null default 0,
  actualizados  integer not null default 0,
  errores       integer not null default 0,
  deshacer      jsonb   not null default '[]'::jsonb,
  deshecha_en   timestamptz,
  nota          text
);

comment on table  public.importaciones          is 'Una fila por cada importación de personas desde CSV hecha en /admin/importar/.';
comment on column public.importaciones.deshacer is 'Lista de lo que hizo la importación: {accion:"crear"|"actualizar", atleta_id, antes:{...}}. Con esto se revierte.';
comment on column public.importaciones.deshecha_en is 'Si tiene fecha, esta importación ya se deshizo y no se puede deshacer otra vez.';

create index if not exists idx_importaciones_fecha on public.importaciones (creado_en desc);

-- La ficha apunta a la tanda de la que vino.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'atletas_importacion_id_fkey') then
    alter table public.atletas add constraint atletas_importacion_id_fkey
      foreign key (importacion_id) references public.importaciones(id) on delete set null;
  end if;
end $$;

-- --- Permisos: SOLO administración -----------------------------------
alter table public.importaciones enable row level security;

drop policy if exists "admin gestiona importaciones" on public.importaciones;
create policy "admin gestiona importaciones" on public.importaciones
  for all to authenticated
  using (public.es_admin())
  with check (public.es_admin());

-- (En `atletas` no hace falta tocar nada: la única política que permite
--  INSERT es «admin gestiona todo», con es_admin(). Un entrenador solo
--  puede SELECT de sus grupos y UPDATE de sus atletas.)


-- =====================================================================
-- 3 · DESHACER UNA IMPORTACIÓN
-- =====================================================================
-- Borra las fichas que creó esa tanda y devuelve a su estado anterior
-- las que actualizó. Solo toca las columnas que la importación puede
-- escribir; lo que se haya cambiado después a mano en otras columnas
-- (grupo, entrenador, observaciones…) no se pierde.

create or replace function public.deshacer_importacion(p_importacion uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  imp          public.importaciones;
  fila         jsonb;
  borrados     integer := 0;
  restaurados  integer := 0;
begin
  if not public.es_admin() then
    raise exception 'Solo administración puede deshacer una importación.';
  end if;

  select * into imp from public.importaciones where id = p_importacion;
  if imp.id is null then
    raise exception 'Esa importación no existe.';
  end if;
  if imp.deshecha_en is not null then
    raise exception 'Esa importación ya se deshizo el %.', to_char(imp.deshecha_en, 'DD/MM/YYYY HH24:MI');
  end if;

  for fila in select * from jsonb_array_elements(coalesce(imp.deshacer, '[]'::jsonb))
  loop
    if fila->>'accion' = 'crear' then
      delete from public.atletas
       where id = (fila->>'atleta_id')::uuid
         and importacion_id = p_importacion;
      if found then borrados := borrados + 1; end if;

    elsif fila->>'accion' = 'actualizar' then
      update public.atletas a set
        nombre           = r.nombre,
        apellidos        = r.apellidos,
        fecha_nacimiento = r.fecha_nacimiento,
        categoria        = r.categoria,
        estado           = r.estado,
        grupo_id         = r.grupo_id,
        especialidades   = r.especialidades,
        dni              = r.dni,
        sexo             = r.sexo,
        email            = r.email,
        telefono         = r.telefono,
        nombre_tutor     = r.nombre_tutor,
        email_tutor      = r.email_tutor,
        telefono_tutor   = r.telefono_tutor,
        importado_en     = r.importado_en,
        importacion_id   = r.importacion_id
      from jsonb_populate_record(null::public.atletas, fila->'antes') r
      where a.id = (fila->>'atleta_id')::uuid;
      if found then restaurados := restaurados + 1; end if;
    end if;
  end loop;

  update public.importaciones
     set deshecha_en = now()
   where id = p_importacion;

  return jsonb_build_object('borrados', borrados, 'restaurados', restaurados);
end;
$fn$;

comment on function public.deshacer_importacion(uuid) is 'Revierte una importación: borra lo que creó y devuelve a su estado anterior lo que actualizó. Solo administración.';

revoke all on function public.deshacer_importacion(uuid) from public, anon;
grant execute on function public.deshacer_importacion(uuid) to authenticated;


-- =====================================================================
-- 4 · AL CREAR LA CUENTA, ENLAZAR CON LA FICHA IMPORTADA
-- =====================================================================
-- Antes: al registrarse alguien se le creaba un perfil suelto con el
-- nombre sacado del correo. Ahora, además, se busca si el club ya tenía
-- su ficha importada con ese correo:
--   · si el correo es el del atleta  -> se enlaza como atleta (perfil_id)
--   · si es el del tutor             -> se enlaza como familia (perfil_padre_id)
-- y el perfil se rellena con el nombre y apellidos de verdad.
-- Si algo fallase, el registro sigue adelante igualmente: nunca puede
-- impedir que alguien se dé de alta.

create or replace function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_ficha_id     uuid    := null;
  v_ficha_nombre text;
  v_ficha_apes   text;
  v_ficha_tutor  text;
  como_tutor     boolean := false;
  v_nombre       text;
  v_apellidos    text    := '';
  v_rol          text    := 'atleta';
begin
  begin
    -- ¿Hay una ficha con este correo como correo del atleta?
    select id, nullif(trim(nombre), ''), coalesce(apellidos, '')
      into v_ficha_id, v_ficha_nombre, v_ficha_apes
      from public.atletas
     where email is not null
       and lower(email) = lower(new.email)
       and perfil_id is null
     order by created_at
     limit 1;

    -- Si no, ¿lo tiene apuntado como correo del padre/madre/tutor?
    if v_ficha_id is null then
      select id, nullif(trim(nombre_tutor), '')
        into v_ficha_id, v_ficha_tutor
        from public.atletas
       where email_tutor is not null
         and lower(email_tutor) = lower(new.email)
         and perfil_padre_id is null
       order by created_at
       limit 1;
      if v_ficha_id is not null then
        como_tutor := true;
        v_rol      := 'padre';
      end if;
    end if;
  exception when others then
    v_ficha_id := null;
    como_tutor := false;
    v_rol      := 'atleta';
  end;

  if v_ficha_id is not null and como_tutor then
    v_nombre    := coalesce(v_ficha_tutor, split_part(new.email, '@', 1));
    v_apellidos := '';
  elsif v_ficha_id is not null then
    v_nombre    := coalesce(v_ficha_nombre, split_part(new.email, '@', 1));
    v_apellidos := coalesce(v_ficha_apes, '');
  else
    v_nombre    := split_part(new.email, '@', 1);
    v_apellidos := '';
  end if;

  insert into public.perfiles (id, email, nombre, apellidos, rol, activo)
  values (new.id, new.email, v_nombre, v_apellidos, v_rol, true)
  on conflict (id) do nothing;

  if v_ficha_id is not null then
    begin
      if como_tutor then
        update public.atletas set perfil_padre_id = new.id where id = v_ficha_id and perfil_padre_id is null;
      else
        update public.atletas set perfil_id = new.id where id = v_ficha_id and perfil_id is null;
      end if;
    exception when others then
      null;
    end;
  end if;

  return new;
end;
$fn$;

comment on function public.crear_perfil_nuevo_usuario() is 'Crea el perfil al registrarse un usuario y, si el club ya tenía su ficha de atleta importada con ese mismo correo, las enlaza (como atleta o como familia).';

commit;

-- =====================================================================
-- Comprobación rápida
-- =====================================================================
select column_name
  from information_schema.columns
 where table_schema = 'public' and table_name = 'atletas'
   and column_name in ('dni','sexo','email','telefono','nombre_tutor','email_tutor',
                       'telefono_tutor','importado_en','importacion_id')
 order by column_name;
