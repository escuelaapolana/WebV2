-- 394 · Cuota domiciliada con un PRIMER CARGO suelto en el mismo enlace
-- ---------------------------------------------------------------------------
-- Andrés (19-oct): «¿no puede hacerlo todo domiciliado con el mismo enlace?».
-- Caso: alta a mitad de mes (María Alejandra Aranda, natación máster, 13-oct):
-- octubre proporcional (37 €) + cuota normal de 60 €/mes desde noviembre.
-- Con `cargo_inicial_cent`, entreno-pagar añade ese importe como cobro único
-- a la misma pasarela: hoy se cobra el proporcional y el mes completo llega
-- solo en la fecha de inicio. Un solo mandato SEPA, un solo enlace.
-- ---------------------------------------------------------------------------
begin;

alter table public.cuotas_entreno add column if not exists cargo_inicial_cent integer;
alter table public.cuotas_entreno add column if not exists cargo_inicial_concepto text;
alter table public.cuotas_entreno drop constraint if exists cuotas_entreno_cargo_inicial_check;
alter table public.cuotas_entreno add constraint cuotas_entreno_cargo_inicial_check
  check (cargo_inicial_cent is null or cargo_inicial_cent >= 50);
comment on column public.cuotas_entreno.cargo_inicial_cent is 'Cobro único que se suma a la PRIMERA pasarela (p. ej. el proporcional del mes de alta). Se cobra al domiciliar; la cuota normal empieza en «inicio».';

-- María Alejandra Aranda: el proporcional de octubre va dentro del enlace de la cuota…
update public.cuotas_entreno
   set cargo_inicial_cent = 3700,
       cargo_inicial_concepto = 'Natación máster · octubre 2026 (proporcional desde el 13)',
       nota = concat_ws(' · ', nullif(nota, ''), 'Primer cargo al domiciliar: 37 € de octubre (60 × 19/31). Después 60 €/mes desde noviembre.')
 where atleta_id = 'cc908194-e307-427e-b469-de5f5ede66cf' and suscripcion_estado = 'pendiente';
-- …así que el recibo suelto de 37 € (sin número, sin pagar) sobra.
delete from public.pagos
 where atleta_id = 'cc908194-e307-427e-b469-de5f5ede66cf' and numero_recibo is null and estado = 'pendiente'
   and concepto = 'Natación máster · octubre 2026 (proporcional desde el 13)';

-- La página del enlace (entreno/cuota/) tiene que contarlo: «hoy se cobran 37 €…».
create or replace function public.cuota_entreno_publica(p_token text)
 returns jsonb language sql stable security definer set search_path to 'public' as $function$
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
           'cargo_inicial_concepto', q.cargo_inicial_concepto)
    from public.cuotas_entreno q
    left join public.pagos_config c on c.id = 1
   where length(coalesce(p_token, '')) >= 40
     and q.token = p_token
   limit 1;
$function$;

commit;
