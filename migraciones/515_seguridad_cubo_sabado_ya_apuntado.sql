-- 515 · Seguridad (revisión 4-nov-2026) · El Cubo: el sábado gratis solo para
-- socios y familias de la escuela, también para quien YA estaba apuntado
-- ---------------------------------------------------------------------------
-- Fallo: en cubo_autoapuntarme (509) el camino «¿ya está apuntado a este
-- grupo?» enganchaba el grupo del sábado ANTES de mirar si era socio/escuela.
-- Un no socio ya apuntado (p. ej. 2 días, 40 €) volvía a llamar con
-- p_sabado = true y entraba al sábado sin pasar a la cuota de 3 días (50 €),
-- sin nota en su alta. Ahora v_reducido se calcula antes y, si no es
-- reducido, ese camino no engancha el sábado: le dice que escriba al club.
-- El resto de la función queda IGUAL que en la 509 (mismos permisos).

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

  -- [515] Se calcula ANTES de mirar si ya estaba apuntado: ese camino también
  -- engancha el sábado y tiene que respetar la regla de la 509.
  v_reducido := exists (
    select 1 from atletas a
     where (a.perfil_id = v_perfil or a.perfil_padre_id = v_perfil)
       and a.tipo_membresia in ('socio', 'escuela'));

  -- ¿ya está apuntado a ESTE grupo? Si además pide el sábado, se le añade
  -- (solo si para él es gratis; si no, cambia su cuota y lo hace el club).
  if exists (select 1 from cubo_altas
               where perfil_id = v_perfil and horario = v_horario
                 and estado <> 'rechazada'
                 and coalesce(suscripcion_estado, '') <> 'cancelada') then
    if v_sab is not null and not v_reducido then
      return jsonb_build_object('ok', false, 'error',
        'El sábado cuenta como un día más en tu cuota. Escríbenos y te lo sumamos.');
    end if;
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

  -- [509] el sábado es gratis para socios y familias de la escuela; para el
  -- resto cuenta como un día más (2+sábado = 3 días).
  v_precio := public.cubo_precio(p_dias + case when v_sab is not null and not v_reducido then 1 else 0 end, v_reducido);
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
          case when v_sab is not null then
            case when v_reducido then 'También los sábados 9:00 (fuerza, gratis).'
                 else 'También los sábados 9:00 (cuenta como un día más).' end end)
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
