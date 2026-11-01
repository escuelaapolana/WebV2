-- 504 · Auditoría de seguridad 1-nov-2026 (pagos)
-- pagos_confirmar() daba por PAGADO un recibo/bono/alta sin mirar cuánto se
-- había cobrado. Ahora acepta un parámetro OPCIONAL p_importe (céntimos que
-- dice Stripe: amount_total de la sesión o amount_received del cobro). Si llega
-- y no cuadra con pagos_online.importe_centimos, NO se confirma: el pago se
-- queda como estaba, el aviso queda anotado en pagos_eventos_stripe con
-- resultado 'importe_no_cuadra …' y se devuelve ok=false para revisarlo a mano.
--
-- Compatible con todos los que ya la llaman (pago-webhook, cubo-webhook,
-- nevera-pagar, natacion-mes-pagar, camp-publico, entreno-resync): quien no
-- manda p_importe sigue funcionando igual que antes (default null = sin
-- comprobar). Se BORRA la versión de 4 argumentos para que no queden dos
-- sobrecargas (PostgREST no sabría cuál elegir con llamadas por nombre).
--
-- Permisos: igual que antes, solo postgres y service_role.

begin;

drop function if exists public.pagos_confirmar(text, text, text, text);

create or replace function public.pagos_confirmar(
  p_referencia text,
  p_session    text    default null,
  p_intent     text    default null,
  p_evento     text    default null,
  p_importe    integer default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_pago    public.pagos_online;
  v_efecto  text;
  v_filas   integer;
begin
  -- CAPA (a): ¿ya se atendió este aviso de Stripe?
  if p_evento is not null then
    insert into public.pagos_eventos_stripe (evento_id, tipo)
    values (p_evento, 'confirmar')
    on conflict (evento_id) do nothing;
    get diagnostics v_filas = row_count;
    if v_filas = 0 then
      return jsonb_build_object('ok', true, 'repetido', true, 'motivo', 'aviso ya atendido');
    end if;
  end if;

  select * into v_pago from public.pagos_online where referencia = p_referencia for update;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'no existe ese pago');
  end if;

  -- CAPA (b): si ya estaba cobrado y aplicado, no se repite nada.
  if v_pago.estado = 'pagado' and v_pago.aplicado_en is not null then
    if p_evento is not null then
      update public.pagos_eventos_stripe
         set pago_id = v_pago.id, resultado = 'ya-aplicado' where evento_id = p_evento;
    end if;
    return jsonb_build_object('ok', true, 'repetido', true, 'referencia', v_pago.referencia);
  end if;

  -- CAPA (c) · 504: el importe cobrado tiene que ser el del pago.
  if p_importe is not null and p_importe <> v_pago.importe_centimos then
    if p_evento is not null then
      update public.pagos_eventos_stripe
         set pago_id = v_pago.id,
             resultado = format('importe_no_cuadra: cobrado %s, esperado %s', p_importe, v_pago.importe_centimos)
       where evento_id = p_evento;
    end if;
    raise warning 'pagos_confirmar: importe que no cuadra en % (cobrado %, esperado %)',
      v_pago.referencia, p_importe, v_pago.importe_centimos;
    return jsonb_build_object('ok', false, 'motivo', 'importe_no_cuadra',
                              'referencia', v_pago.referencia,
                              'cobrado', p_importe, 'esperado', v_pago.importe_centimos);
  end if;

  update public.pagos_online
     set estado                = 'pagado',
         pagado_en             = coalesce(pagado_en, now()),
         stripe_session_id     = coalesce(p_session, stripe_session_id),
         stripe_payment_intent = coalesce(p_intent, stripe_payment_intent)
   where id = v_pago.id;

  v_efecto := public.pagos_aplicar_efecto(v_pago.id);

  if p_evento is not null then
    update public.pagos_eventos_stripe
       set pago_id = v_pago.id, resultado = v_efecto where evento_id = p_evento;
  end if;

  return jsonb_build_object('ok', true, 'repetido', false,
                            'referencia', v_pago.referencia,
                            'tipo', v_pago.tipo,
                            'efecto', v_efecto);
end;
$function$;

revoke all on function public.pagos_confirmar(text, text, text, text, integer) from public, anon, authenticated;
grant execute on function public.pagos_confirmar(text, text, text, text, integer) to service_role;

commit;
