-- 320 · Festivos y cierres: UNA sola regla para saber si un día se cae.
--
-- Auditoría 13-oct-2026: había cuatro comprobaciones distintas sobre
-- calendario_excepciones (hay_excepcion, dia_cancelado, natacion_dia_cancelado
-- y una consulta propia dentro de calendario_club) y cada una decía una cosa.
-- Además, el «no voy» del máster de natación daba +1 aunque ese día fuera
-- festivo (4 bonos de más: avisaron 4-5 oct, el festivo se creó el 6 oct).
--
-- ┌─ LA REGLA (única; la aplica _excepcion_aplica) ─────────────────────────┐
-- │ Una excepción ACTIVA cuyo rango [fecha, fecha_fin] cubre el día se cae  │
-- │ para una actividad (sección, grupo, lugar) si se cumplen LAS TRES:      │
-- │  1. grupo_id   NULL (todos los grupos)  o  = el grupo de la actividad.  │
-- │  2. seccion    NULL (todo el club)      o  = la sección de la actividad │
-- │                o 'natacion' cuando la actividad es 'escuela-natacion'   │
-- │                (la piscina cerrada cierra también la escuela; al revés  │
-- │                NO: un cierre de la escuela de natación no quita el      │
-- │                máster).                                                 │
-- │  3. lugar      NULL (en todas partes)   o  el lugar de la actividad lo  │
-- │                contiene (sin tildes ni mayúsculas): «Joaquín Villar»    │
-- │                cae en «Estadio Joaquín Villar».                         │
-- │ Si quien pregunta no sabe el lugar (p_lugar NULL), excepcion_del_dia    │
-- │ usa los lugares del horario de ese grupo/sección (grupo_horarios).      │
-- │ hay_excepcion conserva su comportamiento: sin lugar = no cae lo que     │
-- │ está limitado a un lugar.                                               │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- Quién la usa:
--   · hay_excepcion(fecha, grupo, seccion, lugar) → boolean (generador de
--     entrenos, entrenos_previstos, natacion_master_disponibles). Misma firma.
--   · excepcion_del_dia(fecha, seccion, grupo?, lugar?) → jsonb con el detalle
--     (cancelado, motivo, tipo, id, seccion, alcance). LA CANÓNICA para un día.
--   · excepciones_rango(desde, hasta) → filas (una por día y excepción) para
--     que las pantallas pinten un rango de una vez; el front aplica la misma
--     regla con assets/js/festivos.js (espejo de _excepcion_aplica).
--   · dia_cancelado(fecha, seccion) y natacion_dia_cancelado(fecha) delegan
--     en excepcion_del_dia (misma firma y mismas claves de siempre).
--   · calendario_club NO se toca aquí (lo lleva el agente de natación): debe
--     pasar a usar _excepcion_aplica / excepcion_del_dia.
--
-- Bonos: natacion_master_no_voy ya no da +1 si el día está cancelado. Los
-- bonos YA dados en días que luego fueron festivo NO se tocan: los revisa
-- Mario con herramientas/festivos_revisar_bonos.sql.

-- ─────────────────────────────────────────────────────────────────────────
-- 1 · El núcleo: ¿esta excepción cae sobre esta actividad?
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public._excepcion_aplica(
  p_e_seccion text, p_e_grupo uuid, p_e_lugar text,
  p_seccion text, p_grupo uuid, p_lugar text)
returns boolean
language sql immutable
set search_path to 'public'
as $function$
  select (p_e_grupo is null or p_e_grupo = p_grupo)
     and (p_e_seccion is null
          or p_e_seccion = p_seccion
          or (p_e_seccion = 'natacion' and p_seccion = 'escuela-natacion'))
     and (p_e_lugar is null or btrim(p_e_lugar) = ''
          or lower(public.apo_sin_tildes(coalesce(p_lugar, ''))) like
             '%' || lower(public.apo_sin_tildes(btrim(p_e_lugar))) || '%');
$function$;

comment on function public._excepcion_aplica(text, uuid, text, text, uuid, text) is
  'Regla única de festivos/cierres (mig 320). Espejo en assets/js/festivos.js. '
  'grupo NULL o igual · seccion NULL, igual, o natacion→escuela-natacion · lugar NULL o contenido.';

-- Lugares conocidos de un grupo (o de una sección entera) según su horario.
create or replace function public._excepcion_lugares(p_seccion text, p_grupo uuid)
returns text
language sql stable security definer
set search_path to 'public'
as $function$
  select string_agg(distinct btrim(h.lugar), ' | ')
    from public.grupo_horarios h
    join public.grupos g on g.id = h.grupo_id
   where h.activo and coalesce(g.activo, true)
     and nullif(btrim(h.lugar), '') is not null
     and case when p_grupo is not null then g.id = p_grupo
              else g.seccion = p_seccion end;
$function$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2 · hay_excepcion: misma firma, ahora con la regla única
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.hay_excepcion(p_fecha date, p_grupo uuid, p_seccion text, p_lugar text)
returns boolean
language sql stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.calendario_excepciones e
     where e.activa
       and p_fecha between e.fecha and coalesce(e.fecha_fin, e.fecha)
       and public._excepcion_aplica(e.seccion, e.grupo_id, e.lugar,
                                    p_seccion, p_grupo, coalesce(p_lugar, ''))
  );
$function$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3 · excepcion_del_dia: LA canónica con detalle
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.excepcion_del_dia(
  p_fecha date, p_seccion text, p_grupo uuid default null, p_lugar text default null)
returns jsonb
language sql stable security definer
set search_path to 'public'
as $function$
  with donde as (
    select coalesce(p_lugar, public._excepcion_lugares(p_seccion, p_grupo), '') as lugar
  )
  select coalesce(
    (select jsonb_build_object(
              'cancelado', true,
              'motivo',    coalesce(nullif(btrim(e.motivo), ''), 'Festivo'),
              'tipo',      coalesce(e.tipo, 'festivo'),
              'id',        e.id,
              'seccion',   e.seccion,
              'alcance',   case when e.grupo_id is not null then 'grupo'
                                when e.lugar is not null and btrim(e.lugar) <> '' then 'lugar'
                                when e.seccion is not null then 'seccion'
                                else 'club' end)
       from public.calendario_excepciones e, donde d
      where e.activa
        and p_fecha between e.fecha and coalesce(e.fecha_fin, e.fecha)
        and public._excepcion_aplica(e.seccion, e.grupo_id, e.lugar,
                                     p_seccion, p_grupo, d.lugar)
      -- lo más concreto primero: grupo › su sección › sección madre › lugar › club
      order by (e.grupo_id is not null) desc,
               (e.seccion is not distinct from p_seccion) desc,
               (e.seccion is not null) desc,
               (e.lugar is not null) desc,
               e.created_at desc
      limit 1),
    jsonb_build_object('cancelado', false));
$function$;

grant execute on function public.excepcion_del_dia(date, text, uuid, text) to anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 4 · excepciones_rango: todo un rango de una vez (para pintar calendarios)
--     Una fila por día y excepción activa. Lectura pública: un festivo no es
--     un dato personal y el calendario público lo necesita sin cuenta.
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.excepciones_rango(p_desde date, p_hasta date)
returns table(fecha date, id uuid, tipo text, motivo text, seccion text, grupo_id uuid, lugar text)
language sql stable security definer
set search_path to 'public'
as $function$
  select d::date, e.id, coalesce(e.tipo, 'festivo'),
         coalesce(nullif(btrim(e.motivo), ''), 'Festivo'),
         e.seccion, e.grupo_id, nullif(btrim(e.lugar), '')
    from public.calendario_excepciones e
    cross join lateral generate_series(
           greatest(e.fecha, p_desde)::timestamp,
           least(coalesce(e.fecha_fin, e.fecha), p_hasta)::timestamp,
           interval '1 day') as d
   where e.activa
     and p_desde is not null and p_hasta is not null
     and p_hasta >= p_desde and p_hasta - p_desde <= 400   -- tope: un año y pico
     and e.fecha <= p_hasta and coalesce(e.fecha_fin, e.fecha) >= p_desde
   order by 1, (e.grupo_id is not null) desc, (e.seccion is not null) desc,
            (e.lugar is not null) desc, e.created_at desc;
$function$;

grant execute on function public.excepciones_rango(date, date) to anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 5 · Los lectores de siempre, ahora delegando (misma firma, mismas claves)
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.dia_cancelado(p_fecha date, p_seccion text)
returns jsonb
language sql stable security definer
set search_path to 'public'
as $function$
  select public.excepcion_del_dia(p_fecha, p_seccion);
$function$;

-- Natación (la piscina entera: máster y escuela comparten franjas).
-- «cancelado» = se cae la natación (todo el club, o seccion='natacion').
-- Además dice aparte si se cae SOLO la escuela de natación, para quien la pinte.
create or replace function public.natacion_dia_cancelado(p_fecha date)
returns jsonb
language sql stable security definer
set search_path to 'public'
as $function$
  select public.excepcion_del_dia(p_fecha, 'natacion')
         || jsonb_build_object('escuela', public.excepcion_del_dia(p_fecha, 'escuela-natacion'));
$function$;

-- Por tipo de plaza: 'Máster' → natacion; 'Escuela' → escuela-natacion
-- (que también se cae si se cierra la natación entera).
create or replace function public.natacion_dia_cancelado(p_fecha date, p_tipo text)
returns jsonb
language sql stable security definer
set search_path to 'public'
as $function$
  select public.excepcion_del_dia(p_fecha,
           case when lower(public.apo_sin_tildes(coalesce(p_tipo, ''))) like 'escuela%'
                then 'escuela-natacion' else 'natacion' end);
$function$;

grant execute on function public.dia_cancelado(date, text) to authenticated;
grant execute on function public.natacion_dia_cancelado(date) to authenticated;
grant execute on function public.natacion_dia_cancelado(date, text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 6 · «No voy» del máster: en un día cancelado no hay nada que avisar ni bono
--     que ganar. (Cuerpo idéntico al de producción + la comprobación.)
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.natacion_master_no_voy(p_franja uuid, p_fecha date)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $function$
declare v_acc uuid; v_ins int; v_exc jsonb;
begin
  select acceso_id into v_acc from public.natacion_master_yo();
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'no_master'); end if;
  if p_fecha < current_date then return jsonb_build_object('ok', false, 'error', 'tarde',
    'msg', 'El +1 es avisando: no vale marcar un día que ya pasó.'); end if;
  if not exists (select 1 from public.natacion_inscripciones
      where acceso_id = v_acc and franja_id = p_franja and activa and tipo = 'Máster') then
    return jsonb_build_object('ok', false, 'error', 'no_es_tuya'); end if;

  -- Mig 320: día festivo/cancelado → ni aviso ni bono.
  v_exc := public.excepcion_del_dia(p_fecha, 'natacion');
  if coalesce((v_exc->>'cancelado')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'cancelado',
      'motivo', v_exc->>'motivo',
      'msg', 'Ese día no hay natación (' || coalesce(v_exc->>'motivo', 'Festivo') ||
             '): no hace falta avisar y no suma sesión para recuperar.');
  end if;

  insert into public.natacion_ausencias(acceso_id, franja_id, fecha, origen)
    values (v_acc, p_franja, p_fecha, 'aviso')
    on conflict (acceso_id, franja_id, fecha) do nothing;
  get diagnostics v_ins = row_count;

  if v_ins > 0 then
    insert into public.natacion_abonos(acceso_id, nombre, saldo)
      select v_acc, (select nombre from public.natacion_accesos where id = v_acc), 1
      on conflict (acceso_id) do update set saldo = public.natacion_abonos.saldo + 1, updated_at = now();
  end if;

  return jsonb_build_object('ok', true, 'nuevo', v_ins > 0,
    'saldo', (select saldo from public.natacion_abonos where acceso_id = v_acc));
end $function$;
