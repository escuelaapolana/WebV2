-- ============================================================
-- 140 · La biblioteca de fotos es privada, y publicar es un acto aparte
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Hasta hoy, meter una foto en la biblioteca del panel era publicarla.
-- La biblioteca guardaba todo en el almacén `imagenes`, que es público:
-- cualquiera con la dirección del archivo lo veía, estuviera esa foto
-- puesta en una página o no. En esas fotos hay menores, y el club acaba
-- de montar el mecanismo para que una familia pueda decir que no quiere
-- que se publiquen las fotos de su hijo. Una biblioteca de trabajo que
-- publica todo lo que toca contradice eso de frente.
--
-- ------------------------------------------------------------
-- EL AGUJERO QUE NOS HEMOS ENCONTRADO POR EL CAMINO (esto es lo urgente)
-- El almacén `imagenes-club` está marcado como privado, y por eso se
-- eligió para guardar ahí las fotos de trabajo. Pero NO lo estaba:
-- la política «Lectura publica imagenes» le daba lectura a `public`, o
-- sea a cualquiera, tenga cuenta o no. Con la clave pública que viaja en
-- la web —la que va en cualquier navegador— se podía listar el almacén
-- entero y pedir un enlace para descargar cualquier archivo. Comprobado
-- de verdad, sin cuenta: listar contestaba y firmar contestaba.
--
-- «Privado» en Supabase solo quiere decir que no hay una dirección fija
-- que funcione sola; quién puede pedir un enlace temporal lo decide esta
-- política, y esta política decía «todo el mundo». Así que las 155 fotos
-- que se acaban de subir ahí estaban, en la práctica, tan expuestas como
-- si estuvieran en el almacén público.
--
-- Se cierra: `imagenes-club` sale de la lectura pública. A partir de
-- aquí solo entra quien es administrador, por la política «Admin
-- gestiona imagenes web», que ya existe y no se toca. Un entrenador
-- tampoco entra: no es administrador.
--
-- ¿Rompe algo? No. Se ha buscado `imagenes-club` en toda la web y en
-- todo el panel y no lo usa nadie: ni una página, ni un script. Es un
-- almacén heredado. `productos-tienda` sí se queda con lectura pública,
-- porque las fotos de la tienda se ven sin cuenta a propósito.
--
-- ------------------------------------------------------------
-- LO QUE SE MONTA: GUARDAR NO ES PUBLICAR
-- A partir de ahora hay dos sitios distintos y un paso entre ellos:
--
--   1. GUARDAR · la foto vive en `imagenes-club/biblioteca/`, que es
--      privado de verdad. Está en la biblioteca, se ve en el panel, se
--      puede buscar y ordenar. No es accesible desde fuera.
--
--   2. PUBLICAR · elegir esa foto para un hueco de la web (la portada,
--      una cabecera, una de las de galería) copia el archivo al almacén
--      público `imagenes`, en la carpeta `publicadas/`. Esa copia es la
--      que ve el visitante, y es la única que existe fuera.
--
--   3. DESPUBLICAR · si esa foto se quita del hueco y no está en ningún
--      otro, la copia pública se borra. El original sigue en la
--      biblioteca. Se despublica, no se pierde.
--
-- Por qué una copia y no mover el archivo: porque la misma foto puede
-- estar en dos huecos a la vez. Si se moviera, quitarla de uno dejaría
-- al otro con un hueco. Con copia, el original nunca se toca y la copia
-- solo desaparece cuando ya no la usa nadie.
--
-- ------------------------------------------------------------
-- LAS COLUMNAS NUEVAS DE `biblioteca_fotos`
--
--   `cubo`  · en qué almacén vive el archivo. Hace falta porque conviven
--             tres orígenes con rutas que se parecen demasiado:
--               'imagenes-club' → la biblioteca privada de ahora
--               'imagenes'      → las 28 que ya estaban en el almacén
--                                 público, y que NO se mueven (hay 12
--                                 puestas en páginas ahora mismo; moverlas
--                                 dejaría esas páginas con un hueco)
--               'sitio'         → las 89 fichas que no apuntan a ningún
--                                 almacén, sino a un archivo del propio
--                                 sitio (`assets/img/...`)
--             Sin esta columna, `biblioteca/algo.jpg` sería ambiguo: la
--             misma ruta existe en los dos almacenes.
--
--   `publicada_ruta` · dónde está la copia pública mientras la foto esté
--             publicada. Vacío = no publicada, no existe fuera.
--
--   `publicada_en`   · cuándo se publicó. Sirve para responder «¿desde
--             cuándo se ve esta foto?», que es la pregunta que hará una
--             familia si algún día reclama.
--
--   `grupo` y `fecha_foto` · el acontecimiento y el día, sacados del
--             nombre del archivo. Con 155 fotos, una rejilla plana no se
--             puede usar en un móvil; agrupadas por «Gala 2019», «Cross
--             de Castellón»… sí. Se rellenan en la 141.
--
-- ------------------------------------------------------------
-- LA FUNCIÓN `biblioteca_usos`
-- Contesta a «¿en cuántos sitios de la web está puesta esta foto?».
-- La respuesta no se lleva en una tabla aparte a propósito: una tabla de
-- apuntes se desincroniza el primer día que alguien cambie una foto por
-- otro camino, y entonces borraríamos una copia pública que sí se estaba
-- usando. Aquí se mira la verdad directamente donde vive: en las tablas
-- que guardan la dirección de la foto de cada hueco.
--
-- Idempotente.
-- ============================================================


-- ------------------------------------------------------------
-- 1 · CERRAR EL ALMACÉN PRIVADO
-- ------------------------------------------------------------
drop policy if exists "Lectura publica imagenes" on storage.objects;
create policy "Lectura publica imagenes"
  on storage.objects for select to public
  using (bucket_id in ('productos-tienda', 'Productos-tienda'));
-- OJO, dos que NO van en esta lista, nunca:
--   · `fotos-atletas`  → son menores (lo dejó dicho la 076).
--   · `imagenes-club`  → es la biblioteca de trabajo, y ahí también hay
--                        menores. Si vuelve a aparecer aquí, la
--                        biblioteca deja de ser privada sin que se note.


-- ------------------------------------------------------------
-- 2 · COLUMNAS NUEVAS
-- ------------------------------------------------------------
alter table public.biblioteca_fotos
  add column if not exists cubo           text,
  add column if not exists publicada_ruta text,
  add column if not exists publicada_en   timestamptz,
  add column if not exists grupo          text,
  add column if not exists fecha_foto     date;

comment on column public.biblioteca_fotos.cubo is
  'En qué almacén vive el archivo: imagenes-club (biblioteca privada), imagenes (las viejas del almacén público) o sitio (un archivo de assets/ del propio sitio).';
comment on column public.biblioteca_fotos.publicada_ruta is
  'Ruta de la copia en el almacén público mientras la foto esté puesta en algún sitio de la web. Vacío = no publicada.';
comment on column public.biblioteca_fotos.grupo is
  'Acontecimiento al que pertenece la foto, sacado del nombre del archivo. Sirve para agruparlas en el selector.';


-- ------------------------------------------------------------
-- 3 · DECIRLE A CADA FICHA VIEJA DÓNDE VIVE
-- ------------------------------------------------------------
-- Las que apuntan a un archivo del sitio (assets/img/...) no están en
-- ningún almacén: las sirve la propia web.
update public.biblioteca_fotos
   set cubo = 'sitio'
 where cubo is null
   and (ruta like 'assets/%' or ruta like '/assets/%' or ruta like './assets/%');

-- Las que quedan y empiezan por http… son direcciones completas puestas
-- a mano; tampoco son de ningún almacén nuestro.
update public.biblioteca_fotos
   set cubo = 'sitio'
 where cubo is null
   and (ruta like 'http://%' or ruta like 'https://%' or ruta like '//%');

-- El resto son las que subió la biblioteca vieja, que iban al almacén
-- público. Se quedan donde están: hay páginas enseñándolas ahora mismo.
update public.biblioteca_fotos
   set cubo = 'imagenes'
 where cubo is null;

-- De aquí en adelante, lo que no diga otra cosa es de la biblioteca privada.
alter table public.biblioteca_fotos
  alter column cubo set default 'imagenes-club';

-- Ninguna ficha puede quedarse sin saber dónde vive: si se queda a
-- medias, el panel no sabría si pedir un enlace firmado o no, y la foto
-- saldría rota.
update public.biblioteca_fotos set cubo = 'imagenes-club' where cubo is null;
alter table public.biblioteca_fotos
  alter column cubo set not null;

-- Solo estos tres valores tienen sentido; cualquier otro sería una foto
-- que el panel no sabría cómo enseñar.
alter table public.biblioteca_fotos drop constraint if exists biblioteca_fotos_cubo_ck;
alter table public.biblioteca_fotos
  add constraint biblioteca_fotos_cubo_ck
  check (cubo in ('imagenes-club', 'imagenes', 'sitio'));

-- Las dos preguntas que se hacen a todo trapo: «enséñame las de este
-- acontecimiento» y «enséñame las que están publicadas».
create index if not exists biblioteca_fotos_grupo_idx     on public.biblioteca_fotos (grupo);
create index if not exists biblioteca_fotos_publicada_idx on public.biblioteca_fotos (publicada_ruta)
  where publicada_ruta is not null;


-- ------------------------------------------------------------
-- 4 · LAS 12 QUE YA ESTÁN PUESTAS EN UNA PÁGINA, MARCADAS COMO PUBLICADAS
-- ------------------------------------------------------------
-- Estas ya viven en el almacén público y ya se están viendo. No se toca
-- ni un archivo: solo se apunta la verdad, que es que están publicadas
-- y que su copia pública es su propia ruta de siempre. Si mañana se
-- quitan de la página, el panel sabrá que hay algo que despublicar.
update public.biblioteca_fotos b
   set publicada_ruta = b.ruta,
       publicada_en   = coalesce(b.publicada_en, b.created_at)
 where b.cubo = 'imagenes'
   and b.publicada_ruta is null
   and exists (
     select 1 from public.contenido_secciones c
      where c.imagen_url like '%/' || b.ruta
   );

update public.biblioteca_fotos b
   set publicada_ruta = b.ruta,
       publicada_en   = coalesce(b.publicada_en, b.created_at)
 where b.cubo = 'imagenes'
   and b.publicada_ruta is null
   and exists (
     select 1 from public.imagenes_web w
      where w.url like '%/' || b.ruta
   );


-- ------------------------------------------------------------
-- 5 · ¿EN CUÁNTOS SITIOS DE LA WEB ESTÁ PUESTA ESTA FOTO?
-- ------------------------------------------------------------
-- Se le pasa la ruta de la copia pública (por ejemplo
-- 'publicadas/xxxx.jpg') y devuelve cuántos huecos la están usando.
-- El panel lo llama justo después de guardar un hueco: si sale 0, esa
-- copia ya no la mira nadie y se puede borrar del almacén público.
--
-- Se miran los cuatro sitios donde el panel guarda la dirección de una
-- foto elegida. Si algún día aparece un quinto, hay que añadirlo aquí:
-- olvidarlo no rompe nada visible, pero deja copias públicas de fotos
-- que ya no se usan, que es justo lo que veníamos a evitar.
create or replace function public.biblioteca_usos(p_ruta text)
returns integer
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    (select count(*) from public.imagenes_web         w where w.url         like '%/' || p_ruta)
  + (select count(*) from public.contenido_secciones  c where c.imagen_url  like '%/' || p_ruta)
  + (select count(*) from public.colaboradores        l where l.logo_url    like '%/' || p_ruta)
  + (select count(*) from public.noticias             n where n.foto_portada like '%/' || p_ruta
                                                          or n.fotos_galeria::text like '%/' || p_ruta)
$$;

comment on function public.biblioteca_usos(text) is
  'Cuántos huecos de la web están usando la copia pública de una foto. 0 = se puede retirar del almacén público.';

-- La contesta cualquiera con cuenta, pero quien puede hacer algo con la
-- respuesta (publicar y despublicar) es solo el administrador, y eso ya
-- lo guardan las políticas del almacén.
revoke all on function public.biblioteca_usos(text) from public, anon;
grant execute on function public.biblioteca_usos(text) to authenticated;


-- ------------------------------------------------------------
-- 6 · LA LISTA DE LA BIBLIOTECA TAMBIÉN ES INTERNA
-- ------------------------------------------------------------
-- Faltaba media puerta. Con los archivos ya cerrados, la TABLA de fichas
-- seguía abierta a cualquiera con cuenta: la política decía «con sesión
-- lee», así que un entrenador o un atleta podían leer las 272 fichas
-- enteras. Fotos no, pero sí los nombres de archivo y los títulos.
--
-- Y eso no es poca cosa, porque los nombres cuentan: llevan la fecha, el
-- acontecimiento y —en alguno— el nombre y los apellidos de dos atletas.
-- Es la lista de qué fotos tiene el club, quién sale y de qué día. Si la
-- biblioteca es interna, su índice también lo es.
--
-- ¿Rompe algo? No. Se ha buscado `biblioteca_fotos` en toda la web y solo
-- la leen cuatro pantallas del panel —Biblioteca, Fotos de la web,
-- Páginas y Colaboradores— y todas son de administración. Ninguna página
-- pública ni del portal de socios la toca.
drop policy if exists "con sesion lee biblioteca_fotos" on public.biblioteca_fotos;
-- La política «admin gestiona biblioteca_fotos», que ya existía, es la
-- que deja entrar: cubre leer, crear, cambiar y borrar, y solo a admin.
