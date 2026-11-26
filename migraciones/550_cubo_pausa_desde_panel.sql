-- 550 · El Cubo: «Pausar un mes» directamente desde el panel (26-nov-2026)
-- ---------------------------------------------------------------------------
-- Caso Evelin Hurtado: quería pausar diciembre el 26-nov, pero la persona solo
-- puede pedirlo hasta el día 20 del mes anterior (cubo_pausa_solicitar). Hubo
-- que crearle la solicitud por psql para que Andrés la aprobara. Andrés:
-- «hazlo» → botón «Pausar un mes» en cada fila de «Pagando».
--
-- Esta RPC crea la solicitud EN NOMBRE de la persona, sin el plazo del día 20.
-- El panel la aprueba al momento con la Edge cubo-pausa de siempre (que es la
-- que toca Stripe, comprueba los cargos pendientes y manda el correo).
-- Sigue valiendo:
--   · solo admin (igual que aprobar: es_admin()),
--   · solo con la cuota activa y sin baja pedida,
--   · un mes por temporada (índice único cubo_pausas_una_por_temporada),
--   · a tiempo: hasta el día 4 del mes pausado (el recibo sale el 5).
-- Si ya había una solicitud de ese mes pedida por la persona, la devuelve.

create or replace function public.cubo_pausa_crear_admin(p_alta uuid, p_mes date)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  a     public.cubo_altas;
  v_mes date := date_trunc('month', p_mes)::date;
  v_id  uuid;
  v_est text;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede pausar cuotas del Cubo.' using errcode = '42501';
  end if;
  perform public.cubo_pausas_caducar();
  select * into a from public.cubo_altas where id = p_alta;
  if not found then return jsonb_build_object('ok', false, 'error', 'Esa ficha ya no está.'); end if;
  if a.suscripcion_estado is distinct from 'activa' then
    return jsonb_build_object('ok', false, 'error', 'Solo se puede pausar una cuota activa.');
  end if;
  if a.baja_solicitada is not null then
    return jsonb_build_object('ok', false, 'error', 'Ha pedido la baja: no hace falta pausar.');
  end if;
  if p_mes is null or public.cubo_pausa_hoy() >= v_mes + 4 then
    return jsonb_build_object('ok', false, 'error', 'Ese mes ya no se puede pausar: el recibo sale el día 5 (hasta el día 4 se puede).');
  end if;
  if v_mes > (date_trunc('month', public.cubo_pausa_hoy()) + interval '6 months')::date then
    return jsonb_build_object('ok', false, 'error', 'Como mucho se puede pausar con 6 meses de antelación.');
  end if;

  -- ¿Ya la había pedido ella para ese mes? Entonces esa misma.
  select id, estado into v_id, v_est from public.cubo_pausas
   where alta_id = p_alta and mes = v_mes and estado in ('solicitada', 'aprobada')
   limit 1;
  if v_id is not null then
    return jsonb_build_object('ok', true, 'id', v_id, 'mes', v_mes, 'ya_estaba', true, 'estado', v_est);
  end if;

  insert into public.cubo_pausas (alta_id, perfil_id, mes)
  values (p_alta, a.perfil_id, v_mes)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'mes', v_mes);
exception when unique_violation then
  return jsonb_build_object('ok', false, 'error',
    'Ya tiene otra pausa pedida o aprobada esta temporada (máximo un mes). Si es otra, deshazla o recházala primero.');
end; $function$;

revoke all on function public.cubo_pausa_crear_admin(uuid, date) from public, anon;
grant execute on function public.cubo_pausa_crear_admin(uuid, date) to authenticated, service_role;
