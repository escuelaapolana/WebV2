-- 429 · Natación: cobro el DÍA 5 + aviso por correo antes de cada cobro
-- ---------------------------------------------------------------------------
-- Mario/Andrés (22-oct-2026): «tras el primer mes, que los pagos se hagan
-- automáticamente los días 5» y «les debería llegar un aviso al mail de lo que
-- les pasarán el día 5, como en SportMember».
--   · entreno-pagar: las cuotas de natación cobran el primer pago al
--     domiciliar y luego el día 5 (_shared/cuota-entreno.ts planNatacion).
--   · cuota_entreno_publica devuelve 'dia_cobro' (5 en natación) para que la
--     página /entreno/cuota/ lo explique.
--   · cuotas_entreno.aviso_cobro_para: fecha del cobro que ya se avisó por
--     correo (Edge natacion-cobro-aviso, cron diario a las 9:00): un aviso por
--     cobro, nunca dos.
--   · Maia (cuota de natación de antes de la 395, origen NULL) pasa a origen
--     'natacion' para tener el mismo día 5, el mismo concepto y el mismo aviso.
-- ---------------------------------------------------------------------------
begin;

alter table public.cuotas_entreno add column if not exists aviso_cobro_para date;
comment on column public.cuotas_entreno.aviso_cobro_para is
  '429 · Día del cobro que ya se avisó por correo (natacion-cobro-aviso). Si coincide con el próximo cobro, no se vuelve a avisar.';

update public.cuotas_entreno set origen = 'natacion'
 where origen is null and concepto ilike 'cuota de natación%'
   and exists (select 1 from public.natacion_accesos na where na.atleta_id = cuotas_entreno.atleta_id);

create or replace function public.cuota_entreno_publica(p_token text)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select jsonb_build_object(
           'concepto', q.concepto,
           'importe', round(case when q.metodo = 'tarjeta' and coalesce(c.repercutir_comision, false)
                                 then public.pagos_con_comision(q.importe_cent)
                                 else q.importe_cent end / 100.0, 2),
           'periodicidad', q.periodicidad,
           'inicio', q.inicio,
           'fin', q.fin,
           'metodo', q.metodo,
           'cargo_inicial', case when coalesce(q.cargo_inicial_cent, 0) >= 50 then round(q.cargo_inicial_cent / 100.0, 2) end,
           'cargo_inicial_concepto', q.cargo_inicial_concepto,
           'dia_cobro', case when q.origen = 'natacion' then 5 end)
    from public.cuotas_entreno q
    left join public.pagos_config c on c.id = 1
   where length(coalesce(p_token, '')) >= 40
     and q.token = p_token
   limit 1;
$function$;

commit;

-- Aviso de cobro: cada mañana a las 9:00 de Madrid (7 y 8 UTC según horario de verano).
select cron.schedule('apolana-natacion-cobro-aviso', '0 7,8 * * *',
  $$ select public.cron_llamar_edge('natacion-cobro-aviso', '{"cron": true}'::jsonb, 9) $$);
-- Pasar al día 5 las ya domiciliadas: se lanzó UNA vez a mano el 22-oct-2026
--   select public.cron_llamar_edge('natacion-dia5', '{"aplicar": true}'::jsonb);
-- (Maia, Sandra, Azucena → 5-nov; Luciano → 5-ene; parada 5-jul-2027.)
