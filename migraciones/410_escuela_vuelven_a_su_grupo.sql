-- 410 · Andrés (20-oct-2026): vuelven a su grupo los niños INSCRITOS que la 401/406
-- sacaron por no salir en el listado de los entrenadores (error: sí están en BUENO ISA),
-- y los de 2º turno a su grupo. Álvaro Vila entrena aparte (de la escuela, sin grupo).
begin;
create temp table _m410 (nombre_norm text primary key, grupo uuid not null) on commit drop;
insert into _m410 values
  ('lola de la casa gomez',          'd93016a6-ba64-45b4-ac83-2756d5337729'),  -- Verde 3 M/J
  ('bruno estevez carbonell',        '85b804bd-b180-4881-b95b-857821e4f137'),  -- Rojo 1a M/J
  ('eric gonzalez orea',             'e09b4694-8de8-4387-89f4-3313c37e81d4'),  -- Rojo 2 L/X
  ('agnes brantuas batalla',         'e09b4694-8de8-4387-89f4-3313c37e81d4'),  -- Rojo 2 L/X
  ('adriana mayor infante',          '7b9fe4a3-3328-492b-b88e-0aa549cd76d0'),  -- Rojo 1b L/X
  ('cristina moratalla papi',        '26bb007d-0d6e-4b15-b9a8-e2baf83573d1'),  -- Rojo 1a L/X
  ('sofia alejandra valencia moreno','af8c1675-905f-4548-979b-3409fc2b25a4'),  -- Verde 1 L/X
  ('noah padilla mokwaka',           '701f1399-50ae-402f-adea-ed6a65dc0d35'),  -- Recreativo L/X/V
  ('sara quintana villalain',        '9d3cf257-4d63-44fd-9647-edb23fb93d53'),  -- Sub 14 M/J/V
  ('vidal garcia duran',             'ac820efa-d9ca-441e-bfef-56a0065d7bcd');  -- Sub 14 L/X/V
insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select a.id, m.grupo, not exists (select 1 from public.atleta_grupos x where x.atleta_id = a.id and x.principal)
  from _m410 m
  join public.atletas a on public._nombre_norm(a.nombre||' '||coalesce(a.apellidos,'')) = m.nombre_norm
 where coalesce(a.estado,'activo') <> 'baja'
   and not exists (select 1 from public.atleta_grupos x where x.atleta_id = a.id and x.grupo_id = m.grupo);
update public.atletas set observaciones = concat_ws(E'\n', nullif(btrim(observaciones),''), 'Entrena aparte: de la escuela pero sin grupo (Andrés, 20-oct-2026)')
 where public._nombre_norm(nombre||' '||coalesce(apellidos,'')) = 'alvaro vila gonzalez'
   and coalesce(observaciones,'') not ilike '%Entrena aparte%';
do $$ declare v int; begin
  select count(*) into v from _m410 m where not exists (
    select 1 from public.atletas a join public.atleta_grupos ag on ag.atleta_id = a.id and ag.grupo_id = m.grupo
     where public._nombre_norm(a.nombre||' '||coalesce(a.apellidos,'')) = m.nombre_norm);
  if v > 0 then raise exception '410: % sin su grupo', v; end if;
end $$;
commit;
