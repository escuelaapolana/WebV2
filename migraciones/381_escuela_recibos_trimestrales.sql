-- 381 · Escuela de atletismo 2026/27: el recibo anual se parte en sus plazos
-- ---------------------------------------------------------------------------
-- Andrés (15-oct): cada niño de la escuela tenía UN recibo anual pendiente
-- («Cuota escuela de atletismo 2026/27», sin número, cuenta 'escuela'), pero
-- Isa lo cobra por remesa en plazos:
--
-- A · Escuela NORMAL = DOS PAGOS (notas de `tarifas`):
--       310 € → 180 € al inscribirse + 130 € en diciembre
--       360 € → 200 €                + 160 €
--       380 € → 205 €                + 175 €
--     Con descuento de hermanos (−20 % / −40 %…) se reparte en la MISMA
--     proporción que su tarifa base (248 = 310×0,8 → 144 + 104). Céntimos
--     exactos; el 2º pago absorbe el redondeo.
--       «… · 1er pago»              periodo 2026-10  vence 05/10/2026
--       «… · 2º pago (diciembre)»   periodo 2026-12  vence 05/12/2026
--     Si un importe no casa con 310/360/380 × (1 | 0,8 | 0,6 | 0,64 | 0,48 |
--     0,36 | 0,512), se usa la base más cercana y sale en un NOTICE «DUDOSO»
--     para que lo revise Andrés (a 15-oct no hay ninguno).
-- B · Academia AC98 con cuota de 750 € (Adrián Berenguer, Ander Pastor,
--     Giovanna Lanz, Gabriel Ródenas) = TRES TRIMESTRES de 250 €:
--       «… · 1er trimestre» 2026-10 · «… · 2º trimestre» 2027-01 ·
--       «… · 3er trimestre» 2027-04 (vencen el día 5).
--     Pablo Rodríguez Ferrer y Miguel Rúa están en el grupo AC98 pero son
--     escuela (360 €): van por DOS PAGOS, como el resto.
-- C · Rafael Gil de Bernabe («Cuota entreno escuela», paga en mano): su recibo
--     de 500 € del 2º y 3er trimestre → 2 × 250 € (05/01/2027 y 05/04/2027),
--     método efectivo, pendientes.
-- D · NO se tocan: Oliver Llopis Arnes (recibo de 0 €), las MUNICIPALES (pago
--     único por temporada: 70 € la familia + subvención del Ayto), quien tenga
--     atletas.cuota_periodicidad distinta de temporada/trimestral (hoy nadie)
--     ni quien ya tenga algún plazo «… 2026/27 · …» (idempotencia).
--
-- REMESA DE OCTUBRE: Andrés CONFIRMA (15-oct) que Isa YA la pasó a todos los
-- niños de la escuela → el 1er pago / 1er trimestre queda PAGADO (domiciliado,
-- 05/10/2026). Al pasar a «pagado» el trigger pagos_numera les pone su número
-- de recibo oficial (serie 2026), en orden alfabético: eso ya no se deshace,
-- solo se anula con anular_recibo.
--
-- Idempotente: solo coge recibos con el concepto ANUAL exacto (y el de 500 €
-- de Rafael por su id) y los borra en la misma sentencia. Comprueba dentro que
-- la suma por atleta y el total de la remesa de Isa no cambian; si algo no
-- cuadra, aborta.
-- ---------------------------------------------------------------------------
begin;

drop table if exists _m381_antes, _m381_plan, _m381_partidos;

-- Total «remesa de Isa» con el mismo criterio que dinero_movimientos_v2
-- (pendiente/impagado con domiciliado|remesa|municipal + pagado domiciliado)
create or replace function pg_temp.m381_total_remesa() returns numeric
language sql stable as $$
  select coalesce(sum(p.importe), 0) from public.pagos p
   where not p.anulado
     and ( (p.estado = 'pendiente' and (p.metodo = 'domiciliado'
                                        or coalesce(p.notas,'') ilike '%remesa%'
                                        or p.concepto ilike '%municipal%'))
        or (p.estado = 'pagado' and p.metodo = 'domiciliado') );
$$;

-- Foto de ANTES: lo pendiente de cada atleta (escuela 2026/27 + Rafael)
create temp table _m381_antes on commit drop as
select p.atleta_id, sum(p.importe) as total, count(*) as n
  from public.pagos p
 where not p.anulado and p.numero_recibo is null and p.estado = 'pendiente'
   and ( p.concepto = 'Cuota escuela de atletismo 2026/27'
      or p.id = '845b361f-1112-4846-822d-513f3f7bf67b')
 group by p.atleta_id;

select set_config('m381.remesa_antes', pg_temp.m381_total_remesa()::text, true);

-- ---------------------------------------------------------------------------
-- 1 · Plan: qué recibo anual se parte, cómo y en cuánto
-- ---------------------------------------------------------------------------
create temp table _m381_plan on commit drop as
with base as (
  select p.*
    from public.pagos p
    left join public.atletas a on a.id = p.atleta_id
   where p.concepto = 'Cuota escuela de atletismo 2026/27'
     and p.estado = 'pendiente'
     and not p.anulado
     and p.numero_recibo is null
     and p.importe > 0
     and coalesce(a.cuota_periodicidad, 'temporada') in ('temporada', 'trimestral')
     and not exists (
       select 1 from public.pagos q
        where q.atleta_id = p.atleta_id
          and q.concepto like 'Cuota escuela de atletismo 2026/27 · %'
          and not q.anulado)
),
tarifa(base, primero) as (values (310.00, 180.00), (360.00, 200.00), (380.00, 205.00)),
factor(f) as (values (1.0), (0.8), (0.6), (0.64), (0.48), (0.36), (0.512)),
casa as (
  select distinct on (b.id) b.id, t.base, t.primero, fa.f,
         abs(b.importe - round(t.base * fa.f, 2)) as dif
    from base b cross join tarifa t cross join factor fa
   order by b.id, abs(b.importe - round(t.base * fa.f, 2)), t.base
)
select b.id, b.atleta_id, b.importe, b.metodo, b.cuenta, b.created_at,
       case when b.atleta_id in ('7eab9e45-435f-4ef7-a189-8368c773b427',   -- Adrián Berenguer Marco
                                 'd98fde93-b3af-442e-8ed7-381a0b1ba909',   -- Ander Pastor Barragan
                                 '1cf6a6ff-091f-42d1-822b-2a12b0d93b28',   -- Giovanna Lanz Monllor
                                 '0106f9c3-8e83-4719-afec-90cc1f37010a')   -- Gabriel Ródenas García De Dionisio
            then 'trimestres' else 'dos_pagos' end as modo,
       c.base, c.f as factor,
       (c.dif > 0.004) as dudoso,
       round(b.importe * c.primero / c.base, 2) as pago1
  from base b join casa c on c.id = b.id;

-- Los dudosos (importe que no casa con ninguna tarifa × descuento), a la vista
do $$
declare r record;
begin
  for r in
    select pl.importe, pl.base, pl.factor, pl.modo,
           trim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')) as persona
      from _m381_plan pl left join public.atletas a on a.id = pl.atleta_id
     where pl.dudoso and pl.modo = 'dos_pagos'
     order by a.apellidos
  loop
    raise notice '381 DUDOSO: % · % € (más cerca de % × %)', r.persona, r.importe, r.base, r.factor;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2 · Crear los plazos y borrar el anual (sin número → se puede)
-- ---------------------------------------------------------------------------
create temp table _m381_partidos on commit drop as
with plazos(modo, n, de, nombre, periodo, vence) as (values
  ('dos_pagos',  1, 2, '1er pago',              '2026-10', date '2026-10-05'),
  ('dos_pagos',  2, 2, '2º pago (diciembre)',   '2026-12', date '2026-12-05'),
  ('trimestres', 1, 3, '1er trimestre',         '2026-10', date '2026-10-05'),
  ('trimestres', 2, 3, '2º trimestre',          '2027-01', date '2027-01-05'),
  ('trimestres', 3, 3, '3er trimestre',         '2027-04', date '2027-04-05')
),
ins as (
  insert into public.pagos
    (atleta_id, concepto, importe, estado, fecha_vencimiento, notas, metodo, periodo, cuenta, created_at)
  select pl.atleta_id,
         'Cuota escuela de atletismo 2026/27 · ' || z.nombre,
         case
           when pl.modo = 'dos_pagos' and z.n = 1 then pl.pago1
           when pl.modo = 'dos_pagos'             then pl.importe - pl.pago1
           when z.n < 3 then floor(round(pl.importe * 100) / 3) / 100.0
           else (round(pl.importe * 100) - 2 * floor(round(pl.importe * 100) / 3)) / 100.0
         end,
         'pendiente',
         z.vence,
         'Remesa de Isa · ' || case when pl.modo = 'dos_pagos' then 'pago ' else 'trimestre ' end
                            || z.n || ' de ' || z.de,
         pl.metodo,
         z.periodo,
         pl.cuenta,
         pl.created_at
    from _m381_plan pl join plazos z on z.modo = pl.modo
  returning id
),
del as (
  delete from public.pagos p using _m381_plan pl
   where p.id = pl.id
     and p.estado = 'pendiente' and p.numero_recibo is null and not p.anulado
  returning p.id, p.atleta_id, p.importe
)
select d.id as anual_id, d.atleta_id, d.importe, (select count(*) from ins) as insertados
  from del d;

-- ---------------------------------------------------------------------------
-- 3 · Rafael Gil de Bernabe: 500 € (2º y 3er trimestre) → 2 × 250 €, en mano
-- ---------------------------------------------------------------------------
with orig as (
  select p.* from public.pagos p
   where p.id = '845b361f-1112-4846-822d-513f3f7bf67b'
     and p.estado = 'pendiente' and p.numero_recibo is null and not p.anulado
     and p.importe = 500
),
ins as (
  insert into public.pagos
    (atleta_id, concepto, importe, estado, fecha_vencimiento, notas, metodo, periodo, cuenta, created_at)
  select o.atleta_id, z.concepto, 250.00, 'pendiente', z.vence,
         'Pago en mano (efectivo) · trimestre ' || z.n || ' de 3', 'efectivo', z.periodo, o.cuenta, o.created_at
    from orig o cross join (values
      (2, 'Cuota entreno escuela · 2º trimestre (ene 2027)',  '2027-01', date '2027-01-05'),
      (3, 'Cuota entreno escuela · 3er trimestre (abr 2027)', '2027-04', date '2027-04-05')
    ) z(n, concepto, periodo, vence)
  returning id
)
delete from public.pagos p using orig o where p.id = o.id;

-- ---------------------------------------------------------------------------
-- Comprobación del reparto (antes de marcar nada pagado)
-- ---------------------------------------------------------------------------
do $$
declare v_n int; v_ins int; v_esp int; v_mal int;
begin
  select count(*), coalesce(max(insertados), 0) into v_n, v_ins from _m381_partidos;
  select coalesce(sum(case modo when 'trimestres' then 3 else 2 end), 0) into v_esp
    from _m381_plan where id in (select anual_id from _m381_partidos);
  if v_n <> (select count(*) from _m381_plan) or v_ins <> v_esp then
    raise exception '381: plan % · borrados % · creados % (esperados %)',
      (select count(*) from _m381_plan), v_n, v_ins, v_esp;
  end if;

  -- Ningún plazo negativo ni a 0
  if exists (select 1 from public.pagos where not anulado and importe <= 0
               and concepto like 'Cuota escuela de atletismo 2026/27 · %') then
    raise exception '381: ha salido algún plazo de 0 € o negativo';
  end if;
  raise notice '381: % recibos anuales partidos en % plazos', v_n, v_ins;
end $$;

-- ---------------------------------------------------------------------------
-- 4 · Isa YA pasó la remesa de OCTUBRE (confirmado por Andrés, 15-oct):
--     1er pago / 1er trimestre = pagado · domiciliado · 05/10/2026 → nº oficial.
--     Numerados por orden alfabético (apellidos, nombre).
-- ---------------------------------------------------------------------------
do $$
declare r record; v_n int := 0;
begin
  for r in
    select p.id
      from public.pagos p
      left join public.atletas a on a.id = p.atleta_id
     where p.concepto in ('Cuota escuela de atletismo 2026/27 · 1er pago',
                          'Cuota escuela de atletismo 2026/27 · 1er trimestre')
       and p.periodo = '2026-10'
       and p.estado = 'pendiente'
       and not p.anulado
       and p.numero_recibo is null
     order by a.apellidos nulls last, a.nombre, p.id
  loop
    update public.pagos
       set estado     = 'pagado',
           metodo     = 'domiciliado',
           fecha_pago = date '2026-10-05',
           notas      = notas || ' · cobrado en la remesa de octubre 2026'
     where id = r.id;
    v_n := v_n + 1;
  end loop;
  raise notice '381: % primeros plazos marcados pagados (remesa de octubre)', v_n;
end $$;

-- ---------------------------------------------------------------------------
-- Comprobación final: lo de cada atleta antes = suma de sus plazos ahora,
-- y el total de la remesa de Isa no cambia.
-- (Se puede relanzar a mano: 0 filas = todo cuadra)
-- ---------------------------------------------------------------------------
-- select a0.atleta_id, a0.total as antes, sum(q.importe) as despues
--   from _m381_antes a0
--   left join public.pagos q
--     on q.atleta_id = a0.atleta_id and not q.anulado
--    and (q.concepto like 'Cuota escuela de atletismo 2026/27%'
--         or q.concepto like 'Cuota entreno escuela · %trimestre (% 2027)')
--  group by a0.atleta_id, a0.total
-- having a0.total is distinct from sum(q.importe);
do $$
declare v_mal int; v_antes numeric; v_desp numeric;
begin
  select count(*) into v_mal from (
    select a0.atleta_id
      from _m381_antes a0
      left join public.pagos q
        on q.atleta_id = a0.atleta_id and not q.anulado
       and (q.concepto like 'Cuota escuela de atletismo 2026/27%'
            or q.concepto like 'Cuota entreno escuela · %trimestre (% 2027)')
     group by a0.atleta_id, a0.total
    having a0.total is distinct from sum(q.importe)) x;
  if v_mal > 0 then
    raise exception '381: % atletas con total distinto antes/después', v_mal;
  end if;

  v_antes := current_setting('m381.remesa_antes')::numeric;
  v_desp := pg_temp.m381_total_remesa();
  if v_antes is distinct from v_desp then
    raise exception '381: el total de la remesa de Isa cambia (% → %)', v_antes, v_desp;
  end if;
  raise notice '381: todo cuadra · remesa de Isa % € antes y después', v_desp;
end $$;

commit;
