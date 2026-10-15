-- 381 · Escuela de atletismo 2026/27: el recibo anual se parte en 3 trimestres
-- ---------------------------------------------------------------------------
-- Andrés (15-oct): cada niño de la escuela tenía UN recibo anual pendiente
-- («Cuota escuela de atletismo 2026/27», sin número, cuenta 'escuela'), pero Isa
-- lo cobra por remesa en 3 trimestres: OCTUBRE, ENERO y ABRIL.
--
-- 1 · Cada recibo anual PENDIENTE, SIN número y no anulado de la escuela 2026/27
--     se cambia por 3 recibos (mismo atleta, cuenta y método):
--       «… · 1er trimestre»  periodo 2026-10  vence 05/10/2026
--       «… · 2º trimestre»   periodo 2027-01  vence 05/01/2027
--       «… · 3er trimestre»  periodo 2027-04  vence 05/04/2027
--     importe = anual / 3 en céntimos exactos; el 3º absorbe el redondeo, así
--     la suma de los 3 es EXACTAMENTE el anual. Luego se borra el anual (sin
--     número → el trigger pagos_protege lo deja borrar).
--     NO se parte:
--       · quien tenga atletas.cuota_periodicidad distinta de temporada/trimestral
--         (anual, mensual…): hoy no hay ninguno, pero queda la guarda;
--       · los recibos de 0 € (Oliver Llopis Arnes): no hay nada que trocear;
--       · quien ya tenga algún recibo «… 2026/27 · N trimestre» (idempotencia).
-- 2 · Idempotente: solo coge recibos con el concepto ANUAL exacto, y los borra
--     en la misma sentencia. Lanzada dos veces, la 2ª no encuentra nada.
--     Comprobación: la suma por atleta (anual antes = trimestres después) se
--     verifica dentro de la migración; si algo no cuadra, aborta.
-- 3 · Remesa de octubre: Andrés CONFIRMA (15-oct) que Isa YA la pasó a todos
--     los niños de la escuela → los 1ºs trimestres quedan pagados (domiciliado,
--     05/10/2026). Al pasar a «pagado» el trigger pagos_numera les pone su
--     número de recibo oficial (serie 2026): eso ya no se deshace, solo se anula.
--
-- Las MUNICIPALES («Cuota municipal (plaza Ayto + subvención) 2026/27») NO se
-- tocan: no siguen este esquema (tarifa municipal = pago único por temporada
-- de 70 € la familia + subvención del Ayto, 320 €/plaza).
-- Rafael Gil de Bernabe (concepto distinto, «Cuota entreno escuela …», 1er
-- trimestre pagado en efectivo + 500 € de 2º y 3º) tampoco se toca.
-- ---------------------------------------------------------------------------
begin;

-- Foto de ANTES: lo que debe cada atleta por la escuela 2026/27 (pendiente)
drop table if exists _m381_antes, _m381_partidos;
create temp table _m381_antes on commit drop as
select p.atleta_id, sum(p.importe) as total, count(*) as n
  from public.pagos p
 where p.concepto = 'Cuota escuela de atletismo 2026/27'
   and p.estado = 'pendiente' and not p.anulado and p.numero_recibo is null
 group by p.atleta_id;

-- ---------------------------------------------------------------------------
-- 1 · Partir el anual en 3 trimestres y borrar el anual
-- ---------------------------------------------------------------------------
create temp table _m381_partidos on commit drop as
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
          and q.concepto like 'Cuota escuela de atletismo 2026/27 · %trimestre'
          and not q.anulado)
),
t(n, nombre, periodo, vence) as (values
  (1, '1er trimestre', '2026-10', date '2026-10-05'),
  (2, '2º trimestre',  '2027-01', date '2027-01-05'),
  (3, '3er trimestre', '2027-04', date '2027-04-05')
),
ins as (
  insert into public.pagos
    (atleta_id, concepto, importe, estado, fecha_vencimiento, notas, metodo, periodo, cuenta, created_at)
  select b.atleta_id,
         'Cuota escuela de atletismo 2026/27 · ' || t.nombre,
         case when t.n < 3
              then floor(round(b.importe * 100) / 3) / 100.0
              else (round(b.importe * 100) - 2 * floor(round(b.importe * 100) / 3)) / 100.0 end,
         'pendiente',
         t.vence,
         'Remesa de Isa · trimestre ' || t.n || ' de 3',
         b.metodo,
         t.periodo,
         b.cuenta,
         b.created_at
    from base b cross join t
  returning id
),
del as (
  delete from public.pagos p using base b where p.id = b.id
  returning p.id, p.atleta_id, p.importe
)
select d.id as anual_id, d.atleta_id, d.importe,
       (select count(*) from ins) as insertados
  from del d;

-- Comprobación: lo partido suma lo mismo por atleta y hay 3 recibos por anual
do $$
declare v_mal int; v_n int; v_ins int;
begin
  select count(*), max(insertados) into v_n, v_ins from _m381_partidos;
  if coalesce(v_ins, 0) <> 3 * v_n then
    raise exception '381: se borraron % anuales pero se crearon % trimestres', v_n, v_ins;
  end if;

  select count(*) into v_mal
    from _m381_partidos d
    left join lateral (
      select sum(q.importe) s, count(*) c from public.pagos q
       where q.atleta_id = d.atleta_id
         and q.concepto like 'Cuota escuela de atletismo 2026/27 · %trimestre'
         and not q.anulado) x on true
   where x.s is distinct from d.importe or x.c <> 3;
  if v_mal > 0 then
    raise exception '381: % atletas no cuadran (anual ≠ suma de sus 3 trimestres)', v_mal;
  end if;
  raise notice '381: % recibos anuales partidos en % trimestres (todo cuadra)', v_n, coalesce(v_ins, 0);
end $$;

-- ---------------------------------------------------------------------------
-- 3 · Isa YA pasó la remesa de OCTUBRE (confirmado por Andrés, 15-oct):
--     1er trimestre = pagado · domiciliado · 05/10/2026 → recibe nº oficial.
--     Se numeran por orden alfabético (apellidos, nombre) para que la serie
--     salga ordenada. Idempotente: solo coge los 1ºs trimestres pendientes.
--     (Incluye a Adrián Berenguer Marco, 7eab9e45-…, que ya estaba confirmado.)
-- ---------------------------------------------------------------------------
do $$
declare r record; v_n int := 0;
begin
  for r in
    select p.id
      from public.pagos p
      left join public.atletas a on a.id = p.atleta_id
     where p.concepto = 'Cuota escuela de atletismo 2026/27 · 1er trimestre'
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
           notas      = 'Remesa de Isa · trimestre 1 de 3 · cobrado en la remesa de octubre 2026'
     where id = r.id;
    v_n := v_n + 1;
  end loop;
  raise notice '381: % primeros trimestres marcados pagados (remesa de octubre)', v_n;
end $$;

-- ---------------------------------------------------------------------------
-- Consulta de comprobación (se puede relanzar cuando se quiera):
--   lo que había antes por atleta = suma de sus 3 trimestres ahora.
-- ---------------------------------------------------------------------------
-- select a0.atleta_id, a0.total as antes, sum(q.importe) as despues,
--        sum(q.importe) filter (where q.estado = 'pagado')    as pagado,
--        sum(q.importe) filter (where q.estado = 'pendiente') as pendiente
--   from _m381_antes a0
--   left join public.pagos q
--     on q.atleta_id = a0.atleta_id and not q.anulado
--    and q.concepto like 'Cuota escuela de atletismo 2026/27%'
--  group by a0.atleta_id, a0.total
-- having a0.total is distinct from sum(q.importe);   -- 0 filas = todo cuadra
do $$
declare v_mal int;
begin
  select count(*) into v_mal from (
    select a0.atleta_id
      from _m381_antes a0
      left join public.pagos q
        on q.atleta_id = a0.atleta_id and not q.anulado
       and q.concepto like 'Cuota escuela de atletismo 2026/27%'
     group by a0.atleta_id, a0.total
    having a0.total is distinct from sum(q.importe)) x;
  if v_mal > 0 then
    raise exception '381: % atletas con total distinto antes/después', v_mal;
  end if;
end $$;

commit;
