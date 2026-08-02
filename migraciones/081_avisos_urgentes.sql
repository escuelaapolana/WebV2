-- ============================================================
-- 081 · Avisos: uno urgente se ve al entrar, y se pueden programar
-- ------------------------------------------------------------
-- (El número 080 ya lo ocupa 080_biblioteca_ficha_huerfana.sql,
--  así que este va con el 081.)
--
-- El problema, medido: la franja de la portada se pinta en el
-- puesto 6 de 10 y arranca en el píxel 1.810, con una pantalla de
-- móvil de 874. Hay que bajar más de una pantalla entera para
-- verla. Vale para «El Cubo abre por las mañanas»; no vale para
-- «mañana no hay entreno por lluvia».
--
-- Se añaden dos casillas:
--   · `urgente`      → sube el aviso arriba del todo, encima del
--                      logotipo. Por defecto NO (false), así que
--                      ningún aviso de los que hay cambia de sitio.
--   · `fecha_inicio` → opcional. Si está puesta, el aviso no
--                      aparece antes de ese día. Hasta ahora solo
--                      existía `fecha_fin`, así que no se podía
--                      dejar nada preparado con antelación.
--
-- Idempotente: se puede volver a lanzar sin romper nada.
-- ============================================================

alter table public.avisos add column if not exists urgente      boolean not null default false;
alter table public.avisos add column if not exists fecha_inicio date;

comment on column public.avisos.urgente is
  'true = la franja sube arriba del todo, encima del hero. false (por defecto) = se queda en su sitio de la portada.';
comment on column public.avisos.fecha_inicio is
  'Opcional. Si está puesta, el aviso no se enseña antes de ese día. Sirve para dejarlo programado.';

-- Los que ya existen se quedan exactamente como estaban: no urgentes
-- y sin fecha de inicio. (El default ya lo hace; esto es el cinturón.)
update public.avisos set urgente = false where urgente is null;

-- ------------------------------------------------------------
-- PERMISOS · el fallo que ya ha vuelto seis veces en este proyecto.
-- Supabase reparte permisos de serie sobre lo que se crea nuevo. Aquí
-- no se crea tabla, solo columnas —que heredan el GRANT de la tabla—,
-- pero se vuelve a cerrar a mano para no fiarlo a eso:
--   · anon        → SOLO leer.
--   · authenticated → su DML de siempre, con la RLS delante.
-- ------------------------------------------------------------
revoke insert, update, delete, truncate, references, trigger on public.avisos from anon;
grant  select on public.avisos to anon;

revoke truncate, references, trigger on public.avisos from authenticated;

-- Y por si acaso, a nivel de columna: que nadie de fuera pueda escribir
-- las dos casillas nuevas ni aunque un GRANT de tabla se afloje.
revoke insert (urgente, fecha_inicio), update (urgente, fecha_inicio)
  on public.avisos from anon;
