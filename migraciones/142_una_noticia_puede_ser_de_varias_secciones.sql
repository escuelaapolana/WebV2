-- ============================================================
-- 142 · Una noticia puede ser de varias secciones
-- ------------------------------------------------------------
-- LO QUE SE PIDE
-- Poder filtrar las noticias por natación, running, escuela y las
-- demás secciones del club, que hoy no se puede.
--
-- POR QUÉ NO VALE LA COLUMNA QUE YA HAY
-- `noticias.categoria` existe, pero dice OTRA COSA: es el tipo de
-- noticia (competición, club, temporada, resultado, actividad). Y
-- además está desequilibrada hasta ser inútil como filtro: de las
-- 102 noticias publicadas, 78 son «competicion». Un filtro donde
-- tres de cada cuatro caen en el mismo botón no filtra nada.
--
-- Encima las dos listas comparten la palabra «competición» con
-- significados distintos: como categoría es «esto va de una
-- competición»; como sección es «atletismo en pista». Si se usara
-- la misma columna para las dos cosas, nadie sabría cuál de las dos
-- está eligiendo.
--
-- ⚠️ POR QUÉ ES UNA LISTA Y NO UN SOLO CAMPO
-- Porque las noticias reales del club son de varias secciones a la
-- vez. Tal cual están escritas hoy:
--
--   «FIN DE SEMANA MUY ACTIVO… ENTRE CARRERAS, NATACIÓN MÁSTER Y
--    ESPÍRITU TRIPIRATA»          → running + natación + triatlón
--   «APOL-ANA BRILLA EN TRIATLÓN, RUTA Y PISTA»
--                                 → triatlón + running + pista
--
-- Con un solo campo habría que meterlas en un cajón y dejarlas
-- fuera de los otros dos: quien filtre por natación no vería una
-- noticia que habla de natación. El array es lo que describe lo que
-- pasa de verdad, y hay precedente en la casa: `altas_socio.secciones`
-- ya funciona así.
--
-- LAS SECCIONES SON LAS DEL MENÚ DE LA WEB
-- Ni más ni menos, para que el filtro use los mismos nombres que el
-- visitante acaba de leer arriba. Salen de MENU, en assets/js/apolana.js.
--
-- QUÉ NO HACE ESTE ARCHIVO
-- No etiqueta ninguna noticia. Las 102 que hay se quedan con la lista
-- vacía y siguen saliendo en «Todas», que es lo correcto: es preferible
-- una noticia sin sección a una noticia mal clasificada. Etiquetarlas se
-- hace desde el panel, o con un repaso aparte.
--
-- ⚠️ NINGÚN DATO PERSONAL SE ESCRIBE AQUÍ. Este repositorio es PÚBLICO.
--
-- Idempotente: se puede relanzar sin romper nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/142_una_noticia_puede_ser_de_varias_secciones.sql
-- ============================================================

begin;

alter table public.noticias
  add column if not exists secciones text[] not null default '{}';

-- Las mismas nueve del menú, y ninguna inventada: si mañana nace una
-- sección, se añade aquí y en MENU, y no en dieciocho sitios.
alter table public.noticias drop constraint if exists noticias_secciones_check;
alter table public.noticias add constraint noticias_secciones_check
  check (secciones <@ array['escuela','escuela-natacion','campus','competicion',
                            'running','natacion','montana','triatlon','cubo']::text[]);

comment on column public.noticias.secciones is
  'De qué secciones del club habla la noticia. Es una LISTA porque una '
  'crónica de fin de semana habla a la vez de running, natación y triatlón, '
  'y meterla en un solo cajón la escondería de los otros dos. Vacía = sin '
  'clasificar: sale en «Todas» y en ningún filtro. Distinto de `categoria`, '
  'que es el TIPO de noticia (competición, club, temporada…), no el deporte.';

-- El filtro pregunta «¿tiene esta sección?» (operador &&), y para eso el
-- índice que sirve es GIN. Sin él, cada clic recorre la tabla entera.
create index if not exists ix_noticias_secciones
  on public.noticias using gin (secciones);

commit;

-- ============================================================
-- LO QUE SIGUE ABIERTO
-- ------------------------------------------------------------
--   · Las 102 noticias publicadas están sin etiquetar. Hasta que se
--     etiqueten, cada filtro de sección sale vacío. Se puede repasar a
--     mano desde el panel, o proponer una primera pasada automática por
--     palabras del título ("trail", "travesía", "cross"…) para revisarla
--     después. Automático y sin revisar, no: una noticia mal clasificada
--     es peor que una sin clasificar.
--   · `categoria` se queda como está. Son dos ejes distintos y los dos
--     valen; lo que no vale es confundirlos.
-- ============================================================
