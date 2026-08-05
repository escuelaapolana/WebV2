-- ============================================================
-- LO QUE TOCA EL ENTRENADOR DE UNA FICHA
-- ------------------------------------------------------------
-- Aviso primero, porque lo que yo mismo conté estaba mal: dije que un
-- entrenador podía cambiar CUALQUIER campo de la ficha de sus atletas,
-- incluido el tipo de socio. Me quedé mirando la regla de la tabla, que
-- efectivamente no distingue campos, y no vi que había además un
-- disparador que sí los distingue. Comprobado uno por uno: el tipo de
-- socio, la cuota, el DNI, el nombre, la fecha de nacimiento, el correo
-- y el teléfono de la familia YA estaban cerrados. No había agujero.
--
-- Lo que sí ha aparecido al mirarlo de cerca son dos problemas, y los
-- dos son de quedarse corto, no de pasarse:
--
--   1. EL QUE ESCUECE: ese disparador solo deja pasar a administración.
--      Tesorería y contabilidad se lo comen igual que un entrenador, y
--      con un mensaje que encima habla de entrenadores. Resultado: hoy,
--      en esta base, tesorería NO puede etiquetar a nadie como socio o
--      escuela, NI fijar una cuota, NI aprobar una propuesta de cuota,
--      NI crear una ficha desde un alta. Cuatro herramientas suyas
--      rotas, y ninguna avisa de por qué.
--
--   2. EL QUE SE DESCUBRE EN SEPTIEMBRE: al entrenador se le quedó
--      fuera media pista. Puede escribir observaciones, pero NO puede
--      poner las especialidades de un atleta, ni sus pruebas, ni los
--      días que entrena, ni si hace gimnasio, ni los pasos entre
--      vallas. Eso es su trabajo, no papeleo del club.
--
-- Así que esta migración no cierra nada nuevo: reparte mejor lo que ya
-- estaba repartido. Lo del dinero y lo de la identidad sigue cerrado
-- exactamente igual que antes.
-- ============================================================

create or replace function public.atletas_cambios_del_entrenador()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  -- LO QUE ES SUYO. La norma para estar en esta lista es sencilla: si
  -- es algo que se decide en la pista, entra; si es algo que se decide
  -- en la oficina o en casa de la familia, no.
  permitidas text[] := array[
    -- dónde y cómo entrena
    'grupo_id', 'dias_entreno', 'hace_gym', 'tiene_fisio', 'dia_fisio',
    -- a qué se dedica dentro del atletismo
    'especialidades', 'pruebas_principales', 'pruebas_secundarias',
    -- detalles técnicos de su forma de correr y saltar
    'perfil_velocista', 'pierna_ataque', 'pasos_entre_vallas',
    -- si está entero, lesionado, de baja, o acabando la prueba
    'estado', 'fecha_prueba_fin',
    -- lo que el entrenador anota de él
    'observaciones', 'contexto_entrenador',
    -- esto lo pone la propia base al guardar
    'updated_at'
  ];
  -- LO QUE NO ES SUYO, y sigue igual de cerrado que hasta hoy:
  --   · el dinero: tipo_membresia, cuota_mensual y todo su rastro
  --   · quién es: nombre, apellidos, fecha_nacimiento, sexo, dni,
  --     categoría (que además se calcula sola) y la licencia
  --   · la familia: perfil_id, perfil_padre_id, y los correos y
  --     teléfonos de la madre o el padre
  --   · quién le entrena: entrenador_id, para que nadie se quede con
  --     un atleta de otro ni suelte a uno suyo por su cuenta
  --   · lo que escribe el propio atleta sobre sí mismo: contexto_atleta
  viejo jsonb := to_jsonb(old);
  nuevo jsonb := to_jsonb(new);
  c text;
  cambiadas text[];
begin
  new.updated_at := now();

  -- Quién pasa de largo por esta puerta.
  --
  -- Sin sesión del portal no hay nadie a quien limitar: son las tareas
  -- del propio sistema (importaciones, avisos automáticos, enganchar la
  -- ficha de alguien que acaba de crearse la cuenta).
  --
  -- Y administración, tesorería y contabilidad tampoco pasan por aquí.
  -- Lo de tesorería es el arreglo de hoy: sus herramientas cambian a
  -- propósito el tipo de socio y la cuota —para eso están—, y este
  -- disparador se las estaba tumbando con un mensaje sobre entrenadores
  -- que no había manera de entender desde la pantalla.
  if (auth.jwt() ->> 'email') is null
     or public.es_admin()
     or public.ve_dinero() then
    return new;
  end if;

  foreach c in array permitidas loop
    viejo := viejo - c;
    nuevo := nuevo - c;
  end loop;

  -- Se mira campo a campo en vez de todo de golpe, para poder DECIR cuál
  -- es el que sobra. Antes el aviso era el mismo pasara lo que pasara, y
  -- desde una pantalla que guarda la ficha entera no había forma de
  -- saber qué campo la estaba atascando.
  select array_agg(k order by k) into cambiadas
    from jsonb_object_keys(nuevo) k
   where (nuevo -> k) is distinct from (viejo -> k);

  if cambiadas is not null then
    raise exception
      'Esto de la ficha no lo lleva el entrenador: %. Lo cambia administración; si hay que corregirlo, avisa al club.',
      array_to_string(cambiadas, ', ');
  end if;

  -- Y aunque el grupo sí es cosa suya, solo puede moverlo a un grupo que
  -- dirija él: cambiar de grupo cambia el horario y a menudo el recibo,
  -- así que soltar a un atleta en el grupo de otro no es cosa de uno.
  if new.grupo_id is distinct from old.grupo_id and new.grupo_id is not null then
    if not exists (select 1 from public.grupos g
                    where g.id = new.grupo_id and g.entrenador_id = public.mi_perfil_id()) then
      raise exception 'Solo puedes mover al atleta a un grupo que dirijas tú. Para pasarlo a otro entrenador, avisa a administración.';
    end if;
  end if;

  return new;
end; $$;

comment on function public.atletas_cambios_del_entrenador() is
  'Decide qué campos de una ficha puede tocar un entrenador: lo de la '
  'pista sí, lo del dinero y lo de la identidad no. Administración, '
  'tesorería y contabilidad no pasan por aquí.';
