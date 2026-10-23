-- 442 · /pagar/ solo dice «cada mes te llegará el aviso» si el recibo es mensual
-- ---------------------------------------------------------------------------
-- La página /pagar/ nació para la natación «mes a mes» (mig 431) y su pie decía
-- siempre «Cada mes te llegará el aviso con su enlace». Desde el 23-oct sirve
-- también para recibos sueltos (David López, entrenamientos oct-dic), y ahí esa
-- frase es falsa. recibo_publico devuelve ahora `mensual`: el recibo viene de
-- una cuota (cuota_entreno_id) y no es un pago suelto.
-- ---------------------------------------------------------------------------
begin;
create or replace function public.recibo_publico(p_token text)
returns jsonb
language sql
stable security definer
set search_path to 'public'
as $function$
  select jsonb_build_object(
           'concepto', p.concepto,
           'importe', p.importe,
           'estado', case when p.anulado then 'anulado' else p.estado end,
           'vence', p.fecha_vencimiento,
           'pagado_el', p.fecha_pago,
           'nombre', initcap(lower(split_part(btrim(coalesce(a.nombre, '')), ' ', 1))),
           'mensual', p.cuota_entreno_id is not null)
    from public.pagos p
    left join public.atletas a on a.id = p.atleta_id
   where length(coalesce(p_token, '')) >= 40 and p.token_pago = p_token
   limit 1;
$function$;
commit;
