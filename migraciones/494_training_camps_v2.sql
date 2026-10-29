-- ===========================================================================
-- 494 · Training Camps v2 (tanda 1)
-- ---------------------------------------------------------------------------
--   · Ajustes: aforo de El Cubo (18 por defecto, editable: depende del tipo de
--     entrenamiento) y un interruptor propio de pagos online, APAGADO: mientras
--     esté apagado no se abre Stripe para ningún pago de concentraciones (el
--     Stripe del club está en real). Encenderlo es decisión de Andrés.
--   · Galería: cada foto o vídeo va a un hueco de la página (portada, estadio,
--     El Cubo o galería) para cambiarlos desde el panel sin tocar código.
--   · Formulario v2: horario conocido o «por concretar» (y por día), menores
--     (sí/no y cuántos, sin datos personales), subgrupos, uso simultáneo de
--     El Cubo, material concreto.
-- Lo público que se abre: solo camp_ajustes_publicos() (aforo y si hay pago online).
-- ===========================================================================
begin;

alter table public.camp_config
  add column cubo_aforo int not null default 18 check (cubo_aforo between 1 and 200),
  add column pagos_online boolean not null default false;
comment on column public.camp_config.pagos_online is 'Training Camps: si se puede pagar con tarjeta desde el enlace. Apagado = no se abre Stripe (solo transferencia apuntada a mano).';

alter table public.camp_galeria
  add column lugar text not null default 'galeria' check (lugar in ('portada','estadio','cubo','galeria'));

alter table public.camp_solicitudes
  add column horario_modo text check (horario_modo in ('known','tba')),
  add column horario_igual boolean,
  add column duracion int check (duracion between 15 and 300),
  add column horario_dias jsonb check (horario_dias is null or jsonb_typeof(horario_dias) = 'object'),
  add column menores text check (menores in ('yes','no')),
  add column menores_n int check (menores_n between 0 and 1000),
  add column subgrupos jsonb not null default '[]' check (jsonb_typeof(subgrupos) = 'array'),
  add column gimnasio_simultaneos int check (gimnasio_simultaneos between 0 and 500),
  add column gimnasio_sesiones int check (gimnasio_sesiones between 0 and 50),
  add column material_items text[] not null default '{}';

-- La página pública solo necesita esto de los ajustes.
create or replace function public.camp_ajustes_publicos() returns jsonb
language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object('cubo_aforo', cubo_aforo, 'pagos_online', pagos_online) from public.camp_config where id = 1
$$;

create or replace function public.camp_solicitud_crear(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare s public.camp_solicitudes;
begin
  insert into public.camp_solicitudes (origen, idioma, entidad, pais, contacto, email, telefono, idioma_com, idioma_com_otro,
    n_atletas, n_entrenadores, modalidades, modalidades_otro, llegada, salida, fechas_flexibles, dias, horario, sesiones_dia,
    dividir, grupos, grupos_detalle, instalaciones, instalaciones_otro, material, gimnasio, gimnasio_detalle, servicios,
    necesidades, comentarios, confirma_datos, privacidad_en,
    horario_modo, horario_igual, duracion, horario_dias, menores, menores_n, subgrupos, gimnasio_simultaneos, gimnasio_sesiones, material_items)
  values ('web', coalesce(nullif(p->>'lang', ''), 'en'), p->>'entidad', nullif(p->>'pais', ''), p->>'contacto', lower(p->>'email'),
    nullif(p->>'telefono', ''), nullif(p->>'idioma_com', ''), nullif(p->>'idioma_com_otro', ''),
    nullif(p->>'n_atletas', '')::int, nullif(p->>'n_entrenadores', '')::int,
    coalesce(array(select jsonb_array_elements_text(p->'modalidades')), '{}'), nullif(p->>'modalidades_otro', ''),
    nullif(p->>'llegada', '')::date, nullif(p->>'salida', '')::date, coalesce((p->>'fechas_flexibles')::boolean, false),
    coalesce(array(select jsonb_array_elements_text(p->'dias')), '{}'), coalesce(array(select jsonb_array_elements_text(p->'horario')), '{}'),
    nullif(p->>'sesiones_dia', '')::int, nullif(p->>'dividir', ''), nullif(p->>'grupos', '')::int, nullif(p->>'grupos_detalle', ''),
    coalesce(array(select jsonb_array_elements_text(p->'instalaciones')), '{}'), nullif(p->>'instalaciones_otro', ''),
    nullif(p->>'material', ''), nullif(p->>'gimnasio', ''), nullif(p->>'gimnasio_detalle', ''), coalesce(p->'servicios', '{}'),
    nullif(p->>'necesidades', ''), nullif(p->>'comentarios', ''), true, now(),
    nullif(p->>'horario_modo', ''), (p->>'horario_igual')::boolean, nullif(p->>'duracion', '')::int,
    case when jsonb_typeof(p->'horario_dias') = 'object' then p->'horario_dias' end,
    nullif(p->>'menores', ''), nullif(p->>'menores_n', '')::int,
    case when jsonb_typeof(p->'subgrupos') = 'array' then p->'subgrupos' else '[]' end,
    nullif(p->>'gimnasio_simultaneos', '')::int, nullif(p->>'gimnasio_sesiones', '')::int,
    coalesce(array(select jsonb_array_elements_text(p->'material_items')), '{}'))
  returning * into s;
  perform public.camp_tarea_auto(s.id, 'responder', 'Contestar a la solicitud y estudiar disponibilidad', public.camp_hoy() + 2);
  return jsonb_build_object('id', s.id, 'codigo', s.codigo);
end $$;

-- El enlace del cliente sabe si puede pagar con tarjeta.
create or replace function public.camp_propuesta_publica(p_token text) returns jsonb
language sql stable security definer set search_path to 'public' as $$
  select public.camp_propuesta_json(id) || jsonb_build_object('pagos_online', (select pagos_online from public.camp_config where id = 1))
    from public.camp_presupuestos where length(coalesce(p_token, '')) >= 40 and token = p_token
$$;

create or replace function public.camp_propuesta_admin(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  return public.camp_propuesta_json(p_id) || jsonb_build_object('pagos_online', (select pagos_online from public.camp_config where id = 1));
end $$;

create or replace function public.camp_pago_publico(p_token text) returns jsonb
language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object('tipo', cp.tipo, 'concepto', cp.concepto, 'importe', cp.importe, 'vence', cp.vence,
    'anulado', cp.anulado_en is not null, 'pagado', coalesce(p.estado = 'pagado', false), 'fecha_pago', p.fecha_pago,
    'codigo', s.codigo, 'entidad', s.entidad, 'email', s.email, 'idioma', coalesce(e.idioma, s.idioma),
    'presupuesto', e.numero, 'propuesta_token', e.token, 'total', e.total, 'llegada', s.llegada, 'salida', s.salida,
    'cancelado', s.estado = 'cancelada', 'emisor', g.emisor, 'pagos_online', g.pagos_online)
  from public.camp_pagos cp
  join public.camp_solicitudes s on s.id = cp.solicitud_id
  left join public.camp_presupuestos e on e.id = cp.presupuesto_id
  left join public.pagos p on p.id = cp.pago_id
  cross join public.camp_config g
  where length(coalesce(p_token, '')) >= 40 and cp.token = p_token and g.id = 1
$$;

-- Ajustes: aforo y pagos online (el interruptor solo lo cambia un admin).
create or replace function public.camp_config_guardar(p jsonb) returns public.camp_config
language plpgsql security definer set search_path to 'public' as $$
declare g public.camp_config;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  update public.camp_config set
    senal_tipo = coalesce(nullif(p->>'senal_tipo', ''), senal_tipo),
    senal_valor = coalesce(nullif(p->>'senal_valor', '')::numeric, senal_valor),
    senal_dias_pago = coalesce(nullif(p->>'senal_dias_pago', '')::int, senal_dias_pago),
    saldo_dias_antes = coalesce(nullif(p->>'saldo_dias_antes', '')::int, saldo_dias_antes),
    validez_dias = coalesce(nullif(p->>'validez_dias', '')::int, validez_dias),
    impuestos = coalesce(p->'impuestos', impuestos),
    impuesto_defecto = coalesce(nullif(p->>'impuesto_defecto', '')::numeric, impuesto_defecto),
    nota_impuestos_en = case when p ? 'nota_impuestos_en' then nullif(btrim(p->>'nota_impuestos_en'), '') else nota_impuestos_en end,
    nota_impuestos_es = case when p ? 'nota_impuestos_es' then nullif(btrim(p->>'nota_impuestos_es'), '') else nota_impuestos_es end,
    formas_pago_en = coalesce(nullif(btrim(p->>'formas_pago_en'), ''), formas_pago_en),
    formas_pago_es = coalesce(nullif(btrim(p->>'formas_pago_es'), ''), formas_pago_es),
    emisor = case when jsonb_typeof(p->'emisor') = 'object' then emisor || (p->'emisor') else emisor end,
    correo_avisos = case when p ? 'correo_avisos' then nullif(btrim(p->>'correo_avisos'), '') else correo_avisos end,
    revisado = coalesce((p->>'revisado')::boolean, revisado),
    cubo_aforo = coalesce(nullif(p->>'cubo_aforo', '')::int, cubo_aforo),
    pagos_online = coalesce((p->>'pagos_online')::boolean, pagos_online),
    actualizado_en = now(), actualizado_por = auth.uid()
  where id = 1 returning * into g;
  if g.senal_tipo = 'porcentaje' and g.senal_valor > 100 then raise exception 'La señal no puede pasar del 100 %%.'; end if;
  return g;
end $$;

revoke execute on function public.camp_ajustes_publicos() from public;
grant execute on function public.camp_ajustes_publicos() to anon, authenticated;

commit;
