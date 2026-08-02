-- ============================================================
-- 071 · Papeles del club, tesorería y contabilidad
-- ------------------------------------------------------------
-- Fuentes: maquetas/v3/CORRECCION-DINERO.md (manda) y el encargo
-- del club de agosto de 2026.
--
-- EL REPARTO REAL DEL DINERO, confirmado por el club:
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
-- Y LA SEGUNDA REGLA, del dueño del club:
--   «Soy tesorero, admin, entrenador y atleta. Soy todo.»
--   En un club pequeño una persona lleva varios papeles. Hasta hoy
--   `perfiles.rol` era UNO, y para probar qué ve cada uno había que
--   cambiárselo en la base. Se acabó: ahora cada persona tiene la
--   LISTA de papeles que le han concedido y elige con cuál actúa.
--
-- QUÉ HACE ESTA MIGRACIÓN
--   1 · Varios papeles por persona (`perfiles.roles`) y un papel
--       activo (`perfiles.rol_activo`) que ella misma elige.
--       es_admin() y es_staff() responden según el ACTIVO.
--   2 · Los tres papeles del dinero: tesorería, contabilidad y junta.
--   3 · La etiqueta escuela/socio de cada ficha, puesta a mano,
--       nunca deducida: sin etiqueta = «sin etiquetar».
--   4 · La cuota mensual, que hasta hoy no existía en la ficha.
--   5 · Los avisos de dinero entre tesorería y contabilidad, en las
--       dos direcciones.
--   6 · Los permisos para que contabilidad pueda trabajar sin poder
--       cambiar importes.
--
-- Idempotente: se puede aplicar las veces que haga falta.
--
-- ⚠️ Supabase reparte permisos solos a `anon`/`authenticated`
--    en todo lo nuevo. Al final hay REVOKE explícitos y una
--    comprobación en information_schema, no solo de políticas.
-- ============================================================

begin;

-- ============================================================
-- 1 · VARIOS PAPELES POR PERSONA, Y UNO ACTIVO
-- ------------------------------------------------------------
-- Tres columnas, y ninguna pisa a la otra:
--
--   rol         el de siempre. NO se toca. Es el papel principal
--               y sigue siendo el que vale cuando no se ha elegido
--               ningún otro. Todo lo que ya existe sigue leyéndolo.
--   roles       la lista de papeles CONCEDIDOS. Concederlos es cosa
--               de administración, y solo de administración.
--   rol_activo  con cuál está actuando ahora. Lo elige la persona,
--               solo entre los suyos, y se recuerda porque vive en
--               la base, no en el navegador.
--
-- Para que no queden dos verdades: `rol` va SIEMPRE dentro de
-- `roles` (lo garantiza un disparador), y el papel que vale en
-- cada momento es `coalesce(rol_activo, rol)`. A medio plazo el
-- sitio donde mirar es `roles`; `rol` se queda como el principal
-- y como red de seguridad de todo lo escrito hasta hoy.
-- ============================================================

-- La columna `papeles` de una versión anterior de esta misma
-- migración se retira: su trabajo lo hace `roles`. Nunca llegó a
-- tener datos, así que no se pierde nada.
drop trigger if exists trg_perfiles_protege_papeles on public.perfiles;
drop function if exists public.perfiles_protege_papeles();
alter table public.perfiles drop constraint if exists perfiles_papeles_check;
alter table public.perfiles drop column if exists papeles;

alter table public.perfiles
  add column if not exists roles          text[],
  add column if not exists rol_activo     text,
  -- «Al entrar, abrir en»: NULL = el último que usé (maqueta 47a).
  add column if not exists papel_al_entrar text;

-- Los ocho papeles que existen. Los cinco de siempre y los tres
-- nuevos del dinero. `rol` acepta los mismos, para quien algún día
-- entre siendo SOLO contable o SOLO de la junta.
do $$
begin
  if exists (select 1 from pg_constraint where conname = 'perfiles_rol_check') then
    alter table public.perfiles drop constraint perfiles_rol_check;
  end if;
  alter table public.perfiles
    add constraint perfiles_rol_check
    check (rol = any (array['admin','coordinador','entrenador','atleta','padre',
                            'tesoreria','contabilidad','junta']::text[]));

  if not exists (select 1 from pg_constraint where conname = 'perfiles_roles_check') then
    alter table public.perfiles
      add constraint perfiles_roles_check
      check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre',
                                             'tesoreria','contabilidad','junta']::text[]);
  end if;

  -- El papel activo tiene que ser uno de los concedidos. Además del
  -- disparador de más abajo, que es quien lo corrige solo.
  if not exists (select 1 from pg_constraint where conname = 'perfiles_rol_activo_check') then
    alter table public.perfiles
      add constraint perfiles_rol_activo_check
      check (rol_activo is null or rol_activo = any(coalesce(roles, array[rol])));
  end if;

  -- Y el papel con el que se abre al entrar, lo mismo.
  if not exists (select 1 from pg_constraint where conname = 'perfiles_papel_al_entrar_check') then
    alter table public.perfiles
      add constraint perfiles_papel_al_entrar_check
      check (papel_al_entrar is null or papel_al_entrar = any(coalesce(roles, array[rol])));
  end if;
end $$;

comment on column public.perfiles.roles is
  'Todos los papeles concedidos a esta persona. Concederlos es cosa de '
  'administración. `rol` va siempre dentro. Ver docs/tesoreria.md.';
comment on column public.perfiles.rol_activo is
  'Con qué papel está actuando ahora. Lo elige ella, solo entre los suyos, '
  'y se recuerda. NULL = actúa con su papel principal (`rol`).';

-- ------------------------------------------------------------
-- Coherencia: `rol` nunca puede quedarse fuera de `roles`, y
-- `rol_activo` nunca puede apuntar a un papel que ya no se tiene.
-- Esto NO es seguridad, es que las tres columnas cuenten lo mismo.
-- Se llama «zz» para que corra el último de los disparadores.
-- ------------------------------------------------------------
create or replace function public.perfiles_roles_coherentes()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  new.roles := coalesce(new.roles, array[]::text[]);
  if new.rol is not null and not (new.rol = any(new.roles)) then
    new.roles := new.roles || new.rol;
  end if;
  if new.rol_activo is not null and not (new.rol_activo = any(new.roles)) then
    new.rol_activo := null;
  end if;
  if new.papel_al_entrar is not null and not (new.papel_al_entrar = any(new.roles)) then
    new.papel_al_entrar := null;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_perfiles_zz_roles_coherentes on public.perfiles;
create trigger trg_perfiles_zz_roles_coherentes
  before insert or update on public.perfiles
  for each row execute function public.perfiles_roles_coherentes();

-- ------------------------------------------------------------
-- ⚠️ ANTI-ESCALADA
-- Los dos disparadores que ya había (trg_perfiles_protege_areas y
-- trg_perfiles_protege_rol) NO se tocan: siguen tal cual y siguen
-- defendiendo `rol`, `email`, `seccion`, `activo` y `areas`.
--
-- Este es un tercero, independiente, solo para lo nuevo:
--
--   · `roles` (lo concedido) NO lo puede cambiar quien no sea
--     administración. Ni para sí mismo ni para nadie.
--   · `rol_activo` SÍ lo puede cambiar cualquiera, pero SOLO a un
--     papel que ya tuviera concedido. Elegir no concede nada.
--
-- Hace falta porque la política «escritura_propia» deja que
-- cualquiera actualice su propia fila.
--
-- Y ojo, esto es a propósito: si alguien está actuando como atleta,
-- es_admin() dice que no, y entonces tampoco puede repartir papeles
-- mientras esté así. Volver a administración es un clic y no está
-- bloqueado, porque cambiar de papel activo siempre se puede.
-- ------------------------------------------------------------
create or replace function public.perfiles_protege_roles()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null or public.es_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- Nadie se da de alta con papeles puestos por él mismo.
    new.roles := array[new.rol];
    new.rol_activo := null;
    new.papel_al_entrar := null;
    return new;
  end if;

  -- Conceder es de administración.
  new.roles := old.roles;

  -- Elegir, sí; pero solo entre los suyos. Vale para el papel activo y
  -- para el que se abre al entrar.
  if new.rol_activo is distinct from old.rol_activo
     and new.rol_activo is not null
     and not (new.rol_activo = any(coalesce(old.roles, array[old.rol]))) then
    new.rol_activo := old.rol_activo;
  end if;
  if new.papel_al_entrar is distinct from old.papel_al_entrar
     and new.papel_al_entrar is not null
     and not (new.papel_al_entrar = any(coalesce(old.roles, array[old.rol]))) then
    new.papel_al_entrar := old.papel_al_entrar;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_perfiles_protege_roles on public.perfiles;
create trigger trg_perfiles_protege_roles
  before insert or update on public.perfiles
  for each row execute function public.perfiles_protege_roles();

-- ------------------------------------------------------------
-- Todo el mundo arranca con su papel de siempre, y solo con ese.
-- Nadie gana nada con esta migración.
-- ------------------------------------------------------------
update public.perfiles
   set roles = array[rol]
 where roles is null or roles = '{}'::text[];

-- Andrés Clavero es el dueño del club y los tiene los cuatro de
-- verdad: administración, tesorería, entrenador y atleta. Se le
-- AÑADEN, no se le sustituyen: si mañana le ponen otro desde el
-- panel, volver a aplicar esto no se lo quita.
update public.perfiles
   set roles = (select array(select distinct unnest(
                  coalesce(roles, '{}'::text[]) ||
                  array['admin','tesoreria','entrenador','atleta']::text[])))
 where email = 'andres.apolana@gmail.com';

-- Adrián Onandía es presidente y lleva la escuela: administración y
-- tesorería. Se le añade el papel de tesorero porque ahora son dos
-- cosas distintas y, sin él, dejaría de poder tocar cobros.
update public.perfiles
   set roles = (select array(select distinct unnest(
                  coalesce(roles, '{}'::text[]) ||
                  array['admin','tesoreria']::text[])))
 where email = 'escuelaapolana@gmail.com';

-- ------------------------------------------------------------
-- QUIÉN ES QUIÉN
-- Todas miran el papel ACTIVO, no la lista entera: esa es la gracia.
-- Si Andrés está actuando como atleta, es_admin() dice que no y el
-- panel no le deja entrar. Así se prueba de verdad lo que ve cada uno.
-- ------------------------------------------------------------

-- El papel con el que estoy actuando ahora mismo.
create or replace function public.mi_rol()
returns text
language sql
stable security definer
set search_path to 'public'
as $function$
  select coalesce(p.rol_activo, p.rol)
    from public.perfiles p
   where p.email = (auth.jwt() ->> 'email')
   limit 1;
$function$;

-- ¿Tengo concedido este papel? (No: ¿estoy actuando con él?)
create or replace function public.tengo_rol(p_rol text)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and p_rol = any(coalesce(p.roles, array[p.rol]))
  );
$function$;

-- es_admin(): igual que siempre, pero mirando el papel activo.
-- Con `rol_activo` a NULL en todo el mundo (que es como queda tras
-- aplicar esto) devuelve exactamente lo mismo que antes.
create or replace function public.es_admin()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and coalesce(p.rol_activo, p.rol) = 'admin'
  );
$function$;

-- es_staff(): lo mismo, y se le suman los tres papeles nuevos para
-- que quien entre SOLO como contable o SOLO como junta pueda usar
-- el panel. Hoy no los tiene nadie: no cambia nada para los 15.
create or replace function public.es_staff()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and coalesce(p.rol_activo, p.rol)
          in ('admin','coordinador','entrenador','tesoreria','contabilidad','junta')
  );
$function$;

-- ------------------------------------------------------------
-- Cambiar de papel activo. Es lo único que la persona hace sola.
-- Solo entre los suyos; elegir no concede nada.
-- ------------------------------------------------------------
create or replace function public.rol_activo_poner(p_rol text)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_id uuid; v_roles text[]; v_principal text;
begin
  select p.id, coalesce(p.roles, array[p.rol]), p.rol
    into v_id, v_roles, v_principal
    from public.perfiles p
   where p.email = (auth.jwt() ->> 'email')
   limit 1;

  if v_id is null then
    raise exception 'No hay ninguna ficha con tu correo.';
  end if;

  -- NULL o el principal = volver a lo de siempre.
  if p_rol is null or p_rol = v_principal then
    update public.perfiles set rol_activo = null where id = v_id;
    return v_principal;
  end if;

  if not (p_rol = any(v_roles)) then
    raise exception 'Ese papel no es tuyo. Pídeselo a administración.';
  end if;

  update public.perfiles set rol_activo = p_rol where id = v_id;
  return p_rol;
end;
$function$;

-- Lo que el interruptor necesita saber, en una sola llamada.
create or replace function public.mis_papeles()
returns jsonb
language sql
stable security definer
set search_path to 'public'
as $function$
  select jsonb_build_object(
    'nombre',    btrim(coalesce(p.nombre,'') || ' ' || coalesce(p.apellidos,'')),
    'principal', p.rol,
    'activo',    coalesce(p.rol_activo, p.rol),
    'elegido',   p.rol_activo,                 -- null = está en el suyo de siempre
    'al_entrar', p.papel_al_entrar,            -- null = el último que usé
    'roles',     to_jsonb(coalesce(p.roles, array[p.rol]))
  )
    from public.perfiles p
   where p.email = (auth.jwt() ->> 'email')
   limit 1;
$function$;

-- ------------------------------------------------------------
-- «Al entrar, abrir en» (maqueta 47a). NULL = el último que usé,
-- que es lo que ya hace `rol_activo` por sí solo.
-- ------------------------------------------------------------
create or replace function public.rol_al_entrar_poner(p_rol text)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_id uuid; v_roles text[];
begin
  select p.id, coalesce(p.roles, array[p.rol]) into v_id, v_roles
    from public.perfiles p where p.email = (auth.jwt() ->> 'email') limit 1;
  if v_id is null then raise exception 'No hay ninguna ficha con tu correo.'; end if;

  if p_rol is not null and not (p_rol = any(v_roles)) then
    raise exception 'Ese papel no es tuyo. Pídeselo a administración.';
  end if;

  update public.perfiles set papel_al_entrar = p_rol where id = v_id;
  return p_rol;
end;
$function$;

-- Se llama justo después de entrar con la contraseña: si esa persona
-- ha fijado un papel de arranque, se le pone. Si no, se queda con el
-- último que usó, que es lo que ya había guardado.
create or replace function public.rol_al_entrar_aplicar()
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_id uuid; v_fijo text; v_roles text[]; v_rol text;
begin
  select p.id, p.papel_al_entrar, coalesce(p.roles, array[p.rol]), p.rol
    into v_id, v_fijo, v_roles, v_rol
    from public.perfiles p where p.email = (auth.jwt() ->> 'email') limit 1;
  if v_id is null then return null; end if;
  if v_fijo is null or not (v_fijo = any(v_roles)) then
    return coalesce((select rol_activo from public.perfiles where id = v_id), v_rol);
  end if;
  update public.perfiles
     set rol_activo = case when v_fijo = v_rol then null else v_fijo end
   where id = v_id;
  return v_fijo;
end;
$function$;

-- ------------------------------------------------------------
-- LO QUE TIENE PENDIENTE CADA PAPEL (maqueta 47a)
-- «Así se elige por el trabajo y no por el nombre, y se ve lo de los
--  otros papeles sin entrar.»
--
-- Se calcula de verdad, con los datos que ya hay. Lo que no se puede
-- calcular se devuelve NULL y la fila sale sin recuento: no se
-- inventa un número para rellenar.
--
-- Ojo: esto se mira con los papeles CONCEDIDOS, no con el activo. Es
-- justamente para ver el trabajo de los otros papeles sin ponérselos.
-- ------------------------------------------------------------
create or replace function public.papeles_pendientes()
returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_id uuid; v_roles text[]; v_hoy date := current_date;
  r jsonb := '{}'::jsonb;
  n int; m int; t text;
begin
  select p.id, coalesce(p.roles, array[p.rol]) into v_id, v_roles
    from public.perfiles p where p.email = (auth.jwt() ->> 'email') limit 1;
  if v_id is null then return r; end if;

  -- ATLETA · su próximo entreno, que es lo que va a mirar
  if 'atleta' = any(v_roles) then
    select g.nombre || ' · ' ||
           case when e.fecha = v_hoy then 'hoy'
                when e.fecha = v_hoy + 1 then 'mañana'
                else 'el ' || to_char(e.fecha, 'DD/MM') end
      into t
      from public.entrenamientos e
      join public.atletas a on a.grupo_id = e.grupo_id
      left join public.grupos g on g.id = e.grupo_id
     where a.perfil_id = v_id and e.fecha >= v_hoy
     order by e.fecha
     limit 1;
    r := r || jsonb_build_object('atleta', t);   -- NULL si no hay: fila sin recuento
  end if;

  -- FAMILIA · recibos sin cobrar de sus hijos
  if 'padre' = any(v_roles) then
    select count(*) into n
      from public.pagos pg
      join public.atletas a on a.id = pg.atleta_id
     where a.perfil_padre_id = v_id
       and (pg.estado = 'impagado'
            or (pg.estado = 'pendiente' and pg.fecha_vencimiento is not null and pg.fecha_vencimiento < v_hoy));
    r := r || jsonb_build_object('padre',
           case when n > 0 then n || case when n = 1 then ' recibo sin pagar' else ' recibos sin pagar' end end);
  end if;

  -- ENTRENADOR · entrenos de sus grupos de la última semana sin lista pasada
  if 'entrenador' = any(v_roles) then
    select count(*) into n
      from public.entrenamientos e
     where e.fecha between v_hoy - 7 and v_hoy
       and (e.entrenador_id = v_id
            or e.grupo_id in (select g.id from public.grupos g where g.entrenador_id = v_id))
       and not exists (select 1 from public.asistencia s where s.entrenamiento_id = e.id);
    r := r || jsonb_build_object('entrenador',
           case when n > 0 then n || ' por pasar lista' end);
  end if;

  -- TESORERO · cobros por resolver + cambios de cuota por aprobar
  if 'tesoreria' = any(v_roles) then
    select count(*) into n
      from public.pagos pg
     where pg.anulado = false
       and (pg.estado = 'impagado'
            or (pg.estado = 'pendiente' and pg.fecha_vencimiento is not null and pg.fecha_vencimiento < v_hoy));
    select count(*) into m
      from public.dinero_avisos d where d.estado = 'pendiente' and d.para = 'tesoreria';
    r := r || jsonb_build_object('tesoreria',
           case when n + m > 0 then
             trim(both ' · ' from
               coalesce(case when n > 0 then n || ' cobros por resolver' end, '') ||
               case when n > 0 and m > 0 then ' · ' else '' end ||
               coalesce(case when m > 0 then m || case when m = 1 then ' cuota por aprobar' else ' cuotas por aprobar' end end, ''))
           end);
  end if;

  -- CONTABILIDAD · lo que le han mandado y está sin ver
  if 'contabilidad' = any(v_roles) then
    select count(*) into n
      from public.dinero_avisos d where d.estado = 'pendiente' and d.para = 'contabilidad';
    r := r || jsonb_build_object('contabilidad',
           case when n > 0 then n || case when n = 1 then ' aviso de tesorería' else ' avisos de tesorería' end end);
  end if;

  -- ADMINISTRADOR · los avisos del panel, con los de la Liga aparte
  if 'admin' = any(v_roles) then
    select
      (select count(*) from public.liga_participaciones where estado = 'pendiente')
      into m;
    select m
      + (select count(*) from public.mensajes where coalesce(atendido, false) = false)
      + (select count(*) from public.solicitudes_inscripcion where coalesce(atendida, false) = false)
      + (select count(*) from public.peticiones_redes where estado = 'pendiente')
      into n;
    r := r || jsonb_build_object('admin',
           case when n > 0 then
             n || case when n = 1 then ' aviso' else ' avisos' end ||
             case when m > 0 then ' · ' || m || ' de la Liga' else '' end
           end);
  end if;

  -- JUNTA y COORDINACIÓN · no hay nada que contar que sea suyo y solo suyo.
  -- Se dejan sin recuento a propósito, antes que inventar un número.
  return r;
end;
$function$;

-- Repartir papeles: solo administración. Es lo que hará falta el día
-- que Isabel tenga cuenta: añadirle «contabilidad» y ya está.
-- Deja `areas` coherente con el papel del dinero, porque el filtro
-- «Solo lo mío» del inicio ya se apoya en esa columna
-- (059_automatizaciones.sql) y no se va a crear otra cosa al lado.
create or replace function public.perfil_roles_poner(p_perfil uuid, p_roles text[])
returns text[]
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_areas text[]; v_rol text;
begin
  if not public.es_admin() then
    raise exception 'Repartir papeles es cosa de administración.';
  end if;
  if p_roles is null or array_length(p_roles, 1) is null then
    raise exception 'Hay que dejarle al menos un papel.';
  end if;
  if not (p_roles <@ array['admin','coordinador','entrenador','atleta','padre',
                           'tesoreria','contabilidad','junta']::text[]) then
    raise exception 'Hay algún papel que no existe.';
  end if;

  select rol into v_rol from public.perfiles where id = p_perfil;
  if v_rol is null then raise exception 'Esa persona no existe.'; end if;

  v_areas := case
    when 'admin'        = any(p_roles) then array['personas','dinero','web','liga','club']
    when 'tesoreria'    = any(p_roles) then array['personas','dinero','web','liga','club']
    when 'contabilidad' = any(p_roles) then array['dinero']
    when 'junta'        = any(p_roles) then array['personas','web','liga','club']
    else null
  end;

  update public.perfiles
     set roles = p_roles,
         areas = coalesce(v_areas, areas)
   where id = p_perfil;

  return p_roles;
end;
$function$;

-- ============================================================
-- 2 · LOS TRES PAPELES DEL DINERO
-- ------------------------------------------------------------
-- Miran el papel activo, igual que es_admin().
--
-- ⚠️ ADMINISTRADOR Y TESORERO SON PAPELES DISTINTOS
-- (maquetas/v3/DECISIONES-Y-PAPELES.md, apartado 9):
--
--   · Tesorero      → cobros, cuotas, remesas, excepciones
--   · Administrador → contenido, Liga, fotos, personas, grupos
--
-- «Separarlos evita abrir una pantalla con 32 secciones cuando solo
--  vienes a girar una remesa.»
--
-- Con una salvedad para no dejar al club sin poder cobrar por un
-- reparto a medias: si a alguien SOLO le han dado administración,
-- administración le sigue valiendo para el dinero. En cuanto tiene
-- también el papel de tesorero, tiene que ponérselo para tocarlo.
-- ============================================================

-- Tesorería: fija cuotas y aprueba excepciones.
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
      and (
        coalesce(p.rol_activo, p.rol) = 'tesoreria'
        or (coalesce(p.rol_activo, p.rol) = 'admin'
            and not ('tesoreria' = any(coalesce(p.roles, array[p.rol]))))
      )
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
      and coalesce(p.rol_activo, p.rol) = 'contabilidad'
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
      and coalesce(p.rol_activo, p.rol) = 'junta'
  );
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
-- Y tesorería también, porque hoy no hay contable y alguien tiene que
-- girar. Administración a secas ya no: para el dinero está el papel de
-- tesorero, que es un clic.
create or replace function public.puede_girar()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select public.es_contabilidad() or public.es_tesoreria();
$function$;

-- ============================================================
-- 3 · ESCUELA O SOCIO: SE ETIQUETA, NO SE DEDUCE
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
  add column if not exists cuota_mensual    numeric(8,2),
  add column if not exists cuota_nota       text,
  add column if not exists cuota_fijada_por uuid,
  add column if not exists cuota_fijada_en  timestamptz;

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
-- 4 · EL CONTACTO DE PAGOS DEPENDE DE LA SECCIÓN
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
-- 5 · LOS AVISOS DE DINERO: EL FLUJO DE DOS PASOS
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
--
-- Ojo: aquí se mira lo CONCEDIDO (`roles`), no el papel activo. Si
-- Andrés está probando el panel como atleta, el aviso de tesorería
-- le tiene que llegar igual: los avisos son de la persona, no del
-- papel con el que esté mirando en ese momento.
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
         and (coalesce(p.roles, array[p.rol]) && array['admin','tesoreria']::text[]))
       or
       (p_para = 'contabilidad'
         and ('contabilidad' = any(coalesce(p.roles, array[p.rol]))))
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
-- 6 · PERMISOS PARA QUE CONTABILIDAD PUEDA TRABAJAR
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
-- 7 · PERMISOS DE TABLA · REVOKE EXPLÍCITO
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
revoke all on function public.perfiles_protege_roles()                            from public, anon, authenticated;
revoke all on function public.perfiles_roles_coherentes()                         from public, anon, authenticated;
revoke all on function public.perfil_roles_poner(uuid, text[])                    from public, anon, authenticated;
revoke all on function public.rol_activo_poner(text)                              from public, anon, authenticated;
revoke all on function public.rol_al_entrar_poner(text)                           from public, anon, authenticated;
revoke all on function public.rol_al_entrar_aplicar()                             from public, anon, authenticated;
revoke all on function public.papeles_pendientes()                                from public, anon, authenticated;
revoke all on function public.mis_papeles()                                       from public, anon, authenticated;
revoke all on function public.mi_rol()                                            from public, anon, authenticated;
revoke all on function public.tengo_rol(text)                                     from public, anon, authenticated;
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

grant execute on function public.perfil_roles_poner(uuid, text[])                 to authenticated;
grant execute on function public.rol_activo_poner(text)                           to authenticated;
grant execute on function public.rol_al_entrar_poner(text)                        to authenticated;
grant execute on function public.rol_al_entrar_aplicar()                          to authenticated;
grant execute on function public.papeles_pendientes()                             to authenticated;
grant execute on function public.mis_papeles()                                    to authenticated;
grant execute on function public.mi_rol()                                         to authenticated;
grant execute on function public.tengo_rol(text)                                  to authenticated;
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

-- `dinero_seccion_de` y los dos disparadores no se llaman nunca desde
-- el navegador: se quedan sin EXECUTE para nadie de fuera.

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
                                 'puede\_%','perfil\_roles\_poner','rol\_activo\_poner',
                                 'rol\_al\_entrar\_%','papeles\_pendientes',
                                 'mis\_papeles','mi\_rol','tengo\_rol','perfiles\_protege\_roles'])
 order by r.routine_name, r.grantee;

-- (c) Los papeles de cada uno, a la vista. Hoy: contabilidad vacío
--     y Andrés con los cuatro.
select 'quién lleva qué' as comprobacion, nombre, apellidos, email,
       rol as principal, roles, rol_activo, areas
  from public.perfiles
 where cardinality(coalesce(roles,'{}')) > 1
    or rol in ('admin','tesoreria','contabilidad','junta')
 order by rol, apellidos;

-- (d) Nadie con el papel activo fuera de sus papeles concedidos.
--     Lo esperado: cero.
select 'papel activo imposible' as comprobacion, count(*) as cuantos
  from public.perfiles
 where rol_activo is not null
   and not (rol_activo = any(coalesce(roles, array[rol])));

-- (e) Cuántas fichas están sin etiquetar.
select 'sin etiquetar' as comprobacion,
       count(*) filter (where tipo_membresia is null)    as sin_etiquetar,
       count(*) filter (where tipo_membresia = 'escuela') as escuela,
       count(*) filter (where tipo_membresia = 'socio')   as socios
  from public.atletas;
