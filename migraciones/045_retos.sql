-- =====================================================================
-- 045_retos.sql  ·  RETOS, PUNTOS, MEDALLAS Y CLASIFICACIÓN
-- =====================================================================
-- Para qué sirve:
--
--   El club quiere animar a la gente a venir, a competir y a dejar
--   constancia de lo que hace. La idea es sencilla: el club propone
--   RETOS («ven a 8 entrenos este mes»), el sistema mira SOLO lo que ya
--   sabe y, cuando alguien llega al objetivo, le apunta unos PUNTOS.
--   Con los puntos se sube de RANGO y se ganan MEDALLAS, y el club
--   ofrece a cambio pequeños premios que escribe a mano en cada reto
--   (un entrenamiento de prueba en otro grupo, un descuento, etc.).
--
--   NADA se cumple a mano ni se teclea. No hay GPS ni kilómetros: todo
--   sale de las tablas que el club ya rellena cada día.
--
-- LAS OCHO MÉTRICAS (lo que se sabe medir)
--   asistencias           días con asistencia marcada como presente
--   racha_asistencias     la racha más larga de asistencias seguidas
--   entrenos_registrados  entrenos con sensaciones enviadas por el atleta
--   cubo_clases           clases de El Cubo con la reserva en «asistida»
--   competiciones         competiciones distintas con inscripción confirmada
--   marcas                marcas nuevas apuntadas (sin contar los objetivos)
--   mejores_personales    marcas apuntadas como mejor marca personal
--   tests                 baterías de tests en las que se participó
--
-- EL PERIODO de un reto puede ser esta semana, este mes, la temporada
--   (de septiembre a agosto) o unas fechas sueltas. Si el reto lleva
--   fechas escritas, mandan las fechas.
--
-- LA CLASIFICACIÓN VIENE APAGADA
--   La competición oficial del club es la Liga Apolana; los retos son
--   una cosa personal (tu progreso, tus puntos, tu rango, tus medallas).
--   La tabla comparativa está hecha, pero detrás de un interruptor que
--   el club enciende desde el panel. Apagado = no se ve en ningún sitio.
--
-- LO QUE SÍ EXISTE: LA FICHA PERSONAL
--   Con la sesión abierta se puede buscar a alguien del club y ver su
--   ficha: nombre elegido, foto, rango, puntos, medallas y los retos
--   que ha cumplido. Nada más: ni contacto, ni pagos, ni marcas.
--
-- DÓNDE VIVE LA IDENTIDAD
--   El nombre público y la foto están en `perfiles` (nombre_publico,
--   foto_ruta, perfil_visible) y se cambian en «Mi perfil» del portal.
--   Aquí solo se leen: este sistema no guarda ninguna foto.
--
-- QUIÉN SE DEJA VER (vale para la ficha, el buscador y la clasificación)
--   · Solo quien haya dicho que SÍ quiere participar. Se apaga cuando
--     se quiera y esa persona desaparece al momento de todas partes.
--   · Los MENORES de edad, solo si consta la autorización de su familia,
--     con quién la dio y cuándo. Sin ella no aparecen: ni nombre ni foto.
--   · Cada persona elige cómo aparece (su nombre o el que ella escriba)
--     y si pone foto, pero eso se hace en «Mi perfil», no aquí.
--   · Quien no ha entrado con su cuenta no ve absolutamente nada.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/045_retos.sql
-- Se puede volver a lanzar las veces que haga falta: no rompe nada.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. LOS RETOS
-- ---------------------------------------------------------------------
create table if not exists public.retos (
  id           uuid primary key default gen_random_uuid(),
  titulo       text not null,
  descripcion  text,
  metrica      text not null,
  objetivo     numeric not null default 1,
  periodo      text not null default 'mes',
  fecha_inicio date,
  fecha_fin    date,
  puntos       int not null default 10,
  premio       text,
  activo       boolean not null default true,
  created_at   timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'retos_metrica_check') then
    alter table public.retos add constraint retos_metrica_check
      check (metrica in ('asistencias','racha_asistencias','entrenos_registrados',
                         'cubo_clases','competiciones','marcas','mejores_personales','tests'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'retos_periodo_check') then
    alter table public.retos add constraint retos_periodo_check
      check (periodo in ('semana','mes','temporada','fechas'));
  end if;
  -- Un reto «de fechas sueltas» sin fechas no se sabría cuándo empieza.
  if not exists (select 1 from pg_constraint where conname = 'retos_fechas_check') then
    alter table public.retos add constraint retos_fechas_check
      check (periodo <> 'fechas' or (fecha_inicio is not null and fecha_fin is not null));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'retos_orden_fechas_check') then
    alter table public.retos add constraint retos_orden_fechas_check
      check (fecha_inicio is null or fecha_fin is null or fecha_fin >= fecha_inicio);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'retos_objetivo_check') then
    alter table public.retos add constraint retos_objetivo_check check (objetivo > 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'retos_puntos_check') then
    alter table public.retos add constraint retos_puntos_check check (puntos >= 0 and puntos <= 10000);
  end if;
end $$;

create index if not exists idx_retos_activo on public.retos (activo, created_at desc);

comment on table  public.retos is
  'Un reto del club: qué se mide, cuánto hay que llegar, en qué periodo, cuántos puntos da y qué premio ofrece el club.';
comment on column public.retos.metrica  is
  'Qué se cuenta: asistencias · racha_asistencias · entrenos_registrados · cubo_clases · competiciones · marcas · mejores_personales · tests.';
comment on column public.retos.periodo  is
  'semana (de lunes a domingo) · mes · temporada (1 de septiembre a 31 de agosto) · fechas (las escritas abajo).';
comment on column public.retos.premio   is
  'Lo que ofrece el club a quien lo consiga. Texto libre, lo escribe el club.';


-- ---------------------------------------------------------------------
-- 2. QUIÉN HA CUMPLIDO QUÉ
-- ---------------------------------------------------------------------
create table if not exists public.reto_logros (
  id               uuid primary key default gen_random_uuid(),
  reto_id          uuid not null references public.retos(id) on delete cascade,
  atleta_id        uuid not null references public.atletas(id) on delete cascade,
  valor_alcanzado  numeric,
  completado_en    timestamptz not null default now(),
  puntos_otorgados int not null default 0
);

do $$
begin
  -- Un reto se cumple UNA vez por persona: nunca se apilan puntos del mismo reto.
  if not exists (select 1 from pg_constraint where conname = 'reto_logros_unico') then
    alter table public.reto_logros add constraint reto_logros_unico unique (reto_id, atleta_id);
  end if;
end $$;

create index if not exists idx_reto_logros_atleta on public.reto_logros (atleta_id);
create index if not exists idx_reto_logros_reto   on public.reto_logros (reto_id);

comment on table public.reto_logros is
  'Reto conseguido por una persona. Lo escribe sola la función retos_actualizar(); no se rellena a mano.';


-- ---------------------------------------------------------------------
-- 3. LAS MEDALLAS · catálogo y las conseguidas
-- ---------------------------------------------------------------------
create table if not exists public.medallas (
  id          uuid primary key default gen_random_uuid(),
  clave       text not null unique,
  titulo      text not null,
  descripcion text,
  criterio    text not null,
  umbral      numeric not null default 1,
  orden       int not null default 0,
  activa      boolean not null default true,
  created_at  timestamptz not null default now()
);

do $$
begin
  -- Las medallas miden lo mismo que los retos, pero SIN periodo (de siempre),
  -- y además pueden mirar los retos completados o los puntos acumulados.
  if not exists (select 1 from pg_constraint where conname = 'medallas_criterio_check') then
    alter table public.medallas add constraint medallas_criterio_check
      check (criterio in ('asistencias','racha_asistencias','entrenos_registrados',
                          'cubo_clases','competiciones','marcas','mejores_personales','tests',
                          'retos_completados','puntos'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'medallas_umbral_check') then
    alter table public.medallas add constraint medallas_umbral_check check (umbral > 0);
  end if;
end $$;

create table if not exists public.atleta_medallas (
  id           uuid primary key default gen_random_uuid(),
  atleta_id    uuid not null references public.atletas(id) on delete cascade,
  medalla_id   uuid not null references public.medallas(id) on delete cascade,
  conseguida_en timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'atleta_medallas_unico') then
    alter table public.atleta_medallas add constraint atleta_medallas_unico unique (atleta_id, medalla_id);
  end if;
end $$;

create index if not exists idx_atleta_medallas_atleta on public.atleta_medallas (atleta_id);

comment on table public.medallas        is 'Catálogo de medallas: el hito que hay que alcanzar para conseguirlas.';
comment on table public.atleta_medallas is 'Medalla conseguida por una persona. La apunta sola retos_actualizar().';


-- ---------------------------------------------------------------------
-- 4. LOS RANGOS · la escala por puntos acumulados
-- ---------------------------------------------------------------------
-- Se guarda en una tabla para que el club pueda cambiar los nombres o
-- los cortes sin tocar ninguna pantalla.
create table if not exists public.juego_rangos (
  clave        text primary key,
  nombre       text not null,
  desde_puntos int not null,
  orden        int not null
);

insert into public.juego_rangos (clave, nombre, desde_puntos, orden) values
  ('debutante','Debutante',    0, 1),
  ('bronce',   'Bronce',      60, 2),
  ('plata',    'Plata',      150, 3),
  ('oro',      'Oro',        300, 4),
  ('platino',  'Platino',    550, 5),
  ('elite',    'Élite',      900, 6),
  ('leyenda',  'Leyenda',   1400, 7)
on conflict (clave) do nothing;

comment on table public.juego_rangos is
  'Escala de rangos por puntos acumulados. Se puede renombrar o mover los cortes sin tocar la web.';


-- ---------------------------------------------------------------------
-- 4 bis. EL INTERRUPTOR DE LA CLASIFICACIÓN
-- ---------------------------------------------------------------------
-- El club ya tiene su competición oficial, la Liga Apolana. Dos tablas a
-- la vez restarían fuerza a la liga, así que los retos nacen como algo
-- PERSONAL: tu progreso, tus puntos, tu rango y tus medallas.
--
-- La clasificación queda hecha pero APAGADA. Se enciende desde el panel
-- y el interruptor vive aquí, no en el navegador: mientras esté apagado,
-- la vista de clasificación no devuelve ni una fila, así que no se pinta
-- en ninguna parte aunque una pantalla lo intente.
create table if not exists public.juego_ajustes (
  id               int primary key default 1,
  ranking_publico  boolean not null default false,
  actualizado      timestamptz not null default now()
);

do $$
begin
  -- Un único juego de ajustes para todo el club: ni cero ni dos.
  if not exists (select 1 from pg_constraint where conname = 'juego_ajustes_una_fila') then
    alter table public.juego_ajustes add constraint juego_ajustes_una_fila check (id = 1);
  end if;
end $$;

insert into public.juego_ajustes (id) values (1) on conflict (id) do nothing;

comment on table  public.juego_ajustes is
  'Ajustes del sistema de retos. Una sola fila.';
comment on column public.juego_ajustes.ranking_publico is
  'Interruptor de la clasificación. Apagado de fábrica: la competición oficial del club es la Liga Apolana.';

-- ¿Está encendida la clasificación? Lo preguntan la vista y las pantallas.
create or replace function public.ranking_encendido()
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select coalesce((select ranking_publico from public.juego_ajustes where id = 1), false);
$function$;

grant execute on function public.ranking_encendido() to authenticated;


-- ---------------------------------------------------------------------
-- 5. EL PERFIL DE JUEGO · participación en los retos
-- ---------------------------------------------------------------------
-- OJO CON LA IDENTIDAD: el nombre público y la foto NO viven aquí. Viven
-- en `perfiles` (nombre_publico, foto_ruta, perfil_visible) y se cambian
-- desde «Mi perfil» del portal, que es donde la gente ya va a cambiar su
-- foto. Aquí solo está lo que es de los retos: si quiere participar y la
-- autorización familiar. Tener dos fotos en dos sitios acabaría dando
-- dos caras distintas a la misma persona.
create table if not exists public.perfil_juego (
  atleta_id             uuid primary key references public.atletas(id) on delete cascade,
  participa             boolean not null default false,
  autoriza_parental_por uuid references public.perfiles(id) on delete set null,
  autoriza_parental_en  timestamptz,
  puntos                int not null default 0,
  actualizado           timestamptz not null default now()
);

-- Si una versión anterior de este archivo guardó aquí el nombre y la foto,
-- se retiran: la identidad es de `perfiles` y de nadie más.
do $$
begin
  if exists (select 1 from pg_constraint where conname = 'perfil_juego_nombre_check') then
    alter table public.perfil_juego drop constraint perfil_juego_nombre_check;
  end if;
  if exists (select 1 from pg_constraint where conname = 'perfil_juego_foto_check') then
    alter table public.perfil_juego drop constraint perfil_juego_foto_check;
  end if;
end $$;
-- Las vistas del punto 9 se apoyaban en esas columnas, así que se
-- retiran primero; abajo se vuelven a crear ya leyendo de `perfiles`.
drop view if exists public.clasificacion_retos;
drop view if exists public.logros_publicos;
drop view if exists public.medallas_publicas;
drop view if exists public.miembros_juego;

alter table public.perfil_juego drop column if exists nombre_publico;
alter table public.perfil_juego drop column if exists foto_url;

do $$
begin
  -- Una autorización sin saber quién la dio no vale como autorización.
  if not exists (select 1 from pg_constraint where conname = 'perfil_juego_autoriza_check') then
    alter table public.perfil_juego add constraint perfil_juego_autoriza_check
      check (autoriza_parental_en is null or autoriza_parental_por is not null);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'perfil_juego_puntos_check') then
    alter table public.perfil_juego add constraint perfil_juego_puntos_check check (puntos >= 0);
  end if;
end $$;

create index if not exists idx_perfil_juego_puntos on public.perfil_juego (puntos desc) where participa;

comment on table  public.perfil_juego is
  'Cómo participa cada persona en los retos: si quiere dejarse ver y —si es menor— con qué autorización familiar. El nombre público y la foto están en perfiles.';
comment on column public.perfil_juego.participa is
  'Por defecto NO. Nadie se deja ver sin decirlo.';
comment on column public.perfil_juego.autoriza_parental_por is
  'Quién dio el permiso familiar. Obligatorio para que un menor se deje ver.';
comment on column public.perfil_juego.puntos is
  'Suma de los puntos de sus retos conseguidos. Lo calcula retos_actualizar(); no se escribe a mano.';


-- ---------------------------------------------------------------------
-- 6. AYUDANTES DE CÁLCULO
-- ---------------------------------------------------------------------

-- ¿Es menor de edad? Si no se sabe la fecha de nacimiento se trata como
-- menor: ante la duda, se protege.
create or replace function public.juego_es_menor(p_fnac date)
returns boolean
language sql stable
as $function$
  select p_fnac is null or p_fnac > (current_date - interval '18 years');
$function$;

-- De qué día a qué día cuenta un reto.
create or replace function public.reto_rango(p_periodo text, p_ini date, p_fin date, p_hoy date default current_date)
returns table (desde date, hasta date)
language sql stable
as $function$
  select
    case
      when p_ini is not null      then p_ini
      when p_periodo = 'semana'   then date_trunc('week',  p_hoy)::date
      when p_periodo = 'mes'      then date_trunc('month', p_hoy)::date
      when p_periodo = 'temporada' then
        case when extract(month from p_hoy) >= 9
             then make_date(extract(year from p_hoy)::int,     9, 1)
             else make_date(extract(year from p_hoy)::int - 1, 9, 1) end
      else date '1900-01-01'
    end,
    case
      when p_fin is not null      then p_fin
      when p_periodo = 'semana'   then (date_trunc('week',  p_hoy) + interval '6 days')::date
      when p_periodo = 'mes'      then (date_trunc('month', p_hoy) + interval '1 month - 1 day')::date
      when p_periodo = 'temporada' then
        case when extract(month from p_hoy) >= 9
             then make_date(extract(year from p_hoy)::int + 1, 8, 31)
             else make_date(extract(year from p_hoy)::int,     8, 31) end
      else date '2999-12-31'
    end;
$function$;

comment on function public.reto_rango(text,date,date,date) is
  'Convierte el periodo de un reto (semana/mes/temporada/fechas) en dos fechas concretas.';

-- EL CORAZÓN DEL SISTEMA: cuánto lleva cada persona en una métrica,
-- entre dos fechas. Todo sale de lo que el club ya apunta.
create or replace function public.juego_metrica(p_metrica text, p_desde date, p_hasta date)
returns table (atleta_id uuid, valor numeric)
language plpgsql stable security definer set search_path to 'public'
as $function$
#variable_conflict use_column
begin
  if p_metrica = 'asistencias' then
    -- Días con la casilla de «presente» marcada.
    return query
      select s.atleta_id, count(*)::numeric
        from public.asistencia s
       where s.presente is true and s.fecha between p_desde and p_hasta
       group by s.atleta_id;

  elsif p_metrica = 'racha_asistencias' then
    -- La tira más larga de asistencias seguidas: se numeran los días y se
    -- agrupan los que van pegados sin ninguna falta en medio.
    return query
      with dias as (
        select s.atleta_id as aid, s.fecha, s.presente,
               row_number() over (partition by s.atleta_id order by s.fecha)
             - row_number() over (partition by s.atleta_id, s.presente order by s.fecha) as bloque
          from public.asistencia s
         where s.fecha between p_desde and p_hasta
      ), rachas as (
        select d.aid, count(*)::numeric as largo
          from dias d where d.presente is true
         group by d.aid, d.bloque
      )
      select r.aid, max(r.largo) from rachas r group by r.aid;

  elsif p_metrica = 'entrenos_registrados' then
    -- Entrenos en los que el atleta mandó sus sensaciones.
    return query
      select r.atleta_id, count(*)::numeric
        from public.registros_sesion r
        join public.sesiones s on s.id = r.sesion_id
       where s.fecha between p_desde and p_hasta
       group by r.atleta_id;

  elsif p_metrica = 'cubo_clases' then
    -- Clases de El Cubo a las que se fue de verdad.
    return query
      select v.atleta_id, count(*)::numeric
        from public.cubo_reservas v
        join public.cubo_clases c on c.id = v.clase_id
       where v.estado = 'asistida' and c.fecha between p_desde and p_hasta
       group by v.atleta_id;

  elsif p_metrica = 'competiciones' then
    -- Competiciones distintas con la inscripción confirmada.
    return query
      select ca.atleta_id, count(distinct ca.competicion_id)::numeric
        from public.competicion_atleta ca
        join public.competiciones c on c.id = ca.competicion_id
       where ca.estado = 'confirmada' and c.fecha_inicio between p_desde and p_hasta
       group by ca.atleta_id;

  elsif p_metrica = 'marcas' then
    -- Marcas nuevas apuntadas. Los «objetivo» son deseos, no marcas hechas.
    return query
      select m.atleta_id, count(*)::numeric
        from public.marcas_atleta m
       where coalesce(m.tipo,'') <> 'objetivo' and m.fecha between p_desde and p_hasta
       group by m.atleta_id;

  elsif p_metrica = 'mejores_personales' then
    return query
      select m.atleta_id, count(*)::numeric
        from public.marcas_atleta m
       where m.tipo = 'mmp' and m.fecha between p_desde and p_hasta
       group by m.atleta_id;

  elsif p_metrica = 'tests' then
    -- Baterías de tests distintas en las que sí se participó.
    return query
      select t.atleta_id, count(distinct t.bateria_id)::numeric
        from public.test_resultados t
        join public.test_baterias b on b.id = t.bateria_id
       where t.no_asiste is false and b.fecha between p_desde and p_hasta
       group by t.atleta_id;

  -- --- Solo para medallas -------------------------------------------
  elsif p_metrica = 'retos_completados' then
    return query
      select l.atleta_id, count(*)::numeric
        from public.reto_logros l
       where l.completado_en::date between p_desde and p_hasta
       group by l.atleta_id;

  elsif p_metrica = 'puntos' then
    return query
      select pj.atleta_id, pj.puntos::numeric
        from public.perfil_juego pj
       where pj.puntos > 0;
  end if;
  return;
end;
$function$;

comment on function public.juego_metrica(text,date,date) is
  'Cuánto lleva cada atleta en una métrica entre dos fechas. Uso interno: solo la llaman las funciones de abajo.';

-- Nadie la llama desde el navegador: devolvería datos de todo el club.
revoke all on function public.juego_metrica(text,date,date) from public;

-- Cómo va UNA persona en cada reto activo (para la barra de progreso).
create or replace function public.retos_progreso_atleta(p_atleta uuid)
returns table (reto_id uuid, valor numeric)
language plpgsql stable security definer set search_path to 'public'
as $function$
#variable_conflict use_column
begin
  -- Sin atleta no hay nada que mirar, y un atleta que no es tuyo tampoco.
  -- El «is null» va delante a propósito: un nulo no es un permiso.
  if p_atleta is null or not (public.es_staff() or p_atleta in (select public.mis_atletas())) then
    raise exception 'No puedes consultar el progreso de este atleta.';
  end if;
  return query
    select r.id,
           coalesce((
             select m.valor
               from public.reto_rango(r.periodo, r.fecha_inicio, r.fecha_fin) g
               cross join lateral public.juego_metrica(r.metrica, g.desde, g.hasta) m
              where m.atleta_id = p_atleta
           ), 0)
      from public.retos r
     where r.activo;
end;
$function$;

grant execute on function public.retos_progreso_atleta(uuid) to authenticated;


-- ---------------------------------------------------------------------
-- 7. ACTUALIZAR EL PROGRESO · el botón del panel
-- ---------------------------------------------------------------------
-- Repasa los retos activos, apunta los que estén conseguidos, vuelve a
-- sumar los puntos de cada persona y reparte las medallas que tocan.
-- No quita nada de lo ya conseguido: un reto ganado, ganado se queda.
create or replace function public.retos_actualizar(p_reto uuid default null)
returns table (retos_revisados int, logros_nuevos int, medallas_nuevas int)
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_retos int := 0;
  v_logros int := 0;
  v_medallas int := 0;
  n int;
  r record;
begin
  if not public.es_staff() then
    raise exception 'Solo el equipo del club puede actualizar el progreso de los retos.';
  end if;

  -- 7.1 Retos conseguidos
  for r in select * from public.retos where activo and (p_reto is null or id = p_reto) loop
    v_retos := v_retos + 1;
    insert into public.reto_logros (reto_id, atleta_id, valor_alcanzado, puntos_otorgados)
    select r.id, m.atleta_id, m.valor, r.puntos
      from public.reto_rango(r.periodo, r.fecha_inicio, r.fecha_fin) g
      cross join lateral public.juego_metrica(r.metrica, g.desde, g.hasta) m
      join public.atletas a on a.id = m.atleta_id
     where m.valor >= r.objetivo
       and coalesce(a.estado,'activo') <> 'baja'
    on conflict (reto_id, atleta_id) do nothing;
    get diagnostics n = row_count;
    v_logros := v_logros + n;
  end loop;

  -- 7.2 Que todo el que tenga logros tenga ficha de juego
  insert into public.perfil_juego (atleta_id)
  select distinct l.atleta_id from public.reto_logros l
  on conflict (atleta_id) do nothing;

  -- 7.3 Los puntos se vuelven a sumar de cero: así una corrección se nota
  update public.perfil_juego pj
     set puntos = s.total, actualizado = now()
    from (
      select pj2.atleta_id,
             coalesce((select sum(l.puntos_otorgados)::int
                         from public.reto_logros l where l.atleta_id = pj2.atleta_id), 0) as total
        from public.perfil_juego pj2
    ) s
   where s.atleta_id = pj.atleta_id
     and pj.puntos is distinct from s.total;

  -- 7.4 Las medallas (se miran de siempre, sin periodo, y con los puntos ya al día)
  for r in select * from public.medallas where activa loop
    insert into public.atleta_medallas (atleta_id, medalla_id)
    select m.atleta_id, r.id
      from public.juego_metrica(r.criterio, date '1900-01-01', date '2999-12-31') m
      join public.atletas a on a.id = m.atleta_id
     where m.valor >= r.umbral
       and coalesce(a.estado,'activo') <> 'baja'
    on conflict (atleta_id, medalla_id) do nothing;
    get diagnostics n = row_count;
    v_medallas := v_medallas + n;
  end loop;

  return query select v_retos, v_logros, v_medallas;
end;
$function$;

grant execute on function public.retos_actualizar(uuid) to authenticated;

comment on function public.retos_actualizar(uuid) is
  'Repasa los retos activos y apunta lo conseguido, los puntos y las medallas. Solo el equipo del club.';


-- ---------------------------------------------------------------------
-- 8. GUARDIA DEL PERFIL DE JUEGO
-- ---------------------------------------------------------------------
-- Una persona puede decidir si participa, con qué nombre y con qué foto,
-- pero NO puede darse a sí misma la autorización familiar ni tocarse los
-- puntos. Si lo intenta, esos campos se quedan como estaban.
create or replace function public.perfil_juego_guardia()
returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
begin
  new.actualizado := now();
  if auth.uid() is null or public.es_staff() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.puntos := 0;
    new.autoriza_parental_por := null;
    new.autoriza_parental_en  := null;
  else
    new.puntos := old.puntos;
    new.autoriza_parental_por := old.autoriza_parental_por;
    new.autoriza_parental_en  := old.autoriza_parental_en;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_perfil_juego_guardia on public.perfil_juego;
create trigger trg_perfil_juego_guardia
before insert or update on public.perfil_juego
for each row execute function public.perfil_juego_guardia();


-- ---------------------------------------------------------------------
-- 9. LO QUE VE EL RESTO DEL CLUB
-- ---------------------------------------------------------------------
-- Tres vistas y una regla única para las tres: se enseña el nombre que
-- esa persona eligió, su foto si la puso, su rango, sus puntos, sus
-- medallas y los retos que ha cumplido. Y NADA MÁS: ni correos, ni
-- teléfonos, ni fechas de nacimiento, ni grupo, ni marcas, ni pagos.
--
-- LA REGLA (la misma en las tres vistas):
--   · Hay que haber dicho que sí (participa = true).
--   · Un MENOR necesita además la autorización familiar registrada.
--   · Quien está de baja, fuera.
--   · Y quien apaga el interruptor desaparece al momento de todas.

-- --- 9.1 El listín: quién se deja ver y su ficha de cabecera ---------
drop view if exists public.clasificacion_retos;
drop view if exists public.logros_publicos;
drop view if exists public.medallas_publicas;
drop view if exists public.miembros_juego;

-- EL NOMBRE Y LA FOTO SALEN DE `perfiles`, no de aquí: es «Mi perfil»
-- del portal quien los cambia, y este sistema solo los lee.
--
-- Se leen con to_jsonb(p) -> 'columna' a propósito. Suena raro, pero
-- tiene un motivo muy práctico: esas tres columnas las está creando otro
-- compañero en su propia migración, y así esta vista NO se rompe si
-- todavía no existen (devuelve vacío) y empieza a enseñarlas sola en
-- cuanto aparezcan, sin volver a tocar nada.
create view public.miembros_juego as
select
  a.id as atleta_id,
  case when coalesce(btrim(to_jsonb(p) ->> 'nombre_publico'), '') <> ''
       then btrim(to_jsonb(p) ->> 'nombre_publico')
       else btrim(a.nombre || ' ' || coalesce(a.apellidos, '')) end as nombre,
  to_jsonb(p) ->> 'foto_ruta' as foto_ruta,
  pj.puntos,
  (select count(*) from public.atleta_medallas am where am.atleta_id = a.id) as medallas,
  (select count(*) from public.reto_logros rl where rl.atleta_id = a.id) as retos,
  (select jr.nombre from public.juego_rangos jr
    where jr.desde_puntos <= pj.puntos order by jr.desde_puntos desc limit 1) as rango
from public.perfil_juego pj
join public.atletas a on a.id = pj.atleta_id
left join public.perfiles p on p.id = a.perfil_id
where pj.participa
  -- Si esa persona ha pedido privacidad en «Mi perfil», mandan sus ganas
  -- de que no la vean. Mientras esa columna no exista, no estorba.
  and coalesce((to_jsonb(p) ->> 'perfil_visible')::boolean, true)
  and coalesce(a.estado, 'activo') <> 'baja'
  and (public.juego_es_menor(a.fecha_nacimiento) = false or pj.autoriza_parental_en is not null);

comment on view public.miembros_juego is
  'Fichas consultables del club: el nombre y la foto que la persona eligió en Mi perfil, su rango, sus puntos y cuántas medallas y retos lleva. Nada personal más.';

-- La regla de visibilidad, en un solo sitio: la vista de arriba. Así no
-- hay dos versiones de «quién se deja ver» que puedan acabar diciendo
-- cosas distintas.
create or replace function public.perfil_juego_visible(p_atleta uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select p_atleta is not null
     and exists (select 1 from public.miembros_juego mj where mj.atleta_id = p_atleta);
$function$;

grant execute on function public.perfil_juego_visible(uuid) to authenticated;

comment on function public.perfil_juego_visible(uuid) is
  'Participa, no está de baja, no ha pedido privacidad en Mi perfil y —si es menor— tiene la autorización familiar registrada.';

-- --- 9.2 Las medallas de esa ficha -----------------------------------
create view public.medallas_publicas as
select
  am.atleta_id,
  m.id as medalla_id,
  m.titulo,
  m.descripcion,
  m.orden,
  am.conseguida_en
from public.atleta_medallas am
join public.medallas m on m.id = am.medalla_id
where m.activa
  and exists (select 1 from public.miembros_juego mj where mj.atleta_id = am.atleta_id);

comment on view public.medallas_publicas is
  'Medallas conseguidas por quien se deja ver. Si esa persona se oculta, sus medallas dejan de listarse.';

-- --- 9.3 Los retos cumplidos de esa ficha ----------------------------
create view public.logros_publicos as
select
  l.atleta_id,
  r.id as reto_id,
  r.titulo,
  r.descripcion,
  l.puntos_otorgados,
  l.completado_en
from public.reto_logros l
join public.retos r on r.id = l.reto_id
where exists (select 1 from public.miembros_juego mj where mj.atleta_id = l.atleta_id);

comment on view public.logros_publicos is
  'Retos cumplidos por quien se deja ver, con la fecha. Sin el valor exacto alcanzado: basta con que conste el logro.';

-- --- 9.4 La clasificación, detrás del interruptor ---------------------
-- Es lo MISMO que el listín, ordenado y numerado, pero solo existe si el
-- club enciende el interruptor. Apagado = ni una fila.
create view public.clasificacion_retos as
select
  mj.atleta_id,
  mj.nombre,
  mj.foto_ruta,
  mj.puntos,
  mj.medallas,
  mj.rango,
  rank() over (order by mj.puntos desc) as puesto
from public.miembros_juego mj
where public.ranking_encendido();

comment on view public.clasificacion_retos is
  'Tabla comparativa del club. Vacía mientras el interruptor esté apagado: la competición oficial es la Liga Apolana.';

-- Las cuatro vistas se saltan a propósito las reglas de las tablas de
-- abajo (para que se pueda ver a gente del club que no es «tuya»), así
-- que el candado está aquí: solo las lee quien ha entrado con su cuenta.
alter view public.miembros_juego      set (security_invoker = off);
alter view public.medallas_publicas   set (security_invoker = off);
alter view public.logros_publicos     set (security_invoker = off);
alter view public.clasificacion_retos set (security_invoker = off);

revoke all on public.miembros_juego      from anon, public;
revoke all on public.medallas_publicas   from anon, public;
revoke all on public.logros_publicos     from anon, public;
revoke all on public.clasificacion_retos from anon, public;

grant select on public.miembros_juego      to authenticated;
grant select on public.medallas_publicas   to authenticated;
grant select on public.logros_publicos     to authenticated;
grant select on public.clasificacion_retos to authenticated;


-- ---------------------------------------------------------------------
-- 10. REGLAS DE SEGURIDAD (RLS)
-- ---------------------------------------------------------------------
-- Todas las reglas son «to authenticated»: sin cuenta no se ve nada.

alter table public.retos           enable row level security;
alter table public.reto_logros     enable row level security;
alter table public.medallas        enable row level security;
alter table public.atleta_medallas enable row level security;
alter table public.perfil_juego    enable row level security;
alter table public.juego_rangos    enable row level security;
alter table public.juego_ajustes   enable row level security;

-- --- 10.1 Retos: los activos los lee cualquiera con sesión ------------
drop policy if exists "retos lectura" on public.retos;
create policy "retos lectura" on public.retos
for select to authenticated
using (activo or es_staff());

drop policy if exists "retos alta del equipo" on public.retos;
create policy "retos alta del equipo" on public.retos
for insert to authenticated with check (es_staff());

drop policy if exists "retos cambia el equipo" on public.retos;
create policy "retos cambia el equipo" on public.retos
for update to authenticated using (es_staff()) with check (es_staff());

drop policy if exists "retos borra el equipo" on public.retos;
create policy "retos borra el equipo" on public.retos
for delete to authenticated using (es_staff());

-- --- 10.2 Logros: cada quien los suyos; el equipo, todos --------------
drop policy if exists "logros lectura" on public.reto_logros;
create policy "logros lectura" on public.reto_logros
for select to authenticated
using (es_staff() or atleta_id in (select mis_atletas()));

drop policy if exists "logros los apunta el equipo" on public.reto_logros;
create policy "logros los apunta el equipo" on public.reto_logros
for insert to authenticated with check (es_staff());

drop policy if exists "logros los cambia el equipo" on public.reto_logros;
create policy "logros los cambia el equipo" on public.reto_logros
for update to authenticated using (es_staff()) with check (es_staff());

drop policy if exists "logros los borra el equipo" on public.reto_logros;
create policy "logros los borra el equipo" on public.reto_logros
for delete to authenticated using (es_staff());

-- --- 10.3 Catálogo de medallas ---------------------------------------
drop policy if exists "medallas lectura" on public.medallas;
create policy "medallas lectura" on public.medallas
for select to authenticated using (activa or es_staff());

drop policy if exists "medallas alta del equipo" on public.medallas;
create policy "medallas alta del equipo" on public.medallas
for insert to authenticated with check (es_staff());

drop policy if exists "medallas cambia el equipo" on public.medallas;
create policy "medallas cambia el equipo" on public.medallas
for update to authenticated using (es_staff()) with check (es_staff());

drop policy if exists "medallas borra el equipo" on public.medallas;
create policy "medallas borra el equipo" on public.medallas
for delete to authenticated using (es_staff());

-- --- 10.4 Medallas conseguidas ---------------------------------------
drop policy if exists "medallas ganadas lectura" on public.atleta_medallas;
create policy "medallas ganadas lectura" on public.atleta_medallas
for select to authenticated
using (es_staff() or atleta_id in (select mis_atletas()));

drop policy if exists "medallas ganadas las apunta el equipo" on public.atleta_medallas;
create policy "medallas ganadas las apunta el equipo" on public.atleta_medallas
for insert to authenticated with check (es_staff());

drop policy if exists "medallas ganadas las borra el equipo" on public.atleta_medallas;
create policy "medallas ganadas las borra el equipo" on public.atleta_medallas
for delete to authenticated using (es_staff());

-- --- 10.5 Perfil de juego --------------------------------------------
-- Leer: el equipo del club y la propia persona (o su familia).
-- Escribir: SOLO la propia persona (o su familia) y el equipo. Un
-- entrenador NO edita el perfil de sus atletas por serlo: para eso está
-- soy_staff_de_atleta(), que además cubre a administración.
drop policy if exists "perfil juego lectura" on public.perfil_juego;
create policy "perfil juego lectura" on public.perfil_juego
for select to authenticated
using (es_staff() or atleta_id in (select mis_atletas()));

drop policy if exists "perfil juego alta" on public.perfil_juego;
create policy "perfil juego alta" on public.perfil_juego
for insert to authenticated
with check (
  soy_staff_de_atleta(atleta_id)
  or atleta_id in (select id from public.atletas
                    where perfil_id = mi_perfil_id() or perfil_padre_id = mi_perfil_id())
);

drop policy if exists "perfil juego cambia" on public.perfil_juego;
create policy "perfil juego cambia" on public.perfil_juego
for update to authenticated
using (
  soy_staff_de_atleta(atleta_id)
  or atleta_id in (select id from public.atletas
                    where perfil_id = mi_perfil_id() or perfil_padre_id = mi_perfil_id())
)
with check (
  soy_staff_de_atleta(atleta_id)
  or atleta_id in (select id from public.atletas
                    where perfil_id = mi_perfil_id() or perfil_padre_id = mi_perfil_id())
);

drop policy if exists "perfil juego borra el equipo" on public.perfil_juego;
create policy "perfil juego borra el equipo" on public.perfil_juego
for delete to authenticated using (es_admin());

-- --- 10.6 Rangos: los lee cualquiera con sesión; los cambia el equipo --
drop policy if exists "rangos lectura" on public.juego_rangos;
create policy "rangos lectura" on public.juego_rangos
for select to authenticated using (true);

drop policy if exists "rangos los cambia el equipo" on public.juego_rangos;
create policy "rangos los cambia el equipo" on public.juego_rangos
for all to authenticated using (es_admin()) with check (es_admin());

-- --- 10.7 Ajustes: los lee cualquiera con sesión (para saber si la
--          clasificación está encendida); el interruptor lo mueve el equipo.
drop policy if exists "ajustes juego lectura" on public.juego_ajustes;
create policy "ajustes juego lectura" on public.juego_ajustes
for select to authenticated using (true);

drop policy if exists "ajustes juego los cambia el equipo" on public.juego_ajustes;
create policy "ajustes juego los cambia el equipo" on public.juego_ajustes
for update to authenticated using (es_staff()) with check (es_staff());

commit;


-- =====================================================================
-- 11. CONTENIDO DE ARRANQUE
-- ---------------------------------------------------------------------
-- Medallas y unos retos de ejemplo para que las pantallas no nazcan en
-- blanco. Todo se puede editar o borrar desde el panel; si se vuelve a
-- lanzar este archivo, lo que el club haya cambiado NO se pisa.
-- =====================================================================

begin;

insert into public.medallas (clave, titulo, descripcion, criterio, umbral, orden) values
  ('primer_dorsal',   'Primer dorsal',    'Tu primera competición con el club.',                 'competiciones',        1,  1),
  ('veterano_pista',  'Diez dorsales',    'Diez competiciones a tus espaldas.',                  'competiciones',       10,  2),
  ('constante',       'Constante',        'Veinticinco entrenamientos con asistencia.',          'asistencias',         25,  3),
  ('inquebrantable',  'Inquebrantable',   'Cien entrenamientos con asistencia.',                 'asistencias',        100,  4),
  ('racha_diez',      'Racha de diez',    'Diez entrenamientos seguidos sin faltar.',            'racha_asistencias',   10,  5),
  ('voz_propia',      'Voz propia',       'Veinte entrenos con tus sensaciones enviadas.',       'entrenos_registrados',20,  6),
  ('primera_marca',   'Primera marca',    'Tu primera mejor marca personal registrada.',         'mejores_personales',   1,  7),
  ('cazamarcas',      'Cazamarcas',       'Cinco mejores marcas personales.',                    'mejores_personales',   5,  8),
  ('cubo_habitual',   'Habitual del Cubo','Quince clases de El Cubo a las que fuiste.',          'cubo_clases',         15,  9),
  ('bien_medido',     'Bien medido',      'Tres baterías de tests completadas.',                 'tests',                3, 10),
  ('coleccionista',   'Coleccionista',    'Cinco retos del club conseguidos.',                   'retos_completados',    5, 11),
  ('quinientos',      'Quinientos',       'Quinientos puntos acumulados.',                       'puntos',             500, 12)
on conflict (clave) do nothing;

insert into public.retos (id, titulo, descripcion, metrica, objetivo, periodo, puntos, premio, activo) values
  ('dddddddd-0045-4000-8000-000000000001'::uuid,
   'Semana redonda',
   'Ven a tres entrenamientos esta semana. Sin excusas y sin prisas.',
   'asistencias', 3, 'semana', 15,
   'Entras en el sorteo mensual de una camiseta del club.', true),
  ('dddddddd-0045-4000-8000-000000000002'::uuid,
   'Mes de los ocho',
   'Ocho entrenamientos este mes. El mes se gana en los días grises.',
   'asistencias', 8, 'mes', 40,
   'Un entrenamiento de prueba en otro grupo, el que quieras.', true),
  ('dddddddd-0045-4000-8000-000000000003'::uuid,
   'Cuéntame cómo fue',
   'Manda tus sensaciones en cinco entrenos de este mes.',
   'entrenos_registrados', 5, 'mes', 25,
   'Revisión de tu plan con tu entrenador, con calma.', true),
  ('dddddddd-0045-4000-8000-000000000004'::uuid,
   'A competir',
   'Dos competiciones esta temporada con el club.',
   'competiciones', 2, 'temporada', 60,
   'Diez por ciento de descuento en la tienda del club.', true),
  ('dddddddd-0045-4000-8000-000000000005'::uuid,
   'Marca de la casa',
   'Una mejor marca personal esta temporada.',
   'mejores_personales', 1, 'temporada', 50,
   'Tu marca en el tablón y en las redes del club.', true)
on conflict (id) do nothing;

commit;


-- --- Comprobación rápida ---------------------------------------------
select 'retos'            as que, count(*) from public.retos
union all select 'medallas',      count(*) from public.medallas
union all select 'rangos',        count(*) from public.juego_rangos
union all select 'perfiles juego',count(*) from public.perfil_juego
union all select 'clasificación encendida', (public.ranking_encendido())::int;
