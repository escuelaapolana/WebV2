-- 512 · Natación · Competiciones: falta la categoría Prebenjamín (2018).
-- La pidió Paloma Solera al añadir competiciones de los niños (4-nov-2026).
-- Las jornadas de la liga ya la nombran («2ª Jornada Liga Benjamín · 1ª Prebenjamín»).
insert into public.natacion_comp_categorias (clave, temporada, nombre, desde_anio, hasta_anio, orden)
values ('prebenjamin', '2026/27', 'Prebenjamín', 2018, 2018, 0)
on conflict do nothing;
