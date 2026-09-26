-- 234 · Freno anti-abuso para altas públicas llamadas desde un Edge (pentest, MEDIO)
--
-- socio-cuenta NO tenía límite de peticiones, a diferencia de acceso-enlace
-- (acceso_pedir_apuntar) o la liga (anti_spam). Sin freno, cualquiera podía
-- crear cuentas en masa o enumerar correos aporreando el Edge.
--
-- El trigger frenar_spam_form() ya frena los formularios que insertan directos
-- desde el navegador (usa ip_peticion(), que ve la IP real del que inserta).
-- Pero socio-cuenta crea la cuenta con la llave de servicio (Auth admin + PATCH
-- perfiles), sin INSERT anónimo que dispare el trigger, y por ahí ip_peticion()
-- vería la IP del propio Edge. Así que aquí va un freno CALLABLE: el Edge calcula
-- un hash del IP del usuario (como acceso-enlace) y lo pasa como "origen".
--
-- Reutiliza la tabla altas_intentos ya existente (columnas tipo, ip); guardamos
-- el hash del origen en "ip" y etiquetamos con "tipo".

create or replace function public.alta_ritmo(
  p_tipo    text,
  p_origen  text,
  p_max     int      default 30,
  p_ventana interval default interval '1 hour'
) returns boolean
language plpgsql security definer set search_path to 'public' as $$
declare v_n int;
begin
  delete from public.altas_intentos where creado_en < now() - interval '1 day';

  -- Sin origen no se puede frenar por origen: se apunta y se deja pasar (el
  -- honeypot del formulario y el tope global de la infraestructura siguen).
  if coalesce(p_origen, '') = '' then
    insert into public.altas_intentos (tipo, ip) values (p_tipo, '');
    return true;
  end if;

  select count(*) into v_n
    from public.altas_intentos
   where tipo = p_tipo and ip = p_origen
     and creado_en > now() - p_ventana;

  -- Se apunta pase lo que pase: si no, quien se pasa nunca acumularía.
  insert into public.altas_intentos (tipo, ip) values (p_tipo, p_origen);

  return v_n < p_max;
end;
$$;

revoke all on function public.alta_ritmo(text, text, int, interval) from public;
grant execute on function public.alta_ritmo(text, text, int, interval) to service_role;
