-- 503 · Auditoría de seguridad 1-nov-2026 (fallos graves)
-- 1) soy_gestor_natacion() incluía es_staff(): cualquier entrenador, junta o
--    tesorería leía DNI/teléfonos de solicitudes y los códigos de acceso de las
--    familias, y podía borrar inscripciones. Queda: sistema, admin y
--    responsables gestores de natación / escuela de natación (Mario).
-- 2) alta_entrenador() delataba si un correo tenía cuenta ('perfil'/'invitado').
--    Ahora responde siempre igual; la Edge entrenador-alta lo comprueba por su cuenta.

create or replace function public.soy_gestor_natacion()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select coalesce(current_setting('apolana.sistema', true), '') = 'natacion'
      or public.es_admin() or exists (
    select 1 from public.responsable_seccion rs
    join public.perfiles p on p.id = rs.perfil_id
    where p.email = (auth.jwt() ->> 'email') and coalesce(p.activo, true)
      and rs.seccion in ('natacion','escuela-natacion') and coalesce(rs.gestor, true)
  );
$$;

create or replace function public.alta_entrenador(p jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_email     text := lower(public.texto_de_fuera(p ->> 'email', 160));
  v_nombre    text := public.texto_de_fuera(p ->> 'nombre', 120);
  v_apellidos text := coalesce(public.texto_de_fuera(p ->> 'apellidos', 120), '');
  v_segundos  int  := coalesce((p ->> 'segundos')::int, 0);
begin
  if public.texto_de_fuera(p ->> 'apellido_de_soltera', 100) is not null
     or v_segundos < 5 then
    return jsonb_build_object('ok', true, 'ya', 'nuevo');
  end if;
  if coalesce(auth.role(), '') <> 'service_role' then
    perform public.anti_spam('alta_entrenador', 5, interval '1 hour');
  end if;
  if v_email is null or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'motivo', 'correo',
      'mensaje', 'Ese correo no parece bien escrito. Revísalo, por favor.');
  end if;
  if v_nombre is null then
    return jsonb_build_object('ok', false, 'motivo', 'nombre', 'mensaje', 'Pon tu nombre.');
  end if;
  -- 503 · Misma respuesta exista o no (no delatar quién tiene cuenta).
  if exists (select 1 from public.perfiles where lower(email) = v_email)
     or exists (select 1 from public.invitaciones_equipo where email = v_email and usado_en is null) then
    return jsonb_build_object('ok', true, 'ya', 'nuevo');
  end if;
  insert into public.invitaciones_equipo (email, nombre, apellidos, rol, roles)
  values (v_email, v_nombre, v_apellidos, 'pendiente', array['pendiente']);
  return jsonb_build_object('ok', true, 'ya', 'nuevo');
end;
$function$;
