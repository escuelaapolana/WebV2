-- ============================================================
-- 136 · Que el móvil suene cuando te piden plaza (y cuando te contestan)
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- La migración 131 montó el pedir plaza entero: el atleta lo pide,
-- quien lleva la actividad acepta o rechaza, y el aviso le llega a su
-- buzón del portal. Todo bien menos una cosa: EL MÓVIL NO SUENA.
--
-- Y sin eso la función se queda coja. Un entrenador que no entra a la
-- app en tres días deja a un chaval tres días esperando respuesta, y
-- el chaval no sabe si es que no le han contestado o es que le han
-- dicho que no. El buzón del portal solo sirve si alguien entra a
-- mirarlo, que es exactamente el problema que vienen a resolver los
-- avisos al móvil.
--
-- ------------------------------------------------------------
-- LO QUE NO SE HACE AQUÍ: UN TERCER SISTEMA DE AVISOS
-- ------------------------------------------------------------
-- Ya costó dejar uno solo. Se reutiliza TODO lo que hay:
--   · `novedades_hora_decente` y `novedades_decide` (migración 120),
--     que son la regla del ruido y la hora de silencio. Ni una línea
--     copiada: se llaman.
--   · `solicitudes_toca_avisar` (migración 131), que ya aplica esa
--     regla por persona y ya decide si toca o sería ruido.
--   · Los buzones de móvil, las claves, el cifrado y la limpieza de
--     los buzones muertos: todo eso vive en la función `aviso-enviar`
--     y no se toca.
--   · El interruptor «gestión» de la migración 120, que ya dice
--     «altas, pedidos y peticiones de plaza» en la pantalla de avisos.
--
-- Lo único que falta —y lo único que se añade— es EL CAMINO entre la
-- base, que es quien sabe que ha pasado algo, y la función que hace
-- sonar los móviles.
--
-- ------------------------------------------------------------
-- POR QUÉ HACE FALTA UNA COLA Y NO UNA LLAMADA DIRECTA
-- ------------------------------------------------------------
-- La base de datos NO PUEDE llamar por su cuenta a la función que
-- manda los avisos. Para eso haría falta una extensión (`pg_net`) que
-- este proyecto no tiene instalada; se ha comprobado. Así que alguien
-- de fuera tiene que dar el toque.
--
-- ¿Y por qué no lo da directamente el navegador de quien pide la
-- plaza, como hacen las altas? Porque la decisión de si toca avisar o
-- sería ruido YA ESTÁ TOMADA aquí dentro, en el mismo momento en que
-- se guarda la petición, y está bien que sea así: es lo que garantiza
-- que treinta peticiones en una tarde sean un aviso y no treinta. Si
-- el navegador volviera a preguntar «¿toca?», la respuesta sería que
-- no —ya se gastó— y no sonaría nunca nada.
--
-- Entonces la base apunta el recado y el navegador solo lo lleva:
--
--     lo que pasa            quién lo hace         qué queda
--     ------------------------------------------------------------
--     entra una petición     la base (disparador)  fila en la cola
--     se contesta            la base (función)     fila en la cola
--     alguien abre el portal el navegador          se vacía la cola
--
-- Esto tiene dos ventajas que no son pequeñas:
--   · SI EL EMPUJÓN FALLA, NO SE PIERDE. La fila se queda en la cola
--     y sale con el siguiente movimiento. Antes, un móvil sin
--     cobertura en ese segundo era un aviso perdido para siempre.
--   · DE NOCHE SE GUARDA, NO SE TIRA. Una respuesta dada a las once
--     de la noche no despierta a nadie: espera en la cola y sale por
--     la mañana. Esto es MEJOR que lo de las altas, donde el aviso
--     nocturno simplemente no salía.
--
-- ------------------------------------------------------------
-- EL AVISO NO LLEVA NI UN DATO DE NADIE
-- ------------------------------------------------------------
-- En esta tabla no se guarda ni el nombre del que pide, ni el de la
-- actividad, ni el motivo del «no». Se guardan dos cosas: A QUIÉN hay
-- que dar el toque y DE QUÉ CLASE es. El texto —«Te han pedido
-- plaza», «Tienes plaza», «No ha podido ser»— está escrito dentro de
-- la función `aviso-enviar` y no lo elige nadie desde fuera.
--
-- Por qué tan poco: ese texto pasa por Google o por Apple y se queda
-- escrito en la pantalla de bloqueo de un móvil que igual está encima
-- de una mesa. El nombre de un crío y el de la actividad a la que no
-- le han dejado ir no tienen por qué hacer ese viaje. Quien lo abra
-- verá el detalle entero en el portal, que además está al día.
--
-- ------------------------------------------------------------
-- SI EL AVISO FALLA, LA PETICIÓN NO SE PIERDE
-- ------------------------------------------------------------
-- Lo de siempre, y es lo que manda: apuntar el recado va DENTRO del
-- mismo envoltorio que ya tenía la 131. Si escribir en la cola
-- reventara, se traga el fallo y la petición (o la respuesta) queda
-- guardada igual. Un problema del buzón no puede deshacer lo que
-- alguien acaba de pedir ni la respuesta que acaba de dar.
--
-- ------------------------------------------------------------
-- QUE SE PUEDA APAGAR, SIN APAGAR LO DEMÁS
-- ------------------------------------------------------------
-- No hace falta un interruptor nuevo, y por eso no se pone:
--   · «Te han pedido plaza» va por «gestión», el mismo de las altas y
--     los pedidos, que ya dice «peticiones de plaza» en su letra.
--     Apagarlo deja intactos entrenos, pagos, competiciones,
--     noticias y retos.
--   · «Tienes plaza» / «No ha podido ser» van por «entrenos», que es
--     donde está lo que le cambia el día a un atleta. Apagarlo deja
--     intactos los otros cinco.
-- Y apagar cualquiera de los dos NO apaga el buzón del portal: el
-- aviso sigue estando ahí. Se apaga el ruido, no la información.
--
-- ------------------------------------------------------------
-- COMPROBADO CONTRA LA BASE, CON LOS NÚMEROS DELANTE
-- ------------------------------------------------------------
-- Se montó la escena dentro de una transacción que después se
-- deshizo: un entrenador con su grupo y una actividad de «hay que
-- pedir plaza», un menor con su ficha colgando de la cuenta de su
-- padre, y un móvil dado de alta para cada uno.
--
--   TRES PETICIONES SEGUIDAS
--     peticiones que entran ............................   3
--     empujones al móvil apuntados ....................    1
--     empujones a quien NO lleva la actividad .........    0
--
--   A QUÉ MÓVILES VA ESE EMPUJÓN
--     buzones del entrenador ..........................    1
--     después de que apague «lo que tienes que revisar»    0
--     y sus avisos de entrenos y de pagos ............. intactos
--
--   LA RESPUESTA A UN MENOR
--     empujones de «Tienes plaza» .....................    2
--       a su cuenta ...................................    1
--       a la de su familia ............................    1
--     contestar dos veces lo mismo ....................    2 (no 4)
--
--   DE NOCHE NO SUENA, Y NO SE PIERDE
--     empujones que salen de noche ....................    0
--     empujones que siguen esperando a la mañana ......    3
--     y por la mañana salen ...........................    3
--     segunda pasada: ya no quedan ....................    0
--
--   LA BANDEJA QUE SIGUE LLENA
--     entra otra petición sin haber contestado ........ no suena
--     se contestan todas y entra una nueva ............ suena (1)
--     y con una más encima ............................    1
--
--   LO QUE NO SE PUEDE HACER DESDE FUERA
--     las cuatro funciones, desde el navegador ........ cerradas
--       (anónimo: no · con cuenta: no · llave del club: sí)
--     una familia contestando a su propia petición .... cortado
--     datos personales guardados en la cola ........... ninguno
--       (id, clase, perfil_id, creado_en, tomado_en,
--        enviado_en, enviados, fallidos)
--
--   Y al deshacerlo todo no quedó ni una fila de prueba.
--
-- Todo el fichero se puede volver a pasar las veces que haga falta.
-- ============================================================

begin;

-- ============================================================
-- 1 · LA COLA DE EMPUJONES
-- ============================================================
-- Una fila = un toque pendiente a una persona. Se crea cuando pasa
-- algo y se borra sola cuando ya no sirve. No es un historial: el
-- historial de avisos ya existe y es `avisos_enviados`.
create table if not exists public.avisos_cola_movil (
  id          uuid primary key default gen_random_uuid(),
  -- De qué clase es el toque. El texto NO está aquí a propósito:
  -- vive en la función que manda los avisos, para que nadie pueda
  -- hacer que el móvil del club diga lo que le dé la gana.
  clase       text not null
              check (clase in ('solicitud_plaza', 'plaza_si', 'plaza_no')),
  perfil_id   uuid not null references public.perfiles(id) on delete cascade,
  creado_en   timestamptz not null default now(),
  -- Cuándo se lo llevó la función que reparte. Sirve para que dos
  -- navegadores a la vez no manden el mismo aviso dos veces.
  tomado_en   timestamptz,
  enviado_en  timestamptz,
  enviados    integer not null default 0,
  fallidos    integer not null default 0
);

comment on table public.avisos_cola_movil is
  'Los toques al móvil pendientes de salir. La base apunta el recado porque no puede llamar ella sola a quien hace sonar los móviles; el navegador lo lleva. Aquí no hay ni un nombre.';

-- Lo que más se hace: pedir lo que queda por mandar, lo más viejo
-- primero. El índice es solo de lo pendiente, que es un puñado de
-- filas aunque la tabla haya visto pasar miles.
create index if not exists idx_avisos_cola_movil_pendiente
  on public.avisos_cola_movil (creado_en)
  where enviado_en is null;

alter table public.avisos_cola_movil enable row level security;

-- Nadie escribe aquí desde el navegador, y desde el navegador solo se
-- ve lo propio: que a una persona le hayan dado o quitado una plaza
-- no es asunto de nadie más.
drop policy if exists "veo mis toques al movil" on public.avisos_cola_movil;
create policy "veo mis toques al movil" on public.avisos_cola_movil
for select to authenticated
using (perfil_id = public.mi_perfil_id());

-- ------------------------------------------------------------
-- 1.b · Apuntar un recado
-- ------------------------------------------------------------
-- La llaman los dos sitios de la migración 131 que ya deciden cuándo
-- hay que avisar. Aquí no se decide nada: se apunta.
--
-- LO ÚNICO QUE SÍ HACE: no apuntar dos veces lo mismo. Si ya hay un
-- toque de esa misma clase esperando a esa misma persona, no se añade
-- otro. Dos «Tienes plaza» seguidos en la pantalla de bloqueo no
-- dicen nada que no diga uno, y el detalle de cada uno está en el
-- portal. Es la misma idea de «un aviso por bandeja», aplicada al
-- último metro.
create or replace function public.avisos_cola_movil_poner(
  p_clase  text,
  p_perfil uuid
)
returns void
language plpgsql
volatile
security definer
set search_path to 'public'
as $$
begin
  if p_perfil is null
     or p_clase is null
     or p_clase not in ('solicitud_plaza', 'plaza_si', 'plaza_no') then
    return;
  end if;

  if exists (
    select 1 from public.avisos_cola_movil
     where perfil_id = p_perfil
       and clase = p_clase
       and enviado_en is null
  ) then
    return;
  end if;

  insert into public.avisos_cola_movil (clase, perfil_id)
  values (p_clase, p_perfil);
end;
$$;

comment on function public.avisos_cola_movil_poner(text, uuid) is
  'Deja apuntado que a esa persona hay que darle un toque al móvil. Si ya había uno igual esperando, no añade otro.';

-- ------------------------------------------------------------
-- 1.c · Coger lo que toca mandar
-- ------------------------------------------------------------
-- La llama SOLO la función `aviso-enviar`, con la llave de servicio.
-- Hace cuatro cosas y en este orden:
--
--   1. DE NOCHE, NADA. Entre las diez y las ocho devuelve la lista
--      vacía y no toca nada: los recados se quedan donde están y
--      salen con el primer movimiento de la mañana. Se usa la misma
--      función de la 120, no una copia.
--   2. Tira lo que ya no sirve. Un «te han pedido plaza» de hace doce
--      horas ya no es un aviso: es un susto. Y para eso está la
--      cifra del portal, que siempre está al día.
--   3. Limpia lo ya mandado de hace más de una semana, para que la
--      tabla no crezca para siempre.
--   4. Coge lo pendiente y lo marca como cogido. Si dos navegadores
--      llaman a la vez, el segundo se salta las filas que tiene el
--      primero (`skip locked`) y no se manda nada dos veces. Si el
--      primero se cae a medias, a los cinco minutos vuelve a estar
--      disponible: mejor un aviso repetido que uno perdido.
create or replace function public.avisos_cola_movil_tomar(p_tope integer default 40)
returns table (id uuid, clase text)
language plpgsql
volatile
security definer
set search_path to 'public'
as $$
begin
  if not public.novedades_hora_decente(now()) then
    return;
  end if;

  delete from public.avisos_cola_movil
   where enviado_en is null
     and creado_en < now() - interval '12 hours';

  delete from public.avisos_cola_movil
   where enviado_en is not null
     and enviado_en < now() - interval '7 days';

  return query
  with cogidas as (
    select c.id
      from public.avisos_cola_movil c
     where c.enviado_en is null
       and (c.tomado_en is null or c.tomado_en < now() - interval '5 minutes')
     order by c.creado_en
     limit greatest(1, least(coalesce(p_tope, 40), 200))
     for update skip locked
  )
  update public.avisos_cola_movil c
     set tomado_en = now()
    from cogidas
   where c.id = cogidas.id
  returning c.id, c.clase;
end;
$$;

comment on function public.avisos_cola_movil_tomar(integer) is
  'Los toques que toca mandar ahora mismo. De noche devuelve nada y los deja esperando a la mañana.';

-- ------------------------------------------------------------
-- 1.d · A qué móviles va ese toque
-- ------------------------------------------------------------
-- Se pide por el recado, no por la persona: así el identificador de
-- nadie tiene que salir de la base ni viajar a ninguna parte. Y
-- devuelve buzones de móvil, igual que `novedades_destinatarios`: ni
-- un nombre, ni un correo, ni un teléfono.
--
-- Aquí es donde manda lo que cada uno haya elegido recibir, con el
-- interruptor que corresponde a esa clase de toque.
create or replace function public.avisos_cola_movil_destinatarios(p_id uuid)
returns table (id uuid, endpoint text, p256dh text, auth text)
language sql
stable
security definer
set search_path to 'public'
as $$
  select s.id, s.endpoint, s.p256dh, s.auth
    from public.avisos_cola_movil c
    join public.perfiles p on p.id = c.perfil_id
    join public.avisos_suscripciones s on s.perfil_id = c.perfil_id
   where c.id = p_id
     and coalesce(p.activo, true)
     and public.avisos_quiere(
           c.perfil_id,
           -- «Te han pedido plaza» es trabajo del club: va con las
           -- altas y los pedidos. La respuesta le cambia el día a un
           -- atleta: va con los cambios de entrenamiento.
           case when c.clase = 'solicitud_plaza' then 'gestion' else 'entrenos' end
         );
$$;

comment on function public.avisos_cola_movil_destinatarios(uuid) is
  'Los buzones de móvil a los que va ese toque, con lo que cada uno haya elegido recibir ya aplicado. No devuelve ni un dato personal.';

-- ------------------------------------------------------------
-- 1.e · Apuntar que salió
-- ------------------------------------------------------------
-- Para que el día que alguien diga «a mí no me llega nada» se pueda
-- mirar si es que no salió, o que salió y no llegó.
create or replace function public.avisos_cola_movil_hecho(
  p_id       uuid,
  p_enviados integer,
  p_fallidos integer
)
returns void
language sql
volatile
security definer
set search_path to 'public'
as $$
  update public.avisos_cola_movil
     set enviado_en = now(),
         enviados   = greatest(coalesce(p_enviados, 0), 0),
         fallidos   = greatest(coalesce(p_fallidos, 0), 0)
   where id = p_id;
$$;

-- ------------------------------------------------------------
-- 1.f · Quién puede llamar a esto
-- ------------------------------------------------------------
-- Nacen cerradas, como manda la migración 090. `poner` la llaman los
-- dos disparadores de la 131, que entran por dentro con el nombre del
-- dueño de la base; las otras tres, solo `aviso-enviar` con la llave
-- de servicio. Desde el navegador no se llama ninguna: lo que el
-- navegador hace es pedirle a `aviso-enviar` que vacíe la cola, y es
-- ella quien mira si hay algo, si es hora y a quién le toca.
revoke all on function public.avisos_cola_movil_poner(text, uuid)      from public, anon, authenticated;
revoke all on function public.avisos_cola_movil_tomar(integer)         from public, anon, authenticated;
revoke all on function public.avisos_cola_movil_destinatarios(uuid)    from public, anon, authenticated;
revoke all on function public.avisos_cola_movil_hecho(uuid, int, int)  from public, anon, authenticated;

grant execute on function public.avisos_cola_movil_tomar(integer)        to service_role;
grant execute on function public.avisos_cola_movil_destinatarios(uuid)   to service_role;
grant execute on function public.avisos_cola_movil_hecho(uuid, int, int) to service_role;

-- ============================================================
-- 2 · EL RECADO A QUIEN DECIDE · «Te han pedido plaza»
-- ============================================================
-- Es la misma función de la migración 131 con una línea más: donde ya
-- escribía en el buzón del portal, ahora además apunta el toque al
-- móvil. Va en el MISMO sitio a propósito, dentro del mismo `if`: la
-- regla del ruido se pregunta UNA VEZ y manda para las dos cosas. Si
-- se preguntara dos veces, la segunda diría que no —ya se gastó— y el
-- móvil no sonaría nunca.
--
-- Y sigue dentro del mismo envoltorio: si algo revienta al avisar, la
-- plaza pedida ya está guardada y no se deshace.
create or replace function public.sesion_solicitud_avisa()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_perfil uuid;
begin
  if NEW.estado <> 'pendiente' then
    return null;
  end if;

  begin
    for v_perfil in select public.quien_decide_sesion(NEW.sesion_id) loop
      if public.solicitudes_toca_avisar(v_perfil) then
        perform public.avisos_registrar(
          'Te han pedido plaza',
          'Tienes peticiones sin contestar en tus actividades.',
          'portal/solicitudes/',
          'persona', 'gestion',
          null, null, v_perfil,
          'Solo para ti',
          0, 0, null, null, 'informativo', null, true, '{}'
        );

        -- Y que además suene el móvil. Sin esto, quien no entra a la
        -- app en tres días deja a un chaval tres días esperando.
        perform public.avisos_cola_movil_poner('solicitud_plaza', v_perfil);
      end if;
    end loop;
  exception when others then
    -- Ni una palabra: la plaza pedida está guardada, que es lo que
    -- importa. El número de verdad lo dice la pantalla al entrar.
    null;
  end;

  return null;
end;
$$;

comment on function public.sesion_solicitud_avisa() is
  'Avisa a quien lleva la actividad de que le han pedido plaza, en el portal y en el móvil, con la regla del ruido puesta y sin poder romper lo que se acaba de guardar.';

-- ============================================================
-- 3 · EL RECADO A QUIEN PIDIÓ · «Tienes plaza» / «No ha podido ser»
-- ============================================================
-- Otra vez la misma función de la 131, con una línea más dentro del
-- bucle que ya recorre a quién hay que avisar. Ese bucle es
-- importante y por eso se respeta tal cual: recorre la cuenta del
-- atleta Y la de su padre o madre. UN CRÍO DE CATORCE PUEDE TARDAR
-- TRES DÍAS EN ABRIR LA APP; SU PADRE NO. Lo que la 131 resolvió para
-- el buzón del portal, ahora vale igual para el móvil.
--
-- Aquí NO se aplica la regla del ruido, y es a propósito: esto no es
-- una bandeja que se llena, es una respuesta a algo que esa persona
-- pidió, y llega una sola vez.
create or replace function public.sesion_solicitud_decidir(
  p_id     uuid,
  p_estado text,
  p_motivo text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path to 'public'
as $$
declare
  v_fila    public.sesion_inscripciones;
  v_sesion  public.sesiones;
  v_yo      uuid := public.mi_perfil_id();
  v_motivo  text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_titulo  text;
  v_cuerpo  text;
  v_perfil  uuid;
begin
  if p_estado not in ('aceptada', 'rechazada', 'pendiente') then
    raise exception 'Eso no es una respuesta.' using errcode = 'P0001';
  end if;

  select * into v_fila from public.sesion_inscripciones where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'Esa petición ya no está.');
  end if;

  -- ESTO ES LO PRIMERO QUE HAY QUE DEMOSTRAR: quien no lleva la
  -- actividad no decide, y da igual que la petición sea suya.
  if not public.puede_decidir_sesion(v_fila.sesion_id) then
    raise exception 'Esta actividad no la llevas tú: no puedes contestar a sus peticiones.'
      using errcode = 'P0001';
  end if;

  select * into v_sesion from public.sesiones where id = v_fila.sesion_id;

  update public.sesion_inscripciones
     set estado       = p_estado,
         motivo       = case when p_estado = 'pendiente' then null else v_motivo end,
         decidida_en  = case when p_estado = 'pendiente' then null else now() end,
         decidida_por = case when p_estado = 'pendiente' then null else v_yo end
   where id = p_id;
  -- Si se pasa del tope, el control del punto 6 de la 131 corta aquí
  -- mismo y la respuesta no se guarda. Es a propósito: mejor un
  -- mensaje de «está completa» que once personas con plaza en diez
  -- sitios.

  -- El aviso a quien pidió la plaza. Envuelto, por lo de siempre:
  -- la decisión ya está tomada y no se deshace porque falle el buzón.
  if p_estado <> 'pendiente' then
    begin
      if p_estado = 'aceptada' then
        v_titulo := 'Tienes plaza';
        v_cuerpo := 'Te han dado plaza en «' || coalesce(nullif(btrim(v_sesion.titulo), ''), 'la actividad') ||
                    '» del ' || to_char(v_sesion.fecha, 'DD/MM') ||
                    coalesce('. ' || v_motivo, '');
      else
        v_titulo := 'No ha podido ser';
        -- El texto de por defecto no da un portazo: dice que fue esta
        -- vez y deja abierta la puerta de preguntar.
        v_cuerpo := 'Esta vez no ha salido la plaza en «' || coalesce(nullif(btrim(v_sesion.titulo), ''), 'la actividad') ||
                    '» del ' || to_char(v_sesion.fecha, 'DD/MM') || '. ' ||
                    coalesce(v_motivo, 'Habrá más días: pregunta a tu entrenador y buscamos otro.');
      end if;

      -- A su cuenta y a la de su familia. Un crío de catorce puede
      -- tardar tres días en abrir la app; su padre no.
      for v_perfil in
        select x from (
          select a.perfil_id as x from public.atletas a where a.id = v_fila.atleta_id
          union
          select a.perfil_padre_id from public.atletas a where a.id = v_fila.atleta_id
        ) t where x is not null
      loop
        perform public.avisos_registrar(
          v_titulo, v_cuerpo, 'portal/calendario/',
          'persona', 'entrenos',
          null, null, v_perfil,
          'Solo para ti',
          0, 0, v_yo, null, 'informativo', null, true, '{}'
        );

        -- Y el toque al móvil, a las dos cuentas igual. El texto que
        -- suena NO es este de arriba: en la pantalla de bloqueo va
        -- «Tienes plaza» o «No ha podido ser» y nada más, sin el
        -- nombre de la actividad ni el motivo. El detalle entero está
        -- aquí, en el buzón, para quien lo abra.
        perform public.avisos_cola_movil_poner(
          case when p_estado = 'aceptada' then 'plaza_si' else 'plaza_no' end,
          v_perfil
        );
      end loop;
    exception when others then
      null;
    end;
  end if;

  return jsonb_build_object('ok', true, 'estado', p_estado);
end;
$$;

comment on function public.sesion_solicitud_decidir(uuid, text, text) is
  'Aceptar, rechazar o volver a dejar pendiente una petición de plaza, y avisar a quien la pidió en el portal y en el móvil. Solo la puede llamar quien lleva la actividad.';

revoke all on function public.sesion_solicitud_decidir(uuid, text, text) from public, anon;
grant execute on function public.sesion_solicitud_decidir(uuid, text, text) to authenticated;

commit;
