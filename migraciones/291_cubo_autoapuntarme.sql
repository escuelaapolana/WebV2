-- 291 · El Cubo: apuntarse a un grupo de PAGO desde el propio portal
-- Para quien YA tiene cuenta (p.ej. probó la fuerza gratis del finde): se
-- apunta a un grupo del Cubo entre semana sin rellenar el formulario público.
-- Reaprovecha su cuenta y su ficha, engancha el grupo (para que lo vea en la
-- app) y deja el alta PENDIENTE → Andrés la aprueba y pasa a «de prueba»
-- (entra en el tracker). Mismo modelo que el formulario (Edge cubo-alta),
-- pero desde dentro y sin re-teclear datos.

create or replace function public.cubo_autoapuntarme(p_slot text, p_dias int, p_dia int default 0)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_email    text := lower(auth.jwt() ->> 'email');
  v_perfil   uuid;
  v_nombre   text; v_apellidos text; v_tel text;
  v_horario  text;            -- nombre del grupo (El Cubo · …)
  v_grupo    uuid;
  v_act      boolean;
  v_slotdias int[];
  v_diassem  int[];
  v_reducido boolean;
  v_precio   int;
  v_atleta   uuid;
  v_limite   int;
  v_ocup     int;
  v_espera   boolean := false;
  v_id       uuid;
begin
  if v_email is null then
    return jsonb_build_object('ok', false, 'error', 'Tienes que iniciar sesión.');
  end if;
  select id, nombre, apellidos, telefono
    into v_perfil, v_nombre, v_apellidos, v_tel
    from perfiles where lower(email) = v_email;
  if v_perfil is null then
    return jsonb_build_object('ok', false, 'error', 'No encontramos tu cuenta.');
  end if;

  -- slot → grupo + días del turno
  v_horario := case p_slot
    when 'lx-1730' then 'El Cubo · L y X 17:30'
    when 'mj-1730' then 'El Cubo · M y J 17:30'
    when 'lx-1845' then 'El Cubo · L y X 18:45'
    else null end;
  if v_horario is null then
    return jsonb_build_object('ok', false, 'error', 'Elige un horario de la lista.');
  end if;
  if p_dias not in (1, 2) then
    return jsonb_build_object('ok', false, 'error', 'Indica si vienes uno o dos días.');
  end if;
  v_slotdias := case when p_slot like 'mj%' then array[2,4] else array[1,3] end;
  -- 2 días = los dos del turno; 1 día = el que eligió (si no cuadra, queda null
  -- y en la lista de Claudia se le ven los dos hasta marcarlo).
  v_diassem := case
    when p_dias = 2 then v_slotdias
    when p_dia = any(v_slotdias) then array[p_dia]
    else null end;

  -- grupo (existe y está activo)
  select id, coalesce(activo, true) into v_grupo, v_act
    from grupos where seccion = 'cubo' and nombre = v_horario limit 1;
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Ese grupo no está disponible.');
  end if;

  -- ¿ya está apuntado a ESTE grupo? (no duplicar)
  if exists (select 1 from cubo_altas
               where perfil_id = v_perfil and horario = v_horario
                 and estado <> 'rechazada'
                 and coalesce(suscripcion_estado, '') <> 'cancelada') then
    return jsonb_build_object('ok', false, 'error', 'Ya estás apuntado a ese grupo.');
  end if;

  -- precio reducido si es familia de escuela o socio
  v_reducido := exists (
    select 1 from atletas a
     where (a.perfil_id = v_perfil or a.perfil_padre_id = v_perfil)
       and a.tipo_membresia in ('socio', 'escuela'));
  v_precio := case when v_reducido then (case when p_dias = 1 then 20 else 30 end)
                   else (case when p_dias = 1 then 30 else 40 end) end;

  -- aforo: si el turno está lleno, va a lista de espera
  select coalesce(limite_grupo, 20) into v_limite from cubo_config where id = 1;
  select count(*) into v_ocup from cubo_altas
    where horario = v_horario and not lista_espera and estado <> 'rechazada';
  if coalesce(v_limite,0) > 0 and v_ocup >= v_limite then v_espera := true; end if;

  -- ficha: reaprovecha la suya; si no tiene, se crea tipo cubo
  select id into v_atleta from atletas where perfil_id = v_perfil limit 1;
  if v_atleta is null then
    insert into atletas (perfil_id, nombre, apellidos, email, telefono, tipo_membresia, estado)
    values (v_perfil, coalesce(v_nombre, ''), coalesce(v_apellidos, ''),
            v_email, v_tel, 'cubo', 'prueba')
    returning id into v_atleta;
  end if;

  -- alta PENDIENTE (Andrés la aprueba → de prueba → tracker)
  insert into cubo_altas (nombre, apellidos, telefono, horario, dias, dias_semana,
                          precio_mes, estado, perfil_id, atleta_id, lista_espera,
                          es_escuela, es_socio)
  values (coalesce(v_nombre, ''), coalesce(v_apellidos, ''), coalesce(v_tel, ''),
          v_horario, p_dias, v_diassem, v_precio, 'pendiente',
          v_perfil, v_atleta, v_espera, false, v_reducido)
  returning id into v_id;

  -- enganche al grupo para que lo vea en su app (salvo lista de espera).
  -- Directo en atleta_grupos (ignora duplicado); y si la ficha no tenía grupo
  -- principal, se lo ponemos (el disparador deja ese como principal).
  if not v_espera then
    insert into atleta_grupos (atleta_id, grupo_id, principal)
    values (v_atleta, v_grupo, false)
    on conflict (atleta_id, grupo_id) do nothing;
    update atletas set grupo_id = v_grupo where id = v_atleta and grupo_id is null;
  end if;

  -- papel del Cubo, sin quitarle los que tenga
  update perfiles
     set roles = coalesce(roles, case when rol is not null then array[rol] else '{}'::text[] end) || array['cubo-atleta']
   where id = v_perfil and not ('cubo-atleta' = any(coalesce(roles, '{}'::text[])));

  return jsonb_build_object('ok', true, 'lista_espera', v_espera, 'grupo', v_horario);
end;
$$;

grant execute on function public.cubo_autoapuntarme(text, int, int) to authenticated;
