-- =====================================================================
-- 060_buzon.sql  ·  LO QUE LE FALTABA AL BUZÓN
-- =====================================================================
-- El buzón ya está montado como bandeja (maqueta 32c). Se quedaron tres
-- cosas sin poder hacer porque no existían en la base de datos:
--
--   1) «Pasar a la junta».  No había ni campo ni destinatario. Ahora un
--      mensaje se puede derivar a la junta o a la persona que toque,
--      queda constancia de quién lo derivó y cuándo, y quien lo recibe
--      lo ve en su bandeja.
--   2) «Quién contestó».  La tabla no guardaba el autor de la respuesta,
--      así que la fila colapsada no podía enseñarlo. Ahora se sella solo
--      al marcar el mensaje como respondido: no se puede falsear.
--   3) «La plantilla que toca según el asunto».  Las plantillas ya
--      existían (033) pero no sabían a qué mensaje corresponden. Se les
--      añade una lista de palabras del asunto, editable desde el panel,
--      y se precargan las cinco de los casos reales del club.
--
-- LO QUE NO SE TOCA
--   · El texto que escribe la gente. A partir de aquí es inmutable:
--     nombre, medio, asunto, mensaje y fecha no se pueden editar desde
--     ninguna pantalla. Un mensaje recibido es un registro, no un
--     borrador.
--   · El formulario público de /contacto/ sigue igual: manda cuatro
--     campos y nada más.
--
-- PRIVACIDAD
--   Los mensajes del buzón son privados. Los lee administración y, si se
--   le ha derivado uno, la persona a la que se le derivó: ese mensaje y
--   ninguno más. Un atleta, una familia o un visitante no leen ninguno,
--   ni el suyo. Y como Supabase concede permisos a `anon` y
--   `authenticated` por su cuenta en todo lo nuevo del esquema público,
--   aquí se revocan a mano y se vuelven a dar uno a uno.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/060_buzon.sql
-- Se puede volver a lanzar las veces que haga falta: no rompe nada.
-- =====================================================================

begin;


-- =====================================================================
-- 1 · A QUIÉN SE LE PASA UN MENSAJE
-- ---------------------------------------------------------------------
-- «Pasar a la junta» no puede ser una palabra escrita en el código: el
-- club cambia de junta, y quien lleva los recibos hoy puede no llevarlos
-- el año que viene. Los destinos son una tabla corta que se edita desde
-- el panel: cómo se llama el destino y a qué cuenta le llega.
--
-- Un destino puede existir sin cuenta asignada (`perfil_id` vacío): es
-- el caso de quien todavía no tiene acceso al panel. Entonces el mensaje
-- queda marcado como derivado —con su constancia— y lo sigue viendo
-- administración, que es quien se lo hace llegar.
-- =====================================================================

create table if not exists public.buzon_destinos (
  id          uuid primary key default gen_random_uuid(),
  -- Etiqueta estable para el código y los enlaces ('junta', 'cuotas'…).
  clave       text not null check (clave ~ '^[a-z0-9_]{2,24}$'),
  -- Cómo se lee en el panel («La junta directiva»).
  nombre      text not null check (length(btrim(nombre)) between 2 and 60),
  -- Una línea que diga qué se le pasa a este destino y qué no.
  descripcion text,
  -- La cuenta que lo recibe en su bandeja. Puede estar vacía.
  perfil_id   uuid references public.perfiles(id) on delete set null,
  activo      boolean not null default true,
  orden       integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create unique index if not exists buzon_destinos_clave_unica
  on public.buzon_destinos (lower(clave));
create index if not exists buzon_destinos_orden_idx
  on public.buzon_destinos (orden) where activo;

comment on table public.buzon_destinos is
  'A quién se le puede pasar un mensaje del buzón. Se edita desde /admin/buzon/: el club cambia de junta y de personas, y esto tiene que poder cambiar sin tocar el código.';
comment on column public.buzon_destinos.perfil_id is
  'Cuenta que recibe el mensaje en su bandeja. Vacío = el destino existe pero todavía no tiene cuenta en el panel: el mensaje queda derivado y sigue en la bandeja de administración.';

drop trigger if exists buzon_destinos_updated on public.buzon_destinos;
create trigger buzon_destinos_updated
  before update on public.buzon_destinos
  for each row execute function public.handle_updated_at();


-- --- Los destinos de verdad del club ---------------------------------
-- Solo se meten la primera vez: si el club ya los ha retocado, se
-- respeta lo que haya puesto.
--
-- La junta se apunta a la cuenta de administración del club, que es la
-- del presidente, Adrián Onandía. Los recibos y las cuotas los lleva
-- Isabel, la contable, que hoy NO tiene cuenta en el panel: su destino
-- nace sin cuenta a propósito, para que se rellene desde el panel el día
-- que la tenga. No se inventa aquí ningún correo suyo.

insert into public.buzon_destinos (clave, nombre, descripcion, perfil_id, orden)
select 'junta', 'La junta directiva',
       'Lo que decide el club: convenios, alquiler de instalaciones, patrocinios, permisos y quejas formales.',
       (select p.id from public.perfiles p
         where lower(p.email) = 'escuelaapolana@gmail.com' and p.rol = 'admin' limit 1),
       1
 where not exists (select 1 from public.buzon_destinos where lower(clave) = 'junta');

insert into public.buzon_destinos (clave, nombre, descripcion, perfil_id, orden)
select 'cuotas', 'Cuotas y recibos · Isabel',
       'Todo lo de dinero: recibos devueltos, cambios de cuenta, importes y devoluciones. Falta asignarle la cuenta del panel cuando la tenga.',
       null, 2
 where not exists (select 1 from public.buzon_destinos where lower(clave) = 'cuotas');

insert into public.buzon_destinos (clave, nombre, descripcion, perfil_id, orden)
select 'escuela', 'Coordinación de la escuela',
       'Grupos, horarios, categorías y pruebas de los peques.',
       null, 3
 where not exists (select 1 from public.buzon_destinos where lower(clave) = 'escuela');


-- =====================================================================
-- 2 · LOS CAMPOS QUE FALTABAN EN `mensajes`
-- =====================================================================

-- --- Quién contestó (y cuándo) ---------------------------------------
alter table public.mensajes add column if not exists respondido_por uuid;
alter table public.mensajes add column if not exists respondido_at  timestamptz;

-- --- A quién se le pasó, quién lo pasó y cuándo -----------------------
alter table public.mensajes add column if not exists derivado_destino uuid;
alter table public.mensajes add column if not exists derivado_a       uuid;
alter table public.mensajes add column if not exists derivado_por     uuid;
alter table public.mensajes add column if not exists derivado_at      timestamptz;
alter table public.mensajes add column if not exists derivado_nota    text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'mensajes_respondido_por_fkey') then
    alter table public.mensajes add constraint mensajes_respondido_por_fkey
      foreign key (respondido_por) references public.perfiles(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'mensajes_derivado_destino_fkey') then
    alter table public.mensajes add constraint mensajes_derivado_destino_fkey
      foreign key (derivado_destino) references public.buzon_destinos(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'mensajes_derivado_a_fkey') then
    alter table public.mensajes add constraint mensajes_derivado_a_fkey
      foreign key (derivado_a) references public.perfiles(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'mensajes_derivado_por_fkey') then
    alter table public.mensajes add constraint mensajes_derivado_por_fkey
      foreign key (derivado_por) references public.perfiles(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'mensajes_derivado_nota_check') then
    alter table public.mensajes add constraint mensajes_derivado_nota_check
      check (derivado_nota is null or length(derivado_nota) <= 500);
  end if;
end $$;

create index if not exists mensajes_sin_responder_idx
  on public.mensajes (created_at) where coalesce(atendido, false) = false;
create index if not exists mensajes_derivado_a_idx
  on public.mensajes (derivado_a) where derivado_a is not null;

comment on column public.mensajes.respondido_por   is 'Quién marcó el mensaje como respondido. Lo pone la base sola: no se puede escribir a mano.';
comment on column public.mensajes.respondido_at    is 'Cuándo se marcó como respondido.';
comment on column public.mensajes.derivado_destino is 'Destino al que se le pasó el mensaje (buzon_destinos).';
comment on column public.mensajes.derivado_a       is 'Cuenta que lo recibe en su bandeja. Es la del destino en el momento de derivar, o una persona suelta del equipo.';
comment on column public.mensajes.derivado_por     is 'Quién lo derivó. Lo pone la base sola.';
comment on column public.mensajes.derivado_nota    is 'Por qué se deriva, en una línea. Lo lee quien lo recibe.';


-- =====================================================================
-- 3 · LA CONSTANCIA LA PONE LA BASE, NO LA PANTALLA
-- ---------------------------------------------------------------------
-- Si «quién contestó» lo escribiera la pantalla, bastaría con abrir la
-- consola del navegador para firmar con el nombre de otro. Lo sella un
-- disparador con `mi_perfil_id()`, que sale del identificador de la
-- sesión y no de lo que mande el navegador.
--
-- El mismo disparador deja el texto recibido en piedra: lo que escribió
-- una familia no se edita desde el panel.
-- =====================================================================

create or replace function public.buzon_sella()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_yo uuid;
begin
  v_yo := public.mi_perfil_id();

  if tg_op = 'INSERT' then
    -- Lo que entra por el formulario público entra limpio: ni derivado,
    -- ni respondido, ni atendido. Aunque alguien lo intente a mano.
    new.atendido         := coalesce(new.atendido, false);
    new.respondido_por   := null;
    new.respondido_at    := null;
    new.derivado_destino := null;
    new.derivado_a       := null;
    new.derivado_por     := null;
    new.derivado_at      := null;
    new.derivado_nota    := null;
    return new;
  end if;

  -- El mensaje recibido no se edita nunca.
  new.id         := old.id;
  new.nombre     := old.nombre;
  new.medio      := old.medio;
  new.asunto     := old.asunto;
  new.mensaje    := old.mensaje;
  new.created_at := old.created_at;

  -- Quién contestó: se sella al pasar a respondido y se borra al deshacer.
  if coalesce(new.atendido, false) and not coalesce(old.atendido, false) then
    new.respondido_por := coalesce(old.respondido_por, v_yo);
    new.respondido_at  := coalesce(old.respondido_at, now());
  elsif not coalesce(new.atendido, false) then
    new.respondido_por := null;
    new.respondido_at  := null;
  else
    -- Ya estaba respondido: la firma no se cambia.
    new.respondido_por := old.respondido_por;
    new.respondido_at  := old.respondido_at;
  end if;

  -- Quién lo pasó: se sella al derivar y se borra al retirar la derivación.
  if new.derivado_destino is distinct from old.derivado_destino
     or new.derivado_a is distinct from old.derivado_a then
    if new.derivado_destino is null and new.derivado_a is null then
      new.derivado_por  := null;
      new.derivado_at   := null;
      new.derivado_nota := null;
    else
      -- Si se elige un destino y no se dice a quién, va a la cuenta del destino.
      if new.derivado_a is null and new.derivado_destino is not null then
        new.derivado_a := (select d.perfil_id from public.buzon_destinos d
                            where d.id = new.derivado_destino);
      end if;
      new.derivado_por := v_yo;
      new.derivado_at  := now();
    end if;
  else
    new.derivado_por := old.derivado_por;
    new.derivado_at  := coalesce(old.derivado_at, new.derivado_at);
  end if;

  return new;
end;
$$;

drop trigger if exists buzon_sella_insert on public.mensajes;
create trigger buzon_sella_insert
  before insert on public.mensajes
  for each row execute function public.buzon_sella();

drop trigger if exists buzon_sella_update on public.mensajes;
create trigger buzon_sella_update
  before update on public.mensajes
  for each row execute function public.buzon_sella();


-- =====================================================================
-- 4 · QUIÉN ENTRA Y QUIÉN NO
-- =====================================================================

alter table public.mensajes        enable row level security;
alter table public.buzon_destinos  enable row level security;

-- --- mensajes ---------------------------------------------------------
-- Administración, todo. (Ya existía; se vuelve a declarar por si acaso.)
drop policy if exists "admin gestiona mensajes" on public.mensajes;
create policy "admin gestiona mensajes" on public.mensajes
  for all to authenticated
  using (es_admin()) with check (es_admin());

-- Cualquiera puede escribir al club desde /contacto/ —también sin cuenta—,
-- pero solo eso: un mensaje nuevo, sin marcar y sin derivar.
drop policy if exists "enviar mensaje" on public.mensajes;
create policy "enviar mensaje" on public.mensajes
  for insert to anon, authenticated
  with check (
    coalesce(atendido, false) = false
    and respondido_por is null
    and derivado_a is null
    and derivado_destino is null
  );

-- A quien le han pasado un mensaje, ese mensaje y ninguno más.
drop policy if exists "buzon lee quien lo tiene derivado" on public.mensajes;
create policy "buzon lee quien lo tiene derivado" on public.mensajes
  for select to authenticated
  using (derivado_a is not null and derivado_a = mi_perfil_id());

-- Y lo puede marcar como respondido. El disparador ya impide que cambie
-- el texto, y esta regla impide que se lo quite de encima pasándoselo a
-- otro: para eso está administración.
drop policy if exists "buzon atiende quien lo tiene derivado" on public.mensajes;
create policy "buzon atiende quien lo tiene derivado" on public.mensajes
  for update to authenticated
  using  (derivado_a is not null and derivado_a = mi_perfil_id())
  with check (derivado_a is not null and derivado_a = mi_perfil_id());

-- Ojo: sobre `mensajes` hay además una política antigua llamada «admin
-- gestiona todo» que también exige es_admin(). Suma, no resta: las
-- políticas de PostgreSQL se combinan con O, y ninguna de las dos abre
-- nada a quien no sea administración.

-- --- buzon_destinos ---------------------------------------------------
-- El equipo puede leer los nombres de los destinos (los necesita para
-- saber a quién le llegó el mensaje); cambiarlos, solo administración.
drop policy if exists "equipo lee los destinos" on public.buzon_destinos;
create policy "equipo lee los destinos" on public.buzon_destinos
  for select to authenticated using (es_staff());

drop policy if exists "admin gestiona los destinos" on public.buzon_destinos;
create policy "admin gestiona los destinos" on public.buzon_destinos
  for all to authenticated
  using (es_admin()) with check (es_admin());


-- --- La otra mitad del candado: los permisos de tabla ------------------
-- Supabase le da permisos a `anon` y a `authenticated` por su cuenta en
-- todo lo que se crea en el esquema público. Aquí se quitan y se vuelven
-- a dar uno a uno. Sin esto, las políticas de arriba no bastan.
-- Se revoca también a `authenticated`: el permiso de tabla que traía de
-- antes incluía TRUNCATE, y TRUNCATE se salta la RLS. Con eso, cualquiera
-- con cuenta —un atleta— podía vaciar el buzón entero sin que ninguna
-- política se lo impidiera.
revoke all on public.mensajes       from anon, public, authenticated;
revoke all on public.buzon_destinos from anon, public, authenticated;

-- El formulario de contacto necesita escribir, y nada más: ni leer, ni
-- cambiar, ni borrar.
grant insert on public.mensajes to anon;
grant select, insert, update, delete on public.mensajes to authenticated;
grant select, insert, update, delete on public.buzon_destinos to authenticated;


-- =====================================================================
-- 5 · LA BANDEJA, CON LOS NOMBRES YA PUESTOS
-- ---------------------------------------------------------------------
-- La fila colapsada tiene que decir «Respondido por Isabel», no un
-- identificador. Los nombres del equipo están en `perfiles`, que no es
-- una tabla que se pueda leer entera desde una pantalla, así que la
-- unión se hace aquí, en una vista cerrada: solo trae los mensajes que
-- esa persona ya podía ver.
-- =====================================================================

drop view if exists public.buzon_bandeja;
create view public.buzon_bandeja as
  select m.id,
         m.nombre,
         m.medio,
         m.asunto,
         m.mensaje,
         m.atendido,
         m.created_at,
         m.respondido_por,
         m.respondido_at,
         nullif(btrim(coalesce(pr.nombre, '') || ' ' || coalesce(pr.apellidos, '')), '') as respondido_por_nombre,
         pr.nombre as respondido_por_pila,
         m.derivado_destino,
         d.clave  as derivado_clave,
         d.nombre as derivado_destino_nombre,
         m.derivado_a,
         nullif(btrim(coalesce(pa.nombre, '') || ' ' || coalesce(pa.apellidos, '')), '') as derivado_a_nombre,
         m.derivado_por,
         nullif(btrim(coalesce(pp.nombre, '') || ' ' || coalesce(pp.apellidos, '')), '') as derivado_por_nombre,
         m.derivado_at,
         m.derivado_nota
    from public.mensajes m
    left join public.perfiles pr on pr.id = m.respondido_por
    left join public.perfiles pp on pp.id = m.derivado_por
    left join public.perfiles pa on pa.id = m.derivado_a
    left join public.buzon_destinos d on d.id = m.derivado_destino
   where public.es_admin()
      or (m.derivado_a is not null and m.derivado_a = public.mi_perfil_id());

comment on view public.buzon_bandeja is
  'El buzón con los nombres ya resueltos. Vista curada: enseña lo mismo que la tabla, ni una fila más. Escribir se escribe siempre sobre `mensajes`.';

-- Vista curada: la filtra su propio WHERE, no la RLS de quien pregunta.
alter view public.buzon_bandeja set (security_invoker = false);
revoke all on public.buzon_bandeja from anon, public, authenticated;
grant select on public.buzon_bandeja to authenticated;


-- =====================================================================
-- 6 · LA PLANTILLA QUE TOCA SEGÚN EL ASUNTO
-- ---------------------------------------------------------------------
-- Las plantillas ya existían (033) pero no sabían a qué mensaje
-- corresponden. `buzon_palabras` es la lista de palabras que, si salen
-- en el asunto o en el mensaje, hacen que el panel ofrezca esa plantilla
-- en la fila de acciones. Se edita en /admin/plantillas/, como el resto:
-- no hay ni una palabra clave escrita en el código de la pantalla.
-- =====================================================================

alter table public.plantillas_email
  add column if not exists buzon_palabras text[] not null default '{}';

comment on column public.plantillas_email.buzon_palabras is
  'Palabras del asunto o del mensaje que hacen que el buzón ofrezca esta plantilla. Sin acentos y en minúscula: la pantalla compara así. Vacío = no se ofrece en el buzón.';

create index if not exists plantillas_email_buzon_palabras_idx
  on public.plantillas_email using gin (buzon_palabras);

-- El equipo técnico puede LEER las plantillas activas (las necesita el
-- que recibe un mensaje derivado). Crear y cambiar sigue siendo solo de
-- administración, como decía 033. Una familia no entra por ningún lado.
drop policy if exists "equipo lee plantillas activas" on public.plantillas_email;
create policy "equipo lee plantillas activas" on public.plantillas_email
  for select to authenticated
  using (es_staff() and activa);

revoke all on public.plantillas_email from anon, public, authenticated;
grant select, insert, update, delete on public.plantillas_email to authenticated;


-- --- Las cinco de los casos reales ------------------------------------
-- Tono del club: cercano y directo, sin fórmulas de oficina. Y sin
-- inventar nada: donde hace falta un dato que no tenemos —un importe, un
-- día, un teléfono— va un marcador entre llaves, que se ve a simple
-- vista y hay que rellenar antes de enviar.
--
-- La firma repite el correo y el teléfono del club a propósito: quien
-- copia y pega se lleva el mensaje entero.
--
-- Solo se meten si no están ya: los textos que el club haya retocado no
-- se pisan.

insert into public.plantillas_email (nombre, asunto, cuerpo, categoria, variables, buzon_palabras)
select * from (values

(
  'Buzón · recibo devuelto',
  'El recibo de {{nombre}}',
  E'Hola:\n\n' ||
  E'Te escribimos porque el banco nos ha devuelto el recibo de {{nombre}} de {{importe}}, el de {{mes}}.\n\n' ||
  E'Antes de nada, tranquilidad: no hay ninguna penalización ni nada apuntado. Casi siempre es un despiste con el saldo o una cuenta que ha cambiado, y se arregla en dos minutos.\n\n' ||
  E'Lo lleva Isabel, que es quien se ocupa de los recibos en el club. Puedes contestar a este correo y te ponemos con ella, o pasarte por secretaría en horario de entrenamiento y lo dejáis resuelto allí mismo.\n\n' ||
  E'Si en algún momento hay un problema de verdad, cuéntanoslo con confianza: aquí no se queda nadie sin entrenar por dinero.\n\n' ||
  E'Un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'buzon',
  array['nombre','importe','mes'],
  array['recibo','devuelto','devolucion','impago','banco','domiciliacion','cargo']
),

(
  'Buzón · duda sobre cuotas',
  'Sobre la cuota de {{nombre}}',
  E'Hola:\n\n' ||
  E'Gracias por escribir. Te contamos cómo va lo de las cuotas.\n\n' ||
  E'La de {{nombre}} es de {{importe}} y se pasa por domiciliación {{cuando_se_pasa}}. No hay matrícula ni permanencia: si algún mes hay que parar, se dice y ya está.\n\n' ||
  E'Quien lleva los recibos y las cuentas es Isabel. Si lo que necesitas es cambiar la cuenta, fraccionar el pago o revisar un cobro concreto, contesta a este correo y te ponemos con ella directamente, que lo resuelve antes que nosotros.\n\n' ||
  E'Cualquier otra duda, por aquí estamos.\n\n' ||
  E'Un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'buzon',
  array['nombre','importe','cuando_se_pasa'],
  array['cuota','cuotas','precio','precios','pago','pagos','tarifa','tarifas','cuanto cuesta','mensualidad']
),

(
  'Buzón · baja del club',
  'La baja de {{nombre}}',
  E'Hola:\n\n' ||
  E'Recibido. Damos de baja a {{nombre}} a partir de {{fecha_baja}}, así que no se le pasará ningún recibo más.\n\n' ||
  E'Sentimos que lo dejéis. Si es por algo que podamos arreglar —el horario, el grupo, cómo se está encontrando— dínoslo y lo miramos, que muchas veces tiene solución. Y si es simplemente que toca parar, ningún problema.\n\n' ||
  E'Si queda algo pendiente por devolver, como ropa del club o el dorsal de alguna prueba, avísanos y lo cuadramos.\n\n' ||
  E'La puerta queda abierta para cuando quiera volver.\n\n' ||
  E'Un abrazo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'buzon',
  array['nombre','fecha_baja'],
  array['baja','dar de baja','darme de baja','anular','cancelar','dejarlo','dejar el club']
),

(
  'Buzón · información de grupos y horarios',
  'Los grupos del club',
  E'Hola:\n\n' ||
  E'Gracias por interesarte. Te cuento lo que encaja con lo que nos pides.\n\n' ||
  E'El grupo que te iría bien es {{grupo}}, que entrena {{horario}} en {{lugar}}. Lo lleva {{entrenador}}.\n\n' ||
  E'Lo mejor es venir a probar antes de decidir nada: se puede entrenar unos días sin compromiso y sin pagar. Solo hace falta ropa cómoda, zapatillas y agua.\n\n' ||
  E'Dinos qué día te viene bien pasarte y avisamos al entrenador para que te esté esperando.\n\n' ||
  E'Un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'buzon',
  array['grupo','horario','lugar','entrenador'],
  array['grupo','grupos','horario','horarios','apuntar','apuntarme','empezar','probar','prueba','escuela','entrenar','informacion','running','correr']
),

(
  'Buzón · incidencia',
  'Sobre lo que nos cuentas',
  E'Hola:\n\n' ||
  E'Gracias por decírnoslo, y perdona por lo que ha pasado.\n\n' ||
  E'Lo estamos mirando: {{que_se_ha_hecho}}. Te contamos en qué queda antes de {{cuando_contestamos}}.\n\n' ||
  E'Si mientras tanto se te ocurre algún detalle más, o prefieres que hablemos por teléfono, dínoslo y te llamamos nosotros.\n\n' ||
  E'Un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'buzon',
  array['que_se_ha_hecho','cuando_contestamos'],
  array['queja','incidencia','problema','reclamacion','protesta','mal','lesion','accidente','robo','material']
)

) as nuevas(nombre, asunto, cuerpo, categoria, variables, buzon_palabras)
 where not exists (
   select 1 from public.plantillas_email p where lower(p.nombre) = lower(nuevas.nombre)
 );


-- --- Y a las que ya existían, sus palabras -----------------------------
-- «Aviso de impago» y «Recordatorio de cuota» ya servían para el buzón:
-- solo les faltaba decirlo. Se rellenan únicamente si están vacías.
update public.plantillas_email
   set buzon_palabras = array['impago','pendiente','atrasado','sin pagar']
 where lower(nombre) = 'aviso de impago' and buzon_palabras = '{}';

update public.plantillas_email
   set buzon_palabras = array['recordatorio','cuando se cobra','domiciliacion']
 where lower(nombre) = 'recordatorio de cuota' and buzon_palabras = '{}';

commit;


-- =====================================================================
-- COMPROBACIÓN · lo que hay que ver después de pasarla
-- =====================================================================

-- 1 · Los permisos de verdad (no las políticas): `anon` solo escribe.
select table_name, grantee, string_agg(privilege_type, ', ' order by privilege_type) as permisos
  from information_schema.role_table_grants
 where table_name in ('mensajes', 'buzon_destinos', 'buzon_bandeja', 'plantillas_email')
   and grantee in ('anon', 'authenticated', 'public')
 group by table_name, grantee
 order by table_name, grantee;

-- 2 · Los destinos, y cuál está sin cuenta todavía.
select clave, nombre, coalesce(perfil_id::text, '— sin cuenta en el panel —') as recibe, activo, orden
  from public.buzon_destinos order by orden;

-- 3 · Las plantillas que el buzón sabrá ofrecer.
select nombre, categoria, buzon_palabras
  from public.plantillas_email
 where buzon_palabras <> '{}'
 order by categoria, nombre;
