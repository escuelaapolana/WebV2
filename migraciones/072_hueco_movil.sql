-- ============================================================
-- 072 · UN SEGUNDO HUECO DE FOTO, SOLO PARA LA PORTADA EN MÓVIL
-- ------------------------------------------------------------
-- QUÉ RESUELVE (decisión del diseñador, textual):
--   «Segundo hueco solo en la portada. En las demás cabeceras,
--    recorte CSS — no merece 28 huecos extra que alguien tiene
--    que rellenar.»
--
--   La portada tiene una sola foto grande (hueco 'home.hero'). En el
--   móvil esa misma foto se aproxima con CSS (se acerca y se sube) para
--   que los atletas queden en el tercio de arriba. Se aproxima bien,
--   pero es una aproximación: una foto pensada para 375 px de ancho
--   siempre va a quedar mejor.
--
-- CÓMO QUEDA:
--   Un hueco nuevo, 'home.hero.movil', que es OPCIONAL:
--     · Si el club sube una foto ahí → en el móvil se usa esa, con su
--       encuadre y su acercamiento.
--     · Si lo deja vacío → no cambia nada: el móvil sigue usando la
--       foto de escritorio con el recorte CSS de siempre.
--   Nada se rompe con el hueco vacío, que es como nace.
--
--   El HTML lo marca con data-img-movil="home.hero.movil" en la misma
--   <img> de la portada, y assets/js/imagenes-web.js decide cuál pone
--   según el ancho de la pantalla.
--
-- ⚠️ PERMISOS: Supabase reparte privilegios de serie en las tablas
--   nuevas del esquema public, y `imagenes_web` los tiene puestos así
--   desde que nació: `anon` con INSERT, UPDATE, DELETE y TRUNCATE.
--   Hoy no se puede aprovechar porque el candado RLS no deja escribir a
--   nadie que no sea administración... salvo TRUNCATE, que **se salta la
--   RLS**: cualquiera con la clave pública podía vaciar la tabla entera.
--   Aquí se quitan esos privilegios a mano y se dejan los tres justos.
--
-- Idempotente: se puede relanzar sin duplicar ni pisar la foto elegida.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/072_hueco_movil.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · EL HUECO NUEVO
-- ------------------------------------------------------------
-- `respaldo` apunta a la foto de escritorio: es la que se ve hoy en el
-- móvil, así que es la miniatura honesta para el panel.
-- `orden` = 1 para que salga justo detrás de la foto grande de la
-- portada (a la que se le baja el orden a 0); las demás de Portada
-- siguen en 2, 3, 4… y no se tocan.
insert into public.imagenes_web (clave, pagina, titulo, respaldo, orden) values
  ('home.hero.movil', 'Portada',
   'Foto grande de la portada · versión para el móvil (opcional)',
   'assets/img/hero.jpg', 1)
on conflict (clave) do update set
  pagina   = excluded.pagina,
  titulo   = excluded.titulo,
  respaldo = excluded.respaldo,
  orden    = excluded.orden;

update public.imagenes_web set orden = 0 where clave = 'home.hero';

-- ------------------------------------------------------------
-- 2 · PERMISOS DE VERDAD (no solo políticas)
-- ------------------------------------------------------------
-- Se quita todo y se devuelve lo justo:
--   · anon (el visitante sin cuenta): SELECT y nada más. La web pública
--     necesita leer esta tabla para pintar sus fotos.
--   · authenticated: SELECT + INSERT/UPDATE/DELETE, que es lo que usa el
--     panel; quién puede de verdad lo sigue decidiendo la RLS con
--     es_admin(). Sin TRUNCATE, que la RLS no controla.
revoke all on public.imagenes_web from public, anon, authenticated;
grant select on public.imagenes_web to anon, authenticated;
grant insert, update, delete on public.imagenes_web to authenticated;

commit;

-- --- Comprobación --------------------------------------------------
-- 1) El hueco está y nace vacío (url null = se sigue usando la de escritorio).
select clave, pagina, titulo, orden,
       case when url is null or url = '' then 'vacío · usa la de escritorio' else 'con foto propia' end as estado
  from public.imagenes_web
 where clave in ('home.hero', 'home.hero.movil')
 order by orden;

-- 2) Los permisos REALES, no las políticas.
--    Esperado:  anon → SELECT   ·   authenticated → DELETE, INSERT, SELECT, UPDATE
select grantee, string_agg(privilege_type, ', ' order by privilege_type) as permisos
  from information_schema.role_table_grants
 where table_schema = 'public' and table_name = 'imagenes_web'
   and grantee in ('anon', 'authenticated', 'public')
 group by grantee
 order by grantee;
