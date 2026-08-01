-- ============================================================
-- 033 · PLANTILLAS DE EMAIL · los textos que el club manda siempre
-- ------------------------------------------------------------
-- QUÉ RESUELVE (maqueta 20a «Plantillas de email y notificación»):
--   Hoy cada correo del club se escribe de cero en Gmail: la
--   bienvenida, el recordatorio de la cuota, el aviso de impago…
--   Cambia quien lo escribe y cambia el tono, se olvidan datos y
--   nadie sabe cuál es "el texto bueno". Con esta tabla el texto se
--   escribe UNA vez, vive en el panel y desde ahí se copia y se pega
--   en el correo.
--
-- IMPORTANTE · ESTO NO ENVÍA CORREOS:
--   La web es estática y no tiene servidor de correo. Aquí solo se
--   GUARDA el texto. En /admin/plantillas/ se elige la plantilla y
--   la persona, se rellenan los marcadores con sus datos reales y se
--   copia al portapapeles (o se abre el correo con "mailto:"). El
--   envío lo hace siempre una persona desde su cuenta de correo.
--   Por eso NO hay aquí columnas de "canal", "enviado" ni "automática":
--   prometerían algo que la web no puede cumplir.
--
-- LOS MARCADORES:
--   En el asunto y en el cuerpo se escriben entre llaves dobles:
--   {{nombre}}, {{importe}}, {{fecha}}, {{grupo}}… Al copiar, el
--   panel los cambia por los datos de verdad de la persona elegida.
--   La columna "variables" lista los que usa cada plantilla, para
--   poder enseñarlos como botones al editar.
--
-- QUIÉN ENTRA:
--   Solo administración (es_admin()). Estos textos hablan de dinero,
--   impagos y bajas: no son públicos ni los ve una familia.
-- ============================================================

create table if not exists public.plantillas_email (
  id         uuid primary key default gen_random_uuid(),
  -- Cómo se llama en la lista del panel ("Recordatorio de cuota").
  nombre     text not null,
  -- Asunto del correo, con marcadores si hacen falta.
  asunto     text not null,
  -- Cuerpo del correo, con marcadores. Texto plano con saltos de línea.
  cuerpo     text not null,
  -- Para agrupar la lista: cuotas, altas, competiciones, avisos, tienda.
  categoria  text,
  -- Qué marcadores usa esta plantilla, p. ej. {'nombre','importe'}.
  variables  text[] not null default '{}',
  -- Desactivada = sigue guardada pero no se ofrece para copiar.
  activa     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Dos plantillas no pueden llamarse igual: si no, en la lista no se
-- sabe cuál es cuál.
create unique index if not exists plantillas_email_nombre_unico
  on public.plantillas_email (lower(nombre));

create index if not exists plantillas_email_categoria_idx
  on public.plantillas_email (categoria);

comment on table public.plantillas_email is
  'Textos reutilizables para escribir a socios y familias. No envía correos: se copian y se pegan.';

-- updated_at al día (la función ya existe en la base).
drop trigger if exists plantillas_email_updated on public.plantillas_email;
create trigger plantillas_email_updated
  before update on public.plantillas_email
  for each row execute function public.handle_updated_at();

-- ------------------------------------------------------------
-- Candado: solo administración
-- ------------------------------------------------------------
alter table public.plantillas_email enable row level security;

drop policy if exists "admin gestiona plantillas email" on public.plantillas_email;
create policy "admin gestiona plantillas email"
  on public.plantillas_email
  for all
  to authenticated
  using (es_admin())
  with check (es_admin());

-- ------------------------------------------------------------
-- Precarga · textos reales del club
-- ------------------------------------------------------------
-- Firma común de todos los correos (datos reales del club):
--   Club Atletismo Apol-Ana
--   administracion@atletismoapolana.com · 625 47 38 30
-- Se repite dentro de cada cuerpo a propósito: así el que copia y
-- pega se lleva el correo entero, sin tener que añadir nada.
--
-- "on conflict do nothing" para poder volver a pasar la migración
-- sin pisar los textos que el club haya retocado ya.
-- ------------------------------------------------------------

insert into public.plantillas_email (nombre, asunto, cuerpo, categoria, variables) values

(
  'Bienvenida al club',
  'Bienvenido al Club Atletismo Apol-Ana, {{nombre}}',
  E'Hola:\n\n' ||
  E'Ya está todo listo: {{nombre}} queda inscrito en el grupo {{grupo}}.\n\n' ||
  E'Los entrenamientos son {{horario}}. Solo hace falta ropa cómoda, zapatillas de deporte y una botella de agua; el material lo pone el club.\n\n' ||
  E'La cuota es de {{importe}} y se pasa por domiciliación. Si hay que cambiar algún dato de la cuenta, escríbenos y lo ajustamos.\n\n' ||
  E'Cualquier duda, por aquí estamos.\n\n' ||
  E'Un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'altas',
  array['nombre','grupo','horario','importe']
),

(
  'Recordatorio de cuota',
  'Recordatorio de la cuota de {{nombre}}',
  E'Hola:\n\n' ||
  E'Te recordamos que el {{fecha}} se pasa la cuota de {{nombre}} ({{grupo}}), de {{importe}}.\n\n' ||
  E'No hay que hacer nada: se cobra por domiciliación en la cuenta que nos disteis. Solo te pedimos que revises que hay saldo, porque cada recibo devuelto tiene comisión del banco.\n\n' ||
  E'Si prefieres pagarlo de otra forma o quieres cambiar la cuenta, dínoslo antes de esa fecha.\n\n' ||
  E'Gracias y un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'cuotas',
  array['nombre','grupo','importe','fecha']
),

(
  'Aviso de impago',
  'Recibo devuelto de {{nombre}}',
  E'Hola:\n\n' ||
  E'El banco nos ha devuelto el recibo de {{nombre}} ({{grupo}}) de {{importe}}, con vencimiento el {{fecha}}.\n\n' ||
  E'Suele ser un despiste con el saldo o un cambio de cuenta, así que no te preocupes. Para ponerlo al día tienes dos opciones:\n\n' ||
  E'· Transferencia al club indicando el nombre del atleta y el mes.\n' ||
  E'· Pasarte por secretaría y lo arreglamos allí mismo.\n\n' ||
  E'Si hay cualquier problema, cuéntanoslo con confianza: siempre buscamos la manera de que nadie deje de entrenar por dinero.\n\n' ||
  E'Un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'cuotas',
  array['nombre','grupo','importe','fecha']
),

(
  'Convocatoria de competición',
  'Convocatoria: {{competicion}} · {{fecha}}',
  E'Hola:\n\n' ||
  E'{{nombre}} está convocado para {{competicion}}, el {{fecha}} en {{lugar}}.\n\n' ||
  E'Quedamos {{hora_quedada}} en el punto de encuentro. Hay que llevar la equipación del club, los clavos, ropa de abrigo, agua y algo de comer para entre pruebas.\n\n' ||
  E'Por favor, confírmanos la asistencia respondiendo a este correo antes del {{fecha_limite}}. Necesitamos saberlo para cerrar las inscripciones y organizar los desplazamientos.\n\n' ||
  E'Un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'competiciones',
  array['nombre','competicion','fecha','lugar','hora_quedada','fecha_limite']
),

(
  'Fin del periodo de prueba',
  'Se acaba el periodo de prueba de {{nombre}}',
  E'Hola:\n\n' ||
  E'{{nombre}} termina el {{fecha}} las semanas de prueba en {{grupo}}. Nos ha gustado mucho tenerlo por la pista y esperamos que él se lo haya pasado igual de bien.\n\n' ||
  E'Ahora toca decidir: si quiere seguir, solo tienes que decírnoslo y lo damos de alta con la cuota de {{importe}}. Si prefieres dejarlo, no hay ningún compromiso ni nada que pagar.\n\n' ||
  E'Si quieres que te contemos cómo lo hemos visto entrenando antes de decidir, llámanos y hablamos con calma.\n\n' ||
  E'Un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'altas',
  array['nombre','grupo','importe','fecha']
),

(
  'Ropa lista para recoger',
  'Ya tienes la ropa de {{nombre}}',
  E'Hola:\n\n' ||
  E'Ha llegado el pedido de ropa de {{nombre}}. Ya lo puedes recoger en secretaría en horario de entrenamiento.\n\n' ||
  E'Importe pendiente: {{importe}}. Se puede pagar al recogerlo.\n\n' ||
  E'Cuando lo tengas, pruébatelo cuanto antes: si la talla no va bien, mientras no se haya usado se puede cambiar sin problema.\n\n' ||
  E'Un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'tienda',
  array['nombre','importe']
),

(
  'Entrenamiento suspendido',
  'Hoy no hay entrenamiento de {{grupo}}',
  E'Hola:\n\n' ||
  E'El entrenamiento de {{grupo}} del {{fecha}} queda suspendido por {{motivo}}.\n\n' ||
  E'El siguiente día se entrena con normalidad en el horario de siempre ({{horario}}). Si hubiera algún cambio más, te avisamos por aquí.\n\n' ||
  E'Perdona las molestias y un saludo,\n' ||
  E'Club Atletismo Apol-Ana\n' ||
  E'administracion@atletismoapolana.com · 625 47 38 30',
  'avisos',
  array['grupo','fecha','motivo','horario']
)

on conflict do nothing;
