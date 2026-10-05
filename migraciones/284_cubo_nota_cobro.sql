-- 284 · Cubo: una «nota de cobro» opcional por alta, que sale en el correo de
-- aviso de pago. Sirve para explicar primeros pagos especiales (p. ej. «este
-- primer pago incluye septiembre + octubre»). En los cobros normales va nula
-- y el correo sale con su texto genérico.

alter table public.cubo_altas add column if not exists nota_cobro text;

-- Se amplía cubo_primer_pago_set con p_nota (se quita la firma vieja de 2 args
-- para que no quede un overload y todas las llamadas usen esta).
drop function if exists public.cubo_primer_pago_set(uuid, numeric);

create or replace function public.cubo_primer_pago_set(p_alta_id uuid, p_euros numeric default null, p_nota text default null)
returns integer
language plpgsql security definer set search_path to 'public'
as $function$
declare v_cent integer; v_n integer := 0;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede poner el primer pago.' using errcode = '42501';
  end if;
  if p_alta_id is null then
    raise exception 'Falta el id del alta.' using errcode = 'P0001';
  end if;

  v_cent := case when p_euros is null or p_euros <= 0 then null else round(p_euros * 100)::integer end;

  update public.cubo_altas
     set primer_pago_cent = v_cent,
         nota_cobro = nullif(btrim(coalesce(p_nota, '')), '')
   where id = p_alta_id;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'Esa alta ya no está.' using errcode = 'P0001'; end if;
  return coalesce(v_cent, 0);
end;
$function$;

-- OJO: al recrear la función (DROP+CREATE con firma nueva) se pierde el GRANT,
-- así que hay que volver a concederlo o la app (authenticated) no puede llamarla.
grant execute on function public.cubo_primer_pago_set(uuid, numeric, text) to authenticated;
