-- 542 · Natación: pagar la cuota POR TRANSFERENCIA (excepción autorizada)
-- ---------------------------------------------------------------------------
-- Andrés (26-nov-2026, caso Timur): «hay que automatizar que todos los meses
-- haya un aviso y que, con el justificante, yo pueda marcar que ha pagado».
-- Se apoya en el «mes a mes» (mig 431), sin rehacer nada:
--   · cuotas_entreno.transferencia = true sobre una cuota 'mes_a_mes'. Cada
--     periodo natacion_recibos_generar crea su recibo en `pagos` como siempre.
--   · natacion-cobro-aviso, si la cuota es de transferencia, manda el correo
--     con el IBAN, el concepto y «contesta con el justificante» (y, de reserva,
--     el enlace para pagar con tarjeta). Recordatorio igual que el mes a mes.
--   · natacion_recibo_marcar_pagado(): quien lleva la natación (o admin) marca
--     el recibo como cobrado por transferencia al recibir el justificante.
--   · natacion_cobro_transferencia(): pasa una cuota a transferencia (o la
--     devuelve a mes a mes con tarjeta). Si era un enlace sin activar, lo
--     convierte en mes a mes y crea ya el primer recibo.
-- ---------------------------------------------------------------------------
begin;

alter table public.cuotas_entreno add column if not exists transferencia boolean not null default false;
comment on column public.cuotas_entreno.transferencia is
  '542 · Cuota «mes a mes» que se paga por transferencia: el aviso lleva el IBAN y el recibo se marca a mano.';
grant select (transferencia) on public.cuotas_entreno to authenticated;

-- Pasar una cuota a transferencia (p_si = true) o quitarla (p_si = false).
create or replace function public.natacion_cobro_transferencia(p_cuota uuid, p_si boolean default true)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_q      public.cuotas_entreno%rowtype;
  v_hoy    date := (now() at time zone 'Europe/Madrid')::date;
  v_mes    date := date_trunc('month', (now() at time zone 'Europe/Madrid'))::date;
  v_enlace text;
  v_ya     int;
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede cambiar cómo se paga.' using errcode = '42501';
  end if;
  select * into v_q from public.cuotas_entreno where id = p_cuota for update;
  if not found or v_q.origen <> 'natacion' then raise exception 'No es una cuota de natación.'; end if;
  if v_q.suscripcion_estado = 'cancelada' then raise exception 'Esa cuota está anulada.'; end if;

  if not p_si then
    update public.cuotas_entreno set transferencia = false,
           nota = coalesce(nota, '') || ' · ' || to_char(now() at time zone 'Europe/Madrid', 'DD/MM/YYYY') || ': ya no paga por transferencia (sigue mes a mes con aviso)'
     where id = p_cuota;
    return jsonb_build_object('cuota_id', p_cuota, 'transferencia', false);
  end if;

  if v_q.metodo <> 'mes_a_mes' then
    if v_q.stripe_subscription_id is not null or v_q.suscripcion_estado not in ('pendiente') then
      raise exception 'Esta cuota ya está domiciliada. Para pasarla a transferencia, avisa a Andrés.';
    end if;
    -- Enlace sin activar → mes a mes. El primer recibo: el cargo inicial (este
    -- mes) si lo tenía y empieza más adelante; si no, el del mes de inicio.
    update public.cuotas_entreno
       set metodo = 'mes_a_mes', suscripcion_estado = 'activa', transferencia = true,
           nota = coalesce(nota, '') || ' · ' || to_char(now() at time zone 'Europe/Madrid', 'DD/MM/YYYY') || ': pasa a pago por TRANSFERENCIA (mig 542)'
     where id = p_cuota;
    select count(*) into v_ya from public.pagos where cuota_entreno_id = p_cuota and not anulado;
    if v_ya = 0 then
      if coalesce(v_q.cargo_inicial_cent, 0) >= 50 and v_q.inicio is not null and v_q.inicio > v_mes then
        v_enlace := public._natacion_recibo_crear(p_cuota, v_mes, round(v_q.cargo_inicial_cent / 100.0, 2), v_q.cargo_inicial_concepto, true);
      elsif v_q.inicio is not null and v_q.inicio <= v_hoy then
        v_enlace := public._natacion_recibo_crear(p_cuota, v_q.inicio, null, null, true);
      end if;
    end if;
  else
    update public.cuotas_entreno set transferencia = true,
           nota = coalesce(nota, '') || ' · ' || to_char(now() at time zone 'Europe/Madrid', 'DD/MM/YYYY') || ': pasa a pago por TRANSFERENCIA (mig 542)'
     where id = p_cuota;
  end if;
  return jsonb_build_object('cuota_id', p_cuota, 'transferencia', true, 'primer_recibo', v_enlace);
end;
$$;
revoke all on function public.natacion_cobro_transferencia(uuid, boolean) from public, anon;
grant execute on function public.natacion_cobro_transferencia(uuid, boolean) to authenticated, service_role;

-- Marcar cobrado un recibo de natación (transferencia o efectivo) al recibir
-- el justificante. Solo recibos de natación pendientes y sin cobro de Stripe.
create or replace function public.natacion_recibo_marcar_pagado(
  p_pago uuid, p_metodo text default 'transferencia', p_fecha date default null, p_nota text default null)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_fecha date := coalesce(p_fecha, (now() at time zone 'Europe/Madrid')::date);
  v_quien text;
  v_r     record;
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede marcar cobros.' using errcode = '42501';
  end if;
  if coalesce(p_metodo, '') not in ('transferencia', 'efectivo') then
    raise exception 'Forma de cobro no válida.';
  end if;
  if v_fecha > (now() at time zone 'Europe/Madrid')::date then
    raise exception 'La fecha de cobro no puede ser futura.';
  end if;
  select coalesce(nullif(btrim(nombre), ''), auth.jwt() ->> 'email') into v_quien
    from public.perfiles where email = (auth.jwt() ->> 'email') limit 1;

  update public.pagos p
     set estado = 'pagado', metodo = p_metodo, fecha_pago = v_fecha,
         notas = coalesce(nullif(p.notas, ''), '') || ' · ' || initcap(p_metodo) || ' marcada el '
                 || to_char(now() at time zone 'Europe/Madrid', 'DD/MM/YYYY') || ' por ' || coalesce(v_quien, '?')
                 || coalesce(' (' || nullif(btrim(p_nota), '') || ')', '')
   where p.id = p_pago
     and not p.anulado and p.estado in ('pendiente', 'impagado')
     and coalesce(p.notas, '') not like 'stripe:%'
     and p.concepto ~* 'nataci'
     and exists (select 1 from public.natacion_accesos na where na.atleta_id = p.atleta_id)
  returning p.id, p.importe, p.numero_recibo, p.concepto into v_r;
  if v_r.id is null then
    raise exception 'Ese recibo ya no está pendiente (o no es de natación).';
  end if;
  return jsonb_build_object('pago_id', v_r.id, 'importe', v_r.importe, 'numero_recibo', v_r.numero_recibo,
                            'concepto', v_r.concepto, 'fecha', v_fecha, 'metodo', p_metodo);
end;
$$;
revoke all on function public.natacion_recibo_marcar_pagado(uuid, text, date, text) from public, anon;
grant execute on function public.natacion_recibo_marcar_pagado(uuid, text, date, text) to authenticated, service_role;

-- Qué cuotas de natación van por transferencia (para la pantalla de Cuotas).
create or replace function public.natacion_cuotas_transferencia()
returns setof uuid
language sql stable security definer
set search_path to 'public'
as $$
  select id from public.cuotas_entreno
   where origen = 'natacion' and transferencia and suscripcion_estado <> 'cancelada'
     and public.natacion_cuotas_puede();
$$;
revoke all on function public.natacion_cuotas_transferencia() from public, anon;
grant execute on function public.natacion_cuotas_transferencia() to authenticated, service_role;

commit;
