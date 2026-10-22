-- 430 · Natación: la familia elige TARJETA o DOMICILIACIÓN al pagar
-- ---------------------------------------------------------------------------
-- Andrés/Mario (22-oct-2026): «que elijan ellos», hasta ahora muchos pagaban
-- con tarjeta. Nuevo método 'ambos': la pasarela de Stripe enseña las dos
-- (tarjeta y SEPA); cuando la familia termina, el webhook mira qué usó y deja
-- en la cuota 'tarjeta' o 'sepa'. Sea cual sea, queda GUARDADA y se cobra
-- sola el día 5 (mig 429). Sin comisión por tarjeta (pagos_config.
-- repercutir_comision = false), así que el importe es el mismo.
--   · cuotas_entreno.metodo admite 'ambos' (solo mientras no ha pagado).
--   · natacion_cobro_crear: p_metodo admite 'ambos' y es el de por defecto.
--   · Las cuotas de natación aún SIN domiciliar (pendientes, sin suscripción)
--     pasan a 'ambos': su mismo enlace ya deja elegir.
-- ---------------------------------------------------------------------------
begin;

alter table public.cuotas_entreno drop constraint if exists cuotas_entreno_metodo_check;
alter table public.cuotas_entreno add constraint cuotas_entreno_metodo_check
  check (metodo = any (array['sepa'::text, 'tarjeta'::text, 'ambos'::text]));

CREATE OR REPLACE FUNCTION public.natacion_cobro_crear(p_atleta uuid, p_importe numeric, p_periodicidad text, p_inicio date, p_fin date, p_cargo_inicial numeric DEFAULT NULL::numeric, p_cargo_concepto text DEFAULT NULL::text, p_metodo text DEFAULT 'ambos'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_hoy      date := (now() at time zone 'Europe/Madrid')::date;
  v_mes_hoy  date := date_trunc('month', (now() at time zone 'Europe/Madrid'))::date;
  v_a        public.atletas%rowtype;
  v_tipo     text;
  v_imp      numeric := round(p_importe, 2);
  v_cargo    numeric := nullif(round(coalesce(p_cargo_inicial, 0), 2), 0);
  v_cconc    text := nullif(btrim(coalesce(p_cargo_concepto, '')), '');
  v_inicio   date;
  v_temp     text;
  v_concepto text;
  v_email    text;
  v_ya       public.cuotas_entreno%rowtype;
  v_token    text;
  v_id       uuid;
  v_enlace   text;
  v_nota     text;
  v_meses    text[] := array['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
  v_eur      text;
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede crear cobros de natación.' using errcode = '42501';
  end if;
  if not public._natacion_es_nadador(p_atleta) then
    raise exception 'Esa persona no es de natación: su cobro lo crea administración desde Dinero.' using errcode = '42501';
  end if;

  -- --- qué y cada cuánto ---
  if v_imp is null or v_imp < 1 or v_imp > 2000 then
    raise exception 'La cuota no parece correcta: escribe un importe entre 1 y 2.000 €.';
  end if;
  if coalesce(p_periodicidad, '') not in ('mensual', 'trimestral') then
    raise exception 'La periodicidad tiene que ser mensual o trimestral.';
  end if;
  if coalesce(p_metodo, '') not in ('sepa', 'tarjeta', 'ambos') then
    raise exception 'La forma de pago tiene que ser domiciliación (SEPA), tarjeta o «la eligen ellos».';
  end if;

  -- --- cuándo (mismas reglas que el asistente de Dinero, 380) ---
  if p_inicio is null then raise exception 'Falta el mes de inicio.'; end if;
  v_inicio := date_trunc('month', p_inicio)::date;
  if v_inicio < v_mes_hoy then
    raise exception 'La fecha de inicio no puede ser un mes pasado: la cuota domiciliada empieza este mes o uno que viene.';
  end if;
  if v_inicio > v_mes_hoy + interval '12 months' then
    raise exception 'La fecha de inicio está demasiado lejos (máximo, dentro de un año).';
  end if;
  if p_fin is null then raise exception 'Falta la fecha de fin (la cuota se para sola ese día).'; end if;
  if p_fin < v_inicio then raise exception 'La fecha de fin es anterior al mes de inicio.'; end if;
  if p_fin < v_hoy then raise exception 'La fecha de fin ya ha pasado.'; end if;
  if p_fin > v_inicio + interval '3 years' then raise exception 'La fecha de fin está demasiado lejos (máximo, 3 años).'; end if;

  -- --- primer cargo suelto (mig 394): p. ej. el proporcional del mes de alta ---
  if v_cargo is not null then
    if v_cargo < 0.5 or v_cargo > 2000 then
      raise exception 'El primer cargo no parece correcto: entre 0,50 y 2.000 € (o déjalo vacío).';
    end if;
    if v_inicio <= v_mes_hoy then
      raise exception 'La fecha de inicio tiene que ser un mes que viene si hay primer cargo (si no, este mes se cobraría dos veces).';
    end if;
    if length(coalesce(v_cconc, '')) > 120 then
      raise exception 'El concepto del primer cargo es demasiado largo (máx. 120).';
    end if;
  else
    v_cconc := null;
  end if;

  -- --- la ficha ---
  select * into v_a from public.atletas where id = p_atleta and anonimizado_en is null;
  if not found then raise exception 'No encuentro esa ficha. Recarga la página.'; end if;
  if coalesce(v_a.estado, 'activo') = 'baja' then
    raise exception 'Está de baja: dale de alta antes de crearle un cobro.';
  end if;
  v_tipo := public._natacion_tipo_de(p_atleta);
  v_email := case when v_tipo = 'Escuela'
                  then coalesce(nullif(btrim(v_a.email_tutor), ''), nullif(btrim(v_a.email), ''),
                                (select nullif(btrim(pf.email), '') from public.perfiles pf where pf.id = coalesce(v_a.perfil_padre_id, v_a.perfil_id)))
                  else coalesce(nullif(btrim(v_a.email), ''), nullif(btrim(v_a.email_tutor), ''),
                                (select nullif(btrim(pf.email), '') from public.perfiles pf where pf.id = coalesce(v_a.perfil_id, v_a.perfil_padre_id)))
             end;
  if v_email is null then
    raise exception 'Falta el correo en su ficha (%): ponlo en la ficha y vuelve a crear el enlace. Stripe lo necesita para el mandato.',
      case when v_tipo = 'Escuela' then 'el del padre, la madre o el tutor' else 'el suyo' end;
  end if;

  -- --- no duplicar: una cuota viva por nadador (de cualquier origen) ---
  perform pg_advisory_xact_lock(hashtext('natacion_cobro_crear:' || p_atleta::text));
  select * into v_ya from public.cuotas_entreno q
   where q.atleta_id = p_atleta and q.suscripcion_estado <> 'cancelada'
   order by q.created_at desc limit 1;
  if found then
    raise exception 'Ya tiene un cobro creado (% € %, %). Si hay que cambiarlo y aún no lo ha domiciliado, anúlalo primero; si ya está domiciliado, avisa a Andrés.',
      replace(to_char(v_ya.importe_cent / 100.0, 'FM999990.00'), '.', ','),
      case v_ya.periodicidad when 'mensual' then 'al mes' when 'trimestral' then 'al trimestre' else 'al año' end,
      case v_ya.suscripcion_estado when 'pendiente' then 'enlace pendiente de domiciliar'
                                   when 'en_camino' then 'domiciliada, primer cobro en camino'
                                   when 'activa' then 'activa'
                                   when 'impago' then 'con un impago'
                                   else v_ya.suscripcion_estado end;
  end if;

  -- --- concepto (como el de Andrés: «Cuota de natación máster · temporada 2026/27 (mensual)») ---
  v_temp := case when extract(month from v_inicio) >= 9
                 then extract(year from v_inicio)::int || '/' || lpad(((extract(year from v_inicio)::int + 1) % 100)::text, 2, '0')
                 else (extract(year from v_inicio)::int - 1) || '/' || lpad((extract(year from v_inicio)::int % 100)::text, 2, '0') end;
  v_concepto := case when v_tipo = 'Escuela' then 'Cuota de escuela de natación' else 'Cuota de natación máster' end
                || ' · temporada ' || v_temp || ' (' || p_periodicidad || ')';
  if v_cargo is not null and v_cconc is null then
    v_cconc := case when v_tipo = 'Escuela' then 'Escuela de natación' else 'Natación máster' end
               || ' · ' || v_meses[extract(month from v_hoy)::int] || ' ' || extract(year from v_hoy)::int || ' (proporcional)';
  end if;

  v_eur := replace(to_char(v_imp, 'FM999990.00'), '.', ',');
  v_nota := 'Creada desde Natación · Cuotas y cobros (mig 395).'
            || case when v_cargo is not null
                    then ' Primer cargo al domiciliar: ' || replace(to_char(v_cargo, 'FM999990.00'), '.', ',') || ' € (' || v_cconc || ').'
                    else '' end
            || ' Después ' || v_eur || ' € ' || case when p_periodicidad = 'mensual' then 'al mes' else 'al trimestre' end
            || ' desde el ' || to_char(v_inicio, 'DD/MM/YYYY') || ' hasta el ' || to_char(p_fin, 'DD/MM/YYYY') || '.';

  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');   -- 64 hex, como el asistente

  insert into public.cuotas_entreno
    (atleta_id, perfil_id, nombre, apellidos, email, concepto, importe_cent,
     periodicidad, inicio, fin, metodo, origen, lote, creado_por, token, cobro_abierto, nota,
     cargo_inicial_cent, cargo_inicial_concepto)
  values
    (v_a.id, coalesce(v_a.perfil_id, v_a.perfil_padre_id), v_a.nombre, v_a.apellidos, lower(v_email),
     v_concepto, round(v_imp * 100)::int,
     p_periodicidad, v_inicio, p_fin, p_metodo, 'natacion', gen_random_uuid(), public.mi_perfil_id(), v_token, true, v_nota,
     case when v_cargo is not null then round(v_cargo * 100)::int end, v_cconc)
  returning id into v_id;

  v_enlace := 'https://atletismoapolana.com/entreno/cuota/?t=' || v_token
              || case when p_periodicidad = 'mensual' then '&m=1' else '' end;

  return jsonb_build_object(
    'cuota_id', v_id, 'enlace', v_enlace, 'concepto', v_concepto, 'email', lower(v_email),
    'importe', v_imp, 'periodicidad', p_periodicidad, 'inicio', v_inicio, 'fin', p_fin,
    'cargo_inicial', v_cargo, 'cargo_inicial_concepto', v_cconc, 'metodo', p_metodo, 'tipo', v_tipo);
end;
$function$;

update public.cuotas_entreno set metodo = 'ambos'
 where origen = 'natacion' and suscripcion_estado = 'pendiente' and stripe_subscription_id is null
   and metodo = 'sepa';

commit;
