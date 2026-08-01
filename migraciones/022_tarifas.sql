-- ============================================================
-- 022 · TARIFAS · el precio del club se escribe UNA sola vez
-- ------------------------------------------------------------
-- QUÉ RESUELVE (maqueta 18b «Editor de tarifas»):
--   Hoy el mismo precio está escrito a mano en varios sitios:
--     · assets/js/datos.js, apartado "tarifas" (40, 55, 70, 120…)
--     · contenido_secciones.precio  ("Desde 30 €/mes", "En cuota"…)
--     · contenido_secciones.grupos  ("Velocidad A · 55 €/mes socios…")
--     · el HTML de /socio/, /competicion/, /natacion/, /campus/…
--   Cambiar 40 por 42 obliga hoy a tocar cinco ficheros. Con esta
--   tabla el precio vive en un solo sitio y la web lo lee.
--
-- LO QUE PIDE LA MAQUETA, CAMPO A CAMPO:
--   · Pestañas: Club · secciones / Escuela / El Cubo / Campus /
--     Cuota de socio            -> columna "ambito"
--   · Columnas de la tabla: GRUPO · DÍAS · SOCIO · NO SOCIO ·
--     PERIODICIDAD              -> concepto, dias, importe_socio,
--                                  importe_no_socio, periodicidad
--   · Panel «AFECTA A»          -> seccion + grupo_id (a qué se aplica)
--   · «Entra en vigor»          -> vigente_desde
--   · «Avisar por email a los socios del grupo» -> avisar_email
--   · «…queda registrado en el histórico, con quién lo hizo»
--                               -> clave + vigente_desde/vigente_hasta
--                                  + creado_por
--
-- CÓMO FUNCIONA EL HISTÓRICO (esto es lo importante):
--   Una tarifa NO es una fila: es una SERIE de filas que comparten
--   la misma "clave". Cada fila es una VERSIÓN con su periodo de
--   validez [vigente_desde, vigente_hasta). Al subir un precio no se
--   pisa el anterior: se le pone fecha de fin y se crea una fila
--   nueva que empieza ese día. Así queda el rastro de siempre:
--   qué se cobraba, desde cuándo y quién lo cambió.
--   La función tarifa_nueva_version() hace las dos cosas de golpe.
--
-- IMPORTES QUE NO SON UNA CIFRA:
--   El club tiene precios reales que no son un número ("Incluida en
--   la cuota", "Consultar secretaría", "Precio a consultar"). Para
--   eso está texto_importe: si está relleno, se enseña en lugar de
--   las cifras. Y para los rangos reales ("40 – 55 €/mes según los
--   días") están importe_socio + importe_socio_hasta.
-- ============================================================

-- Necesaria para el candado que impide dos versiones solapadas
-- de la misma tarifa (mezcla texto e intervalos de fechas).
create extension if not exists btree_gist;

-- ------------------------------------------------------------
-- 1) LA TABLA
-- ------------------------------------------------------------
create table if not exists public.tarifas (
  id                     uuid primary key default gen_random_uuid(),

  -- Identificador ESTABLE de la tarifa a lo largo de todas sus
  -- versiones. Todas las filas con la misma clave son la misma
  -- tarifa en distintos momentos del tiempo.
  clave                  text not null,

  -- Pestaña del editor / bloque del club al que pertenece
  ambito                 text not null default 'club',

  concepto               text not null,          -- "Pista · Velocidad A"
  seccion                text,                   -- contenido_secciones.seccion
  grupo_id               uuid references public.grupos(id) on delete set null,
  dias                   text,                   -- "5 días", "M, J, S", "Fines de semana"

  importe_socio          numeric(8,2),
  importe_socio_hasta    numeric(8,2),           -- solo si el precio es un rango
  importe_no_socio       numeric(8,2),
  importe_no_socio_hasta numeric(8,2),
  texto_importe          text,                   -- "Incluida", "Consultar secretaría"…

  periodicidad           text,

  vigente_desde          date not null default current_date,
  vigente_hasta          date,                   -- null = sigue en vigor

  notas                  text,
  avisar_email           boolean not null default false,
  orden                  integer not null default 0,
  activo                 boolean not null default true,

  creado_por             uuid references public.perfiles(id),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),

  constraint tarifas_fechas_ok
    check (vigente_hasta is null or vigente_hasta > vigente_desde)
);

-- Las restricciones van aparte para que el fichero se pueda volver
-- a pasar sin romper si la tabla ya existía.
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'tarifas_ambito_check') then
    alter table public.tarifas add constraint tarifas_ambito_check
      check (ambito in ('club','escuela','cubo','campus','socio'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'tarifas_periodicidad_check') then
    alter table public.tarifas add constraint tarifas_periodicidad_check
      check (periodicidad is null or periodicidad in
        ('mensual','trimestral','anual','temporada','semanal','pago único','por sesión','bono'));
  end if;
  -- Dos versiones VIVAS de la misma tarifa no pueden pisarse en el
  -- tiempo. Lo vigila la base de datos, no el navegador.
  if not exists (select 1 from pg_constraint where conname = 'tarifas_sin_solape') then
    alter table public.tarifas add constraint tarifas_sin_solape
      exclude using gist (
        clave with =,
        daterange(vigente_desde, vigente_hasta, '[)') with &&
      ) where (activo);
  end if;
end $$;

create index if not exists idx_tarifas_clave    on public.tarifas (clave, vigente_desde desc);
create index if not exists idx_tarifas_ambito   on public.tarifas (ambito, orden, concepto);
create index if not exists idx_tarifas_seccion  on public.tarifas (seccion);
create index if not exists idx_tarifas_grupo    on public.tarifas (grupo_id);

comment on table  public.tarifas is
  'Precios del club. Una tarifa = varias filas con la misma "clave", cada una con su periodo de validez. Fuente única para la web, la inscripción y los recibos.';
comment on column public.tarifas.clave is
  'Identificador estable de la tarifa. No cambia al crear una versión nueva: es lo que hila el histórico.';
comment on column public.tarifas.ambito is
  'Pestaña del editor: club (secciones), escuela, cubo, campus, socio.';
comment on column public.tarifas.dias is
  'Cómo se expresan los días en la web: "5 días", "3 a 5 días", "M, J, S", "Fines de semana".';
comment on column public.tarifas.importe_socio_hasta is
  'Solo para precios que en la web son un rango ("40 – 55 €/mes según los días"). Si es null, el precio es una cifra exacta.';
comment on column public.tarifas.texto_importe is
  'Cuando el precio no es una cifra: "Incluida en la cuota", "Consultar secretaría", "Precio a consultar". Si está relleno manda sobre los importes.';
comment on column public.tarifas.vigente_desde is
  'Fecha de entrada en vigor (el campo "Entra en vigor" de la maqueta).';
comment on column public.tarifas.vigente_hasta is
  'Día en que dejó de aplicarse (no incluido). Null = sigue en vigor. Se rellena solo al crear la versión siguiente.';
comment on column public.tarifas.avisar_email is
  'Marca "Avisar por email a los socios del grupo" del panel de cambio.';

-- ------------------------------------------------------------
-- 2) SELLADO AUTOMÁTICO (quién y cuándo)
-- ------------------------------------------------------------
create or replace function public.tarifas_sellar()
returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
begin
  if TG_OP = 'INSERT' and NEW.creado_por is null then
    NEW.creado_por := public.mi_perfil_id();
  end if;
  NEW.updated_at := now();
  return NEW;
end;
$function$;

drop trigger if exists trg_tarifas_sellar on public.tarifas;
create trigger trg_tarifas_sellar
  before insert or update on public.tarifas
  for each row execute function public.tarifas_sellar();

-- ------------------------------------------------------------
-- 3) LO QUE ESTÁ EN VIGOR HOY (lo que lee la web pública)
-- ------------------------------------------------------------
create or replace view public.tarifas_vigentes as
  select t.*
  from public.tarifas t
  where t.activo
    and t.vigente_desde <= current_date
    and (t.vigente_hasta is null or t.vigente_hasta > current_date);

alter view public.tarifas_vigentes set (security_invoker = on);

comment on view public.tarifas_vigentes is
  'Las tarifas que se aplican HOY. Las páginas públicas leen de aquí y así nunca enseñan un precio caducado ni uno que todavía no ha entrado en vigor.';

-- ------------------------------------------------------------
-- 4) CAMBIAR UN PRECIO = CREAR UNA VERSIÓN NUEVA
--    Cierra la versión que estaba en vigor y crea la siguiente con
--    los cambios encima. Las dos cosas, o ninguna.
--    p_cambios es un objeto con solo los campos que cambian, p. ej.
--    {"importe_socio": 42}.
-- ------------------------------------------------------------
create or replace function public.tarifa_nueva_version(
  p_id      uuid,
  p_desde   date,
  p_cambios jsonb default '{}'::jsonb
)
returns uuid
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_old public.tarifas;
  v_new jsonb;
  v_id  uuid := gen_random_uuid();
begin
  if not public.es_admin() then
    raise exception 'Solo administración puede cambiar las tarifas.' using errcode = 'P0001';
  end if;

  select * into v_old from public.tarifas where id = p_id;
  if not found then
    raise exception 'Esa tarifa no existe.' using errcode = 'P0001';
  end if;

  if p_desde is null then
    raise exception 'Hace falta la fecha de entrada en vigor.' using errcode = 'P0001';
  end if;
  if p_desde <= v_old.vigente_desde then
    raise exception 'La nueva versión tiene que entrar en vigor después del %, que es cuando empezó la actual.',
      to_char(v_old.vigente_desde, 'DD/MM/YYYY') using errcode = 'P0001';
  end if;
  if v_old.vigente_hasta is not null and p_desde >= v_old.vigente_hasta then
    raise exception 'Esa versión ya dejó de aplicarse el %. Crea la versión nueva a partir de la última.',
      to_char(v_old.vigente_hasta, 'DD/MM/YYYY') using errcode = 'P0001';
  end if;

  -- 1) se cierra la versión anterior: NO se pisa, se queda en el histórico
  update public.tarifas
     set vigente_hasta = p_desde,
         updated_at    = now()
   where id = p_id;

  -- 2) se crea la siguiente, copiando lo que no cambia
  v_new := to_jsonb(v_old)
           || coalesce(p_cambios, '{}'::jsonb)
           || jsonb_build_object(
                'id',            v_id,
                'clave',         v_old.clave,
                'vigente_desde', p_desde,
                'vigente_hasta', null,
                'activo',        true,
                'creado_por',    public.mi_perfil_id(),
                'created_at',    now(),
                'updated_at',    now()
              );

  insert into public.tarifas
  select * from jsonb_populate_record(null::public.tarifas, v_new);

  return v_id;
end;
$function$;

comment on function public.tarifa_nueva_version(uuid, date, jsonb) is
  'Sube o baja un precio sin perder el anterior: cierra la versión en vigor el día indicado y crea la siguiente a partir de esa fecha.';

grant execute on function public.tarifa_nueva_version(uuid, date, jsonb) to authenticated;

-- ------------------------------------------------------------
-- 5) REGLAS DE SEGURIDAD (RLS)
--    Los precios se enseñan en la web pública, así que cualquiera
--    puede LEERLOS. Tocarlos, solo administración.
-- ------------------------------------------------------------
alter table public.tarifas enable row level security;

drop policy if exists "lectura publica de tarifas" on public.tarifas;
create policy "lectura publica de tarifas" on public.tarifas
  for select using (true);

drop policy if exists "admin gestiona tarifas" on public.tarifas;
create policy "admin gestiona tarifas" on public.tarifas
  for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

grant select on public.tarifas to anon;
grant select, insert, update, delete on public.tarifas to authenticated;
grant select on public.tarifas_vigentes to anon, authenticated;

-- ------------------------------------------------------------
-- 6) PRECARGA · SOLO PRECIOS QUE YA EXISTEN EN EL PROYECTO
-- ------------------------------------------------------------
-- De dónde sale cada cifra:
--   · assets/js/datos.js -> apartado "tarifas"
--   · contenido_secciones.precio y contenido_secciones.grupos
--   · las tablas de precios del HTML público (/socio/, /escuela/,
--     /natacion/, /escuela-natacion/, /cubo/, /campus/,
--     /escuela-municipal-atletismo/)
-- No se inventa ninguna: lo que no estaba claro se ha dejado fuera.
--
-- vigente_desde = hoy porque NO consta en ninguna parte desde qué
-- día se aplica cada precio. El histórico empieza aquí; a partir de
-- ahora cada cambio deja su fecha.
-- ------------------------------------------------------------
with nuevas (clave, ambito, concepto, seccion, dias,
             importe_socio, importe_socio_hasta, importe_no_socio, importe_no_socio_hasta,
             texto_importe, periodicidad, notas, orden) as (values

  -- ===== CLUB · SECCIONES =====
  ('pista-velocidad-a'::text, 'club'::text, 'Pista · Velocidad A'::text, 'competicion'::text, '5 días'::text,
     55::numeric, null::numeric, 70::numeric, null::numeric,
     null::text, 'trimestral'::text, 'Acceso restringido, por decisión del club.'::text, 10::int),
  ('pista-velocidad-b', 'club', 'Pista · Velocidad B', 'competicion', '3 días',
     40, null, 70, null, null, 'trimestral', null, 20),
  ('pista-fondo-medio-fondo', 'club', 'Pista · Fondo y medio fondo', 'competicion', '3 a 5 días',
     40, 55, 70, null, null, 'trimestral', 'De 40 a 55 € según los días que se entrenen.', 30),
  ('pista-recreativo', 'club', 'Pista · Grupo recreativo', 'competicion', '3 días',
     40, null, 70, null, null, 'trimestral', null, 40),

  ('running-madre-tierra', 'club', 'Running · Madre Tierra', 'running', 'M, J, S',
     40, null, null, null, null, 'mensual', '20-40 km por semana · 10K y media.', 50),
  ('running-la-tribu', 'club', 'Running · La Tribu', 'running', 'M, J, S',
     60, null, null, null, null, 'mensual', '40-80 km por semana · media y maratón.', 60),

  ('natacion-bono-4', 'club', 'Natación · bono 4 clases', 'natacion', '1 día',
     35, null, 50, null, null, 'mensual', null, 70),
  ('natacion-bono-8', 'club', 'Natación · bono 8 clases', 'natacion', '2 días',
     45, null, 60, null, null, 'mensual', 'El más elegido.', 80),
  ('natacion-bono-12', 'club', 'Natación · bono 12 clases', 'natacion', '3 días',
     55, null, 70, null, null, 'mensual', null, 90),

  ('montana', 'club', 'Montaña', 'montana', 'Fines de semana',
     null, null, null, null, 'Incluida', null, 'Incluida en la cuota de socio.', 100),
  ('triatlon', 'club', 'Triatlón', 'triatlon', null,
     null, null, null, null, 'Consultar secretaría', null, null, 110),
  ('deporte-adaptado', 'club', 'Deporte adaptado', 'deporte-adaptado', null,
     null, null, null, null, 'Consultar secretaría', null, null, 120),

  -- ===== ESCUELA =====
  -- Cuotas de temporada de /escuela/ (dos pagos, cubren hasta junio)
  ('escuela-2016-2023', 'escuela', 'Escuela · nacidos 2016 – 2023', 'escuela', null,
     300, null, null, null, null, 'temporada',
     'Dos pagos: 170 € al inscribirse y 130 € en diciembre. 20 % de descuento el segundo hermano y 40 % el tercero y siguientes.', 10),
  ('escuela-2012-2015', 'escuela', 'Escuela · nacidos 2012 – 2015', 'escuela', null,
     350, null, null, null, null, 'temporada',
     'Dos pagos: 195 € al inscribirse y 155 € en diciembre. 20 % de descuento el segundo hermano y 40 % el tercero y siguientes.', 20),
  ('escuela-2009-2011', 'escuela', 'Escuela · nacidos 2009 – 2011', 'escuela', null,
     370, null, null, null, null, 'temporada',
     'Dos pagos: 200 € al inscribirse y 170 € en diciembre. 20 % de descuento el segundo hermano y 40 % el tercero y siguientes.', 30),

  -- Escuela de natación
  ('escuela-natacion-1', 'escuela', 'Escuela de natación · 1 clase por semana', 'escuela-natacion', '1 día',
     35, null, null, null, null, 'mensual',
     'Recibo domiciliado del 1 al 5 de cada mes. 20 % de descuento el segundo hermano y 40 % el tercero y siguientes.', 40),
  ('escuela-natacion-2', 'escuela', 'Escuela de natación · 2 clases por semana', 'escuela-natacion', '2 días',
     45, null, null, null, null, 'mensual',
     'Recibo domiciliado del 1 al 5 de cada mes. 20 % de descuento el segundo hermano y 40 % el tercero y siguientes.', 50),
  ('escuela-natacion-3', 'escuela', 'Escuela de natación · 3 clases por semana', 'escuela-natacion', '3 días',
     55, null, null, null, null, 'mensual',
     'Recibo domiciliado del 1 al 5 de cada mes. 20 % de descuento el segundo hermano y 40 % el tercero y siguientes.', 60),

  -- Escuela municipal de atletismo (un solo pago por toda la actividad)
  ('escuela-municipal-general', 'escuela', 'Escuela municipal · tarifa general', 'escuela-municipal', null,
     70, null, null, null, null, 'temporada',
     'Un único pago por toda la actividad, camiseta y seguro incluidos.', 70),
  ('escuela-municipal-segundo-hermano', 'escuela', 'Escuela municipal · segundo hermano', 'escuela-municipal', null,
     50, null, null, null, null, 'temporada', null, 80),
  ('escuela-municipal-familia-numerosa', 'escuela', 'Escuela municipal · familia numerosa', 'escuela-municipal', null,
     60, null, null, null, null, 'temporada', null, 90),

  -- ===== EL CUBO =====
  ('cubo-padres', 'cubo', 'El Cubo · padres y madres', 'cubo', '3 sesiones',
     40, null, null, null, null, 'mensual',
     'Entrena mientras tu hijo está en la escuela. L a J 17:30-18:30 · L y X 18:30-20:00.', 10),
  ('cubo-padres-escuela', 'cubo', 'El Cubo · padres y madres con hijo en la escuela', 'cubo', '3 sesiones',
     30, null, null, null, null, 'mensual',
     'Precio reducido si tu hijo o hija está en la escuela.', 20),
  ('cubo-socios', 'cubo', 'El Cubo · socios del club', 'cubo', null,
     null, null, null, null, 'Consultar disponibilidad', null,
     'Horario de mañana asignado. Las franjas se asignan por orden.', 30),
  ('cubo-escuela', 'cubo', 'El Cubo · atletas de la escuela', 'cubo', 'M y J',
     null, null, null, null, 'Incluido en la cuota', null,
     'Fuerza dentro del entrenamiento, martes y jueves de 18:30 a 20:00.', 40),
  ('cubo-alquiler', 'cubo', 'El Cubo · alquiler a grupos', 'cubo', null,
     null, null, null, null, 'Precio a consultar', null,
     'Entidades y grupos externos.', 50),

  -- ===== CAMPUS =====
  -- Precio base de un alumno sin servicios opcionales
  ('campus-1-semana', 'campus', 'Campus · 1 semana', 'campus', null,
     99, null, null, null, null, 'pago único',
     '15 % de descuento para el segundo hermano (no aplica al comedor).', 10),
  ('campus-2-semanas', 'campus', 'Campus · 2 semanas', 'campus', null,
     189, null, null, null, null, 'pago único',
     '15 % de descuento para el segundo hermano (no aplica al comedor).', 20),
  ('campus-3-semanas', 'campus', 'Campus · 3 semanas', 'campus', null,
     249, null, null, null, null, 'pago único',
     '15 % de descuento para el segundo hermano (no aplica al comedor).', 30),
  ('campus-4-semanas', 'campus', 'Campus · 4 semanas', 'campus', null,
     299, null, null, null, null, 'pago único',
     '15 % de descuento para el segundo hermano (no aplica al comedor).', 40),
  ('campus-5-semanas', 'campus', 'Campus · 5 semanas', 'campus', null,
     349, null, null, null, null, 'pago único',
     '15 % de descuento para el segundo hermano (no aplica al comedor).', 50),
  ('campus-comedor', 'campus', 'Campus · comedor', 'campus', null,
     42, null, null, null, null, 'semanal',
     'Por persona. Recogida de 15:00 a 15:30.', 60),
  ('campus-matinera', 'campus', 'Campus · matinera', 'campus', null,
     12, null, null, null, null, 'semanal',
     'Por familia, aunque vengan varios hermanos. De 7:40 a 9:00.', 70),

  -- ===== CUOTA DE SOCIO =====
  ('cuota-socio', 'socio', 'Cuota de socio', null, null,
     120, null, null, null, null, 'anual',
     'Licencia, seguro, acceso a instalaciones y voz en la asamblea. Se cobra en septiembre y es independiente del entrenamiento.', 10)
)
insert into public.tarifas (clave, ambito, concepto, seccion, dias,
                            importe_socio, importe_socio_hasta, importe_no_socio, importe_no_socio_hasta,
                            texto_importe, periodicidad, notas, orden, vigente_desde)
select n.clave, n.ambito, n.concepto, n.seccion, n.dias,
       n.importe_socio, n.importe_socio_hasta, n.importe_no_socio, n.importe_no_socio_hasta,
       n.texto_importe, n.periodicidad, n.notas, n.orden, current_date
from nuevas n
where not exists (select 1 from public.tarifas t where t.clave = n.clave);

-- ------------------------------------------------------------
-- 7) LO QUE SE HA DEJADO FUERA A PROPÓSITO (no consta el dato)
--    · contenido_secciones 'mun-atletismo' y 'mun-triatlon' dicen
--      "Subvencionado", pero la página de la escuela municipal
--      enseña 70 / 50 / 60 €. Se han cargado esas cifras bajo la
--      sección 'escuela-municipal' y no la palabra "Subvencionado".
--    · contenido_secciones 'instalaciones' pone "En cuota": no es
--      una tarifa, es una nota de la página.
--    · La matriz completa del campus (comedor, matinera y segundo
--      hermano ya sumados) es un cálculo a partir del precio base
--      más los servicios: se guardan las piezas, no los totales.
--    · El suplemento por ampliar la escuela a 5 días por semana:
--      la web dice "consultar precio", así que no hay cifra.
-- ------------------------------------------------------------
