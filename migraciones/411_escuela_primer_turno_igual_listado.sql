-- 411 · Andrés (20-oct-2026): «los grupos que te he enviado (L/X y M/J) son los fijos:
-- esos son los niños que tiene que haber en los grupos, de primera hora al menos».
-- Se deshace la parte de 1er turno de la 410: fuera de los grupos de las 17:30 los 7
-- inscritos que NO salen en los listados (fichas intactas; quedan «sin grupo» para que
-- el club lo hable con los entrenadores). Los de 2º turno de la 410 se quedan.
begin;
delete from public.atleta_grupos ag
 using public.atletas a, public.grupos g
 where ag.atleta_id = a.id and g.id = ag.grupo_id
   and g.seccion = 'escuela'
   and (g.horario ilike 'Lunes y miércoles 17:30%' or g.horario ilike 'Martes y jueves 17:30%')
   and public._nombre_norm(a.nombre||' '||coalesce(a.apellidos,'')) in (
     'lola de la casa gomez','bruno estevez carbonell','eric gonzalez orea','agnes brantuas batalla',
     'adriana mayor infante','cristina moratalla papi','sofia alejandra valencia moreno');
commit;
