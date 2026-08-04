-- ============================================================
-- 121 · De un alta sale una ficha
-- ------------------------------------------------------------
-- EL ÚLTIMO PASO QUE FALTABA
-- La 114 montó los formularios, la 115 la bandeja donde se ven y la
-- 120 el aviso al móvil. Con eso, un alta entra, se lee y se marca
-- como revisada… y ahí se acaba. Para que ese niño exista de verdad
-- en el club —para que salga en la lista del entrenador, para que se
-- le pueda pasar lista, para cobrarle la cuota— alguien tiene que
-- abrir Atletas y volver a teclear a mano lo que la familia ya
-- escribió: nombre, apellidos, fecha de nacimiento y grupo.
--
-- Con cuatrocientas altas en septiembre eso son horas de teclear, y
-- teclear es de donde salen los apellidos mal escritos y las fechas
-- de nacimiento cambiadas. Un dígito de menos en una fecha y el crío
-- acaba en el grupo de otro año, cosa que se descubre en la pista.
--
-- ------------------------------------------------------------
-- LO QUE ESTO NO ES, DICHO ANTES QUE NADA
-- ESTO NO ES UN BOTÓN DE «IMPORTAR LAS CUATROCIENTAS».
--
-- Aquí no hay ninguna función que recorra la bandeja creando fichas
-- sola, y no la hay a propósito. Se crea UNA ficha por llamada, y
-- cada llamada viene de una persona que ha visto en pantalla lo que
-- se va a crear y le ha dado a aceptar. Un alta mal convertida es un
-- niño en el grupo equivocado; eso no se arregla con un «deshacer»,
-- se arregla en la pista un martes por la tarde con un padre
-- enfadado.
--
-- Y por eso el trabajo de verdad de este archivo NO es crear la
-- ficha —eso son tres líneas de `insert`—, sino DETECTAR LO RARO
-- ANTES de crearla. De las dos funciones que hay aquí, la larga es
-- la que no escribe nada.
--
-- ------------------------------------------------------------
-- LAS DOS PUERTAS
--
--   `alta_examen(qué, id)`  ← NO ESCRIBE NADA.
--        Coge un alta, propone una ficha por cada persona que trae y
--        devuelve, junto a cada propuesta, la lista de lo que huele
--        mal: que ya está en el club, que el año no cuadra con el
--        grupo que eligieron, que el grupo está lleno o cerrado, que
--        falta algo que la ficha necesita. Es lo que lee la pantalla
--        de «Crear las fichas» para pintar la vista previa.
--
--   `alta_crear_ficha(qué, persona, datos)`  ← escribe UNA.
--        Crea (o enlaza) la ficha de UNA persona con los datos que
--        vienen ya corregidos de la pantalla. Vuelve a comprobar por
--        su cuenta lo que no se puede saltar, porque una comprobación
--        que solo vive en el navegador no es una comprobación.
--
-- POR QUÉ UNA POR LLAMADA Y NO EL ALTA ENTERA
-- Porque en un alta de escuela vienen hermanos. Si se hiciera el
-- alta entera de una vez y el segundo hermano fallara —su grupo se
-- cerró ayer, o resulta que ya estaba en el club—, o se pierde la
-- ficha del primero o se queda medio hecho sin que nadie sepa qué
-- mitad. Haciéndolo de uno en uno, cada hermano es su propio intento:
-- el que sale, sale; el que falla, dice por qué y se queda esperando.
--
-- ------------------------------------------------------------
-- QUIÉN PUEDE
-- Lo mismo que en el resto de la bandeja de altas: administración y
-- tesorería. Se respeta lo que ya decidió la 114 y no se estrecha ni
-- se ensancha por el camino.
--
-- Hay un detalle que conviene ver escrito, porque no es evidente: la
-- tabla `atletas` solo deja CREAR a administración (`admin gestiona
-- todo`); tesorería la lee pero no escribe en ella. Así que esta
-- función, que corre con los papeles del dueño de la base, le está
-- abriendo a tesorería una puerta que la tabla no le daba. Es a
-- propósito y es una puerta muy estrecha: no deja escribir una ficha
-- cualquiera, solo deja convertir un alta que ya está en la bandeja
-- que tesorería lleva, con los campos que trae esa alta. Si el club
-- prefiere que crear fichas sea solo de administración, se cambia la
-- primera línea de cada función y no hay que tocar nada más.
--
-- ------------------------------------------------------------
-- NADA PERSONAL AQUÍ DENTRO
-- Ni un nombre, ni un correo, ni un DNI. Este archivo queda en el
-- histórico para siempre y el repositorio es público.
--
-- Y no se rompe lo de la 115: aquí no se destapa ningún número. El
-- DNI del padre y el IBAN siguen saliendo tapados y siguen dejando
-- rastro cuando alguien los destapa. La ficha del atleta no necesita
-- ninguno de los dos, así que ninguno de los dos se copia.
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta. No borra ni una ficha.
-- ============================================================

begin;

-- ============================================================
-- 1 · CUÁNTA GENTE CABE EN UN GRUPO
-- ------------------------------------------------------------
-- Para poder avisar de que un grupo está lleno hay que saber antes
-- cuánta gente cabe, y eso no estaba en ninguna parte: `grupos` tenía
-- nombre, horario, años de nacimiento y turno, pero ni un número de
-- plazas.
--
-- Se deja VACÍO por defecto, y vacío quiere decir «sin tope», no
-- «cero». Poner un número inventado sería peor que no tener ninguno:
-- la pantalla empezaría a decir que la escuela está llena en cuanto
-- entraran veinte altas, todo el mundo aprendería a ignorar ese
-- aviso, y el día que un grupo se llene de verdad nadie lo mirará.
-- El número lo pone el club grupo por grupo, desde la pantalla de
-- Grupos, cuando lo sepa.
-- ============================================================
alter table public.grupos
  add column if not exists plazas smallint;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'grupos_plazas_chk') then
    alter table public.grupos
      add constraint grupos_plazas_chk check (plazas is null or (plazas > 0 and plazas <= 500));
  end if;
end $$;

comment on column public.grupos.plazas is
  'Cuánta gente cabe en el grupo. Vacío = sin tope. Sirve para avisar al '
  'convertir un alta de que ese grupo ya está lleno; nunca impide nada por '
  'su cuenta, porque meter a uno más siempre es una decisión del club.';


-- ============================================================
-- 2 · TRES CUENTAS QUE SE HACÍAN A MANO EN CADA PANTALLA
-- ============================================================

-- ------------------------------------------------------------
-- Un nombre «llano» para poder comparar dos nombres.
-- «Mª Ángeles Núñez» y «Ma Angeles Nuñez» son la misma niña, y si se
-- comparan tal cual son dos personas distintas y el club acaba con
-- dos fichas. Se quitan tildes, mayúsculas, espacios y guiones, y se
-- compara lo que queda.
-- ------------------------------------------------------------
create or replace function public.nombre_llano(p_texto text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select nullif(
           regexp_replace(lower(public.apo_sin_tildes(coalesce(p_texto, ''))),
                          '[^a-z0-9]', '', 'g'),
           '');
$$;

comment on function public.nombre_llano(text) is
  'El nombre sin tildes, sin mayúsculas y sin espacios, para comparar dos '
  'nombres sin que una tilde de más los convierta en dos personas.';


-- ------------------------------------------------------------
-- Partir un nombre completo en nombre y apellidos.
--
-- El formulario de la escuela pide «Nombre y apellidos del niño» en
-- una sola casilla, porque pedirlo en tres casillas hace que media
-- familia ponga los apellidos en la del nombre. La ficha del atleta
-- sí los tiene separados.
--
-- La regla es la española de toda la vida: las DOS ÚLTIMAS palabras
-- son los apellidos. Es la misma que usa la pantalla de Importar, y
-- tiene que ser la misma o los mismos datos entrarían partidos de dos
-- maneras distintas según por dónde entren.
--
-- Se equivoca, y se equivoca de una forma conocida: «María del Mar
-- Sanz» le da «María del» + «Mar Sanz». Por eso lo que sale de aquí
-- es una PROPUESTA que se enseña en dos casillas para corregirla, no
-- un resultado que se guarda a ciegas.
-- ------------------------------------------------------------
create or replace function public.partir_nombre(p_completo text)
returns jsonb
language plpgsql
immutable
set search_path to 'public'
as $$
declare
  v_trozos text[];
  v_n      int;
begin
  v_trozos := regexp_split_to_array(btrim(regexp_replace(coalesce(p_completo, ''), '\s+', ' ', 'g')), ' ');
  v_n := coalesce(array_length(v_trozos, 1), 0);

  if v_n = 0 or v_trozos[1] = '' then
    return jsonb_build_object('nombre', null, 'apellidos', null);
  elsif v_n = 1 then
    return jsonb_build_object('nombre', v_trozos[1], 'apellidos', null);
  elsif v_n = 2 then
    return jsonb_build_object('nombre', v_trozos[1], 'apellidos', v_trozos[2]);
  end if;

  return jsonb_build_object(
    'nombre',    array_to_string(v_trozos[1 : v_n - 2], ' '),
    'apellidos', array_to_string(v_trozos[v_n - 1 : v_n], ' '));
end;
$$;

comment on function public.partir_nombre(text) is
  'Parte «Lucía Pérez Gómez» en nombre y apellidos con la regla española: las '
  'dos últimas palabras son los apellidos. Es una propuesta para corregir a '
  'mano, no una verdad: los nombres compuestos la engañan.';


-- ------------------------------------------------------------
-- La categoría por el año de nacimiento (RFEA).
-- Es la misma cuenta que hacen la ficha del atleta y la pantalla de
-- Importar, escrita ahora también aquí para que las tres digan lo
-- mismo. Va por AÑO, no por edad cumplida: en atletismo nadie cambia
-- de categoría el día de su cumpleaños.
-- ------------------------------------------------------------
create or replace function public.categoria_por_nacimiento(p_fecha date)
returns text
language sql
stable
set search_path to 'public'
as $$
  select case
           when p_fecha is null then null
           else (
             select case
                      when e <=  8 then 'Escuela iniciación'
                      when e <= 10 then 'Sub-12'
                      when e <= 12 then 'Sub-14'
                      when e <= 14 then 'Sub-16'
                      when e <= 16 then 'Sub-18'
                      when e <= 18 then 'Sub-20'
                      when e <= 21 then 'Sub-23'
                      when e <= 34 then 'Absoluto'
                      else 'Máster'
                    end
             from (select extract(year from current_date)::int
                          - extract(year from p_fecha)::int as e) t
           )
         end;
$$;

comment on function public.categoria_por_nacimiento(date) is
  'La categoría de la RFEA por el año de nacimiento. La misma cuenta que hace '
  'la ficha del atleta, para que no haya dos criterios.';


-- ============================================================
-- 3 · CUÁNTA GENTE HAY YA EN CADA GRUPO
-- ------------------------------------------------------------
-- Para decir «este grupo tiene 24 y caben 20» hace falta contarlos, y
-- contarlos bien no es mirar `atletas.grupo_id`: desde la 116 una
-- persona puede estar en varios grupos, y los de más están en
-- `atleta_grupos`. Quien esté por las dos vías se cuenta una vez.
--
-- Las bajas no cuentan: un grupo con veinte fichas de las que ocho se
-- dieron de baja en noviembre no está lleno, y decir que lo está deja
-- fuera a un niño que cabe.
-- ============================================================
create or replace function public.grupo_apuntados(p_grupo uuid)
returns int
language sql
stable
set search_path to 'public'
as $$
  select count(*)::int from (
    select ag.atleta_id as id from public.atleta_grupos ag where ag.grupo_id = p_grupo
    union
    select a.id         from public.atletas a       where a.grupo_id = p_grupo
  ) q
  join public.atletas a2 on a2.id = q.id
  where coalesce(a2.estado, 'activo') <> 'baja';
$$;

comment on function public.grupo_apuntados(uuid) is
  'Cuántos atletas entrenan hoy en ese grupo, contando los de la tabla de '
  'varios grupos y sin contar dos veces a nadie. Las bajas no cuentan.';


-- ============================================================
-- 4 · EL EXAMEN · LA FUNCIÓN QUE NO ESCRIBE NADA
-- ------------------------------------------------------------
-- Devuelve, para un alta, todo lo que la pantalla de vista previa
-- necesita para pintar qué se va a crear y qué huele mal.
--
-- CADA AVISO LLEVA UN TONO, Y EL TONO IMPORTA:
--   · 'para' → esto no se puede crear tal cual. La pantalla no deja
--              darle a aceptar hasta que se arregle.
--   · 'ojo'  → probablemente esté mal, pero puede estar bien. Se
--              enseña en ámbar y hay que leerlo antes de aceptar.
--   · 'nota' → un dato que falta y que no impide nada. Se dice para
--              que alguien lo pida por teléfono, no para asustar.
--
-- Los tres son distintos a propósito. Si todo fuera «ojo», en la
-- tercera alta de la mañana nadie los leería, y el que avisa de que
-- un niño ya está en el club se perdería entre los que avisan de que
-- no puso la talla de la camiseta.
-- ============================================================
create or replace function public.alta_examen(p_que text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_alta      record;
  v_p         record;
  v_g         record;
  v_personas  jsonb := '[]'::jsonb;
  v_avisos    jsonb;
  v_gen       jsonb := '[]'::jsonb;   -- avisos del alta entera
  v_prop      jsonb;
  v_partido   jsonb;
  v_nom       text;
  v_ape       text;
  v_anio      int;
  v_parecidos jsonb;
  v_ya        jsonb;
  v_grupo     jsonb;
  v_opciones  jsonb;
  v_obs       text;
  v_otras     int;
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración y tesorería pueden trabajar las altas';
  end if;

  if p_que not in ('escuela', 'socio') then
    raise exception 'No sé qué alta es «%»', p_que;
  end if;

  -- ----------------------------------------------------------
  -- EL ALTA ENTERA
  -- ----------------------------------------------------------
  if p_que = 'escuela' then
    select a.id, a.referencia, a.temporada, a.estado, a.tutor_nombre, a.tutor_email,
           a.tutor_telefono, a.quien_recoge, a.acepta_normas, a.forma_pago,
           (a.iban is not null) as tiene_iban, a.created_at, a.nota_club
      into v_alta
      from public.altas_escuela a where a.id = p_id;
  else
    select s.id, s.referencia, s.temporada, s.estado, s.nombre as tutor_nombre, s.email as tutor_email,
           s.telefono as tutor_telefono, null::text as quien_recoge, s.acepta_normas,
           null::text as forma_pago, false as tiene_iban, s.created_at, s.nota_club
      into v_alta
      from public.altas_socio s where s.id = p_id;
  end if;

  if v_alta.id is null then
    return jsonb_build_object('ok', false, 'motivo', 'no-esta');
  end if;

  -- Un alta rechazada no se convierte. Se puede volver a «sin revisar»
  -- desde la bandeja si fue un error, pero mientras esté rechazada la
  -- pantalla no ofrece crear nada: rechazarla y crear la ficha de todas
  -- formas es exactamente lo que no puede pasar.
  if v_alta.estado = 'rechazada' then
    v_gen := v_gen || jsonb_build_object(
      'clave', 'alta-rechazada', 'tono', 'para',
      'texto', 'Esta alta está rechazada. Si fue un error, vuelve a ponerla en «sin revisar» antes de crear nada.');
  end if;

  if not v_alta.acepta_normas then
    v_gen := v_gen || jsonb_build_object(
      'clave', 'sin-normas', 'tono', 'ojo',
      'texto', 'La familia no aceptó las normas del club. Comprueba cómo entró esta alta antes de seguir.');
  end if;

  if p_que = 'escuela' and not v_alta.tiene_iban then
    v_gen := v_gen || jsonb_build_object(
      'clave', 'sin-iban', 'tono', 'nota',
      'texto', 'No dejaron número de cuenta. La ficha se crea igual, pero hay que pedírselo para poder pasar el recibo.');
  end if;

  -- ¿Esta familia se ha apuntado más veces? Pasa constantemente: se
  -- rellena el formulario, no llega el correo de confirmación y se
  -- vuelve a rellenar. Si no se dice aquí, salen dos fichas del mismo
  -- niño con dos días de diferencia.
  if p_que = 'escuela' then
    select count(*) into v_otras from public.altas_escuela o
     where o.id <> v_alta.id and lower(o.tutor_email) = lower(v_alta.tutor_email);
  else
    select count(*) into v_otras from public.altas_socio o
     where o.id <> v_alta.id and lower(o.email) = lower(v_alta.tutor_email);
  end if;
  if v_otras > 0 then
    v_gen := v_gen || jsonb_build_object(
      'clave', 'familia-repetida', 'tono', 'ojo',
      'texto', 'Con este mismo correo han entrado ' ||
               (case when v_otras = 1 then 'otra alta' else v_otras::text || ' altas más' end) ||
               '. Míralas antes de crear nada, no sea que sea la misma familia dos veces.');
  end if;

  -- ----------------------------------------------------------
  -- UNA PROPUESTA POR PERSONA
  -- ----------------------------------------------------------
  for v_p in
    select * from (
      -- Los hijos de un alta de escuela: uno o varios hermanos.
      select n.id, n.orden, n.nombre as nombre_tal_cual, n.fecha_nacimiento,
             n.grupo_id, n.grupo_nombre, n.turno, n.alergias, n.atleta_id,
             n.permiso_imagen, (n.sip is not null) as tiene_sip,
             null::text as dni, null::text as sexo, null::text[] as secciones
        from public.altas_escuela_ninos n
       where p_que = 'escuela' and n.alta_id = p_id
      union all
      -- Un alta de socio es una sola persona: ella misma. No tiene
      -- casilla de «ya se convirtió» —eso solo existe en la escuela—,
      -- así que aquí va vacía y quien avisa de que ya está en el club
      -- es la búsqueda de parecidos de más abajo, por DNI.
      select s.id, 1 as orden,
             btrim(coalesce(s.nombre, '') || ' ' || coalesce(s.apellidos, '')) as nombre_tal_cual,
             s.fecha_nacimiento, null::uuid as grupo_id, null::text as grupo_nombre,
             null::text as turno, null::text as alergias,
             null::uuid as atleta_id,
             s.permiso_imagen, false as tiene_sip,
             s.dni, s.sexo, s.secciones
        from public.altas_socio s
       where p_que = 'socio' and s.id = p_id
    ) q
    order by q.orden
  loop
    v_avisos := '[]'::jsonb;
    v_anio   := extract(year from v_p.fecha_nacimiento)::int;

    -- --- El nombre partido en dos ---
    v_partido := public.partir_nombre(v_p.nombre_tal_cual);
    v_nom := v_partido ->> 'nombre';
    v_ape := v_partido ->> 'apellidos';
    -- Para el socio el formulario ya los pide separados: no hay que
    -- adivinar nada y se usan tal cual.
    if p_que = 'socio' then
      select s.nombre, s.apellidos into v_nom, v_ape from public.altas_socio s where s.id = v_p.id;
    end if;

    if v_ape is null or v_ape = '' then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'sin-apellidos', 'tono', 'ojo',
        'texto', 'Solo escribieron una palabra, así que no hay apellidos. Compruébalo antes de crear la ficha.');
    elsif p_que = 'escuela' then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'nombre-partido', 'tono', 'nota',
        'texto', 'El formulario pide el nombre entero en una casilla; lo de arriba es cómo se ha partido. Si el nombre es compuesto, córrigelo aquí.');
    end if;

    -- --- ¿Ya tiene ficha porque ya se convirtió? ---
    v_ya := null;
    if v_p.atleta_id is not null then
      select jsonb_build_object('id', a.id, 'nombre', btrim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')),
                                'estado', a.estado)
        into v_ya from public.atletas a where a.id = v_p.atleta_id;
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'ya-convertida', 'tono', 'para',
        'texto', 'De esta persona ya se creó la ficha desde esta misma alta. No hay nada que crear.');
    end if;

    -- --- ¿Ya está en el club? ---
    -- Dos redes, y se dicen distinto a propósito:
    --   · mismo nombre Y misma fecha de nacimiento → casi seguro que
    --     es la misma persona (un hermano que renueva, la familia que
    --     se apuntó dos veces).
    --   · mismo nombre y OTRA fecha → puede ser el hermano pequeño con
    --     el nombre del abuelo, que pasa más de lo que parece.
    -- Ninguna de las dos impide crear: impedirlo dejaría fuera a dos
    -- primos que se llaman igual. Las dos obligan a mirar.
    select coalesce(jsonb_agg(x order by x ->> 'motivo', x ->> 'nombre'), '[]'::jsonb)
      into v_parecidos
      from (
        select jsonb_build_object(
                 'id', a.id,
                 'nombre', btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')),
                 'fecha_nacimiento', a.fecha_nacimiento,
                 'estado', a.estado,
                 'tipo', a.tipo_membresia,
                 'grupo', (select g.nombre ||
                                  coalesce(' · ' || replace(replace(g.turno, 'lunes-miercoles', 'lunes y miércoles'),
                                                            'martes-jueves', 'martes y jueves'), '')
                             from public.grupos g where g.id = a.grupo_id),
                 'motivo', case
                             when v_p.dni is not null and a.dni is not null
                              and public.nombre_llano(a.dni) = public.nombre_llano(v_p.dni) then 'dni'
                             when v_p.fecha_nacimiento is not null
                              and a.fecha_nacimiento = v_p.fecha_nacimiento then 'mismo'
                             else 'parecido'
                           end) as x
          from public.atletas a
         where a.id is distinct from v_p.atleta_id
           and (
             -- por nombre y apellidos
             (public.nombre_llano(a.nombre) is not distinct from public.nombre_llano(v_nom)
              and public.nombre_llano(a.apellidos) is not distinct from public.nombre_llano(v_ape)
              and public.nombre_llano(v_nom) is not null)
             -- o por DNI, que en un socio es la prueba de que es él
             or (v_p.dni is not null and a.dni is not null
                 and public.nombre_llano(a.dni) = public.nombre_llano(v_p.dni))
           )
         limit 20
      ) t;

    if jsonb_array_length(v_parecidos) > 0 then
      if exists (select 1 from jsonb_array_elements(v_parecidos) e where e.value ->> 'motivo' in ('mismo', 'dni')) then
        v_avisos := v_avisos || jsonb_build_object(
          'clave', 'ya-en-el-club', 'tono', 'ojo',
          'texto', 'Ya hay una ficha con este nombre y esta misma fecha de nacimiento. Lo normal es que sea la misma persona: engánchala a la que ya existe en vez de crear otra.');
      else
        v_avisos := v_avisos || jsonb_build_object(
          'clave', 'se-parece', 'tono', 'ojo',
          'texto', 'Hay alguien en el club que se llama igual pero con otra fecha de nacimiento. Míralo antes de crear una ficha nueva.');
      end if;
    end if;

    -- --- El grupo que eligieron ---
    v_grupo := null;
    if v_p.grupo_id is not null then
      select g.* into v_g from public.grupos g where g.id = v_p.grupo_id;
      if v_g.id is null then
        -- El grupo se borró entre que la familia rellenó y hoy.
        v_avisos := v_avisos || jsonb_build_object(
          'clave', 'grupo-no-existe', 'tono', 'para',
          'texto', 'El grupo que eligieron ya no existe. Hay que elegirle otro.');
      else
        v_grupo := jsonb_build_object(
          'id', v_g.id, 'nombre', v_g.nombre, 'turno', v_g.turno, 'seccion', v_g.seccion,
          'activo', v_g.activo, 'nacidos_desde', v_g.nacidos_desde, 'nacidos_hasta', v_g.nacidos_hasta,
          'plazas', v_g.plazas, 'apuntados', public.grupo_apuntados(v_g.id),
          'entrenador_id', v_g.entrenador_id);

        if not coalesce(v_g.activo, true) then
          v_avisos := v_avisos || jsonb_build_object(
            'clave', 'grupo-cerrado', 'tono', 'para',
            'texto', 'Ese grupo está cerrado. Elígele otro o vuelve a abrirlo en Grupos.');
        end if;

        -- El año no cuadra con el grupo. Es el fallo más caro de todos:
        -- los grupos van por año de nacimiento y la familia elige a ojo.
        if v_g.nacidos_desde is not null and v_anio is not null
           and (v_anio < v_g.nacidos_desde or v_anio > coalesce(v_g.nacidos_hasta, v_g.nacidos_desde)) then
          v_avisos := v_avisos || jsonb_build_object(
            'clave', 'ano-no-cuadra', 'tono', 'ojo',
            'texto', 'Nació en ' || v_anio::text || ' y ese grupo es de los de ' ||
                     v_g.nacidos_desde::text ||
                     coalesce(nullif(' a ' || v_g.nacidos_hasta::text, ' a ' || v_g.nacidos_desde::text), '') ||
                     '. Abajo tienes el que le toca por año; el club puede dejarlo donde está si lo decide a propósito.');
        end if;

        -- Eligieron días y el grupo es del otro turno. Son grupos
        -- distintos con el mismo nombre, y acabar en el turno que no es
        -- quiere decir aparecer en la lista de asistencia del día que no
        -- viene el niño.
        if v_p.turno is not null and v_g.turno is not null and v_p.turno <> v_g.turno then
          v_avisos := v_avisos || jsonb_build_object(
            'clave', 'turno-no-cuadra', 'tono', 'ojo',
            'texto', 'Pidieron ' ||
                     (case v_p.turno when 'lunes-miercoles' then 'lunes y miércoles' else 'martes y jueves' end) ||
                     ' y ese grupo es el de ' ||
                     (case v_g.turno when 'lunes-miercoles' then 'lunes y miércoles' else 'martes y jueves' end) ||
                     '. Son dos grupos distintos con el mismo nombre.');
        end if;

        -- Lleno. Solo se dice si alguien puso las plazas de ese grupo;
        -- sin plazas puestas no se inventa ningún tope.
        if v_g.plazas is not null and public.grupo_apuntados(v_g.id) >= v_g.plazas then
          v_avisos := v_avisos || jsonb_build_object(
            'clave', 'grupo-lleno', 'tono', 'ojo',
            'texto', 'Ese grupo ya tiene ' || public.grupo_apuntados(v_g.id)::text ||
                     ' y las plazas puestas son ' || v_g.plazas::text || '.');
        end if;
      end if;
    elsif p_que = 'escuela' then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'sin-grupo', 'tono', 'para',
        'texto', 'No eligieron grupo. Hay que decir en cuál entra antes de crear la ficha.');
    else
      -- En socio no es que se les olvidara: el formulario NO pregunta el
      -- grupo, solo a qué secciones se apunta. El grupo lo pone el club.
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'sin-grupo', 'tono', 'para',
        'texto', 'El formulario de socio pregunta la sección, no el grupo. Hay que decir en cuál entrena.');
    end if;

    -- --- Los grupos que se le proponen ---
    -- En la escuela, los dos turnos del año que le toca: así el «el año
    -- no cuadra» de arriba se arregla de un toque.
    -- En socio, los de las secciones que marcó, que es lo único que el
    -- formulario pregunta.
    if p_que = 'escuela' and v_anio is not null then
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', g.id, 'nombre', g.nombre, 'turno', g.turno, 'seccion', g.seccion,
               'apuntados', public.grupo_apuntados(g.id), 'plazas', g.plazas)
               order by g.turno), '[]'::jsonb)
        into v_opciones
        from public.grupos g
       where g.seccion = 'escuela' and coalesce(g.activo, true)
         and g.nacidos_desde is not null
         and v_anio between g.nacidos_desde and coalesce(g.nacidos_hasta, g.nacidos_desde);
    elsif p_que = 'socio' and v_p.secciones is not null then
      -- El formulario y los grupos no llaman igual a lo mismo: la
      -- familia marca «atletismo» y los grupos de pista están en la
      -- sección «competicion». Sin esta traducción, marcar atletismo no
      -- ofrecía ni un grupo y parecía que no había ninguno.
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', g.id, 'nombre', g.nombre, 'turno', g.turno, 'seccion', g.seccion,
               'apuntados', public.grupo_apuntados(g.id), 'plazas', g.plazas)
               order by g.seccion, g.nombre), '[]'::jsonb)
        into v_opciones
        from public.grupos g
       where coalesce(g.activo, true)
         and g.seccion = any(
               select case s when 'atletismo' then 'competicion' else s end
                 from unnest(v_p.secciones) s)
         and g.nacidos_desde is null;   -- los de año son de la escuela
    else
      v_opciones := '[]'::jsonb;
    end if;

    -- --- Lo que la ficha necesita y el formulario no pidió ---
    -- El sexo hace falta para la licencia federativa y para las listas
    -- de competición, y el formulario de la escuela no lo pregunta. No
    -- impide crear la ficha; se pide aquí para no tener que volver.
    if v_p.sexo is null then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'sin-sexo', 'tono', 'nota',
        'texto', 'El formulario no pregunta el sexo y la licencia federativa lo pide. Se puede poner ahora o dejarlo para después.');
    end if;

    if v_p.permiso_imagen is null then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'sin-permiso-imagen', 'tono', 'nota',
        'texto', 'No contestaron a lo de las fotos, así que cuenta como un NO: no se puede publicar ninguna foto suya.');
    end if;

    if p_que = 'escuela' and not v_p.tiene_sip then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'sin-sip', 'tono', 'nota',
        'texto', 'No pusieron la tarjeta sanitaria. Hace falta el día que haya que llevarle al médico.');
    end if;

    -- El DNI del alta NO se copia a la ficha, y hay que decirlo aquí
    -- porque si no parece un olvido. En el alta está tapado y se
    -- destapa dejando dicho quién lo miró (migración 115); en la ficha
    -- del atleta lo vería su entrenador sin que nadie se enterara.
    -- Copiarlo automáticamente convertiría una puerta con cerradura en
    -- una puerta abierta, así que se copia a mano el día que haga falta.
    if p_que = 'socio' then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'dni-no-se-copia', 'tono', 'nota',
        'texto', 'El DNI se queda en el alta, tapado. Si la licencia lo necesita en la ficha, se pone a mano desde Atletas.');
    end if;

    -- --- Lo que se propone escribir en la ficha ---
    -- Las alergias van a las observaciones de la ficha, y esa es la
    -- única forma de que el entrenador las vea: el alta solo la leen
    -- administración y tesorería, y quien está en la pista es él.
    -- Se enseña en una casilla que se puede borrar antes de aceptar.
    v_obs := null;
    if v_p.alergias is not null and btrim(v_p.alergias) <> '' then
      v_obs := 'Alergias: ' || btrim(v_p.alergias);
    end if;
    if v_alta.quien_recoge is not null and btrim(v_alta.quien_recoge) <> '' then
      v_obs := coalesce(v_obs || E'\n', '') || 'Puede recogerle: ' || btrim(v_alta.quien_recoge);
    end if;

    v_prop := jsonb_build_object(
      'nombre',           v_nom,
      'apellidos',        v_ape,
      'fecha_nacimiento', v_p.fecha_nacimiento,
      'categoria',        public.categoria_por_nacimiento(v_p.fecha_nacimiento),
      'sexo',             v_p.sexo,
      'estado',           'activo',
      'tipo_membresia',   p_que,
      'grupo_id',         v_p.grupo_id,
      'observaciones',    v_obs,
      'nombre_tutor',     case when p_que = 'escuela' then v_alta.tutor_nombre end,
      'email_tutor',      case when p_que = 'escuela' then v_alta.tutor_email end,
      'telefono_tutor',   case when p_que = 'escuela' then v_alta.tutor_telefono end,
      'email',            case when p_que = 'socio'   then v_alta.tutor_email end,
      'telefono',         case when p_que = 'socio'   then v_alta.tutor_telefono end);

    v_personas := v_personas || jsonb_build_object(
      'id',              v_p.id,
      'orden',           v_p.orden,
      'nombre_tal_cual', v_p.nombre_tal_cual,
      'turno_pedido',    v_p.turno,
      'secciones',       v_p.secciones,
      'alergias',        v_p.alergias,
      'propuesta',       v_prop,
      'ya_creada',       v_ya,
      'parecidos',       v_parecidos,
      'grupo',           v_grupo,
      'grupos_sugeridos', v_opciones,
      'avisos',          v_avisos);
  end loop;

  if jsonb_array_length(v_personas) = 0 then
    v_gen := v_gen || jsonb_build_object(
      'clave', 'alta-vacia', 'tono', 'para',
      'texto', 'Esta alta no trae a nadie apuntado. No debería pasar: avisa antes de tocarla.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'que', p_que,
    'alta', jsonb_build_object(
      'id', v_alta.id, 'referencia', v_alta.referencia, 'temporada', v_alta.temporada,
      'estado', v_alta.estado, 'quien', v_alta.tutor_nombre, 'email', v_alta.tutor_email,
      'telefono', v_alta.tutor_telefono, 'created_at', v_alta.created_at, 'nota_club', v_alta.nota_club),
    'avisos', v_gen,
    'personas', v_personas);
end;
$$;

comment on function public.alta_examen(text, uuid) is
  'Mira un alta y propone una ficha por cada persona que trae, con la lista de '
  'lo que huele mal: que ya está en el club, que el año no cuadra con el grupo, '
  'que el grupo está lleno o cerrado, o que falta un dato. NO escribe nada.';


-- ============================================================
-- 5 · CREAR UNA FICHA · UNA, Y CON ALGUIEN MIRANDO
-- ------------------------------------------------------------
-- `p_datos` viene de la pantalla con lo que se ve en ella, ya
-- corregido a mano. Lo que trae:
--
--   nombre, apellidos, fecha_nacimiento, sexo, categoria,
--   observaciones            → los campos de la ficha
--   grupos: [uuid, …]        → en qué grupos entra (la 116 deja varios)
--   grupo_principal: uuid    → cuál sale en la ficha
--   enlazar_con: uuid | null → si en vez de crear hay que engancharla
--                              a una ficha que ya existe
--
-- LO QUE ESTA FUNCIÓN NO SE CREE
-- No se cree que la pantalla haya comprobado nada. Vuelve a mirar los
-- papeles, que el alta no esté rechazada, que esa persona no tenga ya
-- ficha y que los grupos existan y estén abiertos. Una comprobación
-- que solo vive en el navegador se la salta cualquiera.
--
-- LO QUE SÍ SE CREE, Y ES A PROPÓSITO
-- Se cree los avisos de tono 'ojo': si alguien ha mirado que el año no
-- cuadra y aun así ha dicho que ese grupo, es porque el club lo ha
-- decidido. Aquí no se le lleva la contraria a una persona que acaba
-- de leer el aviso.
--
-- ENLAZAR EN VEZ DE CREAR
-- Cuando es alguien que ya está en el club (un hermano que renueva),
-- no se crea una ficha nueva y NO se pisa la que hay. Solo se rellena
-- lo que estuviera vacío y se le añaden los grupos nuevos. Machacar
-- una ficha con lo que puso una familia en un formulario borraría el
-- trabajo de un entrenador de todo el curso.
-- ============================================================
create or replace function public.alta_crear_ficha(p_que text, p_persona_id uuid, p_datos jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
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
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración y tesorería pueden crear fichas desde un alta';
  end if;
  if p_que not in ('escuela', 'socio') then
    raise exception 'No sé qué alta es «%»', p_que;
  end if;

  select id into v_perfil from public.perfiles where email = (auth.jwt() ->> 'email');

  -- ---------- de qué alta viene y si esa alta deja ----------
  if p_que = 'escuela' then
    select n.alta_id, n.atleta_id into v_alta_id, v_atleta
      from public.altas_escuela_ninos n where n.id = p_persona_id;
    if v_alta_id is null then
      return jsonb_build_object('ok', false, 'motivo', 'no-esta');
    end if;
    select a.estado into v_alta_est from public.altas_escuela a where a.id = v_alta_id;
  else
    select s.id, s.estado into v_alta_id, v_alta_est
      from public.altas_socio s where s.id = p_persona_id;
    if v_alta_id is null then
      return jsonb_build_object('ok', false, 'motivo', 'no-esta');
    end if;
    -- En socio no hay columna que diga «ya se convirtió»: se mira si
    -- hay una ficha con ese mismo DNI, que es lo que identifica a un
    -- adulto sin lugar a dudas.
    select a.id into v_atleta
      from public.atletas a
      join public.altas_socio s on s.id = p_persona_id
     where a.dni is not null and public.nombre_llano(a.dni) = public.nombre_llano(s.dni)
     limit 1;
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
      observaciones, nombre_tutor, email_tutor, telefono_tutor, email, telefono)
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
      public.texto_de_fuera(p_datos ->> 'telefono', 30))
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
    -- En socio no hay `atleta_id`: lo que hay es `perfil_id`, que es
    -- otra cosa (la cuenta del portal, que aquí no se crea). El alta se
    -- da por revisada y la ficha queda enganchada por el DNI.
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
  'Crea la ficha de UNA persona de un alta, o la engancha a la que ya existe. '
  'Una por llamada, a propósito: en un alta vienen hermanos y si uno falla el '
  'otro no se puede perder.';


-- ============================================================
-- 6 · QUIÉN PUEDE LLAMAR A CADA PUERTA
-- ------------------------------------------------------------
-- Igual que en la 114 y la 115: primero se le quita a todo el mundo y
-- después se le da a quien toca. A `anon` —quien no ha entrado— no se
-- le da nada de nada.
-- ============================================================
revoke all on function public.alta_examen(text, uuid)                  from public;
revoke all on function public.alta_crear_ficha(text, uuid, jsonb)      from public;
revoke all on function public.nombre_llano(text)                       from public;
revoke all on function public.partir_nombre(text)                      from public;
revoke all on function public.categoria_por_nacimiento(date)           from public;
revoke all on function public.grupo_apuntados(uuid)                    from public;

grant execute on function public.alta_examen(text, uuid)               to authenticated;
grant execute on function public.alta_crear_ficha(text, uuid, jsonb)   to authenticated;
-- Estas cuatro son cuentas, no datos: cogen un texto o una fecha y
-- devuelven otro texto o un número. `grupo_apuntados` es la única que
-- lee una tabla, y solo devuelve cuántos son, nunca quiénes. Se dan a
-- `authenticated` para que las pantallas del panel puedan usarlas
-- —Grupos las quiere para enseñar cuánta gente hay en cada uno—.
grant execute on function public.nombre_llano(text)                    to authenticated;
grant execute on function public.partir_nombre(text)                   to authenticated;
grant execute on function public.categoria_por_nacimiento(date)        to authenticated;
grant execute on function public.grupo_apuntados(uuid)                 to authenticated;

-- `apo_sin_tildes` la usa `nombre_llano` por dentro. Como
-- `nombre_llano` no es `security definer`, se comprueba contra quien
-- llama, y sin este permiso daría «permiso denegado» a todo el mundo.
grant execute on function public.apo_sin_tildes(text)                  to authenticated;

commit;

-- Que la API se entere de la columna y de las funciones nuevas sin
-- esperar a que se le ocurra sola.
notify pgrst, 'reload schema';
