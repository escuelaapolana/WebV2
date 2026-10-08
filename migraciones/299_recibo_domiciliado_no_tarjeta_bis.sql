-- 299 · Re-aplicar el guard: un recibo domiciliado NO se cobra por la app
-- (la 297 lo puso, la 298 lo quitó por un malentendido). Confirmado por Andrés
-- (8-oct): las cuotas de escuela las cobra ISA POR EL BANCO (remesa de
-- domiciliación con el IBAN que dieron); en la app solo se VEN, sin botón de
-- pagar. Por eso la app NUNCA debe abrir una pasarela para un recibo
-- domiciliado: si lo hiciera, la familia pagaría por la app Y por el banco
-- (doble cobro). Este guard es la red del servidor; el botón ya no sale en el
-- portal para los recibos con cuenta (IBAN) o metodo 'domiciliado'.

create or replace function public.pagos_iniciar_recibo(p_pago_id uuid, p_perfil uuid)
returns pagos_online
language plpgsql security definer set search_path to 'public'
as $function$
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
    raise exception 'El pago todavía no está activado.' using errcode = 'P0001';
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
  -- Domiciliado (adeudo SEPA): lo cobra el club por el banco (Isa). No se paga
  -- por la app, para que nadie pague dos veces.
  if nullif(btrim(coalesce(v_recibo.cuenta, '')), '') is not null or v_recibo.metodo = 'domiciliado' then
    raise exception 'Esta cuota se cobra por domiciliación bancaria, no por la app.' using errcode = 'P0001';
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
$function$;
