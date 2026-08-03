-- ============================================================
-- 084 · HUECOS DE FOTO · que la galería se pueda tocar desde el panel
-- ------------------------------------------------------------
-- QUÉ RESUELVE, EN CRISTIANO
--
--   1) LA GALERÍA NO SE PODÍA CAMBIAR. La página /galeria/ dejó de ser
--      una rejilla plana y pasó a estar agrupada en cuatro bloques
--      (pista, running, agua y escuelas). Sus huecos pasaron a llamarse
--      «galeria.pista.1», «galeria.agua.3»… pero en esta tabla seguían
--      las filas viejas («galeria.1» … «galeria.16»). No coincidía ni
--      una, así que en Panel → Fotos de la web salían dieciséis huecos
--      que no cambiaban nada, y las fotos que de verdad se ven no salían.
--
--      Aquí se crean los DIECIOCHO huecos que la página pide de verdad
--      (las cuatro de la rejilla de cada bloque, más la quinta de «pista»
--      y «escuelas», que se cuenta en el «+1» y solo sale a pantalla
--      completa), con el nombre del bloque en el título, y se retiran los
--      viejos. Ninguno de los viejos tenía foto elegida (todos con `url`
--      a nulo), así que no se pierde nada del club; aun así, por si
--      acaso, solo se borran los que sigan sin foto.
--
--   2) HUECOS QUE YA NO EXISTEN EN LA WEB. La portada nueva se quedó sin
--      el mosaico, sin la tira de Instagram y sin la tarjeta «Para mí»,
--      pero sus doce huecos seguían en el panel: el club cambiaba una
--      foto y en la web no pasaba nada. Se les da un interruptor
--      (`activo`) y se apagan. NO se borran: seis de ellos guardan una
--      foto elegida a mano, y si algún día vuelve el mosaico se encienden
--      otra vez y siguen ahí, con su encuadre. Es el mismo interruptor
--      que hará falta cada vez que un bloque de la web se retire.
--
--   3) DOS TÍTULOS QUE ENGAÑABAN en el panel:
--      · «competicion.foto» decía «Foto del bloque de competición»
--        cuando en la página es el RETRATO del responsable de la
--        sección, en su ficha. Con ese nombre es fácil ponerle una foto
--        de acción sin querer.
--      · «home.publico.escuela» decía «Tarjeta "Para mi hijo o hija"»,
--        pero en la portada de hoy es la banda ancha de «Escuelas».
--      Se cambia SOLO el texto del título: ni una foto se toca.
--
-- LO QUE NO HACE
--   · No cambia ninguna foto ni ningún encuadre elegido por el club.
--   · No toca la cabecera de /competicion/ ni la de /escuela/: esas dos
--     fotos viven en `contenido_secciones` (el hueco «Foto de cabecera
--     (la grande de arriba)» del panel), igual que en las otras doce
--     secciones. No se duplican aquí.
--
-- ⚠️ Supabase reparte permisos de serie en todo lo nuevo. Esta migración
--   no crea tablas, pero al final se comprueba —contra
--   `information_schema`— que `anon` sigue teniendo SOLO SELECT sobre
--   `imagenes_web`, y si no, se corrige y se avisa. Van seis incidentes
--   en este proyecto por esto.
--
-- Idempotente: se puede relanzar sin perder nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/084_huecos_de_foto.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LOS DIECIOCHO HUECOS DE LA GALERÍA
--     Cuatro bloques. En cada uno, cuatro fotos a la vista en la rejilla;
--     «pista» y «escuelas» tienen además una quinta que se cuenta en el
--     «+1» y solo sale a pantalla completa — se cambia igual que las
--     demás, que si no, unas se pueden y otras no sin motivo.
--     El `respaldo` es la foto que la página trae de serie en cada sitio:
--     es la que sale en la miniatura del panel mientras el club no elija
--     otra. Si el hueco ya existe se le refresca el rótulo y el respaldo,
--     pero NUNCA la foto elegida (`url`), ni su encuadre ni su zoom.
-- ------------------------------------------------------------
insert into imagenes_web (clave, pagina, titulo, respaldo, orden) values
  ('galeria.pista.1',    'Galería', 'Galería · pista y competición, foto 1 (la grande)', 'assets/img/galeria-3.jpg',                 1),
  ('galeria.pista.2',    'Galería', 'Galería · pista y competición, foto 2',             'assets/img/competicion-andres.jpg',        2),
  ('galeria.pista.3',    'Galería', 'Galería · pista y competición, foto 3',             'assets/img/galeria-1.jpg',                 3),
  ('galeria.pista.4',    'Galería', 'Galería · pista y competición, foto 4',             'assets/img/running-nicolas.jpg',           4),
  ('galeria.pista.5',    'Galería', 'Galería · pista y competición, foto 5 (solo a pantalla completa)', 'assets/img/ig-3.jpg',      5),
  ('galeria.running.1',  'Galería', 'Galería · running y montaña, foto 1 (la grande)',   'assets/img/running-claudia.jpg',           6),
  ('galeria.running.2',  'Galería', 'Galería · running y montaña, foto 2',               'assets/img/galeria-4.jpg',                 7),
  ('galeria.running.3',  'Galería', 'Galería · running y montaña, foto 3',               'assets/img/instalaciones-monte-tossal.jpg',8),
  ('galeria.running.4',  'Galería', 'Galería · running y montaña, foto 4',               'assets/img/ig-1.jpg',                      9),
  ('galeria.agua.1',     'Galería', 'Galería · agua y triatlón, foto 1 (la grande)',     'assets/img/natacion-hero.jpg',            10),
  ('galeria.agua.2',     'Galería', 'Galería · agua y triatlón, foto 2',                 'assets/img/triatlon-hero.jpg',            11),
  ('galeria.agua.3',     'Galería', 'Galería · agua y triatlón, foto 3',                 'assets/img/escuela-natacion-hero.jpg',    12),
  ('galeria.agua.4',     'Galería', 'Galería · agua y triatlón, foto 4',                 'assets/img/ig-4.jpg',                     13),
  ('galeria.escuelas.1', 'Galería', 'Galería · escuelas y campus, foto 1 (la grande)',   'assets/img/escuela-galeria-1.jpg',        14),
  ('galeria.escuelas.2', 'Galería', 'Galería · escuelas y campus, foto 2',               'assets/img/escuela-galeria-2.jpg',        15),
  ('galeria.escuelas.3', 'Galería', 'Galería · escuelas y campus, foto 3',               'assets/img/campus-itaka.jpg',             16),
  ('galeria.escuelas.4', 'Galería', 'Galería · escuelas y campus, foto 4',               'assets/img/ig-2.jpg',                     17),
  ('galeria.escuelas.5', 'Galería', 'Galería · escuelas y campus, foto 5 (solo a pantalla completa)',   'assets/img/cubo-hero.jpg', 18)
on conflict (clave) do update
  set pagina   = excluded.pagina,
      titulo   = excluded.titulo,
      respaldo = excluded.respaldo,
      orden    = excluded.orden;

-- ------------------------------------------------------------
-- 2 · FUERA LOS HUECOS VIEJOS DE LA GALERÍA
--     «galeria.1» … «galeria.16» ya no los usa ninguna página. Se van
--     solo si nadie les puso foto desde el panel: si alguno la tuviera,
--     se queda y lo dice el aviso de más abajo, para mirarlo a mano.
-- ------------------------------------------------------------
do $$
declare quedan int;
begin
  delete from imagenes_web
   where clave ~ '^galeria\.[0-9]+$'
     and (url is null or btrim(url) = '');

  select count(*) into quedan from imagenes_web where clave ~ '^galeria\.[0-9]+$';
  if quedan > 0 then
    raise warning 'Quedan % huecos viejos de galería CON foto elegida. Míralos a mano antes de borrarlos.', quedan;
  end if;
end $$;

-- ------------------------------------------------------------
-- 3 · UN INTERRUPTOR PARA LOS HUECOS QUE YA NO ESTÁN EN LA WEB
--     `activo` a falso = el hueco no sale en el panel. Ni se borra la
--     fila, ni se toca la foto que hubiera elegida: se guarda entera y
--     vuelve el día que se encienda otra vez.
--     Nace en `true`, así que ningún hueco de los de hoy se entera.
-- ------------------------------------------------------------
alter table imagenes_web
  add column if not exists activo boolean not null default true;

comment on column imagenes_web.activo is
  'Falso = el hueco ya no existe en la web y no sale en el panel. La fila '
  'y la foto elegida se conservan: para recuperarlo, poner a verdadero.';

-- Los doce de la portada vieja: el mosaico «Así vivimos el deporte», la
-- tira de Instagram y la tarjeta «Para mí». La portada de hoy no los
-- pinta, así que en el panel solo confundían. Cinco del mosaico y la
-- tarjeta «Para mí» tienen foto elegida a mano: se queda donde está.
update imagenes_web
   set activo = false
 where clave in (
         'home.mosaico.1', 'home.mosaico.2', 'home.mosaico.3',
         'home.mosaico.4', 'home.mosaico.5',
         'home.instagram.1', 'home.instagram.2', 'home.instagram.3',
         'home.instagram.4', 'home.instagram.5', 'home.instagram.6',
         'home.publico.adultos')
   and activo;

-- ------------------------------------------------------------
-- 4 · DOS TÍTULOS QUE ENGAÑABAN (solo el texto)
-- ------------------------------------------------------------
update imagenes_web
   set titulo = 'Retrato del responsable de la sección'
 where clave = 'competicion.foto'
   and titulo is distinct from 'Retrato del responsable de la sección';

update imagenes_web
   set titulo = 'Banda de «Escuelas»'
 where clave = 'home.publico.escuela'
   and titulo is distinct from 'Banda de «Escuelas»';

-- ------------------------------------------------------------
-- 5 · PERMISOS · que `anon` solo pueda LEER esta tabla
--     No se crea ninguna tabla aquí, pero se comprueba de verdad contra
--     information_schema y se corrige si hiciera falta.
-- ------------------------------------------------------------
revoke insert, update, delete, truncate, references, trigger
  on public.imagenes_web from anon;
grant select on public.imagenes_web to anon;

do $$
declare sobra text;
begin
  select string_agg(privilege_type, ', ' order by privilege_type) into sobra
    from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'imagenes_web'
     and grantee = 'anon' and privilege_type <> 'SELECT';
  if sobra is not null then
    raise exception 'anon conserva permisos de más sobre imagenes_web: %', sobra;
  end if;
end $$;

commit;

-- ------------------------------------------------------------
-- COMPROBACIÓN A MANO (después de lanzarla)
--   select clave, titulo, orden from imagenes_web
--    where pagina = 'Galería' order by orden;
--   select clave, titulo from imagenes_web where not activo order by clave;
--
-- PARA VOLVER A ENCENDER UN HUECO (si su bloque vuelve a la web):
--   update imagenes_web set activo = true where clave = 'home.mosaico.1';
--   select grantee, privilege_type from information_schema.role_table_grants
--    where table_schema='public' and table_name='imagenes_web' order by 1,2;
-- ------------------------------------------------------------
