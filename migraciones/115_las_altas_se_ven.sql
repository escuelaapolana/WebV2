-- ============================================================
-- 115 · Las altas se ven · la bandeja del panel
-- ------------------------------------------------------------
-- QUÉ FALTABA
-- La 114 montó los formularios: una familia rellena, la base lo
-- guarda y devuelve un código. Hasta ahí, bien. El problema es lo
-- que pasaba después: NADA. Las altas entraban y se quedaban en la
-- base sin que nadie las viera, porque no había ni una pantalla que
-- las enseñara. En septiembre se apuntan unas 400 familias.
--
-- Esta migración no cambia ni una coma de cómo se guardan. Solo
-- monta lo que hace falta para poder MIRARLAS sin peligro:
--
--   1. Cuatro vistas que enseñan el alta con el DNI, el IBAN y la
--      tarjeta sanitaria TAPADOS. Son las que lee el panel.
--   2. Una puerta aparte para ver un número entero cuando de verdad
--      hace falta, que además deja apuntado quién lo miró.
--   3. Un botón de «revisada» que se puede pulsar sin poder mentir
--      sobre quién la revisó.
--
-- ------------------------------------------------------------
-- POR QUÉ TAPADO Y NO A PELO
--
-- Las reglas de la 114 ya dicen quién entra: administración y
-- tesorería, y nadie más. Eso está bien y no se toca. Pero «puede
-- entrar» no es lo mismo que «tiene que verlo todo a la vez».
--
-- Quien revisa un alta en septiembre está comprobando otra cosa:
-- que la familia se llama como dice, que el niño cae en el grupo
-- que le toca, que hay teléfono, que aceptó las normas y que dejó
-- cuenta o no la dejó. Para eso no hace falta el número de cuenta
-- entero. Con «ES ···· 7891» ya se puede cuadrar un recibo devuelto
-- por teléfono, que es para lo que se mira.
--
-- Y hay una razón práctica además de la legal: si la lista de 400
-- altas lleva 400 números de cuenta dentro, ese listado entero está
-- en el navegador de quien lo abra, en el móvil, en la cafetería.
-- Tapándolo en la base, el número NO SALE de aquí hasta que alguien
-- lo pide para una fila concreta y queda dicho que lo pidió.
--
-- El número entero sigue estando y sigue haciendo falta: para pasar
-- la remesa al banco, para rellenar una licencia. Para eso está
-- `alta_numero_entero`, más abajo.
--
-- ------------------------------------------------------------
-- LO QUE ESTA MIGRACIÓN NO HACE
-- No crea columnas de estado: `estado`, `revisada_por`, `revisada_en`
-- y `nota_club` ya vienen de la 114 y sirven tal cual.
-- No convierte ningún alta en atleta. Sigue siendo un paso a mano y
-- a propósito, como dejó dicho la 114.
-- No toca las renovaciones ni monta la pantalla de firmar: hoy no
-- existe todavía el texto legal del mandato, así que no hay ni una
-- firma que enseñar.
-- ============================================================


-- ============================================================
-- 1 · TAPAR UN NÚMERO
-- ------------------------------------------------------------
-- Se dejan ver los cuatro últimos y nada más. Cuatro es lo que se
-- canta por teléfono («…acaba en 7891») y lo que sale en el extracto
-- del banco, así que es justo lo que sirve para reconocer sin servir
-- para usar.
--
-- Si el valor es corto se tapa entero: con un dato de cinco
-- caracteres, enseñar cuatro es enseñarlo todo.
-- ============================================================
create or replace function public.tapado(p_valor text, p_deja int default 4)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select case
           when p_valor is null or btrim(p_valor) = '' then null
           when length(btrim(p_valor)) <= p_deja + 2 then '····'
           else '···· ' || right(btrim(p_valor), p_deja)
         end;
$$;

comment on function public.tapado(text, int) is
  'Deja ver los cuatro últimos caracteres de un dato y tapa el resto.';


-- ------------------------------------------------------------
-- El IBAN se tapa igual, pero dejando el país delante. «ES ···· 7891»
-- dice de un vistazo que es una cuenta española; una cuenta francesa
-- en una domiciliación española es un problema, y así se ve sin
-- destapar nada.
-- ------------------------------------------------------------
create or replace function public.iban_tapado(p_iban text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select case
           when p_iban is null or btrim(p_iban) = '' then null
           when length(btrim(p_iban)) <= 8 then '····'
           else left(btrim(p_iban), 2) || ' ···· ' || right(btrim(p_iban), 4)
         end;
$$;

comment on function public.iban_tapado(text) is
  'El IBAN con el país delante y los cuatro últimos: «ES ···· 7891».';


-- ============================================================
-- 2 · LAS VISTAS QUE LEE EL PANEL
-- ------------------------------------------------------------
-- Van con `security_invoker = true`, que quiere decir: la vista NO
-- tiene permisos propios. Cuando alguien la lee, Postgres aplica las
-- reglas de la 114 con los papeles de esa persona.
--
-- Esto importa mucho y es fácil de hacer mal: una vista normal corre
-- con los papeles de QUIEN LA CREÓ, o sea con los del dueño de la
-- base, y sería una puerta trasera por la que un entrenador leería
-- las 400 altas enteras. Con `security_invoker`, un entrenador que
-- lea la vista recibe cero filas, igual que si leyera la tabla.
--
-- Se ha comprobado poniéndose los papeles de cada uno, no leyendo
-- esta línea y dando por hecho que hace lo que dice.
-- ============================================================

drop view if exists public.altas_escuela_panel;
create view public.altas_escuela_panel
with (security_invoker = true) as
select
  a.id,
  a.referencia,
  a.temporada,

  -- Quien apunta. El nombre, el correo y el teléfono van enteros a
  -- propósito: son exactamente lo que se usa para llamar a la familia
  -- cuando falta algo, que es el trabajo de esta pantalla.
  a.tutor_nombre,
  a.tutor_email,
  a.tutor_telefono,

  public.tapado(a.tutor_dni)      as tutor_dni_tapado,
  (a.tutor_dni is not null)       as tiene_dni,

  a.direccion,
  a.cp,
  a.localidad,
  a.quien_recoge,
  a.como_nos_conocio,

  public.iban_tapado(a.iban)      as iban_tapado,
  -- Que la familia NO haya dejado cuenta es un dato que hay que ver
  -- en la lista: es una llamada pendiente, no un hueco cualquiera.
  (a.iban is not null)            as tiene_iban,
  a.forma_pago,

  a.acepta_normas,
  a.texto_normas,

  a.estado,
  a.revisada_por,
  a.revisada_en,
  -- Quién la revisó, por su nombre. Va como subconsulta y no como
  -- `join` a propósito: si quien mira no puede leer esa ficha, aquí
  -- sale vacío y el alta se sigue viendo. Con un `join` desaparecería
  -- el alta entera, que es la clase de fallo que nadie encuentra.
  (select trim(coalesce(p.nombre, '') || ' ' || coalesce(p.apellidos, ''))
     from public.perfiles p where p.id = a.revisada_por) as revisada_por_nombre,
  a.nota_club,

  a.created_at
from public.altas_escuela a;

comment on view public.altas_escuela_panel is
  'Las altas de escuela como las ve el panel: con el DNI y el IBAN tapados.';


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
  s.created_at
from public.altas_socio s;

comment on view public.altas_socio_panel is
  'Las altas de socio como las ve el panel: con el DNI tapado.';


-- ------------------------------------------------------------
-- Las órdenes de domiciliación firmadas.
--
-- Aquí NO va la firma. Un PNG de una firma ocupa hasta 400 KB, y una
-- lista de doscientas se descargaría entera al abrir la pantalla, por
-- el móvil, para no enseñar ninguna. La firma se pide de una en una
-- cuando alguien abre esa orden concreta, leyendo la tabla directa.
-- ------------------------------------------------------------
drop view if exists public.mandatos_sepa_panel;
create view public.mandatos_sepa_panel
with (security_invoker = true) as
select
  m.id,
  m.referencia,
  m.origen,
  m.alta_escuela_id,
  m.alta_socio_id,
  m.atleta_id,
  m.perfil_id,
  m.titular,
  public.iban_tapado(m.iban) as iban_tapado,
  m.bic,
  m.direccion,
  m.cp,
  m.localidad,
  m.pais,
  m.tipo_pago,
  m.lugar_firma,
  m.firmado_en,
  (m.firma_png is not null)  as tiene_firma,
  -- El texto del mandato sí va entero: no es de nadie, es el del
  -- club, y es justo lo que hay que poder releer para saber qué
  -- firmó esta persona.
  m.texto_mandato,
  m.cif_acreedor,
  m.identificador_acreedor,
  m.estado,
  m.pdf_url,
  m.nota_club,
  m.created_at
from public.mandatos_sepa m;

comment on view public.mandatos_sepa_panel is
  'Las órdenes de domiciliación con el IBAN tapado y sin el dibujo de la firma.';


-- ============================================================
-- 3 · QUIÉN HA MIRADO QUÉ
-- ------------------------------------------------------------
-- Una línea por cada vez que alguien destapa un número. No guarda el
-- número: guarda quién, de qué alta y cuándo.
--
-- Para qué sirve de verdad: para poder contestar «¿quién sacó el
-- número de cuenta de esta familia?» el día que alguien lo pregunte.
-- Sin esto, la respuesta es «cualquiera de los cuatro que entran al
-- panel», que no es una respuesta.
--
-- La lee administración. Ni tesorería se lee a sí misma: un registro
-- que puede mirar y borrar quien está registrado no registra nada.
-- Escribir en ella no puede nadie a mano; solo la función de abajo.
-- ============================================================
create table if not exists public.altas_datos_vistos (
  id          bigserial primary key,
  quien       uuid references public.perfiles(id),
  quien_email text,
  que         text not null,          -- 'escuela-iban', 'socio-dni', …
  fila_id     uuid not null,
  creado_en   timestamptz not null default now()
);

create index if not exists idx_altas_datos_vistos_fila
  on public.altas_datos_vistos (fila_id, creado_en desc);
create index if not exists idx_altas_datos_vistos_cuando
  on public.altas_datos_vistos (creado_en desc);

alter table public.altas_datos_vistos enable row level security;

drop policy if exists "admin lee quien ha mirado" on public.altas_datos_vistos;
create policy "admin lee quien ha mirado" on public.altas_datos_vistos
  for select to authenticated
  using (public.es_admin());


-- ------------------------------------------------------------
-- DESTAPAR UN NÚMERO, DE UNO EN UNO
--
-- Devuelve UN dato de UNA fila. No hay forma de pedir «todos los
-- IBAN»: hay que pedirlos de uno en uno y cada petición deja rastro.
-- Eso es lo que separa «lo miré para cuadrar un recibo» de «me llevé
-- la lista».
--
-- Vuelve a comprobar los papeles aunque las reglas de la 114 ya lo
-- hagan: esta función corre con los papeles del dueño de la base, así
-- que aquí dentro las reglas no protegen nada y hay que preguntarlo a
-- mano. Es el precio de poder escribir en el registro de arriba.
-- ------------------------------------------------------------
create or replace function public.alta_numero_entero(p_que text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_valor  text;
  v_email  text := auth.jwt() ->> 'email';
  v_perfil uuid;
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración y tesorería pueden ver estos datos';
  end if;

  select id into v_perfil from public.perfiles where email = v_email;

  if p_que = 'escuela-iban' then
    select iban      into v_valor from public.altas_escuela       where id = p_id;
  elsif p_que = 'escuela-dni' then
    select tutor_dni into v_valor from public.altas_escuela       where id = p_id;
  elsif p_que = 'escuela-sip' then
    select sip       into v_valor from public.altas_escuela_ninos where id = p_id;
  elsif p_que = 'socio-dni' then
    select dni       into v_valor from public.altas_socio         where id = p_id;
  elsif p_que = 'sepa-iban' then
    select iban      into v_valor from public.mandatos_sepa       where id = p_id;
  else
    raise exception 'No sé qué dato es «%»', p_que;
  end if;

  if v_valor is null then
    return jsonb_build_object('ok', false, 'motivo', 'vacio');
  end if;

  insert into public.altas_datos_vistos (quien, quien_email, que, fila_id)
  values (v_perfil, v_email, p_que, p_id);

  return jsonb_build_object('ok', true, 'valor', v_valor);
end;
$$;


-- ============================================================
-- 4 · MARCAR UN ALTA COMO REVISADA
-- ------------------------------------------------------------
-- Para qué existe, en una frase: para que dos personas no revisen la
-- misma alta. En la semana en la que entran cien, eso pasa el primer
-- día.
--
-- Podría hacerse con un `update` normal desde la pantalla, porque las
-- reglas de la 114 ya lo permiten. Se hace aquí por una razón: quién
-- la revisó lo pone la base a partir de quien ha entrado, no lo manda
-- el navegador. Si lo mandara el navegador, «revisada por Isa» sería
-- un dato que se puede escribir a mano, y entonces no vale para nada.
--
-- Estados: 'pendiente', 'revisada' y 'rechazada'. Volver a pendiente
-- tiene que poder hacerse —se marca sin querer todos los días— y
-- entonces se borra quién y cuándo, para que no quede una revisión
-- que no ha pasado.
-- ============================================================
create or replace function public.alta_marcar(p_que text, p_id uuid,
                                              p_estado text, p_nota text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_perfil uuid;
  v_quien  uuid;
  v_cuando timestamptz;
  v_filas  int;
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración y tesorería pueden trabajar las altas';
  end if;

  if p_estado not in ('pendiente', 'revisada', 'rechazada') then
    raise exception 'Ese estado no existe: «%»', p_estado;
  end if;

  select id into v_perfil from public.perfiles where email = (auth.jwt() ->> 'email');

  if p_estado = 'pendiente' then
    v_quien := null; v_cuando := null;
  else
    v_quien := v_perfil; v_cuando := now();
  end if;

  if p_que = 'escuela' then
    update public.altas_escuela
       set estado = p_estado, revisada_por = v_quien, revisada_en = v_cuando,
           nota_club = coalesce(public.texto_de_fuera(p_nota, 1000), nota_club)
     where id = p_id;
  elsif p_que = 'socio' then
    update public.altas_socio
       set estado = p_estado, revisada_por = v_quien, revisada_en = v_cuando,
           nota_club = coalesce(public.texto_de_fuera(p_nota, 1000), nota_club)
     where id = p_id;
  else
    raise exception 'No sé qué alta es «%»', p_que;
  end if;

  get diagnostics v_filas = row_count;
  if v_filas = 0 then
    return jsonb_build_object('ok', false, 'motivo', 'no-esta');
  end if;

  return jsonb_build_object('ok', true, 'estado', p_estado,
                            'revisada_en', v_cuando, 'revisada_por', v_quien);
end;
$$;


-- ------------------------------------------------------------
-- GUARDAR SOLO LA NOTA, sin tocar el estado.
-- Se separa a propósito: apuntar «llamada el martes, falta el IBAN»
-- no es lo mismo que dar el alta por revisada, y si fuera el mismo
-- botón acabaría dándose por revisada media escuela sin querer.
-- ------------------------------------------------------------
create or replace function public.alta_nota(p_que text, p_id uuid, p_nota text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_filas int;
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración y tesorería pueden trabajar las altas';
  end if;

  if p_que = 'escuela' then
    update public.altas_escuela
       set nota_club = public.texto_de_fuera(p_nota, 1000) where id = p_id;
  elsif p_que = 'socio' then
    update public.altas_socio
       set nota_club = public.texto_de_fuera(p_nota, 1000) where id = p_id;
  else
    raise exception 'No sé qué alta es «%»', p_que;
  end if;

  get diagnostics v_filas = row_count;
  return jsonb_build_object('ok', v_filas > 0);
end;
$$;


-- ============================================================
-- 5 · QUIÉN PUEDE LLAMAR A CADA PUERTA
-- ------------------------------------------------------------
-- Igual que en la 114: primero se le quita a todo el mundo y luego se
-- le da a quien toca. Si se hace al revés, el `revoke` de después no
-- sirve de nada.
--
-- A `anon` —quien no ha entrado— no se le da NADA. Ni las vistas, ni
-- las funciones. Aquí no hay ninguna excepción como la del texto del
-- mandato: no hay un solo dato de estas pantallas que tenga que poder
-- leer alguien sin cuenta.
-- ============================================================
grant select on public.altas_escuela_panel       to authenticated;
grant select on public.altas_escuela_ninos_panel to authenticated;
grant select on public.altas_socio_panel         to authenticated;
grant select on public.mandatos_sepa_panel       to authenticated;
grant select on public.altas_datos_vistos        to authenticated;

grant all on public.altas_escuela_panel, public.altas_escuela_ninos_panel,
             public.altas_socio_panel, public.mandatos_sepa_panel,
             public.altas_datos_vistos
  to service_role;
grant usage, select on sequence public.altas_datos_vistos_id_seq to service_role;

revoke all on function public.alta_numero_entero(text, uuid)         from public;
revoke all on function public.alta_marcar(text, uuid, text, text)    from public;
revoke all on function public.alta_nota(text, uuid, text)            from public;
revoke all on function public.tapado(text, int)                      from public;
revoke all on function public.iban_tapado(text)                      from public;

grant execute on function public.alta_numero_entero(text, uuid)      to authenticated;
grant execute on function public.alta_marcar(text, uuid, text, text) to authenticated;
grant execute on function public.alta_nota(text, uuid, text)         to authenticated;
-- `tapado` e `iban_tapado` SÍ hay que dárselas a `authenticated`, y
-- conviene saber por qué: como las vistas de arriba corren con los
-- papeles de quien mira, las funciones que usan por dentro también se
-- comprueban contra esa persona. Sin este permiso las vistas darían
-- «permiso denegado» a todo el mundo, incluida administración.
-- No abre nada: son dos funciones que cogen un texto y devuelven otro
-- con puntos. No leen ni una tabla, así que llamarlas a pelo desde
-- fuera no enseña ningún dato de nadie.
grant execute on function public.tapado(text, int)      to authenticated;
grant execute on function public.iban_tapado(text)      to authenticated;


-- Que la API se entere de que hay vistas y funciones nuevas sin
-- esperar a que se le ocurra sola.
notify pgrst, 'reload schema';
