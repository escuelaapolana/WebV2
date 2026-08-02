-- =====================================================================
-- 068_perfil_socios.sql  ·  EL PERFIL ENTRE SOCIOS: UN SOLO INTERRUPTOR,
--                           Y DE MOMENTO APAGADO
-- =====================================================================
-- Para qué sirve, en una frase: el perfil que un socio puede consultar
-- de otro socio (nombre, rango y medallas) queda construido pero
-- APAGADO para todo el club, y deja de tener dos interruptores.
--
-- QUÉ SE DECIDIÓ (maquetas/v3/DECISIONES-Y-RETOS.md, parte 1)
--   · Los retos son personales: sirven para ver tu propia mejora. Nada
--     público. La competición del club es la Liga Apolana.
--   · El perfil consultable por otros socios se construye pero queda
--     apagado tras un interruptor, igual que la clasificación de la Liga.
--   · Ese interruptor maestro vive AQUÍ, en la base de datos, para poder
--     encenderlo el día que toque sin tocar ni una página.
--   · Cuando se encienda, un menor necesitará 13 años cumplidos Y
--     permiso familiar revocable. Hoy la regla es más dura (un menor no
--     tiene perfil visible ni con permiso) y así se queda: aquí se deja
--     PREPARADA la regla de los 13, sin usarla todavía.
--   · Nunca foto en cuentas de menores: solo nombre abreviado.
--
-- EL LÍO QUE SE DESHACE
--   Había DOS interruptores para lo mismo:
--     · `perfil_juego.participa`  — se movía desde «Mis retos»
--     · `perfiles.perfil_visible` — se movía desde «Mi perfil»
--   y la vista `miembros_juego` exigía LOS DOS encendidos. Alguien podía
--   encender uno, no salir en ninguna parte y no entender por qué.
--
--   A partir de aquí manda UNO SOLO: `perfil_juego.participa`, y se
--   mueve desde «Mi perfil» (maqueta 38b). Se ha elegido ese y no el
--   otro por dos razones:
--     1. Nace APAGADO (`default false`). `perfil_visible` nace
--        encendido, así que el día que se encendiera el club entero
--        aparecería de golpe sin haberlo pedido nadie.
--     2. `perfil_visible` ya tiene otro trabajo: decide si tu nombre
--        sale junto a tus marcas en las clasificaciones de la web
--        (migración 058, vista `ranking_marcas`). Son dos cosas
--        distintas y ahora cada una tiene su columna.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/068_perfil_socios.sql
-- Se puede volver a lanzar las veces que haga falta: no rompe nada.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. EL INTERRUPTOR MAESTRO
-- ---------------------------------------------------------------------
-- Mismo sitio y mismo patrón que el de la clasificación de los retos
-- (`ranking_publico`, migración 045): una sola fila de ajustes para todo
-- el club. Apagado de fábrica.
alter table public.juego_ajustes
  add column if not exists perfil_socios boolean not null default false;

comment on column public.juego_ajustes.perfil_socios is
  'Interruptor del perfil entre socios (la ficha que un socio puede abrir de otro). Apagado de fábrica: los retos son personales. Mientras esté apagado, la vista miembros_juego no devuelve ni una fila a nadie.';

-- Por si la fila de ajustes no existiera todavía.
insert into public.juego_ajustes (id) values (1) on conflict (id) do nothing;

-- ¿Está encendido el perfil entre socios? Lo pregunta la vista, y
-- también las pantallas para explicar por qué el interruptor del socio
-- está desactivado.
create or replace function public.perfil_socios_encendido()
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select coalesce((select perfil_socios from public.juego_ajustes where id = 1), false);
$function$;

comment on function public.perfil_socios_encendido() is
  'Verdadero solo si el club ha encendido el perfil entre socios. Hoy: falso.';

-- Supabase reparte permisos solo por tener algo nuevo en `public`: se
-- retiran a mano y se da únicamente lo que hace falta.
revoke all on function public.perfil_socios_encendido() from public;
revoke all on function public.perfil_socios_encendido() from anon;
grant execute on function public.perfil_socios_encendido() to authenticated;


-- ---------------------------------------------------------------------
-- 2. LA REGLA DE LOS 13 AÑOS · PREPARADA, NO ENCHUFADA
-- ---------------------------------------------------------------------
-- El día que se encienda el perfil entre socios, un menor podrá tener
-- ficha visible solo con 13 años cumplidos Y permiso familiar
-- registrado (y revocable: se borra `autoriza_parental_en` y desaparece
-- al momento). Por debajo de 13, ni con permiso.
--
-- OJO: esta función NO la usa nadie todavía. Está escrita para que el
-- día de encenderlo no haya que inventar nada, pero HOY la vista de
-- abajo sigue con la regla dura: ningún menor de 18, con permiso o sin
-- él. No se relaja nada mientras el interruptor esté apagado.
create or replace function public.perfil_socios_menor_apto(
  p_fecha_nacimiento date,
  p_autoriza_parental_en timestamptz
)
returns boolean
language sql stable
as $function$
  select p_fecha_nacimiento is not null                                  -- sin fecha, no
     and p_fecha_nacimiento <= (current_date - interval '13 years')      -- 13 cumplidos
     and p_autoriza_parental_en is not null;                             -- y permiso familiar
$function$;

comment on function public.perfil_socios_menor_apto(date, timestamptz) is
  'PREPARADA PARA EL FUTURO, hoy no la usa nadie. Dirá si un menor puede tener perfil entre socios el día que se encienda: 13 años cumplidos y permiso familiar registrado. Mientras tanto manda juego_es_menor(), que deja fuera a todos los menores de 18.';

revoke all on function public.perfil_socios_menor_apto(date, timestamptz) from public;
revoke all on function public.perfil_socios_menor_apto(date, timestamptz) from anon;
grant execute on function public.perfil_socios_menor_apto(date, timestamptz) to authenticated;


-- ---------------------------------------------------------------------
-- 3. LA VISTA: UN SOLO INTERRUPTOR DE SOCIO Y EL MAESTRO POR ENCIMA
-- ---------------------------------------------------------------------
-- Se rehace `miembros_juego` con las mismas columnas de siempre, así que
-- las tres vistas que cuelgan de ella (`medallas_publicas`,
-- `logros_publicos`, `clasificacion_retos`) siguen en pie sin tocarlas y
-- se quedan vacías solas: todas preguntan por esta.
--
-- Cambia esto respecto a la 066:
--   · Manda el interruptor maestro. Apagado = ni una fila, para nadie.
--   · Se cae `perfil_visible` como segunda condición. El interruptor del
--     socio es `perfil_juego.participa` y ninguno más.
--   · En cuentas de menores, nunca foto y solo nombre abreviado. Hoy no
--     hace falta (no sale ni uno), pero así ya está puesto para el día
--     que entren los de 13 y no depende de que nadie se acuerde.
create or replace view public.miembros_juego as
  select
    a.id as atleta_id,

    -- El nombre. En un menor, SIEMPRE el abreviado («Nerea V.»): ni el
    -- nombre completo ni el apodo que se haya puesto.
    case
      when public.juego_es_menor(a.fecha_nacimiento)
        then btrim(btrim(a.nombre) || ' ' ||
             case when coalesce(btrim(a.apellidos), '') <> ''
                  then upper(left(btrim(a.apellidos), 1)) || '.'
                  else '' end)
      when coalesce(btrim(p.nombre_publico), '') <> ''
        then btrim(p.nombre_publico)
      else btrim(btrim(a.nombre) || ' ' || coalesce(btrim(a.apellidos), ''))
    end as nombre,

    -- La foto. En un menor, nunca. Decisión cerrada del diseñador.
    case when public.juego_es_menor(a.fecha_nacimiento) then null
         else p.foto_ruta end as foto_ruta,

    pj.puntos,
    (select count(*) from public.atleta_medallas am where am.atleta_id = a.id) as medallas,
    (select count(*) from public.reto_logros   rl where rl.atleta_id = a.id) as retos,
    (select jr.nombre
       from public.juego_rangos jr
      where jr.desde_puntos <= pj.puntos
      order by jr.desde_puntos desc
      limit 1) as rango
  from public.perfil_juego pj
  join public.atletas  a on a.id = pj.atleta_id
  left join public.perfiles p on p.id = a.perfil_id
  -- 1. El club tiene que haberlo encendido. Hoy, no.
  where public.perfil_socios_encendido()
  -- 2. El interruptor de esa persona. El único que hay.
    and pj.participa
  -- 3. Quien está de baja, fuera.
    and coalesce(a.estado, 'activo') <> 'baja'
  -- 4. Los menores, fuera. Ni con permiso familiar.
  --    EL DÍA QUE SE ENCIENDA, esta línea se cambia por:
  --      and (public.juego_es_menor(a.fecha_nacimiento) = false
  --           or public.perfil_socios_menor_apto(a.fecha_nacimiento, pj.autoriza_parental_en))
  --    y ni una cosa más. Está explicado en docs/perfil-entre-socios.md.
    and public.juego_es_menor(a.fecha_nacimiento) = false;

comment on view public.miembros_juego is
  'Fichas consultables entre socios: nombre, foto, rango, puntos, medallas y retos. Vacía mientras juego_ajustes.perfil_socios esté apagado. El interruptor de cada persona es perfil_juego.participa y no hay ningún otro. Los menores no salen, y si algún día salieran sería sin foto y con el nombre abreviado.';

-- La vista se salta a propósito las reglas de las tablas de debajo (para
-- poder ver a gente del club que no es «tuya»), así que el candado es
-- este: solo la lee quien ha entrado con su cuenta. `create or replace`
-- conserva las opciones, pero se vuelve a decir para no depender de eso.
alter view public.miembros_juego set (security_invoker = off);

-- Permisos, a mano y explícitos: Supabase concede solo por existir.
revoke all on public.miembros_juego      from anon;
revoke all on public.miembros_juego      from public;
revoke all on public.medallas_publicas   from anon;
revoke all on public.medallas_publicas   from public;
revoke all on public.logros_publicos     from anon;
revoke all on public.logros_publicos     from public;
revoke all on public.clasificacion_retos from anon;
revoke all on public.clasificacion_retos from public;

grant select on public.miembros_juego      to authenticated;
grant select on public.medallas_publicas   to authenticated;
grant select on public.logros_publicos     to authenticated;
grant select on public.clasificacion_retos to authenticated;


-- ---------------------------------------------------------------------
-- 4. LOS AJUSTES: QUIÉN LOS LEE Y QUIÉN LOS MUEVE
-- ---------------------------------------------------------------------
-- `juego_ajustes` tenía repartidos a `anon` todos los permisos por el
-- reparto automático de Supabase. No se colaba nada (no hay ninguna
-- regla RLS para `anon`, así que veía cero filas), pero un permiso que
-- no hace falta se quita: si mañana alguien escribe una regla nueva sin
-- cuidado, el candado sigue puesto.
revoke all on public.juego_ajustes from anon;
revoke all on public.juego_ajustes from public;
grant select, update on public.juego_ajustes to authenticated;

-- Y las reglas de fila, tal como estaban (064: el interruptor lo mueve
-- un admin, no cualquiera del equipo). Se vuelven a escribir para que
-- este archivo se pueda lanzar sobre una base recién montada.
alter table public.juego_ajustes enable row level security;

drop policy if exists "ajustes juego lectura" on public.juego_ajustes;
create policy "ajustes juego lectura" on public.juego_ajustes
for select to authenticated using (true);

drop policy if exists "ajustes juego los cambia el equipo" on public.juego_ajustes;
drop policy if exists "ajustes juego los cambia admin"     on public.juego_ajustes;
create policy "ajustes juego los cambia admin" on public.juego_ajustes
for update to authenticated using (es_admin()) with check (es_admin());

commit;


-- =====================================================================
-- 5. COMPROBACIONES
-- ---------------------------------------------------------------------
-- Al lanzar el archivo se ven aquí mismo. Lo esperado va escrito.
-- =====================================================================

-- El interruptor existe y está apagado.
select 'interruptor maestro' as que, perfil_socios as encendido
  from public.juego_ajustes where id = 1;                 -- encendido = f

-- Con el interruptor apagado, la vista no devuelve nada a nadie.
select 'fichas visibles ahora mismo' as que, count(*) as filas
  from public.miembros_juego;                             -- filas = 0

-- `anon` no tiene ni un permiso sobre nada de esto.
select 'permisos sueltos de anon' as que, count(*) as total
  from information_schema.role_table_grants
 where table_schema = 'public'
   and grantee = 'anon'
   and table_name in ('juego_ajustes', 'miembros_juego', 'medallas_publicas',
                      'logros_publicos', 'clasificacion_retos');   -- total = 0

-- Las funciones nuevas: solo las ejecuta quien ha entrado con su cuenta.
select 'quien ejecuta las funciones nuevas' as que, p.proname as funcion, p.proacl as permisos
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('perfil_socios_encendido', 'perfil_socios_menor_apto');

-- =====================================================================
-- 6. EL DÍA QUE SE QUIERA ENCENDER
-- ---------------------------------------------------------------------
-- Está contado en llano en docs/perfil-entre-socios.md. En corto:
--
--   1. Cambiar la línea 4 de la vista de arriba por la de los 13 años
--      (está escrita ahí mismo, en el comentario) y volver a lanzar
--      este archivo.
--   2. Pedir el permiso familiar de los menores de 13 a 17 y apuntarlo
--      en `perfil_juego.autoriza_parental_por` y `autoriza_parental_en`.
--   3. Y encender el maestro:
--
--        update public.juego_ajustes
--           set perfil_socios = true, actualizado = now()
--         where id = 1;
--
--      No sale nadie de golpe, porque `perfil_juego.participa` nace
--      apagado: solo aparecerá quien lo encienda a mano en «Mi perfil».
--
-- La página «Mi perfil» no hay que tocarla: pregunta por
-- `perfil_socios_encendido()` al cargar y, en cuanto esto diga que sí,
-- el interruptor del socio se activa solo.
--
-- Para volver a apagarlo, lo mismo con `false`. Es instantáneo y no
-- borra nada: las fichas dejan de verse y ya está.
-- =====================================================================
