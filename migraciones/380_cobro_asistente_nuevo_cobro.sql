-- 380 · Asistente «Nuevo cobro» en admin/dinero
-- ---------------------------------------------------------------------------
-- QUÉ ES
--   Un solo asistente (4 pasos + resumen) para cobrar: ¿a quién? (una persona,
--   un grupo o varias) · ¿qué? (concepto + importe, igual o por persona) ·
--   ¿cada cuánto? (una vez / mensual / trimestral / anual, con mes de inicio y
--   fecha de fin) · ¿cómo? (tarjeta · domiciliación SEPA · remesa de Isa ·
--   efectivo). No inventa circuitos: reparte en los que ya existen.
--
--     Una vez   + remesa / efectivo / tarjeta → recibos en `pagos` con la MISMA
--                 RPC de «Cobrar a un grupo» (cobro_grupo_lineas, mig 269):
--                 remesa = metodo 'domiciliado' + cuenta (la pasa Isa, la familia
--                 no la ve); efectivo = 'efectivo' (se marca a mano en Dinero);
--                 tarjeta = 'tarjeta' SIN cuenta (la persona lo paga desde su
--                 Inicio con «Pagar con tarjeta» → pago-crear).
--     Recurrente + remesa / efectivo → un recibo por PLAZO (periodo y fecha de
--                 cargo de cada plazo), también con cobro_grupo_lineas.
--     Recurrente + SEPA / tarjeta → una fila en `cuotas_entreno` por persona
--                 (suscripción de Stripe: entreno-pagar, webhook cubo-webhook
--                 rama «entreno-», se para sola en `fin`), con enlace por correo
--                 (entreno-enlace). Nuevas columnas: metodo, inicio, origen…
--
-- PERMISOS: crear = admin o ve_dinero() (tesorería / contabilidad), lo mismo que
--   ve el dinero (dinero_puede_ver). Responsables de sección (Mario…) NO.
--   (Si algún día un responsable debe crear cobros SOLO de su sección, el sitio
--   es cobro_asistente_puede(): ahora no lo contempla a propósito.)
--
-- Toca además (copiadas de la versión VIVA, cambio mínimo y marcado «380»):
--   · dinero_movimientos(): la cuota con tarjeta sale como 'tarjeta' y
--     «sin pagar» (no «sin IBAN»).
--   · dinero_cuotas(): cada persona lleva su `metodo` e `inicio`.
--   · mi_cuota_entreno(): devuelve también periodicidad y metodo (Inicio del
--     portal: «/ mes», «con tarjeta»…). Cambia el tipo → drop + create + grants.
--   · cuota_entreno_publica(token): lo que /entreno/cuota/ necesita para
--     explicar la cuota (sin datos personales).
-- ---------------------------------------------------------------------------
begin;

-- ===========================================================================
-- 1 · cuotas_entreno generalizada
-- ===========================================================================
alter table public.cuotas_entreno
  add column if not exists metodo     text not null default 'sepa',
  add column if not exists inicio     date,
  add column if not exists origen     text,
  add column if not exists lote       uuid,
  add column if not exists creado_por uuid;

alter table public.cuotas_entreno drop constraint if exists cuotas_entreno_metodo_check;
alter table public.cuotas_entreno add constraint cuotas_entreno_metodo_check
  check (metodo in ('sepa', 'tarjeta'));

alter table public.cuotas_entreno drop constraint if exists cuotas_entreno_periodicidad_check;
alter table public.cuotas_entreno add constraint cuotas_entreno_periodicidad_check
  check (periodicidad in ('trimestral', 'mensual', 'anual'));

alter table public.cuotas_entreno drop constraint if exists cuotas_entreno_inicio_fin_check;
alter table public.cuotas_entreno add constraint cuotas_entreno_inicio_fin_check
  check (inicio is null or fin is null or fin >= inicio);

comment on column public.cuotas_entreno.metodo is
  'sepa (adeudo, por defecto: lo de siempre) o tarjeta (mig 380). Decide payment_method_types en entreno-pagar.';
comment on column public.cuotas_entreno.inicio is
  'Día 1 del mes de inicio (mig 380). Si está a más de 48 h, el 1er cobro espera a ese día (trial_end de Stripe). NULL = cuotas viejas.';
comment on column public.cuotas_entreno.origen is
  '''asistente'' = creada con «Nuevo cobro» (admin/dinero, mig 380): textos y concepto genéricos. NULL = las de antes (trimestral de adultos, Maia).';
comment on column public.cuotas_entreno.lote is
  'Cuotas creadas a la vez con el asistente (mig 380).';

create index if not exists idx_cuotas_entreno_lote on public.cuotas_entreno(lote) where lote is not null;

-- ===========================================================================
-- 2 · Quién puede usar el asistente
-- ===========================================================================
create or replace function public.cobro_asistente_puede()
returns boolean
language sql stable security definer
set search_path to 'public'
as $$
  -- Lo mismo que ve el dinero (dinero_puede_ver): admin, tesorería o
  -- contabilidad. Junta NO. Responsables de sección NO (a propósito).
  select public.es_admin() or public.ve_dinero();
$$;
revoke all on function public.cobro_asistente_puede() from public, anon;
grant execute on function public.cobro_asistente_puede() to authenticated, service_role;

-- ===========================================================================
-- 3 · Datos para abrir el asistente: grupos (con natación por inscripciones) y
--     la configuración del pago con tarjeta.
-- ===========================================================================
create or replace function public.cobro_asistente_datos()
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
declare
  v jsonb;
begin
  if not public.cobro_asistente_puede() then
    raise exception 'Solo administración, tesorería o contabilidad pueden crear cobros.' using errcode = '42501';
  end if;

  with miembros as (
    select ag.grupo_id, ag.atleta_id from public.atleta_grupos ag
    union
    select a.grupo_id, a.id from public.atletas a where a.grupo_id is not null
  ),
  g as (
    select gr.id::text as clave, gr.nombre, gr.seccion,
           count(distinct a.id) as n
      from public.grupos gr
      join miembros mb on mb.grupo_id = gr.id
      join public.atletas a on a.id = mb.atleta_id
     where coalesce(gr.activo, true)
       and coalesce(a.estado, 'activo') <> 'baja'
       and a.anonimizado_en is null
       and coalesce(a.nombre, '') not like '%(duplicado)%'
     group by gr.id, gr.nombre, gr.seccion
    having count(distinct a.id) > 0
  ),
  -- Natación: la gente está en natacion_inscripciones (no en grupos).
  nat as (
    select 'nat:' || i.tipo as clave,
           case i.tipo when 'Escuela' then 'Escuela de natación (inscritos)' else 'Natación Máster (inscritos)' end as nombre,
           case i.tipo when 'Escuela' then 'escuela-natacion' else 'natacion' end as seccion,
           count(distinct i.atleta_id) as n
      from public.natacion_inscripciones i
      join public.atletas a on a.id = i.atleta_id
     where i.activa and coalesce(a.estado, 'activo') <> 'baja' and a.anonimizado_en is null
     group by i.tipo
    union all
    select 'nat:Escuela:' || i.nivel,
           'Escuela de natación · ' || i.nivel || ' (inscritos)',
           'escuela-natacion',
           count(distinct i.atleta_id)
      from public.natacion_inscripciones i
      join public.atletas a on a.id = i.atleta_id
     where i.activa and i.tipo = 'Escuela' and i.nivel is not null
       and coalesce(a.estado, 'activo') <> 'baja' and a.anonimizado_en is null
     group by i.nivel
  )
  select jsonb_build_object(
    'grupos', coalesce((select jsonb_agg(jsonb_build_object('clave', x.clave, 'nombre', x.nombre, 'seccion', x.seccion, 'n', x.n)
                                         order by x.seccion, x.nombre)
                          from (select * from g union all select * from nat where n > 0) x), '[]'::jsonb),
    'config', (select jsonb_build_object('activo', c.activo, 'modo', c.modo, 'repercutir_comision', c.repercutir_comision)
                 from public.pagos_config c where c.id = 1),
    'hoy', (now() at time zone 'Europe/Madrid')::date
  ) into v;
  return v;
end;
$$;
revoke all on function public.cobro_asistente_datos() from public, anon;
grant execute on function public.cobro_asistente_datos() to authenticated, service_role;

-- ===========================================================================
-- 4 · Personas: por nombre (buscador), por grupo (o natación) o por ids.
--     Sin correo ni teléfono: solo si TIENE correo y cuenta en la app.
-- ===========================================================================
create or replace function public.cobro_asistente_personas(
  p_q     text   default null,
  p_grupo text   default null,
  p_ids   uuid[] default null
)
returns table (
  id uuid, nombre text, apellidos text, seccion text, grupo text,
  cuota_importe numeric, cuota_periodicidad text,
  tiene_correo boolean, tiene_cuenta boolean, estado text
)
language plpgsql stable security definer
set search_path to 'public'
as $$
declare
  v_q   text := lower(public.unaccent(btrim(coalesce(p_q, ''))));
  v_pal text[];
begin
  if not public.cobro_asistente_puede() then
    raise exception 'Solo administración, tesorería o contabilidad pueden crear cobros.' using errcode = '42501';
  end if;
  if v_q = '' and p_grupo is null and p_ids is null then
    return;
  end if;
  if v_q <> '' and length(v_q) < 2 then
    return;
  end if;
  v_pal := case when v_q = '' then null else regexp_split_to_array(v_q, '\s+') end;

  return query
  with base as (
    select a.* from public.atletas a
     where coalesce(a.estado, 'activo') <> 'baja'
       and a.anonimizado_en is null
       and coalesce(a.nombre, '') not like '%(duplicado)%'
  ),
  sel as (
    select b.* from base b
     where
       case
         when p_ids is not null then b.id = any(p_ids)
         when p_grupo like 'nat:%' then exists (
           select 1 from public.natacion_inscripciones i
            where i.atleta_id = b.id and i.activa
              and i.tipo = split_part(p_grupo, ':', 2)
              and (split_part(p_grupo, ':', 3) = '' or i.nivel = split_part(p_grupo, ':', 3)))
         when p_grupo is not null then (
              b.grupo_id::text = p_grupo
           or exists (select 1 from public.atleta_grupos ag where ag.atleta_id = b.id and ag.grupo_id::text = p_grupo))
         else (
           select bool_and(lower(public.unaccent(coalesce(b.nombre, '') || ' ' || coalesce(b.apellidos, ''))) like '%' || w || '%')
             from unnest(v_pal) w)
       end
  )
  select s.id, s.nombre, s.apellidos,
         coalesce(gp.seccion, case s.tipo_membresia when 'socio' then 'socios' when 'cubo' then 'cubo'
                                                     when 'escuela' then 'escuela' when 'municipal' then 'escuela' end),
         gp.nombre,
         s.cuota_importe, s.cuota_periodicidad,
         (coalesce(nullif(btrim(s.email), ''), nullif(btrim(s.email_tutor), ''),
                   (select nullif(btrim(pf.email), '') from public.perfiles pf where pf.id = coalesce(s.perfil_id, s.perfil_padre_id))) is not null),
         (s.perfil_id is not null or s.perfil_padre_id is not null),
         coalesce(s.estado, 'activo')
    from sel s
    left join lateral (
      select g.nombre, g.seccion from public.grupos g
       where g.id = coalesce(
               (select ag.grupo_id from public.atleta_grupos ag where ag.atleta_id = s.id order by ag.principal desc, ag.desde limit 1),
               s.grupo_id)
    ) gp on true
   order by s.apellidos nulls last, s.nombre
   limit case when p_grupo is null and p_ids is null then 30 else 1000 end;
end;
$$;
revoke all on function public.cobro_asistente_personas(text, text, uuid[]) from public, anon;
grant execute on function public.cobro_asistente_personas(text, text, uuid[]) to authenticated, service_role;

-- ===========================================================================
-- 5 · CREAR (o simular, con p->>'simular' = true: no escribe nada y dice qué
--     pasaría: cuántos cobros, quién se salta y por qué).
--
--   p = { concepto, frecuencia: unica|mensual|trimestral|anual,
--         metodo: tarjeta|sepa|remesa|efectivo,
--         inicio: 'YYYY-MM'  (mes de inicio; en «una vez», el periodo),
--         fin: 'YYYY-MM-DD'  (recurrente: último día que cubre; se para sola),
--         vencimiento: 'YYYY-MM-DD' (una vez: fecha límite, opcional),
--         dia_cargo: 1..28   (recurrente por recibos: día de cada plazo, 5),
--         cuenta: escuela|club (solo remesa), notas, guardar_cuota,
--         lineas: [{atleta_id, importe}], simular }
-- ===========================================================================
create or replace function public.cobro_asistente_crear(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_concepto text := btrim(coalesce(p->>'concepto', ''));
  v_frec     text := coalesce(p->>'frecuencia', '');
  v_metodo   text := coalesce(p->>'metodo', '');
  v_simular  boolean := coalesce((p->>'simular')::boolean, false);
  v_guardar  boolean := coalesce((p->>'guardar_cuota')::boolean, false);
  v_notas    text := nullif(btrim(coalesce(p->>'notas', '')), '');
  v_cuenta   text := nullif(btrim(coalesce(p->>'cuenta', '')), '');
  v_dia      int;
  v_inicio   date;
  v_fin      date;
  v_venc     date;
  v_paso     int;
  v_plazos   date[] := '{}';
  v_plazo    date;
  v_hoy      date := (now() at time zone 'Europe/Madrid')::date;
  v_lineas   jsonb := '[]'::jsonb;    -- limpias: [{atleta_id, importe, periodicidad}]
  v_rec      jsonb;
  v_at       uuid;
  v_imp      numeric;
  v_a        public.atletas;
  v_email    text;
  v_nombre   text;
  v_lote     uuid := gen_random_uuid();
  v_lotes    uuid[] := '{}';
  v_r        jsonb;
  v_id       uuid;
  v_creados  int := 0;
  v_omit     int := 0;
  v_omit_det jsonb := '[]'::jsonb;
  v_total    numeric := 0;
  v_cuotas   uuid[] := '{}';
  v_pagos    uuid[] := '{}';
  v_mpago    text;
  v_periodo  text;
  v_cuenta_ok boolean;
  v_n        int;
  i          int;
begin
  if not public.cobro_asistente_puede() then
    raise exception 'Solo administración, tesorería o contabilidad pueden crear cobros.' using errcode = '42501';
  end if;

  -- --- Qué ---
  if v_concepto = '' then raise exception 'Falta el concepto.' using errcode = 'P0001'; end if;
  if length(v_concepto) > 120 then raise exception 'El concepto es demasiado largo (máx. 120).' using errcode = 'P0001'; end if;
  if v_frec not in ('unica', 'mensual', 'trimestral', 'anual') then
    raise exception 'Cada cuánto: una vez, mensual, trimestral o anual.' using errcode = 'P0001';
  end if;
  if v_metodo not in ('tarjeta', 'sepa', 'remesa', 'efectivo') then
    raise exception 'Cómo se paga: tarjeta, domiciliación SEPA, remesa de Isa o efectivo.' using errcode = 'P0001';
  end if;
  if v_frec = 'unica' and v_metodo = 'sepa' then
    raise exception 'Un cobro de una sola vez no va por domiciliación SEPA de Stripe: elige tarjeta, remesa de Isa o efectivo.' using errcode = 'P0001';
  end if;

  -- --- Cuándo ---
  begin
    v_inicio := to_date(coalesce(p->>'inicio', '') || '-01', 'YYYY-MM-DD');
  exception when others then v_inicio := null;
  end;
  if v_inicio is null or (p->>'inicio') !~ '^\d{4}-(0[1-9]|1[0-2])$' then
    raise exception 'Falta el mes de inicio.' using errcode = 'P0001';
  end if;
  if v_inicio < date_trunc('month', v_hoy)::date - interval '12 months'
     or v_inicio > date_trunc('month', v_hoy)::date + interval '24 months' then
    raise exception 'El mes de inicio está demasiado lejos.' using errcode = 'P0001';
  end if;

  if v_frec = 'unica' then
    v_venc := nullif(p->>'vencimiento', '')::date;
    v_plazos := array[v_inicio];
  else
    v_fin := nullif(p->>'fin', '')::date;
    if v_fin is null then raise exception 'Falta la fecha de fin (la cuota se para sola ese día).' using errcode = 'P0001'; end if;
    if v_fin < v_inicio then raise exception 'La fecha de fin es anterior al mes de inicio.' using errcode = 'P0001'; end if;
    if v_fin > v_inicio + interval '3 years' then raise exception 'Como mucho, 3 años de cuota.' using errcode = 'P0001'; end if;
    if v_metodo in ('sepa', 'tarjeta') and v_fin < v_hoy then
      raise exception 'La fecha de fin ya ha pasado.' using errcode = 'P0001';
    end if;
    -- Con Stripe la cuota arranca al pagar (o el día 1 del mes de inicio si es
    -- futuro): un mes pasado no se puede «recuperar», y contaría cobros de más.
    if v_metodo in ('sepa', 'tarjeta') and v_inicio < date_trunc('month', v_hoy)::date then
      raise exception 'Con tarjeta o SEPA el mes de inicio no puede ser un mes pasado.' using errcode = 'P0001';
    end if;
    v_paso := case v_frec when 'mensual' then 1 when 'trimestral' then 3 else 12 end;
    v_plazo := v_inicio;
    while v_plazo <= v_fin loop
      v_plazos := v_plazos || v_plazo;
      v_plazo := (v_plazo + make_interval(months => v_paso))::date;
    end loop;
    if array_length(v_plazos, 1) > 36 then raise exception 'Demasiados plazos (máx. 36).' using errcode = 'P0001'; end if;
  end if;
  v_dia := least(greatest(coalesce(nullif(p->>'dia_cargo', '')::int, 5), 1), 28);

  -- --- Cuenta: solo la remesa la lleva (es lo que la esconde de la familia y
  --     la manda a Isa). Tarjeta NUNCA: con cuenta, el recibo no se podría pagar.
  if v_metodo = 'remesa' then
    if v_cuenta is null or v_cuenta not in ('escuela', 'club') then
      raise exception 'Para la remesa de Isa hay que decir la cuenta: escuela o club.' using errcode = 'P0001';
    end if;
  else
    v_cuenta := null;
  end if;

  -- --- A quién: líneas limpias ---
  if p->'lineas' is null or jsonb_typeof(p->'lineas') <> 'array' or jsonb_array_length(p->'lineas') = 0 then
    raise exception 'No hay nadie a quien cobrar.' using errcode = 'P0001';
  end if;
  if jsonb_array_length(p->'lineas') > 600 then
    raise exception 'Demasiadas personas de una vez (máx. 600).' using errcode = 'P0001';
  end if;
  for v_rec in select * from jsonb_array_elements(p->'lineas') loop
    begin
      v_at  := nullif(v_rec->>'atleta_id', '')::uuid;
      v_imp := round(nullif(v_rec->>'importe', '')::numeric, 2);
    exception when others then
      raise exception 'Hay una línea con datos no válidos.' using errcode = 'P0001';
    end;
    if v_at is null then raise exception 'Hay una línea sin persona.' using errcode = 'P0001'; end if;
    if v_imp is null or v_imp <= 0 then raise exception 'Hay una persona sin importe.' using errcode = 'P0001'; end if;
    if v_imp > 5000 then raise exception 'Importe demasiado alto (% €): revísalo.', v_imp using errcode = 'P0001'; end if;
    if v_lineas @> jsonb_build_array(jsonb_build_object('atleta_id', v_at)) then
      raise exception 'Una persona está repetida.' using errcode = 'P0001';
    end if;
    v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
      'atleta_id', v_at, 'importe', v_imp,
      'periodicidad', case v_frec when 'unica' then 'unico' else v_frec end));
  end loop;

  if (select count(*) from jsonb_array_elements(v_lineas) l
        join public.atletas a on a.id = (l->>'atleta_id')::uuid
       where coalesce(a.estado, 'activo') <> 'baja') <> jsonb_array_length(v_lineas) then
    raise exception 'Alguna persona no existe o está de baja.' using errcode = 'P0001';
  end if;

  -- =========================================================================
  -- A · RECIBOS en `pagos` (una vez, o recurrente por remesa / efectivo)
  -- =========================================================================
  if v_frec = 'unica' or v_metodo in ('remesa', 'efectivo') then
    v_mpago := case v_metodo when 'remesa' then 'domiciliado' when 'efectivo' then 'efectivo' else 'tarjeta' end;
    i := 0;
    foreach v_plazo in array v_plazos loop
      i := i + 1;
      v_periodo := to_char(v_plazo, 'YYYY-MM');
      if v_simular then
        -- Misma regla de duplicados que cobro_grupo_lineas.
        for v_rec in select * from jsonb_array_elements(v_lineas) loop
          if exists (select 1 from public.pagos pg
                      where pg.atleta_id = (v_rec->>'atleta_id')::uuid and pg.anulado = false
                        and lower(btrim(pg.concepto)) = lower(v_concepto)
                        and coalesce(pg.periodo, '') = v_periodo) then
            v_omit := v_omit + 1;
            v_omit_det := v_omit_det || jsonb_build_array(jsonb_build_object(
              'atleta_id', v_rec->>'atleta_id', 'periodo', v_periodo, 'motivo', 'ya tiene ese recibo'));
          else
            v_creados := v_creados + 1;
            v_total := v_total + (v_rec->>'importe')::numeric;
          end if;
        end loop;
      else
        v_r := public.cobro_grupo_lineas(
          v_concepto, v_periodo,
          case when v_frec = 'unica' then v_venc
               else make_date(extract(year from v_plazo)::int, extract(month from v_plazo)::int, v_dia) end,
          v_cuenta, v_mpago, v_lineas,
          v_guardar and i = 1,
          v_notas);
        v_creados := v_creados + coalesce((v_r->>'creados')::int, 0);
        v_omit    := v_omit + coalesce((v_r->>'omitidos')::int, 0);
        v_total   := v_total + coalesce((v_r->>'total')::numeric, 0);
        if (v_r->>'lote') is not null then v_lotes := v_lotes || (v_r->>'lote')::uuid; end if;
      end if;
    end loop;
    if not v_simular then
      select coalesce(array_agg(pg.id), '{}') into v_pagos from public.pagos pg where pg.lote = any(v_lotes);
    end if;

    return jsonb_build_object(
      'modo', 'recibos', 'simulado', v_simular,
      'lote', case when array_length(v_lotes, 1) = 1 then v_lotes[1] end, 'lotes', to_jsonb(v_lotes),
      'creados', v_creados, 'omitidos', v_omit, 'omitidos_detalle', v_omit_det,
      'total', round(v_total, 2), 'plazos', (select jsonb_agg(to_char(x, 'YYYY-MM')) from unnest(v_plazos) x),
      'pagos', to_jsonb(v_pagos), 'cuotas', '[]'::jsonb,
      'metodo_pagos', v_mpago, 'cuenta', v_cuenta);
  end if;

  -- =========================================================================
  -- B · CUOTA RECURRENTE por Stripe (SEPA o tarjeta) → cuotas_entreno
  -- =========================================================================
  v_n := array_length(v_plazos, 1);
  for v_rec in select * from jsonb_array_elements(v_lineas) loop
    select * into v_a from public.atletas where id = (v_rec->>'atleta_id')::uuid;
    v_nombre := btrim(coalesce(v_a.nombre, '') || ' ' || coalesce(v_a.apellidos, ''));
    v_email := coalesce(nullif(btrim(v_a.email), ''), nullif(btrim(v_a.email_tutor), ''),
                        (select nullif(btrim(pf.email), '') from public.perfiles pf
                          where pf.id = coalesce(v_a.perfil_id, v_a.perfil_padre_id)));
    if v_email is null then
      v_omit := v_omit + 1;
      v_omit_det := v_omit_det || jsonb_build_array(jsonb_build_object(
        'atleta_id', v_a.id, 'persona', v_nombre, 'motivo', 'sin correo en su ficha (no le llegaría el enlace)'));
      continue;
    end if;
    if exists (select 1 from public.cuotas_entreno q
                where q.atleta_id = v_a.id and q.suscripcion_estado <> 'cancelada'
                  and lower(btrim(q.concepto)) = lower(v_concepto)) then
      v_omit := v_omit + 1;
      v_omit_det := v_omit_det || jsonb_build_array(jsonb_build_object(
        'atleta_id', v_a.id, 'persona', v_nombre, 'motivo', 'ya tiene esa cuota'));
      continue;
    end if;

    v_creados := v_creados + 1;
    v_total := v_total + (v_rec->>'importe')::numeric * v_n;
    if v_simular then continue; end if;

    insert into public.cuotas_entreno
      (atleta_id, perfil_id, nombre, apellidos, email, concepto, importe_cent,
       periodicidad, inicio, fin, metodo, origen, lote, creado_por, token, cobro_abierto, nota)
    values
      (v_a.id, coalesce(v_a.perfil_id, v_a.perfil_padre_id), v_a.nombre, v_a.apellidos, v_email,
       v_concepto, round((v_rec->>'importe')::numeric * 100)::int,
       v_frec, v_inicio, v_fin, v_metodo, 'asistente', v_lote, public.mi_perfil_id(),
       replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
       true, v_notas)
    returning id into v_id;
    v_cuotas := v_cuotas || v_id;

    if v_guardar then
      update public.atletas set cuota_importe = (v_rec->>'importe')::numeric, cuota_periodicidad = v_frec
       where id = v_a.id;
    end if;
  end loop;

  return jsonb_build_object(
    'modo', 'cuotas', 'simulado', v_simular, 'lote', case when v_simular then null else v_lote end,
    'creados', v_creados, 'omitidos', v_omit, 'omitidos_detalle', v_omit_det,
    'total', round(v_total, 2), 'plazos', (select jsonb_agg(to_char(x, 'YYYY-MM')) from unnest(v_plazos) x),
    'pagos', '[]'::jsonb, 'cuotas', to_jsonb(v_cuotas), 'metodo', v_metodo);
end;
$$;
revoke all on function public.cobro_asistente_crear(jsonb) from public, anon;
grant execute on function public.cobro_asistente_crear(jsonb) to authenticated, service_role;

-- ===========================================================================
-- 6 · Pública (sin sesión): lo que /entreno/cuota/?t=… necesita para explicar
--     la cuota. Por el token (64 hex, imposible de adivinar). Nada personal.
--     El importe es el que se va a cobrar (con la comisión si el club la
--     repercute y es con tarjeta: la misma regla que entreno-pagar).
-- ===========================================================================
create or replace function public.cuota_entreno_publica(p_token text)
returns jsonb
language sql stable security definer
set search_path to 'public'
as $$
  select jsonb_build_object(
           'concepto', q.concepto,
           'importe', round(case when q.metodo = 'tarjeta' and coalesce(c.repercutir_comision, false)
                                 then public.pagos_con_comision(q.importe_cent)
                                 else q.importe_cent end / 100.0, 2),
           'periodicidad', q.periodicidad,
           'inicio', q.inicio,
           'fin', q.fin,
           'metodo', q.metodo)
    from public.cuotas_entreno q
    left join public.pagos_config c on c.id = 1
   where length(coalesce(p_token, '')) >= 40
     and q.token = p_token
   limit 1;
$$;
revoke all on function public.cuota_entreno_publica(text) from public;
grant execute on function public.cuota_entreno_publica(text) to anon, authenticated, service_role;

-- ===========================================================================
-- 7 · mi_cuota_entreno(): + periodicidad y metodo (cambia el tipo de vuelta)
-- ===========================================================================
drop function if exists public.mi_cuota_entreno();
create function public.mi_cuota_entreno()
returns table(token text, importe_cent integer, concepto text, suscripcion_estado text,
              periodicidad text, metodo text)
language sql stable security definer
set search_path to 'public'
as $function$
  select case when ce.suscripcion_estado = 'en_camino' then null else ce.token end,
         ce.importe_cent, ce.concepto, ce.suscripcion_estado,
         ce.periodicidad, ce.metodo
  from public.cuotas_entreno ce
  where ce.perfil_id = public.mi_perfil_id()
    and ce.cobro_abierto
    and coalesce(ce.suscripcion_estado, '') <> 'activa'
  order by ce.created_at desc
  limit 1;
$function$;
revoke all on function public.mi_cuota_entreno() from public, anon;
grant execute on function public.mi_cuota_entreno() to authenticated, service_role;


-- ===========================================================================
-- 8 · dinero_movimientos(): copia de la versión VIVA (15-oct) con el único
--     cambio de la cuota con tarjeta (líneas marcadas «380»).
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.dinero_movimientos()
 RETURNS TABLE(origen text, ref_id uuid, persona text, atleta_id uuid, concepto text, importe numeric, estado text, cobrado_en date, fecha timestamp with time zone, metodo text, importado boolean, aproximado boolean, detalle text, enlace text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.dinero_puede_ver() then
    raise exception 'Solo administración, tesorería o contabilidad ven el dinero.' using errcode = '42501';
  end if;

  return query
  with
  nom as (
    select a.id, trim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')) as n from public.atletas a
  ),
  cfg as (select coalesce((select precio_alta_socio_cent from public.pagos_config where id = 1), 3500) as alta_cent),

  -- A · Recibos del libro de cobros (y las filas que deja Stripe: stripe:in_…)
  r as (
    select
      case when p.notas like 'stripe:in_%' and p.concepto ilike '%cubo%' then 'cubo'
           when p.notas like 'stripe:in_%' then 'entreno'
           else 'recibo' end                                         as origen,
      p.id                                                           as ref_id,
      coalesce(nullif(nom.n,''), 'Sin persona')                      as persona,
      p.atleta_id,
      p.concepto,
      p.importe::numeric                                             as importe,
      case when p.estado = 'pagado' then 'pagado'
           when p.estado = 'impagado' then 'fallido'
           when p.metodo = 'domiciliado' or coalesce(p.notas,'') ilike '%remesa%'
                or p.concepto ilike '%municipal%' then 'remesa'   -- las municipales también las pasa Isa (Andrés, 13-oct)
           else 'pendiente' end                                      as estado,
      case when p.estado = 'pagado' then p.fecha_pago end            as cobrado_en,
      coalesce(p.fecha_pago::timestamptz, p.fecha_vencimiento::timestamptz, p.created_at) as fecha,
      p.metodo,
      (p.estado = 'pagado' and p.metodo is null and coalesce(p.notas,'') not like 'stripe:%') as importado,
      false                                                          as aproximado,
      case when p.estado = 'pagado' and p.metodo is null and coalesce(p.notas,'') not like 'stripe:%'
             then 'Registro sin forma de cobro (importación o marcado a mano)'
           when p.notas like 'stripe:in_%' then 'Cobrado por Stripe'
           when p.estado = 'impagado' then 'Impagado / devuelto'
           when p.estado = 'pendiente' and p.fecha_vencimiento is not null
             then 'Vence el ' || to_char(p.fecha_vencimiento, 'DD/MM/YYYY')
           else nullif(p.notas,'') end                               as detalle,
      case when p.notas like 'stripe:in_%' and p.concepto ilike '%cubo%' then 'admin/cubo-altas/'
           when p.notas like 'stripe:in_%' then 'admin/cuotas-entreno/'
           else 'admin/cobros/' end                                  as enlace
    from public.pagos p
    left join nom on nom.id = p.atleta_id
    where not p.anulado
  ),

  -- B · El Cubo: cuota mensual (suscripción de Stripe)
  cu as (
    select
      'cubo'::text, ca.id,
      trim(ca.nombre || ' ' || ca.apellidos),
      ca.atleta_id,
      case when ca.suscripcion_estado = 'impago' then 'Cuota El Cubo · recibo fallido'
           else 'Cuota El Cubo · primer pago' end,
      case when ca.suscripcion_estado = 'impago' then ca.precio_mes::numeric
           else coalesce(ca.primer_pago_cent / 100.0, ca.precio_mes::numeric) end,
      case when ca.suscripcion_estado = 'impago' then 'fallido' else 'pendiente' end,
      null::date,
      coalesce(ca.cobro_avisado_en, ca.created_at),
      'tarjeta'::text,
      false, false,
      case when ca.suscripcion_estado = 'impago' then 'Stripe no pudo cobrar el recibo mensual'
           when ca.cobro_avisado_en is not null
             then 'Cobro abierto, sin pagar · avisado el ' || to_char(ca.cobro_avisado_en at time zone 'Europe/Madrid', 'DD/MM')
           else 'Cobro abierto, sin pagar' end,
      'admin/cubo-altas/'::text
    from public.cubo_altas ca
    where ca.estado = 'aprobada'
      and not coalesce(ca.lista_espera, false)
      and ca.pago_externo is null
      and ( ca.suscripcion_estado = 'impago'
         or (coalesce(ca.cobro_abierto, false) and ca.suscripcion_estado is null) )
  ),
  -- B2 · El Cubo: último cobro de Stripe que aún no tiene su fila en `pagos`
  cu_ult as (
    select
      'cubo'::text, ca.id,
      trim(ca.nombre || ' ' || ca.apellidos),
      ca.atleta_id,
      'Cuota El Cubo · ' || (array['enero','febrero','marzo','abril','mayo','junio','julio','agosto',
                                  'septiembre','octubre','noviembre','diciembre'])
                                 [extract(month from ca.ultimo_cobro at time zone 'Europe/Madrid')::int]
                           || ' ' || extract(year from ca.ultimo_cobro at time zone 'Europe/Madrid')::int,
      x.imp,
      'pagado'::text,
      (ca.ultimo_cobro at time zone 'Europe/Madrid')::date,
      ca.ultimo_cobro,
      'tarjeta'::text,
      false, true,
      'Último cobro según Stripe (importe deducido)'::text,
      'admin/cubo-altas/'::text
    from public.cubo_altas ca
    cross join lateral (
      select case
        when extract(day from ca.ultimo_cobro at time zone 'Europe/Madrid') = 5 then ca.precio_mes::numeric
        when ca.primer_pago_cent is not null then ca.primer_pago_cent / 100.0
        else null end as imp
    ) x
    where ca.ultimo_cobro is not null
      and x.imp is not null
      and not exists (
        select 1 from public.pagos p
         where p.notas like 'stripe:in_%'
           and p.atleta_id = ca.atleta_id
           and p.fecha_pago = (ca.ultimo_cobro at time zone 'Europe/Madrid')::date
           and not p.anulado)
  ),
  -- C · Cobros puntuales del Cubo («ponle un pago»)
  cc as (
    select
      'cubo'::text, c.id,
      coalesce(trim(ca.nombre || ' ' || ca.apellidos), 'Sin persona'),
      ca.atleta_id,
      c.concepto,
      c.importe_cent / 100.0,
      case when c.estado = 'pagado' then 'pagado' else 'pendiente' end,
      case when c.estado = 'pagado' then (c.pagado_en at time zone 'Europe/Madrid')::date end,
      coalesce(c.pagado_en, c.created_at),
      'tarjeta'::text,
      false, false,
      'Cobro puntual del Cubo'::text,
      'admin/cubo-altas/'::text
    from public.cubo_cobros c
    left join public.cubo_altas ca on ca.id = c.alta_id
    where c.estado in ('pendiente','pagado')
  ),
  -- D · Cuotas de entreno (suscripción SEPA trimestral)
  ce as (
    select
      'entreno'::text, q.id,
      trim(coalesce(q.nombre,'') || ' ' || coalesce(q.apellidos,'')),
      q.atleta_id,
      q.concepto,
      q.importe_cent / 100.0,
      case q.suscripcion_estado when 'en_camino' then 'en_camino'
                                when 'impago'    then 'fallido'
                                else 'pendiente' end,
      null::date,
      coalesce(q.factura_fecha, q.created_at),
      case when q.metodo = 'tarjeta' then 'tarjeta' else 'domiciliado' end,   -- 380
      false, false,
      case q.suscripcion_estado
        when 'en_camino' then 'Mandato SEPA firmado; el primer adeudo tarda ~5 días hábiles (hasta 14)'
        when 'impago'    then case when q.metodo = 'tarjeta' then 'El cobro con tarjeta falló'      -- 380
                               else 'El adeudo falló o se devolvió' end
        else case when q.metodo = 'tarjeta' then 'Sin pagar: aún no ha metido su tarjeta'          -- 380
                  else 'Sin domiciliar: aún no ha metido su IBAN' end end,
      'admin/cuotas-entreno/'::text
    from public.cuotas_entreno q
    where q.suscripcion_estado in ('pendiente','en_camino','impago')
      and (q.cobro_abierto or q.suscripcion_estado <> 'pendiente')
  ),
  -- E · Altas de socio (35 € por SEPA en la pasarela)
  so as (
    select
      'alta_socio'::text, a.id,
      trim(a.nombre || ' ' || coalesce(a.apellidos,'')),
      a.atleta_id,
      'Alta de socio · ' || a.referencia,
      coalesce(po.importe_centimos, (select alta_cent from cfg)) / 100.0,
      case a.pago_estado when 'pagado' then 'pagado'
                         when 'en_camino' then 'en_camino'
                         when 'fallido' then 'fallido'
                         when 'devuelto' then 'fallido'
                         else 'pendiente' end,
      case when a.pago_estado = 'pagado'
           then (coalesce(po.pagado_en, a.pagado_en) at time zone 'Europe/Madrid')::date end,
      coalesce(case when a.pago_estado = 'pagado' then coalesce(po.pagado_en, a.pagado_en) end,
               a.mandato_firmado_en, a.created_at),
      coalesce(po.metadatos ->> 'metodo', 'domiciliado'),
      false, false,
      case a.pago_estado
        when 'en_camino' then 'Mandato SEPA firmado el ' || to_char(a.mandato_firmado_en at time zone 'Europe/Madrid', 'DD/MM')
                              || '; el primer adeudo tarda ~5 días hábiles (hasta 14)'
        when 'fallido'   then 'El adeudo SEPA falló'
        when 'devuelto'  then 'El adeudo SEPA se devolvió'
        when 'pagado'    then nullif(po.metadatos ->> 'nota','')
        else case when a.stripe_session_id is not null then 'Empezó a pagar y no terminó' else 'Aún no ha pagado' end end,
      'admin/altas/?tipo=socio'::text
    from public.altas_socio a
    left join public.pagos_online po on po.referencia = 'socio-' || a.id::text
    where a.estado <> 'rechazada'
  ),
  -- F · Pagos online sueltos (tienda, bonos…). Los de recibo y alta de socio ya
  --     cuentan arriba (A y E): aquí no, para no contarlos dos veces.
  po as (
    select
      case po.tipo when 'ropa' then 'tienda' when 'bono' then 'bono' else 'online' end,
      po.id,
      coalesce(nullif(nom.n,''), nullif(trim(coalesce(pf.nombre,'') || ' ' || coalesce(pf.apellidos,'')),''), 'Sin persona'),
      po.atleta_id,
      po.concepto,
      po.importe_centimos / 100.0,
      case when po.estado = 'pagado' then 'pagado' else 'devuelto' end,
      case when po.estado = 'pagado' then (po.pagado_en at time zone 'Europe/Madrid')::date end,
      coalesce(po.pagado_en, po.creado_en),
      'tarjeta'::text,
      false, false,
      case po.estado when 'reembolsado' then 'Devuelto (reembolso)' when 'fallido' then 'El pago falló' else null end,
      case po.tipo when 'ropa' then 'admin/pedidos/' else 'admin/pagos-online/' end
    from public.pagos_online po
    left join nom on nom.id = po.atleta_id
    left join public.perfiles pf on pf.id = po.perfil_id
    where po.tipo not in ('recibo','alta_socio')
      and po.estado in ('pagado','reembolsado')
  )
  select u.origen, u.ref_id, u.persona, u.atleta_id, u.concepto,
         round(u.importe, 2), u.estado, u.cobrado_en, u.fecha, u.metodo,
         u.importado, u.aproximado, u.detalle, u.enlace
    from (
            select * from r
  union all select * from cu
  union all select * from cu_ult
  union all select * from cc
  union all select * from ce
  union all select * from so
  union all select * from po
    ) u;
end;
$function$;

-- ===========================================================================
-- 9 · dinero_cuotas(): copia de la versión VIVA con metodo e inicio por persona.
-- ===========================================================================
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
    where q.suscripcion_estado <> 'cancelada'
       or q.ultimo_cobro >= v_m
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

-- (create or replace conserva los permisos de las dos de arriba)

commit;
