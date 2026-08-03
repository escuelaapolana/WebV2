-- ============================================================
-- 092 · Montaña y Triatlón, también con su interruptor
-- ------------------------------------------------------------
-- QUÉ RESUELVE:
--   La migración 085 metió en la base a las personas de contacto de
--   seis secciones (natación, pista, running, club, administración y
--   escuela), cada una con sus dos interruptores de privacidad. Pero
--   Montaña y Triatlón se quedaron fuera.
--
--   Sus dos páginas —/montana/ y /triatlon/— ya vienen preparadas
--   para preguntar a la base (llevan sus `data-contacto` y cargan
--   `contactos-web.js`), pero como no había fila que contestara, se
--   quedaban siempre con el correo escrito a mano en el HTML. O sea:
--   dos correos personales publicados en una web que Google indexa,
--   y sin ningún interruptor que los apague. Quitarlos era editar
--   código; en las otras seis secciones es un clic en el panel.
--
-- CÓMO QUEDA:
--   Dos filas más, con las mismas reglas que las demás. A partir de
--   hoy, «Club → Personas de contacto» las apaga y las enciende.
--
-- ⚠️ AQUÍ NO HAY NI UN CORREO, Y ES LA REGLA DE LA CASA
--   Este repositorio es PÚBLICO. Un correo escrito en un archivo .sql
--   está tan a la vista como uno escrito en una página, y encima queda
--   en el histórico de Git para siempre. El interruptor protege la
--   WEB, no este archivo.
--   Así que esta migración trae el molde, el nombre y la sección; los
--   correos se cargan aparte, directamente en la base, por el mismo
--   camino que los de la 085 (ver su apartado 7 y el de abajo).
--
--   Lo que sí puede estar escrito: el nombre, el cargo y la sección.
--   Eso ya sale hoy en /montana/ y /triatlon/ y no es un dato de
--   contacto.
--
-- POR DEFECTO, EXACTAMENTE COMO ESTÁ HOY
--   publicar_email = true: los dos correos YA están publicados en la
--   web, así que dejarlos apagados no sería «no cambiar nada», sería
--   retirar de la web dos datos que el club publica a propósito, y esa
--   decisión no la toma una migración.
--   publicar_telefono = false: hoy no hay ningún teléfono suyo en la
--   web, y no se va a sacar uno nuevo por la puerta de atrás. Además
--   nacen SIN teléfono guardado: no hay número que enseñar.
--
-- Idempotente: `do nothing`, así que relanzarla no pisa lo que el club
--   haya editado desde el panel.
-- Cómo se lanza:
--   bash .secrets/psql.sh -f migraciones/092_contactos_montana_triatlon.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LAS DOS PERSONAS · sin sus correos
-- ------------------------------------------------------------
-- El `cargo` es el rótulo que hoy sale sobre su nombre en la página
-- («Dirección de la sección»). No es invento: está copiado del HTML,
-- que es lo único que hay escrito sobre estas dos personas. Ni
-- cargo_detalle, ni descripción, ni cifras: la web no las enseña, y
-- rellenarlas sería publicar cosas que nadie ha dicho.
insert into public.contactos
  (clave, nombre, cargo,
   telefono, publicar_telefono, publicar_email,
   seccion, es_responsable, orden, activo)
values
  ('enrique', 'Enrique Gallego', 'Dirección de la sección',
   null, false, true,        -- el correo se mete a mano en la base
   'montana', true, 7, true),

  ('jose', 'José Fernández', 'Dirección de la sección',
   null, false, true,        -- el correo se mete a mano en la base
   'triatlon', true, 8, true)
on conflict (clave) do nothing;

-- Por si las filas ya existieran de una pasada anterior sin la marca:
-- que quede claro que estos dos son QUIEN RESPONDE de su sección, que
-- es lo que hace que la página los encuentre preguntando por 'montana'
-- o por 'triatlon' sin saberse el nombre.
update public.contactos
   set es_responsable = true
 where clave in ('enrique', 'jose')
   and seccion is not null
   and not es_responsable;

commit;

-- ============================================================
-- 2 · CÓMO SE CARGAN LOS CORREOS
-- ------------------------------------------------------------
-- No están en este archivo a propósito (ver la cabecera). Se cargan
-- de una de estas dos maneras, igual que los de la 085:
--
--   a) desde el panel: Club → «Personas de contacto» → Editar; o
--   b) por psql, en local, escribiendo el valor real en el momento:
--
--      update public.contactos set email = '…' where clave = 'enrique';
--      update public.contactos set email = '…' where clave = 'jose';
--
-- Mientras estén vacíos no pasa nada malo: /montana/ y /triatlon/
-- siguen enseñando el correo que llevan escrito de respaldo en su
-- HTML, así que ningún visitante ve un hueco en blanco.
-- ============================================================

-- --- Comprobación 1: las dos filas están y responden de su sección ---
select clave, nombre, cargo, seccion, es_responsable, orden, activo,
       publicar_telefono, publicar_email,
       (email is not null and btrim(email) <> '') as tiene_correo_cargado
  from public.contactos
 where seccion in ('montana', 'triatlon')
 order by orden;

-- --- Comprobación 2: lo que ve de verdad un visitante ---------------
-- Debe salir el correo (publicar_email está puesto) y el teléfono
-- vacío. Si el correo sale vacío es que falta cargarlo (apartado 2).
select clave, nombre_corto, cargo, seccion, es_responsable, telefono, email
  from public.contactos_publicos
 where seccion in ('montana', 'triatlon')
 order by orden;
