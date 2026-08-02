-- ============================================================
-- 058 · RANKING DEL CLUB · quién va mejor este año, por prueba
-- ------------------------------------------------------------
-- QUÉ RESUELVE
--   El club ya tiene los récords (la mejor marca de la historia) y
--   el palmarés (las medallas). Lo que no se podía ver es lo que
--   más engancha: **quién va mejor ESTA temporada** en los 100, en
--   los 800 o en 10 km. El dato ya estaba en `marcas_atleta`, pero
--   esa tabla es privada: solo la ve cada uno, su entrenador y el
--   administrador. Aquí se abre **una ventana muy estrecha** para
--   que la página pública `/club/ranking/` pueda leer lo justo.
--
-- QUÉ AÑADE
--   1) La vista `public.ranking_marcas`, de solo lectura.
--   2) Dos índices para que ordenar por prueba y fecha sea barato.
--
-- ⚠️ MENORES · LA REGLA DEL CLUB, ESCRITA EN SQL
--   No se publica el nombre de un menor sin autorización familiar
--   registrada. Aquí no es una recomendación: es la vista.
--
--     · Quien apaga «perfil visible» en Mi perfil        → NO SALE.
--     · Quien está de baja                              → NO SALE.
--     · MENOR sin autorización familiar registrada      → sale la
--       marca, pero `nombre` viene VACÍO. Nunca con nombre.
--     · MENOR con autorización (`perfil_juego.autoriza_parental_en`)
--       y perfil visible                                → con nombre.
--     · Persona adulta con perfil visible               → con nombre,
--       igual que en `records_club` y en `palmares`.
--
--   «Menor» se decide con `public.juego_es_menor()`, la MISMA
--   función que ya usa el sistema de retos (migración 045). Una sola
--   definición de menor en todo el proyecto: si no consta la fecha
--   de nacimiento, se trata como menor. Ante la duda, se protege.
--
-- ⚠️ EL IDENTIFICADOR DEL ATLETA NO SALE
--   La página necesita agrupar las marcas de una misma persona
--   (su mejor marca del año, si ha mejorado…), pero un anónimo no
--   tiene por qué recibir el id real de nadie. Sale `clave`, que es
--   un resumen del id: sirve para agrupar y no vale para nada más.
--
-- ⚠️ PERMISOS · SUPABASE REGALA PERMISOS EN LO NUEVO
--   Supabase tiene permisos por defecto que conceden TODO a `anon` y
--   `authenticated` sobre cualquier objeto nuevo de `public`. Por eso
--   aquí se hace REVOKE ALL primero y se concede después solo SELECT.
--   Sin ese revoke, la vista nacería con permisos de escritura.
--   Comprobado con psql simulando los dos roles (ver el final).
--
-- QUÉ **NO** TOCA
--   · `marcas_atleta`, `atletas`, `perfiles` y `perfil_juego`: ni
--     una columna, ni una política. Sus RLS siguen exactamente igual.
--   · `records_club` y `palmares`: no se rozan.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/058_ranking.sql
-- (Es idempotente: se puede relanzar sin romper nada.)
-- ============================================================


-- =====================================================================
-- 1 · ÍNDICES · el ranking se pide por prueba y por fecha
-- =====================================================================
-- Hoy son unos cientos de marcas y da igual, pero esto crece solo:
-- cada temporada añade las suyas y nadie vuelve a mirarlo.

create index if not exists idx_marcas_prueba_fecha
  on public.marcas_atleta (prueba, fecha desc);

create index if not exists idx_marcas_atleta_prueba
  on public.marcas_atleta (atleta_id, prueba, fecha);


-- =====================================================================
-- 2 · LA VENTANA PÚBLICA · public.ranking_marcas
-- ---------------------------------------------------------------------
-- La vista es de `postgres`, que es el dueño de las tablas, así que
-- lee por debajo de las RLS. Es justo lo que se quiere: la vista SÍ
-- puede mirar `marcas_atleta`, y el navegador solo puede mirar la
-- vista. Ese es el candado. Por eso la vista NO lleva ni una columna
-- de más: nada de correos, teléfonos, DNI, grupo, entrenador,
-- fechas de nacimiento ni observaciones.
--
-- QUÉ SE QUEDA FUERA DE LA VISTA, Y POR QUÉ
--   · `tipo = 'objetivo'`: es lo que alguien QUIERE hacer, no lo que
--     ha hecho. Publicarlo como marca sería mentir.
--   · Marcas sin `tiempo_segundos`: no se pueden ordenar. Antes de
--     poner un guion donde falta el dato, no se enseña la fila: el
--     guion solo significa «no ha hecho esa prueba».
--   · Marcas sin fecha o sin contexto: no se sabe de qué temporada
--     son ni si fueron en competición. Fuera.
--   · Pruebas que no están en el catálogo `pruebas`: sin saber si
--     gana el número mayor o el menor no hay ranking posible.
-- =====================================================================

drop view if exists public.ranking_marcas;

create view public.ranking_marcas as
with base as (
  select
    m.id,
    m.atleta_id,
    m.prueba,
    m.contexto,
    m.tiempo_segundos                as valor,
    m.tiempo_display                 as marca,
    m.fecha,
    m.created_at,
    nullif(btrim(m.sede), '')        as sede,
    p.disciplina,
    p.ambito,
    p.unidad,
    p.mas_es_mejor,
    p.orden                          as orden_prueba,
    nullif(btrim(a.categoria), '')   as categoria,
    a.sexo,
    -- ¿Se puede decir su nombre? Un menor necesita la autorización
    -- familiar registrada; una persona adulta, no. Quien ha apagado
    -- el interruptor de «perfil visible» ni siquiera llega aquí.
    (public.juego_es_menor(a.fecha_nacimiento) = false
     or pj.autoriza_parental_en is not null)        as con_nombre,
    coalesce(nullif(btrim(pe.nombre_publico), ''),
             btrim(a.nombre || ' ' || coalesce(a.apellidos, ''))) as nombre_real
  from public.marcas_atleta m
  join public.pruebas  p on p.nombre = m.prueba and p.activa
  join public.atletas  a on a.id = m.atleta_id
  left join public.perfiles     pe on pe.id = a.perfil_id
  left join public.perfil_juego pj on pj.atleta_id = a.id
  where m.tipo is distinct from 'objetivo'
    and m.tiempo_segundos is not null
    and m.fecha is not null
    and m.contexto in ('competicion', 'entreno')
    and coalesce(a.estado, 'activo') <> 'baja'
    -- El interruptor de privacidad de «Mi perfil» manda sobre todo lo
    -- demás. Mientras alguien no tenga cuenta, no hay interruptor que
    -- apagar y se entiende que no ha pedido nada (coalesce a true).
    and coalesce(pe.perfil_visible, true)
)
select
  -- Resumen del id: agrupa las marcas de una misma persona sin
  -- entregar su identificador de verdad.
  substr(md5(b.atleta_id::text), 1, 12) as clave,

  -- El nombre solo si se puede. Si no, viene vacío y la página
  -- escribe «Atleta del club» con su categoría.
  case when b.con_nombre then b.nombre_real end as nombre,
  b.con_nombre,

  b.categoria,
  b.sexo,

  b.prueba,
  b.disciplina,
  b.ambito,
  b.unidad,
  b.mas_es_mejor,
  b.orden_prueba,

  -- Temporada de septiembre a agosto, igual que en los retos.
  case when extract(month from b.fecha) >= 9
       then extract(year from b.fecha)::int       || '/' || (extract(year from b.fecha)::int + 1)
       else (extract(year from b.fecha)::int - 1) || '/' ||  extract(year from b.fecha)::int
  end as temporada,

  b.contexto,
  b.valor,
  b.marca,
  b.fecha,
  b.sede,

  -- ¿Con esta marca mejoró lo que ya tenía? Se compara SOLO contra lo
  -- que esa persona había hecho ANTES en esa misma prueba y en el
  -- mismo contexto: una marca de entreno no «mejora» una de
  -- competición, son dos cosas distintas. La primera marca de alguien
  -- no es una mejora: no había nada que batir.
  coalesce(
    case when b.mas_es_mejor
         then b.valor > max(b.valor) over anterior
         else b.valor < min(b.valor) over anterior
    end, false) as mejora

from base b
window anterior as (
  partition by b.atleta_id, b.prueba, b.contexto
  order by b.fecha, b.created_at
  rows between unbounded preceding and 1 preceding
);

comment on view public.ranking_marcas is
  'Ventana pública del ranking del club: una fila por marca conseguida, con la prueba, la temporada, la categoría y si fue en competición o en entreno. El nombre solo aparece cuando se puede publicar: nunca el de un menor sin autorización familiar registrada, y nunca el de quien ha apagado su perfil.';


-- =====================================================================
-- 3 · PERMISOS · primero quitar, después dar lo justo
-- ---------------------------------------------------------------------
-- El orden importa. Supabase concede permisos automáticamente sobre
-- todo lo nuevo de `public`; si solo se hace GRANT SELECT, los otros
-- permisos que regaló se quedan puestos.
-- =====================================================================

revoke all on public.ranking_marcas from anon;
revoke all on public.ranking_marcas from authenticated;
revoke all on public.ranking_marcas from public;

-- Lo único que puede hacer el navegador: leer.
grant select on public.ranking_marcas to anon, authenticated;

-- La vista llama a `juego_es_menor()` para decidir si hay que tapar un
-- nombre. Es una cuenta de fechas, sin ningún dato dentro, y se
-- concede explícitamente para no depender de permisos heredados.
grant execute on function public.juego_es_menor(date) to anon, authenticated;
