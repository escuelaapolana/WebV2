-- 196 · Auto-alta de entrenadores de la escuela
-- Un entrenador se da de alta solo desde /entrenador/alta/ (enlace que se
-- comparte con ellos). Crea una invitación con rol 'entrenador'; al entrar
-- con su correo (enlace mágico) se le crea el perfil con ese rol.
-- SEGURO: un entrenador nuevo no ve NADA hasta que el club le asigna un grupo
-- (grupos.entrenador_id / atletas.entrenador_id). Con anti-spam básico.

create or replace function public.alta_entrenador(p jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_email     text := lower(public.texto_de_fuera(p ->> 'email', 160));
  v_nombre    text := public.texto_de_fuera(p ->> 'nombre', 120);
  v_apellidos text := coalesce(public.texto_de_fuera(p ->> 'apellidos', 120), '');
  v_segundos  int  := coalesce((p ->> 'segundos')::int, 0);
begin
  -- Honeypot + tiempo mínimo: si un bot rellena el campo trampa o va
  -- demasiado rápido, se finge OK y no se crea nada.
  if public.texto_de_fuera(p ->> 'apellido_de_soltera', 100) is not null
     or v_segundos < 5 then
    return jsonb_build_object('ok', true, 'ya', 'nuevo');
  end if;

  if v_email is null or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'motivo', 'correo',
      'mensaje', 'Ese correo no parece bien escrito. Revísalo, por favor.');
  end if;

  if v_nombre is null then
    return jsonb_build_object('ok', false, 'motivo', 'nombre',
      'mensaje', 'Pon tu nombre.');
  end if;

  -- ¿Ya tiene cuenta? Puede entrar directamente.
  if exists (select 1 from public.perfiles where lower(email) = v_email) then
    return jsonb_build_object('ok', true, 'ya', 'perfil');
  end if;

  -- ¿Ya está invitado y sin usar? No duplicar.
  if exists (select 1 from public.invitaciones_equipo
             where email = v_email and usado_en is null) then
    return jsonb_build_object('ok', true, 'ya', 'invitado');
  end if;

  insert into public.invitaciones_equipo (email, nombre, apellidos, rol, roles)
  values (v_email, v_nombre, v_apellidos, 'entrenador', array['entrenador']);

  return jsonb_build_object('ok', true, 'ya', 'nuevo');
end;
$function$;

grant execute on function public.alta_entrenador(jsonb) to anon, authenticated;
