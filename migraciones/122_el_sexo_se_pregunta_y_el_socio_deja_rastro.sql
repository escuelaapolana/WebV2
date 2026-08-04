-- ============================================================
-- 122 · El sexo se pregunta una vez, y el alta de socio deja rastro
-- ------------------------------------------------------------
-- DOS COSAS QUE LA 121 DEJÓ DICHAS Y AQUÍ SE ARREGLAN
--
-- 1 · EL SEXO SE LO PREGUNTAMOS A QUIEN LO SABE
-- La ficha del atleta tiene casilla de sexo porque la licencia
-- federativa lo pide, y el formulario de la escuela no lo
-- preguntaba. Así que al convertir un alta salía un aviso de «falta
-- el sexo» y quien revisaba cien altas una mañana acababa
-- deduciéndolo del nombre. Deducirlo del nombre es exactamente lo
-- que no queremos que pase: hay nombres que no lo dicen, hay
-- nombres de fuera, y acertar el 95 % de las veces significa
-- equivocarse en cinco críos de cada cien.
--
-- Se pregunta en el formulario, una vez, a la familia, que lo sabe
-- y tarda dos segundos. El alta de socio ya lo preguntaba desde la
-- 114; esto es ponerlo también en la de escuela y que las dos
-- pregunten igual.
--
-- QUÉ VALORES, Y POR QUÉ ESTOS
-- La normativa de licencias de la RFEA llama «sexo» a este dato y
-- el atletismo federado lo lleva a dos categorías, masculino y
-- femenino: no hay una tercera en la que inscribir a nadie. En la
-- app ese dato ya existía y ya se guardaba como «hombre» y «mujer»
-- —en `atletas.sexo` y en `altas_socio.sexo`—, que es lo mismo
-- dicho con las palabras que usa el club. Se usan esas y no se
-- inventa ninguna nueva.
--
-- «Otro» también se admite, y conviene entender por qué está y qué
-- pasa con él: estaba ya en la ficha del atleta y en el alta de
-- socio antes de esto, y quitarlo de una de las tres pantallas
-- dejaría a la app diciendo dos cosas distintas. Lo que hay que
-- saber es que la licencia federativa NO lo puede llevar: quien lo
-- marque y además se federe habrá que hablarlo con él. Es una
-- conversación del club, no algo que decida un formulario.
--
-- ⚠️ LAS ALTAS QUE YA ESTÁN ENTRADAS NO SE ROMPEN
-- La casilla nace VACÍA y se queda vacía en todas las altas de
-- antes, porque a esas familias no se les preguntó. Vacío no impide
-- convertir nada: sigue saliendo el aviso de «falta» —de los que no
-- frenan— y se rellena a mano al crear la ficha, como hasta ahora.
-- Poner un valor por defecto sería peor que dejarlo vacío: llenaría
-- de datos inventados unas altas que nadie contestó.
--
-- 2 · UN ALTA DE SOCIO DEJA ESCRITO A QUÉ FICHA DIO LUGAR
-- En la escuela eso ya estaba: `altas_escuela_ninos.atleta_id`. En
-- socio no había ninguna casilla, así que la 121 lo resolvía
-- buscando una ficha con el mismo DNI. Eso funciona hasta que
-- alguien escribe el DNI con la letra en minúscula, con un punto o
-- con un espacio de más, y entonces el rastro se pierde sin que
-- nadie se entere y el mismo socio se puede crear dos veces.
--
-- Una columna y se acabó. El DNI se sigue mirando, pero solo como
-- red de abajo para las altas de socio anteriores a hoy, que no
-- tienen la columna rellena.
--
-- ------------------------------------------------------------
-- NADA PERSONAL AQUÍ DENTRO
-- Ni un nombre, ni un correo, ni un DNI. Este archivo queda en el
-- histórico para siempre y el repositorio es público.
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta. No borra ni una ficha.
-- ============================================================

begin;

-- ============================================================
-- 1 · LA CASILLA DEL SEXO EN EL ALTA DE ESCUELA
-- ------------------------------------------------------------
-- Los mismos tres valores que `atletas.sexo` y que
-- `altas_socio.sexo`, y por la misma razón de siempre: para que el
-- dato pase del formulario a la ficha sin que nadie lo traduzca por
-- el camino. Una traducción es un sitio donde equivocarse.
-- ============================================================
alter table public.altas_escuela_ninos
  add column if not exists sexo text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'altas_escuela_ninos_sexo_chk') then
    alter table public.altas_escuela_ninos
      add constraint altas_escuela_ninos_sexo_chk
      check (sexo is null or sexo = any (array['hombre', 'mujer', 'otro']));
  end if;
end $$;

comment on column public.altas_escuela_ninos.sexo is
  'Lo pide la licencia federativa, que llama «sexo» a este dato y solo lo lleva '
  'a masculino o femenino. Se guarda con las mismas palabras que la ficha del '
  'atleta para que pase de una a otra sin traducir. Vacío en las altas '
  'anteriores a agosto de 2026, cuando no se preguntaba.';


-- ------------------------------------------------------------
-- La vista del panel tiene que enseñarlo, o la pantalla de altas y
-- la de crear fichas seguirían sin verlo. Se vuelve a crear entera
-- porque una vista no se puede ampliar por un lado.
--
-- El sexo va SIN TAPAR, como la fecha de nacimiento y las alergias:
-- es un dato de la ficha, no un número de documento. Lo que se tapa
-- en esta vista es lo que sirve para suplantar a alguien —el DNI,
-- la cuenta, la tarjeta sanitaria—, y esto no es de esos.
-- ------------------------------------------------------------
drop view if exists public.altas_escuela_ninos_panel;
create view public.altas_escuela_ninos_panel
with (security_invoker = true) as
select
  n.id,
  n.alta_id,
  n.orden,
  n.nombre,
  -- La fecha de nacimiento se ve entera y tiene que ser así: es la
  -- que decide en qué grupo cae el niño, y comprobar eso es la mitad
  -- del trabajo de revisar un alta de escuela.
  n.fecha_nacimiento,
  n.sexo,

  public.tapado(n.sip)      as sip_tapado,
  (n.sip is not null)       as tiene_sip,

  n.turno,
  n.grupo_id,
  n.grupo_nombre,
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
  'Los hijos de un alta de escuela, con la tarjeta sanitaria tapada.';

grant select on public.altas_escuela_ninos_panel to authenticated;
grant all    on public.altas_escuela_ninos_panel to service_role;


-- ============================================================
-- 2 · LA PUERTA DE ENTRADA GUARDA EL SEXO
-- ------------------------------------------------------------
-- Es la función de la 114 con DOS LÍNEAS MÁS: la columna en el
-- `insert` y el valor sacado del paquete. Todo lo demás está igual y
-- se copia tal cual —el cepo para robots, el corte por correo mal
-- escrito, el «esto ya lo hemos recibido hace un momento» y la
-- búsqueda del grupo por año y días, que sigue sin creerse lo que
-- diga el navegador—.
--
-- Se copia entera porque en SQL una función se cambia entera o no se
-- cambia: no hay forma de tocarle un renglón. La de la 114 se queda
-- en su archivo como historia de cómo era.
--
-- El valor NO se mete tal cual: se comprueba contra los tres que la
-- casilla admite y, si viene cualquier otra cosa, se guarda vacío en
-- vez de reventar el alta entera. Una familia no puede perder su
-- inscripción porque alguien manipule ese campo.
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

  if public.texto_de_fuera(p ->> 'tutor_nombre', 120) is null
     or public.texto_de_fuera(p ->> 'tutor_telefono', 30) is null then
    return jsonb_build_object('ok', false, 'motivo', 'familia',
      'mensaje', 'Faltan el nombre y el teléfono de quien apunta.');
  end if;

  if coalesce((p ->> 'acepta_normas')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'motivo', 'normas',
      'mensaje', 'Hay que aceptar las normas del club para poder apuntarse.');
  end if;

  v_primero := lower(public.texto_de_fuera(v_ninos -> 0 ->> 'nombre', 120));

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
    referencia, tutor_nombre, tutor_dni, tutor_email, tutor_telefono,
    direccion, cp, localidad, quien_recoge, como_nos_conocio,
    iban, forma_pago, acepta_normas, texto_normas, ip, navegador
  ) values (
    v_ref,
    public.texto_de_fuera(p ->> 'tutor_nombre', 120),
    public.texto_de_fuera(p ->> 'tutor_dni', 20),
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
    insert into public.altas_escuela_ninos (
      alta_id, orden, nombre, fecha_nacimiento, sexo, sip, turno,
      grupo_id, grupo_nombre, alergias,
      permiso_imagen, permiso_imagen_ambitos, texto_imagen,
      talla_camiseta, talla_sudadera
    ) values (
      v_alta_id, v_i,
      public.texto_de_fuera(v_nino ->> 'nombre', 120),
      (v_nino ->> 'fecha_nacimiento')::date,
      -- Si viene algo que no es ninguno de los tres, se guarda vacío.
      -- Un alta no se pierde por un campo que alguien haya trasteado.
      (case when lower(public.texto_de_fuera(v_nino ->> 'sexo', 10))
                 = any (array['hombre', 'mujer', 'otro'])
            then lower(public.texto_de_fuera(v_nino ->> 'sexo', 10)) end),
      public.texto_de_fuera(v_nino ->> 'sip', 30),
      public.texto_de_fuera(v_nino ->> 'turno', 20),
      -- El grupo NO se cree lo que diga el navegador: se busca en la
      -- base por el año de nacimiento y los días, que es de donde
      -- sale de verdad. Si el navegador mandara otro, se ignora.
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

-- Los permisos se vuelven a poner: `create or replace` no los pierde,
-- pero dejarlo escrito evita que el día que alguien haga un `drop` y
-- vuelva a crearla el formulario deje de funcionar sin que se sepa.
revoke all on function public.enviar_alta_escuela(jsonb) from public;
grant execute on function public.enviar_alta_escuela(jsonb) to anon, authenticated;


-- ============================================================
-- 3 · EL ALTA DE SOCIO DEJA ESCRITO A QUÉ FICHA DIO LUGAR
-- ------------------------------------------------------------
-- `on delete set null` y no `cascade`: si un día se borra la ficha
-- del atleta, el alta NO se borra con ella. El alta es el papel que
-- firmó una persona y hay que poder enseñarlo aunque su ficha ya no
-- esté; lo único que se pierde es el hilo entre las dos.
-- ============================================================
alter table public.altas_socio
  add column if not exists atleta_id uuid references public.atletas(id) on delete set null;

create index if not exists idx_altas_socio_atleta on public.altas_socio (atleta_id);

comment on column public.altas_socio.atleta_id is
  'La ficha de atleta que salió de este alta. Existe para no depender del DNI: '
  'un DNI escrito con la letra en minúscula o con un espacio de más pierde el '
  'rastro sin que nadie se entere, y el mismo socio se crea dos veces. Vacío '
  'en las altas anteriores a agosto de 2026 y en las que aún no se han '
  'convertido.';


-- ------------------------------------------------------------
-- La vista del panel también lo enseña.
-- ------------------------------------------------------------
drop view if exists public.altas_socio_panel;
create view public.altas_socio_panel
with (security_invoker = true) as
select
  s.id,
  s.referencia,
  s.temporada,
  s.nombre,
  s.apellidos,
  public.tapado(s.dni)  as dni_tapado,
  (s.dni is not null)   as tiene_dni,
  s.fecha_nacimiento,
  s.sexo,
  s.direccion,
  s.cp,
  s.localidad,
  s.provincia,
  s.email,
  s.telefono,
  s.secciones,
  s.acepta_normas,
  s.texto_normas,
  s.permiso_imagen,
  s.permiso_imagen_ambitos,
  s.texto_imagen,
  s.texto_condiciones,
  s.estado,
  s.revisada_por,
  (select trim(coalesce(p.nombre, '') || ' ' || coalesce(p.apellidos, ''))
     from public.perfiles p where p.id = s.revisada_por) as revisada_por_nombre,
  s.revisada_en,
  s.nota_club,
  s.perfil_id,
  s.atleta_id,
  s.created_at
from public.altas_socio s;

comment on view public.altas_socio_panel is
  'Las altas de socio como las ve el panel: con el DNI tapado.';

grant select on public.altas_socio_panel to authenticated;
grant all    on public.altas_socio_panel to service_role;


-- ============================================================
-- 4 · EL EXAMEN, AL DÍA
-- ------------------------------------------------------------
-- Cambia en dos sitios y en nada más:
--   · el sexo del niño sale ahora del alta, así que el aviso de
--     «falta el sexo» solo salta cuando de verdad falta;
--   · en socio, «esta persona ya tiene ficha» se sabe por la columna
--     nueva y no por el DNI.
-- Todo lo demás —los duplicados, el año que no cuadra, el turno, el
-- grupo lleno o cerrado— está igual que en la 121.
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
             null::text as dni, n.sexo, null::text[] as secciones
        from public.altas_escuela_ninos n
       where p_que = 'escuela' and n.alta_id = p_id
      union all
      -- Un alta de socio es una sola persona: ella misma. Desde la 122
      -- también tiene su propia casilla de «a qué ficha dio lugar».
      select s.id, 1 as orden,
             btrim(coalesce(s.nombre, '') || ' ' || coalesce(s.apellidos, '')) as nombre_tal_cual,
             s.fecha_nacimiento, null::uuid as grupo_id, null::text as grupo_nombre,
             null::text as turno, null::text as alergias,
             s.atleta_id,
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
-- 5 · CREAR LA FICHA, AL DÍA
-- ------------------------------------------------------------
-- Cambia solo en el socio: se apunta en el alta a qué ficha dio
-- lugar, y saber si «ya tiene ficha» se mira primero en esa columna.
-- El DNI se sigue mirando detrás, y solo por las altas de socio
-- anteriores a hoy, que no la tienen rellena.
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
    select n.alta_id, n.atleta_id into v_alta_id, v_atleta
      from public.altas_escuela_ninos n where n.id = p_persona_id;
    if v_alta_id is null then
      return jsonb_build_object('ok', false, 'motivo', 'no-esta');
    end if;
    select a.estado into v_alta_est from public.altas_escuela a where a.id = v_alta_id;
  else
    select s.id, s.estado, s.atleta_id into v_alta_id, v_alta_est, v_atleta
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
  'Crea la ficha de UNA persona de un alta, o la engancha a la que ya existe. '
  'Una por llamada, a propósito: en un alta vienen hermanos y si uno falla el '
  'otro no se puede perder.';


-- Los permisos de las dos funciones, otra vez por escrito.
revoke all on function public.alta_examen(text, uuid)               from public;
revoke all on function public.alta_crear_ficha(text, uuid, jsonb)   from public;
grant execute on function public.alta_examen(text, uuid)            to authenticated;
grant execute on function public.alta_crear_ficha(text, uuid, jsonb) to authenticated;

commit;

-- Que la API se entere de las columnas y las vistas nuevas sin esperar
-- a que se le ocurra sola.
notify pgrst, 'reload schema';
