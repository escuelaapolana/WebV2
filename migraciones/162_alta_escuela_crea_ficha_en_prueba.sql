-- ============================================================
-- 162 · Fase 2 · la inscripción de escuela crea la ficha en «prueba»
-- ------------------------------------------------------------
-- QUÉ HACE
--   Cuando entra una inscripción de escuela, cada niño pasa a tener
--   su ficha SOLA, en estado «prueba», con su grupo, sin que nadie la
--   convierta a mano. Así el niño ya sale en las listas y en «pasar
--   lista» desde el primer día, y al acabar la prueba se confirma en
--   lote (Atletas → «En prueba»).
--
--   · El grupo: el que eligió la familia si vale; si no, el que le toca
--     por su año de nacimiento y su turno (los grupos de escuela con
--     turno, incluidos Recreación 1 y 2).
--   · Si esa persona YA existe (mismo nombre, apellidos y fecha), se
--     enlaza con su ficha en vez de duplicarla.
--   · La fecha de fin de prueba (14 días) la pone sola el disparador de
--     la 156.
--
-- ES UN EXTRA, NUNCA UN OBSTÁCULO
--   Todo va dentro de un bloque que atrapa cualquier fallo: si no se
--   puede crear la ficha (falta el grupo, un dato raro, lo que sea), la
--   INSCRIPCIÓN SE GUARDA IGUAL y el alta se convierte a mano como
--   siempre. Una inscripción no se pierde nunca por esto.
--
--   Los socios no entran aquí: no eligen grupo ni tienen prueba al
--   inscribirse; siguen convirtiéndose a mano.
-- ============================================================

create or replace function public.apo_alta_nino_a_prueba()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_e         record;
  v_grupo     uuid;
  v_nombre    text;
  v_apellidos text;
  v_atleta    uuid;
  v_dup       uuid;
begin
  -- Ya enlazado a una ficha (p. ej. lo convirtieron a mano): no se toca.
  if new.atleta_id is not null then
    return new;
  end if;

  begin
    v_nombre    := nullif(btrim(coalesce(new.nombre_pila, new.nombre)), '');
    v_apellidos := nullif(btrim(concat_ws(' ', new.apellido1, new.apellido2)), '');

    -- Sin lo mínimo, se deja para convertir a mano.
    if v_nombre is null or new.fecha_nacimiento is null then
      return new;
    end if;

    -- El grupo: el elegido por la familia si sigue abierto; si no, el que
    -- le toca por año y turno.
    if new.grupo_id is not null
       and exists (select 1 from public.grupos g where g.id = new.grupo_id and coalesce(g.activo, true)) then
      v_grupo := new.grupo_id;
    elsif nullif(new.turno, '') is not null then
      select g.id into v_grupo
        from public.grupos g
       where g.seccion = 'escuela' and g.turno = new.turno and coalesce(g.activo, true)
         and extract(year from new.fecha_nacimiento) between g.nacidos_desde and g.nacidos_hasta
       limit 1;
    end if;

    -- Sin grupo claro, a mano (no se inventa uno).
    if v_grupo is null then
      return new;
    end if;

    -- ¿Ya existe esa persona? Mismo nombre + apellidos + fecha → se enlaza.
    select a.id into v_dup
      from public.atletas a
     where lower(btrim(a.nombre)) = lower(v_nombre)
       and lower(btrim(coalesce(a.apellidos, ''))) = lower(coalesce(v_apellidos, ''))
       and a.fecha_nacimiento = new.fecha_nacimiento
     limit 1;
    if v_dup is not null then
      new.atleta_id := v_dup;
      return new;
    end if;

    -- El alta padre, para el tutor y el permiso de imagen.
    select * into v_e from public.altas_escuela where id = new.alta_id;

    insert into public.atletas (
      nombre, apellidos, fecha_nacimiento, sexo, dni, estado, tipo_membresia,
      nombre_tutor, email_tutor, telefono_tutor,
      permiso_imagen, permiso_imagen_ambitos, permiso_imagen_en, permiso_imagen_origen)
    values (
      v_nombre, v_apellidos, new.fecha_nacimiento, nullif(new.sexo, ''), nullif(new.dni, ''),
      'prueba', 'escuela',
      nullif(btrim(coalesce(v_e.tutor_nombre,
             concat_ws(' ', v_e.tutor_nombre_pila, v_e.tutor_apellido1, v_e.tutor_apellido2))), ''),
      v_e.tutor_email, v_e.tutor_telefono,
      new.permiso_imagen,
      case when new.permiso_imagen is not null then new.permiso_imagen_ambitos end,
      case when new.permiso_imagen is not null then now() end,
      case when new.permiso_imagen is not null then 'alta' end)
    returning id into v_atleta;

    insert into public.atleta_grupos (atleta_id, grupo_id, principal)
    values (v_atleta, v_grupo, true)
    on conflict (atleta_id, grupo_id) do nothing;

    new.atleta_id := v_atleta;
    return new;

  exception when others then
    -- Cualquier fallo: la inscripción se guarda igual, sin ficha. A mano.
    return new;
  end;
end;
$$;

drop trigger if exists apo_alta_nino_a_prueba on public.altas_escuela_ninos;
create trigger apo_alta_nino_a_prueba
before insert on public.altas_escuela_ninos
for each row execute function public.apo_alta_nino_a_prueba();
