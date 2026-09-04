-- ============================================================
-- 145 · Freno anti-spam en /contacto/ y /prueba/
-- ------------------------------------------------------------
-- HALLAZGO (auditoría sep 2026): /contacto/ (tabla `mensajes`) y /prueba/
-- (tabla `solicitudes_inscripcion`) aceptan INSERT anónimo SIN límite de
-- frecuencia. Un script podría insertar miles de mensajes y llenar el buzón /
-- la base. No es fuga de datos (el RLS impide leerlos), es abuso/DoS de
-- contenido. Las ALTAS ya tienen freno (migración 114); esto le pone el mismo
-- tipo de freno a estos dos formularios, reutilizando `ip_peticion()` y la
-- tabla `altas_intentos` que ya existen.
--
-- PRINCIPIO: FALLAR EN ABIERTO. Si no se puede leer la IP, o cualquier cosa va
-- rara al contar, se DEJA PASAR. Preferimos que un día no frene a un bot antes
-- que bloquear a una familia que quiere apuntarse. El tope es GENEROSO (30 por
-- IP y hora): una persona real jamás lo alcanza; un bot que dispara cientos, sí.
--
-- Idempotente: se puede volver a pasar. No borra nada.
-- ============================================================
begin;

-- La función del disparador: cuenta cuántos envíos de ese tipo ha hecho esta
-- IP en la última hora y, si se pasa del tope, corta. Apunta el intento
-- siempre (como la 114). Todo envuelto: si algo falla que NO sea el tope, deja
-- pasar (fail-open).
create or replace function public.frenar_spam_form()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_tipo text := TG_ARGV[0];
  v_tope int  := coalesce(nullif(TG_ARGV[1], '')::int, 30);
  v_ip   text;
  v_n    int;
begin
  begin
    v_ip := public.ip_peticion();
    -- Sin IP no se puede frenar por IP: se deja pasar (el tope global de la
    -- infraestructura y el honeypot del formulario siguen actuando).
    if v_ip is null or v_ip = '' then
      return NEW;
    end if;

    select count(*) into v_n
      from public.altas_intentos
     where tipo = v_tipo
       and ip = v_ip
       and creado_en > now() - interval '1 hour';

    if v_n >= v_tope then
      raise exception 'Demasiados envíos desde aquí en poco rato. Prueba de nuevo en un rato, o escríbenos por teléfono.'
        using errcode = 'P0001';
    end if;

    insert into public.altas_intentos (tipo, ip) values (v_tipo, v_ip);
  exception
    when others then
      -- Si es NUESTRA excepción de tope, propágala (corta el spam). Cualquier
      -- otro fallo (leer cabeceras, contar…): se traga y se deja pasar.
      if SQLSTATE = 'P0001' then raise; end if;
      return NEW;
  end;

  return NEW;
end;
$$;

comment on function public.frenar_spam_form() is
  'Disparador BEFORE INSERT: frena por IP los formularios públicos (contacto/prueba). Falla en abierto: sin IP o ante cualquier fallo que no sea el tope, deja pasar.';

-- /contacto/ → tabla mensajes
drop trigger if exists trg_frenar_spam_mensajes on public.mensajes;
create trigger trg_frenar_spam_mensajes
  before insert on public.mensajes
  for each row execute function public.frenar_spam_form('contacto', '30');

-- /prueba/ y preinscripción → tabla solicitudes_inscripcion
drop trigger if exists trg_frenar_spam_solicitudes on public.solicitudes_inscripcion;
create trigger trg_frenar_spam_solicitudes
  before insert on public.solicitudes_inscripcion
  for each row execute function public.frenar_spam_form('prueba', '30');

commit;

-- ------------------------------------------------------------
-- CÓMO PROBAR (sin dejar basura): dentro de una transacción que se deshace,
-- insertar 31 filas rápidas con la misma IP simulada y ver que la nº 31 falla,
-- y que UNA sola pasa. Como el INSERT anónimo real trae la IP por cabecera,
-- en psql (sin cabecera) `ip_peticion()` devuelve '' y el trigger deja pasar
-- —por eso conviene probar el conteo forzando `v_ip` en un test, o confiar en
-- que el camino de producción (con cabecera) es el que cuenta.
-- ------------------------------------------------------------
