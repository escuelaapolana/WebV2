-- 403 · Inés García Martínez: la 398 la dio de baja por estar en ROJO en la hoja de
-- la escuela, pero está en VERDE en la de municipales (se pasó a municipal) y en el
-- listado de Verde 1 de martes/jueves. Vuelve: activa, municipal y en Verde 1 M/J.
begin;
update public.atletas
   set estado = 'activo', fecha_baja = null, tipo_membresia = 'municipal',
       observaciones = concat_ws(E'\n', nullif(btrim(observaciones),''), 'Vuelve 20-oct-2026: verde en municipales (la baja era de la hoja de la escuela)')
 where nombre = 'Inés' and apellidos = 'García Martínez' and estado = 'baja';
insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select a.id, 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', true
  from public.atletas a
 where a.nombre = 'Inés' and a.apellidos = 'García Martínez'
   and not exists (select 1 from public.atleta_grupos x where x.atleta_id = a.id and x.grupo_id = 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658');
commit;
