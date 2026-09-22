-- ============================================================
-- 207 · El Cubo · fijar el «primer pago» de una persona (solo admin)
-- ------------------------------------------------------------
-- El club pone, alta por alta, el importe (en €) del primer pago que se
-- cobrará al activar la cuota. Se guarda en céntimos. p_euros = null o 0
-- deja el valor por defecto (10 €) que aplica la función de cobro.
-- ============================================================

create or replace function public.cubo_primer_pago_set(
  p_alta_id uuid,
  p_euros numeric default null
)
 returns integer
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_cent integer;
  v_n integer := 0;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede poner el primer pago.' using errcode = '42501';
  end if;
  if p_alta_id is null then
    raise exception 'Falta el id del alta.' using errcode = 'P0001';
  end if;

  v_cent := case
    when p_euros is null or p_euros <= 0 then null
    else round(p_euros * 100)::integer
  end;

  update public.cubo_altas
     set primer_pago_cent = v_cent
   where id = p_alta_id;
  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'Esa alta ya no está.' using errcode = 'P0001';
  end if;
  return coalesce(v_cent, 0);
end;
$function$;

grant execute on function public.cubo_primer_pago_set(uuid, numeric) to authenticated;
