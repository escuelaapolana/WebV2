-- ============================================================
-- 135 · El permiso de las fotos llega a la pista
-- ------------------------------------------------------------
-- EL AGUJERO, DICHO SIN ADORNOS
-- Al apuntar a un hijo, la familia contesta si podemos publicar sus
-- fotos. Esa respuesta se guarda desde la 114, y se guarda bien: en
-- `altas_escuela_ninos.permiso_imagen`, con los canales a los que se
-- refiere y con la pregunta literal que se le hizo.
--
-- El problema es DÓNDE se queda. El alta solo la ven administración y
-- tesorería. Quien está en la pista un martes por la tarde con el
-- móvil en la mano es el entrenador, y la ficha del atleta no tenía
-- ninguna casilla para esto. O sea que un entrenador podía subir a
-- Instagram la foto de un crío cuya familia había dicho que no, sin
-- ninguna manera de saberlo. No por descuido suyo: porque nadie se lo
-- había dicho.
--
-- Es el mismo fallo que el de las alergias, pero al revés. Allí el dato
-- no se preguntaba; aquí se pregunta, se guarda, y se queda encerrado
-- donde no lo ve quien lo necesita. Un dato que no llega a tiempo a
-- quien decide es igual que no tenerlo.
--
-- ------------------------------------------------------------
-- LO QUE HACE ESTA MIGRACIÓN
--   1. Cuatro casillas nuevas en `atletas`, para que el permiso viva
--      donde el entrenador ya mira.
--   2. `alta_crear_ficha` las rellena al convertir el alta en ficha,
--      igual que hace con el resto de los datos.
--   3. Lo que ya se convirtió antes de hoy, se rescata del alta.
--
-- ------------------------------------------------------------
-- LA DECISIÓN QUE MÁS IMPORTA: VACÍO NO ES «SÍ»
-- La casilla nace SIN valor por defecto, y eso es a propósito. Los
-- atletas que hoy están en el club entraron antes de que se preguntara
-- nada, así que de ellos NO SE SABE. Poner un `default true` habría
-- dejado la base bonita y habría sido mentira: se estaría dando por
-- autorizado a doscientos críos a los que nadie preguntó.
--
-- Y el otro extremo tampoco: poner `default false` diría «esta familia
-- dijo que no», que también es falso y además es feo, porque acusa a
-- una familia de algo que no ha dicho.
--
-- Vacío quiere decir NO CONSTA, y eso es lo que se enseña en pantalla
-- con esas palabras. En lo que se puede hacer, «no consta» y «dijeron
-- que no» valen lo mismo —no se publica—, pero no son lo mismo de cara
-- a la familia: uno se arregla preguntando y el otro no hay que
-- preguntarlo, ya está contestado. Es el mismo criterio que ya usa la
-- 121 al examinar un alta sin contestar («cuenta como un NO»), y el
-- mismo que el ranking con los menores: sin autorización que conste,
-- el crío no sale (`perfil_juego.autoriza_parental_en`).
--
-- ------------------------------------------------------------
-- QUIÉN PUEDE TOCARLO
-- Nadie más que administración, y no hace falta añadir ninguna regla
-- para eso: la única regla de escritura de `atletas` es «admin gestiona
-- todo», y el disparador de la 130 solo deja al entrenador cambiar lo
-- que se decide en la pista. Un consentimiento no se decide en la
-- pista: lo da la familia y lo recoge el club. El entrenador lo LEE,
-- que es justo lo que faltaba, y no lo cambia.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/135_el_permiso_de_las_fotos_llega_a_la_pista.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LAS CASILLAS
-- ------------------------------------------------------------
alter table public.atletas
  add column if not exists permiso_imagen boolean;

alter table public.atletas
  add column if not exists permiso_imagen_ambitos text[];

alter table public.atletas
  add column if not exists permiso_imagen_en timestamptz;

alter table public.atletas
  add column if not exists permiso_imagen_origen text;

comment on column public.atletas.permiso_imagen is
  'Si la familia autorizó publicar fotos suyas. VACÍO NO ES QUE SÍ: vacío es que no consta, '
  'y mientras no conste no se publica nada. Se rellena al convertir el alta en ficha, o a '
  'mano desde Atletas cuando la autorización llega en papel.';

comment on column public.atletas.permiso_imagen_ambitos is
  'Para qué canales vale el permiso, con los apartados del impreso del club: web, redes, '
  'mensajeria, medios. El impreso de papel los ofrece por separado; el formulario de la web '
  'pregunta uno solo que vale por los tres primeros y nunca por «medios».';

comment on column public.atletas.permiso_imagen_en is
  'Cuándo quedó apuntado el permiso. Hace falta el día que una familia dice que lo retiró: '
  'sin fecha no hay manera de saber qué había apuntado y desde cuándo.';

comment on column public.atletas.permiso_imagen_origen is
  'De dónde salió: «alta» si vino del formulario que rellenó la familia, «mano» si lo escribió '
  'alguien del club desde Atletas (autorización en papel, llamada, correo).';

-- ------------------------------------------------------------
-- 2 · QUE EL PERMISO VIAJE AL CREAR LA FICHA
-- ------------------------------------------------------------
-- Un detalle que no es un detalle: el permiso NO se lee de `p_datos`,
-- que es lo que manda la pantalla, sino del alta, aquí dentro. Todo lo
-- demás de la pantalla se puede retocar antes de crear la ficha —un
-- apellido mal escrito, un grupo cambiado— y está bien que se pueda.
-- Un consentimiento no. Lo que vale es lo que contestó la familia, no
-- lo que llegue en la petición, y así no hay forma de que se cambie por
-- el camino ni por error ni queriendo.
--
-- Al enlazar con una ficha que ya existe se usa `coalesce`, como con
-- todo lo demás en esa rama: lo que ya hay en la ficha manda. Si un
-- hermano mayor ya tenía su permiso apuntado, un alta nueva no lo pisa.
create or replace function public.alta_crear_ficha(p_que text, p_persona_id uuid, p_datos jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alta_id    uuid;
  v_alta_est   text;
  v_atleta     uuid;
  v_enlazar    uuid;
  v_grupos     uuid[];
  v_principal  uuid;
  v_g          record;
  v_nombre     text;
  v_apellidos  text;
  v_fnac       date;
  v_perfil     uuid;
  v_pendientes int;
  v_creada     boolean := true;
  v_revisada   boolean := false;   -- si el alta ha quedado revisada AHORA
  v_permiso    boolean;            -- lo que contestó la familia a lo de las fotos
  v_ambitos    text[];             -- y para qué canales
begin
  -- ⚠️ DECISIÓN TOMADA A PROPÓSITO, NO UN DESCUIDO · agosto de 2026
  -- Esta línea deja entrar a administración Y a tesorería, igual que
  -- el resto de la bandeja de altas (migraciones 114 y 115).
  --
  -- Lo que hay que saber, porque no se ve mirando esta línea: la
  -- tabla `atletas` NO le deja crear a tesorería. Su única regla de
  -- escritura es «admin gestiona todo»; tesorería la lee y nada más.
  -- Como esta función corre con los papeles del dueño de la base, esas
  -- reglas aquí dentro no protegen nada, así que ESTA FUNCIÓN LE ABRE
  -- A TESORERÍA UNA PUERTA QUE LA TABLA NO LE DABA.
  --
  -- Se hizo así porque quien revisa las altas en septiembre es también
  -- quien las convierte, y partir el trabajo en dos personas era
  -- garantizar que las altas se quedan revisadas y sin ficha. La
  -- puerta es estrecha a propósito: no deja escribir una ficha
  -- cualquiera, solo convertir un alta que ya está en la bandeja que
  -- tesorería lleva, con los datos que trae esa alta.
  --
  -- Si el club prefiere que crear fichas sea solo de administración:
  -- se quita `or public.es_tesoreria()` de aquí y de `alta_examen`, y
  -- no hay que tocar nada más.
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración y tesorería pueden crear fichas desde un alta';
  end if;
  if p_que not in ('escuela', 'socio') then
    raise exception 'No sé qué alta es «%»', p_que;
  end if;

  select id into v_perfil from public.perfiles where email = (auth.jwt() ->> 'email');

  -- ---------- de qué alta viene y si esa alta deja ----------
  if p_que = 'escuela' then
    select n.alta_id, n.atleta_id, n.permiso_imagen, n.permiso_imagen_ambitos
      into v_alta_id, v_atleta, v_permiso, v_ambitos
      from public.altas_escuela_ninos n where n.id = p_persona_id;
    if v_alta_id is null then
      return jsonb_build_object('ok', false, 'motivo', 'no-esta');
    end if;
    select a.estado into v_alta_est from public.altas_escuela a where a.id = v_alta_id;
  else
    select s.id, s.estado, s.atleta_id, s.permiso_imagen, s.permiso_imagen_ambitos
      into v_alta_id, v_alta_est, v_atleta, v_permiso, v_ambitos
      from public.altas_socio s where s.id = p_persona_id;
    if v_alta_id is null then
      return jsonb_build_object('ok', false, 'motivo', 'no-esta');
    end if;
    -- La red de abajo, solo para las altas de socio de antes de la 122:
    -- si no tienen la casilla puesta, se busca por DNI. En las nuevas
    -- esto ni se ejecuta, que es de lo que se trataba.
    if v_atleta is null then
      select a.id into v_atleta
        from public.atletas a
        join public.altas_socio s on s.id = p_persona_id
       where a.dni is not null and s.dni is not null
         and public.nombre_llano(a.dni) = public.nombre_llano(s.dni)
       limit 1;
    end if;
  end if;

  if v_alta_est = 'rechazada' then
    return jsonb_build_object('ok', false, 'motivo', 'alta-rechazada');
  end if;

  v_enlazar := nullif(p_datos ->> 'enlazar_con', '')::uuid;

  -- Ya tiene ficha y no se ha dicho a cuál engancharla: se para. Crear
  -- la segunda es justo lo que hay que evitar.
  if v_atleta is not null and v_enlazar is null then
    return jsonb_build_object('ok', false, 'motivo', 'ya-tiene-ficha', 'atleta_id', v_atleta);
  end if;
  if v_enlazar is not null and not exists (select 1 from public.atletas a where a.id = v_enlazar) then
    return jsonb_build_object('ok', false, 'motivo', 'la-ficha-a-enlazar-no-esta');
  end if;

  -- ---------- los datos, limpiados ----------
  v_nombre    := public.texto_de_fuera(p_datos ->> 'nombre', 80);
  v_apellidos := public.texto_de_fuera(p_datos ->> 'apellidos', 120);
  v_fnac      := nullif(p_datos ->> 'fecha_nacimiento', '')::date;

  if v_nombre is null then
    return jsonb_build_object('ok', false, 'motivo', 'sin-nombre');
  end if;

  -- ---------- los grupos ----------
  select coalesce(array_agg(distinct x::uuid), '{}')
    into v_grupos
    from jsonb_array_elements_text(coalesce(p_datos -> 'grupos', '[]'::jsonb)) x
   where x <> '';
  v_principal := nullif(p_datos ->> 'grupo_principal', '')::uuid;
  if v_principal is null and array_length(v_grupos, 1) = 1 then
    v_principal := v_grupos[1];
  end if;
  if v_principal is not null and not (v_principal = any(v_grupos)) then
    v_grupos := v_grupos || v_principal;
  end if;

  if array_length(v_grupos, 1) is null then
    return jsonb_build_object('ok', false, 'motivo', 'sin-grupo');
  end if;

  -- Que todos existan y estén abiertos. Se comprueba aquí y no solo en
  -- la pantalla porque entre que se abrió la vista previa y se pulsó
  -- aceptar pueden pasar veinte minutos y alguien puede haber cerrado
  -- el grupo mientras tanto.
  for v_g in select g.id, g.nombre, g.activo from public.grupos g where g.id = any(v_grupos) loop
    if not coalesce(v_g.activo, true) then
      return jsonb_build_object('ok', false, 'motivo', 'grupo-cerrado', 'grupo', v_g.nombre);
    end if;
  end loop;
  if (select count(*) from public.grupos g where g.id = any(v_grupos)) <> array_length(v_grupos, 1) then
    return jsonb_build_object('ok', false, 'motivo', 'grupo-no-existe');
  end if;

  -- ---------- crear, o enlazar con la que ya hay ----------
  if v_enlazar is not null then
    v_creada := false;
    v_atleta := v_enlazar;
    -- Solo se rellena lo que estuviera vacío. Ni un `coalesce` al
    -- revés: lo que ya hay en la ficha manda siempre.
    update public.atletas a
       set fecha_nacimiento = coalesce(a.fecha_nacimiento, v_fnac),
           categoria        = coalesce(a.categoria, public.texto_de_fuera(p_datos ->> 'categoria', 40)),
           sexo             = coalesce(a.sexo, nullif(p_datos ->> 'sexo', '')),
           tipo_membresia   = coalesce(a.tipo_membresia, p_que),
           nombre_tutor     = coalesce(a.nombre_tutor,   public.texto_de_fuera(p_datos ->> 'nombre_tutor', 120)),
           email_tutor      = coalesce(a.email_tutor,    public.texto_de_fuera(p_datos ->> 'email_tutor', 160)),
           telefono_tutor   = coalesce(a.telefono_tutor, public.texto_de_fuera(p_datos ->> 'telefono_tutor', 30)),
           email            = coalesce(a.email,          public.texto_de_fuera(p_datos ->> 'email', 160)),
           telefono         = coalesce(a.telefono,       public.texto_de_fuera(p_datos ->> 'telefono', 30)),
           -- Lo de las fotos, con la misma regla: si la ficha ya tenía
           -- algo apuntado, no se pisa. Y la fecha y el origen solo se
           -- ponen si el permiso entra ahora; si no, quedarían diciendo
           -- que este dato es de hoy cuando es de hace un año.
           permiso_imagen         = coalesce(a.permiso_imagen, v_permiso),
           permiso_imagen_ambitos = case when a.permiso_imagen is null and v_permiso is not null
                                         then v_ambitos else a.permiso_imagen_ambitos end,
           permiso_imagen_en      = case when a.permiso_imagen is null and v_permiso is not null
                                         then now() else a.permiso_imagen_en end,
           permiso_imagen_origen  = case when a.permiso_imagen is null and v_permiso is not null
                                         then 'alta' else a.permiso_imagen_origen end,
           -- Las observaciones no se pisan: se añaden debajo. Lo que
           -- escribió el entrenador en marzo vale tanto como esto.
           observaciones = case
             when public.texto_de_fuera(p_datos ->> 'observaciones', 1000) is null then a.observaciones
             when a.observaciones is null or btrim(a.observaciones) = ''
               then public.texto_de_fuera(p_datos ->> 'observaciones', 1000)
             when position(public.texto_de_fuera(p_datos ->> 'observaciones', 1000) in a.observaciones) > 0
               then a.observaciones
             else a.observaciones || E'\n' || public.texto_de_fuera(p_datos ->> 'observaciones', 1000)
           end,
           updated_at = now()
     where a.id = v_atleta;
  else
    -- La ficha nace SIN grupo en la casilla, y el grupo entra justo
    -- después por `atleta_grupos`. Es el orden que quiere la 116: el
    -- disparador de esa tabla pone solo la casilla de la ficha a partir
    -- del principal. Al revés se pisan el uno al otro.
    insert into public.atletas (
      nombre, apellidos, fecha_nacimiento, categoria, sexo, estado, tipo_membresia,
      observaciones, nombre_tutor, email_tutor, telefono_tutor, email, telefono,
      permiso_imagen, permiso_imagen_ambitos, permiso_imagen_en, permiso_imagen_origen)
    values (
      v_nombre, v_apellidos, v_fnac,
      public.texto_de_fuera(p_datos ->> 'categoria', 40),
      nullif(p_datos ->> 'sexo', ''),
      coalesce(nullif(p_datos ->> 'estado', ''), 'activo'),
      p_que,
      public.texto_de_fuera(p_datos ->> 'observaciones', 1000),
      public.texto_de_fuera(p_datos ->> 'nombre_tutor', 120),
      public.texto_de_fuera(p_datos ->> 'email_tutor', 160),
      public.texto_de_fuera(p_datos ->> 'telefono_tutor', 30),
      public.texto_de_fuera(p_datos ->> 'email', 160),
      public.texto_de_fuera(p_datos ->> 'telefono', 30),
      v_permiso,
      case when v_permiso is not null then v_ambitos end,
      case when v_permiso is not null then now() end,
      case when v_permiso is not null then 'alta' end)
    returning id into v_atleta;
  end if;

  -- ---------- en qué grupos entra ----------
  -- Primero los de acompañamiento y al final el principal, que es el
  -- orden que pide la 116: se asciende, no se degrada. Si se enlaza con
  -- una ficha que ya tenía principal, no se le toca: entrar en un grupo
  -- nuevo no cambia cuál es el suyo de siempre.
  insert into public.atleta_grupos (atleta_id, grupo_id, principal)
  select v_atleta, g, false from unnest(v_grupos) g
   where v_principal is null or g <> v_principal
  on conflict (atleta_id, grupo_id) do nothing;

  if v_principal is not null then
    if v_creada or not exists (select 1 from public.atleta_grupos ag
                                where ag.atleta_id = v_atleta and ag.principal) then
      insert into public.atleta_grupos (atleta_id, grupo_id, principal)
      values (v_atleta, v_principal, true)
      on conflict (atleta_id, grupo_id) do update set principal = true;
    else
      insert into public.atleta_grupos (atleta_id, grupo_id, principal)
      values (v_atleta, v_principal, false)
      on conflict (atleta_id, grupo_id) do nothing;
    end if;
  end if;

  -- El entrenador de la ficha: el del grupo principal, si tiene. Es lo
  -- que hace que el atleta le salga en su pantalla desde el primer día
  -- sin que nadie se acuerde de asignarlo.
  update public.atletas a
     set entrenador_id = (select g.entrenador_id from public.grupos g where g.id = a.grupo_id)
   where a.id = v_atleta and a.entrenador_id is null;

  -- ---------- dejar dicho de dónde salió ----------
  if p_que = 'escuela' then
    update public.altas_escuela_ninos n set atleta_id = v_atleta where n.id = p_persona_id;

    -- Si ya no queda ningún hermano por convertir, el alta queda
    -- revisada sola. No es un atajo: un alta de la que ya han salido
    -- todas las fichas está trabajada, y dejarla en «sin revisar»
    -- hace que alguien la vuelva a abrir mañana para nada.
    select count(*) into v_pendientes
      from public.altas_escuela_ninos n where n.alta_id = v_alta_id and n.atleta_id is null;
    if v_pendientes = 0 and v_alta_est = 'pendiente' then
      update public.altas_escuela
         set estado = 'revisada', revisada_por = v_perfil, revisada_en = now()
       where id = v_alta_id;
      v_revisada := true;
    end if;
  else
    -- Desde la 122 el alta de socio guarda a qué ficha dio lugar, así
    -- que el hilo entre las dos no depende de cómo se escribiera un DNI.
    update public.altas_socio set atleta_id = v_atleta where id = v_alta_id;
    if v_alta_est = 'pendiente' then
      update public.altas_socio
         set estado = 'revisada', revisada_por = v_perfil, revisada_en = now()
       where id = v_alta_id;
      v_revisada := true;
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'atleta_id', v_atleta,
    'creada', v_creada,
    'alta_revisada', v_revisada);
end;
$$;

comment on function public.alta_crear_ficha(text, uuid, jsonb) is
  'Crea UNA ficha de atleta a partir de una persona de un alta, la mete en sus grupos y '
  'deja apuntado en el alta a qué ficha dio lugar. Desde la 135 se lleva también el permiso '
  'de imagen, leído del alta y no de lo que manda la pantalla: un consentimiento no se retoca '
  'por el camino.';

revoke all on function public.alta_crear_ficha(text, uuid, jsonb)   from public;
grant execute on function public.alta_crear_ficha(text, uuid, jsonb) to authenticated;

-- ------------------------------------------------------------
-- 3 · RESCATAR LO QUE YA SE CONVIRTIÓ
-- ------------------------------------------------------------
-- Las fichas que salieron de un alta ANTES de hoy dejaron el permiso
-- atrás. Esto no se inventa nada: coge la respuesta que la familia ya
-- había dado en su alta y la copia a la ficha que salió de ella. Si el
-- alta tampoco lo traía, la ficha se queda vacía —que es «no consta»—,
-- que es exactamente lo que hay que decir.
--
-- Solo se toca lo que esté vacío, para no pisar nada escrito a mano.
update public.atletas a
   set permiso_imagen         = n.permiso_imagen,
       permiso_imagen_ambitos = n.permiso_imagen_ambitos,
       permiso_imagen_en      = coalesce(n.created_at, now()),
       permiso_imagen_origen  = 'alta'
  from public.altas_escuela_ninos n
 where n.atleta_id = a.id
   and n.permiso_imagen is not null
   and a.permiso_imagen is null;

update public.atletas a
   set permiso_imagen         = s.permiso_imagen,
       permiso_imagen_ambitos = s.permiso_imagen_ambitos,
       permiso_imagen_en      = coalesce(s.created_at, now()),
       permiso_imagen_origen  = 'alta'
  from public.altas_socio s
 where s.atleta_id = a.id
   and s.permiso_imagen is not null
   and a.permiso_imagen is null;

commit;

-- Que la API se entere de las columnas nuevas sin esperar a que se le
-- ocurra sola.
notify pgrst, 'reload schema';

-- ------------------------------------------------------------
-- CÓMO QUEDA LA COSA
-- ------------------------------------------------------------
select 'con permiso apuntado' as que, count(*) as total from public.atletas where permiso_imagen is not null
union all
select 'sin que conste',            count(*) from public.atletas where permiso_imagen is null;
