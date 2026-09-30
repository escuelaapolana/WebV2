-- 264 · El pago de la PRIMERA CUOTA DE SOCIO con tarjeta ya se registra en
-- `pagos_online` (tipo='alta_socio'), pero faltaban dos cosas:
--   1) el CHECK de `pagos_online.tipo` NO permitía 'alta_socio' (solo bono,
--      licencia, ropa, otro) → el insert de socio-pagar fallaba y el pago nunca
--      quedaba registrado. Se amplía el conjunto permitido.
--   2) `pagos_aplicar_efecto` no sabía qué hacer con ese tipo. Se le añade la
--      rama: al confirmar el pago, marca el alta de socio como pagada (así a Isa
--      le consta pagada y el correo con los datos se dispara solo tras esto).
-- Ambos cambios son aditivos; el resto de la función queda idéntico.
begin;

-- 1 · Permitir el tipo 'alta_socio' en pagos_online (solo AMPLÍA el CHECK).
alter table public.pagos_online drop constraint if exists pagos_online_tipo_check;
alter table public.pagos_online add constraint pagos_online_tipo_check
  check (tipo = any (array['bono','licencia','ropa','otro','alta_socio']));

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
    -- Primera cuota de socio pagada: se marca el alta como pagada.
    update public.altas_socio
       set pago_estado = 'pagado'
     where id = (v_pago.metadatos ->> 'alta_id')::uuid;
  end if;

  update public.pagos_online set aplicado_en = now() where id = p_pago;
  return 'aplicado';
end;
$function$;

commit;
