-- ============================================================
-- 071 · Tesorería y contabilidad: el reparto del dinero
-- ------------------------------------------------------------
-- Fuente: maquetas/v3/CORRECCION-DINERO.md (corrige lo anterior).
--
-- EL REPARTO REAL, confirmado por el club:
--   · Isabel Fuentes  · contable   → socios y adultos. Gira remesas
--                                    y hace transferencias
--   · Adrián Onandía  · presidente → escuela (y acceso a todo)
--   · Andrés Clavero  · tesorero   → escuela (y acceso a todo)
--
-- LA REGLA DE FONDO:
--   «Quien decide un importe y quien lo ejecuta no son la misma
--    persona, y el panel lo refleja con un aviso entre los dos,
--    no con un permiso que bloquea.»
--
-- QUÉ HACE ESTA MIGRACIÓN
--   1 · Tres papeles nuevos (tesorería, contabilidad, junta) sin
--       tocar los roles que ya existen ni es_admin()/es_staff().
--   2 · La etiqueta escuela/socio de cada ficha, puesta a mano,
--       nunca deducida: sin etiqueta = «sin etiquetar».
--   3 · La cuota mensual, que hasta hoy no existía en la ficha.
--   4 · Los avisos de dinero entre tesorería y contabilidad, con
--       las dos direcciones del flujo.
--   5 · Los permisos para que contabilidad pueda trabajar sin
--       poder cambiar importes.
--
-- Idempotente: se puede aplicar las veces que haga falta.
--
-- ⚠️ Supabase reparte permisos solos a `anon`/`authenticated`
--    en todo lo nuevo. Al final hay REVOKE explícitos y una
--    comprobación en information_schema, no solo de políticas.
-- ============================================================

begin;

-- ============================================================
-- 1 · LOS TRES PAPELES
-- ------------------------------------------------------------
-- `rol` es de un solo valor y lo usan es_admin() y es_staff(),
-- de los que depende el panel entero. Andrés y Adrián son admin
-- Y tesorería a la vez: si el papel fuera un `rol` habría que
-- quitarles el de admin y perderían el panel.
--
-- Por eso el papel va en una columna aparte, `papeles`, que
-- admite varios. `rol` se queda como está y además se le abren
-- los tres valores nuevos por si algún día entra alguien que
-- SOLO es contable o SOLO es de la junta.
-- ============================================================

alter table public.perfiles
  add column if not exists papeles text[];

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'perfiles_papeles_check') then
    alter table public.perfiles
      add constraint perfiles_papeles_check
      check (papeles is null or papeles <@ array['tesoreria','contabilidad','junta']::text[]);
  end if;
end $$;

comment on column public.perfiles.papeles is
  'Papeles del dinero, sueltos del rol: tesoreria (fija cuotas y aprueba), '
  'contabilidad (gira remesas y transferencias), junta (sin acceso a dinero). '
  'Se ponen desde el panel. Ver docs/tesoreria.md.';

-- `rol` acepta ahora también los tres, para quien no sea ni admin
-- ni entrenador ni atleta. No cambia ninguna fila existente.
do $$
begin
  if exists (select 1 from pg_constraint where conname = 'perfiles_rol_check') then
    alter table public.perfiles drop constraint perfiles_rol_check;
  end if;
  alter table public.perfiles
    add constraint perfiles_rol_check
    check (rol = any (array['admin','coordinador','entrenador','atleta','padre',
                            'tesoreria','contabilidad','junta']::text[]));
end $$;

-- ------------------------------------------------------------
-- Anti-escalada: la columna nueva se protege igual que `areas`
-- y que `rol`. NO se toca ninguno de los dos disparadores que
-- ya existen (trg_perfiles_protege_areas, trg_perfiles_protege_rol):
-- este es un tercero, independiente, solo para `papeles`.
--
-- Hace falta porque la política «escritura_propia» deja que
-- cualquiera actualice su propia fila: sin esto, cualquier
-- socio podría ponerse el papel de tesorería.
-- ------------------------------------------------------------
create or replace function public.perfiles_protege_papeles()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is not null and not public.es_admin() then
    new.papeles := old.papeles;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_perfiles_protege_papeles on public.perfiles;
create trigger trg_perfiles_protege_papeles
  before update on public.perfiles
  for each row execute function public.perfiles_protege_papeles();

-- ------------------------------------------------------------
-- Quién es quién. Todas siguen el mismo patrón que es_admin():
-- se busca por el correo del testigo de sesión.
-- ------------------------------------------------------------

-- Tesorería: fija cuotas y aprueba excepciones.
-- Los admin de hoy (Andrés y Adrián) son tesorería sin tocar nada:
-- así el panel sigue funcionando igual el minuto después de aplicar esto.
create or replace function public.es_tesoreria()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and coalesce(p.activo, true)
      and (p.rol in ('admin','tesoreria') or 'tesoreria' = any(coalesce(p.papeles, '{}')))
  );
$function$;

-- Contabilidad: socios y adultos. Gira remesas y hace transferencias.
-- Hoy no la tiene nadie: el papel queda creado y vacío, esperando a Isabel.
create or replace function public.es_contabilidad()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and coalesce(p.activo, true)
      and (p.rol = 'contabilidad' or 'contabilidad' = any(coalesce(p.papeles, '{}')))
  );
$function$;

-- Junta: entra al panel, pero el dinero no es suyo.
create or replace function public.es_junta()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and coalesce(p.activo, true)
      and (p.rol = 'junta' or 'junta' = any(coalesce(p.papeles, '{}')))
  ) and not public.es_tesoreria() and not public.es_contabilidad();
$function$;

-- Ve el dinero: tesorería y contabilidad. La junta, no.
create or replace function public.ve_dinero()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select public.es_tesoreria() or public.es_contabilidad();
$function$;

-- Decide un importe (fijar cuota, aprobar una excepción): tesorería.
create or replace function public.puede_fijar_cuota()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select public.es_tesoreria();
$function$;

-- Ejecuta (girar la remesa, hacer la transferencia): contabilidad.
-- Los admin también, porque hoy no hay contable y alguien tiene que girar.
create or replace function public.puede_girar()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select public.es_contabilidad() or public.es_admin();
$function$;

-- es_staff(): se le añaden los tres papeles como rol, para que el día
-- que alguien entre SOLO como contable o SOLO como junta pueda usar el
-- panel. No cambia nada para los 15 perfiles de hoy: ninguno tiene esos
-- roles, así que la función devuelve exactamente lo mismo que antes.
create or replace function public.es_staff()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and p.rol in ('admin','coordinador','entrenador','tesoreria','contabilidad','junta')
  );
$function$;

-- Poner o quitar el papel del dinero a alguien, en un clic desde el panel.
-- Deja `areas` coherente para el filtro «Solo lo mío» del inicio, que ya
-- se apoya en esa columna (059_automatizaciones.sql).
create or replace function public.perfil_papel_dinero(p_perfil uuid, p_papel text)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_areas text[];
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador reparte los papeles del dinero.';
  end if;
  if p_papel is not null and p_papel not in ('tesoreria','contabilidad','junta') then
    raise exception 'Papel desconocido: %', p_papel;
  end if;

  v_areas := case p_papel
    when 'tesoreria'    then array['personas','dinero','web','liga','club']
    when 'contabilidad' then array['dinero']
    when 'junta'        then array['personas','web','liga','club']
    else null
  end;

  update public.perfiles
     set papeles = case when p_papel is null then null else array[p_papel] end,
         areas   = v_areas
   where id = p_perfil;

  return p_papel;
end;
$function$;

-- ============================================================
-- 2 · ESCUELA O SOCIO: SE ETIQUETA, NO SE DEDUCE
-- ------------------------------------------------------------
-- Decisión del club: cada persona lleva su etiqueta puesta al
-- darla de alta. Sin etiqueta NO se adivina por el año de
-- nacimiento: se dice «sin etiquetar».
--
-- Encaja con las dos cuentas bancarias: la escuela tiene la suya
-- y el club (socios y adultos) la otra.
-- ============================================================

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'atletas_tipo_membresia_check') then
    -- Antes de poner el candado, se limpia lo que no encaje.
    update public.atletas
       set tipo_membresia = null
     where tipo_membresia is not null
       and tipo_membresia not in ('escuela','socio');

    alter table public.atletas
      add constraint atletas_tipo_membresia_check
      check (tipo_membresia is null or tipo_membresia in ('escuela','socio'));
  end if;
end $$;

comment on column public.atletas.tipo_membresia is
  'Etiqueta de sección, puesta a mano al dar de alta: escuela o socio. '
  'NULL = sin etiquetar, y así se enseña. No se deduce del año de '
  'nacimiento, ni del grupo, ni de la tarifa.';

create index if not exists idx_atletas_tipo_membresia
  on public.atletas (tipo_membresia);

-- ------------------------------------------------------------
-- La cuota mensual de cada ficha. Hasta hoy no existía: en el
-- panel se enseñaba el importe del último recibo, que es otra
-- cosa (lo cobrado, no lo acordado).
-- ------------------------------------------------------------
alter table public.atletas
  add column if not exists cuota_mensual   numeric(8,2),
  add column if not exists cuota_nota      text,
  add column if not exists cuota_fijada_por uuid,
  add column if not exists cuota_fijada_en timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'atletas_cuota_mensual_check') then
    alter table public.atletas
      add constraint atletas_cuota_mensual_check
      check (cuota_mensual is null or cuota_mensual >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'atletas_cuota_fijada_por_fkey') then
    alter table public.atletas
      add constraint atletas_cuota_fijada_por_fkey
      foreign key (cuota_fijada_por) references public.perfiles(id) on delete set null;
  end if;
end $$;

comment on column public.atletas.cuota_mensual is
  'Cuota acordada con esta persona. La fija tesorería (dinero_fijar_cuota); '
  'contabilidad la ve y pide el cambio (dinero_pedir_cambio_cuota).';

-- ============================================================
-- 3 · EL CONTACTO DE PAGOS DEPENDE DE LA SECCIÓN
-- ------------------------------------------------------------
-- No del tipo de duda. La tabla `info_pagos` ya tiene las dos
-- filas y los campos de contacto; estaban vacíos. Solo se
-- rellena lo que esté en blanco: si el club ya escribió algo,
-- manda lo suyo.
--
-- El correo de Isabel NO se inventa: se queda vacío hasta que
-- el club lo escriba desde el panel.
-- ============================================================

update public.info_pagos
   set contacto_nombre     = coalesce(nullif(btrim(contacto_nombre), ''), 'Adrián Onandía · presidente'),
       contacto_email      = coalesce(nullif(btrim(contacto_email), ''), 'escuelaapolana@gmail.com'),
       contacto_alt_nombre = coalesce(nullif(btrim(contacto_alt_nombre), ''), 'Andrés Clavero · tesorero'),
       contacto_alt_email  = coalesce(nullif(btrim(contacto_alt_email), ''), 'andres.apolana@gmail.com')
 where clave = 'escuela';

update public.info_pagos
   set contacto_nombre = coalesce(nullif(btrim(contacto_nombre), ''), 'Isabel Fuentes · contable')
 where clave = 'club';

-- ============================================================
-- 4 · LOS AVISOS DE DINERO: EL FLUJO DE DOS PASOS
-- ------------------------------------------------------------
-- Las dos direcciones en una sola tabla:
--   · contabilidad pide un cambio de cuota → le llega a tesorería
--   · tesorería cambia una cuota           → le llega a contabilidad
--     para que lo tenga en cuenta en la remesa
--
-- No es un permiso que bloquea: es un aviso entre los dos.
-- ============================================================

create table if not exists public.dinero_avisos (
  id                uuid primary key default gen_random_uuid(),
  tipo              text not null,
  para              text not null,
  seccion           text,
  atleta_id         uuid references public.atletas(id) on delete cascade,
  importe_actual    numeric(8,2),
  importe_propuesto numeric(8,2),
  motivo            text,
  estado            text not null default 'pendiente',
  respuesta         text,
  creado_por        uuid references public.perfiles(id) on delete set null,
  created_at        timestamptz not null default now(),
  resuelto_por      uuid references public.perfiles(id) on delete set null,
  resuelto_en       timestamptz,
  -- Vía 2 · aviso al móvil. Se sella cuando la función `aviso-enviar`
  -- lo ha mandado (categoría «pagos»).
  movil_en          timestamptz,
  -- Vía 3 · correo. HOY NO EXISTE: el club no manda correos
  -- automáticos. Estas dos columnas son el enganche, y se quedan
  -- siempre en NULL hasta que se monte. Ver docs/tesoreria.md.
  correo_en         timestamptz,
  correo_error      text
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'dinero_avisos_tipo_check') then
    alter table public.dinero_avisos add constraint dinero_avisos_tipo_check
      check (tipo in ('cambio_cuota','cuota_fijada','excepcion'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'dinero_avisos_para_check') then
    alter table public.dinero_avisos add constraint dinero_avisos_para_check
      check (para in ('tesoreria','contabilidad'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'dinero_avisos_estado_check') then
    alter table public.dinero_avisos add constraint dinero_avisos_estado_check
      check (estado in ('pendiente','aprobado','rechazado','visto'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'dinero_avisos_seccion_check') then
    alter table public.dinero_avisos add constraint dinero_avisos_seccion_check
      check (seccion is null or seccion in ('escuela','club'));
  end if;
end $$;

create index if not exists idx_dinero_avisos_pendientes
  on public.dinero_avisos (para, estado, created_at desc);
create index if not exists idx_dinero_avisos_atleta
  on public.dinero_avisos (atleta_id);

comment on table public.dinero_avisos is
  'Avisos entre tesorería y contabilidad. Quien decide un importe y quien '
  'lo ejecuta no son la misma persona: aquí queda el paso entre los dos.';

alter table public.dinero_avisos enable row level security;

-- Se lee según el papel; se escribe SOLO por las funciones de abajo.
drop policy if exists "dinero lee sus avisos" on public.dinero_avisos;
create policy "dinero lee sus avisos" on public.dinero_avisos
  for select to authenticated
  using (
    public.es_tesoreria()
    or (public.es_contabilidad() and (para = 'contabilidad' or creado_por = public.mi_perfil_id()))
  );

-- ------------------------------------------------------------
-- Qué sección le toca a un atleta. Sin etiqueta, NULL: no se
-- adivina, y el aviso sale como «sin etiquetar».
-- ------------------------------------------------------------
create or replace function public.dinero_seccion_de(p_atleta uuid)
returns text
language sql
stable security definer
set search_path to 'public'
as $function$
  select case a.tipo_membresia when 'escuela' then 'escuela' when 'socio' then 'club' else null end
    from public.atletas a where a.id = p_atleta;
$function$;

-- ------------------------------------------------------------
-- Contabilidad pide un cambio de cuota → aviso a tesorería.
-- ------------------------------------------------------------
create or replace function public.dinero_pedir_cambio_cuota(
  p_atleta uuid, p_importe numeric, p_motivo text default null)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_id uuid;
begin
  if not public.ve_dinero() then
    raise exception 'Esto es cosa de tesorería o de contabilidad.';
  end if;
  if p_importe is not null and p_importe < 0 then
    raise exception 'La cuota no puede ser negativa.';
  end if;

  insert into public.dinero_avisos
    (tipo, para, seccion, atleta_id, importe_actual, importe_propuesto, motivo, creado_por)
  select 'cambio_cuota', 'tesoreria', public.dinero_seccion_de(p_atleta), p_atleta,
         a.cuota_mensual, p_importe, nullif(btrim(p_motivo), ''), public.mi_perfil_id()
    from public.atletas a where a.id = p_atleta
  returning id into v_id;

  if v_id is null then raise exception 'Esa ficha no existe.'; end if;
  return v_id;
end;
$function$;

-- ------------------------------------------------------------
-- Tesorería fija la cuota → aviso a contabilidad para la remesa.
-- ------------------------------------------------------------
create or replace function public.dinero_fijar_cuota(
  p_atleta uuid, p_importe numeric, p_nota text default null)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_id uuid; v_antes numeric(8,2);
begin
  if not public.puede_fijar_cuota() then
    raise exception 'Cambiar una cuota es cosa de tesorería.';
  end if;
  if p_importe is not null and p_importe < 0 then
    raise exception 'La cuota no puede ser negativa.';
  end if;

  select cuota_mensual into v_antes from public.atletas where id = p_atleta;
  if not found then raise exception 'Esa ficha no existe.'; end if;

  update public.atletas
     set cuota_mensual    = p_importe,
         cuota_nota       = nullif(btrim(p_nota), ''),
         cuota_fijada_por = public.mi_perfil_id(),
         cuota_fijada_en  = now()
   where id = p_atleta;

  -- Aunque hoy no haya contable, el aviso se guarda igual: el día que
  -- Isabel tenga cuenta se encuentra el historial hecho.
  insert into public.dinero_avisos
    (tipo, para, seccion, atleta_id, importe_actual, importe_propuesto, motivo, creado_por)
  values ('cuota_fijada', 'contabilidad', public.dinero_seccion_de(p_atleta), p_atleta,
          v_antes, p_importe, nullif(btrim(p_nota), ''), public.mi_perfil_id())
  returning id into v_id;

  return v_id;
end;
$function$;

-- ------------------------------------------------------------
-- Resolver un aviso. Tesorería aprueba o rechaza lo que le piden;
-- contabilidad solo da por visto lo que le llega.
-- Al aprobar un cambio de cuota se aplica de verdad y se devuelve
-- el aviso al que lo pidió: el círculo se cierra.
-- ------------------------------------------------------------
create or replace function public.dinero_resolver(
  p_id uuid, p_estado text, p_respuesta text default null)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v public.dinero_avisos%rowtype; v_nuevo uuid;
begin
  select * into v from public.dinero_avisos where id = p_id;
  if not found then raise exception 'Ese aviso ya no está.'; end if;
  if v.estado <> 'pendiente' then raise exception 'Ese aviso ya estaba resuelto.'; end if;

  if v.para = 'tesoreria' then
    if not public.es_tesoreria() then
      raise exception 'Aprobar un cambio de cuota es cosa de tesorería.';
    end if;
    if p_estado not in ('aprobado','rechazado') then
      raise exception 'Un aviso de tesorería se aprueba o se rechaza.';
    end if;
  else
    if not public.puede_girar() then
      raise exception 'Este aviso es de contabilidad.';
    end if;
    if p_estado <> 'visto' then
      raise exception 'Un aviso de contabilidad solo se da por visto.';
    end if;
  end if;

  update public.dinero_avisos
     set estado = p_estado,
         respuesta = nullif(btrim(p_respuesta), ''),
         resuelto_por = public.mi_perfil_id(),
         resuelto_en = now()
   where id = p_id;

  if p_estado = 'aprobado' and v.tipo = 'cambio_cuota' and v.atleta_id is not null then
    update public.atletas
       set cuota_mensual    = v.importe_propuesto,
           cuota_nota       = v.motivo,
           cuota_fijada_por = public.mi_perfil_id(),
           cuota_fijada_en  = now()
     where id = v.atleta_id;

    insert into public.dinero_avisos
      (tipo, para, seccion, atleta_id, importe_actual, importe_propuesto, motivo, creado_por)
    values ('cuota_fijada', 'contabilidad', v.seccion, v.atleta_id,
            v.importe_actual, v.importe_propuesto,
            'Aprobado el cambio que pidió contabilidad', public.mi_perfil_id())
    returning id into v_nuevo;
  end if;

  return coalesce(v_nuevo, p_id);
end;
$function$;

-- Sellar que el aviso al móvil ya salió (vía 2 de las tres).
create or replace function public.dinero_marcar_movil(p_id uuid)
returns void
language sql
security definer
set search_path to 'public'
as $function$
  update public.dinero_avisos set movil_en = now()
   where id = p_id and public.ve_dinero() and movil_en is null;
$function$;

-- ------------------------------------------------------------
-- La bandeja del inicio, ya filtrada por el papel de quien entra.
-- Junta no recibe ni una fila.
-- ------------------------------------------------------------
create or replace function public.dinero_bandeja()
returns table (
  id uuid, tipo text, para text, seccion text,
  atleta_id uuid, atleta text,
  importe_actual numeric, importe_propuesto numeric,
  motivo text, created_at timestamptz, mio boolean
)
language sql
stable security definer
set search_path to 'public'
as $function$
  select d.id, d.tipo, d.para, d.seccion,
         d.atleta_id,
         nullif(btrim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')), ''),
         d.importe_actual, d.importe_propuesto, d.motivo, d.created_at,
         (d.creado_por = public.mi_perfil_id())
    from public.dinero_avisos d
    left join public.atletas a on a.id = d.atleta_id
   where d.estado = 'pendiente'
     and (
       (public.es_tesoreria() and d.para = 'tesoreria')
       or (public.puede_girar() and d.para = 'contabilidad')
     )
   order by d.created_at desc
   limit 50;
$function$;

-- A quién hay que avisar al móvil. Devuelve perfiles, nunca correos
-- ni teléfonos: la función `aviso-enviar` va por perfil.
create or replace function public.dinero_destinatarios(p_para text)
returns table (perfil_id uuid, nombre text)
language sql
stable security definer
set search_path to 'public'
as $function$
  select p.id, btrim(coalesce(p.nombre,'') || ' ' || coalesce(p.apellidos,''))
    from public.perfiles p
   where public.ve_dinero()
     and coalesce(p.activo, true)
     and (
       (p_para = 'tesoreria'
         and (p.rol in ('admin','tesoreria') or 'tesoreria' = any(coalesce(p.papeles,'{}'))))
       or
       (p_para = 'contabilidad'
         and (p.rol = 'contabilidad' or 'contabilidad' = any(coalesce(p.papeles,'{}'))))
     );
$function$;

-- ------------------------------------------------------------
-- Etiquetar en bloque las fichas que están sin etiquetar.
-- La sugerencia por año de nacimiento se DEVUELVE como sugerencia,
-- para enseñarla al lado; no se aplica sola nunca.
-- ------------------------------------------------------------
create or replace function public.atletas_sin_etiqueta()
returns table (
  id uuid, nombre text, apellidos text,
  fecha_nacimiento date, grupo text, sugerencia text
)
language sql
stable security definer
set search_path to 'public'
as $function$
  select a.id, a.nombre, a.apellidos, a.fecha_nacimiento, g.nombre,
         case
           when a.fecha_nacimiento is null then null
           when extract(year from a.fecha_nacimiento) >= 2009 then 'escuela'
           else 'socio'
         end
    from public.atletas a
    left join public.grupos g on g.id = a.grupo_id
   where public.ve_dinero()
     and a.tipo_membresia is null
   order by a.apellidos nulls last, a.nombre;
$function$;

create or replace function public.atletas_etiquetar(p_ids uuid[], p_tipo text)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare n integer;
begin
  if not public.ve_dinero() then
    raise exception 'Etiquetar es cosa de tesorería o de contabilidad.';
  end if;
  if p_tipo is not null and p_tipo not in ('escuela','socio') then
    raise exception 'La etiqueta es escuela o socio.';
  end if;
  update public.atletas set tipo_membresia = p_tipo
   where id = any(coalesce(p_ids, '{}'::uuid[]));
  get diagnostics n = row_count;
  return n;
end;
$function$;

-- Cuántas quedan sin etiquetar, para la fila de la bandeja.
create or replace function public.atletas_sin_etiqueta_cuantos()
returns integer
language sql
stable security definer
set search_path to 'public'
as $function$
  select case when public.ve_dinero()
              then (select count(*)::int from public.atletas where tipo_membresia is null)
              else 0 end;
$function$;

-- ------------------------------------------------------------
-- Quién soy yo para el dinero. Una sola llamada, y el panel ya
-- sabe qué botón encender y cómo arrancar «Solo lo mío».
-- ------------------------------------------------------------
create or replace function public.dinero_quien_soy()
returns jsonb
language sql
stable security definer
set search_path to 'public'
as $function$
  select jsonb_build_object(
    'papel', case
               when public.es_tesoreria()    then 'tesoreria'
               when public.es_contabilidad() then 'contabilidad'
               when public.es_junta()        then 'junta'
               else null end,
    've_dinero',        public.ve_dinero(),
    'fija_cuotas',      public.puede_fijar_cuota(),
    'gira_remesas',     public.puede_girar(),
    'es_admin',         public.es_admin(),
    -- «Solo lo mío»: contabilidad lo trae activado y filtrado a socios
    -- y adultos; tesorería lo trae desactivado, porque lo ve todo.
    'solo_lo_mio',      public.es_contabilidad() and not public.es_tesoreria(),
    'seccion',          case when public.es_contabilidad() and not public.es_tesoreria()
                             then 'club' else null end
  );
$function$;

-- ============================================================
-- 5 · PERMISOS PARA QUE CONTABILIDAD PUEDA TRABAJAR
-- ------------------------------------------------------------
-- Se AÑADEN políticas; no se toca ni se quita ninguna de las que
-- ya había, así que admin, entrenadores y atletas siguen igual.
--
-- Contabilidad tiene SELECT sobre las fichas e INSERT/UPDATE
-- sobre los recibos (girar, marcar cobrado, marcar devuelto),
-- pero NO UPDATE sobre las fichas: por eso la cuota se cambia
-- por la función y no a mano. Borrar recibos sigue siendo de
-- admin (064_borrado_solo_admin.sql).
-- ============================================================

drop policy if exists "dinero ve las fichas" on public.atletas;
create policy "dinero ve las fichas" on public.atletas
  for select to authenticated using (public.ve_dinero());

drop policy if exists "contabilidad ve los recibos" on public.pagos;
create policy "contabilidad ve los recibos" on public.pagos
  for select to authenticated using (public.ve_dinero());

drop policy if exists "contabilidad gira recibos" on public.pagos;
create policy "contabilidad gira recibos" on public.pagos
  for insert to authenticated with check (public.puede_girar());

drop policy if exists "contabilidad actualiza recibos" on public.pagos;
create policy "contabilidad actualiza recibos" on public.pagos
  for update to authenticated
  using (public.puede_girar()) with check (public.puede_girar());

-- Los nombres y correos del equipo, para poder escribirle a quien toca.
drop policy if exists "dinero lee perfiles" on public.perfiles;
create policy "dinero lee perfiles" on public.perfiles
  for select to authenticated using (public.ve_dinero());

-- Las tarifas las fija tesorería; contabilidad solo las lee (ya es pública).
drop policy if exists "tesoreria gestiona tarifas" on public.tarifas;
create policy "tesoreria gestiona tarifas" on public.tarifas
  for all to authenticated
  using (public.es_tesoreria()) with check (public.es_tesoreria());

-- ============================================================
-- 6 · PERMISOS DE TABLA · REVOKE EXPLÍCITO
-- ------------------------------------------------------------
-- Supabase tiene un «alter default privileges … grant all» que
-- reparte permisos solos a anon y authenticated en todo lo que se
-- crea. Las políticas no bastan: TRUNCATE se salta el RLS.
-- Aquí se quita todo y se devuelve solo lo justo.
--
-- `dinero_avisos` se escribe SOLO por las funciones de arriba:
-- authenticated tiene SELECT y nada más. Ni INSERT, ni UPDATE,
-- ni DELETE, ni TRUNCATE.
-- ============================================================

revoke all on public.dinero_avisos from public, anon, authenticated;
grant select on public.dinero_avisos to authenticated;

-- Las funciones: fuera de anon en todas, y de `public` en las que
-- tocan datos. Solo se le da EXECUTE a authenticated.
revoke all on function public.perfiles_protege_papeles()                          from public, anon, authenticated;
revoke all on function public.perfil_papel_dinero(uuid, text)                     from public, anon, authenticated;
revoke all on function public.dinero_seccion_de(uuid)                             from public, anon, authenticated;
revoke all on function public.dinero_pedir_cambio_cuota(uuid, numeric, text)      from public, anon, authenticated;
revoke all on function public.dinero_fijar_cuota(uuid, numeric, text)             from public, anon, authenticated;
revoke all on function public.dinero_resolver(uuid, text, text)                   from public, anon, authenticated;
revoke all on function public.dinero_marcar_movil(uuid)                           from public, anon, authenticated;
revoke all on function public.dinero_bandeja()                                    from public, anon, authenticated;
revoke all on function public.dinero_destinatarios(text)                          from public, anon, authenticated;
revoke all on function public.dinero_quien_soy()                                  from public, anon, authenticated;
revoke all on function public.atletas_sin_etiqueta()                              from public, anon, authenticated;
revoke all on function public.atletas_sin_etiqueta_cuantos()                      from public, anon, authenticated;
revoke all on function public.atletas_etiquetar(uuid[], text)                     from public, anon, authenticated;
revoke all on function public.es_tesoreria()                                      from public, anon;
revoke all on function public.es_contabilidad()                                   from public, anon;
revoke all on function public.es_junta()                                          from public, anon;
revoke all on function public.ve_dinero()                                         from public, anon;
revoke all on function public.puede_fijar_cuota()                                 from public, anon;
revoke all on function public.puede_girar()                                       from public, anon;

grant execute on function public.perfil_papel_dinero(uuid, text)                  to authenticated;
grant execute on function public.dinero_pedir_cambio_cuota(uuid, numeric, text)   to authenticated;
grant execute on function public.dinero_fijar_cuota(uuid, numeric, text)          to authenticated;
grant execute on function public.dinero_resolver(uuid, text, text)                to authenticated;
grant execute on function public.dinero_marcar_movil(uuid)                        to authenticated;
grant execute on function public.dinero_bandeja()                                 to authenticated;
grant execute on function public.dinero_destinatarios(text)                       to authenticated;
grant execute on function public.dinero_quien_soy()                               to authenticated;
grant execute on function public.atletas_sin_etiqueta()                           to authenticated;
grant execute on function public.atletas_sin_etiqueta_cuantos()                   to authenticated;
grant execute on function public.atletas_etiquetar(uuid[], text)                  to authenticated;
grant execute on function public.es_tesoreria()                                   to authenticated;
grant execute on function public.es_contabilidad()                                to authenticated;
grant execute on function public.es_junta()                                       to authenticated;
grant execute on function public.ve_dinero()                                      to authenticated;
grant execute on function public.puede_fijar_cuota()                              to authenticated;
grant execute on function public.puede_girar()                                    to authenticated;

-- `dinero_seccion_de` y `perfiles_protege_papeles` no se llaman nunca
-- desde el navegador: se quedan sin EXECUTE para nadie de fuera.

commit;

-- ============================================================
-- COMPROBACIÓN · se mira lo que hay de verdad, no lo que debería
-- ============================================================

-- (a) Permisos reales de la tabla nueva. Lo esperado: una sola
--     línea, `authenticated | SELECT`. Si sale anon, o sale
--     TRUNCATE, algo ha fallado.
select 'permisos de tabla' as comprobacion, grantee,
       string_agg(privilege_type, ', ' order by privilege_type) as permisos
  from information_schema.role_table_grants
 where table_schema = 'public' and table_name = 'dinero_avisos'
   and grantee in ('anon','authenticated','public')
 group by grantee
 order by grantee;

-- (b) Permisos reales de las funciones nuevas. Lo esperado: ni una
--     fila. Si sale alguna, es que anon o public pueden ejecutarla.
select 'función abierta de más' as comprobacion,
       r.routine_name, r.grantee, r.privilege_type
  from information_schema.role_routine_grants r
 where r.routine_schema = 'public'
   and r.grantee in ('anon','PUBLIC','public')
   and r.routine_name like any (array['dinero\_%','atletas\_etiquetar','atletas\_sin\_etiqueta%',
                                 'es\_tesoreria','es\_contabilidad','es\_junta','ve\_dinero',
                                 'puede\_%','perfil\_papel\_dinero','perfiles\_protege\_papeles'])
 order by r.routine_name, r.grantee;

-- (c) Los tres papeles, a la vista. Hoy: contabilidad vacío.
select 'quién lleva qué' as comprobacion, nombre, apellidos, email, rol, papeles, areas
  from public.perfiles
 where rol in ('admin','tesoreria','contabilidad','junta')
    or papeles is not null
 order by rol, apellidos;

-- (d) Cuántas fichas están sin etiquetar.
select 'sin etiquetar' as comprobacion,
       count(*) filter (where tipo_membresia is null)   as sin_etiquetar,
       count(*) filter (where tipo_membresia = 'escuela') as escuela,
       count(*) filter (where tipo_membresia = 'socio')   as socios
  from public.atletas;
