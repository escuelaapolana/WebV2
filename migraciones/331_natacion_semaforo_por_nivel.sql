-- 331 · Natación: el semáforo sale de la ocupación única, por CALLE y NIVEL,
--       y respeta el semáforo forzado en todos sitios. (Requiere la 330.)
--
-- Auditoría 13-oct-2026:
--   · El semáforo se calculaba en SQL (natacion_recalcular_semaforo, con el
--     TOTAL de la franja) y otra vez en JS en portal/natacion-gestion (que
--     no respetaba `semaforo_forzado`).
--   · La web (/natacion y /escuela-natacion) decía «Admite plazas» aunque el
--     nivel estuviera lleno, porque solo miraba el total: una calle pasada de
--     cupo «se comía» el sitio que sobraba en otra.
--
-- ┌─ LA REGLA ─────────────────────────────────────────────────────────────┐
-- │ Foto «de siempre» = natacion_ocupacion(NULL, franja): solo fijos.       │
-- │ Por calle: libres = cupo − fijos → ≤0 rojo · 1-2 ámbar · ≥3 verde.      │
-- │ Nivel de una calle (las calles SON niveles): el nivel que más se repite │
-- │   entre sus fijos (empate: los empatados). Calle vacía: la costumbre    │
-- │   del club (C1/Vaso = Iniciación · C2 = Desarrollo · C3 = Perfecciona-  │
-- │   miento). No se calcula nada más.                                      │
-- │ Por nivel admitido (admite_niveles): libres = suma de los libres        │
-- │   POSITIVOS de sus calles → mismo umbral. Nivel sin calle: ámbar        │
-- │   («consultar»): no sabemos dónde iría.                                 │
-- │ Franja (auto): el mejor de sus niveles admitidos; si no tiene niveles,  │
-- │   el de la suma de libres positivos de sus calles. Sin cupos: se        │
-- │   respeta lo que hubiera.                                               │
-- │ FORZADO: si `semaforo_forzado` está puesto, manda en la franja Y en     │
-- │   todos sus niveles.                                                    │
-- └────────────────────────────────────────────────────────────────────────┘
--
-- Se guarda en `natacion_franjas.semaforo` (el efectivo, como siempre) y en
-- la columna nueva `semaforo_detalle` (jsonb: auto, forzado, libres, niveles,
-- calles). Lo recalculan los triggers de siempre (inscripciones y franjas).
-- El gestor (portal/natacion-gestion) LEE `semaforo_detalle` en vez de
-- recalcular. La vista pública `natacion_vacantes` añade, al final:
-- es_escuela, es_master y niveles [{nivel, semaforo}] (sin cifras).
--
-- No toca inscripciones ni cupos. SÍ recalcula `semaforo` de las franjas NO
-- forzadas (es un dato derivado): ver el antes/después en el informe.

alter table public.natacion_franjas
  add column if not exists semaforo_detalle jsonb;

comment on column public.natacion_franjas.semaforo_detalle is
  'Mig 331 · detalle del semáforo calculado (natacion_semaforo_calcular): auto, forzado, semaforo, cupo, fijos, libres, niveles[], calles[]. Lo rellenan los triggers; no editar a mano.';

create or replace function public._natacion_semaforo_de(p_libres integer)
returns text
language sql immutable
as $$
  select case when p_libres is null then null
              when p_libres <= 0 then 'rojo'
              when p_libres <= 2 then 'ambar'
              else 'verde' end;
$$;

create or replace function public.natacion_semaforo_calcular(p_franja uuid)
returns jsonb
language sql stable security definer
set search_path to 'public'
as $$
  with f as (
    select * from public.natacion_franjas where id = p_franja
  ),
  oc as (
    select * from public.natacion_ocupacion(null, p_franja) o where o.calle is not null
  ),
  cn as (   -- nivel(es) más repetido(s) entre los fijos de cada calle
    select i.calle, i.nivel,
           rank() over (partition by i.calle order by count(*) desc) as rk
      from public.natacion_inscripciones i
     where i.franja_id = p_franja and i.activa and i.nivel is not null
     group by i.calle, i.nivel
  ),
  calles as (
    select oc.calle, oc.en_cupos, oc.cupo, oc.fijos, (oc.cupo - oc.fijos) as libres,
           coalesce(
             (select array_agg(cn.nivel order by cn.nivel) from cn where cn.calle = oc.calle and cn.rk = 1),
             case when oc.calle ~* '^vaso' or public._num_calle(oc.calle) = 1 then array['Iniciación']
                  when public._num_calle(oc.calle) = 2 then array['Desarrollo']
                  when public._num_calle(oc.calle) = 3 then array['Perfeccionamiento']
                  else array[]::text[] end) as niveles
      from oc
  ),
  tot as (
    select coalesce(sum(cupo) filter (where en_cupos), 0)::int as cupo,
           coalesce(sum(fijos), 0)::int as fijos,
           coalesce(sum(greatest(libres, 0)) filter (where en_cupos), 0)::int as libres
      from calles
  ),
  niv as (
    select n.nivel, n.ord,
           (select sum(greatest(c.libres, 0))::int from calles c
             where c.en_cupos and n.nivel = any(c.niveles)) as libres
      from f, unnest(coalesce(f.admite_niveles, '{}'::text[])) with ordinality as n(nivel, ord)
  ),
  niv2 as (
    select nivel, ord, libres, coalesce(public._natacion_semaforo_de(libres), 'ambar') as auto
      from niv
  ),
  au as (
    select case
             when (select cupo from tot) = 0 then null
             when exists (select 1 from niv2) then
               (select auto from niv2
                 order by case auto when 'verde' then 1 when 'ambar' then 2 else 3 end
                 limit 1)
             else public._natacion_semaforo_de((select libres from tot))
           end as s
  )
  select jsonb_build_object(
           'cupo',     tot.cupo,
           'fijos',    tot.fijos,
           'libres',   tot.libres,
           'auto',     au.s,
           'forzado',  f.semaforo_forzado,
           'semaforo', coalesce(f.semaforo_forzado, au.s, f.semaforo),
           'niveles',  coalesce((
              select jsonb_agg(jsonb_build_object(
                       'nivel', n.nivel, 'libres', n.libres, 'auto', n.auto,
                       'semaforo', coalesce(f.semaforo_forzado, n.auto)) order by n.ord)
                from niv2 n), '[]'::jsonb),
           'calles',   coalesce((
              select jsonb_agg(jsonb_build_object(
                       'calle', c.calle, 'en_cupos', c.en_cupos, 'cupo', c.cupo,
                       'fijos', c.fijos, 'libres', c.libres,
                       'niveles', to_jsonb(c.niveles),
                       'semaforo', case when c.en_cupos then public._natacion_semaforo_de(c.libres) end)
                       order by public._num_calle(c.calle) nulls first, c.calle)
                from calles c), '[]'::jsonb))
    from f, tot, au;
$$;

comment on function public.natacion_semaforo_calcular(uuid) is
  'Mig 331 · semáforo de una franja (auto por nivel/calle + forzado). Lo guarda natacion_recalcular_semaforo en semaforo/semaforo_detalle.';

revoke all on function public.natacion_semaforo_calcular(uuid) from public, anon, authenticated;

-- Misma firma. Guarda el efectivo en `semaforo` y el detalle en `semaforo_detalle`.
create or replace function public.natacion_recalcular_semaforo(p_franja uuid)
returns void
language plpgsql security definer
set search_path to 'public'
as $$
declare v jsonb;
begin
  if not exists (select 1 from public.natacion_franjas where id = p_franja) then return; end if;
  v := public.natacion_semaforo_calcular(p_franja);
  update public.natacion_franjas
     set semaforo = coalesce(v->>'semaforo', semaforo),
         semaforo_detalle = v
   where id = p_franja
     and (semaforo is distinct from coalesce(v->>'semaforo', semaforo)
          or semaforo_detalle is distinct from v);
end $$;

-- El trigger de franjas también salta al crear una franja y al cambiar los
-- niveles que admite o el «admite máster» (antes solo cupos y forzado).
drop trigger if exists natacion_franja_recalc_t on public.natacion_franjas;
create trigger natacion_franja_recalc_t
  after insert or update of cupos, semaforo_forzado, admite_niveles, admite_master, activa
  on public.natacion_franjas
  for each row execute function public.natacion_franja_recalc();

-- Vista pública: mismas columnas + al final es_escuela, es_master y niveles
-- (solo nivel + semáforo; ni cifras ni nombres).
create or replace view public.natacion_vacantes as
  select f.dia, f.hora, f.orden, f.grupo, f.calles, f.tiene_vaso, f.semaforo,
         f.admite_niveles, f.criterio, f.id,
         public.natacion_es_escuela(f.grupo)                as es_escuela,
         public.natacion_es_master(f.grupo, f.admite_master) as es_master,
         coalesce((
           select jsonb_agg(jsonb_build_object('nivel', x.n->>'nivel', 'semaforo', x.n->>'semaforo')
                            order by x.o)
             from jsonb_array_elements(coalesce(f.semaforo_detalle->'niveles', '[]'::jsonb))
                  with ordinality as x(n, o)), '[]'::jsonb) as niveles
    from public.natacion_franjas f
   where f.activa
   order by f.dia, f.hora;

grant select on public.natacion_vacantes to anon, authenticated;

-- Recalcular TODAS las franjas con la regla nueva (rellena semaforo_detalle).
do $$
declare r record;
begin
  for r in select id from public.natacion_franjas loop
    perform public.natacion_recalcular_semaforo(r.id);
  end loop;
end $$;
