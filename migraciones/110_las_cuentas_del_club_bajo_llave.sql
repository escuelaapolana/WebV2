-- ============================================================
-- 110 · Las cuentas del club, bajo llave
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Cualquiera con cuenta en la web se podía descargar entera la tabla
-- donde están las cuentas bancarias del club.
--
-- POR QUÉ PASA
-- La tabla `info_pagos` (migración 052) nació con una sola regla de
-- lectura:
--
--     lectura info_pagos con sesion  →  authenticated  →  true
--
-- «true» quiere decir: sin condición. Con haber iniciado sesión
-- bastaba. Y eso incluye a los once entrenadores, a los atletas y a
-- un chaval de catorce años del grupo de la escuela, que con abrir la
-- consola del navegador se llevaba las dos cuentas, sus titulares y
-- los teléfonos y correos de quien lleva los cobros.
--
-- Esto no es un descuido tonto: la tabla se cerró a los visitantes
-- sin cuenta (`anon`) con dos candados, y eso sigue bien. Lo que no
-- se pensó entonces es que «tener cuenta» no es lo mismo que «tener
-- por qué verlo».
--
-- LO QUE HA DECIDIDO LA TESORERÍA
-- Textualmente: las cuentas bancarias no las puede ver cualquiera,
-- solo tesorería y administración; a no ser que sea la tuya propia.
--
-- LO QUE SE HACE AQUÍ
-- Se separan dos cosas que hasta hoy eran la misma:
--
--   1. LA TABLA ENTERA (las dos cuentas, todas las columnas) pasa a
--      leerla solo quien lleva el dinero: administración y tesorería.
--      Es la puerta del panel de Cobros.
--
--   2. LO QUE UNA FAMILIA NECESITA PARA PAGAR sale por una puerta
--      nueva y estrecha, la vista `como_se_paga`, que enseña a cada
--      quien la cuenta en la que ingresa ÉL, y solo esa.
--
-- POR QUÉ NO SE CIERRA A SECAS
-- Porque la cuenta del club no es un secreto para quien tiene que
-- ingresar en ella. El bloque «Cómo se paga» que hay debajo de los
-- recibos en la zona del atleta, en la de la familia y en la del
-- socio saca de aquí el número de cuenta al que se transfiere la
-- licencia federativa, la ropa y los bonos. Cerrar la tabla y no
-- poner nada en su sitio habría dejado a las familias con el recibo
-- delante y sin saber dónde ingresar.
--
-- QUÉ ES «LA TUYA PROPIA» EN ESTA TABLA
-- Conviene decirlo claro porque es fácil entenderlo al revés: aquí
-- NO hay cuentas bancarias de personas. Hay dos cuentas, y las dos
-- son del club: la de la escuela y la de socios y adultos. Ninguna
-- columna ata una fila a nadie. Así que «la tuya propia» solo puede
-- querer decir una cosa: la cuenta en la que TÚ ingresas. Un padre
-- con dos críos en la escuela ve la de la escuela; un socio adulto
-- ve la del club; nadie ve las dos salvo administración, tesorería y
-- quien de verdad tenga gente en las dos.
--
-- El día que se guarden domiciliaciones de socios —el IBAN de cada
-- familia— eso será otra tabla y otra migración, y ahí «la tuya
-- propia» sí querrá decir literalmente la tuya.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · DÓNDE PAGO YO
-- ------------------------------------------------------------
-- Devuelve las claves de las cuentas que le tocan a quien está
-- mirando: 'escuela', 'club', las dos, o ninguna.
--
-- El criterio es EL MISMO que ya usaba la web para elegir qué cuenta
-- enseñar (assets/js/info-pagos.js, y antes el panel de atletas):
-- manda lo que el club haya escrito a mano en la ficha
-- (`tipo_membresia`) y, si está en blanco, se deduce por el año de
-- nacimiento. La diferencia es que antes esa decisión se tomaba en el
-- navegador, DESPUÉS de habérselo descargado todo, que es como decir
-- que no se tomaba. Ahora se toma aquí, y lo que no te toca no sale
-- de la base de datos.
--
-- ⚠️ El año de corte está escrito en dos sitios: aquí y en el
-- JavaScript. Si algún día se mueve, hay que moverlo en los dos, o el
-- navegador pedirá una cuenta que la base no le va a dar.
--
-- Tres casos, y el tercero es el importante:
--   · No tengo a nadie apuntado    → ninguna cuenta. Si no pagas
--     nada, no tienes por qué ver dónde se ingresa.
--   · Tengo gente y sé de qué son  → la suya, y solo la suya.
--   · Tengo gente pero la ficha no dice ni el tipo ni la fecha de
--     nacimiento → las dos, con su título. Es lo que ya hacía la web
--     en ese caso, y por la misma razón: más vale enseñar dos y que
--     la familia elija, que enseñar la equivocada y que el dinero
--     acabe en la cuenta que no era.
-- ------------------------------------------------------------
create or replace function public.donde_pago()
returns text[]
language sql
stable
security definer
set search_path to 'public'
as $$
  with mios as (
    -- Los míos son los míos de verdad: mi propia ficha y la de mis
    -- hijos. A propósito NO se usa mis_atletas(), que además incluye
    -- a los atletas que uno entrena: un entrenador no paga la cuota
    -- de su grupo, así que ese camino no le da derecho a nada.
    select a.tipo_membresia, a.fecha_nacimiento
      from public.atletas a
     where a.perfil_id       = public.mi_perfil_id()
        or a.perfil_padre_id = public.mi_perfil_id()
  ),
  claves as (
    select distinct case
             when m.tipo_membresia = 'escuela' then 'escuela'
             when m.tipo_membresia = 'socio'   then 'club'
             when extract(year from m.fecha_nacimiento) >= 2009 then 'escuela'
             when m.fecha_nacimiento is not null then 'club'
           end as clave
      from mios m
  )
  select case
           when not exists (select 1 from mios) then array[]::text[]
           when exists (select 1 from claves where clave is not null)
             then array(select clave from claves where clave is not null)
           else array(select i.clave from public.info_pagos i where i.activo)
         end;
$$;

comment on function public.donde_pago() is
  'Las cuentas del club en las que ingresa quien está mirando la web. Vacío si no paga nada. Es lo que decide qué fila deja ver la vista como_se_paga.';

-- Se le da permiso a quien tiene sesión, igual que a ve_dinero() y a
-- dinero_quien_soy(). No enseña nada de nadie: solo contesta «tú
-- ingresas en la de la escuela», que es un dato tuyo.
revoke all on function public.donde_pago() from public;
grant execute on function public.donde_pago() to authenticated;

-- ------------------------------------------------------------
-- 2 · LA TABLA ENTERA · SOLO QUIEN LLEVA EL DINERO
-- ------------------------------------------------------------
-- Se tira la regla vieja, la del «true». En su lugar, la misma
-- condición que ya guarda el resto del dinero del club: es_admin()
-- para administración y ve_dinero() para tesorería y contabilidad.
-- No se inventa aquí ninguna condición nueva: si mañana se cambia
-- quién es tesorería, se cambia en un sitio y esta tabla se entera
-- sola.
--
-- Escribir (dar de alta una cuenta, cambiar un IBAN) sigue siendo
-- cosa de administración y sigue igual que estaba: es la política
-- «admin gestiona info_pagos», que no se toca.
-- ------------------------------------------------------------
drop policy if exists "lectura info_pagos con sesion" on public.info_pagos;
drop policy if exists "lectura info_pagos solo dinero" on public.info_pagos;

create policy "lectura info_pagos solo dinero"
  on public.info_pagos
  for select
  to authenticated
  using (public.es_admin() or public.ve_dinero());

-- El permiso de tabla se deja como estaba (RLS es quien manda), pero
-- se vuelve a revocar todo a `anon` y a `public` por si acaso: es
-- gratis y es el candado que no depende de que ninguna regla esté
-- bien escrita.
revoke all on public.info_pagos from anon;
revoke all on public.info_pagos from public;

-- ------------------------------------------------------------
-- 3 · LA PUERTA ESTRECHA · `como_se_paga`
-- ------------------------------------------------------------
-- Es lo único que lee ya la web: el bloque «Cómo se paga» de la zona
-- del atleta, la de la familia y la del socio.
--
-- Enseña las filas activas que le tocan a quien pregunta, y nada más.
-- Quedan fuera dos columnas de trastienda que a una familia no le
-- dicen nada: `activo` (la fila apagada sencillamente no aparece) y
-- `updated_at` (cuándo se retocó por última vez desde el panel).
--
-- Mismo patrón que `contactos_publicos` (085) y `cubo_personas`
-- (109): vista curada a propósito, con security_invoker = false, o
-- sea que la vista mira la tabla con sus propios permisos y no con
-- los de quien la consulta. Por eso funciona aunque la tabla de
-- debajo esté cerrada, y por eso el filtro de quién ve qué tiene que
-- estar DENTRO de la vista.
--
-- A `anon` no se le da: un visitante sin cuenta no ve nada, igual que
-- antes.
--
-- Se tira y se rehace en vez de `create or replace` porque reemplazar
-- una vista solo deja añadir columnas al final. Así la migración se
-- puede relanzar siempre.
-- ------------------------------------------------------------
drop view if exists public.como_se_paga;
create view public.como_se_paga as
  select i.clave,
         i.titulo,
         i.titular,
         i.iban,
         i.banco,
         i.metodo,
         i.cuando,
         i.otros_pagos,
         i.concepto_transferencia,
         i.ejemplos_concepto,
         i.texto_devuelto,
         i.contacto_nombre,
         i.contacto_tel,
         i.contacto_email,
         i.contacto_alt_nombre,
         i.contacto_alt_tel,
         i.contacto_alt_email,
         i.nota,
         i.orden
    from public.info_pagos i
   where i.activo
     and (
       -- Quien lleva el dinero sigue viéndolo todo también por aquí,
       -- para que el panel y la vista nunca cuenten cosas distintas.
       public.es_admin()
       or public.ve_dinero()
       -- Y cada quien, la cuenta en la que ingresa él.
       or i.clave = any (public.donde_pago())
     );

comment on view public.como_se_paga is
  'Lo unico de info_pagos que puede leer la web: a cada quien, la cuenta del club en la que ingresa el. La tabla entera solo la leen administracion y tesoreria.';

alter view public.como_se_paga set (security_invoker = false);

revoke all on public.como_se_paga from public;
revoke all on public.como_se_paga from anon;
grant select on public.como_se_paga to authenticated;

commit;

-- ============================================================
-- 4 · CÓMO SE COMPRUEBA QUE ESTO ES VERDAD
-- ------------------------------------------------------------
-- No basta con leer las reglas: hay que sentarse en la silla de cada
-- uno. Se hace dentro de una transacción que se deshace al final, así
-- que no cambia nada. Sustituir el correo por uno real de cada papel:
--
--   begin;
--     set local role authenticated;
--     set local request.jwt.claims to '{"email":"..."}';
--     select count(*) from info_pagos;    -- la tabla entera
--     select count(*) from como_se_paga;  -- lo que ve la web
--   rollback;
--
-- Y para el visitante sin cuenta, lo mismo con `set local role anon`
-- y sin claims: tienen que salir cero y cero.
-- ============================================================
