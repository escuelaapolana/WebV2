-- 509 · El Cubo: el sábado es gratis SOLO para socios y familias de la escuela
-- ---------------------------------------------------------------------------
-- Andrés (3-nov-2026), sobre la 508: «el sábado es gratis para socios del club
-- y padres/madres de la escuela; los demás no». Para el resto el sábado cuenta
-- como un día de pago más: 1 día 30 €, 2 días 40 €, 3 días (L y X + sábado)
-- 50 €. Reducido: el sábado no suma (sigue siendo su precio de 1 o 2 días).
--
-- · tarifa nueva 'cubo-3dias' (50 €, sin sección: no sale en la web).
-- · cubo_precio admite p_dias = 3 (general → cubo-3dias; reducido → su precio
--   de 2 días, por si alguien lo llama así).
-- · cubo_precios() devuelve también '3'.
-- · cubo_autoapuntarme: precio con el sábado sumado si no es reducido.
-- cubo_altas.dias sigue siendo los días ENTRE SEMANA (1 o 2); el sábado va en
-- la nota y en el grupo del sábado.

insert into tarifas (clave, ambito, concepto, seccion, dias, importe_socio, periodicidad, vigente_desde, notas, avisar_email, orden, activo)
select 'cubo-3dias', 'cubo', 'El Cubo · adultos · 3 días (con sábado)', null, '3 sesiones', 50, 'mensual', '2026-07-31',
       'Quien no es socio ni familia de la escuela y suma el sábado 9:00 a sus dos días. La usa el alta del Cubo. Sin sección para que no salga en la web.',
       false, 12, true
where not exists (select 1 from tarifas where clave = 'cubo-3dias');

create or replace function public.cubo_precio(p_dias integer, p_reducido boolean)
 returns integer
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select round(t.importe_socio)::int
    from public.tarifas t
   where p_dias in (1, 2, 3)
     and t.clave = case
           when coalesce(p_reducido, false) then
             case when p_dias = 1 then 'cubo-1dia-reducido' else 'cubo-padres-escuela' end
           else
             case p_dias when 1 then 'cubo-1dia' when 2 then 'cubo-padres' else 'cubo-3dias' end
         end
     and t.activo
     and t.importe_socio is not null
     and t.vigente_desde <= current_date
     and (t.vigente_hasta is null or t.vigente_hasta > current_date)
   order by t.vigente_desde desc
   limit 1;
$function$;

create or replace function public.cubo_precios()
 returns jsonb
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select jsonb_build_object(
    'reducido', jsonb_build_object('1', public.cubo_precio(1, true),  '2', public.cubo_precio(2, true),  '3', public.cubo_precio(3, true)),
    'general',  jsonb_build_object('1', public.cubo_precio(1, false), '2', public.cubo_precio(2, false), '3', public.cubo_precio(3, false))
  );
$function$;

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

grant execute on function public.cubo_autoapuntarme(text, integer, integer, boolean) to authenticated;
