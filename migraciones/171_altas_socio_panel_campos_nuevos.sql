-- ============================================================
-- 171 · La vista del panel enseña los campos nuevos del alta de socio
-- ------------------------------------------------------------
-- `altas_socio_panel` seleccionaba columnas a mano y no incluía lo
-- añadido en 169/170 (nacionalidad, nacimiento, peso, estatura,
-- tallas y las rutas de los documentos). Se recrea con todo.
--
-- La vista solo la lee administración (RLS de altas_socio manda,
-- security invoker). Las rutas de las fotos NO son la foto: para
-- verla, el panel firma un enlace temporal contra el bucket privado.
-- ============================================================

create or replace view public.altas_socio_panel as
  select
    id, referencia, temporada, nombre, apellidos,
    tapado(dni) as dni_tapado,
    dni is not null as tiene_dni,
    fecha_nacimiento, sexo,
    direccion, cp, localidad, provincia, email, telefono, secciones,
    acepta_normas, texto_normas,
    permiso_imagen, permiso_imagen_ambitos, texto_imagen, texto_condiciones,
    estado, revisada_por,
    (select btrim((coalesce(p.nombre,'') || ' ') || coalesce(p.apellidos,''))
       from perfiles p where p.id = s.revisada_por) as revisada_por_nombre,
    revisada_en, nota_club, perfil_id, atleta_id, created_at,
    -- Campos añadidos (169)
    nacionalidad, ciudad_nacimiento, provincia_nacimiento, pais_nacimiento,
    peso, estatura, talla_camiseta, talla_pantalon, talla_calcetin,
    -- Rutas de los documentos (170) — solo la ruta, la foto se firma aparte
    foto_carnet, dni_anverso, dni_reverso
  from altas_socio s;
