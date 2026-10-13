-- 311 · Dinero · SEPA: firmar el mandato NO es cobrar
-- ------------------------------------------------------------------
-- QUÉ PASABA
--   · Alta de socio (SEPA, 35 €): el webhook la marcaba `pago_estado='pagado'`
--     al TERMINAR la pasarela, que en SEPA solo significa «mandato firmado».
--     El dinero llega días después (el 1er adeudo de un mandato nuevo tarda
--     ~5 días hábiles, a veces hasta 14) y puede devolverse. `pagos_online`
--     seguía «iniciado», así que había dos verdades.
--   · Cuota de entreno (suscripción SEPA): igual, quedaba `activa` al firmar,
--     sin mirar si el primer adeudo había entrado.
--
-- QUÉ CAMBIA (aditivo; nada se borra)
--   1. altas_socio: nuevo estado 'en_camino' (mandato firmado, adeudo sin
--      liquidar) y 'fallido' / 'devuelto'. Columna `mandato_firmado_en`.
--      `pagado_en` pasa a ser la fecha REAL del cobro.
--   2. cuotas_entreno: nuevo estado 'en_camino' (mismo sentido).
--   3. pagos_aplicar_efecto: al confirmarse el cobro del alta de socio pone
--      también `pagado_en` (antes solo el estado).
--   4. Histórico de cobros de Stripe (Cubo y entreno): una fila en `pagos` por
--      factura, idempotente por `notas='stripe:in_…'` (índice único) y con una
--      sola puerta de entrada para los webhooks: dinero_registrar_cobro_stripe().
--   5. Datos: las 3 altas de socio SEPA y las 5 cuotas de entreno que salían
--      «pagadas/activas» sin cobro confirmado pasan a 'en_camino'.
--
-- ORDEN DE DESPLIEGUE: primero esta migración, luego las funciones
-- cubo-webhook, entreno-pagar, entreno-resync y socio-pagar (escriben/leen
-- los estados nuevos; sin la migración, sus PATCH fallarían por el CHECK).
-- ------------------------------------------------------------------
begin;

-- 1 · altas_socio ----------------------------------------------------
alter table public.altas_socio add column if not exists mandato_firmado_en timestamptz;
comment on column public.altas_socio.mandato_firmado_en is
  'Cuándo firmó el mandato SEPA en la pasarela (no es el cobro: el cobro es pagado_en).';
comment on column public.altas_socio.pago_estado is
  'pendiente · en_camino (mandato SEPA firmado, adeudo sin liquidar) · pagado (dinero entrado) · fallido · devuelto';

alter table public.altas_socio drop constraint if exists altas_socio_pago_estado_chk;
alter table public.altas_socio add constraint altas_socio_pago_estado_chk
  check (pago_estado in ('pendiente','en_camino','pagado','fallido','devuelto'));

-- Datos: «pagado» por el webhook al firmar, pero su pago online sigue sin
-- confirmar (iniciado) → en camino. No toca los pagados a mano (transferencia),
-- cuyo pagos_online sí está 'pagado'.
update public.altas_socio a
   set pago_estado        = 'en_camino',
       mandato_firmado_en = coalesce(a.mandato_firmado_en, a.pagado_en),
       pagado_en          = null
 where a.pago_estado = 'pagado'
   and exists (select 1 from public.pagos_online po
                where po.referencia = 'socio-' || a.id::text
                  and po.estado = 'iniciado');

-- 2 · cuotas_entreno -------------------------------------------------
alter table public.cuotas_entreno drop constraint if exists cuotas_entreno_suscripcion_estado_check;
alter table public.cuotas_entreno add constraint cuotas_entreno_suscripcion_estado_check
  check (suscripcion_estado in ('pendiente','en_camino','activa','impago','cancelada'));
comment on column public.cuotas_entreno.suscripcion_estado is
  'pendiente (sin domiciliar) · en_camino (mandato firmado, 1er adeudo sin liquidar) · activa (cobro confirmado) · impago · cancelada';

-- Datos: «activa» sin ningún cobro confirmado → en camino.
update public.cuotas_entreno
   set suscripcion_estado = 'en_camino'
 where suscripcion_estado = 'activa'
   and ultimo_cobro is null
   and stripe_subscription_id is not null;

-- 3 · pagos_aplicar_efecto: el alta de socio guarda la fecha real de cobro --
create or replace function public.pagos_aplicar_efecto(p_pago uuid)
 returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_pago public.pagos_online;
  v_usos integer;
  v_dias integer;
  v_bono uuid;
begin
  select * into v_pago from public.pagos_online where id = p_pago for update;
  if not found then return 'no-existe'; end if;
  if v_pago.estado <> 'pagado' then return 'no-pagado'; end if;
  if v_pago.aplicado_en is not null then return 'ya-aplicado'; end if;

  if v_pago.tipo = 'bono' then
    v_usos := nullif(v_pago.metadatos ->> 'usos', '')::int;
    v_dias := nullif(v_pago.metadatos ->> 'caducidad_dias', '')::int;
    if v_pago.atleta_id is null or v_usos is null or v_usos <= 0 then
      update public.pagos_online
         set metadatos = metadatos || jsonb_build_object('aviso', 'Pago cobrado sin datos para dar el bono; revisar a mano.')
       where id = p_pago;
      return 'sin-datos';
    end if;
    insert into public.cubo_bonos (atleta_id, usos_totales, precio, fecha_compra, caducidad, activo, notas, pago_online_id)
    values (v_pago.atleta_id, v_usos, round(v_pago.importe_centimos::numeric / 100, 2), current_date,
            case when v_dias is not null then current_date + v_dias else null end,
            true, 'Pagado con tarjeta · ' || v_pago.referencia, v_pago.id)
    on conflict (pago_online_id) where pago_online_id is not null do nothing
    returning id into v_bono;
    if v_bono is null then
      update public.pagos_online set aplicado_en = coalesce(aplicado_en, now()) where id = p_pago;
      return 'ya-aplicado';
    end if;

  elsif v_pago.tipo = 'ropa' then
    update public.pedidos
       set pagado_en = coalesce(pagado_en, now())
     where pago_online_id = v_pago.id;

  elsif v_pago.tipo = 'alta_socio' then
    -- (311) también la fecha REAL del cobro; la de la firma va aparte.
    update public.altas_socio
       set pago_estado = 'pagado',
           pagado_en   = coalesce(pagado_en, v_pago.pagado_en, now())
     where id = (v_pago.metadatos ->> 'alta_id')::uuid;

  elsif v_pago.tipo = 'recibo' then
    -- El recibo del libro de cobros queda pagado con tarjeta.
    update public.pagos
       set estado     = 'pagado',
           fecha_pago = coalesce(fecha_pago, current_date),
           metodo     = 'tarjeta'
     where id = (v_pago.metadatos ->> 'pago_id')::uuid
       and anulado = false
       and estado <> 'pagado';
  end if;

  update public.pagos_online set aplicado_en = now() where id = p_pago;
  return 'aplicado';
end;
$function$;
revoke all on function public.pagos_aplicar_efecto(uuid) from public, anon, authenticated;
grant execute on function public.pagos_aplicar_efecto(uuid) to service_role;

-- 3b · pagos_marcar: si el adeudo del alta de socio falla o se devuelve, el
--      alta lo refleja (así da igual qué webhook reciba el aviso: pago-webhook
--      o cubo-webhook). Solo se añade el bloque final; lo demás, igual.
create or replace function public.pagos_marcar(p_referencia text, p_estado text, p_evento text default null::text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_pago  public.pagos_online;
  v_filas integer;
begin
  if p_estado not in ('fallido','cancelado','reembolsado') then
    raise exception 'Ese estado no se puede poner desde aquí.' using errcode = 'P0001';
  end if;

  if p_evento is not null then
    insert into public.pagos_eventos_stripe (evento_id, tipo)
    values (p_evento, 'marcar:' || p_estado)
    on conflict (evento_id) do nothing;
    get diagnostics v_filas = row_count;
    if v_filas = 0 then
      return jsonb_build_object('ok', true, 'repetido', true);
    end if;
  end if;

  select * into v_pago from public.pagos_online where referencia = p_referencia for update;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'no existe ese pago');
  end if;

  -- Un pago ya cobrado solo puede pasar a 'reembolsado'.
  if v_pago.estado = 'pagado' and p_estado <> 'reembolsado' then
    return jsonb_build_object('ok', true, 'sin_cambios', true, 'estado', v_pago.estado);
  end if;

  update public.pagos_online set estado = p_estado where id = v_pago.id;

  -- (311) Alta de socio: el adeudo SEPA falló o se devolvió → el alta deja de
  -- estar «en camino»/«pagada». 'cancelado' (pasarela abandonada) no toca nada.
  if v_pago.tipo = 'alta_socio' and p_estado in ('fallido','reembolsado') then
    update public.altas_socio
       set pago_estado = case when p_estado = 'fallido' then 'fallido' else 'devuelto' end
     where id = nullif(v_pago.metadatos ->> 'alta_id','')::uuid
       and pago_estado in ('pendiente','en_camino','pagado');
  end if;

  if p_evento is not null then
    update public.pagos_eventos_stripe
       set pago_id = v_pago.id, resultado = p_estado where evento_id = p_evento;
  end if;

  return jsonb_build_object('ok', true, 'estado', p_estado, 'referencia', v_pago.referencia);
end;
$function$;
revoke all on function public.pagos_marcar(text, text, text) from public, anon, authenticated;
grant execute on function public.pagos_marcar(text, text, text) to service_role;

-- 4 · Histórico de cobros de Stripe en `pagos` -----------------------
-- Una factura de Stripe = una fila. El índice hace imposible duplicar aunque
-- Stripe mande invoice.paid e invoice.payment_succeeded a la vez.
create unique index if not exists pagos_stripe_factura_unica
  on public.pagos (notas) where notas like 'stripe:in_%';

create or replace function public.dinero_registrar_cobro_stripe(
  p_factura  text,      -- id de la factura de Stripe (in_…)
  p_atleta   uuid,
  p_concepto text,
  p_importe  numeric,   -- en euros
  p_fecha    date,      -- fecha REAL del cobro (paid_at), no la de hoy
  p_metodo   text,      -- 'tarjeta' | 'domiciliado'
  p_periodo  text default null
) returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_filas integer;
begin
  if coalesce(p_factura, '') !~ '^in_[A-Za-z0-9]+$' then return 'sin-factura'; end if;
  if coalesce(p_importe, 0) <= 0 then return 'sin-importe'; end if;   -- factura de 0 € (prueba gratis)
  if p_periodo is not null and p_periodo !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then p_periodo := null; end if;

  insert into public.pagos (atleta_id, concepto, importe, estado, fecha_pago, metodo, cuenta, periodo, notas)
  values (p_atleta, p_concepto, round(p_importe, 2), 'pagado', coalesce(p_fecha, current_date),
          case when p_metodo in ('tarjeta','domiciliado') then p_metodo else 'tarjeta' end,
          null,          -- sin cuenta: no es un recibo de remesa
          p_periodo, 'stripe:' || p_factura)
  on conflict (notas) where notas like 'stripe:in_%' do nothing;
  get diagnostics v_filas = row_count;
  return case when v_filas = 0 then 'ya-estaba' else 'creado' end;
end;
$function$;
comment on function public.dinero_registrar_cobro_stripe(text, uuid, text, numeric, date, text, text) is
  'Webhooks de Stripe (Cubo/entreno): deja UNA fila pagada en pagos por factura. Idempotente.';
revoke all on function public.dinero_registrar_cobro_stripe(text, uuid, text, numeric, date, text, text) from public, anon, authenticated;
grant execute on function public.dinero_registrar_cobro_stripe(text, uuid, text, numeric, date, text, text) to service_role;

commit;
