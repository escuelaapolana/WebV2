-- ============================================================
-- 109 · Un administrador para El Cubo, y para nada más
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Hoy, para que alguien lleve las reservas de El Cubo hay que
-- hacerle administrador del club entero.
--
-- LO QUE ESO SIGNIFICA DE VERDAD
-- Un administrador ve los recibos sin cobrar de todas las familias,
-- los teléfonos de los socios y de sus padres, los DNI, las cuotas
-- de cada uno y las observaciones que los entrenadores escriben
-- sobre los menores. Todo eso, para poder apuntar quién viene a
-- hacer pesas y venderle un bono de diez usos.
--
-- LO QUE SE HACE AQUÍ
-- Se crea un papel nuevo, `cubo`, que manda en TODO lo de El Cubo
-- —clases, plazas, reservas y bonos, que son dinero— y en nada más
-- del club.
--
-- POR QUÉ ES UN ARCHIVO CORTO PARA LO QUE PARECE
-- Casi todo estaba ya montado. Las cuatro tablas de El Cubo
-- (`cubo_clases`, `cubo_reservas`, `cubo_bonos`, `cubo_movimientos`)
-- ya tienen cada una su regla «el gestor de El Cubo puede con esto»,
-- y todas preguntan a la misma función: `cubo_es_gestor()`. O sea
-- que no hay que tocar ni una regla: en cuanto esa función reconozca
-- el papel nuevo, el mando sobre El Cubo llega solo, entero y por el
-- mismo camino que ya usan los monitores.
--
-- Lo único que había que pensar de verdad es el apartado 3:
-- a qué PERSONAS puede ver, que es donde estaba el peligro.
--
-- ⚠️ NINGÚN DATO PERSONAL SE ESCRIBE EN ESTE ARCHIVO
--   Ni un nombre, ni un correo, ni un teléfono. Este repositorio es
--   PÚBLICO y las migraciones quedan en el histórico de Git para
--   siempre. Aquí va el molde; a quién se le pone el papel se decide
--   desde el panel, no desde aquí.
--
-- Idempotente: se puede relanzar sin romper nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/109_admin_del_cubo.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · QUE EL PAPEL EXISTA
-- ------------------------------------------------------------
-- Son dos listas y no una por un motivo: `rol` es el papel de
-- siempre de esa persona, y `roles` son todos los sombreros que
-- puede ponerse (migración 102). Alguien puede ser entrenador de
-- pista de lunes a viernes y llevar El Cubo los sábados, así que el
-- papel tiene que valer en las dos.
--
-- Solo se AÑADE un valor a una lista que ya existía: ninguna fila
-- guardada deja de cumplir la condición, así que esto no puede
-- fallar por los datos que ya hay.
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles add constraint perfiles_rol_check
  check (rol in ('admin','coordinador','entrenador','atleta','padre',
                 'tesoreria','contabilidad','junta','cubo'));

alter table public.perfiles drop constraint if exists perfiles_roles_check;
alter table public.perfiles add constraint perfiles_roles_check
  check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre',
                                         'tesoreria','contabilidad','junta','cubo']);

-- ------------------------------------------------------------
-- 2 · QUE `cubo_es_gestor()` LO RECONOZCA
-- ------------------------------------------------------------
-- Se le añade una tercera razón para mandar en El Cubo, además de
-- las dos que ya había (ser administrador del club, o ser el
-- entrenador/monitor que da las clases).
--
-- Ojo al `coalesce(rol_activo, rol)`: manda quien lleva el sombrero
-- PUESTO, no quien lo tiene guardado en el armario. Es el mismo
-- criterio que usan `es_admin()`, `es_tesoreria()` y todas las
-- demás, y es a propósito: si alguien se cambia a «atleta» para
-- mirar sus entrenamientos, mientras tanto no está administrando
-- El Cubo. La casa entera funciona así.
--
-- Se aprovecha para exigir además que la persona esté de alta
-- (`activo`), como ya hacen `es_tesoreria()` y `es_junta()`. Eso
-- CIERRA, no abre: a quien se le da de baja deja de mandar el mismo
-- día, sin tener que acordarse de quitarle nada más.
--
-- SECURITY DEFINER, y no se toca: la función tiene que poder mirar
-- la tabla `perfiles` para saber quién eres, y quien pregunta no
-- puede leer esa tabla. Ya se rompió el guardado una vez por perder
-- este renglón (migraciones 090 y 106). No quitarlo.
create or replace function public.cubo_es_gestor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.es_admin() or exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and coalesce(p.activo, true)
      and (
        -- El papel nuevo: administrador de El Cubo.
        coalesce(p.rol_activo, p.rol) = 'cubo'
        -- Quien entrena un grupo de la sección Cubo.
        or exists (select 1 from public.grupos g
                    where g.seccion = 'cubo' and g.entrenador_id = p.id)
        -- Quien está puesto de monitor en alguna clase de El Cubo.
        or exists (select 1 from public.cubo_clases c
                    where c.monitor_id = p.id)
      )
  );
$$;

comment on function public.cubo_es_gestor() is
  'Quién manda en El Cubo: administración del club, el papel `cubo`, quien entrena un grupo de esa sección o quien está de monitor en una clase. Es la única puerta de las cuatro tablas de El Cubo; el papel `cubo` no abre NADA más del club.';

-- ------------------------------------------------------------
-- 3 · A QUÉ PERSONAS PUEDE VER · LA PARTE DELICADA
-- ------------------------------------------------------------
-- EL LÍO
-- Para apuntar a alguien a una clase o venderle un bono hay que
-- poder buscarlo por su nombre. Pero las fichas de los atletas
-- guardan, en la misma tabla y en la misma fila: teléfono, correo,
-- DNI, teléfono del padre o de la madre, cuota mensual, si tiene
-- fisio, si está lesionado y las observaciones que escribe el
-- entrenador. Cuarenta y dos columnas.
--
-- POR QUÉ NO SIRVE UNA «REGLA DE ACCESO» NORMAL
-- Las reglas de acceso de la base (RLS) deciden QUÉ FILAS puede
-- leer cada uno, pero no qué columnas. Una regla que diga «el
-- gestor de El Cubo puede leer las fichas» le da la fila ENTERA:
-- el teléfono y la cuota incluidos. No hay forma de escribir «solo
-- el nombre» en una regla de acceso.
--
-- LA SOLUCIÓN: UNA VENTANA, NO UNA PUERTA
-- Se crean dos vistas. Una vista es una consulta con nombre: la
-- base la trata como si fuera una tabla, pero solo devuelve las
-- columnas que se le escriben aquí. El resto no es que esté tapado:
-- es que no sale de la base de datos. Aunque alguien se ponga a
-- probar a mano desde el navegador —y puede, la clave pública está
-- a la vista de cualquiera— por esta ventana no salen teléfonos,
-- porque la ventana no tiene teléfonos.
--
-- Es el mismo apaño que `contactos_publicos` (migración 085), que
-- es lo que lee la web pública en vez de la tabla de contactos.
--
-- EL PORTERO ESTÁ DENTRO DE LA VISTA
-- El `where public.cubo_es_gestor()` del final no es un adorno: si
-- quien pregunta no manda en El Cubo, la vista no devuelve ninguna
-- fila. Ni una. Así que esto no le abre la lista de socios a nadie
-- que no la tuviera ya.
-- ------------------------------------------------------------

-- 3.a · LAS PERSONAS A LAS QUE PUEDE APUNTAR
-- Nombre y apellidos, y el identificador para poder apuntarlas.
-- Nada más. Salen todas y no solo las de alta a propósito: en la
-- lista de una clase de hace tres meses también tienen que poder
-- leerse los nombres de quien vino, y si alguien desaparece de la
-- lista esa clase pasada se queda llena de «(atleta)».
drop view if exists public.cubo_personas;
create view public.cubo_personas as
  select a.id,
         a.nombre,
         a.apellidos
    from public.atletas a
   where public.cubo_es_gestor();

comment on view public.cubo_personas is
  'La agenda de El Cubo: el nombre de cada atleta y nada más, para poder buscarlo y apuntarlo a una clase. Sin teléfono, sin correo, sin DNI, sin cuota, sin observaciones. Solo devuelve filas a quien manda en El Cubo.';

-- Vista curada a propósito (SECURITY DEFINER, igual que
-- `contactos_publicos`): enseña solo lo que se puede enseñar, y
-- quién puede mirarla lo decide su propio `where`.
alter view public.cubo_personas set (security_invoker = false);

revoke all on public.cubo_personas from public;
-- A `authenticated` y NO a `anon`: hay que tener cuenta y sesión
-- abierta. Un visitante de la web no llega ni a preguntar.
grant select on public.cubo_personas to authenticated;

-- 3.b · QUIÉN PUEDE FIGURAR COMO MONITOR DE UNA CLASE
-- La pantalla de El Cubo tiene un desplegable «monitor con cuenta
-- en la app». Se resuelve por el mismo camino y por el mismo
-- motivo: los perfiles del equipo técnico también guardan correo y
-- teléfono, y para escribir quién da la clase basta el nombre.
--
-- Se deja fuera a los atletas y a los padres: en ese desplegable no
-- pintan nada, y así son doce nombres y no doscientos.
drop view if exists public.cubo_monitores;
create view public.cubo_monitores as
  select p.id,
         p.nombre,
         p.apellidos,
         coalesce(p.rol_activo, p.rol) as rol
    from public.perfiles p
   where coalesce(p.activo, true)
     and coalesce(p.rol_activo, p.rol) in ('admin','coordinador','entrenador','cubo')
     and public.cubo_es_gestor();

comment on view public.cubo_monitores is
  'Quién puede figurar como monitor de una clase de El Cubo: nombre y papel del equipo técnico, sin correo ni teléfono. Solo devuelve filas a quien manda en El Cubo.';

alter view public.cubo_monitores set (security_invoker = false);

revoke all on public.cubo_monitores from public;
grant select on public.cubo_monitores to authenticated;

-- ------------------------------------------------------------
-- 4 · QUE NO PUEDA ASCENDERSE SOLO
-- ------------------------------------------------------------
-- Lo primero que probaría cualquiera con este papel es escribirse
-- «admin» en su propia ficha. Hay tres candados y ninguno se toca:
--
--   · `perfiles_protege_rol` (migración 041): al modificar una
--     ficha, si no eres administración se te devuelven a su valor
--     de antes el papel, el correo, la sección y el alta. Escribes,
--     pero no cambia nada.
--   · `perfiles_protege_roles` (migración 102): los sombreros los
--     concede administración. Puedes ELEGIR cuál llevas puesto,
--     pero solo de entre los que ya te dieron.
--   · Las reglas de acceso de `perfiles`: solo puedes modificar tu
--     propia ficha. La del vecino no.
--
-- LO QUE SÍ FALTABA, Y SE ARREGLA AQUÍ
-- Los dos primeros candados vigilan bien los CAMBIOS de ficha, pero
-- el segundo era blando al DAR DE ALTA una ficha nueva: recortaba
-- los sombreros, y en cambio dejaba pasar el papel principal tal y
-- como venía escrito. O sea que quien pudiera colar una ficha nueva
-- a su nombre, podía nacer administrador.
--
-- Hoy eso no llega a pasar, pero por casualidad y no por norma: las
-- fichas las crea sola la base cuando alguien se registra, con el
-- mismo identificador que su cuenta, así que una segunda ficha
-- choca con la primera y la base la rechaza. Es un choque de
-- identificadores lo que nos está salvando, no una regla. El día
-- que alguien tenga cuenta y no ficha —una importación a medias, un
-- borrado, un enganche que falló— ese hueco se abre.
--
-- Así que ahora se dice en voz alta: dándote de alta tú mismo,
-- naces atleta o padre. Los papeles con mando los reparte
-- administración, uno por uno, desde el panel.
--
-- SECURITY DEFINER, y no se toca (mismo motivo que en el apartado 2).
create or replace function public.perfiles_protege_roles()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- La propia base creando la ficha al registrarse alguien, o
  -- administración repartiendo papeles: eso sí puede.
  if auth.uid() is null or public.es_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- Nadie se da de alta con papeles puestos por él mismo.
    if new.rol is distinct from 'atleta' and new.rol is distinct from 'padre' then
      new.rol := 'atleta';
    end if;
    new.roles := array[new.rol];
    new.rol_activo := null;
    new.papel_al_entrar := null;
    return new;
  end if;

  -- Conceder es de administración.
  new.roles := old.roles;

  -- Elegir, sí; pero solo entre los suyos. Vale para el papel activo y
  -- para el que se abre al entrar.
  if new.rol_activo is distinct from old.rol_activo
     and new.rol_activo is not null
     and not (new.rol_activo = any(coalesce(old.roles, array[old.rol]))) then
    new.rol_activo := old.rol_activo;
  end if;
  if new.papel_al_entrar is distinct from old.papel_al_entrar
     and new.papel_al_entrar is not null
     and not (new.papel_al_entrar = any(coalesce(old.roles, array[old.rol]))) then
    new.papel_al_entrar := old.papel_al_entrar;
  end if;

  return new;
end;
$$;

comment on function public.perfiles_protege_roles() is
  'Los papeles con mando los reparte administración. Uno puede elegir cuál de los suyos lleva puesto, pero no darse ninguno nuevo, ni al modificar su ficha ni al darse de alta.';

commit;

-- ============================================================
-- LO QUE ESTE PAPEL NO PUEDE HACER
-- ------------------------------------------------------------
-- Se ha repasado tabla por tabla que `cubo` no herede nada de nadie:
--
--   · No es «equipo técnico». `es_staff()` es la llave de cuarenta y
--     una reglas (tests, medallas, retos, la liga, las plantillas de
--     correo, el buzón…) y NO se ha tocado. Meter `cubo` ahí habría
--     sido cómodo y habría regalado medio club.
--   · No ve dinero. `ve_dinero()`, `es_tesoreria()`, `es_junta()` y
--     `es_contabilidad()` comparan el papel con un valor exacto, así
--     que `cubo` no entra por ninguna. Recibos, pagos y cuotas
--     siguen cerrados. El único dinero que toca es el precio del
--     bono de El Cubo, que es lo que se le encarga vender.
--   · No ve fichas de atletas. Ni el teléfono, ni el DNI, ni la
--     cuota, ni las observaciones del entrenador sobre un menor.
--     Solo el nombre, y por la ventana del apartado 3.
--   · No ve entrenamientos, ni asistencias de pista, ni el buzón.
--
-- Y UNA COSA QUE SÍ PUEDE, PARA QUE CONSTE
-- Quien manda en El Cubo puede poner de monitor de una clase a
-- cualquiera del equipo técnico, y estar de monitor da mando sobre
-- El Cubo. O sea que puede dar entrada a otro EN EL CUBO. No fuera
-- de él. Es cómo estaba montado desde la migración 020 y no cambia.
-- ============================================================
