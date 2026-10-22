-- 431 · Natación «MES A MES»: aviso cada mes con enlace y pagan ese mes
-- ---------------------------------------------------------------------------
-- Andrés/Mario (22-oct-2026): algunos (sobre todo máster) NO quieren dejar la
-- tarjeta guardada: «prefieren que les salga un aviso para pagar, entren y
-- paguen». Tercera forma de pago de una cuota de natación, la elige Mario:
--   · 'mes_a_mes': sin suscripción. Cada periodo (mes / trimestre) se crea un
--     RECIBO normal en `pagos` (pendiente, tarjeta, vence el día 5) con un
--     enlace propio /pagar/?t=… que se paga SIN cuenta (Stripe, un solo pago).
--     El webhook de siempre (cubo-webhook → pagos_confirmar → pagos_aplicar_
--     efecto 'recibo') lo deja PAGADO. Sale en Dinero, en el Excel de Mario…
--   · Los recibos los crea natacion_recibos_generar() (la llama cada mañana
--     natacion-cobro-aviso, que manda el correo con el enlace el día 1 y un
--     recordatorio si el día 8 sigue sin pagar).
--   · Dinero: estas cuotas NO cuentan como «domiciliadas» (van por recibos).
-- ---------------------------------------------------------------------------
begin;

alter table public.cuotas_entreno drop constraint if exists cuotas_entreno_metodo_check;
alter table public.cuotas_entreno add constraint cuotas_entreno_metodo_check
  check (metodo = any (array['sepa'::text, 'tarjeta'::text, 'ambos'::text, 'mes_a_mes'::text]));

alter table public.pagos add column if not exists cuota_entreno_id uuid references public.cuotas_entreno(id) on delete set null;
alter table public.pagos add column if not exists token_pago text;
alter table public.pagos add column if not exists aviso_pago_en timestamptz;
alter table public.pagos add column if not exists recordatorio_pago_en timestamptz;
create unique index if not exists pagos_token_pago_unico on public.pagos (token_pago) where token_pago is not null;
create unique index if not exists pagos_cuota_periodo_unico on public.pagos (cuota_entreno_id, periodo)
  where cuota_entreno_id is not null and not anulado;
-- `pagos` tiene SELECT por columnas: sin esto, un select('*') del panel falla.
grant select (cuota_entreno_id, token_pago, aviso_pago_en, recordatorio_pago_en) on public.pagos to authenticated;
comment on column public.pagos.cuota_entreno_id is '431 · Recibo de una cuota de natación «mes a mes».';
comment on column public.pagos.token_pago is '431 · Enlace público de pago (/pagar/?t=…), sin cuenta.';

-- Crea (si no está) el recibo de una cuota «mes a mes» para el periodo que
-- empieza en p_mes y devuelve su enlace de pago. p_importe/p_concepto: para
-- el primer cargo (proporcional); si no, la cuota entera del periodo.
create or replace function public._natacion_recibo_crear(
  p_cuota uuid, p_mes date, p_importe numeric default null, p_concepto text default null, p_avisado boolean default false)
returns text
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_q      public.cuotas_entreno%rowtype;
  v_mes    date := date_trunc('month', p_mes)::date;
  v_hoy    date := (now() at time zone 'Europe/Madrid')::date;
  v_n      int;
  v_fin    date;
  v_meses  text[] := array['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
  v_m3     text[] := array['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
  v_etq    text;
  v_conc   text;
  v_tok    text;
begin
  select * into v_q from public.cuotas_entreno where id = p_cuota;
  if not found or v_q.metodo <> 'mes_a_mes' then raise exception 'Esa cuota no es «mes a mes».'; end if;

  select token_pago into v_tok from public.pagos
   where cuota_entreno_id = p_cuota and periodo = to_char(v_mes, 'YYYY-MM') and not anulado limit 1;
  if v_tok is not null then return 'https://atletismoapolana.com/pagar/?t=' || v_tok; end if;

  v_n := case v_q.periodicidad when 'mensual' then 1 when 'anual' then 12 else 3 end;
  v_fin := (v_mes + make_interval(months => v_n - 1))::date;
  v_etq := case when v_n = 1 then v_meses[extract(month from v_mes)::int] || ' ' || extract(year from v_mes)::int
                when extract(year from v_mes) = extract(year from v_fin)
                  then v_m3[extract(month from v_mes)::int] || '-' || v_m3[extract(month from v_fin)::int] || ' ' || extract(year from v_mes)::int
                else v_m3[extract(month from v_mes)::int] || ' ' || extract(year from v_mes)::int || '-' || v_m3[extract(month from v_fin)::int] || ' ' || extract(year from v_fin)::int end;
  v_conc := coalesce(nullif(btrim(p_concepto), ''),
                     split_part(coalesce(v_q.concepto, 'Cuota de natación'), ' · temporada', 1) || ' · ' || v_etq);
  v_tok := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');

  insert into public.pagos (atleta_id, concepto, importe, estado, fecha_vencimiento, metodo, periodo, notas,
                            cuota_entreno_id, token_pago, aviso_pago_en)
  values (v_q.atleta_id, v_conc, coalesce(p_importe, round(v_q.importe_cent / 100.0, 2)), 'pendiente',
          greatest(v_mes + 4, v_hoy), 'tarjeta', to_char(v_mes, 'YYYY-MM'),
          'Natación · mes a mes (mig 431)', p_cuota, v_tok, case when p_avisado then now() end);
  return 'https://atletismoapolana.com/pagar/?t=' || v_tok;
end;
$$;
revoke all on function public._natacion_recibo_crear(uuid, date, numeric, text, boolean) from public, anon, authenticated;
grant execute on function public._natacion_recibo_crear(uuid, date, numeric, text, boolean) to service_role;

-- Crea el recibo del periodo en curso de cada cuota «mes a mes» viva. Lo
-- llama natacion-cobro-aviso cada mañana (idempotente). Devuelve cuántos creó.
create or replace function public.natacion_recibos_generar(p_hoy date default null)
returns integer
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_hoy  date := coalesce(p_hoy, (now() at time zone 'Europe/Madrid')::date);
  v_q    record;
  v_n    int;
  v_dif  int;
  v_ini  date;
  v_ya   int;
  v_c    int := 0;
begin
  for v_q in select * from public.cuotas_entreno
              where origen = 'natacion' and metodo = 'mes_a_mes'
                and suscripcion_estado <> 'cancelada' and coalesce(cobro_abierto, true)
                and inicio is not null
  loop
    v_n := case v_q.periodicidad when 'mensual' then 1 when 'anual' then 12 else 3 end;
    v_dif := (extract(year from v_hoy)::int * 12 + extract(month from v_hoy)::int)
           - (extract(year from v_q.inicio)::int * 12 + extract(month from v_q.inicio)::int);
    continue when v_dif < 0;
    v_ini := (date_trunc('month', v_q.inicio) + make_interval(months => (v_dif / v_n) * v_n))::date;
    continue when v_q.fin is not null and v_ini > v_q.fin;
    select count(*) into v_ya from public.pagos
     where cuota_entreno_id = v_q.id and periodo = to_char(v_ini, 'YYYY-MM') and not anulado;
    if v_ya = 0 then
      perform public._natacion_recibo_crear(v_q.id, v_ini, null, null, false);
      v_c := v_c + 1;
    end if;
  end loop;
  return v_c;
end;
$$;
revoke all on function public.natacion_recibos_generar(date) from public, anon, authenticated;
grant execute on function public.natacion_recibos_generar(date) to service_role;

-- Lo que enseña la página pública /pagar/?t=… (sin cuenta).
create or replace function public.recibo_publico(p_token text)
returns jsonb
language sql stable security definer
set search_path to 'public'
as $$
  select jsonb_build_object(
           'concepto', p.concepto,
           'importe', p.importe,
           'estado', case when p.anulado then 'anulado' else p.estado end,
           'vence', p.fecha_vencimiento,
           'pagado_el', p.fecha_pago,
           'nombre', initcap(lower(split_part(btrim(coalesce(a.nombre, '')), ' ', 1))))
    from public.pagos p
    left join public.atletas a on a.id = p.atleta_id
   where length(coalesce(p_token, '')) >= 40 and p.token_pago = p_token
   limit 1;
$$;
revoke all on function public.recibo_publico(text) from public;
grant execute on function public.recibo_publico(text) to anon, authenticated, service_role;

-- Abre el pago con tarjeta de un recibo por su enlace (lo llama la Edge
-- natacion-mes-pagar con la clave de servicio). Mismas comprobaciones que
-- pagos_iniciar_recibo, pero sin cuenta: el enlace ES el permiso.
create or replace function public.pagos_iniciar_recibo_token(p_token text)
returns public.pagos_online
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_cfg    public.pagos_config;
  v_recibo public.pagos;
  v_ref    text;
  v_pago   public.pagos_online;
begin
  select * into v_cfg from public.pagos_config where id = 1;
  if not found or not v_cfg.activo then raise exception 'El pago todavía no está activado.' using errcode = 'P0001'; end if;
  if length(coalesce(p_token, '')) < 40 then raise exception 'Ese enlace no es válido.' using errcode = 'P0001'; end if;
  select * into v_recibo from public.pagos where token_pago = p_token;
  if not found then raise exception 'Ese enlace no es válido.' using errcode = 'P0001'; end if;
  if v_recibo.anulado then raise exception 'Este recibo está anulado.' using errcode = 'P0001'; end if;
  if v_recibo.estado = 'pagado' then raise exception 'Este recibo ya está pagado.' using errcode = 'P0001'; end if;
  if v_recibo.importe is null or v_recibo.importe <= 0 then raise exception 'Este recibo no tiene importe.' using errcode = 'P0001'; end if;

  v_ref := 'APO-' || to_char(now(), 'YYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  insert into public.pagos_online (referencia, atleta_id, perfil_id, concepto, tipo, importe_centimos, metadatos)
  values (v_ref, v_recibo.atleta_id,
          (select coalesce(a.perfil_padre_id, a.perfil_id) from public.atletas a where a.id = v_recibo.atleta_id),
          coalesce(nullif(btrim(v_recibo.concepto), ''), 'Recibo del club'), 'recibo',
          round(v_recibo.importe * 100)::int,
          jsonb_build_object('pago_id', v_recibo.id, 'origen', 'enlace'))
  returning * into v_pago;
  return v_pago;
end;
$$;
revoke all on function public.pagos_iniciar_recibo_token(text) from public, anon, authenticated;
grant execute on function public.pagos_iniciar_recibo_token(text) to service_role;

-- Cambia lo que devuelve (columnas del recibo del mes): hay que borrarla antes.
drop function if exists public.natacion_cuotas_listar();
CREATE OR REPLACE FUNCTION public.natacion_cuotas_listar()
 RETURNS TABLE(atleta_id uuid, codigo text, nombre text, apellidos text, tipo text, dias integer, franjas text, acceso_activo boolean, cuota_importe numeric, cuota_periodicidad text, cuota_nota text, cuota_otra_seccion boolean, es_socio boolean, email text, telefono text, cobro_id uuid, cobro_estado text, cobro_importe numeric, cobro_periodicidad text, cobro_metodo text, cobro_inicio date, cobro_fin date, cobro_cargo_inicial numeric, cobro_cargo_concepto text, cobro_abierto boolean, cobro_creado timestamp with time zone, cobro_anulable boolean, enlace text, mes_periodo text, mes_estado text, mes_importe numeric, mes_enlace text, mes_vence date)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede ver las cuotas de natación.' using errcode = '42501';
  end if;

  return query
  with nad as (
    select na.atleta_id, bool_or(na.activo) as activo,
           (array_agg(na.codigo order by na.activo desc, na.created_at desc))[1] as codigo
      from public.natacion_accesos na
     where na.atleta_id is not null
     group by na.atleta_id
  ),
  ins as (
    select i.atleta_id,
           count(distinct i.franja_id)::int as n,
           bool_or(i.tipo = 'Máster') as hay_master,
           string_agg(distinct (array['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'])[f.dia] || ' ' || to_char(f.hora, 'HH24:MI')
                      || '#' || f.dia || to_char(f.hora, 'HH24MI'), ' · ') as fr_raw
      from public.natacion_inscripciones i
      join public.natacion_franjas f on f.id = i.franja_id
     where i.activa and i.atleta_id is not null
     group by i.atleta_id
  ),
  viva as (
    select distinct on (q.atleta_id) q.*
      from public.cuotas_entreno q
     where q.suscripcion_estado <> 'cancelada'
       and q.atleta_id in (select nad.atleta_id from nad)
     order by q.atleta_id, q.created_at desc
  )
  select a.id,
         nad.codigo,
         a.nombre,
         a.apellidos,
         case when ins.atleta_id is not null then (case when ins.hay_master then 'Máster' else 'Escuela' end)
              else public._natacion_tipo_de(a.id) end,
         coalesce(ins.n, 0),
         -- orden por día y hora: se ordena por la clave «#dHHMM» y luego se quita
         (select string_agg(split_part(x, '#', 1), ' · ' order by split_part(x, '#', 2))
            from unnest(string_to_array(ins.fr_raw, ' · ')) x),
         nad.activo and coalesce(a.estado, 'activo') <> 'baja',
         a.cuota_importe,
         a.cuota_periodicidad,
         a.cuota_nota,
         (a.cuota_importe is not null and coalesce(a.cuota_nota, '') !~* '^nataci'),
         coalesce(a.tipo_membresia = 'socio' or a.numero_socio is not null, false),
         case when (case when ins.atleta_id is not null then not ins.hay_master
                         else public._natacion_tipo_de(a.id) = 'Escuela' end)
              then coalesce(nullif(btrim(a.email_tutor), ''), nullif(btrim(a.email), ''),
                            (select nullif(btrim(pf.email), '') from public.perfiles pf where pf.id = coalesce(a.perfil_padre_id, a.perfil_id)))
              else coalesce(nullif(btrim(a.email), ''), nullif(btrim(a.email_tutor), ''),
                            (select nullif(btrim(pf.email), '') from public.perfiles pf where pf.id = coalesce(a.perfil_id, a.perfil_padre_id)))
         end,
         case when (case when ins.atleta_id is not null then not ins.hay_master
                         else public._natacion_tipo_de(a.id) = 'Escuela' end)
              then coalesce(nullif(btrim(a.telefono_tutor), ''), nullif(btrim(a.telefono), ''))
              else coalesce(nullif(btrim(a.telefono), ''), nullif(btrim(a.telefono_tutor), ''))
         end,
         v.id,
         v.suscripcion_estado,
         round(v.importe_cent / 100.0, 2),
         v.periodicidad,
         v.metodo,
         v.inicio,
         v.fin,
         case when coalesce(v.cargo_inicial_cent, 0) >= 50 then round(v.cargo_inicial_cent / 100.0, 2) end,
         v.cargo_inicial_concepto,
         v.cobro_abierto,
         v.created_at,
         (v.id is not null and ((v.suscripcion_estado = 'pendiente' and v.stripe_subscription_id is null) or v.metodo = 'mes_a_mes')),
         case when v.suscripcion_estado = 'pendiente' and v.cobro_abierto and length(coalesce(v.token, '')) >= 40
              then 'https://atletismoapolana.com/entreno/cuota/?t=' || v.token
                   || case when v.periodicidad = 'mensual' then '&m=1' else '' end
         end,
         rm.periodo,
         rm.estado,
         rm.importe,
         case when rm.estado <> 'pagado' and rm.token_pago is not null then 'https://atletismoapolana.com/pagar/?t=' || rm.token_pago end,
         rm.fecha_vencimiento
    from nad
    join public.atletas a on a.id = nad.atleta_id
    left join ins  on ins.atleta_id = a.id
    left join viva v on v.atleta_id = a.id
    -- 431 · «mes a mes»: el último recibo de esa cuota (el del periodo que toca)
    left join lateral (
      select p.periodo, p.estado, p.importe, p.token_pago, p.fecha_vencimiento
        from public.pagos p
       where p.cuota_entreno_id = v.id and not p.anulado
       order by p.periodo desc nulls last, p.created_at desc
       limit 1
    ) rm on v.metodo = 'mes_a_mes'
   where a.anonimizado_en is null
     and coalesce(a.nombre, '') not like '%(duplicado)%'
     -- los de baja solo si aún tienen una cuota viva (para poder verla/anularla)
     and ((nad.activo and coalesce(a.estado, 'activo') <> 'baja') or v.id is not null)
   order by lower(public.unaccent(coalesce(a.nombre, ''))), lower(public.unaccent(coalesce(a.apellidos, '')));
end;
$function$;

CREATE OR REPLACE FUNCTION public.natacion_cobro_anular(p_cuota uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_q public.cuotas_entreno%rowtype;
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede anular cobros de natación.' using errcode = '42501';
  end if;
  select * into v_q from public.cuotas_entreno where id = p_cuota for update;
  if not found then raise exception 'No encuentro ese cobro. Recarga la página.'; end if;
  if not public._natacion_es_nadador(v_q.atleta_id) then
    raise exception 'Ese cobro no es de natación: lo lleva administración.' using errcode = '42501';
  end if;
  if v_q.suscripcion_estado = 'cancelada' then
    return jsonb_build_object('cuota_id', v_q.id, 'ya_estaba', true);
  end if;
  if v_q.metodo <> 'mes_a_mes' and (v_q.suscripcion_estado <> 'pendiente' or v_q.stripe_subscription_id is not null) then
    raise exception 'Ya está domiciliada (o en marcha en Stripe): no se puede anular desde aquí. Avisa a Andrés.';
  end if;

  update public.cuotas_entreno set
    suscripcion_estado = 'cancelada',
    cobro_abierto      = false,
    nota = left(concat_ws(' · ', nullif(nota, ''),
                'Anulada desde Natación el ' || to_char((now() at time zone 'Europe/Madrid'), 'DD/MM/YYYY HH24:MI')
                || coalesce(' por ' || (select nullif(btrim(coalesce(pf.nombre, '') || ' ' || coalesce(pf.apellidos, '')), '')
                                          from public.perfiles pf where pf.id = public.mi_perfil_id()), '')), 1000)
  where id = v_q.id;

  -- 431 · mes a mes: los recibos que aún no se han pagado caen con ella. Los
  -- que no tienen número (no emitidos) se borran; los numerados se anulan con
  -- el permiso de un solo uso de anular_recibo (pagos_protege).
  delete from public.pagos
   where cuota_entreno_id = v_q.id and not anulado and estado <> 'pagado' and numero_recibo is null;
  perform set_config('apolana.anulando', 'si', true);
  update public.pagos set anulado = true, anulado_en = now(),
         anulado_motivo = 'Cuota de natación (mes a mes) anulada desde Natación'
   where cuota_entreno_id = v_q.id and not anulado and estado <> 'pagado';
  perform set_config('apolana.anulando', '', true);

  return jsonb_build_object('cuota_id', v_q.id, 'anulada', true);
end;
$function$;

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
  if coalesce(p_metodo, '') not in ('sepa', 'tarjeta', 'ambos', 'mes_a_mes') then
    raise exception 'La forma de pago tiene que ser «se cobra sola» (tarjeta o IBAN) o «mes a mes».';
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

  -- 431 · MES A MES: no hay suscripción. La cuota queda «activa» y se crea ya
  -- el primer recibo (el primer cargo, o el del mes de inicio) con su enlace
  -- de pago; el resto los crea natacion_recibos_generar cada periodo. Mario
  -- manda este primer enlace (por eso se marca avisado y no sale el correo).
  if p_metodo = 'mes_a_mes' then
    update public.cuotas_entreno set suscripcion_estado = 'activa' where id = v_id;
    v_enlace := public._natacion_recibo_crear(v_id, coalesce(
      case when v_cargo is not null then date_trunc('month', v_hoy)::date end, v_inicio), v_cargo, v_cconc, true);
  end if;

  return jsonb_build_object(
    'cuota_id', v_id, 'enlace', v_enlace, 'concepto', v_concepto, 'email', lower(v_email),
    'importe', v_imp, 'periodicidad', p_periodicidad, 'inicio', v_inicio, 'fin', p_fin,
    'cargo_inicial', v_cargo, 'cargo_inicial_concepto', v_cconc, 'metodo', p_metodo, 'tipo', v_tipo);
end;
$function$;
CREATE OR REPLACE FUNCTION public.dinero_proximos()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_hoy  date := (now() at time zone 'Europe/Madrid')::date;
  v_mes  date := date_trunc('month', (now() at time zone 'Europe/Madrid'))::date;
  v_dia5 date;
  v_res  jsonb;
begin
  if not public.dinero_puede_ver() then
    raise exception 'Solo administración, tesorería o contabilidad ven el dinero.' using errcode = '42501';
  end if;
  v_dia5 := case when extract(day from v_hoy) < 5 then v_mes + 4
                 else (v_mes + interval '1 month')::date + 4 end;

  with cu as (
    select coalesce((ca.proximo_cobro at time zone 'Europe/Madrid')::date, v_dia5) as fecha, ca.*
      from public.cubo_altas ca
     where ca.estado = 'aprobada' and not coalesce(ca.lista_espera, false)
       and ca.suscripcion_estado = 'activa' and ca.pago_externo is null
  ),
  filas as (
    select cu.fecha, 'cubo'::text as tipo, trim(cu.nombre || ' ' || cu.apellidos) as persona,
           'Cuota El Cubo · ' || cu.dias || (case when cu.dias = 1 then ' día' else ' días' end) as concepto,
           cu.precio_mes::numeric as importe,
           exists (select 1 from public.cubo_pausas cp where cp.alta_id = cu.id and cp.estado = 'aprobada'
                    and cp.mes = date_trunc('month', cu.fecha)::date) as pausa,
           case when cu.baja_solicitada is not null then 'Ha pedido la baja' end as detalle,
           'admin/cubo-altas/'::text as enlace
      from cu
    union all
    select (q.proximo_cobro at time zone 'Europe/Madrid')::date, 'cuota',
           trim(coalesce(q.nombre,'') || ' ' || coalesce(q.apellidos,'')),
           q.concepto, round(q.importe_cent / 100.0, 2), false,
           concat_ws(' · ',
             case q.suscripcion_estado when 'en_camino' then 'Primer adeudo en camino' end,
             case when q.proximo_cobro is null then 'Stripe aún no ha dado la fecha' end,
             case when q.cancel_programado then 'Se cancela sola al terminar' end,
             case when q.fin is not null then 'Hasta el ' || to_char(q.fin, 'DD/MM/YYYY') end),
           'admin/cuotas-entreno/'
      from public.cuotas_entreno q
     where q.suscripcion_estado in ('activa','en_camino')
       and q.metodo <> 'mes_a_mes'   -- 431: esas van por recibos (salen abajo)
       and (q.fin is null or q.proximo_cobro is null or (q.proximo_cobro at time zone 'Europe/Madrid')::date <= q.fin)
       -- 380: la parada va en un límite de periodo; los adultos sin fin no cobran tras abril (el «próximo» de julio es la parada, no un cobro)
       and (q.fin is not null or q.proximo_cobro is null or q.proximo_cobro < timestamptz '2027-05-06 09:00+00')
    union all
    select p.fecha_vencimiento,
           case when p.metodo = 'domiciliado' or coalesce(p.notas,'') ilike '%remesa%'
                     or p.concepto ilike '%municipal%' then 'remesa' else 'unico' end,
           coalesce(nullif(trim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')),''), 'Sin persona'),
           p.concepto, p.importe::numeric, false,
           nullif(p.periodo, ''),
           'admin/cobros/'
      from public.pagos p
      left join public.atletas a on a.id = p.atleta_id
     where not p.anulado and p.estado = 'pendiente' and p.fecha_vencimiento >= v_hoy
  )
  select jsonb_build_object(
    'hoy', v_hoy,
    'filas', coalesce((select jsonb_agg(to_jsonb(f) order by f.fecha nulls last, f.tipo, f.persona) from filas f), '[]'::jsonb)
  ) into v_res;
  return v_res;
end;
$function$;

CREATE OR REPLACE FUNCTION public.dinero_cuotas(p_mes date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_m   date := date_trunc('month', coalesce(p_mes, (now() at time zone 'Europe/Madrid')::date))::date;
  v_res jsonb;
begin
  if not public.dinero_puede_ver() then
    raise exception 'Solo administración, tesorería o contabilidad ven el dinero.' using errcode = '42501';
  end if;

  with m as (select * from public.dinero_movimientos_v2()),
  pag as (select alta_id, count(*) n, sum(importe) e from m
           where origen = 'cubo' and estado = 'pagado' and mes_ref = v_m and alta_id is not null group by alta_id),
  pen as (select alta_id, count(*) n, sum(importe) e from m
           where origen = 'cubo' and estado in ('pendiente','fallido') and alta_id is not null group by alta_id),
  al as (
    select ca.*,
      case when ca.precio_mes = public.cubo_precio(ca.dias, true)  then 'reducido'
           when ca.precio_mes = public.cubo_precio(ca.dias, false) then 'general'
           else 'otro' end as tarifa,
      exists (select 1 from public.cubo_pausas cp
               where cp.alta_id = ca.id and cp.estado = 'aprobada' and cp.mes = v_m) as pausa,
      pag.n as pag_n, pag.e as pag_e, pen.n as pen_n, pen.e as pen_e
    from public.cubo_altas ca
    left join pag on pag.alta_id = ca.id
    left join pen on pen.alta_id = ca.id
    where ca.estado = 'aprobada' and not coalesce(ca.lista_espera, false)
      and coalesce(ca.suscripcion_estado, '') <> 'cancelada'
  ),
  cubo as (
    select al.precio_mes, al.dias, al.tarifa,
      count(*) as gente,
      count(*) filter (where al.suscripcion_estado = 'activa')                                   as activas,
      count(*) filter (where al.suscripcion_estado is null and al.cobro_abierto and al.pago_externo is null) as abiertas,
      count(*) filter (where al.suscripcion_estado = 'impago')                                   as impago,
      count(*) filter (where al.pago_externo is not null)                                        as externo,
      count(*) filter (where al.suscripcion_estado is null and not al.cobro_abierto and al.pago_externo is null) as sin_cobro,
      count(*) filter (where al.pausa)                                                           as en_pausa,
      count(*) filter (where al.pag_n is not null)                                               as pag_n,
      coalesce(sum(al.pag_e), 0)                                                                 as pag_e,
      count(*) filter (where al.pen_n is not null)                                               as pen_n,
      coalesce(sum(al.pen_e), 0)                                                                 as pen_e
    from al group by al.precio_mes, al.dias, al.tarifa
  ),
  ce as (
    select q.*,
      (select count(*) from m where m.origen = 'entreno' and m.estado = 'pagado' and m.mes_ref = v_m and m.atleta_id = q.atleta_id) as pag_n,
      (select coalesce(sum(importe),0) from m where m.origen = 'entreno' and m.estado = 'pagado' and m.mes_ref = v_m and m.atleta_id = q.atleta_id) as pag_e
    from public.cuotas_entreno q
    where q.metodo <> 'mes_a_mes'   -- 431: esas van por recibos
      and (q.suscripcion_estado <> 'cancelada'
       or q.ultimo_cobro >= v_m)
  )
  select jsonb_build_object(
    'mes', to_char(v_m, 'YYYY-MM'),
    'precios', public.cubo_precios(),
    'cubo', coalesce((select jsonb_agg(to_jsonb(c) order by c.dias desc, c.precio_mes desc) from cubo c), '[]'::jsonb),
    'cubo_sin_alta', (select count(*) from m where origen = 'cubo' and estado = 'pagado' and mes_ref = v_m and alta_id is null),
    'domiciliadas', coalesce((select jsonb_agg(jsonb_build_object(
        'periodicidad', g.periodicidad,
        'n', g.n, 'activa', g.activa, 'en_camino', g.en_camino, 'sin_iban', g.sin_iban,
        'impago', g.impago, 'cancelada', g.cancelada, 'importe_periodo', g.imp,
        'pagado', jsonb_build_object('n', g.pag_n, 'total', g.pag_e),
        'pendiente', jsonb_build_object('n', g.pen_n, 'total', g.pen_e),
        'personas', g.personas) order by g.periodicidad desc)
      from (
        select ce.periodicidad,
          count(*) n,
          count(*) filter (where ce.suscripcion_estado = 'activa')    activa,
          count(*) filter (where ce.suscripcion_estado = 'en_camino') en_camino,
          count(*) filter (where ce.suscripcion_estado = 'pendiente') sin_iban,
          count(*) filter (where ce.suscripcion_estado = 'impago')    impago,
          count(*) filter (where ce.suscripcion_estado = 'cancelada') cancelada,
          round(coalesce(sum(ce.importe_cent) filter (where ce.suscripcion_estado <> 'cancelada'), 0) / 100.0, 2) imp,
          sum(ce.pag_n) pag_n, sum(ce.pag_e) pag_e,
          count(*) filter (where ce.suscripcion_estado in ('pendiente','impago') and ce.cobro_abierto) pen_n,
          round(coalesce(sum(ce.importe_cent) filter (where ce.suscripcion_estado in ('pendiente','impago') and ce.cobro_abierto), 0) / 100.0, 2) pen_e,
          jsonb_agg(jsonb_build_object(
            'id', ce.id, 'persona', trim(coalesce(ce.nombre,'') || ' ' || coalesce(ce.apellidos,'')),
            'concepto', ce.concepto, 'importe', round(ce.importe_cent / 100.0, 2),
            'estado', ce.suscripcion_estado, 'cobro_abierto', ce.cobro_abierto,
            'proximo_cobro', (ce.proximo_cobro at time zone 'Europe/Madrid')::date,
            'ultimo_cobro', (ce.ultimo_cobro at time zone 'Europe/Madrid')::date,
            'fin', ce.fin, 'cancel_programado', ce.cancel_programado,
            'metodo', ce.metodo, 'inicio', ce.inicio)   -- 380
            order by ce.suscripcion_estado, ce.apellidos) personas
        from ce group by ce.periodicidad
      ) g), '[]'::jsonb)
  ) into v_res;
  return v_res;
end;
$function$;

revoke all on function public.natacion_cuotas_listar() from public, anon;
grant execute on function public.natacion_cuotas_listar() to authenticated, service_role;

insert into public.salud_rpc_front (nombre, en_publica) values ('recibo_publico', true)
on conflict (nombre) do nothing;

commit;
