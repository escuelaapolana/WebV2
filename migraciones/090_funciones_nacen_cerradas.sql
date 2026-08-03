-- ============================================================
-- 090 · La raíz de los permisos, ahora para las FUNCIONES
-- ------------------------------------------------------------
-- La migración 077 cerró la raíz de las TABLAS: hoy una tabla nueva de
-- `public` nace sin permisos para quien entra sin cuenta (`anon`) ni
-- para quien tiene cuenta normal (`authenticated`). Pero las FUNCIONES
-- se quedaron fuera de aquel arreglo, y ahí seguía el mismo agujero de
-- fondo: **toda función nueva nace EJECUTABLE por `anon` y
-- `authenticated`**. Cada RPC (una función que el navegador puede
-- llamar) arrastra el permiso, y solo lo tapa que la función compruebe
-- por dentro quién la llama. Si una se despista, queda abierta.
--
-- Y una se había despistado. La auditoría (tercera ronda) lo demostró
-- EN VIVO contra la API de verdad, sin cuenta:
--
--   POST /rest/v1/rpc/juego_metrica
--   { "p_metrica":"puntos", "p_desde":"2000-01-01", "p_hasta":"2999-12-31" }
--   -> [ {"atleta_id":"…","valor":50}, … ]  (158 atletas)
--
-- `juego_metrica` es una pieza interna del juego de retos: devuelve,
-- para CADA atleta, sus recuentos de asistencias, marcas, tests,
-- competiciones, clases de El Cubo y puntos. Nunca la llama la web
-- (solo la usan por dentro `retos_progreso_atleta` y `retos_actualizar`,
-- que sí comprueban quién pregunta). Pero nacía ejecutable por `anon`,
-- así que cualquiera, sin cuenta, se llevaba de golpe la actividad de
-- todo el club —de menores incluidos— ligada a su identificador. Es
-- justo la clase de fuga que esta raíz mal cerrada deja pasar.
--
-- POR QUÉ NO BASTA CON CAMBIAR EL VALOR POR DEFECTO
-- Las funciones traen de serie un permiso EXECUTE para PUBLIC (todo el
-- mundo). En este Supabase, `alter default privileges … revoke execute
-- … from public` se acepta pero NO quita ese permiso de PUBLIC en lo
-- que se cree después (comprobado: la función nueva sigue naciendo con
-- `=X`, ejecutable por `anon`). Así que hacen falta DOS candados que se
-- complementan, y aquí se ponen los dos.
--
-- POR QUÉ NO SE PUEDE «REVOCAR TODO LO QUE NO LLAMA LA WEB» DE GOLPE
-- Muchas funciones internas (es_admin, es_staff, mi_perfil_id…) NO las
-- llama el navegador, pero SÍ las usan las reglas de acceso (RLS) por
-- dentro. Y una regla RLS que llama a una función EXIGE que quien hace
-- la consulta pueda ejecutarla: comprobado en vivo, si a
-- `authenticated` le quitas el EXECUTE de `es_admin`, cualquier consulta
-- a una tabla cuya política use `es_admin` revienta con «permission
-- denied for function es_admin». Por eso NO se puede cerrar en bloque:
-- se cierra la fuga concreta y se cambia la raíz para lo que venga.
-- Idempotente.
-- ============================================================

-- ------------------------------------------------------------
-- 1 · CERRAR LA FUGA DE AHORA
-- ------------------------------------------------------------
-- Piezas internas del juego: solo las llaman otras funciones (que corren
-- como su dueño y no necesitan este permiso). La web nunca las llama.
-- Se les quita el EXECUTE a PUBLIC, anon y authenticated.
revoke execute on function public.juego_metrica(text, date, date)     from public, anon, authenticated;

-- De paso, dos ayudantes del Cubo del mismo estilo: reciben un atleta
-- por parámetro y NO comprueban quién pregunta. No los llama la web
-- (solo cubo_consumir_uso y cubo_reservas_promocion, por dentro), así
-- que se cierran igual. Devuelven poco (un número, un id), pero un
-- ayudante interno no tiene por qué ser una RPC pública.
revoke execute on function public.cubo_usos_disponibles(uuid) from public, anon, authenticated;
revoke execute on function public.cubo_bono_a_usar(uuid)      from public, anon, authenticated;


-- ------------------------------------------------------------
-- 2 · LA RAÍZ (candado A): que lo nuevo no reciba el permiso EXPLÍCITO
-- ------------------------------------------------------------
-- Supabase deja puesto un «permiso por defecto» que da EXECUTE explícito
-- a anon y authenticated en cada función nueva. Se retira, igual que la
-- 077 hizo con las tablas. Con esto, una función nueva ya no nace con
-- anon=X/authenticated=X; solo le queda el EXECUTE heredado de PUBLIC,
-- que se lo quita el candado B. (A service_role y postgres no se les
-- toca: los necesita el servidor.)
alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated;


-- ------------------------------------------------------------
-- 3 · LA RAÍZ (candado B): quitar el EXECUTE de PUBLIC a lo recién nacido
-- ------------------------------------------------------------
-- Como el «por defecto» no puede quitar el EXECUTE de PUBLIC (ver arriba),
-- lo hace este disparador de eventos en cuanto se crea una función en
-- `public`. Es el mismo patrón, ya probado, que `rls_auto_enable` usa
-- para encender la RLS en las tablas nuevas.
--
-- Detalles pensados para NO romper nada:
--   · Solo QUITA el EXECUTE de PUBLIC. NO toca los permisos explícitos
--     (anon=X/authenticated=X) que una función pueda tener. Por eso un
--     `create or replace` de una RPC pública que ya existe la deja
--     igual: conserva su anon/authenticated y sigue funcionando.
--   · Una función nueva pensada para ser pública se abre A PROPÓSITO en
--     su propia migración, con `grant execute … to anon, authenticated`
--     DESPUÉS de crearla (el grant gana al disparador).
--   · Se salta las funciones que trae una extensión (btree_gist, etc.):
--     esas las usa el motor por dentro y no son RPC.
create or replace function public.funcs_nacen_cerradas()
returns event_trigger
language plpgsql
security definer
set search_path to pg_catalog
as $fn$
declare
  cmd record;
begin
  for cmd in
    select * from pg_event_trigger_ddl_commands()
    where command_tag = 'CREATE FUNCTION'
      and schema_name = 'public'
  loop
    -- Objetos que pertenecen a una extensión: no se tocan.
    if exists (
      select 1 from pg_depend d
      where d.classid = 'pg_proc'::regclass
        and d.objid   = cmd.objid
        and d.deptype = 'e'
    ) then
      continue;
    end if;

    begin
      execute format('revoke execute on function %s from public', cmd.object_identity);
    exception when others then
      -- Nunca romper una migración por esto: se deja constancia y sigue.
      raise log 'funcs_nacen_cerradas: no pude cerrar % (%)', cmd.object_identity, sqlerrm;
    end;
  end loop;
end;
$fn$;

-- Esta función interna tampoco necesita ser pública.
revoke execute on function public.funcs_nacen_cerradas() from public, anon, authenticated;

drop event trigger if exists ztrg_funcs_nacen_cerradas;
create event trigger ztrg_funcs_nacen_cerradas
  on ddl_command_end
  when tag in ('CREATE FUNCTION')
  execute function public.funcs_nacen_cerradas();


-- ------------------------------------------------------------
-- 4 · COMPROBACIÓN AL LANZAR
-- ------------------------------------------------------------
-- La fuga cerrada: anon ya NO puede ejecutar juego_metrica.
select 'juego_metrica ejecutable por anon (debe ser f)' as comprobacion,
       has_function_privilege('anon', 'public.juego_metrica(text,date,date)', 'EXECUTE') as valor;

-- El candado B, puesto.
select 'disparador funcs_nacen_cerradas activo' as comprobacion,
       exists(select 1 from pg_event_trigger where evtname = 'ztrg_funcs_nacen_cerradas') as valor;
