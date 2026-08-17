-- ============================================================
-- 147 · LOS TEXTOS SUELTOS DE LA WEB
-- ------------------------------------------------------------
-- QUÉ PROBLEMA RESUELVE
--
-- Andrés lo pidió sin rodeos: «quiero editar tooodo en fantasma,
-- cualquier tarjeta y cualquier cosa». Y él mismo dio con el motivo por
-- el que no se podía: «si está en HTML habrá que pasarlo a la base, ¿no?».
-- Exacto. El editor que escribe encima de la página solo puede cambiar
-- lo que vive en una tabla; lo que está escrito dentro del HTML no lo
-- puede tocar nadie desde el navegador, por mucha vista fantasma que se
-- le ponga delante.
--
-- Las páginas de sección ya salían de `contenido_secciones`, pero esa
-- tabla tiene columnas fijas —título, entradilla, servicios, precio…—
-- pensadas para UNA página de sección. Las tarjetas de /club/, de
-- /familias/ o de /instalaciones/ no encajan ahí: son huecos sueltos,
-- distintos en cada página, y no tiene sentido inventarse una columna
-- por cada uno.
--
-- LA FORMA QUE SÍ ENCAJA, Y NO ES NUEVA
--
-- La misma que ya usan las fotos. `imagenes_web` no tiene una columna
-- por foto: tiene una fila por hueco, con su clave. Esto es lo mismo
-- para el texto. En el HTML, cada trozo editable se marca:
--
--     <p data-texto="club.junta.pie">Lo que diga hoy</p>
--
-- y aquí hay una fila con esa clave. Lo escrito en el HTML se queda
-- como respaldo: si la base no contesta, la página se lee igual. Eso no
-- es un detalle — es lo que permite que esta web siga siendo estática y
-- que una caída de Supabase no la deje en blanco.
--
-- POR QUÉ LA CLAVE LA PONE QUIEN ESCRIBE EL HTML Y NO LA BASE
--
-- Porque el hueco existe antes que el texto. Si la fila no está, la
-- página enseña su respaldo y no pasa nada; el día que alguien escriba
-- ahí desde el editor, se crea. Al revés —crear filas y esperar a que
-- alguien las use— se llena la tabla de claves que ya no apunta a ningún
-- sitio y nadie se atreve a borrarlas.
--
-- LO QUE ESTO NO ES
--
-- No es un gestor de contenidos. No crea páginas, no mueve bloques y no
-- cambia el diseño. Cambia LO QUE DICE un hueco que ya existe. Quien
-- quiera un bloque nuevo sigue necesitando tocar el HTML.
-- ============================================================

create table if not exists textos_web (
  clave      text primary key,
  texto      text not null default '',
  -- Para qué es este hueco, en cristiano. Sale en el editor como nombre
  -- del campo, así que sin esto el panel enseñaría «club.junta.pie».
  nombre     text,
  -- La página donde vive, para poder agruparlos en el panel. Se saca de
  -- la clave, pero guardado explícito se puede filtrar sin trocear texto.
  pagina     text,
  updated_at timestamptz not null default now()
);

comment on table textos_web is
  'Textos sueltos de las páginas que no son de sección. Una fila por hueco, marcado en el HTML con data-texto="clave". Lo escrito en el HTML es el respaldo.';

create index if not exists ix_textos_web_pagina on textos_web (pagina);

-- ------------------------------------------------------------
-- QUIÉN PUEDE QUÉ
-- Lo mismo que las fotos: lo lee cualquiera —es el contenido de una web
-- pública— y solo administración lo cambia. La escuela NO entra aquí:
-- puede con lo suyo (ver la migración 144), pero el texto de la web del
-- club no es lo suyo.
-- ------------------------------------------------------------
-- ⚠️ LOS PERMISOS DE TABLA VAN ANTES QUE LAS POLÍTICAS, Y NO SON LO MISMO.
-- Esto no salió de leer el código: salió de probarlo. La primera versión de
-- esta migración tenía las políticas bien y la tabla no se podía ni leer:
--     ERROR: permission denied for table textos_web
-- Las políticas RLS deciden QUÉ FILAS ve cada uno, pero solo entre las que
-- su rol tiene permiso de tocar. Sin este GRANT no llega a haber filas que
-- filtrar: la web pública habría enseñado siempre el respaldo del HTML y
-- nadie habría entendido por qué no se guardaba nada.
-- Los mismos permisos que `imagenes_web`, que es la tabla hermana.
grant select on textos_web to anon;
grant select, insert, update, delete on textos_web to authenticated;

alter table textos_web enable row level security;

drop policy if exists "lectura publica textos_web" on textos_web;
create policy "lectura publica textos_web"
  on textos_web for select
  using (true);

drop policy if exists "admin gestiona textos_web" on textos_web;
create policy "admin gestiona textos_web"
  on textos_web for all
  using (es_admin())
  with check (es_admin());

-- `updated_at` a mano no se mantiene solo: el editor guarda muchas filas
-- de golpe y se olvidaría en alguna.
create or replace function textos_web_marca_hora()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists tg_textos_web_marca_hora on textos_web;
create trigger tg_textos_web_marca_hora
  before update on textos_web
  for each row execute function textos_web_marca_hora();
