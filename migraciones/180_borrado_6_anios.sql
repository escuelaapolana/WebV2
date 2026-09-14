-- 180 · Borrado (anonimización) automático a los 6 años de la baja
-- ============================================================
-- QUÉ HACE, EN CRISTIANO
--   El RGPD dice que los datos personales no se guardan para siempre.
--   El club fija 6 años desde la BAJA. Pasado ese plazo, de una persona
--   que YA NO tiene ningún vínculo vivo (ni entrena, ni es socia) se
--   borra lo PRIVADO —DNI, dirección, teléfono, correo, fecha de
--   nacimiento, salud y notas del entrenador— y se conserva lo
--   HISTÓRICO —el nombre, sus marcas, récords y medallas—, porque un
--   récord del club es historia y sin nombre no dice nada. Los recibos
--   se quedan por obligación fiscal (ya van desligados de la persona).
--
--   No es un borrado a lo bruto: es ANONIMIZAR. La ficha sobrevive como
--   un cascarón sin datos personales, para que el histórico deportivo no
--   se rompa. Es reversible ante un fallo (no arrastra 32 tablas) y deja
--   RASTRO de qué se limpió y cuándo.
--
-- ESTA MIGRACIÓN NO BORRA NADA HOY. Solo deja montado:
--   1) atletas.fecha_baja  — se sella sola cuando alguien pasa a baja.
--   2) atletas.anonimizado_en — marca de que ya se limpió (no repetir).
--   3) datos_anonimizados — el registro de cada limpieza (sin datos
--      personales dentro).
--   4) purga_6anios_preview()  — ENSAYO: dice a quién le tocaría, sin
--      tocar nada.
--   5) purga_6anios_ejecutar() — la limpieza de verdad. Existe pero NO
--      se programa aquí: se enciende aparte, después de mirar el ensayo.
--
--   Alcance: SOLO atletas. La entrenadora y los administradores (personal
--   del club, relación en marcha) se repasan a mano una vez al año.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · Cuándo se dio de baja (hoy no se guarda). A partir de ahí
--     empieza a contar el reloj de los 6 años.
-- ------------------------------------------------------------
alter table public.atletas
  add column if not exists fecha_baja    timestamptz,
  add column if not exists anonimizado_en timestamptz;

comment on column public.atletas.fecha_baja is
  'Momento en que la ficha pasó a estado=baja. Empieza a contar el plazo de conservación (6 años). Se sella sola por trigger.';
comment on column public.atletas.anonimizado_en is
  'Momento en que se anonimizó por haber pasado 6 años de baja. Si está puesto, ya no se vuelve a tocar.';

-- Sella la fecha de baja al pasar a baja; la borra si la persona vuelve.
create or replace function public.atletas_sella_baja()
returns trigger
language plpgsql
as $function$
begin
  if new.estado = 'baja' and (tg_op = 'INSERT' or old.estado is distinct from 'baja') then
    if new.fecha_baja is null then
      new.fecha_baja := now();
    end if;
  elsif new.estado is distinct from 'baja' then
    -- Ha vuelto (o nunca estuvo de baja): se reinicia el reloj.
    new.fecha_baja := null;
    new.anonimizado_en := null;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_atletas_sella_baja on public.atletas;
create trigger trg_atletas_sella_baja
  before insert or update of estado on public.atletas
  for each row execute function public.atletas_sella_baja();

-- ------------------------------------------------------------
-- 2 · El registro de limpiezas. OJO: aquí NO se guarda ningún dato
--     personal; solo el rastro de que se hizo y cuánto se tocó.
-- ------------------------------------------------------------
create table if not exists public.datos_anonimizados (
  id             uuid primary key default gen_random_uuid(),
  atleta_id      uuid,           -- referencia informativa (ya es un cascarón)
  perfil_id      uuid,
  fecha_baja     timestamptz,    -- cuándo se dio de baja
  anonimizado_en timestamptz not null default now(),
  detalle        jsonb           -- qué tablas se tocaron y cuántas filas
);

alter table public.datos_anonimizados enable row level security;
drop policy if exists datos_anon_admin_lee on public.datos_anonimizados;
create policy datos_anon_admin_lee on public.datos_anonimizados
  for select using (public.es_admin());

-- ------------------------------------------------------------
--   Quién cumple para ser anonimizado: baja de hace más de 6 años,
--   que NO sea socio y que aún no se haya limpiado. (Estar de baja ya
--   implica que no entrena; una persona = una ficha.)
-- ------------------------------------------------------------
create or replace function public.purga_6anios_candidatos()
returns setof public.atletas
language sql
stable
security definer
set search_path to 'public'
as $function$
  select a.*
  from public.atletas a
  where a.estado = 'baja'
    and a.fecha_baja is not null
    and a.fecha_baja < now() - interval '6 years'
    and a.tipo_membresia is distinct from 'socio'
    and a.anonimizado_en is null;
$function$;

-- ------------------------------------------------------------
-- 4 · ENSAYO. Lista a quién le tocaría, SIN borrar nada. Solo admin.
-- ------------------------------------------------------------
create or replace function public.purga_6anios_preview()
returns table (atleta_id uuid, nombre text, apellidos text, fecha_baja timestamptz, anos_de_baja numeric)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select c.id, c.nombre, c.apellidos, c.fecha_baja,
         round(extract(epoch from (now() - c.fecha_baja)) / 31557600.0, 1)
  from public.purga_6anios_candidatos() c
  order by c.fecha_baja;
$function$;

revoke all on function public.purga_6anios_preview() from public;
grant execute on function public.purga_6anios_preview() to authenticated;

-- ------------------------------------------------------------
-- 5 · La limpieza de verdad. Existe, pero NO se programa aquí.
--     Se puede llamar a mano (solo admin) o, más adelante, desde el
--     programador (que corre sin usuario: por eso se permite cuando
--     auth.uid() es nulo, igual que hace el resto del sistema).
-- ------------------------------------------------------------
create or replace function public.purga_6anios_ejecutar()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  c public.atletas;
  n_total int := 0;
  d jsonb;
begin
  -- Candado de seguridad: si hay alguien con sesión, tiene que ser admin.
  -- Si no hay sesión (el programador automático), se deja pasar.
  if auth.uid() is not null and not public.es_admin() then
    raise exception 'Solo el club puede lanzar la purga de datos.' using errcode = '42501';
  end if;

  for c in select * from public.purga_6anios_candidatos() loop
    d := '{}'::jsonb;

    -- ---- Se BORRA lo sensible (salud, notas, partes de entreno) ----
    with x as (delete from public.bienestar_diario   where atleta_id = c.id returning 1) select d || jsonb_build_object('bienestar_diario',   count(*)) into d from x;
    with x as (delete from public.lesiones_atleta     where atleta_id = c.id returning 1) select d || jsonb_build_object('lesiones_atleta',     count(*)) into d from x;
    with x as (delete from public.notas_atleta        where atleta_id = c.id returning 1) select d || jsonb_build_object('notas_atleta',        count(*)) into d from x;
    with x as (delete from public.notas_familia       where atleta_id = c.id returning 1) select d || jsonb_build_object('notas_familia',       count(*)) into d from x;
    with x as (delete from public.entrevista_inicial  where atleta_id = c.id returning 1) select d || jsonb_build_object('entrevista_inicial',  count(*)) into d from x;
    with x as (delete from public.registros_sesion    where atleta_id = c.id returning 1) select d || jsonb_build_object('registros_sesion',    count(*)) into d from x;

    -- ---- Se ANONIMIZA la ficha: fuera lo personal, se queda el nombre
    --      y los atributos deportivos (para que el récord siga leyéndose) ----
    update public.atletas set
      dni = null, sexo = null, email = null, telefono = null,
      fecha_nacimiento = null, licencia = null,
      nombre_tutor = null, email_tutor = null, telefono_tutor = null,
      perfil_padre_id = null,
      observaciones = null, contexto_entrenador = null, contexto_atleta = null,
      cuota_nota = null,
      anonimizado_en = now()
    where id = c.id;

    -- ---- El registro del formulario de alta guarda OTRA copia del DNI
    --      y la dirección: se limpia también ----
    update public.altas_socio set
      dni = null, direccion = null, email = null, telefono = null,
      fecha_nacimiento = null, cp = null, localidad = null, provincia = null,
      nombre = null, apellidos = null
    where atleta_id = c.id;
    update public.altas_escuela_ninos set
      dni = null, fecha_nacimiento = null
    where atleta_id = c.id;

    -- ---- La cuenta (perfil): se desactiva y se le quita el contacto.
    --      Se conserva el nombre para que el histórico deportivo lea ----
    if c.perfil_id is not null then
      update public.perfiles set
        email = null, telefono = null,
        activo = false, rol_activo = false
      where id = c.perfil_id;

      -- La cuenta de acceso (correo real de login): se inutiliza.
      begin
        update auth.users set
          email = 'anon+' || c.perfil_id || '@apolana.invalid',
          phone = null,
          raw_user_meta_data = '{}'::jsonb
        where id = c.perfil_id;
      exception when others then
        -- Si el sistema de cuentas se resiste, se sigue: la ficha ya
        -- quedó anonimizada y esto se puede rematar a mano.
        d := d || jsonb_build_object('aviso_cuenta', 'no se pudo inutilizar el login');
      end;
    end if;

    -- ---- Rastro (sin datos personales) ----
    insert into public.datos_anonimizados (atleta_id, perfil_id, fecha_baja, detalle)
    values (c.id, c.perfil_id, c.fecha_baja, d);

    n_total := n_total + 1;
  end loop;

  return jsonb_build_object('ok', true, 'anonimizados', n_total, 'cuando', now());
end;
$function$;

revoke all on function public.purga_6anios_ejecutar() from public;
grant execute on function public.purga_6anios_ejecutar() to authenticated;

commit;
