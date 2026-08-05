-- ============================================================
-- 133 · Publicar carreras es cosa del papel que llevas puesto
-- ------------------------------------------------------------
-- Dos cosas en este fichero, y solo la primera cambia algo:
--   1 · Se arregla quién puede publicar carreras de la Liga.
--   2 · Se deja escrita una decisión pendiente sobre los contactos
--       de mensajes, para que quien la lea dentro de un año sepa que
--       está esperando al club y no la «arregle» por su cuenta.
--
-- ------------------------------------------------------------
-- 1 · QUIÉN PUBLICA CARRERAS EN EL CALENDARIO PÚBLICO
-- ------------------------------------------------------------
-- EL PROBLEMA
-- La puerta que deja publicar una carrera propuesta en el calendario
-- público miraba el papel principal a pelo:
--
--     where p.email = (auth.jwt() ->> 'email')
--       and p.rol in ('admin', 'coordinador')
--
-- Ahí faltan dos cosas, y las dos abren de más:
--
--   a) NO MIRA EL PAPEL QUE SE LLEVA PUESTO. En este club una persona
--      tiene varios papeles y elige con cuál está mirando el club
--      (`rol_activo`). Publicar es HACER algo, y para hacer algo manda
--      el papel que se lleva puesto, no la lista de los que se tienen.
--      Tal y como estaba, alguien que ha entrado como atleta —para ver
--      sus entrenos, sin ánimo de administrar nada— podía publicar en
--      el calendario que ve todo el mundo, dentro y fuera del club.
--      Hoy mismo hay una persona en esa situación.
--
--   b) NO MIRA SI LA FICHA ESTÁ DE BAJA. Quien deja el club conserva
--      su papel escrito en la ficha, y `activo = false` es lo único
--      que dice que ya no está. Sin esa comprobación, un coordinador
--      que se fue el año pasado seguiría pudiendo publicar. Hoy no hay
--      nadie de baja con ese papel, así que esto no arregla ningún
--      caso real: cierra la puerta antes de que pase.
--
-- Es el mismo fallo que la migración 130 encontró en tesorería, pero
-- del revés: allí la puerta se quedaba corta y tumbaba herramientas
-- que sí eran de tesorería; aquí se pasa y deja publicar a quien en
-- ese momento no está haciendo de administración.
--
-- LO QUE SE HACE
-- Se añaden las dos condiciones que faltaban. Nada más:
--
--     and coalesce(p.activo, true)
--     and coalesce(p.rol_activo, p.rol) in ('admin', 'coordinador')
--
-- El `coalesce` de `rol_activo` es «el que llevo puesto, y si no he
-- elegido ninguno, el mío de siempre». Es la misma fórmula exacta que
-- usan `es_admin`, `es_staff`, `es_tesoreria` y `cubo_es_gestor`.
--
-- ESTO NO DEJA A NADIE FUERA DE VERDAD
-- Quien coordina y ahora mismo está mirando el club como atleta no
-- pierde nada: cambia de papel arriba, como para cualquier otra tarea
-- del panel, y publica. Es exactamente lo que ya le pasa con el resto
-- de herramientas de administración, así que no hay nada nuevo que
-- aprender ni ninguna pantalla que se quede en blanco sin explicar.
--
-- Y OJO, QUE NO SE CONFUNDA CON LA MIGRACIÓN 132
-- La de ayer hacía justo lo contrario en los avisos: allí se pasó a
-- mirar TODOS los papeles que se tienen. No se contradicen, son las
-- dos mitades de la misma regla del club:
--
--   · RECIBIR un aviso  → cuenta lo que se TIENE.
--   · HACER algo        → cuenta lo que se LLEVA PUESTO.
--
-- COMPROBADO CONTRA LA BASE, CON LOS NÚMEROS DELANTE
--
--   QUIÉN PODÍA PUBLICAR
--     antes .............................................  3 personas
--     después ...........................................  2 personas
--     la que sale es quien está mirando el club como
--     atleta, y vuelve a entrar en cuanto se cambia
--     el papel ..........................................  sí
--
--   LA CARA DE «NO SE CIERRA DE MÁS»
--     personas con administración o coordinación puesta
--     que se hayan quedado fuera ........................  0
--     fichas de baja que podían publicar (se simuló una
--     baja dentro de una transacción que se deshizo):
--       antes ...........................................  1
--       después .........................................  0
--
-- ------------------------------------------------------------
-- 2 · LA DECISIÓN QUE ESTÁ PENDIENTE, Y NO ES TÉCNICA
-- ------------------------------------------------------------
-- Al repasar dónde más se miraba el papel principal apareció esto,
-- que NO se toca aquí a propósito.
--
-- En los mensajes del portal, «administración del club» —la gente con
-- la que cualquiera puede hablar, y a quien le sale hablar con todo el
-- club— se saca de `p.rol = 'admin'`, o sea, del papel principal.
--
-- Hoy da exactamente lo mismo: las tres personas que salen serían las
-- mismas mirando la lista entera de papeles. Pero el día que alguien
-- tenga `admin` como segundo papel, la pregunta deja de ser técnica:
-- si sale en la lista, cientos de familias van a poder escribirle a él
-- directamente, y eso cambia a quién llaman cuando hay un problema.
--
-- Eso lo decide el club, no una migración. Se queda escrito en el
-- comentario de las dos funciones para que quien las lea lo sepa.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- Quién puede publicar una carrera propuesta
-- ------------------------------------------------------------
-- Publicar en el calendario público no es cosa de cualquiera del
-- equipo: `competiciones` es tabla de administración. Abren la puerta
-- quien lleva el club y quien coordina, que son los que miran la Liga
-- —y solo mientras están haciendo de eso.
create or replace function public.es_responsable_liga()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles p
     where p.email = (auth.jwt() ->> 'email')
       -- Quien ya no está en el club no publica nada.
       and coalesce(p.activo, true)
       -- El papel que lleva puesto ahora mismo, no todos los que
       -- tiene: publicar es hacer, y para hacer manda el sombrero
       -- que uno se ha puesto. Quien entró como atleta se cambia
       -- arriba y publica, igual que para el resto del panel.
       and coalesce(p.rol_activo, p.rol) in ('admin', 'coordinador')
  );
$$;

comment on function public.es_responsable_liga() is
  'Cierto si quien pregunta está haciendo de administración o de coordinación en este momento, y sigue en el club. Es la puerta de publicar carreras de la Liga en el calendario público.';

-- Sigue cerrada igual que estaba (migración 059): desde el navegador
-- no se llama. La usan por dentro `liga_publicar_propuesta` y
-- `liga_publicar_pendientes`, que sí se llaman desde el panel.
revoke all on function public.es_responsable_liga() from public, anon, authenticated;
grant execute on function public.es_responsable_liga() to service_role;

-- ------------------------------------------------------------
-- La nota de lo que está pendiente
-- ------------------------------------------------------------
-- No cambian de comportamiento: solo se les pega el aviso encima.
comment on function public.mis_contactos_mensajes() is
  'Con quién puede hablar cada uno por el portal. PENDIENTE DE DECIDIR EN EL CLUB, no lo cambies sin preguntar: «administración» se saca del papel PRINCIPAL (rol), no de la lista de papeles (roles). Hoy salen las mismas tres personas de todas formas. El día que alguien tenga admin como segundo papel hay que decidir antes si queremos que cientos de familias le escriban directamente, porque eso cambia a quién llaman cuando hay un problema.';

comment on function public.puedo_hablar_con(uuid) is
  'Sí o no: si estas dos personas pueden escribirse. PENDIENTE DE DECIDIR EN EL CLUB, va de la mano de mis_contactos_mensajes: aquí «administración» también sale del papel PRINCIPAL. Si se cambia una hay que cambiar la otra, o saldrá gente en la lista de contactos a la que luego no se le puede escribir.';

commit;
