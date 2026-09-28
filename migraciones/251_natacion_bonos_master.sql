-- 251 · Autoservicio de BONOS del Máster de natación
-- ---------------------------------------------------------------------------
-- REGLA (Andrés): el máster funciona por bonos. Si un día no puede ir, lo marca
-- AVISANDO (antes, no un "no show") y se le guarda un +1 que usa el día y hora
-- que quiera. Calles: Perfeccionamiento (C3) puede ir a cualquier calle; los de
-- C2 a C1 y C2; los de C1 solo a C1. Hueco POR CALLE (adultos 7/calle). La calle
-- se asigna automáticamente. Lo hace el propio nadador en su portal; Mario/Andrés
-- también pueden a mano (RPC de staff que ya existen).
--
-- Se AÑADE, no se toca lo de staff. Todo SECURITY DEFINER y acotado al que llama
-- (por su perfil): un nadador solo se gestiona a sí mismo.
-- ---------------------------------------------------------------------------
begin;

-- Nº de calle a partir de "C2" → 2.
create or replace function public._num_calle(t text)
returns int language sql immutable as $$
  select nullif(regexp_replace(coalesce(t, ''), '\D', '', 'g'), '')::int
$$;

-- ¿Quién soy como MÁSTER? (acceso, nombre y mi calle "de casa" = mi nivel).
-- Devuelve 0 filas si el que llama no es un nadador máster.
create or replace function public.natacion_master_yo()
returns table(acceso_id uuid, nombre text, calle_num int)
language sql stable security definer set search_path = 'public' as $$
  select ac.id, ac.nombre, max(public._num_calle(i.calle))
  from public.natacion_inscripciones i
  join public.natacion_accesos ac on ac.id = i.acceso_id
  join public.atletas a on a.id = i.atleta_id
  where i.activa and i.tipo = 'Máster'
    and a.perfil_id = public.mi_perfil_id()
  group by ac.id, ac.nombre
  limit 1;
$$;
revoke all on function public.natacion_master_yo() from public, anon;
grant execute on function public.natacion_master_yo() to authenticated;

-- Huecos POR CALLE de una franja un día (cuenta fijos - bajas - reservas por calle).
-- Devuelve una fila por calle con su hueco. Interna (la usan las de abajo).
create or replace function public.natacion_huecos_calle(p_franja uuid, p_fecha date)
returns table(calle text, cupo int, ocupados int, huecos int)
language sql stable security definer set search_path = 'public' as $$
  with f as (select cupos, calles from public.natacion_franjas where id = p_franja),
  calles as (
    select k as calle, (v)::int as cupo
    from f, jsonb_each_text((select cupos from f)) as e(k, v)
  )
  select c.calle, c.cupo,
    ( (select count(*) from public.natacion_inscripciones i
         where i.franja_id = p_franja and i.activa and i.calle = c.calle)
      - (select count(*) from public.natacion_ausencias au
           join public.natacion_inscripciones i2 on i2.acceso_id = au.acceso_id and i2.franja_id = au.franja_id and i2.activa
         where au.franja_id = p_franja and au.fecha = p_fecha and i2.calle = c.calle)
      + (select count(*) from public.natacion_reservas r
           where r.franja_id = p_franja and r.fecha = p_fecha and r.calle = c.calle and r.estado = 'reservada')
    )::int as ocupados,
    ( c.cupo
      - ( (select count(*) from public.natacion_inscripciones i
             where i.franja_id = p_franja and i.activa and i.calle = c.calle)
          - (select count(*) from public.natacion_ausencias au
               join public.natacion_inscripciones i2 on i2.acceso_id = au.acceso_id and i2.franja_id = au.franja_id and i2.activa
             where au.franja_id = p_franja and au.fecha = p_fecha and i2.calle = c.calle) )
      - (select count(*) from public.natacion_reservas r
           where r.franja_id = p_franja and r.fecha = p_fecha and r.calle = c.calle and r.estado = 'reservada')
    )::int as huecos
  from calles c
  order by c.calle;
$$;
revoke all on function public.natacion_huecos_calle(uuid, date) from public, anon;
grant execute on function public.natacion_huecos_calle(uuid, date) to authenticated;

-- NO VOY (avisando) → guarda la ausencia y suma +1 al abono. Solo el propio
-- nadador, solo en SU franja, solo a futuro (avisando). Sin doble crédito.
create or replace function public.natacion_master_no_voy(p_franja uuid, p_fecha date)
returns jsonb language plpgsql security definer set search_path = 'public' as $$
declare v_acc uuid; v_ins int;
begin
  select acceso_id into v_acc from public.natacion_master_yo();
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'no_master'); end if;
  if p_fecha < current_date then return jsonb_build_object('ok', false, 'error', 'tarde',
    'msg', 'El +1 es avisando: no vale marcar un día que ya pasó.'); end if;
  if not exists (select 1 from public.natacion_inscripciones
      where acceso_id = v_acc and franja_id = p_franja and activa and tipo = 'Máster') then
    return jsonb_build_object('ok', false, 'error', 'no_es_tuya'); end if;

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
end $$;
revoke all on function public.natacion_master_no_voy(uuid, date) from public, anon;
grant execute on function public.natacion_master_no_voy(uuid, date) to authenticated;

-- Deshacer el "no voy" (si al final sí va): quita la ausencia y devuelve el +1.
create or replace function public.natacion_master_si_voy(p_franja uuid, p_fecha date)
returns jsonb language plpgsql security definer set search_path = 'public' as $$
declare v_acc uuid; v_del int;
begin
  select acceso_id into v_acc from public.natacion_master_yo();
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'no_master'); end if;
  delete from public.natacion_ausencias
   where acceso_id = v_acc and franja_id = p_franja and fecha = p_fecha and origen = 'aviso';
  get diagnostics v_del = row_count;
  if v_del > 0 then
    update public.natacion_abonos set saldo = greatest(saldo - 1, 0), updated_at = now()
     where acceso_id = v_acc;
  end if;
  return jsonb_build_object('ok', true, 'quitado', v_del > 0,
    'saldo', (select saldo from public.natacion_abonos where acceso_id = v_acc));
end $$;
revoke all on function public.natacion_master_si_voy(uuid, date) from public, anon;
grant execute on function public.natacion_master_si_voy(uuid, date) to authenticated;

-- Franjas de un día donde el nadador PUEDE gastar un bono: las que tienen una
-- calle a la que él llega (calle_num <= la suya) con hueco. Devuelve la mejor
-- calle disponible (la más alta a la que llega, empezando por la suya).
create or replace function public.natacion_master_disponibles(p_fecha date)
returns table(franja_id uuid, hora time, grupo text, calle text, huecos int)
language plpgsql stable security definer set search_path = 'public' as $$
declare v_calle int;
begin
  select calle_num into v_calle from public.natacion_master_yo();
  if v_calle is null then return; end if;
  return query
  select f.id, f.hora, f.grupo, hc.calle, hc.huecos
  from public.natacion_franjas f
  join lateral (
    select h.calle, h.huecos
    from public.natacion_huecos_calle(f.id, p_fecha) h
    where public._num_calle(h.calle) <= v_calle and h.huecos > 0
    order by public._num_calle(h.calle) desc   -- la más alta a la que llega
    limit 1
  ) hc on true
  where coalesce(f.activa, true) and f.dia = extract(isodow from p_fecha)::smallint
  order by f.hora;
end $$;
revoke all on function public.natacion_master_disponibles(date) from public, anon;
grant execute on function public.natacion_master_disponibles(date) to authenticated;

-- USAR UN BONO: reserva una franja un día. Comprueba saldo, elige calle
-- automáticamente (la más alta a la que llega con hueco), descuenta 1.
create or replace function public.natacion_master_usar_bono(p_franja uuid, p_fecha date)
returns jsonb language plpgsql security definer set search_path = 'public' as $$
declare v_acc uuid; v_nombre text; v_calle_num int; v_saldo int; v_calle text;
begin
  select acceso_id, nombre, calle_num into v_acc, v_nombre, v_calle_num from public.natacion_master_yo();
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'no_master'); end if;
  if p_fecha < current_date then return jsonb_build_object('ok', false, 'error', 'fecha',
    'msg', 'No puedes reservar un día que ya pasó.'); end if;

  select saldo into v_saldo from public.natacion_abonos where acceso_id = v_acc;
  if coalesce(v_saldo, 0) <= 0 then
    return jsonb_build_object('ok', false, 'error', 'sin_saldo', 'msg', 'No te quedan bonos. Marca "no voy" un día para ganar uno.'); end if;

  if not (coalesce(exists(select 1 from public.natacion_franjas where id = p_franja and coalesce(activa,true)
             and dia = extract(isodow from p_fecha)::smallint), false)) then
    return jsonb_build_object('ok', false, 'error', 'franja', 'msg', 'Esa franja no es de ese día.'); end if;

  -- Ya tiene reserva o es su franja fija ese día → no tiene sentido gastar bono.
  if exists(select 1 from public.natacion_reservas where acceso_id = v_acc and franja_id = p_franja and fecha = p_fecha and estado = 'reservada') then
    return jsonb_build_object('ok', false, 'error', 'ya_reservada', 'msg', 'Ya tienes esa sesión reservada.'); end if;

  -- Elige la calle: la más alta a la que llega con hueco.
  select h.calle into v_calle
  from public.natacion_huecos_calle(p_franja, p_fecha) h
  where public._num_calle(h.calle) <= v_calle_num and h.huecos > 0
  order by public._num_calle(h.calle) desc
  limit 1;
  if v_calle is null then
    return jsonb_build_object('ok', false, 'error', 'sin_hueco', 'msg', 'No hay hueco en ninguna calle a la que llegues ese día.'); end if;

  insert into public.natacion_reservas(franja_id, fecha, acceso_id, nombre, calle, estado, creada_por)
    values (p_franja, p_fecha, v_acc, coalesce(v_nombre, (select nombre from public.natacion_accesos where id = v_acc)),
            v_calle, 'reservada', public.mi_perfil_id());
  update public.natacion_abonos set saldo = saldo - 1, updated_at = now() where acceso_id = v_acc;

  return jsonb_build_object('ok', true, 'calle', v_calle, 'saldo', v_saldo - 1);
end $$;
revoke all on function public.natacion_master_usar_bono(uuid, date) from public, anon;
grant execute on function public.natacion_master_usar_bono(uuid, date) to authenticated;

-- Cancelar una reserva hecha con bono → devuelve el +1 (solo la suya, a futuro).
create or replace function public.natacion_master_cancelar(p_reserva uuid)
returns jsonb language plpgsql security definer set search_path = 'public' as $$
declare v_acc uuid; v_r record;
begin
  select acceso_id into v_acc from public.natacion_master_yo();
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'no_master'); end if;
  select * into v_r from public.natacion_reservas where id = p_reserva and acceso_id = v_acc;
  if v_r is null then return jsonb_build_object('ok', false, 'error', 'no_es_tuya'); end if;
  if v_r.fecha < current_date then return jsonb_build_object('ok', false, 'error', 'pasada'); end if;
  delete from public.natacion_reservas where id = p_reserva;
  update public.natacion_abonos set saldo = saldo + 1, updated_at = now() where acceso_id = v_acc;
  return jsonb_build_object('ok', true, 'saldo', (select saldo from public.natacion_abonos where acceso_id = v_acc));
end $$;
revoke all on function public.natacion_master_cancelar(uuid) from public, anon;
grant execute on function public.natacion_master_cancelar(uuid) to authenticated;

-- Mi estado de bonos: saldo + mis próximas reservas + mis próximos "no voy".
create or replace function public.natacion_master_estado()
returns jsonb language sql stable security definer set search_path = 'public' as $$
  with yo as (select acceso_id, nombre, calle_num from public.natacion_master_yo())
  select case when (select acceso_id from yo) is null then jsonb_build_object('es_master', false)
  else jsonb_build_object(
    'es_master', true,
    'nombre', (select nombre from yo),
    'calle', (select calle_num from yo),
    'saldo', coalesce((select saldo from public.natacion_abonos where acceso_id = (select acceso_id from yo)), 0),
    'reservas', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'fecha', r.fecha,
        'hora', to_char(f.hora,'HH24:MI'), 'grupo', f.grupo, 'calle', r.calle) order by r.fecha)
      from public.natacion_reservas r join public.natacion_franjas f on f.id = r.franja_id
      where r.acceso_id = (select acceso_id from yo) and r.estado = 'reservada' and r.fecha >= current_date), '[]'::jsonb),
    'no_voy', coalesce((select jsonb_agg(jsonb_build_object('franja_id', a.franja_id, 'fecha', a.fecha,
        'hora', to_char(f.hora,'HH24:MI'), 'grupo', f.grupo) order by a.fecha)
      from public.natacion_ausencias a join public.natacion_franjas f on f.id = a.franja_id
      where a.acceso_id = (select acceso_id from yo) and a.origen = 'aviso' and a.fecha >= current_date), '[]'::jsonb)
  ) end;
$$;
revoke all on function public.natacion_master_estado() from public, anon;
grant execute on function public.natacion_master_estado() to authenticated;

commit;
