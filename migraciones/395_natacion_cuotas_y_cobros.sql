-- 395 · Natación: «Cuotas y cobros» para el responsable (Mario)
-- ---------------------------------------------------------------------------
-- Andrés (19-oct): «Haz que Mario pueda crear estos enlaces, solo para
-- natación». Y que vea y cambie la cuota de sus nadadores. Hoy Mario no puede:
-- la tabla `atletas` solo le enseña su ficha y `cuotas_entreno` es solo de
-- admin / tesorería (RLS, mig 386).
--
-- Pantalla nueva: portal/natacion-cuotas/ (mundo Natación y Escuela de
-- natación). Todo va por RPC SECURITY DEFINER que comprueban DENTRO:
--   · quién: natacion_cuotas_puede() = admin, o responsable GESTOR de
--     natación / escuela de natación (tabla responsable_seccion). Más
--     estrecho que soy_gestor_natacion(), que también deja pasar a cualquier
--     es_staff() (entrenador, junta…): aquí se crea dinero, así que solo
--     quien lleva la sección.
--   · a quién: solo nadadores, es decir, fichas con fila en natacion_accesos
--     (atleta_id), la misma marca que usan las natacion_* (mig 350…).
--   · GRANT solo a authenticated (desde la 386 nada nuevo va a anon).
--
--   natacion_cuotas_puede()        → ¿puedo usar la pantalla?
--   natacion_cuotas_listar()       → nadadores con tipo, días/franjas, cuota de
--                                    la ficha, socio, correo/teléfono y su
--                                    cuota domiciliada viva (con ENLACE solo si
--                                    sigue pendiente de domiciliar).
--   natacion_cuota_set(...)        → cambia la cuota de la FICHA (0–2000 €,
--                                    mensual o trimestral). No pisa una cuota
--                                    de otra sección (misma regla que la 385).
--   natacion_cobro_crear(...)      → una fila en cuotas_entreno (como el
--                                    asistente de Dinero, mig 380) con
--                                    origen 'natacion', concepto de natación,
--                                    token de 64 hex y, si hace falta, el
--                                    primer cargo suelto (mig 394). No duplica:
--                                    si el nadador ya tiene una cuota viva (de
--                                    cualquier origen) se para con aviso.
--                                    Devuelve el ENLACE. NO manda correos.
--   natacion_cobro_anular(cuota)   → solo si sigue pendiente y sin suscripción
--                                    de Stripe: cancelada + cobro cerrado (el
--                                    enlace deja de valer). Para corregir.
--
-- Edge functions: _shared/cuota-entreno.ts trata 'natacion' igual que
-- 'asistente' (cobro diferido al mes de inicio, concepto del recibo, textos
-- del correo). Hay que desplegar entreno-pagar, cubo-webhook, entreno-resync
-- y entreno-enlace.
--
-- No da a Mario acceso al dinero general (Dinero, recibos, pagos de otros):
-- estas RPC solo devuelven cuotas de nadadores. No toca la RLS de `atletas`.
-- No cambia datos existentes.
-- ---------------------------------------------------------------------------
begin;

comment on column public.cuotas_entreno.origen is
  '''asistente'' = creada con «Nuevo cobro» (admin/dinero, mig 380); ''natacion'' = creada por el responsable de natación (portal/natacion-cuotas, mig 395). Las dos se comportan igual en Stripe (_shared/cuota-entreno.ts). NULL = las de antes (trimestral de adultos, Maia).';

-- Una sola cuota viva por nadador creada desde natación (aunque se pulse
-- «Crear» dos veces a la vez). La función además mira las de cualquier origen.
create unique index if not exists ux_cuotas_entreno_natacion_viva
  on public.cuotas_entreno (atleta_id)
  where origen = 'natacion' and suscripcion_estado <> 'cancelada';

-- ===========================================================================
-- 0 · ¿Quién puede? admin o responsable gestor de natación / escuela natación
-- ===========================================================================
create or replace function public.natacion_cuotas_puede()
returns boolean
language sql stable security definer
set search_path to 'public'
as $$
  select public.es_admin() or exists (
    select 1
      from public.responsable_seccion rs
      join public.perfiles p on p.id = rs.perfil_id
     where p.email = (auth.jwt() ->> 'email')
       and coalesce(p.activo, true)
       and rs.seccion in ('natacion', 'escuela-natacion')
       and coalesce(rs.gestor, true)
  );
$$;
revoke all on function public.natacion_cuotas_puede() from public, anon;
grant execute on function public.natacion_cuotas_puede() to authenticated, service_role;

-- ¿Es nadador? (ficha con acceso de natación). Auxiliar interna.
create or replace function public._natacion_es_nadador(p_atleta uuid)
returns boolean
language sql stable security definer
set search_path to 'public'
as $$
  select p_atleta is not null
     and exists (select 1 from public.natacion_accesos na where na.atleta_id = p_atleta);
$$;
revoke all on function public._natacion_es_nadador(uuid) from public, anon, authenticated;
grant execute on function public._natacion_es_nadador(uuid) to service_role;

-- Escuela o Máster de un nadador: Máster si tiene alguna inscripción activa de
-- máster; si no, Escuela si tiene alguna de escuela; si no tiene ninguna
-- activa, la de su última inscripción; y si nunca tuvo, Máster.
create or replace function public._natacion_tipo_de(p_atleta uuid)
returns text
language sql stable security definer
set search_path to 'public'
as $$
  select coalesce(
    (select case when bool_or(i.tipo = 'Máster') then 'Máster' else 'Escuela' end
       from public.natacion_inscripciones i
      where i.atleta_id = p_atleta and i.activa
     having count(*) > 0),
    (select i.tipo from public.natacion_inscripciones i
      where i.atleta_id = p_atleta order by i.updated_at desc nulls last limit 1),
    'Máster');
$$;
revoke all on function public._natacion_tipo_de(uuid) from public, anon, authenticated;
grant execute on function public._natacion_tipo_de(uuid) to service_role;

-- ===========================================================================
-- 1 · Lista de nadadores con su cuota y su cobro
-- ===========================================================================
create or replace function public.natacion_cuotas_listar()
returns table (
  atleta_id            uuid,
  codigo               text,
  nombre               text,
  apellidos            text,
  tipo                 text,       -- 'Máster' | 'Escuela'
  dias                 integer,    -- franjas activas distintas
  franjas              text,       -- «Lun 19:00 · Mié 20:00»
  acceso_activo        boolean,
  cuota_importe        numeric,
  cuota_periodicidad   text,
  cuota_nota           text,
  cuota_otra_seccion   boolean,    -- la cuota de la ficha no es de natación: no se toca
  es_socio             boolean,
  email                text,       -- el que usaría el cobro (escuela: el del tutor primero)
  telefono             text,       -- para WhatsApp (escuela: el del tutor primero)
  cobro_id             uuid,
  cobro_estado         text,       -- pendiente · en_camino · activa · impago (NULL = sin cobro vivo)
  cobro_importe        numeric,
  cobro_periodicidad   text,
  cobro_metodo         text,
  cobro_inicio         date,
  cobro_fin            date,
  cobro_cargo_inicial  numeric,
  cobro_cargo_concepto text,
  cobro_abierto        boolean,
  cobro_creado         timestamptz,
  cobro_anulable       boolean,
  enlace               text        -- solo si sigue pendiente de domiciliar
)
language plpgsql stable security definer
set search_path to 'public'
as $$
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
         (v.id is not null and v.suscripcion_estado = 'pendiente' and v.stripe_subscription_id is null),
         case when v.suscripcion_estado = 'pendiente' and v.cobro_abierto and length(coalesce(v.token, '')) >= 40
              then 'https://atletismoapolana.com/entreno/cuota/?t=' || v.token
                   || case when v.periodicidad = 'mensual' then '&m=1' else '' end
         end
    from nad
    join public.atletas a on a.id = nad.atleta_id
    left join ins  on ins.atleta_id = a.id
    left join viva v on v.atleta_id = a.id
   where a.anonimizado_en is null
     and coalesce(a.nombre, '') not like '%(duplicado)%'
     -- los de baja solo si aún tienen una cuota viva (para poder verla/anularla)
     and ((nad.activo and coalesce(a.estado, 'activo') <> 'baja') or v.id is not null)
   order by lower(public.unaccent(coalesce(a.nombre, ''))), lower(public.unaccent(coalesce(a.apellidos, '')));
end;
$$;
revoke all on function public.natacion_cuotas_listar() from public, anon;
grant execute on function public.natacion_cuotas_listar() to authenticated, service_role;

-- ===========================================================================
-- 2 · Cambiar la cuota de la FICHA (lo que se apunta, no lo que se cobra)
-- ===========================================================================
create or replace function public.natacion_cuota_set(
  p_atleta       uuid,
  p_importe      numeric,
  p_periodicidad text
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_a    public.atletas%rowtype;
  v_tipo text;
  v_imp  numeric := round(p_importe, 2);
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede cambiar cuotas de natación.' using errcode = '42501';
  end if;
  if not public._natacion_es_nadador(p_atleta) then
    raise exception 'Esa persona no es de natación: su cuota la lleva administración.' using errcode = '42501';
  end if;
  if v_imp is null or v_imp < 0 or v_imp > 2000 then
    raise exception 'La cuota no parece correcta: escribe un importe entre 0 y 2.000 €.';
  end if;
  if coalesce(p_periodicidad, '') not in ('mensual', 'trimestral') then
    raise exception 'La periodicidad tiene que ser mensual o trimestral.';
  end if;

  select * into v_a from public.atletas where id = p_atleta and anonimizado_en is null for update;
  if not found then
    raise exception 'No encuentro esa ficha. Recarga la página.';
  end if;
  -- Misma regla que el alta (385): una cuota de OTRA sección no se pisa desde natación.
  if v_a.cuota_importe is not null and coalesce(v_a.cuota_nota, '') !~* '^nataci' and not public.es_admin() then
    raise exception 'Su ficha ya tiene una cuota de otra sección (% €): no la cambio desde natación. Si debe cambiar, que lo vea administración.',
      replace(to_char(v_a.cuota_importe, 'FM999990.00'), '.', ',');
  end if;

  v_tipo := public._natacion_tipo_de(p_atleta);
  perform set_config('apolana.via_natacion', '1', true);   -- el trigger de cambios del entrenador lo deja pasar (350)
  update public.atletas set
    cuota_importe      = v_imp,
    cuota_periodicidad = p_periodicidad,
    cuota_nota         = left('Natación ' || case when v_tipo = 'Máster' then 'máster' else 'escuela' end
                              || ' · puesta a mano el ' || to_char((now() at time zone 'Europe/Madrid')::date, 'DD/MM/YYYY')
                              || case when v_a.cuota_importe is not null
                                      then ' · antes ' || replace(to_char(v_a.cuota_importe, 'FM999990.00'), '.', ',') || ' € '
                                           || coalesce(v_a.cuota_periodicidad, '')
                                      else '' end, 300),
    cuota_fijada_en    = now(),
    cuota_fijada_por   = public.mi_perfil_id(),
    updated_at         = now()
  where id = p_atleta;
  perform set_config('apolana.via_natacion', '', true);

  return jsonb_build_object('atleta_id', p_atleta, 'cuota_importe', v_imp, 'cuota_periodicidad', p_periodicidad,
                            'antes', v_a.cuota_importe, 'antes_periodicidad', v_a.cuota_periodicidad);
end;
$$;
revoke all on function public.natacion_cuota_set(uuid, numeric, text) from public, anon;
grant execute on function public.natacion_cuota_set(uuid, numeric, text) to authenticated, service_role;

-- ===========================================================================
-- 3 · Crear el cobro domiciliado (fila en cuotas_entreno) y devolver el enlace
-- ===========================================================================
create or replace function public.natacion_cobro_crear(
  p_atleta         uuid,
  p_importe        numeric,
  p_periodicidad   text,
  p_inicio         date,
  p_fin            date,
  p_cargo_inicial  numeric default null,
  p_cargo_concepto text    default null,
  p_metodo         text    default 'sepa'
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
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
  if coalesce(p_metodo, '') not in ('sepa', 'tarjeta') then
    raise exception 'La forma de pago tiene que ser domiciliación (SEPA) o tarjeta.';
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
$$;
revoke all on function public.natacion_cobro_crear(uuid, numeric, text, date, date, numeric, text, text) from public, anon;
grant execute on function public.natacion_cobro_crear(uuid, numeric, text, date, date, numeric, text, text) to authenticated, service_role;

-- ===========================================================================
-- 4 · Anular un cobro que aún nadie ha domiciliado (para corregir un error)
-- ===========================================================================
create or replace function public.natacion_cobro_anular(p_cuota uuid)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
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
  if v_q.suscripcion_estado <> 'pendiente' or v_q.stripe_subscription_id is not null then
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

  return jsonb_build_object('cuota_id', v_q.id, 'anulada', true);
end;
$$;
revoke all on function public.natacion_cobro_anular(uuid) from public, anon;
grant execute on function public.natacion_cobro_anular(uuid) to authenticated, service_role;

-- La salud diaria comprueba que las RPC que llama el front existen (391).
insert into public.salud_rpc_front (nombre, en_publica) values
  ('natacion_cuotas_puede', false),
  ('natacion_cuotas_listar', false),
  ('natacion_cuota_set', false),
  ('natacion_cobro_crear', false),
  ('natacion_cobro_anular', false)
on conflict (nombre) do nothing;

commit;
