-- 188 · Aforo de los grupos del Cubo + lista de espera
-- ------------------------------------------------------------
-- Cada grupo del Cubo tiene un límite de plazas (por defecto 20). Cuando un
-- grupo se llena, las altas nuevas de ese turno entran en LISTA DE ESPERA
-- (marca `lista_espera` en cubo_altas): no cuentan como plaza, no pagan, y el
-- club decide cuándo darles sitio (quitar la marca) o ampliar el límite.
-- El límite vive en cubo_config (global); se puede subir cuando el club quiera.
-- ============================================================
begin;

alter table public.cubo_altas
  add column if not exists lista_espera boolean not null default false;

alter table public.cubo_config
  add column if not exists limite_grupo integer not null default 20;

commit;
