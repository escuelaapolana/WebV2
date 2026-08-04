-- ============================================================
-- 120 · Que alguien se entere de que ha entrado un alta
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Una familia rellena el alta, la web le dice «recibido»… y no se
-- entera nadie. El alta se queda en la base esperando a que alguien
-- se acuerde de entrar a mirar.
--
-- Hoy no se nota porque no hay ninguna: las tres bandejas están a
-- cero. En septiembre entran unas cuatrocientas familias, y entonces
-- «acordarse de mirar» deja de ser un plan.
--
-- LO QUE YA HABÍA, Y NO SE TOCA
-- Verlas ya se puede: están `admin/altas/` y `admin/pedidos/`, y al
-- entrar al panel la bandeja de «Necesita tu atención» ya dice
-- cuántas hay sin revisar. Eso está bien y se queda como está.
-- Lo que falta no es una pantalla más: es el empujón al móvil para
-- no tener que entrar a mirar por si acaso.
--
-- Los avisos al móvil también están montados (migraciones 054, 082 y
-- 083, y la función `aviso-enviar`). Aquí NO se monta un segundo
-- sistema: se usa el mismo, con las mismas claves, los mismos buzones
-- de móvil y la misma limpieza de los que ya no existen. Lo único que
-- se añade es quién recibe estos avisos y cada cuánto.
--
-- ------------------------------------------------------------
-- A QUIÉN SE AVISA · SALE DE LOS PAPELES, NO DE UNA LISTA
-- ------------------------------------------------------------
-- Lo decidió el club:
--   · alta de la escuela ....  administración
--   · alta de socio .........  administración y contabilidad
--   · pedido de ropa ........  administración
--
-- No hay ni un nombre ni un correo escrito en este archivo, y no lo
-- puede haber: el repositorio es público. Se mira el papel que cada
-- uno tiene en `perfiles`, así que el día que entre otra persona en
-- administración empieza a recibirlos sola, sin tocar nada.
--
-- OJO CON UN DETALLE: se mira `roles` (los papeles que TIENE), no
-- `rol_activo` (el papel que lleva puesto ahora mismo). Quien lleva
-- dos papeles y en ese momento está mirando el panel como entrenador
-- sigue siendo de administración, y el alta le tiene que llegar
-- igual. Por eso aquí no se usan `es_admin()` ni sus hermanas, que
-- para lo que sirven —decidir qué puede tocar alguien en la pantalla
-- en la que está— hacen bien en mirar el papel puesto.
--
-- ------------------------------------------------------------
-- EL RUIDO · ESTE ES EL PROBLEMA DE VERDAD
-- ------------------------------------------------------------
-- Si entran cuarenta altas en una tarde de septiembre, cuarenta
-- avisos seguidos no ayudan a nadie: son el motivo por el que la
-- gente apaga los avisos del club. Y el día que se apagan se pierden
-- también los que sí importaban.
--
-- La regla que se aplica aquí, en una frase:
--
--     UN AVISO POR BANDEJA. NO SALE OTRO HASTA QUE ESA BANDEJA SE
--     QUEDE A CERO. Y SI NADIE LA VACÍA, SE INSISTE UNA VEZ AL DÍA.
--
-- Lo que pasa en la práctica el primer día de septiembre:
--   09:00  entra el alta nº 1  → suena el móvil: «hay altas nuevas».
--   09:05  entra el alta nº 2  → no suena.
--   …      entran 38 más       → no suena ni una vez.
--   20:00  se revisan todas.
--   20:05  entra el alta nº 41 → vuelve a sonar.
--
-- Un aviso en lugar de cuarenta y uno, y sin perderse ninguna: el
-- número de verdad está en el panel, que se cuenta solo y siempre
-- está al día.
--
-- CÓMO SE SABE QUE LA BANDEJA SE VACIÓ, SIN APUNTAR NADA MÁS
-- Se mira la fecha del alta MÁS VIEJA que sigue sin revisar. Si esa
-- alta llegó DESPUÉS del último aviso, quiere decir que todo lo que
-- había cuando se avisó ya está resuelto: la bandeja se vació y lo
-- que hay ahora es cosecha nueva, así que toca avisar otra vez. Y
-- durante una avalancha pasa justo lo contrario —la más vieja es
-- anterior al aviso— y por eso no suena. Sale gratis: no hace falta
-- apuntar quién revisó qué ni cuántas había.
--
-- LO DE INSISTIR UNA VEZ AL DÍA
-- Si una bandeja se queda sin revisar, a las doce horas puede volver
-- a sonar una vez. Es el equilibrio entre «no insistas» y «que no se
-- quede una familia sin contestar una semana». Doce horas y no menos
-- porque así, como mucho, es una por la mañana y otra por la tarde.
--
-- DE NOCHE NO SE AVISA
-- Entre las diez de la noche y las ocho de la mañana no suena nada.
-- Un alta no es una urgencia, y un móvil que suena a las tres de la
-- madrugada es la forma más rápida de que alguien apague los avisos
-- para siempre. El aviso no se pierde: como esa noche no se apunta
-- que se haya avisado, sale con el siguiente movimiento de la mañana.
-- Y si esa noche no entrara nada más, la bandeja del panel lo sigue
-- diciendo al entrar, que es la vía que manda.
--
-- ------------------------------------------------------------
-- EL AVISO NO LLEVA NI UN DATO DE NADIE
-- ------------------------------------------------------------
-- Pone «Un alta nueva de la escuela» y nada más. Ni el nombre del
-- niño, ni el del tutor, ni cuántas hay. Dos razones:
--   · Un aviso al móvil pasa por Google o por Apple antes de llegar.
--     Va cifrado, pero el nombre de un menor no tiene por qué hacer
--     ese viaje para decir algo que se resuelve con «ve a mirar».
--   · Se queda escrito en la pantalla de bloqueo de un móvil que
--     igual está encima de una mesa, boca arriba, en una cafetería.
-- Tampoco lleva el número: cuando lo abran, el panel dirá el de
-- verdad, y un número de hace tres horas solo sirve para confundir.
--
-- ------------------------------------------------------------
-- SI EL AVISO FALLA, EL ALTA NO SE PIERDE
-- ------------------------------------------------------------
-- Lo importante es que la familia quede apuntada. El aviso es un
-- extra, y va en un paso aparte y envuelto, como se hizo con las
-- faltas: el alta se guarda primero y se confirma a la familia; el
-- empujón al móvil va después, por su cuenta, y si se rompe no se le
-- dice nada a quien está delante ni se deshace nada. Un fallo de
-- Google no puede parecer que el alta no se ha guardado.
--
-- ------------------------------------------------------------
-- COMPROBADO CONTRA LA BASE, SIMULANDO LOS PAPELES
-- ------------------------------------------------------------
-- Se montó la escena dentro de una transacción que después se
-- deshizo: siete personas de mentira con los papeles que hay en el
-- club de verdad, un móvil dado de alta para cada una, y cuarenta
-- altas entrando una detrás de otra.
--
--   A QUIÉN LE LLEGA CADA BANDEJA
--                                        escuela  socio  pedidos
--     admin con varios papeles ........      sí     sí      sí
--     admin a secas ...................      sí     sí      sí
--     contabilidad ....................      NO     sí      NO
--     entrenador ......................      NO     NO      NO
--     atleta ..........................      NO     NO      NO
--     entrenador que TAMBIÉN es admin .      sí     sí      sí
--     admin sin móvil dado de alta ....      NO     NO      NO
--
--   El penúltimo es el que importa: su papel de siempre es
--   «entrenador» y aun así recibe las altas, porque las lleva. Con
--   la forma antigua de mirar el papel se habría quedado fuera.
--
--   UNA TARDE DE SEPTIEMBRE · 40 altas seguidas
--     altas que entran .................................  40
--     veces que suena el móvil .........................   1
--     y suena en la número ............................    1
--
--   SE REVISAN LAS 40 Y ENTRA LA 41
--     con la bandeja vacía, ¿suena? ....................  no
--     entra la 41, ¿suena? .............................  sí
--     se pregunta otra vez, ¿suena? ....................  no
--     y otra vez más ...................................  no
--
--   LA BANDEJA QUE NADIE MIRA
--     a las 11 horas ...................................  no
--     a las 12 horas ...................................  sí
--
--   DE NOCHE NO · las 24 horas, una por una
--     suena de 08:00 a 21:00 ...........................  14 horas
--     no suena de 22:00 a 07:00 ........................  10 horas
--     un alta a las 3 de la madrugada ..................  no suena
--     esa misma alta a las 8:30 ........................  sí suena
--
--   QUIEN LO APAGA DEJA DE RECIBIRLO
--     móviles del aviso de socio .......................   5
--     después de que dos lo apaguen ....................   3
--     y sus otros avisos (entrenos, pagos) ............. intactos
--
--   LO QUE NO SE PUEDE HACER DESDE FUERA
--     una bandeja inventada despierta a alguien ........  no
--     llamar sin decir de qué ..........................  no
--     leer la tabla sin cuenta / escribirla con cuenta .  no
--     las cuatro funciones, desde el navegador .........  cerradas
--     datos personales que salen de la base ............ ninguno
--       (solo devuelve: id, endpoint, p256dh, auth)
--
--   Y al deshacerlo todo no quedó ni una fila de prueba.
--
-- Todo el fichero se puede volver a pasar las veces que haga falta.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · Un interruptor más: «Altas y pedidos»
-- ------------------------------------------------------------
-- Los avisos del club ya tenían cinco interruptores, uno por tema
-- (migración 054). Estos no encajan en ninguno: no son un
-- entrenamiento, ni una competición, ni un recibo. Son trabajo del
-- club, así que llevan el suyo.
--
-- Nace encendido porque quien lo recibe es justo quien ha pedido que
-- le avisen. Y se puede apagar desde «Avisos» en el portal: quien lo
-- apague sigue viendo las altas al entrar al panel, en la bandeja de
-- «Necesita tu atención». Apagar el ruido no es dejar de enterarse.
alter table public.avisos_preferencias
  add column if not exists gestion boolean not null default true;

comment on column public.avisos_preferencias.gestion is
  'Avisar al móvil cuando entra un alta o un pedido de ropa. Solo lo reciben administración y contabilidad; para los demás no cambia nada.';

-- La misma función de siempre, con el tema nuevo añadido. Se copia
-- entera porque en Postgres no se puede añadir media función.
create or replace function public.avisos_quiere(p_perfil uuid, p_categoria text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select case p_categoria
    when 'entrenos'      then coalesce((select p.entrenos      from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    when 'competiciones' then coalesce((select p.competiciones from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    when 'pagos'         then coalesce((select p.pagos         from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    when 'noticias'      then coalesce((select p.noticias      from public.avisos_preferencias p where p.perfil_id = p_perfil), false)
    when 'retos'         then coalesce((select p.retos         from public.avisos_preferencias p where p.perfil_id = p_perfil), false)
    -- Nuevo: altas y pedidos. Encendido de fábrica, como los tres
    -- primeros: quien lo recibe es quien lleva esa tarea.
    when 'gestion'       then coalesce((select p.gestion       from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    else false
  end;
$$;

-- ------------------------------------------------------------
-- 2 · Las tres bandejas y cuándo se avisó de cada una
-- ------------------------------------------------------------
-- Una fila por bandeja y para siempre: no crece nunca. Aquí solo se
-- apunta CUÁNDO salió el último aviso de cada una, que es lo único
-- que hace falta para no repetir. No se guarda nada de ningún alta
-- ni de ninguna persona.
create table if not exists public.avisos_novedades (
  tipo        text primary key
              check (tipo in ('alta_escuela', 'alta_socio', 'pedido')),
  avisado_en  timestamptz,
  -- Solo para poder mirar si esto funciona: a cuántos móviles llegó
  -- el último aviso y cuántos fallaron. Sin esto, el día que nadie
  -- reciba nada no habría por dónde empezar a buscar.
  enviados    integer not null default 0,
  fallidos    integer not null default 0
);

comment on table public.avisos_novedades is
  'Cuándo se avisó por última vez de cada bandeja. Sirve para que una avalancha de altas no sea una avalancha de avisos.';

insert into public.avisos_novedades (tipo)
values ('alta_escuela'), ('alta_socio'), ('pedido')
on conflict (tipo) do nothing;

alter table public.avisos_novedades enable row level security;

-- Nadie escribe aquí desde el navegador. Lo lleva la función que
-- manda los avisos, que entra con la llave de servicio y no pasa por
-- estas reglas. Al equipo del club se le deja mirar, para poder
-- comprobar que los avisos salen.
drop policy if exists "el equipo mira cuando se avisó" on public.avisos_novedades;
create policy "el equipo mira cuando se avisó" on public.avisos_novedades
for select to authenticated
using (public.es_staff());

-- ------------------------------------------------------------
-- 3 · ¿Cuántas hay sin revisar, y de cuándo es la más vieja?
-- ------------------------------------------------------------
-- Las dos cosas de una vez, porque siempre se piden juntas: el
-- número dice si hay algo de lo que avisar, y la fecha de la más
-- vieja dice si la bandeja se vació desde el último aviso.
create or replace function public.novedades_sin_revisar(p_tipo text)
returns table (cuantas integer, la_mas_vieja timestamptz)
language sql
stable
security definer
set search_path to 'public'
as $$
  select count(*)::integer, min(created_at)
    from (
      select created_at from public.altas_escuela
       where p_tipo = 'alta_escuela' and estado = 'pendiente'
      union all
      select created_at from public.altas_socio
       where p_tipo = 'alta_socio'   and estado = 'pendiente'
      union all
      select created_at from public.pedidos
       where p_tipo = 'pedido'       and estado = 'pendiente'
    ) t;
$$;

comment on function public.novedades_sin_revisar(text) is
  'Cuántas cosas esperan en esa bandeja y de cuándo es la más antigua.';

-- ------------------------------------------------------------
-- 3.b · ¿Es hora decente para que suene un móvil?
-- ------------------------------------------------------------
-- De ocho de la mañana a diez de la noche, hora de España. Está
-- aparte y recibe el momento por fuera para poder probarla a
-- cualquier hora del día sin esperar a que sean las tres de la
-- madrugada: así se comprueban las veinticuatro horas de una vez.
create or replace function public.novedades_hora_decente(p_momento timestamptz default now())
returns boolean
language sql
immutable
as $$
  select (p_momento at time zone 'Europe/Madrid')::time >= time '08:00'
     and (p_momento at time zone 'Europe/Madrid')::time <  time '22:00';
$$;

comment on function public.novedades_hora_decente(timestamptz) is
  'De 8:00 a 22:00, hora de España. Fuera de ahí no suena ningún móvil por un alta: no es una urgencia.';

-- ------------------------------------------------------------
-- 3.c · LA REGLA, ELLA SOLA
-- ------------------------------------------------------------
-- Aquí están las cuatro condiciones y nada más: no mira la base, no
-- escribe nada y no sabe qué hora es hasta que se lo dicen. Se le dan
-- los cuatro datos y contesta sí o no.
--
-- Está separada para poder demostrar que hace lo que dice. Metida
-- dentro de la función que escribe, la única forma de comprobar la
-- regla de «de noche no» sería ejecutar la comprobación a las tres de
-- la madrugada, y la de las doce horas, esperando doce horas. Así se
-- prueban las veinticuatro horas del día y cualquier situación en un
-- segundo, y lo que se prueba es exactamente lo que corre de verdad.
create or replace function public.novedades_decide(
  p_avisado    timestamptz,   -- cuándo se avisó por última vez (o nada)
  p_cuantas    integer,       -- cuántas esperan ahora mismo
  p_mas_vieja  timestamptz,   -- de cuándo es la más antigua que espera
  p_ahora      timestamptz    -- qué momento es
)
returns boolean
language sql
immutable
as $$
  select case
    -- De noche no suena nada, pase lo que pase.
    when not public.novedades_hora_decente(p_ahora)   then false
    -- No hay nada esperando: no hay de qué avisar.
    when coalesce(p_cuantas, 0) = 0                   then false
    -- Nunca se ha avisado de esta bandeja.
    when p_avisado is null                            then true
    -- La más vieja que sigue sin revisar llegó DESPUÉS del último
    -- aviso: la bandeja se vació entera y esto es cosecha nueva.
    when p_mas_vieja > p_avisado                      then true
    -- Nadie la ha mirado en doce horas. Se insiste una vez.
    when p_ahora - p_avisado >= interval '12 hours'   then true
    -- Ya se avisó y sigue dentro lo mismo. Silencio.
    else false
  end;
$$;

comment on function public.novedades_decide(timestamptz, integer, timestamptz, timestamptz) is
  'La regla del ruido, ella sola y sin tocar nada: un aviso por bandeja, otro cuando se vacía o a las doce horas, y nunca de noche.';

-- ------------------------------------------------------------
-- 4 · ¿Toca avisar, o sería ruido?
-- ------------------------------------------------------------
-- Esta es la única que escribe. Reúne los datos, le pregunta a la
-- regla de arriba y, si dice que sí, deja apuntado que se avisó, todo
-- de una vez: si dos altas entran en el mismo segundo, la fila se
-- bloquea y la segunda encuentra el aviso ya apuntado y se calla. Sin
-- eso, dos familias rellenando el formulario a la vez serían dos
-- avisos por lo mismo.
create or replace function public.novedades_toca_avisar(p_tipo text)
returns boolean
language plpgsql
volatile
security definer
set search_path to 'public'
as $$
declare
  v_avisado   timestamptz;
  v_cuantas   integer;
  v_mas_vieja timestamptz;
begin
  -- Un tipo que no existe no avisa de nada. Se contesta que no y ya:
  -- esto lo llama una función a la que puede escribir cualquiera
  -- desde la calle, así que no se fía de lo que le llega.
  if p_tipo is null or p_tipo not in ('alta_escuela', 'alta_socio', 'pedido') then
    return false;
  end if;

  -- DE NOCHE NO, y se mira lo primero: así se sale sin tocar nada, el
  -- aviso no se gasta, y sale con el primer movimiento de la mañana.
  if not public.novedades_hora_decente(now()) then
    return false;
  end if;

  -- Se coge la fila de esta bandeja y se queda cogida hasta el final:
  -- es lo que impide que dos altas a la vez manden dos avisos.
  select avisado_en into v_avisado
    from public.avisos_novedades
   where tipo = p_tipo
     for update;

  if not found then
    return false;
  end if;

  select cuantas, la_mas_vieja into v_cuantas, v_mas_vieja
    from public.novedades_sin_revisar(p_tipo);

  -- No hay nada esperando. Puede pasar: alguien revisó el alta en el
  -- rato que va del formulario al aviso. Se borra la marca para que
  -- la próxima que entre avise sin esperar a nada.
  if coalesce(v_cuantas, 0) = 0 then
    update public.avisos_novedades
       set avisado_en = null
     where tipo = p_tipo;
    return false;
  end if;

  if public.novedades_decide(v_avisado, v_cuantas, v_mas_vieja, now()) then
    update public.avisos_novedades
       set avisado_en = now(), enviados = 0, fallidos = 0
     where tipo = p_tipo;
    return true;
  end if;

  return false;
end;
$$;

comment on function public.novedades_toca_avisar(text) is
  'Sí o no: un aviso por bandeja, ninguno más hasta que se vacíe o pasen doce horas, y nunca de noche. Al decir que sí, deja apuntado que se avisó.';

-- ------------------------------------------------------------
-- 5 · A qué móviles va
-- ------------------------------------------------------------
-- Devuelve buzones de móvil, no personas: ni un nombre, ni un correo,
-- ni un teléfono salen de aquí. Es lo mismo que hace
-- `avisos_destinatarios` para los avisos del club (migración 054), y
-- se apoya en `avisos_quiere` para respetar a quien lo haya apagado.
create or replace function public.novedades_destinatarios(p_tipo text)
returns table (id uuid, endpoint text, p256dh text, auth text)
language sql
stable
security definer
set search_path to 'public'
as $$
  select s.id, s.endpoint, s.p256dh, s.auth
    from public.avisos_suscripciones s
    join public.perfiles p on p.id = s.perfil_id
   where coalesce(p.activo, true)
     -- LOS PAPELES QUE TIENE, no el que lleva puesto ahora mismo:
     -- quien está mirando el panel como entrenador sigue siendo de
     -- administración y el alta le tiene que llegar igual.
     -- `coalesce` porque hay fichas antiguas que solo tienen el papel
     -- de siempre (`rol`) y todavía no la lista (`roles`).
     and coalesce(p.roles, array[p.rol]) && (
           case p_tipo
             -- Las altas de la escuela y los pedidos de ropa los
             -- lleva administración.
             when 'alta_escuela' then array['admin']
             when 'pedido'       then array['admin']
             -- Las de socio, administración y quien lleva la
             -- contabilidad.
             when 'alta_socio'   then array['admin', 'contabilidad']
             -- Cualquier otra cosa: a nadie.
             else array[]::text[]
           end
         )
     and public.avisos_quiere(s.perfil_id, 'gestion');
$$;

comment on function public.novedades_destinatarios(text) is
  'Los buzones de móvil a los que va el aviso de esa bandeja, sacados del papel que cada uno tiene en el club. No devuelve ni un dato personal.';

-- ------------------------------------------------------------
-- 6 · Apuntar cómo fue
-- ------------------------------------------------------------
-- Para que el día que nadie reciba nada se pueda mirar si es que no
-- salió, o que salió y no llegó.
create or replace function public.novedades_apuntar_envio(
  p_tipo text, p_enviados integer, p_fallidos integer
)
returns void
language sql
volatile
security definer
set search_path to 'public'
as $$
  update public.avisos_novedades
     set enviados = greatest(coalesce(p_enviados, 0), 0),
         fallidos = greatest(coalesce(p_fallidos, 0), 0)
   where tipo = p_tipo;
$$;

-- ------------------------------------------------------------
-- 7 · Quién puede llamar a todo esto
-- ------------------------------------------------------------
-- Nace cerrado, como manda la migración 090. Estas seis las llama
-- SOLO la función `aviso-enviar`, que entra con la llave de servicio
-- del club. Desde el navegador no se llaman nunca, ni habiendo
-- entrado con cuenta: lo que el navegador hace es pedirle a
-- `aviso-enviar` que mire si toca avisar, y es ella quien decide.
--
-- Y esto es lo que impide que nadie se salte la regla del ruido desde
-- fuera: la decisión y el apunte de «ya se avisó» pasan siempre por
-- la misma puerta, que está cerrada con llave.
revoke all on function public.novedades_hora_decente(timestamptz)         from public, anon, authenticated;
revoke all on function public.novedades_decide(timestamptz, integer, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function public.novedades_sin_revisar(text)                 from public, anon, authenticated;
revoke all on function public.novedades_toca_avisar(text)                 from public, anon, authenticated;
revoke all on function public.novedades_destinatarios(text)               from public, anon, authenticated;
revoke all on function public.novedades_apuntar_envio(text, int, int)     from public, anon, authenticated;

grant execute on function public.novedades_hora_decente(timestamptz)      to service_role;
grant execute on function public.novedades_decide(timestamptz, integer, timestamptz, timestamptz) to service_role;
grant execute on function public.novedades_sin_revisar(text)              to service_role;
grant execute on function public.novedades_toca_avisar(text)              to service_role;
grant execute on function public.novedades_destinatarios(text)            to service_role;
grant execute on function public.novedades_apuntar_envio(text, int, int)  to service_role;

commit;
