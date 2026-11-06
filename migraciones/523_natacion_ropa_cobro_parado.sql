-- 523 · Natación · Ropa: cobro PARADO hasta saber a qué cuenta va
-- ---------------------------------------------------------------------------
-- Andrés (6-nov-2026): «los de natación no quiero que paguen todavía su ropa
-- porque no me han dicho a qué cuenta es». Interruptor en pagos_config:
--   ropa_natacion_cobro = false →
--     · natacion_ropa_stock_cobro: no crea enlaces («Pedir el pago» parado).
--     · natacion_equip_estado_set('llegado') con algo que pagar: no deja
--       marcar/avisar (el correo llevaría un enlace que no cobra).
--     · Edge natacion-mes-pagar: un recibo de ropa no abre la pasarela.
-- Para abrirlo: update pagos_config set ropa_natacion_cobro = true;
-- (y decidir la clave: hoy natacion-mes-pagar manda la ropa a Ítaka).
-- ---------------------------------------------------------------------------
begin;
alter table public.pagos_config add column if not exists ropa_natacion_cobro boolean not null default false;

create or replace function public.natacion_ropa_cobro_abierto()
returns boolean language sql stable security definer set search_path to 'public'
as $$ select coalesce((select ropa_natacion_cobro from public.pagos_config where id = 1), false) $$;
grant execute on function public.natacion_ropa_cobro_abierto() to authenticated, service_role;

-- «Pedir el pago» del stock
do $$
declare d text;
begin
  select pg_get_functiondef('public.natacion_ropa_stock_cobro(uuid)'::regprocedure) into d;
  d := replace(d, $x$  select * into v from public.natacion_ropa_stock where id = p_id for update;$x$,
    $x$  if not public.natacion_ropa_cobro_abierto() then
    raise exception 'El cobro de la ropa está parado de momento. Si te paga en mano, apúntalo con «Ha pagado».' using errcode = 'P0001';
  end if;
  select * into v from public.natacion_ropa_stock where id = p_id for update;$x$);
  if position('natacion_ropa_cobro_abierto' in d) = 0 then raise exception 'No pude parchear natacion_ropa_stock_cobro'; end if;
  execute d;

  select pg_get_functiondef('public.natacion_equip_estado_set(uuid,text,text)'::regprocedure) into d;
  d := replace(d, $x$  if p_estado = 'llegado' then
    if v_f.total > 0 and v_f.pago_id is null then$x$,
    $x$  if p_estado = 'llegado' then
    if v_f.total > 0 and v_f.pago_id is null and not public.natacion_ropa_cobro_abierto() then
      raise exception 'El cobro de la ropa está parado de momento: esta familia tiene % € por pagar y el aviso llevaría el enlace de pago. Espera a que se abra.', v_f.total using errcode = 'P0001';
    end if;
    if v_f.total > 0 and v_f.pago_id is null then$x$);
  if position('natacion_ropa_cobro_abierto' in d) = 0 then raise exception 'No pude parchear natacion_equip_estado_set'; end if;
  execute d;

  -- listar: dice si el cobro está abierto
  select pg_get_functiondef('public.natacion_ropa_stock_listar()'::regprocedure) into d;
  d := replace(d, $x$  return jsonb_build_object(
    'stock',$x$, $x$  return jsonb_build_object(
    'cobro_abierto', public.natacion_ropa_cobro_abierto(),
    'stock',$x$);
  if position('cobro_abierto' in d) = 0 then raise exception 'No pude parchear natacion_ropa_stock_listar'; end if;
  execute d;
end $$;
commit;
