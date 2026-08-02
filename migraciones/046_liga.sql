-- =====================================================================
-- 046_liga.sql  ·  LIGA APOLANA · competición interna de participación
-- =====================================================================
-- Para qué sirve:
--
--   El club lleva a mano, en una hoja de cálculo, una liga interna que
--   NO premia marcas ni resultados: premia PARTICIPAR. Cada vez que un
--   socio compite con el club (atletismo, running, trail, triatlón y
--   afines o natación) suma los puntos que dice la tabla oficial del
--   reglamento, y al final de la temporada hay bonus por constancia y
--   por hacer varios deportes. Este archivo mete esa hoja en la base de
--   datos: el socio comunica su prueba desde el portal, el club la
--   valida con un clic y la clasificación se calcula sola, igual para
--   todos y sin fórmulas que se rompan.
--
-- LO QUE DICE EL REGLAMENTO (y aquí se cumple al pie de la letra)
--   · Solo puntúa participar en pruebas oficiales o reconocidas, con la
--     inscripción a nombre del Club Atletismo Apolana y compitiendo con
--     la ropa del club. Los entrenamientos no puntúan.
--   · Una prueba cuya distancia esté ENTRE dos de la tabla puntúa por la
--     MENOR (de 7,5 km a 9,9 km puntúa como 5 km).
--   · Los relevos de atletismo y de natación NO puntúan.
--   · En una competición de atletismo o natación con más de dos pruebas,
--     solo puntúan las dos de más puntuación.
--   · En esta primera edición no hay puntos por licencia federativa.
--   · Bonus mensual de participación, bonus anual de constancia y bonus
--     multideporte (los tres se suman entre sí).
--   · La acreditación válida es el enlace a la clasificación oficial, y
--     las pruebas se comunican antes del día 5 del mes siguiente.
--   · Las clasificaciones se publican en la web del club.
--
-- CÓMO ESTÁ MONTADO
--   liga_ediciones        una fila por temporada (2026, 2027…).
--   liga_categorias       los tramos de edad, EDITABLES (para Sub-23).
--   liga_baremo           la tabla de puntos del Anexo I, EDITABLE.
--   liga_participaciones  cada dorsal de cada persona (la comunica el
--                         socio desde el portal o la mete el club).
--   liga_propuestas_prueba  el «falta una carrera» de los socios.
--   liga_ajustes_puntos   puntos sueltos que añade el club a mano, con
--                         su concepto. Van SIEMPRE aparte del bonus del
--                         reglamento para que la tabla sea explicable.
--   liga_clasificacion()  la función que aplica TODAS las reglas.
--   Vistas: general, por disciplina, por categoría y una PÚBLICA
--   (sin datos personales de más) para /liga/.
--   Bucket privado «liga-justificantes» para las capturas y los PDF.
--
-- LO QUE **NO** HACE (a propósito): la liga no se conecta con los retos
--   ni con las medallas internas del club. Si algún día se decide que un
--   reto dé puntos de liga, se apunta como un ajuste en
--   liga_ajustes_puntos y ya está: no hay que rehacer nada.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/046_liga.sql
-- Se puede volver a lanzar las veces que haga falta: no rompe nada y no
-- pisa lo que el club haya cambiado a mano.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. LAS EDICIONES · una por temporada
-- ---------------------------------------------------------------------
create table if not exists public.liga_ediciones (
  id           uuid primary key default gen_random_uuid(),
  anio         int  not null,
  nombre       text not null,
  fecha_inicio date not null,
  fecha_fin    date not null,
  activa       boolean not null default false,
  notas        text,
  created_at   timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'liga_ediciones_anio_unico') then
    alter table public.liga_ediciones add constraint liga_ediciones_anio_unico unique (anio);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'liga_ediciones_fechas_check') then
    alter table public.liga_ediciones add constraint liga_ediciones_fechas_check
      check (fecha_fin >= fecha_inicio);
  end if;
end $$;

-- Solo puede haber UNA edición en marcha: la web pública y el panel
-- enseñan siempre esa, así que no puede haber dos a la vez.
create unique index if not exists liga_ediciones_una_activa
  on public.liga_ediciones ((activa)) where activa;

comment on table  public.liga_ediciones is
  'Una temporada de la Liga Apolana. Solo una puede estar activa: es la que sale en el panel y en la web.';
comment on column public.liga_ediciones.fecha_fin is
  'El reglamento la fija en 7 días antes de la Gala Anual. Como la fecha de la gala cambia cada año, se escribe aquí a mano.';


-- ---------------------------------------------------------------------
-- 2. LAS CATEGORÍAS DE EDAD · editables
-- ---------------------------------------------------------------------
-- La edad se mira a 31 de diciembre del año de la edición, así que basta
-- con restar el año de nacimiento al año de la edición. Se guardan en
-- una tabla porque el club ya ha dicho que quiere añadir Sub-23 más
-- adelante: se añade una fila y listo, sin tocar ninguna pantalla.
create table if not exists public.liga_categorias (
  id         uuid primary key default gen_random_uuid(),
  edicion_id uuid not null references public.liga_ediciones(id) on delete cascade,
  nombre     text not null,
  edad_min   int,
  edad_max   int,
  orden      int  not null default 0,
  activa     boolean not null default true
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'liga_categorias_unica') then
    alter table public.liga_categorias add constraint liga_categorias_unica unique (edicion_id, nombre);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'liga_categorias_edades_check') then
    alter table public.liga_categorias add constraint liga_categorias_edades_check
      check (edad_min is null or edad_max is null or edad_max >= edad_min);
  end if;
end $$;

create index if not exists idx_liga_categorias_edicion on public.liga_categorias (edicion_id, orden);

comment on table public.liga_categorias is
  'Tramos de edad de una edición. La edad se cuenta a 31 de diciembre del año de la edición.';


-- ---------------------------------------------------------------------
-- 3. EL BAREMO · la tabla de puntos del Anexo I, editable
-- ---------------------------------------------------------------------
--  disciplina  una de las ocho que reconoce el reglamento.
--  familia     para qué se agrupa a la hora de aplicar la regla de la
--              distancia («entre dos, la menor»): las lisas de atletismo
--              no se mezclan con los concursos, ni el 200 libre con el
--              200 estilos, que valen distinto.
--  distancia_km  la distancia de la prueba en kilómetros; sirve para
--              resolver sola la regla anterior. Vacía en lo que no es
--              una distancia (saltos, lanzamientos, combinadas,
--              triatlones por denominación…).
--  es_relevo   marca las pruebas de relevos: se pueden apuntar para que
--              quede constancia, pero valen 0 puntos por reglamento.
create table if not exists public.liga_baremo (
  id           uuid primary key default gen_random_uuid(),
  edicion_id   uuid not null references public.liga_ediciones(id) on delete cascade,
  disciplina   text not null,
  familia      text not null default 'otra',
  modalidad    text not null,
  distancia_km numeric,
  puntos       int  not null default 0,
  es_relevo    boolean not null default false,
  orden        int  not null default 0,
  activa       boolean not null default true
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'liga_baremo_unico') then
    alter table public.liga_baremo add constraint liga_baremo_unico unique (edicion_id, disciplina, modalidad);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'liga_baremo_disciplina_check') then
    alter table public.liga_baremo add constraint liga_baremo_disciplina_check
      check (disciplina in ('atletismo','running','trail','triatlon','duatlon','aquabike','acuatlon','natacion'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'liga_baremo_puntos_check') then
    alter table public.liga_baremo add constraint liga_baremo_puntos_check check (puntos >= 0 and puntos <= 1000);
  end if;
end $$;

create index if not exists idx_liga_baremo_edicion on public.liga_baremo (edicion_id, orden);

comment on table  public.liga_baremo is
  'Tabla de puntos del Anexo I del reglamento. El club la puede cambiar desde el panel sin tocar nada más.';
comment on column public.liga_baremo.familia is
  'Grupo dentro del que se aplica la regla «una distancia entre dos puntúa por la menor».';
comment on column public.liga_baremo.es_relevo is
  'Los relevos de atletismo y natación no puntúan (reglamento). Se apuntan con 0 para que quede el registro.';


-- ---------------------------------------------------------------------
-- 4. LAS PARTICIPACIONES · cada dorsal de cada persona
-- ---------------------------------------------------------------------
-- Puede ser de alguien con ficha en el club (atleta_id) o de un socio
-- sin ficha, al que se apunta con el nombre escrito a mano.
--
-- El estado manda:
--   pendiente    la ha comunicado alguien y el club aún no la ha mirado
--   validada     comprobada: puntúa
--   no_validada  el club la descarta, con su motivo escrito
-- La columna «validada» se rellena sola desde el estado; está para que
-- las consultas de la clasificación sean cortas y claras.
create table if not exists public.liga_participaciones (
  id                  uuid primary key default gen_random_uuid(),
  edicion_id          uuid not null references public.liga_ediciones(id) on delete cascade,
  atleta_id           uuid references public.atletas(id) on delete set null,
  nombre_libre        text,
  categoria_manual    text,
  fecha               date not null,
  competicion         text not null,
  disciplina          text not null,
  modalidad           text not null,
  baremo_id           uuid references public.liga_baremo(id) on delete set null,
  distancia_km        numeric,
  puntos_aplicados    int  not null default 0,
  es_relevo           boolean not null default false,
  enlace_clasificacion text,
  adjuntos            jsonb not null default '[]'::jsonb,
  con_ropa_club       boolean not null default false,
  inscrito_como_club  boolean not null default false,
  estado              text not null default 'pendiente',
  validada            boolean not null default false,
  motivo_no_validada  text,
  comunicada_por      uuid references public.perfiles(id) on delete set null,
  revisada_por        uuid references public.perfiles(id) on delete set null,
  revisada_en         timestamptz,
  notas               text,
  created_at          timestamptz not null default now()
);

-- Columnas nuevas si la tabla ya existía de una versión anterior.
alter table public.liga_participaciones add column if not exists adjuntos           jsonb not null default '[]'::jsonb;
alter table public.liga_participaciones add column if not exists estado             text  not null default 'pendiente';
alter table public.liga_participaciones add column if not exists motivo_no_validada text;
alter table public.liga_participaciones add column if not exists comunicada_por     uuid;
alter table public.liga_participaciones add column if not exists revisada_por       uuid;
alter table public.liga_participaciones add column if not exists revisada_en        timestamptz;

do $$
begin
  -- O ficha del club o nombre a mano, pero alguno de los dos.
  if not exists (select 1 from pg_constraint where conname = 'liga_part_quien_check') then
    alter table public.liga_participaciones add constraint liga_part_quien_check
      check (atleta_id is not null or coalesce(btrim(nombre_libre), '') <> '');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'liga_part_disciplina_check') then
    alter table public.liga_participaciones add constraint liga_part_disciplina_check
      check (disciplina in ('atletismo','running','trail','triatlon','duatlon','aquabike','acuatlon','natacion'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'liga_part_competicion_check') then
    alter table public.liga_participaciones add constraint liga_part_competicion_check
      check (btrim(competicion) <> '');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'liga_part_estado_check') then
    alter table public.liga_participaciones add constraint liga_part_estado_check
      check (estado in ('pendiente','validada','no_validada'));
  end if;
  -- El reglamento es tajante: sin inscripción a nombre del club y sin la
  -- ropa del club, la prueba NO puntúa. Por eso no se puede dar por
  -- válida una participación a la que le falte cualquiera de las dos.
  if not exists (select 1 from pg_constraint where conname = 'liga_part_validada_check') then
    alter table public.liga_participaciones add constraint liga_part_validada_check
      check (validada = false or (inscrito_como_club and con_ropa_club));
  end if;
end $$;

create index if not exists idx_liga_part_edicion on public.liga_participaciones (edicion_id, fecha desc);
create index if not exists idx_liga_part_atleta  on public.liga_participaciones (atleta_id);
create index if not exists idx_liga_part_fecha   on public.liga_participaciones (fecha desc);
create index if not exists idx_liga_part_estado  on public.liga_participaciones (estado);
create index if not exists idx_liga_part_libre   on public.liga_participaciones (lower(btrim(nombre_libre)));
create index if not exists idx_liga_part_quien   on public.liga_participaciones (comunicada_por);

comment on table  public.liga_participaciones is
  'Una participación en una competición. Es lo único que se teclea: los puntos y la clasificación salen solos.';
comment on column public.liga_participaciones.nombre_libre is
  'Para socios sin ficha de atleta en el club. Si hay atleta_id, este campo se vacía solo.';
comment on column public.liga_participaciones.categoria_manual is
  'Categoría escrita a mano para quien no tiene ficha (y por tanto no tiene fecha de nacimiento guardada).';
comment on column public.liga_participaciones.enlace_clasificacion is
  'Acreditación válida según el reglamento: enlace a la clasificación oficial de la prueba.';
comment on column public.liga_participaciones.adjuntos is
  'Justificantes subidos al bucket privado «liga-justificantes»: [{"ruta":"…","nombre":"…","tipo":"image/jpeg"}].';


-- ---------------------------------------------------------------------
-- 5. LAS PROPUESTAS · el «falta una carrera» de los socios
-- ---------------------------------------------------------------------
create table if not exists public.liga_propuestas_prueba (
  id                 uuid primary key default gen_random_uuid(),
  edicion_id         uuid references public.liga_ediciones(id) on delete cascade,
  propuesta_por      uuid references public.perfiles(id) on delete set null,
  nombre             text not null,
  fecha              date,
  lugar              text,
  disciplina         text,
  modalidad_sugerida text,
  enlace             text,
  adjuntos           jsonb not null default '[]'::jsonb,
  estado             text not null default 'pendiente',
  notas_club         text,
  created_at         timestamptz not null default now()
);

alter table public.liga_propuestas_prueba add column if not exists adjuntos jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'liga_propuestas_estado_check') then
    alter table public.liga_propuestas_prueba add constraint liga_propuestas_estado_check
      check (estado in ('pendiente','aceptada','descartada'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'liga_propuestas_nombre_check') then
    alter table public.liga_propuestas_prueba add constraint liga_propuestas_nombre_check
      check (btrim(nombre) <> '');
  end if;
end $$;

create index if not exists idx_liga_propuestas_estado on public.liga_propuestas_prueba (estado, created_at desc);
create index if not exists idx_liga_propuestas_quien  on public.liga_propuestas_prueba (propuesta_por);

comment on table public.liga_propuestas_prueba is
  'Carreras que un socio echa en falta en la liga o en el calendario. El club las acepta o las descarta.';


-- ---------------------------------------------------------------------
-- 6. LOS AJUSTES DE PUNTOS · lo que el club añade a mano
-- ---------------------------------------------------------------------
-- Puntos sueltos, con su concepto, para casos que el reglamento no
-- cubre (una corrección, un acuerdo de la junta y, si algún día se
-- decide, los retos internos del club). Van SIEMPRE en una columna
-- aparte de la clasificación: nunca se mezclan con los bonus del
-- reglamento, para que cualquiera pueda entender de dónde sale cada
-- punto. Pueden ser negativos.
create table if not exists public.liga_ajustes_puntos (
  id               uuid primary key default gen_random_uuid(),
  edicion_id       uuid not null references public.liga_ediciones(id) on delete cascade,
  atleta_id        uuid references public.atletas(id) on delete set null,
  nombre_libre     text,
  categoria_manual text,
  concepto         text not null,
  puntos           int  not null default 0,
  fecha            date not null default current_date,
  creado_por       uuid references public.perfiles(id) on delete set null,
  notas            text,
  created_at       timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'liga_ajustes_quien_check') then
    alter table public.liga_ajustes_puntos add constraint liga_ajustes_quien_check
      check (atleta_id is not null or coalesce(btrim(nombre_libre), '') <> '');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'liga_ajustes_concepto_check') then
    alter table public.liga_ajustes_puntos add constraint liga_ajustes_concepto_check
      check (btrim(concepto) <> '');
  end if;
end $$;

create index if not exists idx_liga_ajustes_edicion on public.liga_ajustes_puntos (edicion_id, fecha desc);
create index if not exists idx_liga_ajustes_atleta  on public.liga_ajustes_puntos (atleta_id);

comment on table public.liga_ajustes_puntos is
  'Puntos que el club suma o resta a mano, con su concepto. Aparecen aparte del bonus del reglamento.';


-- ---------------------------------------------------------------------
-- 7. EL SERVIDOR MANDA SOBRE LOS PUNTOS
-- ---------------------------------------------------------------------
-- Igual que con los precios de la tienda: quien decide cuántos puntos
-- vale una prueba es el baremo, no la pantalla. Al guardar, se copian
-- disciplina, modalidad y puntos de la fila del baremo elegida, y los
-- relevos se quedan a cero pase lo que pase.
create or replace function public.liga_participacion_normaliza()
returns trigger language plpgsql security definer set search_path = public as $$
declare b record;
begin
  if new.edicion_id is null then
    select id into new.edicion_id from public.liga_ediciones where activa limit 1;
    if new.edicion_id is null then
      raise exception 'No hay ninguna edición de la liga en marcha.';
    end if;
  end if;

  -- Quien tiene ficha en el club no lleva nombre escrito a mano.
  if new.atleta_id is not null then
    new.nombre_libre := null;
    new.categoria_manual := null;
  else
    new.nombre_libre := btrim(new.nombre_libre);
  end if;

  new.competicion := btrim(new.competicion);
  new.enlace_clasificacion := nullif(btrim(coalesce(new.enlace_clasificacion, '')), '');
  if new.adjuntos is null then new.adjuntos := '[]'::jsonb; end if;

  if tg_op = 'INSERT' and new.comunicada_por is null then
    new.comunicada_por := public.mi_perfil_id();
  end if;

  if new.baremo_id is not null then
    select * into b from public.liga_baremo where id = new.baremo_id;
    if b.id is null then
      raise exception 'La modalidad elegida ya no existe en el baremo.';
    end if;
    if b.edicion_id <> new.edicion_id then
      raise exception 'La modalidad elegida es de otra edición de la liga.';
    end if;
    new.disciplina       := b.disciplina;
    new.modalidad        := b.modalidad;
    new.es_relevo        := b.es_relevo;
    new.puntos_aplicados := case when b.es_relevo then 0 else b.puntos end;
  else
    new.puntos_aplicados := greatest(coalesce(new.puntos_aplicados, 0), 0);
    if new.es_relevo then new.puntos_aplicados := 0; end if;
  end if;

  -- El estado manda; «validada» se rellena sola.
  if new.estado = 'validada' and not (new.inscrito_como_club and new.con_ropa_club) then
    raise exception 'Para dar por válida una prueba tiene que constar la inscripción como Club Atletismo Apolana y haber competido con la ropa del club.';
  end if;
  new.validada := (new.estado = 'validada');
  if new.estado <> 'no_validada' then new.motivo_no_validada := null; end if;
  if tg_op = 'UPDATE' and new.estado is distinct from old.estado and new.estado <> 'pendiente' then
    new.revisada_en  := now();
    new.revisada_por := coalesce(new.revisada_por, public.mi_perfil_id());
  end if;

  return new;
end $$;

drop trigger if exists trg_liga_participacion_normaliza on public.liga_participaciones;
create trigger trg_liga_participacion_normaliza
  before insert or update on public.liga_participaciones
  for each row execute function public.liga_participacion_normaliza();

-- Quién propone y quién ajusta se apuntan solos.
create or replace function public.liga_marca_autor()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'liga_propuestas_prueba' then
    if new.propuesta_por is null then new.propuesta_por := public.mi_perfil_id(); end if;
    if new.edicion_id is null then
      select id into new.edicion_id from public.liga_ediciones where activa limit 1;
    end if;
  else
    if new.creado_por is null then new.creado_por := public.mi_perfil_id(); end if;
    if new.atleta_id is not null then new.nombre_libre := null; new.categoria_manual := null; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_liga_propuesta_autor on public.liga_propuestas_prueba;
create trigger trg_liga_propuesta_autor
  before insert on public.liga_propuestas_prueba
  for each row execute function public.liga_marca_autor();

drop trigger if exists trg_liga_ajuste_autor on public.liga_ajustes_puntos;
create trigger trg_liga_ajuste_autor
  before insert on public.liga_ajustes_puntos
  for each row execute function public.liga_marca_autor();


-- ---------------------------------------------------------------------
-- 8. AYUDANTES
-- ---------------------------------------------------------------------

-- La edición que está en marcha ahora mismo.
create or replace function public.liga_edicion_activa()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.liga_ediciones where activa limit 1;
$$;

-- Las cinco disciplinas principales del reglamento. Triatlón, duatlón,
-- aquabike y acuatlón son modalidades de una sola disciplina («triatlón
-- y afines»), y así es como se agrupan en la clasificación y como cuentan
-- para el bonus multideporte.
create or replace function public.liga_disciplina_principal(p_disciplina text)
returns text language sql immutable as $$
  select case p_disciplina
           when 'atletismo' then 'atletismo'
           when 'running'   then 'running'
           when 'trail'     then 'trail'
           when 'natacion'  then 'natacion'
           when 'triatlon'  then 'triatlon'
           when 'duatlon'   then 'triatlon'
           when 'aquabike'  then 'triatlon'
           when 'acuatlon'  then 'triatlon'
           else 'otra'
         end;
$$;

-- Categoría de edad: se cuenta la edad a 31 de diciembre del año de la
-- edición, así que basta con restar los años.
create or replace function public.liga_categoria_por_edad(p_edicion uuid, p_fecha_nac date)
returns text language sql stable security definer set search_path = public as $$
  select c.nombre
    from public.liga_categorias c
    join public.liga_ediciones e on e.id = c.edicion_id
   where c.edicion_id = p_edicion
     and c.activa
     and p_fecha_nac is not null
     and (e.anio - extract(year from p_fecha_nac)::int)
         between coalesce(c.edad_min, 0) and coalesce(c.edad_max, 200)
   order by c.orden
   limit 1;
$$;

-- Regla de la distancia: una prueba de 7,5 km puntúa como una de 5 km.
-- Devuelve la fila del baremo que le toca a una distancia dada.
create or replace function public.liga_baremo_por_distancia(p_edicion uuid, p_familia text, p_km numeric)
returns uuid language sql stable security definer set search_path = public as $$
  select b.id
    from public.liga_baremo b
   where b.edicion_id = p_edicion
     and b.familia = p_familia
     and b.activa
     and not b.es_relevo
     and b.distancia_km is not null
     and b.distancia_km <= p_km
   order by b.distancia_km desc
   limit 1;
$$;

-- El reglamento pide comunicar cada prueba antes del día 5 del mes
-- siguiente. Esto dice si una se comunicó tarde.
create or replace function public.liga_fuera_de_plazo(p_fecha date, p_comunicada timestamptz)
returns boolean language sql immutable as $$
  select p_fecha is not null
     and p_comunicada is not null
     and p_comunicada::date >= (date_trunc('month', p_fecha)::date + interval '1 month' + interval '4 days')::date;
$$;


-- ---------------------------------------------------------------------
-- 9. LA CLASIFICACIÓN · aquí viven todas las reglas
-- ---------------------------------------------------------------------
-- Orden en que se aplican las reglas:
--   1) Solo cuentan las participaciones VALIDADAS de la edición. Validar
--      exige (por la regla de la tabla) inscripción a nombre del club y
--      ropa del club.
--   2) Los RELEVOS quedan fuera de todo: no dan puntos y no cuentan como
--      prueba (el reglamento habla de «pruebas individuales»).
--   3) En atletismo y natación, dentro de UNA MISMA competición, solo
--      puntúan las DOS pruebas de más puntuación; de la tercera en
--      adelante se apuntan con 0 puntos, pero siguen contando como
--      participación.
--   4) La regla de la distancia («entre dos, la menor») ya viene
--      resuelta desde el baremo al elegir la modalidad.
--   5) Bonus mensual: por cada mes natural, 3 o 4 pruebas suman 2 puntos
--      y 5 o más suman 5. Dentro del mes solo cuenta el tramo de arriba;
--      a lo largo de la temporada se van sumando mes a mes.
--   6) Bonus de constancia: 10 o más pruebas individuales validadas en
--      toda la temporada suman 10 puntos, una sola vez.
--   7) Bonus multideporte: 2 disciplinas principales suman 5, 3 suman 10
--      y 4 o más suman 15, una sola vez.
--   8) Camiseta «Finisher»: 8 pruebas en una misma disciplina, o bien 6
--      pruebas repartidas en 2 disciplinas distintas o más.
--   9) Los ajustes del club se suman al total EN SU PROPIA COLUMNA, sin
--      mezclarse nunca con el bonus del reglamento.
create or replace function public.liga_clasificacion(p_edicion uuid)
returns table (
  clave              text,
  atleta_id          uuid,
  nombre             text,
  categoria          text,
  categoria_orden    int,
  p_atletismo        int,
  p_running          int,
  p_trail            int,
  p_triatlon         int,
  p_natacion         int,
  bonus              int,
  ajustes            int,
  total              int,
  pruebas            int,
  bonus_mensual      int,
  bonus_constancia   int,
  bonus_multideporte int,
  disciplinas        int,
  finisher           boolean,
  finisher_falta     int
)
language sql stable security definer set search_path = public as $$
  with base as (
    select
      pa.id,
      coalesce(pa.atleta_id::text, 'libre:' || lower(btrim(pa.nombre_libre)))          as clave,
      pa.atleta_id,
      coalesce(nullif(btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')), ''),
               btrim(pa.nombre_libre))                                                 as nombre,
      pa.fecha,
      lower(btrim(pa.competicion))                                                     as competicion_k,
      public.liga_disciplina_principal(pa.disciplina)                                  as principal,
      coalesce(pa.puntos_aplicados, 0)                                                 as puntos_brutos,
      pa.categoria_manual,
      a.fecha_nacimiento
    from public.liga_participaciones pa
    left join public.atletas a on a.id = pa.atleta_id
    where pa.edicion_id = p_edicion
      and pa.validada
      and not pa.es_relevo          -- los relevos no puntúan ni cuentan
  ),
  -- Regla de las dos mejores pruebas por competición (atletismo y natación)
  ordenadas as (
    select b.*,
           case when b.principal in ('atletismo', 'natacion')
                then row_number() over (partition by b.clave, b.principal, b.competicion_k
                                        order by b.puntos_brutos desc, b.id)
                else 1 end as puesto_en_competicion
    from base b
  ),
  puntuadas as (
    select o.*,
           case when o.puesto_en_competicion > 2 then 0 else o.puntos_brutos end as puntos
    from ordenadas o
  ),
  -- Ajustes del club (van aparte, nunca dentro del bonus del reglamento)
  ajustes_base as (
    select coalesce(aj.atleta_id::text, 'libre:' || lower(btrim(aj.nombre_libre)))     as clave,
           aj.atleta_id,
           coalesce(nullif(btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')), ''),
                    btrim(aj.nombre_libre))                                            as nombre,
           a.fecha_nacimiento,
           aj.categoria_manual,
           aj.puntos
    from public.liga_ajustes_puntos aj
    left join public.atletas a on a.id = aj.atleta_id
    where aj.edicion_id = p_edicion
  ),
  ajustes_tot as (
    select clave, sum(puntos)::int as pts from ajustes_base group by clave
  ),
  -- Puntos y número de pruebas por disciplina principal
  por_disciplina as (
    select clave, principal, sum(puntos)::int as pts, count(*)::int as n
    from puntuadas
    group by clave, principal
  ),
  columnas as (
    select clave,
           coalesce(sum(pts) filter (where principal = 'atletismo'), 0)::int as p_atletismo,
           coalesce(sum(pts) filter (where principal = 'running'),   0)::int as p_running,
           coalesce(sum(pts) filter (where principal = 'trail'),     0)::int as p_trail,
           coalesce(sum(pts) filter (where principal = 'triatlon'),  0)::int as p_triatlon,
           coalesce(sum(pts) filter (where principal = 'natacion'),  0)::int as p_natacion,
           max(n)::int                                                       as max_en_una_disciplina,
           count(*)::int                                                     as n_disciplinas
    from por_disciplina
    group by clave
  ),
  -- Bonus mensual de participación
  por_mes as (
    select clave, date_trunc('month', fecha) as mes, count(*)::int as n
    from puntuadas
    group by clave, date_trunc('month', fecha)
  ),
  bonus_mes as (
    select clave,
           sum(case when n >= 5 then 5 when n >= 3 then 2 else 0 end)::int as bonus_mensual
    from por_mes
    group by clave
  ),
  -- Cada participante: los que tienen pruebas y los que solo tienen ajustes
  personas as (
    select clave,
           max(atleta_id::text)::uuid            as atleta_id,
           max(nombre)                           as nombre,
           max(fecha_nacimiento)                 as fecha_nacimiento,
           max(categoria_manual)                 as categoria_manual,
           count(*) filter (where de_prueba)::int as pruebas
    from (
      select clave, atleta_id, nombre, fecha_nacimiento, categoria_manual, true  as de_prueba from puntuadas
      union all
      select clave, atleta_id, nombre, fecha_nacimiento, categoria_manual, false as de_prueba from ajustes_base
    ) t
    group by clave
  )
  select
    p.clave,
    p.atleta_id,
    p.nombre,
    coalesce(public.liga_categoria_por_edad(p_edicion, p.fecha_nacimiento),
             p.categoria_manual,
             'Sin categoría')                                              as categoria,
    coalesce((select c.orden from public.liga_categorias c
               where c.edicion_id = p_edicion
                 and c.nombre = coalesce(public.liga_categoria_por_edad(p_edicion, p.fecha_nacimiento),
                                         p.categoria_manual)), 99)         as categoria_orden,
    coalesce(c.p_atletismo, 0) as p_atletismo,
    coalesce(c.p_running,   0) as p_running,
    coalesce(c.p_trail,     0) as p_trail,
    coalesce(c.p_triatlon,  0) as p_triatlon,
    coalesce(c.p_natacion,  0) as p_natacion,
    (coalesce(bm.bonus_mensual, 0)
     + case when p.pruebas >= 10 then 10 else 0 end
     + case when coalesce(c.n_disciplinas, 0) >= 4 then 15
            when coalesce(c.n_disciplinas, 0)  = 3 then 10
            when coalesce(c.n_disciplinas, 0)  = 2 then 5
            else 0 end)::int                                               as bonus,
    coalesce(aj.pts, 0)                                                    as ajustes,
    (coalesce(c.p_atletismo, 0) + coalesce(c.p_running, 0) + coalesce(c.p_trail, 0)
     + coalesce(c.p_triatlon, 0) + coalesce(c.p_natacion, 0)
     + coalesce(bm.bonus_mensual, 0)
     + case when p.pruebas >= 10 then 10 else 0 end
     + case when coalesce(c.n_disciplinas, 0) >= 4 then 15
            when coalesce(c.n_disciplinas, 0)  = 3 then 10
            when coalesce(c.n_disciplinas, 0)  = 2 then 5
            else 0 end
     + coalesce(aj.pts, 0))::int                                           as total,
    p.pruebas,
    coalesce(bm.bonus_mensual, 0)                                          as bonus_mensual,
    (case when p.pruebas >= 10 then 10 else 0 end)                         as bonus_constancia,
    (case when coalesce(c.n_disciplinas, 0) >= 4 then 15
          when coalesce(c.n_disciplinas, 0)  = 3 then 10
          when coalesce(c.n_disciplinas, 0)  = 2 then 5
          else 0 end)                                                      as bonus_multideporte,
    coalesce(c.n_disciplinas, 0)                                           as disciplinas,
    (least(greatest(8 - coalesce(c.max_en_una_disciplina, 0), 0),
           case when coalesce(c.n_disciplinas, 0) >= 2 then greatest(6 - p.pruebas, 0) else 99 end) = 0)
                                                                           as finisher,
    least(greatest(8 - coalesce(c.max_en_una_disciplina, 0), 0),
          case when coalesce(c.n_disciplinas, 0) >= 2 then greatest(6 - p.pruebas, 0) else 99 end)::int
                                                                           as finisher_falta
  from personas p
  left join columnas    c  using (clave)
  left join bonus_mes   bm using (clave)
  left join ajustes_tot aj using (clave);
$$;

comment on function public.liga_clasificacion(uuid) is
  'Clasificación completa de una edición con todas las reglas y bonus del reglamento aplicados, más los ajustes del club en columna aparte.';

-- OJO: Supabase concede EXECUTE al rol «anon» en cuanto se crea una
-- función en el esquema public, así que no basta con quitárselo a
-- «public»: hay que retirárselo a «anon» por su nombre. Sin esto, un
-- visitante sin cuenta podría pedir la clasificación entera (con los
-- identificadores de cada atleta) llamando a la función a mano.
revoke all on function public.liga_clasificacion(uuid) from public, anon;
revoke all on function public.liga_edicion_activa()   from public, anon;
revoke all on function public.liga_categoria_por_edad(uuid, date) from public, anon;
revoke all on function public.liga_baremo_por_distancia(uuid, text, numeric) from public, anon;
revoke all on function public.liga_participacion_normaliza() from public, anon, authenticated;
revoke all on function public.liga_marca_autor()             from public, anon, authenticated;
grant execute on function public.liga_clasificacion(uuid)                    to authenticated;
grant execute on function public.liga_edicion_activa()                       to authenticated;
grant execute on function public.liga_categoria_por_edad(uuid, date)         to authenticated;
grant execute on function public.liga_baremo_por_distancia(uuid, text, numeric) to authenticated;
grant execute on function public.liga_fuera_de_plazo(date, timestamptz)      to authenticated, anon;
grant execute on function public.liga_disciplina_principal(text)             to authenticated, anon;


-- ---------------------------------------------------------------------
-- 10. LAS VISTAS
-- ---------------------------------------------------------------------
-- Todas trabajan sobre la edición que está en marcha.
drop view if exists public.liga_clasificacion_publica;
drop view if exists public.liga_clasificacion_por_categoria;
drop view if exists public.liga_clasificacion_por_disciplina;
drop view if exists public.liga_clasificacion_general;

-- 10.1 General (con sesión): la tabla completa, con el identificador del
--      atleta para poder enlazar con su ficha desde el panel.
create view public.liga_clasificacion_general as
  select rank() over (order by c.total desc, c.pruebas desc, c.nombre) as posicion,
         c.*
    from public.liga_clasificacion(public.liga_edicion_activa()) c;

alter view public.liga_clasificacion_general set (security_invoker = false);
revoke all on public.liga_clasificacion_general from anon, public;
grant select on public.liga_clasificacion_general to authenticated;

-- 10.2 Por disciplina (con sesión): una fila por persona y disciplina en
--      la que haya puntuado, con su puesto dentro de esa disciplina.
create view public.liga_clasificacion_por_disciplina as
  select d.disciplina,
         rank() over (partition by d.disciplina order by d.puntos desc, c.nombre) as posicion,
         c.clave, c.atleta_id, c.nombre, c.categoria, d.puntos
    from public.liga_clasificacion(public.liga_edicion_activa()) c
    cross join lateral (values
        ('atletismo', c.p_atletismo),
        ('running',   c.p_running),
        ('trail',     c.p_trail),
        ('triatlon',  c.p_triatlon),
        ('natacion',  c.p_natacion)
      ) as d(disciplina, puntos)
   where d.puntos > 0;

alter view public.liga_clasificacion_por_disciplina set (security_invoker = false);
revoke all on public.liga_clasificacion_por_disciplina from anon, public;
grant select on public.liga_clasificacion_por_disciplina to authenticated;

-- 10.3 Por categoría (con sesión): la misma tabla, pero con el puesto
--      recalculado dentro de cada tramo de edad.
create view public.liga_clasificacion_por_categoria as
  select c.categoria,
         c.categoria_orden,
         rank() over (partition by c.categoria order by c.total desc, c.pruebas desc, c.nombre) as posicion,
         c.clave, c.atleta_id, c.nombre, c.total, c.pruebas, c.bonus, c.ajustes,
         c.p_atletismo, c.p_running, c.p_trail, c.p_triatlon, c.p_natacion
    from public.liga_clasificacion(public.liga_edicion_activa()) c;

alter view public.liga_clasificacion_por_categoria set (security_invoker = false);
revoke all on public.liga_clasificacion_por_categoria from anon, public;
grant select on public.liga_clasificacion_por_categoria to authenticated;

-- 10.4 PÚBLICA: la que se publica en /liga/, como manda el reglamento.
--      Lleva exactamente las columnas de la hoja del club y NADA más:
--      ni identificadores, ni fechas de nacimiento, ni enlaces, ni quién
--      apuntó qué. Con esas columnas la web arma sola las pestañas por
--      disciplina y por categoría, sin exponer nada de más.
--
--      POR QUÉ AQUÍ HAY UNA FUNCIÓN Y NO SOLO UNA VISTA: una vista
--      «definer» resuelve los permisos de TABLAS con los del dueño, pero
--      los de las FUNCIONES los sigue mirando con los de quien consulta.
--      Como el visitante sin cuenta no puede (ni debe) ejecutar
--      liga_clasificacion(), la vista sola le daría «permiso denegado».
--      Metiéndolo en una función SECURITY DEFINER, dentro de ella el
--      usuario efectivo pasa a ser el dueño y las llamadas de dentro sí
--      valen; y lo que sale por la puerta son solo estas columnas.
drop function if exists public.liga_clasificacion_publica_fn();
create function public.liga_clasificacion_publica_fn()
returns table (
  posicion        bigint,
  nombre          text,
  categoria       text,
  categoria_orden int,
  p_atletismo     int,
  p_running       int,
  p_trail         int,
  p_triatlon      int,
  p_natacion      int,
  bonus           int,
  ajustes         int,
  total           int,
  pruebas         int,
  finisher        boolean
)
language sql stable security definer set search_path = public as $$
  select rank() over (order by c.total desc, c.pruebas desc, c.nombre) as posicion,
         c.nombre, c.categoria, c.categoria_orden,
         c.p_atletismo, c.p_running, c.p_trail, c.p_triatlon, c.p_natacion,
         c.bonus, c.ajustes, c.total, c.pruebas, c.finisher
    from public.liga_clasificacion(public.liga_edicion_activa()) c;
$$;

revoke all on function public.liga_clasificacion_publica_fn() from public;
grant execute on function public.liga_clasificacion_publica_fn() to anon, authenticated;

create view public.liga_clasificacion_publica as
  select * from public.liga_clasificacion_publica_fn();

alter view public.liga_clasificacion_publica set (security_invoker = false);
revoke all on public.liga_clasificacion_publica from public;
grant select on public.liga_clasificacion_publica to anon, authenticated;

-- 10.5 La tabla de puntos y la edición, también públicas: la web enseña
--      el baremo vigente y, si el club lo cambia, cambia solo.
create or replace view public.liga_baremo_publico as
  select b.disciplina, b.modalidad, b.puntos, b.es_relevo, b.orden
    from public.liga_baremo b
    join public.liga_ediciones e on e.id = b.edicion_id
   where e.activa and b.activa;

alter view public.liga_baremo_publico set (security_invoker = false);
revoke all on public.liga_baremo_publico from public;
grant select on public.liga_baremo_publico to anon, authenticated;

create or replace view public.liga_edicion_publica as
  select anio, nombre, fecha_inicio, fecha_fin
    from public.liga_ediciones
   where activa;

alter view public.liga_edicion_publica set (security_invoker = false);
revoke all on public.liga_edicion_publica from public;
grant select on public.liga_edicion_publica to anon, authenticated;

comment on view public.liga_clasificacion_publica is
  'Clasificación que se publica en la web del club: nombre, categoría y puntos. Sin ningún otro dato personal.';


-- ---------------------------------------------------------------------
-- 11. REGLAS DE SEGURIDAD (RLS)
-- ---------------------------------------------------------------------
-- Las tablas solo se leen con sesión iniciada; escribe el equipo del
-- club (admin, coordinación y entrenadores) y, en sus propias pruebas,
-- el socio. Lo que ve Internet entra por las vistas curadas de arriba,
-- nunca por las tablas.
alter table public.liga_ediciones         enable row level security;
alter table public.liga_categorias        enable row level security;
alter table public.liga_baremo            enable row level security;
alter table public.liga_participaciones   enable row level security;
alter table public.liga_propuestas_prueba enable row level security;
alter table public.liga_ajustes_puntos    enable row level security;

-- 11.1 Ediciones
drop policy if exists "liga ediciones lectura" on public.liga_ediciones;
create policy "liga ediciones lectura" on public.liga_ediciones
for select to authenticated using (true);

drop policy if exists "liga ediciones gestiona el equipo" on public.liga_ediciones;
create policy "liga ediciones gestiona el equipo" on public.liga_ediciones
for all to authenticated using (es_staff()) with check (es_staff());

-- 11.2 Categorías
drop policy if exists "liga categorias lectura" on public.liga_categorias;
create policy "liga categorias lectura" on public.liga_categorias
for select to authenticated using (true);

drop policy if exists "liga categorias gestiona el equipo" on public.liga_categorias;
create policy "liga categorias gestiona el equipo" on public.liga_categorias
for all to authenticated using (es_staff()) with check (es_staff());

-- 11.3 Baremo
drop policy if exists "liga baremo lectura" on public.liga_baremo;
create policy "liga baremo lectura" on public.liga_baremo
for select to authenticated using (true);

drop policy if exists "liga baremo gestiona el equipo" on public.liga_baremo;
create policy "liga baremo gestiona el equipo" on public.liga_baremo
for all to authenticated using (es_staff()) with check (es_staff());

-- 11.4 Participaciones
--   Leer: cualquiera con sesión (la clasificación es pública de todos modos).
--   Crear: el equipo, o el propio socio (o su familia) para SUS fichas, y
--          siempre como «pendiente»: nadie se valida su propia prueba.
--   Cambiar/borrar: el equipo siempre; el socio solo mientras siga
--          pendiente de revisión.
drop policy if exists "liga participaciones lectura" on public.liga_participaciones;
create policy "liga participaciones lectura" on public.liga_participaciones
for select to authenticated using (true);

drop policy if exists "liga participaciones alta del equipo" on public.liga_participaciones;
create policy "liga participaciones alta del equipo" on public.liga_participaciones
for insert to authenticated
with check (
  es_staff()
  or (estado = 'pendiente'
      and atleta_id in (select id from public.atletas
                         where perfil_id = mi_perfil_id() or perfil_padre_id = mi_perfil_id()))
);

drop policy if exists "liga participaciones cambia el equipo" on public.liga_participaciones;
create policy "liga participaciones cambia el equipo" on public.liga_participaciones
for update to authenticated
using (
  es_staff()
  or (estado = 'pendiente'
      and atleta_id in (select id from public.atletas
                         where perfil_id = mi_perfil_id() or perfil_padre_id = mi_perfil_id()))
)
with check (
  es_staff()
  or (estado = 'pendiente'
      and atleta_id in (select id from public.atletas
                         where perfil_id = mi_perfil_id() or perfil_padre_id = mi_perfil_id()))
);

drop policy if exists "liga participaciones borra el equipo" on public.liga_participaciones;
create policy "liga participaciones borra el equipo" on public.liga_participaciones
for delete to authenticated
using (
  es_staff()
  or (estado = 'pendiente'
      and atleta_id in (select id from public.atletas
                         where perfil_id = mi_perfil_id() or perfil_padre_id = mi_perfil_id()))
);

-- 11.5 Propuestas de carrera: cada quien ve las suyas; el equipo, todas.
drop policy if exists "liga propuestas lectura" on public.liga_propuestas_prueba;
create policy "liga propuestas lectura" on public.liga_propuestas_prueba
for select to authenticated using (es_staff() or propuesta_por = mi_perfil_id());

drop policy if exists "liga propuestas alta" on public.liga_propuestas_prueba;
create policy "liga propuestas alta" on public.liga_propuestas_prueba
for insert to authenticated
with check (es_staff() or propuesta_por is null or propuesta_por = mi_perfil_id());

drop policy if exists "liga propuestas gestiona el equipo" on public.liga_propuestas_prueba;
create policy "liga propuestas gestiona el equipo" on public.liga_propuestas_prueba
for update to authenticated using (es_staff()) with check (es_staff());

drop policy if exists "liga propuestas borra" on public.liga_propuestas_prueba;
create policy "liga propuestas borra" on public.liga_propuestas_prueba
for delete to authenticated
using (es_staff() or (estado = 'pendiente' and propuesta_por = mi_perfil_id()));

-- 11.6 Ajustes de puntos: los ve cualquiera con sesión (la clasificación
--      tiene que ser explicable), pero solo los escribe el equipo.
drop policy if exists "liga ajustes lectura" on public.liga_ajustes_puntos;
create policy "liga ajustes lectura" on public.liga_ajustes_puntos
for select to authenticated using (true);

drop policy if exists "liga ajustes gestiona el equipo" on public.liga_ajustes_puntos;
create policy "liga ajustes gestiona el equipo" on public.liga_ajustes_puntos
for all to authenticated using (es_staff()) with check (es_staff());

commit;


-- =====================================================================
-- 12. LOS JUSTIFICANTES · bucket PRIVADO en el Storage
-- ---------------------------------------------------------------------
-- Las capturas de la clasificación llevan nombre y dorsal, así que el
-- bucket NO es público: cada archivo se guarda en una carpeta con el
-- identificador de quien lo sube y solo lo ven esa persona y el equipo
-- del club. Las pantallas piden una URL firmada de un rato para verlo.
-- Ruta: liga-justificantes/<id de usuario>/<archivo>
-- =====================================================================

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('liga-justificantes', 'liga-justificantes', false, 10485760,
        array['image/jpeg','image/png','image/webp','image/heic','image/heif','application/pdf'])
on conflict (id) do update
  set public = false,
      file_size_limit = 10485760,
      allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','image/heif','application/pdf'];

drop policy if exists "liga justificantes sube el autor"  on storage.objects;
create policy "liga justificantes sube el autor" on storage.objects
for insert to authenticated
with check (bucket_id = 'liga-justificantes'
            and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "liga justificantes ve el autor y el equipo" on storage.objects;
create policy "liga justificantes ve el autor y el equipo" on storage.objects
for select to authenticated
using (bucket_id = 'liga-justificantes'
       and (public.es_staff() or (storage.foldername(name))[1] = auth.uid()::text));

drop policy if exists "liga justificantes borra el autor y el equipo" on storage.objects;
create policy "liga justificantes borra el autor y el equipo" on storage.objects
for delete to authenticated
using (bucket_id = 'liga-justificantes'
       and (public.es_staff() or (storage.foldername(name))[1] = auth.uid()::text));

commit;


-- =====================================================================
-- 13. CONTENIDO DE ARRANQUE · edición 2026, categorías y Anexo I
-- ---------------------------------------------------------------------
-- Todo esto es editable desde el panel. Si este archivo se vuelve a
-- lanzar, lo que el club haya cambiado NO se pisa.
-- =====================================================================

begin;

insert into public.liga_ediciones (id, anio, nombre, fecha_inicio, fecha_fin, activa, notas) values
  ('11111111-2026-4000-8000-000000000001'::uuid, 2026, 'Liga Apolana 2026',
   '2026-01-01', '2026-12-31', true,
   'El reglamento cierra la liga 7 días antes de la Gala Anual: cuando se sepa la fecha de la gala, se cambia aquí la fecha de fin.')
on conflict (anio) do nothing;

insert into public.liga_categorias (edicion_id, nombre, edad_min, edad_max, orden) values
  ('11111111-2026-4000-8000-000000000001'::uuid, 'Hasta 17 años',   null,  17, 1),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'De 18 a 35 años',   18,  35, 2),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'De 36 a 47 años',   36,  47, 3),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'De 48 a 59 años',   48,  59, 4),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'De 60 en adelante', 60, null, 5)
on conflict (edicion_id, nombre) do nothing;

-- --- Anexo I · tabla oficial de puntos --------------------------------
insert into public.liga_baremo (edicion_id, disciplina, familia, modalidad, distancia_km, puntos, es_relevo, orden) values
  -- Atletismo · pruebas lisas
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     '60 m',              0.060,  6, false,  1),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     '100 m',             0.100,  6, false,  2),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     '200 m',             0.200,  8, false,  3),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     '400 m',             0.400, 10, false,  4),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     '800 m',             0.800, 12, false,  5),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     '1500 m',            1.500, 14, false,  6),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     'Milla (1609 m)',    1.609, 14, false,  7),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     '3000 m',            3.000, 16, false,  8),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     '5000 m',            5.000, 18, false,  9),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_liso',     '10.000 m',         10.000, 22, false, 10),
  -- Atletismo · concursos y combinadas
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_concurso', 'Saltos',             null, 12, false, 11),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_concurso', 'Lanzamientos',       null, 12, false, 12),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_combinada','Heptatlón',          null, 30, false, 13),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_combinada','Decatlón',           null, 35, false, 14),
  -- Atletismo · relevos (por reglamento, no puntúan)
  ('11111111-2026-4000-8000-000000000001'::uuid, 'atletismo', 'atletismo_relevo',   'Relevos',            null,  0, true,  15),

  -- Running
  ('11111111-2026-4000-8000-000000000001'::uuid, 'running',   'running',            '5 km',              5.000, 16, false, 21),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'running',   'running',            '10 km',            10.000, 20, false, 22),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'running',   'running',            'Más de 20 km',     20.000, 28, false, 23),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'running',   'running',            'Más de 40 km',     40.000, 38, false, 24),

  -- Trail / montaña
  ('11111111-2026-4000-8000-000000000001'::uuid, 'trail',     'trail',              '5 km',              5.000, 18, false, 31),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'trail',     'trail',              '10 km',            10.000, 22, false, 32),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'trail',     'trail',              'Más de 20 km',     20.000, 30, false, 33),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'trail',     'trail',              'Más de 40 km',     40.000, 40, false, 34),

  -- Triatlón
  ('11111111-2026-4000-8000-000000000001'::uuid, 'triatlon',  'triatlon',           'Super Sprint',       null, 18, false, 41),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'triatlon',  'triatlon',           'Sprint',             null, 26, false, 42),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'triatlon',  'triatlon',           'Olímpica',           null, 34, false, 43),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'triatlon',  'triatlon',           'Half',               null, 42, false, 44),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'triatlon',  'triatlon',           'Half Ironman',       null, 45, false, 45),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'triatlon',  'triatlon',           'Ironman',            null, 55, false, 46),

  -- Duatlón
  ('11111111-2026-4000-8000-000000000001'::uuid, 'duatlon',   'duatlon',            'Super Sprint',       null, 16, false, 51),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'duatlon',   'duatlon',            'Sprint',             null, 24, false, 52),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'duatlon',   'duatlon',            'Olímpica',           null, 32, false, 53),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'duatlon',   'duatlon',            'Half',               null, 40, false, 54),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'duatlon',   'duatlon',            'Half Ironman',       null, 43, false, 55),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'duatlon',   'duatlon',            'Ironman',            null, 52, false, 56),

  -- Aquabike
  ('11111111-2026-4000-8000-000000000001'::uuid, 'aquabike',  'aquabike',           'Olímpica',           null, 30, false, 61),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'aquabike',  'aquabike',           'Half Ironman',       null, 40, false, 62),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'aquabike',  'aquabike',           'Ironman',            null, 50, false, 63),

  -- Acuatlón
  ('11111111-2026-4000-8000-000000000001'::uuid, 'acuatlon',  'acuatlon',           'Corta',              null, 18, false, 71),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'acuatlon',  'acuatlon',           'Larga',              null, 24, false, 72),

  -- Natación
  ('11111111-2026-4000-8000-000000000001'::uuid, 'natacion',  'natacion_libre',     '50 m',              0.050,  6, false, 81),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'natacion',  'natacion_libre',     '100 m',             0.100, 10, false, 82),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'natacion',  'natacion_libre',     '200 m',             0.200, 14, false, 83),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'natacion',  'natacion_libre',     '400 m',             0.400, 18, false, 84),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'natacion',  'natacion_estilos',   '200 m Estilos',     0.200, 18, false, 85),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'natacion',  'natacion_estilos',   '400 m Estilos',     0.400, 26, false, 86),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'natacion',  'natacion_libre',     '800 m',             0.800, 30, false, 87),
  ('11111111-2026-4000-8000-000000000001'::uuid, 'natacion',  'natacion_relevo',    'Relevos',            null,  0, true,  88)
on conflict (edicion_id, disciplina, modalidad) do nothing;

commit;


-- --- Comprobación rápida ---------------------------------------------
select 'ediciones'        as que, count(*) from public.liga_ediciones
union all select 'categorías',      count(*) from public.liga_categorias
union all select 'baremo',          count(*) from public.liga_baremo
union all select 'participaciones', count(*) from public.liga_participaciones
union all select 'propuestas',      count(*) from public.liga_propuestas_prueba
union all select 'ajustes',         count(*) from public.liga_ajustes_puntos;
