-- ============================================================
-- 141 · Las fotos que ya estaban subidas entran en la biblioteca
-- ------------------------------------------------------------
-- QUÉ HACE
-- En `imagenes-club/biblioteca/` hay 155 fotos subidas a mano: 98
-- históricas del club (de 2019 a 2026) y 57 sueltas de buena
-- resolución. Están en el almacén pero no tienen ficha, así que el
-- panel no las ve. Esta migración les crea la ficha.
--
-- ------------------------------------------------------------
-- DE DÓNDE SALEN EL TÍTULO Y LA SECCIÓN
-- Del nombre del archivo, que ya viene puesto con criterio:
--
--   historicas--2019-11-29-gala-cena-club-atletismo-apolana-2019-12.jpg
--               └──fecha──┘ └────────acontecimiento────────┘ └nº┘
--
-- De ahí salen el día, el acontecimiento y —por las palabras que
-- lleva— la sección. Un campeonato es competición, una gala es un
-- evento, una carrera vertical en la sierra es montaña.
--
-- Las que empiezan por `club--` son fotos sueltas del club. Muchas se
-- llaman `IMG_2183` o `WhatsApp Image…`, que no dicen de qué son: a
-- esas se les deja el título vacío a propósito. Inventarles un título
-- sería peor que dejarlo en blanco, porque parecería revisado y no lo
-- está. En las de WhatsApp sí se puede sacar el día del propio nombre,
-- y eso ya sirve para agruparlas.
--
-- ------------------------------------------------------------
-- POR QUÉ AQUÍ NO HAY NI UN NOMBRE DE ARCHIVO ESCRITO
-- El repositorio es público. Uno de esos nombres lleva el nombre y los
-- apellidos de dos atletas (es el titular de una noticia). Así que esta
-- migración no lista nada: lee los nombres del propio almacén y saca de
-- ahí lo que necesita. Lo que se escribe en la base sale de la base.
--
-- ------------------------------------------------------------
-- LO QUE NO HACE
-- No publica ninguna. Todas entran con `publicada_ruta` vacío, o sea,
-- guardadas y no publicadas. Aparecen en el panel y no existen fuera
-- hasta que alguien las elija para un hueco de la web. Ese es justo el
-- cambio que trajo la 140.
--
-- Idempotente: si se pasa dos veces, la segunda no inserta nada
-- (`ruta` es única y se ignoran las repetidas).
-- ============================================================

insert into public.biblioteca_fotos (ruta, cubo, nombre, titulo, categoria, grupo, fecha_foto)
with base as (
  select o.name as ruta,
         regexp_replace(o.name, '^biblioteca/', '') as arch
    from storage.objects o
   where o.bucket_id = 'imagenes-club'
     and o.name like 'biblioteca/%'
     and o.name <> 'biblioteca/.emptyFolderPlaceholder'
),
troceada as (
  select
    ruta,
    arch,
    arch like 'historicas--%' as es_historica,
    -- El día que se hizo la foto, cuando el nombre lo trae delante.
    substring(arch from '^historicas--([0-9]{4}-[0-9]{2}-[0-9]{2})-') as fecha_txt,
    -- El acontecimiento: el nombre sin la fecha, sin el número de orden
    -- y sin la extensión. Es lo que agrupa las fotos de un mismo día.
    regexp_replace(
      regexp_replace(arch, '^historicas--[0-9]{4}-[0-9]{2}-[0-9]{2}-', ''),
      '(-[0-9]+)?\.[a-z0-9]+$', ''
    ) as slug,
    -- Las de WhatsApp y las capturas traen el día dentro del nombre.
    coalesce(
      substring(arch from 'whatsapp-image-([0-9]{4}-[0-9]{2}-[0-9]{2})-at'),
      substring(arch from 'screenshot_([0-9]{8})_')
    ) as fecha_suelta
  from base
),
lista as (
  select
    ruta,
    arch,
    es_historica,
    case
      when fecha_txt is not null then fecha_txt::date
      when fecha_suelta ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then fecha_suelta::date
      when fecha_suelta ~ '^[0-9]{8}$' then to_date(fecha_suelta, 'YYYYMMDD')
    end as fecha_foto,
    -- El acontecimiento en legible: guiones fuera y la primera en mayúscula.
    case when es_historica then
      upper(left(replace(slug, '-', ' '), 1)) || substring(replace(slug, '-', ' ') from 2)
    end as grupo,
    slug
  from troceada
)
select
  ruta,
  'imagenes-club',
  -- El nombre del archivo tal cual, que es lo que se busca cuando se
  -- busca «la que me pasaron por WhatsApp el 4 de junio».
  arch,
  -- Título: el acontecimiento en las históricas; en las sueltas, nada.
  grupo,
  -- Sección, por las palabras del nombre. Gana la primera que encaje,
  -- de la más concreta a la más general: «carrera vertical en la
  -- sierra» es montaña aunque también diga «autonómico».
  case
    when not es_historica                                            then 'club'
    when slug ~ 'vertical|sierra|monte|trail|montana|travesia'       then 'montana'
    when slug ~ 'gala|cena|comida|hermandad|cumpleanos|aniversario'  then 'eventos'
    when slug ~ 'campeonato|autonomico|provincial|nacional|espana|cross|master|alevin|sub[0-9]' then 'competicion'
    else 'club'
  end,
  grupo,
  fecha_foto
from lista
on conflict (ruta) do nothing;
