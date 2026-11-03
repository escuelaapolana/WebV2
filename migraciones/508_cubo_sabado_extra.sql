-- 508 · El Cubo: «también los sábados» al apuntarse (3-nov-2026)
-- ---------------------------------------------------------------------------
-- Andrés: la sesión del sábado 9:00 (El Cubo · Fuerza gratis) continúa y la
-- gente tiene que poder elegirla al apuntarse (caso Bibiana: L y X 18:45 +
-- sábado). Decisión: el sábado SIGUE GRATIS, es un extra; la cuota se calcula
-- igual que antes por los días entre semana (1 o 2). 3 días = precio de 2.
--
-- cubo_autoapuntarme gana p_sabado: si viene a true, además del grupo de pago
-- se le engancha al grupo del sábado (atleta_grupos). Si ya estaba apuntado a
-- ese turno de pago y solo pide el sábado, se le añade el sábado sin error.
-- La firma vieja (3 argumentos) se borra para que la llamada con nombres no
-- sea ambigua.

drop function if exists public.cubo_autoapuntarme(text, integer, integer);

create or replace function public.cubo_sabado_grupo()
returns uuid language sql stable security definer set search_path = public as $$
  select id from grupos
   where seccion = 'cubo' and coalesce(activo, true)
     and nombre = 'El Cubo · Fuerza gratis · Sábado 9:00'
   limit 1
$$;
revoke all on function public.cubo_sabado_grupo() from public, anon, authenticated;

create or replace function public.cubo_autoapuntarme(p_slot text, p_dias integer, p_dia integer default 0, p_sabado boolean default false)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_email    text := lower(auth.jwt() ->> 'email');
  v_perfil   uuid;
  v_nombre   text; v_apellidos text; v_tel text;
  v_horario  text;
  v_grupo    uuid;
  v_act      boolean;
  v_slotdias int[];
  v_diassem  int[];
  v_reducido boolean;
  v_precio   int;
  v_atleta   uuid;
  v_espera   boolean := false;
  v_id       uuid;
  v_sab      uuid;
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
  v_diassem := case
    when p_dias = 2 then v_slotdias
    when p_dia = any(v_slotdias) then array[p_dia]
    else null end;

  select id, coalesce(activo, true) into v_grupo, v_act
    from grupos where seccion = 'cubo' and nombre = v_horario limit 1;
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Ese grupo no está disponible.');
  end if;

  v_sab := case when p_sabado then public.cubo_sabado_grupo() end;

  -- ¿ya está apuntado a ESTE grupo? Si además pide el sábado, se le añade.
  if exists (select 1 from cubo_altas
               where perfil_id = v_perfil and horario = v_horario
                 and estado <> 'rechazada'
                 and coalesce(suscripcion_estado, '') <> 'cancelada') then
    if v_sab is not null then
      select id into v_atleta from atletas where perfil_id = v_perfil limit 1;
      if v_atleta is not null then
        insert into atleta_grupos (atleta_id, grupo_id, principal)
        values (v_atleta, v_sab, false)
        on conflict (atleta_id, grupo_id) do nothing;
        return jsonb_build_object('ok', true, 'lista_espera', false, 'grupo', v_horario, 'sabado', true, 'solo_sabado', true);
      end if;
    end if;
    return jsonb_build_object('ok', false, 'error', 'Ya estás apuntado a ese grupo.');
  end if;

  v_reducido := exists (
    select 1 from atletas a
     where (a.perfil_id = v_perfil or a.perfil_padre_id = v_perfil)
       and a.tipo_membresia in ('socio', 'escuela'));
  v_precio := public.cubo_precio(p_dias, v_reducido);
  if v_precio is null then
    return jsonb_build_object('ok', false, 'error', 'Ahora mismo no podemos calcular la cuota. Escríbenos y te apuntamos.');
  end if;

  v_espera := public.cubo_turno_lleno(v_horario);

  select id into v_atleta from atletas where perfil_id = v_perfil limit 1;
  if v_atleta is null then
    insert into atletas (perfil_id, nombre, apellidos, email, telefono, tipo_membresia, estado)
    values (v_perfil, coalesce(v_nombre, ''), coalesce(v_apellidos, ''),
            v_email, v_tel, 'cubo', 'prueba')
    returning id into v_atleta;
  end if;

  insert into cubo_altas (nombre, apellidos, telefono, horario, dias, dias_semana,
                          precio_mes, estado, perfil_id, atleta_id, lista_espera,
                          es_escuela, es_socio, nota)
  values (coalesce(v_nombre, ''), coalesce(v_apellidos, ''), coalesce(v_tel, ''),
          v_horario, p_dias, v_diassem, v_precio, 'pendiente',
          v_perfil, v_atleta, v_espera, false, v_reducido,
          case when v_sab is not null then 'También los sábados 9:00 (fuerza, gratis).' end)
  returning id into v_id;

  if not v_espera then
    insert into atleta_grupos (atleta_id, grupo_id, principal)
    values (v_atleta, v_grupo, false)
    on conflict (atleta_id, grupo_id) do nothing;
    update atletas set grupo_id = v_grupo where id = v_atleta and grupo_id is null;
  end if;
  -- El sábado es gratis y sin aforo de turno: se engancha siempre.
  if v_sab is not null then
    insert into atleta_grupos (atleta_id, grupo_id, principal)
    values (v_atleta, v_sab, false)
    on conflict (atleta_id, grupo_id) do nothing;
  end if;

  update perfiles
     set roles = coalesce(roles, case when rol is not null then array[rol] else '{}'::text[] end) || array['cubo-atleta']
   where id = v_perfil and not ('cubo-atleta' = any(coalesce(roles, '{}'::text[])));

  return jsonb_build_object('ok', true, 'lista_espera', v_espera, 'grupo', v_horario, 'sabado', v_sab is not null);
end;
$function$;

revoke all on function public.cubo_autoapuntarme(text, integer, integer, boolean) from public, anon;
grant execute on function public.cubo_autoapuntarme(text, integer, integer, boolean) to authenticated;
grant execute on function public.cubo_sabado_grupo() to service_role;
