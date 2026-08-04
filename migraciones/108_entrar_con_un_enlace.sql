-- ============================================================
-- 108 · Entrar con un enlace (sin contraseña)
-- ------------------------------------------------------------
-- EL PROBLEMA, CON NÚMEROS
-- Hoy no hay ninguna forma de dar de alta cuentas. Hay 15 cuentas
-- y 13 son de prueba: dos personas reales. De 207 atletas, 3
-- tienen cuenta. Dar acceso a alguien significa que el tesorero
-- entre al panel de Supabase y cree la cuenta a mano, con su
-- contraseña. En septiembre entran unas 200 familias a la vez.
--
-- LO QUE MONTA ESTE ARCHIVO
-- La persona escribe su correo, le llega un enlace, lo pulsa y
-- está dentro. La cuenta se crea sola la primera vez. Aquí abajo
-- están las TRES piezas de base de datos que eso necesita:
--
--   1. acceso_puede_entrar(correo)  · quién tiene derecho a entrar
--   2. acceso_enganchar(id, correo) · atar la cuenta a su ficha
--   3. acceso_intentos + acceso_pedir_apuntar() · que no se pueda
--      pedir el enlace cincuenta veces seguidas
--
-- NINGUNA de las tres se puede llamar desde un navegador: las
-- funciones de esta base nacen cerradas (migración 090) y solo las
-- puede ejecutar `service_role`, que vive en la función
-- `acceso-enlace` de Supabase y NUNCA viaja al móvil de nadie.
-- Eso es a propósito: si `acceso_puede_entrar` fuera pública,
-- cualquiera podría ir probando correos hasta averiguar cuáles
-- están dados de alta en el club.
--
-- ⚠️ AVISO IMPORTANTE PARA QUIEN LEA ESTO EN EL CLUB
-- A día de hoy, de los 207 atletas, CERO tienen correo apuntado en
-- su ficha (ni el suyo ni el de su padre o madre). Con esto puesto
-- funcionará el mecanismo, pero no entrará nadie nuevo hasta que
-- los correos estén en la base. Se cargan con la pantalla de
-- «Importar» del panel, que ya entiende las columnas «email» y
-- «email tutor». Sin ese paso, en septiembre no entra ninguna
-- familia.
-- ============================================================


-- ------------------------------------------------------------
-- 1 · QUIÉN TIENE DERECHO A ENTRAR
-- ------------------------------------------------------------
-- Solo quien ya esté en la base del club. Un correo da derecho a
-- entrar si aparece en alguno de estos tres sitios:
--
--   · perfiles.email      → ya tiene cuenta (entrenadores, junta,
--                           administración, los que ya entran hoy)
--   · atletas.email       → es el correo del propio atleta
--   · atletas.email_tutor → es el correo del padre, madre o tutor
--
-- Fuera queda `contactos.email`: son los correos de contacto que el
-- club PUBLICA en la web (secciones, responsables). Están a la
-- vista de cualquiera, así que no pueden servir de llave. Quien
-- lleva una sección y además necesita entrar, tiene su perfil.
--
-- Las bajas no entran. Los de «prueba» y los lesionados sí: son
-- gente que está entrenando ahora mismo.
--
-- La comparación es en minúsculas porque nadie escribe su correo
-- dos veces igual, y va contra los índices que ya existen
-- (idx_atletas_email, idx_atletas_email_tutor), así que es
-- instantánea aunque haya miles de fichas.
-- ------------------------------------------------------------
create or replace function public.acceso_puede_entrar(p_email text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
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
    );
$$;

comment on function public.acceso_puede_entrar(text) is
  'Dice si un correo tiene derecho a entrar en el portal. Solo la puede llamar service_role: si fuera pública, sería una forma de averiguar qué correos están dados de alta en el club.';


-- ------------------------------------------------------------
-- 2 · EL ENGANCHE · atar la cuenta nueva a la ficha que ya existe
-- ------------------------------------------------------------
-- Es la parte que, si falla, hace el peor primer día posible: la
-- persona entra y no ve nada suyo.
--
-- LO QUE ARREGLA RESPECTO A ANTES
-- El enganche ya existía dentro del disparador de altas, pero se
-- paraba en la PRIMERA ficha que encontraba (`limit 1`). Una madre
-- con tres hijos en el club se enganchaba a uno y los otros dos
-- desaparecían de su pantalla. Aquí se enganchan TODAS.
--
-- Además esto se puede volver a llamar cuantas veces haga falta
-- sin estropear nada (solo rellena lo que está vacío), y por eso
-- la función del enlace lo llama SIEMPRE, también con cuentas que
-- ya existían: así se arreglan solas las que se crearon antes de
-- que su ficha tuviera correo.
--
-- LO QUE NO TOCA
-- Los papeles concedidos a mano (entrenador, coordinación,
-- administración, tesorería…) no se quitan nunca: solo se AÑADE
-- «atleta» o «padre» según lo que digan las fichas. Y el papel
-- principal solo se recalcula si hoy es «atleta» o «padre»; si
-- alguien es entrenador, sigue siendo entrenador.
-- ------------------------------------------------------------
create or replace function public.acceso_enganchar(p_uid uuid, p_email text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_email      text := lower(btrim(p_email));
  v_fichas     int  := 0;   -- fichas propias enganchadas ahora
  v_hijos      int  := 0;   -- fichas de hijos enganchadas ahora
  v_es_atleta  boolean;
  v_es_familia boolean;
  v_nombre     text;
  v_apellidos  text;
  v_rol        text;
  v_roles      text[];
begin
  if p_uid is null or v_email = '' then
    return jsonb_build_object('ok', false);
  end if;

  -- Su propia ficha de atleta. Puede haber más de una (un atleta
  -- que se dio de baja y volvió), y se cogen todas: la pantalla ya
  -- sabe enseñar varias.
  update public.atletas
     set perfil_id = p_uid
   where email is not null
     and lower(email) = v_email
     and perfil_id is null;
  get diagnostics v_fichas = row_count;

  -- Las fichas de sus hijos. TODAS, no la primera.
  update public.atletas
     set perfil_padre_id = p_uid
   where email_tutor is not null
     and lower(email_tutor) = v_email
     and perfil_padre_id is null;
  get diagnostics v_hijos = row_count;

  -- A partir de aquí se mira el estado FINAL (lo enganchado ahora y
  -- lo que ya estuviera enganchado de antes), no solo lo de este
  -- momento: si la ficha ya estaba atada, sigue contando.
  select exists (select 1 from public.atletas where perfil_id = p_uid),
         exists (select 1 from public.atletas where perfil_padre_id = p_uid)
    into v_es_atleta, v_es_familia;

  -- El nombre. Cuando la cuenta se crea sola, el nombre provisional
  -- es el trozo del correo antes de la arroba («marta.ibanez»).
  -- Si hay ficha, se pone el nombre de verdad; si no la hay, se
  -- deja lo que tuviera puesto, que igual lo escribió ella misma.
  select nombre, coalesce(apellidos, '')
    into v_nombre, v_apellidos
    from public.atletas
   where perfil_id = p_uid
   order by created_at
   limit 1;

  if v_nombre is null and v_es_familia then
    select nullif(btrim(nombre_tutor), ''), ''
      into v_nombre, v_apellidos
      from public.atletas
     where perfil_padre_id = p_uid
       and nullif(btrim(nombre_tutor), '') is not null
     order by created_at
     limit 1;
  end if;

  -- Los papeles que se deducen de las fichas.
  select rol, coalesce(roles, array[]::text[]) into v_rol, v_roles
    from public.perfiles where id = p_uid;

  -- «Atleta» y «familia» no los concede nadie a mano: los dicen las
  -- fichas. Así que cuando hay ficha se recolocan los dos de golpe,
  -- quitando el que ya no toca. Sin esto, una madre sin ficha propia
  -- se quedaba con el papel «atleta» que le puso el alta por defecto
  -- y le salía en el selector una pestaña de atleta vacía.
  --
  -- Si NO se ha deducido nada (alguien del club sin ficha: junta,
  -- administración, un entrenador que no entrena), no se toca ni un
  -- papel: lo que tenga puesto lo puso el club a propósito.
  --
  -- `array_append` y no `||`: con `||` Postgres intenta leer el texto
  -- suelto como si fuera un array y revienta («malformed array literal»).
  if v_es_atleta or v_es_familia then
    select coalesce(array_agg(x), array[]::text[]) into v_roles
      from unnest(v_roles) as x
     where x not in ('atleta', 'padre');
    if v_es_atleta  then v_roles := array_append(v_roles, 'atleta'); end if;
    if v_es_familia then v_roles := array_append(v_roles, 'padre');  end if;

    -- El papel principal solo se recoloca entre atleta y padre. Quien
    -- ya es entrenador, coordinación o administración se queda como
    -- está: eso lo concede el club, no una ficha.
    if v_rol in ('atleta', 'padre') then
      v_rol := case when v_es_atleta then 'atleta' else 'padre' end;
    end if;
  end if;

  update public.perfiles
     set rol       = coalesce(v_rol, rol),
         roles     = v_roles,
         nombre    = case
                       when v_nombre is null then nombre
                       -- Solo se pisa el nombre provisional (el del
                       -- correo). Si la persona ya puso el suyo, manda ella.
                       -- En minúsculas los dos: el correo se guarda tal y
                       -- como lo escribió («Madre.Prueba@…»), así que
                       -- comparándolo en crudo no coincidía nunca.
                       when lower(nombre) = split_part(v_email, '@', 1) then v_nombre
                       else nombre
                     end,
         apellidos = case
                       when v_nombre is null then apellidos
                       when lower(nombre) = split_part(v_email, '@', 1) then v_apellidos
                       else apellidos
                     end
   where id = p_uid;

  return jsonb_build_object(
    'ok',       true,
    'fichas',   v_fichas,
    'hijos',    v_hijos,
    'atleta',   v_es_atleta,
    'familia',  v_es_familia
  );
exception when others then
  -- Que un tropiezo aquí no impida entrar: la persona entra y el
  -- club le enlaza la ficha desde el panel de usuarios. Pero se
  -- deja gritado en el registro de la base, porque un enganche que
  -- falla en silencio es justo el fallo que nadie ve hasta que una
  -- familia llama diciendo que no ve a sus hijos.
  raise warning 'acceso_enganchar falló para % : %', p_uid, sqlerrm;
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

comment on function public.acceso_enganchar(uuid, text) is
  'Ata una cuenta a las fichas del club que llevan su correo: la suya y las de TODOS sus hijos. Se puede repetir sin estropear nada.';


-- ------------------------------------------------------------
-- 3 · EL DISPARADOR DE ALTAS, AHORA MÁS CORTO
-- ------------------------------------------------------------
-- Salta cuando Supabase crea una cuenta. Antes llevaba dentro toda
-- la lógica del enganche —y con el `limit 1` que se dejaba hijos
-- por el camino—. Ahora solo hace lo mínimo (crear la fila de
-- perfil) y le pasa el enganche a la función de arriba, que es la
-- misma que usa el enlace de acceso. Una sola versión de esto en
-- toda la base: si mañana cambia la regla, cambia en un sitio.
-- ------------------------------------------------------------
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  -- El nombre provisional es el trozo del correo antes de la arroba.
  -- `acceso_enganchar` lo cambia por el de verdad si hay ficha.
  insert into public.perfiles (id, email, nombre, apellidos, rol, activo)
  values (new.id, new.email, split_part(new.email, '@', 1), '', 'atleta', true)
  on conflict (id) do nothing;

  begin
    perform public.acceso_enganchar(new.id, new.email);
  exception when others then
    null;  -- si el enganche falla, la cuenta se crea igual
  end;

  return new;
end;
$$;


-- ------------------------------------------------------------
-- 4 · QUE NO SE PUEDA PEDIR EL ENLACE CINCUENTA VECES
-- ------------------------------------------------------------
-- Sin esto, cualquiera puede dejar un script pidiendo enlaces toda
-- la noche: llenaría de correos el buzón de una familia y, de paso,
-- quemaría el cupo de envíos del club.
--
-- Se apunta cada petición y se miran dos límites:
--   · por correo · 3 en una hora. Con tres intentos, si no ha
--     llegado no es cosa de insistir: es que el correo no es ese.
--   · por origen · 20 en una hora, para el que va probando correos
--     en cadena.
--
-- Del origen NO se guarda la dirección de internet, sino un
-- resumen suyo que no se puede deshacer (lo calcula la función de
-- acceso antes de llamar aquí). Sirve para contar y no sirve para
-- saber quién es.
--
-- La tabla se limpia sola: cada llamada borra lo de hace más de un
-- día. No hace falta ninguna tarea programada.
-- ------------------------------------------------------------
create table if not exists public.acceso_intentos (
  id         bigserial primary key,
  email      text        not null,
  origen     text,                       -- resumen del origen, no la dirección
  creado_en  timestamptz not null default now()
);

create index if not exists idx_acceso_intentos_email  on public.acceso_intentos (lower(email), creado_en desc);
create index if not exists idx_acceso_intentos_origen on public.acceso_intentos (origen, creado_en desc);

-- Nace cerrada del todo: RLS puesta y ni una sola política. Así no
-- la lee ni la escribe nadie desde el navegador, ni con cuenta ni
-- sin ella. Solo `service_role` pasa por encima de RLS.
alter table public.acceso_intentos enable row level security;
revoke all on public.acceso_intentos from anon, authenticated;

comment on table public.acceso_intentos is
  'Cuántas veces se ha pedido el enlace de acceso, para no dejar que se pida sin parar. Se borra sola al día.';


-- Apunta el intento y dice si se puede enviar. Las dos cosas a la
-- vez, porque preguntar primero y apuntar después deja una rendija
-- para el que llama veinte veces en el mismo segundo.
create or replace function public.acceso_pedir_apuntar(p_email text, p_origen text)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_email  text := lower(btrim(p_email));
  v_correo int;
  v_origen int;
begin
  delete from public.acceso_intentos where creado_en < now() - interval '1 day';

  select count(*) into v_correo
    from public.acceso_intentos
   where lower(email) = v_email
     and creado_en > now() - interval '1 hour';

  select count(*) into v_origen
    from public.acceso_intentos
   where p_origen is not null
     and origen = p_origen
     and creado_en > now() - interval '1 hour';

  -- El intento se apunta pase lo que pase: si no, el que se pasa de
  -- la raya nunca acumularía y podría seguir pidiendo para siempre.
  insert into public.acceso_intentos (email, origen) values (v_email, p_origen);

  return v_correo < 3 and v_origen < 20;
end;
$$;

comment on function public.acceso_pedir_apuntar(text, text) is
  'Apunta una petición de enlace de acceso y dice si toca enviarlo (3 por correo y 20 por origen en una hora).';


-- ------------------------------------------------------------
-- 5 · REPASO DE LAS CUENTAS QUE YA EXISTEN
-- ------------------------------------------------------------
-- Las cuentas creadas antes de hoy nunca pasaron por el enganche
-- nuevo. Se les pasa ahora, una vez, para que las que tengan ficha
-- con su correo queden atadas (y las madres con varios hijos vean
-- a todos, no a uno).
-- ------------------------------------------------------------
do $$
declare r record;
begin
  for r in select id, email from public.perfiles where email is not null loop
    perform public.acceso_enganchar(r.id, r.email);
  end loop;
end $$;
