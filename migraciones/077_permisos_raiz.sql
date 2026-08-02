-- ============================================================
-- 077 · La raíz de los permisos: que las tablas nuevas nazcan cerradas
-- ------------------------------------------------------------
-- Una auditoría hostil encontró por fin POR QUÉ este fallo reaparece
-- una y otra vez (van seis incidentes): Supabase deja unos «permisos
-- por defecto» que hacen que **toda tabla nueva de `public` nazca con
-- INSERT/UPDATE/DELETE para anon y authenticated**. Cada migración que
-- crea una tabla arrastra el agujero, y solo la tapa la RLS — si algún
-- día una RLS se afloja, queda abierto.
--
-- Además había un exploit EN VIVO: la vista `liga_edicion_publica`
-- corría con permisos de superusuario y era escribible por anon, así
-- que **un visitante anónimo podía renombrar o borrar la edición
-- activa de la Liga** saltándose la RLS. Ejecutado de verdad en la
-- auditoría (y revertido).
--
-- Esto cierra las dos cosas de golpe:
--   · anon pasa a SOLO LEER (menos los dos formularios públicos);
--   · a authenticated se le quita lo que un cliente nunca usa;
--   · y se cierra la raíz: lo que se cree a partir de ahora nace sin
--     permisos para anon/authenticated (quien los necesite, que los dé
--     a mano en su migración).
-- Idempotente. Validado en transacción antes de aplicar.
-- ============================================================

-- 1 · VISTAS · nadie del cliente escribe a través de una vista.
--     Aquí vivía el exploit de liga_edicion_publica.
do $$ declare r record; begin
  for r in select table_name from information_schema.views where table_schema='public' loop
    execute format('revoke insert, update, delete, truncate, references, trigger on public.%I from anon, authenticated', r.table_name);
  end loop;
end $$;

-- 2 · TABLAS · anon SOLO lee. Fuera toda la escritura.
do $$ declare r record; begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
           where n.nspname='public' and c.relkind='r' loop
    execute format('revoke insert, update, delete, truncate, references, trigger on public.%I from anon', r.relname);
  end loop;
end $$;

-- 2b · Los DOS únicos formularios públicos legítimos recuperan su INSERT:
--      el de contacto y el de alta de nuevos. (Si alguno no existe con
--      ese nombre, su grant se ignora sin romper nada.)
do $$ begin
  begin grant insert on public.mensajes to anon; exception when undefined_table then null; end;
  begin grant insert on public.solicitudes_inscripcion to anon; exception when undefined_table then null; end;
end $$;

-- 3 · TABLAS · authenticated conserva su DML (la app lo necesita, con la
--     RLS delante), pero se le quita TRUNCATE/REFERENCES/TRIGGER, que un
--     cliente nunca usa.
do $$ declare r record; begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
           where n.nspname='public' and c.relkind='r' loop
    execute format('revoke truncate, references, trigger on public.%I from authenticated', r.relname);
  end loop;
end $$;

-- 4 · LA RAÍZ · que las tablas nuevas nazcan SIN permisos para
--     anon/authenticated. El que los necesite, que los conceda en su
--     migración, a la vista de todos.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;

-- 5 · EXECUTE en funciones DISPARADOR: ruido inofensivo (no se pueden
--     llamar como función normal), pero se retira para no dejar cabos.
do $$ declare r record; begin
  for r in select p.oid::regprocedure sig
           from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           join pg_type t on t.oid=p.prorettype
           where n.nspname='public' and t.typname='trigger' loop
    execute format('revoke execute on function %s from anon, authenticated', r.sig);
  end loop;
end $$;
