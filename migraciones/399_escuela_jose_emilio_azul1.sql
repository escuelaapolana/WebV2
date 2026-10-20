-- 399 · José Emilio Pineda Carchipulla: salía en dos grupos del listado de martes/jueves
-- (Rojo 3 y Azul 1). Andrés (20-oct-2026): «Azul 1». Idempotente.
begin;
delete from public.atleta_grupos ag
 using public.atletas a
 where ag.atleta_id = a.id and a.nombre = 'José Emilio' and a.apellidos ilike 'Pineda Carchipulla%'
   and ag.grupo_id = '629bd004-c3f1-4139-a051-17dcd15f9de1';          -- Rojo 3 M/J
insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select a.id, '74567283-d08e-4c41-8427-f64633ea9745', true                -- Azul 1 M/J
  from public.atletas a
 where a.nombre = 'José Emilio' and a.apellidos ilike 'Pineda Carchipulla%'
   and not exists (select 1 from public.atleta_grupos x where x.atleta_id = a.id and x.grupo_id = '74567283-d08e-4c41-8427-f64633ea9745');
commit;
