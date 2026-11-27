-- ============================================================
-- 551 · Natación · la prueba solo en la lista de su día; la franja, cuando se queda
-- ------------------------------------------------------------
-- Andrés (27-nov-2026): «hay muchos que se dan de alta, vienen a probar pero no
-- continúan, y siguen en la franja: aparecen en franjas sin estar en el club y por
-- eso rechazamos gente. Que los de prueba salgan en la lista de ese día concreto y,
-- cuando yo confirme que se quedan y en qué horario, entren en la franja.»
--
--   · Dar de alta de prueba (a mano o desde el formulario): se crean la ficha y el
--     acceso, pero NO la plaza. El día de prueba es una reserva de ese día
--     (natacion_reservas.tipo = 'prueba'), como los que vienen con bono: sale en
--     Pasar lista con la marca «Prueba» y ocupa sitio solo ese día. No cuenta en
--     las franjas ni en los cupos.
--   · natacion_solicitudes.plazas guarda el horario propuesto (franja, calle, nivel).
--   · «Se queda» crea AHORA las plazas, en el horario confirmado (p_datos.plazas)
--     o, si no se dice, en el de la prueba. Antes no había plaza que crear.
--   · Pasar lista guarda si el de prueba vino o no (natacion_reservas.asistio, con
--     natacion_prueba_asistio) y la solicitud pasa sola a «Vino» o apunta «Faltó».
--   · «No sigue» quita su día de prueba si aún no ha llegado (y, como no tiene
--     plaza, baja de natación como hasta ahora).
--   · Las solicitudes antiguas (plazas = null) siguen como estaban.
-- ============================================================
begin;

alter table public.natacion_reservas
  add column if not exists tipo text,
  add column if not exists asistio boolean,
  add column if not exists solicitud_id uuid references public.natacion_solicitudes(id) on delete set null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'natacion_reservas_tipo_check') then
    alter table public.natacion_reservas add constraint natacion_reservas_tipo_check check (tipo is null or tipo in ('prueba'));
  end if;
end $$;
create index if not exists natacion_reservas_solicitud on public.natacion_reservas (solicitud_id) where solicitud_id is not null;
comment on column public.natacion_reservas.tipo is 'null = bono o cambio de día; ''prueba'' = día de prueba de una solicitud (mig 551)';
comment on column public.natacion_reservas.asistio is 'Pasar lista: true vino, false no vino, null sin marcar (mig 551; de momento solo las de prueba)';
comment on column public.natacion_reservas.solicitud_id is 'Solicitud de natación de la que sale esta reserva de prueba (mig 551)';

alter table public.natacion_solicitudes add column if not exists plazas jsonb;
comment on column public.natacion_solicitudes.plazas is
  'Horario propuesto/confirmado [{franja, calle, nivel}]. Si no es null, la prueba va como reserva de ese día y la plaza se crea al «Se queda» (mig 551).';

-- Pone (o mueve) la reserva del día de prueba de una solicitud: la franja de su horario
-- cuyo día de la semana es el de fecha_prueba. Una sola reserva de prueba pendiente.
create or replace function public._nat_sol_reservar_prueba(p_id uuid)
returns uuid
language plpgsql security definer
set search_path = public
as $f$
declare
  s     public.natacion_solicitudes%rowtype;
  v_p   jsonb;
  v_fr  uuid;
  v_ca  text;
  v_nom text;
  v_id  uuid;
  v_dias text[] := array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
begin
  select * into s from public.natacion_solicitudes where id = p_id;
  if not found or s.plazas is null or s.estado <> 'prueba' or s.fecha_prueba is null then return null; end if;
  select x into v_p from jsonb_array_elements(s.plazas) x
    join public.natacion_franjas f on f.id = (x ->> 'franja')::uuid
   where f.dia = extract(isodow from s.fecha_prueba)::int
   limit 1;
  if v_p is null then
    raise exception 'El % no tiene clase en su horario de prueba (%). Elige un día que sí.',
      to_char(s.fecha_prueba, 'DD/MM'),
      (select string_agg(v_dias[f.dia] || ' ' || to_char(f.hora, 'HH24:MI'), ', ' order by f.dia, f.hora)
         from jsonb_array_elements(s.plazas) x join public.natacion_franjas f on f.id = (x ->> 'franja')::uuid);
  end if;
  v_fr := (v_p ->> 'franja')::uuid;
  v_ca := nullif(btrim(coalesce(v_p ->> 'calle', '')), '');
  select upper(btrim(nombre || ' ' || coalesce(apellidos, ''))) into v_nom from public.atletas where id = s.atleta_id;
  v_nom := coalesce(v_nom, upper(btrim(s.nombre || ' ' || coalesce(s.apellidos, ''))));
  -- la pendiente (sin marcar) se mueve; si no hay, se crea
  select id into v_id from public.natacion_reservas
   where solicitud_id = p_id and tipo = 'prueba' and estado = 'reservada' and asistio is null
   order by creada_en desc limit 1;
  if v_id is not null then
    update public.natacion_reservas set franja_id = v_fr, fecha = s.fecha_prueba, calle = v_ca, nombre = v_nom,
                                        acceso_id = s.acceso_id
     where id = v_id;
    update public.natacion_reservas set estado = 'cancelada'      -- por si quedaba alguna otra pendiente
     where solicitud_id = p_id and tipo = 'prueba' and estado = 'reservada' and asistio is null and id <> v_id;
  else
    insert into public.natacion_reservas (franja_id, fecha, acceso_id, nombre, calle, estado, creada_por, tipo, solicitud_id)
    values (v_fr, s.fecha_prueba, s.acceso_id, v_nom, v_ca, 'reservada', public.mi_perfil_id(), 'prueba', p_id)
    returning id into v_id;
  end if;
  return v_id;
end $f$;
revoke all on function public._nat_sol_reservar_prueba(uuid) from public, anon, authenticated;

-- Pasar lista: el de prueba vino (true) / no vino (false) / sin marcar (null).
create or replace function public.natacion_prueba_asistio(p_reserva uuid, p_vino boolean)
returns jsonb
language plpgsql security definer
set search_path = public
as $f$
declare r public.natacion_reservas%rowtype;
begin
  if not (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion')) then
    raise exception 'Sin permiso para pasar lista de natación.' using errcode = '42501';
  end if;
  select * into r from public.natacion_reservas where id = p_reserva for update;
  if not found or r.tipo is distinct from 'prueba' then raise exception 'Esa reserva no es de prueba.'; end if;
  update public.natacion_reservas set asistio = p_vino where id = p_reserva;
  if r.solicitud_id is not null then
    if p_vino is true then
      update public.natacion_solicitudes
         set estado = 'probo', vino_el = r.fecha, falto_el = null, actualizado_en = now()
       where id = r.solicitud_id and estado = 'prueba';
    elsif p_vino is false then
      update public.natacion_solicitudes set falto_el = r.fecha, actualizado_en = now()
       where id = r.solicitud_id and estado = 'prueba';
    else
      update public.natacion_solicitudes
         set estado = 'prueba', vino_el = null, actualizado_en = now()
       where id = r.solicitud_id and estado = 'probo' and vino_el = r.fecha;
      update public.natacion_solicitudes set falto_el = null, actualizado_en = now()
       where id = r.solicitud_id and estado = 'prueba' and falto_el = r.fecha;
    end if;
  end if;
  return jsonb_build_object('ok', true, 'asistio', p_vino);
end $f$;
revoke all on function public.natacion_prueba_asistio(uuid, boolean) from public, anon;
grant execute on function public.natacion_prueba_asistio(uuid, boolean) to authenticated;

-- Pasar lista lee también el tipo, si vino y la solicitud (cambia lo que devuelve).
drop function if exists public.natacion_reservas_dia(date);
create function public.natacion_reservas_dia(p_fecha date)
returns table(id uuid, franja_id uuid, acceso_id uuid, nombre text, calle text, tipo text, asistio boolean, solicitud_id uuid)
language sql stable security definer
set search_path = public
as $f$
  select r.id, r.franja_id, r.acceso_id, r.nombre, r.calle, r.tipo, r.asistio, r.solicitud_id
  from public.natacion_reservas r
  join public.natacion_franjas f on f.id = r.franja_id
  where r.fecha = p_fecha and r.estado = 'reservada'
    and coalesce(f.activa, true)
    and (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
  order by r.calle, r.nombre;
$f$;
revoke all on function public.natacion_reservas_dia(date) from public, anon;
grant execute on function public.natacion_reservas_dia(date) to authenticated;

CREATE OR REPLACE FUNCTION public.natacion_alta_unificada(p_tipo text, p_plazas jsonb, p_atleta uuid DEFAULT NULL::uuid, p_nombre text DEFAULT NULL::text, p_apellidos text DEFAULT NULL::text, p_fecha_nac date DEFAULT NULL::date, p_dni text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_telefono text DEFAULT NULL::text, p_nombre_tutor text DEFAULT NULL::text, p_nivel text DEFAULT NULL::text, p_confirmar_llenas boolean DEFAULT false, p_cuota_importe numeric DEFAULT NULL::numeric, p_cuota_periodicidad text DEFAULT 'mensual'::text, p_cuota_nota text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tipo    text;
  v_email   text := lower(btrim(coalesce(p_email, '')));
  v_tel     text := nullif(btrim(coalesce(p_telefono, '')), '');
  v_dni     text := nullif(upper(regexp_replace(coalesce(p_dni, ''), '[\s.-]', '', 'g')), '');
  v_res     jsonb;
  v_atleta  uuid;
  v_acceso  uuid;
  v_nommay  text;
  v_p       jsonb;
  v_franja  uuid;
  v_calle   text;
  v_nivel   text;
  v_f       public.natacion_franjas%rowtype;
  v_libres  int;
  v_lab     text;
  v_llenas  text[] := '{}';
  v_vistas  uuid[] := '{}';
  v_hechas  jsonb := '[]'::jsonb;
  v_ya      jsonb := '[]'::jsonb;
  v_sobre   jsonb := '[]'::jsonb;
  v_dias    text[] := array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  v_mail_re text := '^[^@\s]+@[^@\s]+\.[^@\s]+$';
  v_cuota_ok boolean := null;
  v_cuota_msg text := null;
  v_cuota_prev numeric;
  v_nota_prev text;
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede dar altas.' using errcode = '42501';
  end if;
  if p_tipo not in ('Escuela', 'Máster') then
    raise exception 'Falta elegir si es de la escuela o adulto/máster.';
  end if;
  v_tipo := p_tipo;
  if p_nivel is not null and p_nivel not in ('Iniciación', 'Desarrollo', 'Perfeccionamiento') then
    raise exception 'Nivel no válido: %', p_nivel;
  end if;
  if jsonb_typeof(coalesce(p_plazas, 'null'::jsonb)) <> 'array' or jsonb_array_length(p_plazas) = 0 then
    raise exception 'Falta elegir al menos un día (franja) y su calle.';
  end if;
  if jsonb_array_length(p_plazas) > 7 then
    raise exception 'Demasiadas franjas a la vez (máximo 7).';
  end if;
  if v_email <> '' and v_email !~ v_mail_re then
    raise exception 'Ese correo no parece válido: %', v_email;
  end if;
  if p_cuota_importe is not null and (p_cuota_importe < 0 or p_cuota_importe > 2000) then
    raise exception 'La cuota no parece correcta: % €.', p_cuota_importe;
  end if;
  if coalesce(p_cuota_periodicidad, 'mensual') not in ('mensual', 'trimestral', 'temporada', 'anual') then
    raise exception 'La periodicidad de la cuota no es válida.';
  end if;
  if v_dni is not null and v_dni !~ '^[0-9XYZ][0-9]{7}[A-Z]$' then
    raise exception 'Ese DNI/NIE no parece válido: % (8 números y una letra; NIE con X/Y/Z delante).', v_dni;
  end if;

  -- ---- comprobar TODAS las plazas antes de tocar nada ----
  for v_p in select * from jsonb_array_elements(p_plazas) loop
    begin
      v_franja := (v_p ->> 'franja')::uuid;
    exception when others then
      raise exception 'Hay una franja que no reconozco. Recarga la página y vuelve a elegir.';
    end;
    v_calle := nullif(btrim(coalesce(v_p ->> 'calle', '')), '');
    v_nivel := coalesce(nullif(btrim(coalesce(v_p ->> 'nivel', '')), ''), p_nivel);
    select * into v_f from public.natacion_franjas where id = v_franja;
    if not found or not coalesce(v_f.activa, true) then
      raise exception 'Una de las franjas ya no existe o está cerrada. Recarga la página y vuelve a elegir.';
    end if;
    if v_franja = any(v_vistas) then
      raise exception 'La franja del % a las % está elegida dos veces.', v_dias[v_f.dia], to_char(v_f.hora, 'HH24:MI');
    end if;
    v_vistas := v_vistas || v_franja;
    if (v_tipo = 'Máster' and not public.natacion_es_master(v_f.grupo, v_f.admite_master))
       or (v_tipo = 'Escuela' and not public.natacion_es_escuela(v_f.grupo)) then
      raise exception 'La franja del % a las % no es de %.', v_dias[v_f.dia], to_char(v_f.hora, 'HH24:MI'),
        case when v_tipo = 'Máster' then 'adultos/máster' else 'la escuela' end;
    end if;
    if v_calle is null then
      raise exception 'Falta elegir la calle del % a las %.', v_dias[v_f.dia], to_char(v_f.hora, 'HH24:MI');
    end if;
    if not (coalesce(v_f.cupos, '{}'::jsonb) ? v_calle) then
      raise exception 'La calle % no existe en la franja del % a las %.', v_calle, v_dias[v_f.dia], to_char(v_f.hora, 'HH24:MI');
    end if;
    if v_nivel is not null and v_nivel not in ('Iniciación', 'Desarrollo', 'Perfeccionamiento') then
      raise exception 'Nivel no válido: %', v_nivel;
    end if;
  end loop;

  -- ---- la ficha ----
  if p_atleta is not null then
    -- YA existe: código, reactivar si estaba de baja, correo si faltaba, token
    v_res := public.natacion_alta_desde_ficha(p_atleta, '{}'::uuid[], p_nivel, null, v_tipo,
                                              nullif(v_email, ''), '{}'::uuid[]);
    v_atleta := p_atleta;
    if nullif(v_res ->> 'email_tutor', '') is null then
      raise exception '%', case when v_tipo = 'Máster'
        then 'Falta el correo del nadador: su ficha no tiene y es por donde le llega el acceso.'
        else 'Falta el correo del tutor: la ficha no tiene y es por donde le llega el acceso a la familia.' end;
    end if;
    -- completar SOLO los huecos (nunca pisa lo que ya hay)
    perform set_config('apolana.via_natacion', '1', true);
    update public.atletas set
      apellidos        = coalesce(nullif(btrim(coalesce(apellidos, '')), ''), nullif(btrim(coalesce(p_apellidos, '')), '')),
      fecha_nacimiento = coalesce(fecha_nacimiento, p_fecha_nac),
      dni              = coalesce(nullif(btrim(coalesce(dni, '')), ''), v_dni),
      telefono         = case when v_tipo = 'Máster'
                              then coalesce(nullif(btrim(coalesce(telefono, '')), ''), v_tel) else telefono end,
      telefono_tutor   = case when v_tipo = 'Escuela'
                              then coalesce(nullif(btrim(coalesce(telefono_tutor, '')), ''), v_tel) else telefono_tutor end,
      nombre_tutor     = case when v_tipo = 'Escuela'
                              then coalesce(nullif(btrim(coalesce(nombre_tutor, '')), ''), nullif(btrim(coalesce(p_nombre_tutor, '')), ''))
                              else nombre_tutor end,
      updated_at       = now()
    where id = p_atleta;
    perform set_config('apolana.via_natacion', '', true);
  else
    -- NUEVA (natacion_crear_nadador ya evita duplicar por DNI o nombre+nacimiento)
    if btrim(coalesce(p_nombre, '')) = '' then
      raise exception 'Falta el nombre.';
    end if;
    if btrim(coalesce(p_apellidos, '')) = '' then
      raise exception 'Faltan los apellidos.';
    end if;
    if p_fecha_nac is null then
      raise exception 'Falta la fecha de nacimiento.';
    end if;
    if p_fecha_nac > current_date or p_fecha_nac < date '1920-01-01' then
      raise exception 'La fecha de nacimiento no parece correcta.';
    end if;
    if v_email = '' then
      raise exception '%', case when v_tipo = 'Máster' then 'Falta el correo del nadador.' else 'Falta el correo del tutor.' end;
    end if;
    if v_tipo = 'Escuela' and btrim(coalesce(p_nombre_tutor, '')) = '' then
      raise exception 'Falta el nombre del padre, madre o tutor.';
    end if;
    v_res := public.natacion_crear_nadador(
      btrim(p_nombre), btrim(p_apellidos), v_dni, p_fecha_nac, v_email,
      case when v_tipo = 'Escuela' then btrim(p_nombre_tutor) end, v_tel,
      '{}'::uuid[], coalesce(p_nivel, 'Iniciación'), 'C1', v_tipo);
    v_atleta := (v_res ->> 'atleta_id')::uuid;
    v_res := v_res || jsonb_build_object('publico', case when v_tipo = 'Máster' then 'master' else 'familia' end);
  end if;

  v_acceso := (v_res ->> 'acceso_id')::uuid;
  select upper(btrim(nombre || ' ' || coalesce(apellidos, ''))) into v_nommay
    from public.atletas where id = v_atleta;

  -- ---- una inscripción por franja, cada una con SU calle y nivel ----
  -- (mig 551) Si es solo para PROBAR (apolana.nat_prueba = '1'), no se crea ninguna plaza:
  -- la ficha y el acceso sí, y el día de prueba va como reserva de ese día (tipo 'prueba').
  if coalesce(current_setting('apolana.nat_prueba', true), '') <> '1' then
  for v_p in select * from jsonb_array_elements(p_plazas) loop
    v_franja := (v_p ->> 'franja')::uuid;
    v_calle  := btrim(v_p ->> 'calle');
    v_nivel  := coalesce(nullif(btrim(coalesce(v_p ->> 'nivel', '')), ''), p_nivel);
    select * into v_f from public.natacion_franjas where id = v_franja;
    v_lab    := v_dias[v_f.dia] || ' ' || to_char(v_f.hora, 'HH24:MI') || ' · ' || v_calle;
    -- ya estaba en esa franja (repetir el alta no duplica ni cuenta como «llena»)
    if exists (select 1 from public.natacion_inscripciones
                where franja_id = v_franja and activa and (atleta_id = v_atleta or acceso_id = v_acceso)) then
      v_ya := v_ya || jsonb_build_array(v_dias[v_f.dia] || ' ' || to_char(v_f.hora, 'HH24:MI'));
      continue;
    end if;
    -- hueco: el mismo cálculo que enseña el asistente (antes de meterle)
    select a.libres into v_libres
      from public.natacion_alta_franjas(v_tipo) a
     where a.franja_id = v_franja and a.calle = v_calle;
    if coalesce(v_libres, 0) <= 0 then
      v_llenas := v_llenas || v_lab;
    end if;
    insert into public.natacion_inscripciones
      (franja_id, nombre, tipo, nivel, calle, acceso_id, atleta_id, activa)
    values (v_franja, v_nommay, v_tipo, v_nivel, v_calle, v_acceso, v_atleta, true);
    v_hechas := v_hechas || jsonb_build_array(v_lab);
  end loop;

  -- calle sin hueco y sin confirmar → se deshace TODO (es una sola transacción)
  if array_length(v_llenas, 1) > 0 and not coalesce(p_confirmar_llenas, false) then
    raise exception 'CALLE LLENA: % no tiene hueco. Si quieres meterle igualmente, confírmalo.',
      array_to_string(v_llenas, ', ');
  end if;
  v_sobre := to_jsonb(v_llenas);
  end if;   -- (mig 551) fin de «no es solo para probar»

  -- ---- la cuota, apuntada en la ficha (sin cobrar nada) ----
  -- Una ficha tiene UNA cuota. Si ya tenía una que NO es de natación (Cubo,
  -- escuela de atletismo…), no se pisa: se avisa para que lo vea administración.
  if p_cuota_importe is not null then
    select cuota_importe, cuota_nota into v_cuota_prev, v_nota_prev from public.atletas where id = v_atleta;
    if v_cuota_prev is not null and coalesce(v_nota_prev, '') !~* '^nataci' then
      v_cuota_ok := false;
      v_cuota_msg := 'Ya tenía otra cuota de ' || replace(to_char(v_cuota_prev, 'FM999990.00'), '.', ',') || ' € (de otra sección): no la he cambiado. Si debe cambiar, que lo vea administración.';
    else
      perform set_config('apolana.via_natacion', '1', true);
      update public.atletas set
        cuota_importe      = round(p_cuota_importe, 2),
        cuota_periodicidad = coalesce(p_cuota_periodicidad, 'mensual'),
        cuota_nota         = left(coalesce(nullif(btrim(coalesce(p_cuota_nota, '')), ''),
                                  'Natación ' || case when v_tipo = 'Máster' then 'máster' else 'escuela' end), 300),
        cuota_fijada_en    = now(),
        cuota_fijada_por   = public.mi_perfil_id(),
        updated_at         = now()
      where id = v_atleta;
      perform set_config('apolana.via_natacion', '', true);
      v_cuota_ok := true;
    end if;
  end if;

  return v_res || jsonb_build_object(
    'atleta_id', v_atleta, 'acceso_id', v_acceso, 'nombre', v_nommay, 'tipo', v_tipo,
    'franjas', v_hechas, 'inscripciones', jsonb_array_length(v_hechas),
    'ya_estaba', v_ya, 'sobre_cupo', v_sobre,
    'cuota_guardada', v_cuota_ok, 'cuota_aviso', v_cuota_msg);
end $function$;

CREATE OR REPLACE FUNCTION public.natacion_solicitud_accion(p_id uuid, p_accion text, p_datos jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  s       public.natacion_solicitudes%rowtype;
  d       jsonb := coalesce(p_datos, '{}'::jsonb);
  v_res   jsonb;
  v_franja uuid;
  v_r     text;
  v_plz   jsonb;
  v_fr    uuid[];
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede llevar las solicitudes.' using errcode = '42501';
  end if;
  select * into s from public.natacion_solicitudes where id = p_id for update;
  if not found then raise exception 'No encuentro esa solicitud.'; end if;

  if p_accion = 'datos' then
    update public.natacion_solicitudes set
      nombre    = case when d ? 'nombre'    then nullif(btrim(d ->> 'nombre'), '')    else nombre end,
      apellidos = case when d ? 'apellidos' then nullif(btrim(d ->> 'apellidos'), '') else apellidos end,
      fecha_nac = case when d ? 'fecha_nac' then nullif(d ->> 'fecha_nac', '')::date  else fecha_nac end,
      tutor     = case when d ? 'tutor'     then nullif(btrim(d ->> 'tutor'), '')     else tutor end,
      email     = case when d ? 'email'     then nullif(lower(btrim(d ->> 'email')), '') else email end,
      telefono  = case when d ? 'telefono'  then nullif(btrim(d ->> 'telefono'), '')  else telefono end,
      nivel     = case when d ? 'nivel'     then nullif(d ->> 'nivel', '')            else nivel end,
      socio     = case when d ? 'socio'     then (d ->> 'socio')::boolean             else socio end,
      nota      = case when d ? 'nota'      then nullif(btrim(d ->> 'nota'), '')      else nota end,
      fecha_prueba = case when d ? 'fecha_prueba' then nullif(d ->> 'fecha_prueba', '')::date else fecha_prueba end,
      actualizado_en = now()
    where id = p_id;
    -- (mig 536) si cambia el día de la prueba, cambia también desde cuándo sale en la lista
    if d ? 'fecha_prueba' then
      if s.plazas is not null then perform public._nat_sol_reservar_prueba(p_id);   -- (mig 551) se mueve su día de prueba
      else perform public._nat_sol_poner_desde(p_id); end if;
    end if;

  elsif p_accion = 'asignar' then
    if s.estado not in ('anterior', 'revisar', 'espera', 'sin_hueco', 'no_sigue') then
      raise exception 'Esta solicitud ya tiene grupo.';
    end if;
    v_franja := (d ->> 'franja')::uuid;
    if v_franja is null or nullif(d ->> 'calle', '') is null then raise exception 'Elige franja y calle.'; end if;
    -- (mig 551) Solo para probar: ficha y acceso sí, plaza NO. Sale únicamente en la lista
    -- de su día de prueba; entra en la franja cuando se confirme «Se queda» (con su horario).
    v_plz := jsonb_build_array(jsonb_build_object('franja', v_franja, 'calle', d ->> 'calle',
                                                  'nivel', coalesce(nullif(d ->> 'nivel', ''), s.nivel)));
    perform set_config('apolana.nat_prueba', '1', true);
    v_res := public.natacion_alta_unificada(
      s.origen, v_plz,
      s.atleta_id, s.nombre, s.apellidos, s.fecha_nac, s.dni, s.email, s.telefono, s.tutor,
      coalesce(nullif(d ->> 'nivel', ''), s.nivel), true, null, null, null);
    perform set_config('apolana.nat_prueba', '', true);
    update public.natacion_solicitudes
       set estado = 'prueba', motivo = null, alta_en = now(), franjas = array[v_franja], plazas = v_plz,
           fecha_prueba = public._nat_proxima_clase(v_franja, current_date + 1),
           nivel = coalesce(nullif(d ->> 'nivel', ''), nivel),
           atleta_id = (v_res ->> 'atleta_id')::uuid, acceso_id = (v_res ->> 'acceso_id')::uuid,
           vino_el = null, falto_el = null, avisado = 'prueba', actualizado_en = now()
     where id = p_id;
    perform public._nat_sol_reservar_prueba(p_id);   -- (mig 551) solo en la lista de su día de prueba

  elsif p_accion = 'procesar' then          -- una «anterior» entra en el circuito
    update public.natacion_solicitudes set estado = 'revisar', avisado = 'revisar', actualizado_en = now() where id = p_id;
    v_r := public._nat_sol_procesar(p_id);
    update public.natacion_solicitudes set avisado = estado where id = p_id;

  elsif p_accion = 'espera' then
    update public.natacion_solicitudes
       set estado = 'espera', espera_hasta = current_date + 15, avisado = null, actualizado_en = now() where id = p_id;

  elsif p_accion = 'sin_hueco' then
    update public.natacion_solicitudes set estado = 'sin_hueco', avisado = null, actualizado_en = now() where id = p_id;

  elsif p_accion = 'vino' then
    update public.natacion_solicitudes
       set estado = 'probo', vino_el = coalesce(nullif(d ->> 'fecha', '')::date, current_date), avisado = 'probo',
           actualizado_en = now()
     where id = p_id;
    update public.natacion_reservas set asistio = true      -- (mig 551) su día de prueba, como venido
     where solicitud_id = p_id and tipo = 'prueba' and estado = 'reservada' and asistio is null;

  elsif p_accion = 'se_queda' then
    if s.plazas is not null then
      -- (mig 551) AHORA entra en la franja: en el horario confirmado (si no se dice, el de la prueba)
      v_plz := case when jsonb_typeof(d -> 'plazas') = 'array' and jsonb_array_length(d -> 'plazas') > 0
                    then d -> 'plazas' else s.plazas end;
      v_res := public.natacion_alta_unificada(
        s.origen, v_plz, s.atleta_id, s.nombre, s.apellidos, s.fecha_nac, s.dni, s.email, s.telefono, s.tutor,
        s.nivel, coalesce((d ->> 'confirmar')::boolean, false), null, null, null);
      select array_agg((x ->> 'franja')::uuid) into v_fr from jsonb_array_elements(v_plz) x;
      update public.natacion_solicitudes
         set estado = 'formaliza', avisado = null, plazas = v_plz, franjas = v_fr,
             atleta_id = coalesce(atleta_id, (v_res ->> 'atleta_id')::uuid), acceso_id = coalesce(acceso_id, (v_res ->> 'acceso_id')::uuid),
             actualizado_en = now()
       where id = p_id;
    else
      update public.natacion_solicitudes set estado = 'formaliza', avisado = null, actualizado_en = now() where id = p_id;
    end if;

  elsif p_accion = 'no_sigue' then
    -- (mig 551) su día de prueba, si aún no ha llegado, fuera de la lista
    update public.natacion_reservas set estado = 'cancelada'
     where solicitud_id = p_id and tipo = 'prueba' and estado = 'reservada' and fecha >= current_date and asistio is null;
    -- fuera de las franjas que se le dieron para probar; y si no le queda ninguna
    -- otra, baja de natación completa (código, reservas…) como en «Dar de baja»
    update public.natacion_inscripciones set activa = false, updated_at = now()
     where activa and acceso_id = s.acceso_id and s.alta_en is not null
       and created_at >= s.alta_en - interval '1 minute';
    if (s.acceso_id is not null or s.atleta_id is not null) and not exists (
         select 1 from public.natacion_inscripciones i
          where i.activa and (i.acceso_id = s.acceso_id or i.atleta_id = s.atleta_id)) then
      perform public.natacion_dar_baja(s.acceso_id, s.atleta_id);
    end if;
    update public.natacion_solicitudes set estado = 'no_sigue', avisado = 'no_sigue', actualizado_en = now() where id = p_id;

  elsif p_accion = 'descartar' then
    update public.natacion_solicitudes set estado = 'descartada', avisado = 'descartada', actualizado_en = now() where id = p_id;

  elsif p_accion = 'reabrir' then
    update public.natacion_solicitudes
       set estado = 'revisar', motivo = coalesce(motivo, 'Reabierta a mano.'), avisado = 'revisar', actualizado_en = now()
     where id = p_id;

  elsif p_accion = 'msg' then
    update public.natacion_solicitudes set
      msg_prueba_en    = case when d ->> 'que' = 'prueba'    then now() else msg_prueba_en end,
      msg_espera_en    = case when d ->> 'que' = 'espera'    then now() else msg_espera_en end,
      msg_formaliza_en = case when d ->> 'que' = 'formaliza' then now() else msg_formaliza_en end,
      msg_sin_hueco_en = case when d ->> 'que' = 'sin_hueco' then now() else msg_sin_hueco_en end,
      actualizado_en = now()
    where id = p_id;

  else
    raise exception 'Acción desconocida: %', p_accion;
  end if;

  return (select to_jsonb(x) from public.natacion_solicitudes x where x.id = p_id);
end $function$;

CREATE OR REPLACE FUNCTION public._nat_sol_procesar(p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  s        public.natacion_solicitudes%rowtype;
  v_franja uuid;
  c        record;
  v_plazas jsonb := '[]'::jsonb;
  v_llenas text[] := '{}';
  v_cerrad text[] := '{}';
  v_elegid uuid[] := '{}';
  v_res    jsonb;
  v_ya     text;
  v_ya_at  uuid;
  v_ya_ac  uuid;
  v_dias   text[] := array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  v_prueba date;
begin
  select * into s from public.natacion_solicitudes where id = p_id for update;
  if not found or s.estado <> 'revisar' then return null; end if;

  -- ¿la misma persona ya tiene otra solicitud en marcha? → repetida, lo decide Andrés
  if exists (select 1 from public.natacion_solicitudes o
              where o.id <> s.id and o.origen = s.origen
                and o.estado in ('revisar', 'prueba', 'probo', 'espera', 'formaliza')
                and o.creado_en <= s.creado_en
                and (public._nat_sol_norm(o.nombre || ' ' || coalesce(o.apellidos, '')) = public._nat_sol_norm(s.nombre || ' ' || coalesce(s.apellidos, ''))
                     or (s.dni is not null and o.dni = s.dni))) then
    update public.natacion_solicitudes
       set motivo = 'Repetida: ya hay otra solicitud suya en marcha. Descarta una de las dos.', actualizado_en = now()
     where id = p_id;
    return 'revisar';
  end if;

  -- ¿ya nada en el club? (mismo nombre en una franja activa) → lo decide Andrés
  select string_agg(distinct v_dias[f.dia] || ' ' || to_char(f.hora, 'HH24:MI'), ', '),
         (array_agg(i.atleta_id) filter (where i.atleta_id is not null))[1],
         (array_agg(i.acceso_id) filter (where i.acceso_id is not null))[1]
    into v_ya, v_ya_at, v_ya_ac
    from public.natacion_inscripciones i join public.natacion_franjas f on f.id = i.franja_id
   where i.activa and public._nat_sol_norm(i.nombre) = public._nat_sol_norm(s.nombre || ' ' || coalesce(s.apellidos, ''));
  if v_ya is not null then
    update public.natacion_solicitudes
       set motivo = 'Ya nada en el club (' || v_ya || '). Mira si es un cambio de horario.',
           atleta_id = coalesce(atleta_id, v_ya_at), acceso_id = coalesce(acceso_id, v_ya_ac), actualizado_en = now()
     where id = p_id;
    return 'revisar';
  end if;

  -- (mig 535, 19-nov-2026) Máster de INICIACIÓN: no prueba entre semana (Lorena no quiere
  -- a nadie de iniciación entre semana). Prueba un sábado en Monte Tossal con Mario, sin
  -- competición cerca, y Mario le da el nivel. La fecha la pone a mano quien lleva natación
  -- («asignar» en la franja del sábado 8:30 y luego la fecha de prueba).
  if s.origen = 'Máster' and s.nivel = 'Iniciación' then
    update public.natacion_solicitudes
       set motivo = 'Máster de iniciación: no prueba entre semana. Prueba un sábado en Monte Tossal con Mario (sin competición cerca) y Mario le dice su nivel.',
           actualizado_en = now()
     where id = p_id;
    return 'revisar';
  end if;

  -- no se entiende el horario (o solo una parte): mejor que lo mire Andrés que
  -- apuntarle a medias
  if coalesce(array_length(s.franjas_pedidas, 1), 0) = 0 or s.motivo is not null then
    update public.natacion_solicitudes
       set motivo = coalesce(motivo, 'No entiendo qué horario pide.'), actualizado_en = now() where id = p_id;
    return 'revisar';
  end if;

  -- una calle por franja: de su tipo (o vacía), con hueco, y mejor de su nivel
  foreach v_franja in array s.franjas_pedidas loop
    -- semáforo puesto a mano en Franjas y cupos (rojo = cerrado, ámbar = consultar)
    if exists (select 1 from public.natacion_franjas f where f.id = v_franja and f.semaforo_forzado in ('rojo', 'ambar')) then
      select v_cerrad || (v_dias[f.dia] || ' ' || to_char(f.hora, 'HH24:MI')) into v_cerrad
        from public.natacion_franjas f where f.id = v_franja;
      continue;
    end if;
    select a.calle, a.libres, a.cupo, a.fijos, a.nivel, a.dia, a.hora,
           (select count(*) filter (where i.tipo = s.origen) - count(*) filter (where i.tipo <> s.origen)
              from public.natacion_inscripciones i
             where i.franja_id = v_franja and i.calle = a.calle and i.activa) as afin
      into c
      from public.natacion_alta_franjas(s.origen) a
     where a.franja_id = v_franja
     order by ((select count(*) filter (where i.tipo = s.origen) - count(*) filter (where i.tipo <> s.origen)
                  from public.natacion_inscripciones i
                 where i.franja_id = v_franja and i.calle = a.calle and i.activa) >= 0) desc,
              (a.libres > 0) desc, (a.nivel is not distinct from s.nivel) desc, a.libres desc, a.calle
     limit 1;
    if not found then
      v_llenas := v_llenas || 'una franja que ya no está abierta';
    elsif c.afin < 0 or c.libres <= 0 then
      v_llenas := v_llenas || (v_dias[c.dia] || ' ' || to_char(c.hora, 'HH24:MI')
                              || case when c.afin >= 0 then ' (calle ' || replace(c.calle, 'C', '') || ': '
                                      || c.fijos || ' de ' || c.cupo || ')' else '' end);
    else
      v_plazas := v_plazas || jsonb_build_object('franja', v_franja, 'calle', c.calle, 'nivel', coalesce(s.nivel, c.nivel));
      v_elegid := v_elegid || v_franja;
    end if;
  end loop;

  if array_length(v_llenas, 1) > 0 or array_length(v_cerrad, 1) > 0 then
    update public.natacion_solicitudes
       set motivo = concat_ws(' ',
             case when array_length(v_llenas, 1) > 0 then 'Grupo completo: ' || array_to_string(v_llenas, ', ') || '.' end,
             case when array_length(v_cerrad, 1) > 0 then 'Horario cerrado o «consultar» en Franjas y cupos: '
                                                          || array_to_string(v_cerrad, ', ') || '.' end),
           actualizado_en = now()
     where id = p_id;
    return 'revisar';
  end if;

  begin
    perform set_config('apolana.nat_prueba', '1', true);   -- (mig 551) ficha y acceso, sin plaza
    v_res := public.natacion_alta_unificada(
      s.origen, v_plazas, null, s.nombre, s.apellidos, s.fecha_nac, s.dni, s.email, s.telefono, s.tutor,
      s.nivel, false, null, null, null);
    perform set_config('apolana.nat_prueba', '', true);
  exception when others then
    perform set_config('apolana.nat_prueba', '', true);
    update public.natacion_solicitudes
       set motivo = 'No he podido darle de alta: ' || sqlerrm, actualizado_en = now() where id = p_id;
    return 'revisar';
  end;

  select min(public._nat_proxima_clase(f, current_date + 1)) into v_prueba from unnest(v_elegid) f;
  update public.natacion_solicitudes
     set estado = 'prueba', motivo = null, alta_en = now(), franjas = v_elegid, fecha_prueba = v_prueba, plazas = v_plazas,
         atleta_id = (v_res ->> 'atleta_id')::uuid, acceso_id = (v_res ->> 'acceso_id')::uuid, actualizado_en = now()
   where id = p_id;
  perform public._nat_sol_reservar_prueba(p_id);   -- (mig 551) solo en la lista de su día de prueba
  return 'prueba';
end $function$;

CREATE OR REPLACE FUNCTION public.natacion_solicitudes_revisar()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  s       record;
  v_vino  date;
  v_falto date;
  v_desde date;
  v_ok    boolean;
  v_pasada boolean;
  n_vino  int := 0;
  n_alta  int := 0;
  n_fuera int := 0;
begin
  for s in select * from public.natacion_solicitudes
            where estado in ('prueba', 'probo', 'formaliza') and acceso_id is not null loop
    -- ya tiene cuota de natación hecha después del alta → alta (fin del circuito)
    if s.atleta_id is not null and exists (
         select 1 from public.cuotas_entreno c
          where c.atleta_id = s.atleta_id and c.origen = 'natacion'
            and c.created_at >= coalesce(s.alta_en, s.creado_en)) then
      update public.natacion_solicitudes set estado = 'alta', avisado = 'alta', actualizado_en = now() where id = s.id;
      n_alta := n_alta + 1; continue;
    end if;
    -- (mig 551) prueba «solo ese día»: aún no tiene franja (es lo normal); vale lo que diga su reserva
    if s.plazas is not null and s.estado in ('prueba', 'probo') then
      if s.estado = 'prueba' then
        select r.fecha, r.asistio,
               exists (select 1 from public.natacion_lista l
                        where l.franja_id = r.franja_id and l.fecha = r.fecha
                          and l.pasada_en > coalesce(s.alta_en, s.creado_en)) as pasada
          into v_vino, v_ok, v_pasada
          from public.natacion_reservas r
         where r.solicitud_id = s.id and r.tipo = 'prueba' and r.estado = 'reservada'
         order by r.fecha desc limit 1;
        if v_vino is not null and (v_ok is true or (v_ok is null and v_pasada)) then
          update public.natacion_solicitudes set estado = 'probo', vino_el = v_vino, actualizado_en = now() where id = s.id;
          n_vino := n_vino + 1;
        elsif v_vino is not null and v_ok is false and v_vino is distinct from s.falto_el then
          update public.natacion_solicitudes set falto_el = v_vino, actualizado_en = now() where id = s.id;
        end if;
      end if;
      continue;
    end if;
    -- ya no está en ninguna franja (lo quitaron a mano) → no sigue
    if not exists (select 1 from public.natacion_inscripciones i where i.acceso_id = s.acceso_id and i.activa) then
      update public.natacion_solicitudes
         set estado = 'no_sigue', motivo = 'Ya no está en ninguna franja.', avisado = 'no_sigue', actualizado_en = now()
       where id = s.id;
      n_fuera := n_fuera + 1; continue;
    end if;
    if s.estado <> 'prueba' then continue; end if;
    -- solo cuentan las clases desde el día de la prueba (no las de antes de avisarle)
    v_desde := coalesce(s.fecha_prueba, (coalesce(s.alta_en, s.creado_en) at time zone 'Europe/Madrid')::date);
    -- vino: lista de su franja pasada DESPUÉS del alta, desde el día de la prueba y sin falta suya
    select min(l.fecha) into v_vino
      from public.natacion_lista l
     where l.franja_id in (select i.franja_id from public.natacion_inscripciones i where i.acceso_id = s.acceso_id and i.activa)
       and l.pasada_en > coalesce(s.alta_en, s.creado_en)
       and l.fecha >= v_desde
       and not exists (select 1 from public.natacion_ausencias a
                        where a.acceso_id = s.acceso_id and a.franja_id = l.franja_id and a.fecha = l.fecha);
    if v_vino is not null then
      update public.natacion_solicitudes set estado = 'probo', vino_el = v_vino, actualizado_en = now() where id = s.id;
      n_vino := n_vino + 1;
    else
      select max(a.fecha) into v_falto
        from public.natacion_ausencias a
        join public.natacion_lista l on l.franja_id = a.franja_id and l.fecha = a.fecha
       where a.acceso_id = s.acceso_id and l.pasada_en > coalesce(s.alta_en, s.creado_en)
         and a.fecha >= v_desde;
      if v_falto is distinct from s.falto_el then
        update public.natacion_solicitudes set falto_el = v_falto, actualizado_en = now() where id = s.id;
      end if;
    end if;
  end loop;
  return jsonb_build_object('vinieron', n_vino, 'con_cuota', n_alta, 'fuera', n_fuera);
end $function$;

CREATE OR REPLACE FUNCTION public.natacion_solicitudes_correo(p_todo boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with hoy as (select (now() at time zone 'Europe/Madrid')::date as d),
  fr as (   -- franjas con su monitor
    select f.id, f.dia, to_char(f.hora, 'HH24:MI') as hora, f.monitores from public.natacion_franjas f
  ),
  x as (
    select s.*,
           case when s.estado = 'prueba' and s.falto_el is not null then 'falto'
                when s.estado in ('revisar', 'prueba', 'probo') then s.estado
                when s.estado = 'espera' and s.espera_hasta <= (select d from hoy) then 'plazo' end as k
      from public.natacion_solicitudes s
  ),
  av as (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', x.id, 'que', x.k, 'origen', x.origen,
             'nombre', btrim(x.nombre || ' ' || coalesce(x.apellidos, '')),
             'nombre_pila', x.nombre, 'tutor', x.tutor, 'socio', case when public._nat_ficha_socio(x.atleta_id) then true else x.socio end, 'nivel', x.nivel,
             'nacimiento', x.fecha_nac, 'pide', x.pide, 'motivo', x.motivo, 'observaciones', x.observaciones,
             'fecha_prueba', x.fecha_prueba, 'vino_el', x.vino_el, 'falto_el', x.falto_el, 'espera_hasta', x.espera_hasta,
             'dias', case when x.plazas is not null and x.estado in ('prueba', 'probo') then jsonb_array_length(x.plazas)   -- (mig 551) el horario propuesto
                     else (select count(*) from public.natacion_inscripciones i where i.acceso_id = x.acceso_id and i.activa) end,
             'franjas', (select string_agg((array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'])[fr.dia]
                                           || ' ' || fr.hora, ', ' order by fr.dia, fr.hora)
                           from unnest(x.franjas) u join fr on fr.id = u),
             'franjas_det', (select coalesce(jsonb_agg(jsonb_build_object('dia', fr.dia, 'hora', fr.hora, 'monitores', fr.monitores)
                                                       order by fr.dia, fr.hora), '[]'::jsonb)
                               from unnest(case when coalesce(array_length(x.franjas, 1), 0) > 0 then x.franjas else x.franjas_pedidas end) u
                               join fr on fr.id = u))
             order by x.k, x.creado_en), '[]'::jsonb) as j
      from x
     where x.k is not null and (p_todo or x.k is distinct from x.avisado)
  ),
  ag as (   -- quién viene a probar, de hoy en adelante (la franja del día de la prueba)
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', s.id, 'origen', s.origen, 'nombre', btrim(s.nombre || ' ' || coalesce(s.apellidos, '')),
             'nacimiento', s.fecha_nac, 'nivel', s.nivel, 'observaciones', s.observaciones,
             'fecha', s.fecha_prueba, 'dia', p.dia, 'hora', p.hora, 'monitores', p.monitores, 'calle', p.calle)
             order by s.fecha_prueba, p.hora, s.nombre), '[]'::jsonb) as j
      from public.natacion_solicitudes s
      left join lateral (
        select fr.dia, fr.hora, fr.monitores,
               coalesce((select i.calle from public.natacion_inscripciones i
                          where i.acceso_id = s.acceso_id and i.franja_id = fr.id and i.activa limit 1),
                        (select r.calle from public.natacion_reservas r      -- (mig 551) la de su día de prueba
                          where r.solicitud_id = s.id and r.tipo = 'prueba' and r.franja_id = fr.id
                            and r.estado = 'reservada' limit 1)) as calle
          from unnest(s.franjas) u join fr on fr.id = u
         order by (fr.dia = extract(isodow from s.fecha_prueba)::int) desc, fr.dia, fr.hora
         limit 1) p on true
     where s.estado = 'prueba' and s.fecha_prueba >= (select d from hoy)
  ),
  ta as (   -- cuotas por nº de días (las mismas que natacion_alta_cuota)
    select jsonb_object_agg(t.tipo, t.j) as j
      from (
        select tipo, coalesce(jsonb_agg(jsonb_build_object('dias', x.n, 'socio', x.importe_socio, 'no_socio', x.importe_no_socio)
                                        order by x.n), '[]'::jsonb) as j
          from (values ('Escuela', 'escuela-natacion'), ('Máster', 'natacion')) v(tipo, seccion)
          left join lateral (
            select distinct on (substring(t.dias from '^\s*(\d+)')::int)
                   substring(t.dias from '^\s*(\d+)')::int as n, t.importe_socio, t.importe_no_socio
              from public.tarifas t
             where t.activo and t.seccion = v.seccion
               and t.vigente_desde <= (select d from hoy)
               and (t.vigente_hasta is null or t.vigente_hasta >= (select d from hoy))
               and substring(t.dias from '^\s*(\d+)') is not null
             order by substring(t.dias from '^\s*(\d+)')::int, t.vigente_desde desc, t.orden) x on true
         where x.n is not null
         group by tipo) t
  )
  select jsonb_build_object('avisos', (select j from av), 'agenda', (select j from ag),
                            'tarifas', coalesce((select j from ta), '{}'::jsonb));
$function$;

-- (mig 551) Cancelar una reserva de PRUEBA no devuelve ningún bono.
CREATE OR REPLACE FUNCTION public.natacion_cancelar_reserva(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_acc uuid; v_est text; v_tipo text;
begin
  if not (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;
  select acceso_id, estado, tipo into v_acc, v_est, v_tipo from natacion_reservas where id = p_id;
  if v_est is null then return jsonb_build_object('ok', false, 'msg', 'No existe.'); end if;
  if v_est <> 'reservada' then return jsonb_build_object('ok', false, 'msg', 'Ya no está activa.'); end if;
  update natacion_reservas set estado = 'cancelada' where id = p_id;
  if v_tipo is not distinct from 'prueba' then   -- (mig 551) un día de prueba no es un bono: no se devuelve nada
    return jsonb_build_object('ok', true, 'msg', 'Día de prueba quitado.');
  end if;
  if v_acc is not null then update natacion_abonos set saldo = saldo + 1, updated_at = now() where acceso_id = v_acc; end if;
  return jsonb_build_object('ok', true, 'msg', 'Reserva cancelada y clase devuelta.');
end $function$;

CREATE OR REPLACE FUNCTION public.natacion_master_cancelar(p_reserva uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_acc uuid; v_r record;
begin
  select acceso_id into v_acc from public.natacion_master_yo();
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'no_master'); end if;
  select * into v_r from public.natacion_reservas where id = p_reserva and acceso_id = v_acc;
  if v_r is null then return jsonb_build_object('ok', false, 'error', 'no_es_tuya'); end if;
  if v_r.fecha < current_date then return jsonb_build_object('ok', false, 'error', 'pasada'); end if;
  if v_r.tipo is not distinct from 'prueba' then   -- (mig 551) su día de prueba: se quita, sin bono que devolver
    update public.natacion_reservas set estado = 'cancelada' where id = p_reserva;
    return jsonb_build_object('ok', true, 'saldo', (select saldo from public.natacion_abonos where acceso_id = v_acc));
  end if;
  delete from public.natacion_reservas where id = p_reserva;
  update public.natacion_abonos set saldo = saldo + 1, updated_at = now() where acceso_id = v_acc;
  return jsonb_build_object('ok', true, 'saldo', (select saldo from public.natacion_abonos where acceso_id = v_acc));
end $function$;

commit;
