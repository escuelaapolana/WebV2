-- ============================================================
-- 074 · Fuera el permiso de VACIAR TABLAS
-- ------------------------------------------------------------
-- Supabase reparte permisos de serie sobre todo lo que se crea
-- en `public`, y entre ellos va TRUNCATE, que es «vaciar la
-- tabla entera de golpe».
--
-- Y TRUNCATE **se salta las reglas de acceso (RLS)**. Da igual
-- lo bien escritas que estén: quien lo tiene, borra todo.
--
-- Estaba concedido en 81 tablas a quien tiene cuenta y en 71
-- **incluso sin cuenta**. Entre ellas, `atletas` y `pagos`.
-- Es decir: una sola orden desde la consola del navegador dejaba
-- al club sin fichas de sus atletas y sin sus recibos, sin dejar
-- rastro y sin nada que recuperar.
--
-- Nadie necesita TRUNCATE desde la web. Ni el club, que borra
-- fila a fila desde el panel. Aquí se retira de todas las tablas
-- y también de las que se creen a partir de ahora.
-- Idempotente.
-- ============================================================

-- 1 · Quitarlo de todo lo que existe hoy
do $$
declare t record;
begin
  for t in
    select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('revoke truncate on public.%I from anon, authenticated', t.tablename);
  end loop;
end $$;

-- 2 · Y que no vuelva a aparecer en lo que se cree después.
--     Supabase lo concede con estos «permisos por defecto»; se
--     recorta aquí para que las tablas nuevas nazcan sin él.
alter default privileges in schema public
  revoke truncate on tables from anon, authenticated;

-- 3 · Y de las vistas. Ahí no hay riesgo (una vista no se puede
--     vaciar), pero se retira para que no quede ni un permiso
--     suelto que confunda en la próxima revisión.
do $$
declare v record;
begin
  for v in
    select table_name from information_schema.views where table_schema = 'public'
  loop
    execute format('revoke truncate on public.%I from anon, authenticated', v.table_name);
  end loop;
end $$;
