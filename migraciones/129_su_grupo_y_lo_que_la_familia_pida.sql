-- ============================================================
-- 129 · El grupo que le toca por su año, y lo que la familia pida
-- ------------------------------------------------------------
-- LO QUE VIO EL DUEÑO SIGUIENDO EL FORMULARIO COMO UN PADRE
--   «Mi hijo puede tener 5 años y llevarle a un grupo que no puede
--    ir.»
-- Y lo que matizó después, que es lo que manda:
--   «Hay requisitos internos para subir. No lo añadas. Los de
--    primera hora están claros. Van a pagar lo mismo, así que nada.
--    Los de 2ª hora sí que hay más decisión.»
--
-- ------------------------------------------------------------
-- LO QUE ESTE ARCHIVO NO HACE, Y ES LA MITAD DE LA DECISIÓN
--
-- NO ESCRIBE NINGUNA REGLA DE QUIÉN PUEDE SUBIR DE GRUPO. Ni aquí
-- ni en el formulario. Quién pasa al grupo de competición lo decide
-- el club mirando al chaval —hay requisitos internos que no están en
-- ninguna base de datos—, y cualquier regla que escribiéramos aquí
-- sería mentira el primer día y habría que pelearse con ella cada
-- septiembre.
--
-- NO CIERRA NINGUNA PUERTA. En la escuela de primera hora los grupos
-- van por año de nacimiento y TODOS PAGAN LO MISMO, así que
-- equivocarse de color no tiene consecuencia ni de dinero ni de
-- plaza. El formulario propone el que le toca por su año, que es lo
-- cómodo, y si una familia quiere otra cosa lo dice y ya está: quien
-- revisa el alta lo ve, y además sigue saltando el aviso de «nació
-- en tal año y ese grupo es de los de tal otro» de la migración 121.
--
-- ------------------------------------------------------------
-- LO QUE SÍ HACE: UNA CASILLA PARA PEDIR
--
-- El formulario solo ofrece los grupos de PRIMERA HORA, los de por
-- año de nacimiento. Los de segunda hora y el de competición no
-- salen, y no salen a propósito: ahí entra el nivel del chaval y el
-- criterio del entrenador, y enseñarlos en una lista los convertiría
-- en «una opción más» que se marca sin saber lo que se marca.
--
-- Pero una familia puede tener un motivo de verdad —dos hermanos que
-- quieren coincidir, un crío que ya entrena fuera, la sospecha de que
-- su hija se aburre con los de su edad—. Antes eso se perdía: llegaba
-- por WhatsApp en septiembre o no llegaba. Ahora se escribe con el
-- alta, en `peticion_grupo`, y aparece en la pantalla de convertir
-- como algo que hay que decidir ANTES de crear la ficha.
--
-- Es la diferencia entre «no puedes» y «pídelo y te contestamos», y
-- es toda la diferencia para quien está rellenando el formulario a
-- las once de la noche con el niño ya dormido.
--
-- ------------------------------------------------------------
-- ⚠️ LAS ALTAS QUE YA ESTÁN ENTRADAS NO SE ROMPEN
-- La columna nace VACÍA y se queda vacía en todo lo anterior, porque
-- a esas familias no se les preguntó. Igual que el sexo en la 122 y
-- que el documento del niño en la 128.
--
-- NADA PERSONAL AQUÍ DENTRO
-- Este archivo queda en el histórico para siempre y el repositorio es
-- público.
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta. No borra ni una ficha.
-- ============================================================

begin;

-- ============================================================
-- 1 · LO QUE LA FAMILIA PIDE
-- ------------------------------------------------------------
-- Texto libre y no una lista de grupos, y esto es a propósito: si
-- fuera una lista, elegir «Grupo de competición» sería un clic, y un
-- clic no es una conversación. Escrito con sus palabras se lee el
-- MOTIVO —«queremos que coincida con su hermana», «lleva dos años en
-- otro club»—, que es justo lo que el club necesita para decidir.
-- ============================================================
alter table public.altas_escuela_ninos
  add column if not exists peticion_grupo text;

comment on column public.altas_escuela_ninos.peticion_grupo is
  'Lo que la familia pide sobre el grupo, con sus palabras: otro color, otro '
  'turno, coincidir con un hermano, o que creen que le corresponde el grupo de '
  'competición. El formulario NO les deja elegir esos grupos —eso lo decide el '
  'club mirando al chaval, y hay requisitos internos que no caben en una base '
  'de datos—, pero sí pedirlo. Vacío en las altas anteriores a agosto de 2026 '
  'y en las de quien no pidió nada, que son casi todas.';


-- ------------------------------------------------------------
-- La vista del panel lo enseña. Es la de la 128 con una línea más.
-- ------------------------------------------------------------
drop view if exists public.altas_escuela_ninos_panel;
create view public.altas_escuela_ninos_panel
with (security_invoker = true) as
select
  n.id,
  n.alta_id,
  n.orden,
  -- El nombre entero, que es el que se enseña en todas partes. En las
  -- altas nuevas sale de juntar las tres casillas; en las viejas es lo
  -- que escribió la familia de una tirada.
  n.nombre,
  n.nombre_pila,
  n.apellido1,
  n.apellido2,
  -- La fecha de nacimiento se ve entera y tiene que ser así: es la
  -- que decide en qué grupo cae el niño, y comprobar eso es la mitad
  -- del trabajo de revisar un alta de escuela.
  n.fecha_nacimiento,
  n.sexo,

  public.tapado(n.sip)      as sip_tapado,
  (n.sip is not null)       as tiene_sip,

  -- El documento del niño, tapado igual que el del tutor. Se ven las
  -- dos cosas por separado porque hacen falta las dos: si hay algo
  -- puesto (para reconocerlo) y si la familia dijo que todavía no
  -- tiene (para no llamar a pedir lo que no existe).
  public.tapado(n.dni)      as dni_tapado,
  (n.dni is not null)       as tiene_dni,
  n.sin_dni,

  n.turno,
  n.grupo_id,
  n.grupo_nombre,
  -- Lo que la familia pidió sobre el grupo. Va entero: es una frase
  -- escrita para que alguien la lea y conteste.
  n.peticion_grupo,
  -- Con quién le gustaría entrenar. Va entero y sin tapar: son
  -- nombres que escribió la familia para que el club los lea al
  -- repartir los grupos, que es justo para lo que existe el dato.
  n.amigos,
  -- Las alergias se ven enteras y sin tapar nada. Es un dato de
  -- salud, sí, y precisamente por eso: existe para que alguien lo
  -- lea antes de que el crío pise la pista.
  n.alergias,
  n.permiso_imagen,
  n.permiso_imagen_ambitos,
  n.texto_imagen,
  n.talla_camiseta,
  n.talla_sudadera,
  n.atleta_id,
  n.created_at
from public.altas_escuela_ninos n;

comment on view public.altas_escuela_ninos_panel is
  'Los hijos de un alta de escuela, con la tarjeta sanitaria y el documento '
  'tapados.';

grant select on public.altas_escuela_ninos_panel to authenticated;
grant all    on public.altas_escuela_ninos_panel to service_role;


-- ============================================================
-- 2 · LA PUERTA DE ENTRADA GUARDA LA PETICIÓN
-- ------------------------------------------------------------
-- Es la función de la 128 con DOS LÍNEAS MÁS: la columna en el
-- `insert` y el valor sacado del paquete. Se copia entera porque en
-- SQL una función se cambia entera o no se cambia.
--
-- El grupo se sigue buscando en la base por el año de nacimiento y
-- los días, y sigue SIN CREERSE lo que diga el navegador. Eso no
-- cambia y es lo que de verdad cierra el agujero: aunque alguien
-- manipulara el formulario para mandar otro turno, de aquí no puede
-- salir un grupo que no sea el de su año. Lo que la familia pide se
-- guarda APARTE, como lo que es: una petición, no una decisión.
-- ============================================================
create or replace function public.enviar_alta_escuela(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_email     text := lower(public.texto_de_fuera(p ->> 'tutor_email', 160));
  v_ninos     jsonb := coalesce(p -> 'ninos', '[]'::jsonb);
  v_nino      jsonb;
  v_alta_id   uuid;
  v_ref       text;
  v_i         int := 0;
  v_primero   text;
  v_ya        uuid;
  v_segundos  int := coalesce((p ->> 'segundos')::int, 0);
  v_tutor     text;
  v_nombre    text;
begin
  -- El cepo para robots: un campo escondido que una persona no ve y
  -- por tanto nunca rellena, y el tiempo que se ha tardado. Nadie
  -- apunta a un hijo en seis segundos. Se contesta que sí para no
  -- enseñarle al robot dónde está la trampa, pero no se guarda.
  if public.texto_de_fuera(p ->> 'apellido_de_soltera', 100) is not null
     or v_segundos < 6 then
    return jsonb_build_object('ok', true, 'referencia', public.referencia_corta('ESC'));
  end if;

  if not public.altas_hay_sitio('escuela') then
    return jsonb_build_object('ok', false, 'motivo', 'demasiados',
      'mensaje', 'Ahora mismo no podemos recoger más altas. Prueba dentro de un rato o llámanos.');
  end if;

  if v_email is null or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'motivo', 'correo',
      'mensaje', 'Ese correo no parece bien escrito. Revísalo, por favor.');
  end if;

  if jsonb_array_length(v_ninos) = 0 or jsonb_array_length(v_ninos) > 6 then
    return jsonb_build_object('ok', false, 'motivo', 'ninos',
      'mensaje', 'Falta el niño o la niña que se apunta.');
  end if;

  -- El nombre de quien apunta: de las tres casillas si vienen, y si no
  -- de la casilla única de siempre.
  v_tutor := coalesce(
    public.nombre_junto(
      public.texto_de_fuera(p ->> 'tutor_nombre_pila', 60),
      public.texto_de_fuera(p ->> 'tutor_apellido1',   60),
      public.texto_de_fuera(p ->> 'tutor_apellido2',   60)),
    public.texto_de_fuera(p ->> 'tutor_nombre', 120));

  if v_tutor is null
     or public.texto_de_fuera(p ->> 'tutor_telefono', 30) is null then
    return jsonb_build_object('ok', false, 'motivo', 'familia',
      'mensaje', 'Faltan el nombre y el teléfono de quien apunta.');
  end if;

  if coalesce((p ->> 'acepta_normas')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'motivo', 'normas',
      'mensaje', 'Hay que aceptar las normas del club para poder apuntarse.');
  end if;

  -- Que ninguno venga sin nombre, y se comprueba ANTES de escribir
  -- nada: si se descubriera a mitad del bucle habría que tirar el alta
  -- ya empezada, y la familia vería un error feo en vez de saber qué
  -- le falta.
  for v_nino in select * from jsonb_array_elements(v_ninos) loop
    if coalesce(
         public.nombre_junto(
           public.texto_de_fuera(v_nino ->> 'nombre_pila', 60),
           public.texto_de_fuera(v_nino ->> 'apellido1',   60),
           public.texto_de_fuera(v_nino ->> 'apellido2',   60)),
         public.texto_de_fuera(v_nino ->> 'nombre', 120)) is null then
      return jsonb_build_object('ok', false, 'motivo', 'ninos',
        'mensaje', 'Falta el nombre de uno de los niños que se apuntan.');
    end if;
  end loop;

  -- El nombre entero del primero, que es con el que se busca si esta
  -- misma alta acaba de entrar hace un momento.
  v_primero := lower(coalesce(
    public.nombre_junto(
      public.texto_de_fuera(v_ninos -> 0 ->> 'nombre_pila', 60),
      public.texto_de_fuera(v_ninos -> 0 ->> 'apellido1',   60),
      public.texto_de_fuera(v_ninos -> 0 ->> 'apellido2',   60)),
    public.texto_de_fuera(v_ninos -> 0 ->> 'nombre', 120)));

  -- ¿Esto ya lo hemos recibido hace un momento?
  select a.id into v_ya
    from public.altas_escuela a
    join public.altas_escuela_ninos n on n.alta_id = a.id and n.orden = 1
   where lower(a.tutor_email) = v_email
     and lower(n.nombre) = v_primero
     and a.created_at > now() - interval '1 hour'
   limit 1;

  if v_ya is not null then
    return jsonb_build_object('ok', true, 'repetida', true,
      'referencia', (select referencia from public.altas_escuela where id = v_ya));
  end if;

  v_ref := public.referencia_corta('ESC');

  insert into public.altas_escuela (
    referencia, tutor_nombre, tutor_nombre_pila, tutor_apellido1, tutor_apellido2,
    tutor_dni, tutor_email, tutor_telefono,
    direccion, cp, localidad, quien_recoge, como_nos_conocio,
    iban, forma_pago, acepta_normas, texto_normas, ip, navegador
  ) values (
    v_ref,
    v_tutor,
    public.texto_de_fuera(p ->> 'tutor_nombre_pila', 60),
    public.texto_de_fuera(p ->> 'tutor_apellido1',   60),
    public.texto_de_fuera(p ->> 'tutor_apellido2',   60),
    -- El documento, en mayúsculas y sin puntos ni guiones. El mismo
    -- documento escrito de dos maneras no puede parecer dos personas.
    nullif(upper(regexp_replace(
      coalesce(public.texto_de_fuera(p ->> 'tutor_dni', 20), ''), '[^A-Za-z0-9]', '', 'g')), ''),
    v_email,
    public.texto_de_fuera(p ->> 'tutor_telefono', 30),
    public.texto_de_fuera(p ->> 'direccion', 200),
    public.texto_de_fuera(p ->> 'cp', 10),
    public.texto_de_fuera(p ->> 'localidad', 80),
    public.texto_de_fuera(p ->> 'quien_recoge', 400),
    public.texto_de_fuera(p ->> 'como_nos_conocio', 60),
    upper(replace(coalesce(public.texto_de_fuera(p ->> 'iban', 40), ''), ' ', '')),
    public.texto_de_fuera(p ->> 'forma_pago', 20),
    true,
    public.texto_de_fuera(p ->> 'texto_normas', 2000),
    public.ip_peticion(),
    public.navegador_peticion()
  ) returning id into v_alta_id;

  -- Si el IBAN venía vacío queda vacío, no una cadena de nada.
  update public.altas_escuela set iban = nullif(iban, '') where id = v_alta_id;

  for v_nino in select * from jsonb_array_elements(v_ninos) loop
    v_i := v_i + 1;

    v_nombre := coalesce(
      public.nombre_junto(
        public.texto_de_fuera(v_nino ->> 'nombre_pila', 60),
        public.texto_de_fuera(v_nino ->> 'apellido1',   60),
        public.texto_de_fuera(v_nino ->> 'apellido2',   60)),
      public.texto_de_fuera(v_nino ->> 'nombre', 120));

    insert into public.altas_escuela_ninos (
      alta_id, orden, nombre, nombre_pila, apellido1, apellido2,
      fecha_nacimiento, sexo, sip, dni, sin_dni, amigos, turno,
      grupo_id, grupo_nombre, peticion_grupo, alergias,
      permiso_imagen, permiso_imagen_ambitos, texto_imagen,
      talla_camiseta, talla_sudadera
    ) values (
      v_alta_id, v_i,
      v_nombre,
      public.texto_de_fuera(v_nino ->> 'nombre_pila', 60),
      public.texto_de_fuera(v_nino ->> 'apellido1',   60),
      public.texto_de_fuera(v_nino ->> 'apellido2',   60),
      (v_nino ->> 'fecha_nacimiento')::date,
      -- Si viene algo que no es ninguno de los tres, se guarda vacío.
      -- Un alta no se pierde por un campo que alguien haya trasteado.
      (case when lower(public.texto_de_fuera(v_nino ->> 'sexo', 10))
                 = any (array['hombre', 'mujer', 'otro'])
            then lower(public.texto_de_fuera(v_nino ->> 'sexo', 10)) end),
      public.texto_de_fuera(v_nino ->> 'sip', 30),
      -- El DNI o el NIE del niño, limpiado igual que el del tutor. Aquí
      -- NO se comprueba el formato: se admite lo que traigan, porque un
      -- pasaporte o un documento de fuera no puede dejar a un niño sin
      -- apuntarse. El aviso de «esto no parece un DNI» lo da el
      -- formulario, y no frena.
      nullif(upper(regexp_replace(
        coalesce(public.texto_de_fuera(v_nino ->> 'dni', 20), ''), '[^A-Za-z0-9]', '', 'g')), ''),
      -- Solo se guarda si viene un sí o un no de verdad. Vacío quiere
      -- decir «no se preguntó», que es lo que pasa con las altas viejas.
      (case when v_nino ->> 'sin_dni' in ('true', 'false')
            then (v_nino ->> 'sin_dni')::boolean end),
      -- Los amigos, tal y como los escribieron y como mucho seis. No se
      -- busca a nadie ni se engancha con ninguna ficha: el amigo puede
      -- no estar apuntado todavía.
      (select array_agg(t.x)
         from (select public.texto_de_fuera(e.value, 120) as x
                 from jsonb_array_elements_text(
                        case when jsonb_typeof(v_nino -> 'amigos') = 'array'
                             then v_nino -> 'amigos' else '[]'::jsonb end) e(value)
                limit 6) t
        where t.x is not null),
      public.texto_de_fuera(v_nino ->> 'turno', 20),
      -- El grupo NO se cree lo que diga el navegador: se busca en la
      -- base por el año de nacimiento y los días, que es de donde
      -- sale de verdad. Si el navegador mandara otro, se ignora.
      --
      -- AQUÍ ESTÁ EL CIERRE DE VERDAD del agujero que vio el dueño: de
      -- estas dos consultas no puede salir un grupo que no sea el de su
      -- año, se manipule el formulario como se manipule.
      (select g.id from public.grupos g
        where g.seccion = 'escuela' and g.activo
          and g.turno = public.texto_de_fuera(v_nino ->> 'turno', 20)
          and extract(year from (v_nino ->> 'fecha_nacimiento')::date)::int
              between coalesce(g.nacidos_desde, 0) and coalesce(g.nacidos_hasta, 9999)
        limit 1),
      (select g.nombre from public.grupos g
        where g.seccion = 'escuela' and g.activo
          and g.turno = public.texto_de_fuera(v_nino ->> 'turno', 20)
          and extract(year from (v_nino ->> 'fecha_nacimiento')::date)::int
              between coalesce(g.nacidos_desde, 0) and coalesce(g.nacidos_hasta, 9999)
        limit 1),
      -- Y lo que la familia pida, aparte y en sus palabras. No mueve
      -- ni un grupo: lo lee una persona.
      public.texto_de_fuera(v_nino ->> 'peticion_grupo', 600),
      public.texto_de_fuera(v_nino ->> 'alergias', 600),
      (v_nino ->> 'permiso_imagen')::boolean,
      case when v_nino ? 'permiso_imagen_ambitos'
           then array(select jsonb_array_elements_text(v_nino -> 'permiso_imagen_ambitos'))
           else null end,
      public.texto_de_fuera(v_nino ->> 'texto_imagen', 600),
      public.texto_de_fuera(v_nino ->> 'talla_camiseta', 10),
      public.texto_de_fuera(v_nino ->> 'talla_sudadera', 10)
    );
  end loop;

  return jsonb_build_object('ok', true, 'referencia', v_ref);
end;
$function$;

revoke all on function public.enviar_alta_escuela(jsonb) from public;
grant execute on function public.enviar_alta_escuela(jsonb) to anon, authenticated;


-- ============================================================
-- 3 · EL EXAMEN ENSEÑA LO QUE PIDIERON
-- ------------------------------------------------------------
-- Es el de la 128 con UN aviso más, y va en tono «ojo» —de los que
-- obligan a mirar pero no frenan— porque es una decisión del club que
-- hay que tomar ANTES de crear la ficha: después, mover a un crío de
-- grupo ya es rehacer listas.
--
-- El aviso de «nació en tal año y ese grupo es de los de tal otro» de
-- la 121 se queda donde estaba y no se toca: es la red de abajo para
-- las altas viejas y para cuando alguien mueva un grupo a mano.
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
      select n.id, n.orden, n.nombre as nombre_tal_cual,
             n.nombre_pila, n.apellido1, n.apellido2,
             n.fecha_nacimiento,
             n.grupo_id, n.grupo_nombre, n.turno, n.alergias, n.atleta_id,
             n.permiso_imagen, (n.sip is not null) as tiene_sip,
             null::text as dni, n.sexo, null::text[] as secciones,
             (n.dni is not null) as tiene_dni_propio, n.sin_dni, n.amigos,
             n.peticion_grupo
        from public.altas_escuela_ninos n
       where p_que = 'escuela' and n.alta_id = p_id
      union all
      -- Un alta de socio es una sola persona: ella misma. Desde la 122
      -- también tiene su propia casilla de «a qué ficha dio lugar».
      select s.id, 1 as orden,
             btrim(coalesce(s.nombre, '') || ' ' || coalesce(s.apellidos, '')) as nombre_tal_cual,
             s.nombre as nombre_pila, s.apellidos as apellido1, null::text as apellido2,
             s.fecha_nacimiento, null::uuid as grupo_id, null::text as grupo_nombre,
             null::text as turno, null::text as alergias,
             s.atleta_id,
             s.permiso_imagen, false as tiene_sip,
             s.dni, s.sexo, s.secciones,
             false as tiene_dni_propio, null::boolean as sin_dni, null::text[] as amigos,
             null::text as peticion_grupo
        from public.altas_socio s
       where p_que = 'socio' and s.id = p_id
    ) q
    order by q.orden
  loop
    v_avisos := '[]'::jsonb;
    v_anio   := extract(year from v_p.fecha_nacimiento)::int;

    -- --- El nombre ---
    -- Desde agosto de 2026 el formulario de la escuela lo pide en tres
    -- casillas, así que no hay nada que adivinar. El de socio lo pedía
    -- partido desde el principio. Solo queda por partir lo que entró
    -- antes, y para eso sigue estando la regla de la 121.
    if v_p.nombre_pila is not null then
      v_nom := v_p.nombre_pila;
      v_ape := public.nombre_junto(null, v_p.apellido1, v_p.apellido2);
    else
      v_partido := public.partir_nombre(v_p.nombre_tal_cual);
      v_nom := v_partido ->> 'nombre';
      v_ape := v_partido ->> 'apellidos';
    end if;

    if v_ape is null or v_ape = '' then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'sin-apellidos', 'tono', 'ojo',
        'texto', 'No hay apellidos. Compruébalo antes de crear la ficha.');
    elsif p_que = 'escuela' and v_p.nombre_pila is null then
      -- Solo en las altas de antes de agosto de 2026, que pedían el
      -- nombre entero en una casilla. En las nuevas la familia ya lo
      -- escribió partido y este aviso sería ruido.
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'nombre-partido', 'tono', 'nota',
        'texto', 'Esta alta es de cuando el formulario pedía el nombre entero en una casilla; lo de arriba es cómo se ha partido. Si el nombre es compuesto, córrigelo aquí.');
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

    -- --- Lo que la familia pidió sobre el grupo ---
    -- Va en «ojo» y no en «nota»: es una decisión del club que hay que
    -- tomar ANTES de crear la ficha, porque mover a un crío de grupo
    -- después ya es rehacer listas y avisar a dos entrenadores.
    --
    -- El formulario NO les deja elegir el grupo de segunda hora ni el
    -- de competición, a propósito: para esos hay requisitos internos y
    -- hay que ver al chaval. Lo único que pueden hacer es pedirlo, y
    -- eso es lo que se lee aquí.
    if v_p.peticion_grupo is not null then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'pide-otro-grupo', 'tono', 'ojo',
        'texto', 'La familia pide otro grupo: «' || v_p.peticion_grupo ||
                 '». Decídelo antes de crear la ficha, y contéstales: el formulario les dice que lo mira el club.');
    end if;

    -- --- Con quién le gustaría entrenar ---
    -- Se dice AQUÍ, en la pantalla donde se le está eligiendo el grupo,
    -- que es el único momento en que este dato sirve para algo. No
    -- frena nada y no obliga a nada: los grupos van por año, y a veces
    -- se puede y a veces no.
    if v_p.amigos is not null and array_length(v_p.amigos, 1) > 0 then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'quiere-estar-con', 'tono', 'nota',
        'texto', 'La familia pidió que entrenara con ' || array_to_string(v_p.amigos, ', ') ||
                 '. Es una preferencia, no una promesa: si cuadra con su año, mejor.');
    end if;

    -- --- Los grupos que se le proponen ---
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

    -- --- Lo que la ficha necesita y puede que no esté ---
    -- Desde la 122 el sexo se pregunta en los dos formularios, así que
    -- este aviso ya no salta siempre: solo en las altas de antes, que
    -- entraron cuando no se preguntaba, y en quien lo dejó en blanco.
    if v_p.sexo is null then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'sin-sexo', 'tono', 'nota',
        'texto', 'No dijeron el sexo y la licencia federativa lo pide. Se puede poner ahora o dejarlo para después.');
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

    -- --- El documento del niño, con sus tres finales ---
    -- Ninguno frena: se puede crear la ficha sin documento. Lo que hace
    -- falta es saber cuál de los tres es, porque «todavía no tiene» y
    -- «no lo pusieron» son dos llamadas de teléfono distintas, y una de
    -- ellas no hay que hacerla.
    if p_que = 'escuela' then
      if v_p.tiene_dni_propio then
        -- Igual que en el alta de socio: el documento se queda en el
        -- alta, tapado, y no se copia a la ficha. En el alta se destapa
        -- dejando dicho quién lo miró (migración 115); en la ficha lo
        -- vería su entrenador sin que nadie se enterara.
        v_avisos := v_avisos || jsonb_build_object(
          'clave', 'dni-no-se-copia', 'tono', 'nota',
          'texto', 'El DNI del niño se queda en el alta, tapado. Si la licencia lo necesita en la ficha, se pone a mano desde Atletas.');
      elsif v_p.sin_dni is true then
        v_avisos := v_avisos || jsonb_build_object(
          'clave', 'todavia-sin-dni', 'tono', 'nota',
          'texto', 'La familia dijo que todavía no tiene DNI ni NIE. No hay que reclamárselo: hará falta cuando lo saque, para la licencia.');
      else
        v_avisos := v_avisos || jsonb_build_object(
          'clave', 'sin-dni-nino', 'tono', 'nota',
          'texto', 'No pusieron el DNI ni el NIE del niño y la licencia federativa lo pide. Hay que pedírselo.');
      end if;
    end if;

    -- El DNI del alta NO se copia a la ficha, y hay que decirlo aquí
    -- porque si no parece un olvido. En el alta está tapado y se
    -- destapa dejando dicho quién lo miró (migración 115); en la ficha
    -- del atleta lo vería su entrenador sin que nadie se enterara.
    if p_que = 'socio' then
      v_avisos := v_avisos || jsonb_build_object(
        'clave', 'dni-no-se-copia', 'tono', 'nota',
        'texto', 'El DNI se queda en el alta, tapado. Si la licencia lo necesita en la ficha, se pone a mano desde Atletas.');
    end if;

    -- --- Lo que se propone escribir en la ficha ---
    -- Las alergias van a las observaciones de la ficha, y esa es la
    -- única forma de que el entrenador las vea: el alta solo la leen
    -- administración y tesorería, y quien está en la pista es él.
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
      'amigos',          to_jsonb(coalesce(v_p.amigos, '{}'::text[])),
      'peticion_grupo',  v_p.peticion_grupo,
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
  'que el grupo está lleno o cerrado, que la familia pide otro, o que falta un '
  'dato. NO escribe nada.';

revoke all on function public.alta_examen(text, uuid)    from public;
grant execute on function public.alta_examen(text, uuid) to authenticated;

commit;

-- Que la API se entere de la columna nueva sin esperar a que se le
-- ocurra sola.
notify pgrst, 'reload schema';
