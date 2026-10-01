-- 270_pagar_recibo_tarjeta.sql
-- Cobros · CAPA B: pagar un RECIBO (pagos) con tarjeta desde la app.
--
-- Se engancha al flujo de pago genérico que ya existe (pago-crear →
-- pagos_online → pago-webhook → pagos_confirmar → pagos_aplicar_efecto):
--   · pagos_iniciar_recibo: como pagos_iniciar, pero el importe sale del
--     RECIBO (no del catálogo). Comprueba que el recibo es de quien paga.
--   · pagos_aplicar_efecto: nueva rama tipo='recibo' → marca el recibo
--     `pagos` como pagado (fecha_pago + metodo='tarjeta') cuando Stripe
--     confirma. Idempotente (no re-aplica).
--
-- Seguridad: el importe lo pone la base desde el recibo, nunca el navegador.
-- La propiedad del recibo se comprueba contra atletas.perfil_id/perfil_padre_id.

begin;

-- 0) Admitir el nuevo tipo de pago online 'recibo'
alter table public.pagos_online drop constraint if exists pagos_online_tipo_check;
alter table public.pagos_online add constraint pagos_online_tipo_check
  check (tipo = any (array['bono'::text, 'licencia'::text, 'ropa'::text, 'otro'::text, 'alta_socio'::text, 'recibo'::text]));

-- 1) Iniciar el pago de un recibo concreto
create or replace function public.pagos_iniciar_recibo(
  p_pago_id uuid,
  p_perfil  uuid
) returns public.pagos_online
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_cfg    public.pagos_config;
  v_recibo public.pagos;
  v_suyo   boolean;
  v_ref    text;
  v_cent   integer;
  v_pago   public.pagos_online;
begin
  select * into v_cfg from public.pagos_config where id = 1;
  if not found or not v_cfg.activo then
    raise exception 'El pago con tarjeta todavía no está activado.' using errcode = 'P0001';
  end if;

  select * into v_recibo from public.pagos where id = p_pago_id;
  if not found then
    raise exception 'Ese recibo no existe.' using errcode = 'P0001';
  end if;
  if v_recibo.anulado then
    raise exception 'Ese recibo está anulado.' using errcode = 'P0001';
  end if;
  if v_recibo.estado = 'pagado' then
    raise exception 'Ese recibo ya está pagado.' using errcode = 'P0001';
  end if;
  if v_recibo.importe is null or v_recibo.importe <= 0 then
    raise exception 'Ese recibo no tiene importe.' using errcode = 'P0001';
  end if;
  if v_recibo.atleta_id is null then
    raise exception 'Ese recibo no está asignado a nadie.' using errcode = 'P0001';
  end if;

  -- ¿El recibo es de un atleta de esta persona (suyo o de un hijo)?
  select exists (
    select 1 from public.atletas a
    where a.id = v_recibo.atleta_id
      and (a.perfil_id = p_perfil or a.perfil_padre_id = p_perfil)
  ) into v_suyo;
  if not v_suyo then
    raise exception 'Ese recibo no es tuyo.' using errcode = 'P0001';
  end if;

  v_cent := round(v_recibo.importe * 100)::int;

  v_ref := 'APO-' || to_char(now(), 'YYMMDD') || '-' ||
           upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  insert into public.pagos_online
    (referencia, atleta_id, perfil_id, concepto, tipo, importe_centimos, metadatos)
  values
    (v_ref, v_recibo.atleta_id, p_perfil,
     coalesce(nullif(btrim(v_recibo.concepto), ''), 'Recibo del club'),
     'recibo', v_cent,
     jsonb_build_object('pago_id', v_recibo.id, 'origen', 'portal'))
  returning * into v_pago;

  return v_pago;
end;
$$;

-- Solo la llama la Edge pago-crear con la service key. No se concede a
-- authenticated: así nadie puede invocarla directamente pasando un perfil ajeno
-- (la Edge siempre pasa el perfil del JWT verificado).
revoke all on function public.pagos_iniciar_recibo(uuid, uuid) from public, anon, authenticated;
grant execute on function public.pagos_iniciar_recibo(uuid, uuid) to service_role;

-- 2) Al confirmar el pago, marcar el recibo como pagado (rama 'recibo')
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
    update public.altas_socio
       set pago_estado = 'pagado'
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

commit;
