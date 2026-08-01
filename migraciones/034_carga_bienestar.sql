-- =====================================================================
-- 034_carga_bienestar.sql  ·  CARGA DE ENTRENAMIENTO Y BIENESTAR
-- =====================================================================
-- Para qué sirve:
--
--   1) Guardar cuánto DURA cada sesión. Sin duración no se puede medir
--      la carga de entrenamiento: la carga de una sesión es
--      «esfuerzo (RPE 1-10) × minutos». Es el método sRPE, el más
--      sencillo y el más contrastado.
--
--   2) Dejar sembradas unas semanas de sensaciones de ejemplo para poder
--      ver los gráficos de /portal/carga/ con datos. Todo lo sembrado
--      lleva identificador «dddddddd-», igual que el resto de datos de
--      demostración, así que 901_borrar_datos_demo.sql se lo lleva.
--
-- No cambia ningún permiso: las políticas que ya existen valen tal cual
--   · registros_sesion → «ver datos de mis atletas» (atleta_id in mis_atletas())
--   · sesiones         → el atleta ve las publicadas de su grupo;
--                        el entrenador, las de sus grupos; admin, todas.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/034_carga_bienestar.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. LA DURACIÓN DE LA SESIÓN
-- ---------------------------------------------------------------------
-- Minutos de trabajo previstos, calentamiento incluido. Si está vacío,
-- la web estima la duración por el tipo de sesión y AVISA de que es una
-- estimación (nunca se la inventa en silencio).
alter table sesiones add column if not exists duracion_min int;

comment on column sesiones.duracion_min is
  'Duración prevista de la sesión en minutos (calentamiento incluido). '
  'Se usa para calcular la carga: RPE x minutos. Si está vacío, la web '
  'estima por tipo de sesión y lo indica como "duración estimada".';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'sesiones_duracion_min_check') then
    alter table sesiones add constraint sesiones_duracion_min_check
      check (duracion_min is null or (duracion_min > 0 and duracion_min <= 600));
  end if;
end $$;

-- Un índice por atleta + fecha ayuda a los listados de carga del grupo.
create index if not exists idx_registros_atleta_creado
  on registros_sesion (atleta_id, created_at desc);

commit;


-- =====================================================================
-- 2. DATOS DE EJEMPLO (FICTICIOS) PARA VER LOS GRÁFICOS
-- =====================================================================
-- Antes de esta migración la tabla registros_sesion estaba VACÍA: sin
-- sensaciones no hay nada que dibujar. Aquí se siembran doce semanas de
-- entrenamientos y de sensaciones para cuatro grupos.
--
-- Se puede volver a lanzar cuando se quiera: primero borra lo que sembró
-- la vez anterior (tramos 0034 y 0035) y lo vuelve a crear con la fecha
-- de hoy, para que los gráficos siempre lleguen hasta la semana actual.
-- =====================================================================

begin;

delete from registros_sesion where id::text like 'dddddddd-0035-%';
delete from sesiones         where id::text like 'dddddddd-0034-%';

-- --- 2.1 Doce semanas de entrenamientos publicados -------------------
with plantilla (grupo_id, dow, tipo, rol, titulo, duracion_min) as (
  values
    -- Velocidad · Sub-20 (grupo real del club)
    ('11111111-1111-4111-8111-111111111111'::uuid, 1, 'pista',    'calidad_fuerte', 'Series cortas y salidas',        95),
    ('11111111-1111-4111-8111-111111111111'::uuid, 3, 'pista',    'secundaria',     'Técnica de carrera y velocidad', 85),
    ('11111111-1111-4111-8111-111111111111'::uuid, 5, 'gym',      'secundaria',     'Fuerza general',                 60),
    ('11111111-1111-4111-8111-111111111111'::uuid, 6, 'continuo', 'activacion',     'Rodaje suave y movilidad',       45),
    -- Velocidad A
    ('dddddddd-0002-4000-8000-000000000001'::uuid, 1, 'pista',    'calidad_fuerte', 'Velocidad lanzada',              95),
    ('dddddddd-0002-4000-8000-000000000001'::uuid, 2, 'gym',      'secundaria',     'Fuerza y pliometría',            55),
    ('dddddddd-0002-4000-8000-000000000001'::uuid, 4, 'pista',    'calidad_fuerte', 'Series de 150 y 200',           100),
    ('dddddddd-0002-4000-8000-000000000001'::uuid, 6, 'pista',    'secundaria',     'Salidas y tacos',                80),
    -- Fondistas
    ('dddddddd-0021-4000-8000-000000000002'::uuid, 1, 'continuo', 'secundaria',     'Rodaje medio',                   70),
    ('dddddddd-0021-4000-8000-000000000002'::uuid, 3, 'pista',    'calidad_fuerte', 'Series largas en pista',         90),
    ('dddddddd-0021-4000-8000-000000000002'::uuid, 5, 'continuo', 'activacion',     'Rodaje suave',                   55),
    ('dddddddd-0021-4000-8000-000000000002'::uuid, 7, 'continuo', 'calidad_fuerte', 'Tirada larga',                  105),
    -- Natación · Perfeccionamiento
    ('dddddddd-0002-4000-8000-000000000008'::uuid, 1, 'natacion', 'secundaria',     'Técnica de los cuatro estilos',  75),
    ('dddddddd-0002-4000-8000-000000000008'::uuid, 2, 'natacion', 'calidad_fuerte', 'Series de crol por calles',      80),
    ('dddddddd-0002-4000-8000-000000000008'::uuid, 4, 'natacion', 'calidad_fuerte', 'Ritmo de competición',           80),
    ('dddddddd-0002-4000-8000-000000000008'::uuid, 5, 'gym',      'secundaria',     'Trabajo en seco',                45)
),
semanas as (
  select generate_series(0, 11) as w
),
brutas as (
  select p.grupo_id, p.tipo, p.rol, p.titulo, p.duracion_min,
         (date_trunc('week', current_date)::date - (s.w * 7) + (p.dow - 1)) as fecha
    from plantilla p cross join semanas s
),
filtradas as (
  select b.*,
         row_number() over (order by b.fecha, b.grupo_id, b.titulo) as n
    from brutas b
   where b.fecha <= current_date
)
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, bloques, publicada, duracion_min)
select ('dddddddd-0034-4000-8000-' || lpad(f.n::text, 12, '0'))::uuid,
       f.grupo_id,
       f.fecha,
       (array['domingo','lunes','martes','miércoles','jueves','viernes','sábado'])[extract(dow from f.fecha)::int + 1],
       f.tipo,
       f.rol,
       f.titulo,
       '[]'::jsonb,
       true,
       f.duracion_min + ((mod(('x' || substr(md5(f.fecha::text || f.titulo), 1, 6))::bit(24)::int, 3) - 1) * 5)
  from filtradas f;

-- --- 2.2 Las sensaciones de cada atleta ------------------------------
-- Cómo se inventan (siempre igual, no cambian de una vez a otra: salen
-- de un cálculo sobre el identificador del atleta y de la sesión):
--   · el esfuerzo (RPE) parte del tipo de sesión y varía un punto arriba
--     o abajo;
--   · a cada atleta le toca un «perfil» del 0 al 9 y unos pocos llevan
--     algo llamativo a propósito, para poder ver los avisos funcionando:
--       0 y 1 → subida brusca de carga en los últimos doce días
--       2     → duerme poco
--       3     → arrastra la misma molestia una y otra vez
--       4     → apenas rellena las sesiones (cumplimiento bajo)
--       7     → rellena a medias
--     el resto entrena de forma sana y estable.
with base as (
  select s.id as sesion_id, s.fecha, s.tipo, a.id as atleta_id,
         (current_date - s.fecha) as dias_atras,
         mod(('x' || substr(md5(s.id::text || a.id::text || 'r0'), 1, 6))::bit(24)::int, 100) as h0,
         mod(('x' || substr(md5(s.id::text || a.id::text || 'r1'), 1, 6))::bit(24)::int, 100) as h1,
         mod(('x' || substr(md5(s.id::text || a.id::text || 'r2'), 1, 6))::bit(24)::int, 100) as h2,
         mod(('x' || substr(md5(s.id::text || a.id::text || 'r3'), 1, 6))::bit(24)::int, 100) as h3,
         mod(('x' || substr(md5(s.id::text || a.id::text || 'r4'), 1, 6))::bit(24)::int, 100) as h4,
         mod(('x' || substr(md5(s.id::text || a.id::text || 'r5'), 1, 6))::bit(24)::int, 100) as h5,
         mod(('x' || substr(md5(s.id::text || a.id::text || 'r6'), 1, 6))::bit(24)::int, 100) as h6,
         mod(('x' || substr(md5(a.id::text || 'perfil'), 1, 6))::bit(24)::int, 10)  as perfil,
         mod(('x' || substr(md5(a.id::text || 'peso'),   1, 6))::bit(24)::int, 30)  as peso_base,
         mod(('x' || substr(md5(a.id::text || 'zona'),   1, 6))::bit(24)::int, 8)   as zona
    from sesiones s
    join atletas  a on a.grupo_id = s.grupo_id
   where s.id::text like 'dddddddd-0034-%'
     and coalesce(a.estado, 'activo') <> 'baja'
),
calculada as (
  select b.*,
         case b.tipo when 'pista' then 8 when 'natacion' then 6 when 'continuo' then 5
                     when 'gym' then 6 when 'activacion' then 3 else 7 end as rpe_base,
         case when b.perfil in (0, 1) and b.dias_atras <= 12 then 2 else 0 end as subidon,
         case when b.perfil = 4 then 35 when b.perfil = 7 then 62 else 88 end as umbral
    from base b
),
final as (
  select c.*,
         greatest(1, least(10, c.rpe_base + (c.h1 % 3) - 1 + c.subidon)) as rpe
    from calculada c
   where c.h0 < c.umbral
)
insert into registros_sesion
  (id, sesion_id, atleta_id, rpe, sensacion_general, horas_sueno, peso_kg, molestias, notas_atleta, created_at)
select ('dddddddd-0035-4000-8000-' || lpad((row_number() over (order by f.fecha, f.sesion_id, f.atleta_id))::text, 12, '0'))::uuid,
       f.sesion_id,
       f.atleta_id,
       f.rpe,
       -- Sensación general: al revés que el esfuerzo, y peor si duerme mal.
       greatest(1, least(10, 12 - f.rpe + (f.h2 % 3) - 1 - (case when f.perfil = 2 then 2 else 0 end))),
       -- Horas de sueño
       case when f.perfil = 2 then round((5.2 + (f.h3 % 9) / 10.0)::numeric, 1)
            else                   round((6.8 + (f.h3 % 18) / 10.0)::numeric, 1) end,
       -- Peso: cada atleta tiene el suyo y oscila unos gramos
       round((52 + f.peso_base + (f.h4 % 7 - 3) / 10.0)::numeric, 1),
       -- Molestias: el perfil 3 repite siempre la misma zona; los demás, alguna suelta
       case
         when f.perfil = 3 and f.h5 < 45 then
           (array['Molestia en el gemelo derecho','Tirantez en los isquios','Molestia en el tendón de Aquiles',
                  'Cargado de cuádriceps','Molestia en la rodilla izquierda','Sobrecarga lumbar',
                  'Molestia en el hombro derecho','Molestia en el aductor'])[f.zona + 1]
         when f.h5 < 6 then
           (array['Algo cargado el gemelo','Tirantez en los isquios','Molestia leve en el tobillo',
                  'Rozadura en el pie','Sobrecarga lumbar','Molestia en el hombro',
                  'Cargado de cuádriceps','Molestia en la planta del pie'])[f.h5 + 1]
         else null
       end,
       case when f.h6 < 14 then
         (array['Buenas sensaciones.','Me ha costado arrancar.','Terminé fuerte.','Mucho calor hoy.',
                'Piernas pesadas del día anterior.','Sesión completa, sin problemas.','Voy notando mejoría.'])[f.h6 % 7 + 1]
       end,
       (f.fecha + time '20:45') at time zone 'Europe/Madrid'
  from final f;

commit;

-- --- Comprobación rápida ---------------------------------------------
select 'sesiones sembradas'  as que, count(*) from sesiones         where id::text like 'dddddddd-0034-%'
union all
select 'registros sembrados',       count(*) from registros_sesion  where id::text like 'dddddddd-0035-%';
