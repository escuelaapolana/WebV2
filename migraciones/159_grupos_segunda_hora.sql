-- ============================================================
-- 159 · Grupos de 2ª hora: Fondo-Mediofondo y Recreación 1 y 2
-- ------------------------------------------------------------
-- La 2ª hora (los mayores) tiene:
--   · Grupo A y Grupo B  → ya existían. Son de SELECCIÓN: no entran en
--     el reparto; Andrés promociona ahí a mano desde Recreación.
--   · Fondo-Mediofondo    → NUEVO. Entrena 5 días. También de selección.
--   · Recreación 1 y 2    → NUEVOS. Aquí aterriza la gente nueva de 2ª
--     hora; luego se promociona a A/B/Fondo.
--
-- Se crean como seccion='escuela' (son parte de la escuela, 2ª hora) y
-- SIN turno todavía: así no se cuelan como columna en el reparto de 1ª
-- hora. El turno de 3 días (L-X-V / M-J-V) y el rango de edad de
-- Recreación se ponen cuando se enganche el reparto de 2ª hora.
-- Insert idempotente: si ya existen por nombre, no se duplican.
-- ============================================================

insert into public.grupos (nombre, seccion, activo, descripcion)
select 'Fondo-Mediofondo', 'escuela', true, '2ª hora · entrena 5 días · grupo de selección (no entra en el reparto)'
where not exists (select 1 from public.grupos where nombre = 'Fondo-Mediofondo');

insert into public.grupos (nombre, seccion, activo, descripcion)
select 'Recreación 1', 'escuela', true, '2ª hora · aquí entra la gente nueva; luego se promociona a A/B/Fondo'
where not exists (select 1 from public.grupos where nombre = 'Recreación 1');

insert into public.grupos (nombre, seccion, activo, descripcion)
select 'Recreación 2', 'escuela', true, '2ª hora · segundo grupo de recreación, según cuánta gente haya'
where not exists (select 1 from public.grupos where nombre = 'Recreación 2');
