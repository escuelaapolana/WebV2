-- 189 · El Cubo: marcar quién entra como socio del club
-- --------------------------------------------------------------------
-- Hasta ahora el precio reducido (20 €/1 día · 30 €/2 días) era solo para
-- familias de la escuela (`es_escuela`). Los socios del club tienen el mismo
-- precio que las familias, así que se añade una marca propia para poder
-- distinguirlos en el panel (el club comprueba la condición al aprobar).
-- El precio lo sigue calculando el servidor (cubo-alta) a partir de
-- es_escuela / es_socio + días.

alter table public.cubo_altas
  add column if not exists es_socio boolean not null default false;
