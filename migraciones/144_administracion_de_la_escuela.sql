-- ============================================================
-- 144 · Administración de la escuela, y de nada más
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Quien lleva la escuela necesita mandar en la escuela, y hoy para
-- eso hay que hacerle administrador del club entero.
--
-- LO QUE ESO SIGNIFICA DE VERDAD
-- Un administrador ve los recibos de todas las familias, las cuotas,
-- los mandatos SEPA con el número de cuenta de cada socio, las fichas
-- de los adultos con su DNI y su teléfono, y puede repartir papeles
-- —incluido el suyo—. Todo eso, para poder apuntar a los niños que
-- entran en septiembre y pedir las camisetas.
--
-- LO QUE SE PIDIÓ, TAL CUAL SE DIJO
-- «Adriana puede ser admin entera pero no debería ver el dinero del
--  club (no es tesorera ni nada), lo de adultos tampoco, lo de escuela
--  sí y pedidos de ropa sí porque desde la escuela pedirán.»
--
-- LO QUE SE HACE AQUÍ
-- Un papel nuevo, `escuela`. Manda en las altas de la escuela, en los
-- niños de la escuela, en sus grupos y sus listas, en el contenido de
-- la web y en los pedidos de ropa. Y en nada más.
--
-- ------------------------------------------------------------
-- POR QUÉ SE AÑADEN REGLAS EN VEZ DE TOCAR LAS QUE HAY
-- ------------------------------------------------------------
-- Hay NOVENTA Y SIETE reglas de acceso que preguntan `es_admin()`.
-- Había dos caminos:
--
--   1 · Que `es_admin()` dijera que sí también para `escuela`. Una
--       línea, y se abren las noventa y siete de golpe: recibos,
--       mandatos SEPA y fichas de adultos incluidos. Un cambio de
--       una línea que regala el club entero, y que además nadie
--       vería al leer el diff.
--   2 · Escribir una regla NUEVA por cada cosa que sí puede tocar.
--       Es más largo y es lo que se hace aquí.
--
-- Cada regla que se añade se llama «escuela …». Ninguna de las que ya
-- había se modifica ni se borra: si mañana este papel se quiere
-- retirar, se tiran las reglas que empiezan por «escuela » y el club
-- se queda exactamente como estaba.
--
-- ------------------------------------------------------------
-- ⚠️ DOS COSAS QUE HAY QUE SABER ANTES DE PONERLE ESTE PAPEL A NADIE
-- ------------------------------------------------------------
-- 1 · LAS REGLAS DE ACCESO DAN FILAS ENTERAS, NO COLUMNAS.
--     La ficha de un niño lleva su cuota mensual en la misma fila que
--     su nombre. No hay forma de escribir «todo menos la cuota» en una
--     regla de acceso. Así que quien lleve la escuela VE la cuota de
--     los niños de la escuela — no la de nadie más, y ningún recibo,
--     ningún pago y ningún número de cuenta—. Lo que sí se cierra es
--     TOCARLA: el apartado 6 devuelve la cuota a su valor anterior si
--     la escribe este papel. Fijar cuotas es de tesorería.
--
-- 2 · QUÉ ES «UN NIÑO DE LA ESCUELA».
--     `atletas` no tiene columna de sección: se sabe por el GRUPO en
--     el que entrena. Así que un atleta sin grupo no es de nadie, y
--     este papel no lo ve. Es a propósito: si «sin grupo» contara
--     como escuela, cualquier adulto recién dado de alta y todavía sin
--     asignar aparecería en su lista.
--
-- ⚠️ NINGÚN DATO PERSONAL SE ESCRIBE EN ESTE ARCHIVO. Este repositorio
--    es PÚBLICO. Aquí va el molde; a quién se le pone el papel se
--    decide desde el panel.
--
-- Idempotente: se puede relanzar sin romper nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/144_administracion_de_la_escuela.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · QUE EL PAPEL EXISTA
-- ------------------------------------------------------------
-- Dos listas y no una, igual que en la 109: `rol` es el papel de
-- siempre y `roles` son todos los sombreros que puede ponerse. Solo se
-- AÑADE un valor a listas que ya existían, así que ninguna fila
-- guardada deja de cumplir la condición.
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles add constraint perfiles_rol_check
  check (rol in ('admin','coordinador','entrenador','atleta','padre',
                 'tesoreria','contabilidad','junta','cubo','escuela'));

alter table public.perfiles drop constraint if exists perfiles_roles_check;
alter table public.perfiles add constraint perfiles_roles_check
  check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre',
                                         'tesoreria','contabilidad','junta','cubo','escuela']);

-- ------------------------------------------------------------
-- 2 · LAS TRES FUNCIONES QUE LO DECIDEN TODO
-- ------------------------------------------------------------
-- SECURITY DEFINER, y no se toca: la función tiene que poder mirar
-- `perfiles` para saber quién eres, y quien pregunta no puede leer esa
-- tabla. Ya se rompió el guardado dos veces por perder este renglón
-- (migraciones 090 y 106).
--
-- `coalesce(rol_activo, rol)`: manda el sombrero PUESTO, no el que se
-- tiene guardado. Es el criterio de toda la casa. Y `activo`, para que
-- a quien se da de baja deje de mandar el mismo día.
create or replace function public.es_escuela()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and coalesce(p.activo, true)
      and coalesce(p.rol_activo, p.rol) = 'escuela'
  );
$$;

comment on function public.es_escuela() is
  'Quién lleva la escuela. NO es administración del club: no ve dinero, ni adultos, ni reparte papeles. Ver la migración 144 para la lista entera de lo que abre y lo que no.';

-- Qué secciones son «la escuela». Está en una función y no repetido en
-- veinte reglas porque el día que se abra «escuela-triatlón» hay que
-- poder añadirla en un sitio y no en veinte.
create or replace function public.escuela_secciones()
returns text[]
language sql
immutable
as $$
  select array['escuela','escuela-natacion'];
$$;

comment on function public.escuela_secciones() is
  'Las secciones que cuentan como escuela. Si se abre una nueva, se añade AQUÍ y todas las reglas de la migración 144 la reconocen solas.';

-- ¿Este atleta es un niño de la escuela? Lo es si entrena en algún
-- grupo de una sección de escuela. Un atleta SIN grupo no lo es: ver
-- el aviso 2 de la cabecera.
create or replace function public.escuela_lleva_atleta(p_atleta uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.grupos g
     where g.id in (select public.grupos_del_atleta(p_atleta))
       and g.seccion = any(public.escuela_secciones())
  );
$$;

comment on function public.escuela_lleva_atleta(uuid) is
  'Si ese atleta entrena en algún grupo de la escuela. Es lo que separa a los niños de los adultos para el papel `escuela`; un atleta sin grupo no cuenta.';

-- ------------------------------------------------------------
-- 3 · LAS ALTAS DE LA ESCUELA · su trabajo principal
-- ------------------------------------------------------------
-- Las cuatro tablas del alta de septiembre. Aquí sí manda entera: es
-- literalmente lo que se le encarga.
drop policy if exists "escuela gestiona las altas" on public.altas_escuela;
create policy "escuela gestiona las altas" on public.altas_escuela
  for all using (public.es_escuela()) with check (public.es_escuela());

drop policy if exists "escuela gestiona los ninos del alta" on public.altas_escuela_ninos;
create policy "escuela gestiona los ninos del alta" on public.altas_escuela_ninos
  for all using (public.es_escuela()) with check (public.es_escuela());

-- El rastro de quién ha mirado los datos de un alta. Solo lectura, y a
-- propósito: es un registro de accesos, y un registro de accesos que
-- puede borrar quien accede no sirve para nada.
drop policy if exists "escuela lee quien ha mirado" on public.altas_datos_vistos;
create policy "escuela lee quien ha mirado" on public.altas_datos_vistos
  for select using (public.es_escuela());

drop policy if exists "escuela gestiona el historico" on public.escuela_historico;
create policy "escuela gestiona el historico" on public.escuela_historico
  for all using (public.es_escuela()) with check (public.es_escuela());

-- Quien pregunta por una plaza. No tiene sección —es un formulario de
-- la web—, así que o se ve entero o no se ve. Se ve: contestar a las
-- familias que preguntan por la escuela es su trabajo, y ahí no hay
-- ningún dato de socio, solo el de quien escribe.
drop policy if exists "escuela atiende solicitudes" on public.solicitudes_inscripcion;
create policy "escuela atiende solicitudes" on public.solicitudes_inscripcion
  for all using (public.es_escuela()) with check (public.es_escuela());

-- ------------------------------------------------------------
-- 4 · LOS NIÑOS, SUS GRUPOS Y SUS LISTAS
-- ------------------------------------------------------------
-- Aquí está la línea que separa este papel de un administrador: cada
-- regla lleva su `escuela_lleva_atleta(...)` o su sección. Los adultos
-- no salen por ninguna.

-- 4.a · LAS FICHAS
-- Leer, corregir y borrar: solo niños de la escuela.
drop policy if exists "escuela ve a sus ninos" on public.atletas;
create policy "escuela ve a sus ninos" on public.atletas
  for select using (public.es_escuela() and public.escuela_lleva_atleta(id));

/* ⚠️ EL `with check` NO PUEDE SER IGUAL QUE EL `using`, Y ESTO SE
   DESCUBRIÓ PROBÁNDOLO. Con los dos iguales, quien lleva la escuela
   podía cambiarle el grupo a un niño y sacarlo a un grupo de adultos: la
   condición pregunta `escuela_lleva_atleta(id)`, que mira `atleta_grupos`,
   y esa tabla la actualiza un disparador que corre DESPUÉS
   (`trg_atleta_grupos_desde_la_ficha`). O sea que en el momento de
   comprobar, el niño seguía figurando en su grupo viejo y la condición
   daba que sí. La fila pasaba y el niño acababa en competición —con el
   recibo que eso trae—.
   Así que además se mira el grupo que se le está poniendo. Se admite
   dejarlo sin grupo (hay altas a medias que están así), pero no
   mandarlo a una sección que no es suya. */
drop policy if exists "escuela corrige a sus ninos" on public.atletas;
create policy "escuela corrige a sus ninos" on public.atletas
  for update using (public.es_escuela() and public.escuela_lleva_atleta(id))
          with check (
            public.es_escuela()
            and public.escuela_lleva_atleta(id)
            and (grupo_id is null or exists (
                  select 1 from public.grupos g
                   where g.id = atletas.grupo_id
                     and g.seccion = any(public.escuela_secciones())))
          );

drop policy if exists "escuela borra a sus ninos" on public.atletas;
create policy "escuela borra a sus ninos" on public.atletas
  for delete using (public.es_escuela() and public.escuela_lleva_atleta(id));

/* Dar de alta a un niño. Aquí NO se puede pedir `escuela_lleva_atleta`
   —la ficha todavía no existe, así que no está en ningún grupo—, y por
   eso la condición mira el grupo que se le está poniendo: si es de la
   escuela, pasa. Sin grupo NO pasa, y es a propósito: una ficha sin
   grupo la crea y luego ni ella misma la puede volver a leer, y se
   quedaría una ficha huérfana que solo ve administración. */
drop policy if exists "escuela da de alta a un nino" on public.atletas;
create policy "escuela da de alta a un nino" on public.atletas
  for insert with check (
    public.es_escuela()
    and grupo_id is not null
    and exists (select 1 from public.grupos g
                 where g.id = grupo_id
                   and g.seccion = any(public.escuela_secciones()))
  );

-- 4.b · LOS GRUPOS DE LA ESCUELA y sus horarios
drop policy if exists "escuela gestiona sus grupos" on public.grupos;
create policy "escuela gestiona sus grupos" on public.grupos
  for all using (public.es_escuela() and seccion = any(public.escuela_secciones()))
          with check (public.es_escuela() and seccion = any(public.escuela_secciones()));

drop policy if exists "escuela gestiona sus horarios" on public.grupo_horarios;
create policy "escuela gestiona sus horarios" on public.grupo_horarios
  for all using (public.es_escuela() and exists (
        select 1 from public.grupos g where g.id = grupo_horarios.grupo_id
           and g.seccion = any(public.escuela_secciones())))
      with check (public.es_escuela() and exists (
        select 1 from public.grupos g where g.id = grupo_horarios.grupo_id
           and g.seccion = any(public.escuela_secciones())));

-- 4.c · REPARTIR NIÑOS ENTRE GRUPOS
-- La condición es sobre el GRUPO y no sobre el atleta: así no se puede
-- meter a un adulto en un grupo de la escuela para acabar viéndolo.
drop policy if exists "escuela reparte a sus ninos" on public.atleta_grupos;
create policy "escuela reparte a sus ninos" on public.atleta_grupos
  for all using (public.es_escuela() and exists (
        select 1 from public.grupos g where g.id = atleta_grupos.grupo_id
           and g.seccion = any(public.escuela_secciones())))
      with check (public.es_escuela() and exists (
        select 1 from public.grupos g where g.id = atleta_grupos.grupo_id
           and g.seccion = any(public.escuela_secciones())));

-- 4.d · LISTAS Y FALTAS
-- Quién vino y quién avisó de que no venía. Es lo que hay que contestar
-- cuando llama un padre, y por eso entra.
drop policy if exists "escuela pasa lista a sus ninos" on public.asistencia;
create policy "escuela pasa lista a sus ninos" on public.asistencia
  for all using (public.es_escuela() and public.escuela_lleva_atleta(atleta_id))
      with check (public.es_escuela() and public.escuela_lleva_atleta(atleta_id));

drop policy if exists "escuela ve las faltas de sus ninos" on public.ausencias;
create policy "escuela ve las faltas de sus ninos" on public.ausencias
  for all using (public.es_escuela() and public.escuela_lleva_atleta(atleta_id))
      with check (public.es_escuela() and public.escuela_lleva_atleta(atleta_id));

-- ------------------------------------------------------------
-- 5 · LOS PEDIDOS DE ROPA
-- ------------------------------------------------------------
-- «Pedidos de ropa sí porque desde la escuela pedirán.» Aquí manda
-- entero y no solo en lo de la escuela: un pedido no tiene sección, y
-- partir la ropa en dos mitades dejaría medio pedido sin nadie que lo
-- cierre.
--
-- OJO A LO QUE ESTO SÍ ES: un pedido lleva importe. Pero es el precio
-- de una camiseta, no la contabilidad del club — es exactamente lo que
-- se le encarga cobrar y entregar. Los recibos de las cuotas, los
-- pagos, las renovaciones y los mandatos SEPA siguen cerrados.
drop policy if exists "escuela gestiona los pedidos" on public.pedidos;
create policy "escuela gestiona los pedidos" on public.pedidos
  for all using (public.es_escuela()) with check (public.es_escuela());

drop policy if exists "escuela gestiona las lineas del pedido" on public.pedido_items;
create policy "escuela gestiona las lineas del pedido" on public.pedido_items
  for all using (public.es_escuela()) with check (public.es_escuela());

drop policy if exists "escuela gestiona el catalogo" on public.productos;
create policy "escuela gestiona el catalogo" on public.productos
  for all using (public.es_escuela()) with check (public.es_escuela());

-- ------------------------------------------------------------
-- 6 · LA CUOTA DE UN NIÑO SE VE, PERO NO SE TOCA
-- ------------------------------------------------------------
-- Ver el aviso 1 de la cabecera: la regla de acceso da la fila entera y
-- la cuota va en esa fila. Lo que sí se puede cerrar es escribirla, y
-- se cierra: si quien modifica la ficha lleva puesto el papel `escuela`
-- —y no es además administración ni tesorería—, las cinco columnas de
-- la cuota vuelven a su valor anterior. Escribe, y no cambia nada.
--
-- Es el mismo mecanismo que `perfiles_protege_rol` (migración 041), y
-- por el mismo motivo: hay cosas que no se arreglan diciendo «no lo
-- hagas», se arreglan haciendo que no pase.
create or replace function public.atletas_escuela_no_toca_cuota()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Quien de verdad manda en el dinero pasa de largo.
  if public.es_admin() or public.es_tesoreria() or public.es_contabilidad() then
    return new;
  end if;
  if public.es_escuela() then
    new.cuota_mensual   := old.cuota_mensual;
    new.cuota_nota      := old.cuota_nota;
    new.cuota_fijada_por := old.cuota_fijada_por;
    new.cuota_fijada_en  := old.cuota_fijada_en;
    new.tipo_membresia  := old.tipo_membresia;
  end if;
  return new;
end;
$$;

comment on function public.atletas_escuela_no_toca_cuota() is
  'Quien lleva la escuela puede corregir la ficha de un niño, pero no su cuota ni su tipo de membresía: eso es de tesorería. Migración 144.';

drop trigger if exists trg_atletas_escuela_no_toca_cuota on public.atletas;
create trigger trg_atletas_escuela_no_toca_cuota
  before update on public.atletas
  for each row execute function public.atletas_escuela_no_toca_cuota();

-- ------------------------------------------------------------
-- 6 bis · Y QUE EL GUARDIÁN DE LA FICHA LA DEJE PASAR
-- ------------------------------------------------------------
-- ⚠️ SIN ESTO, TODO EL APARTADO 4 NO SIRVE DE NADA, y no se ve al leer
--    las reglas de acceso: está en un disparador.
--
-- `atletas_cambios_del_entrenador()` (migración 130) no es una lista de
-- lo prohibido: es una lista de lo PERMITIDO. Quien no sea
-- administración ni tesorería solo puede tocar diecisiete columnas —las
-- que se deciden en la pista: grupo, días, lesión, observaciones— y
-- cualquier otra levanta un error. Quien lleva la escuela caía en ese
-- saco: podía leer la ficha del niño y no podía corregirle ni el
-- apellido, con un mensaje que además habla de entrenadores.
--
-- Así que pasa de largo, igual que tesorería. Y lo que NO puede tocar
-- —la cuota— lo cierra el disparador de arriba, que se ejecuta después
-- (`atletas_cambios_entrenador_trg` va antes por orden alfabético) y
-- devuelve esas cinco columnas a su valor anterior sin decir nada.
--
-- Lo demás del disparador se copia tal cual de la 130. Si algún día se
-- toca allí, hay que acordarse de este archivo.
create or replace function public.atletas_cambios_del_entrenador()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  permitidas text[] := array[
    'grupo_id', 'dias_entreno', 'hace_gym', 'tiene_fisio', 'dia_fisio',
    'especialidades', 'pruebas_principales', 'pruebas_secundarias',
    'perfil_velocista', 'pierna_ataque', 'pasos_entre_vallas',
    'estado', 'fecha_prueba_fin',
    'observaciones', 'contexto_entrenador',
    'updated_at'
  ];
  viejo jsonb := to_jsonb(old);
  nuevo jsonb := to_jsonb(new);
  c text;
  cambiadas text[];
begin
  new.updated_at := now();

  -- Quién pasa de largo: las tareas del propio sistema (sin sesión),
  -- administración, tesorería/contabilidad… y desde la 144 quien lleva
  -- la escuela, que administra las fichas de los niños. La cuota se la
  -- cierra `atletas_escuela_no_toca_cuota()`, no esta lista.
  if (auth.jwt() ->> 'email') is null
     or public.es_admin()
     or public.ve_dinero()
     or public.es_escuela() then
    return new;
  end if;

  foreach c in array permitidas loop
    viejo := viejo - c;
    nuevo := nuevo - c;
  end loop;

  select array_agg(k order by k) into cambiadas
    from jsonb_object_keys(nuevo) k
   where (nuevo -> k) is distinct from (viejo -> k);

  if cambiadas is not null then
    raise exception
      'Esto de la ficha no lo lleva el entrenador: %. Lo cambia administración; si hay que corregirlo, avisa al club.',
      array_to_string(cambiadas, ', ');
  end if;

  if new.grupo_id is distinct from old.grupo_id and new.grupo_id is not null then
    if not exists (select 1 from public.grupos g
                    where g.id = new.grupo_id and g.entrenador_id = public.mi_perfil_id()) then
      raise exception 'Solo puedes mover al atleta a un grupo que dirijas tú. Para pasarlo a otro entrenador, avisa a administración.';
    end if;
  end if;

  return new;
end; $function$;

-- ------------------------------------------------------------
-- 7 · QUE EL PAPEL SE PUEDA REPARTIR DESDE EL PANEL
-- ------------------------------------------------------------
-- `perfil_roles_poner` lleva su propia lista de papeles válidos, y si
-- no se añade aquí el panel contesta «hay algún papel que no existe».
--
-- ⚠️ Y DE PASO SE ARREGLA `cubo`, QUE LLEVA SIN PODER REPARTIRSE DESDE
--    LA MIGRACIÓN 109. El papel existe, las reglas lo reconocen, pero
--    esta función lo rechazaba: se creó en la 071 y nadie volvió por
--    aquí al añadirlo. O sea que el papel de El Cubo solo se podía
--    poner a mano, contra la base.
--
-- Las áreas (`v_areas`) no se tocan para el papel nuevo: `areas` es el
-- reparto de las pantallas de DINERO, y este papel no entra ahí.
create or replace function public.perfil_roles_poner(p_perfil uuid, p_roles text[])
returns text[]
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_areas text[]; v_rol text;
begin
  if not public.es_admin() then
    raise exception 'Repartir papeles es cosa de administración.';
  end if;
  if p_roles is null or array_length(p_roles, 1) is null then
    raise exception 'Hay que dejarle al menos un papel.';
  end if;
  if not (p_roles <@ array['admin','coordinador','entrenador','atleta','padre',
                           'tesoreria','contabilidad','junta','cubo','escuela']::text[]) then
    raise exception 'Hay algún papel que no existe.';
  end if;

  select rol into v_rol from public.perfiles where id = p_perfil;
  if v_rol is null then raise exception 'Esa persona no existe.'; end if;

  v_areas := case
    when 'admin'        = any(p_roles) then array['personas','dinero','web','liga','club']
    when 'tesoreria'    = any(p_roles) then array['personas','dinero','web','liga','club']
    when 'contabilidad' = any(p_roles) then array['dinero']
    when 'junta'        = any(p_roles) then array['personas','web','liga','club']
    else null
  end;

  update public.perfiles
     set roles = p_roles,
         areas = coalesce(v_areas, areas)
   where id = p_perfil;

  return p_roles;
end;
$function$;

/* Los permisos de la función, tal y como los dejó la 071: se le quitan a
   todo el mundo y se le devuelven SOLO a quien tiene sesión abierta. El
   portero de verdad es el `es_admin()` de la primera línea del cuerpo.

   ⚠️ EL `grant` DE ABAJO NO SOBRA. `create or replace` conserva los
   permisos de la función que había, así que un `revoke` suelto se los
   quita y no se los devuelve nadie: el panel llamaría a la función y la
   base contestaría «permiso denegado» al repartir papeles. Las dos
   líneas van juntas o no va ninguna. */
revoke all on function public.perfil_roles_poner(uuid, text[]) from public, anon, authenticated;
grant execute on function public.perfil_roles_poner(uuid, text[]) to authenticated;

-- ------------------------------------------------------------
-- 8 · QUIÉN PUEDE PREGUNTAR
-- ------------------------------------------------------------
-- Las tres funciones nuevas las llaman las reglas de acceso (que van por
-- dentro) y también el panel, desde el navegador: `admin-auth.js`
-- pregunta `es_escuela()` para abrir la puerta. Sin esto, esa llamada
-- devuelve «permiso denegado» y quien lleva la escuela se queda fuera.
--
-- A `authenticated` y NO a `anon`: hay que tener cuenta y sesión.
grant execute on function public.es_escuela()                  to authenticated;
grant execute on function public.escuela_secciones()           to authenticated;
grant execute on function public.escuela_lleva_atleta(uuid)    to authenticated;

commit;

-- ============================================================
-- LO QUE ESTE PAPEL **NO** PUEDE HACER
-- ------------------------------------------------------------
-- Repasado tabla por tabla. `escuela` no aparece en ninguna de estas y
-- ninguna función suya lo reconoce:
--
--   · DINERO. `ve_dinero()`, `es_tesoreria()`, `es_contabilidad()` y
--     `es_junta()` comparan el papel con un valor exacto, así que
--     `escuela` no entra por ninguna. Recibos, pagos, cuotas del club,
--     renovaciones, Stripe y los MANDATOS SEPA —con el número de
--     cuenta de cada familia— siguen cerrados.
--   · ADULTOS. Las fichas de quien no entrena en un grupo de la
--     escuela no salen por ninguna regla suya.
--   · REPARTIR PAPELES. `perfil_roles_poner` exige `es_admin()`, y los
--     tres candados de `perfiles` (migraciones 041, 102 y 109) siguen
--     donde estaban: no puede ascenderse ni ascender a nadie.
--   · EQUIPO TÉCNICO. NO se ha tocado `es_staff()`, que es la llave de
--     cuarenta y una reglas (tests, medallas, retos, la liga, las
--     plantillas de correo, el buzón…). Meter `escuela` ahí habría
--     sido cómodo y habría regalado medio club.
--   · EL CUBO, LA LIGA, LAS COMPETICIONES y las marcas.
--   · EL CUADERNO DE LOS ENTRENADORES. `notas_atleta` —lo que el
--     equipo técnico escribe sobre un menor— y `notas_familia` no
--     entran. Tampoco el buzón ni los mensajes.
--   · LA WEB PÚBLICA. Noticias, eventos, imágenes y documentos NO
--     entran todavía. Se dejan fuera a posta: publicar en nombre del
--     club es otra decisión y se pide aparte. Si hace falta, son cinco
--     reglas más y se añaden en otra migración.
--
-- ------------------------------------------------------------
-- LO QUE SE PROBÓ ANTES DE SUBIRLO
-- ------------------------------------------------------------
-- Contra la base de verdad, dentro de una transacción que se deshace al
-- final, con un perfil de prueba con este papel puesto:
--
--   · De 208 atletas ve 44, y son exactamente los 44 que entrenan en un
--     grupo de escuela. Ni uno más.
--   · Cero filas en pagos, mandatos SEPA, renovaciones, notas del
--     entrenador, notas para la familia, mensajes, bonos de El Cubo y
--     marcas. De `perfiles`, una: la suya.
--   · `es_admin()`, `es_staff()`, `ve_dinero()` y `cubo_es_gestor()`
--     contestan que no.
--   · Le pone 999 a la cuota de un niño y la cuota se queda en 30.
--   · Le corrige el nombre y el teléfono del tutor: sí.
--   · Da de alta a un niño en un grupo de escuela: sí. En uno de
--     competición: rechazado.
--   · Mueve a un niño a otro grupo de escuela: sí. A competición:
--     rechazado (era el agujero que encontró la prueba B).
--   · Crea un grupo de escuela: sí. Uno de competición: rechazado.
--   · Y lo de siempre sigue igual: un entrenador cambia observaciones y
--     no la cuota; administración sí cambia la cuota.
--
-- CÓMO SE QUITA TODO ESTO, SI SE QUIERE
--   delete de las políticas cuyo nombre empieza por 'escuela ' en
--   public, más el trigger del apartado 6. Nada de lo que ya había se
--   ha modificado, así que el club vuelve a estar como estaba.
-- ============================================================
