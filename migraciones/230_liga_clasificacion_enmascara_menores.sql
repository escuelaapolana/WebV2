-- 230 · MEDIO · Las vistas internas de clasificación de la Liga (usadas por el
-- portal y el panel) exponían el nombre y apellidos COMPLETOS de menores a
-- cualquier cuenta autenticada, justo lo que la clasificación pública sí
-- enmascara. Se reescriben para enmascarar el nombre de menores (nombre de pila
-- + inicial del apellido) cuando el que consulta NO es staff; el staff sigue
-- viendo el nombre completo. Se mantiene atleta_id (el portal lo usa para
-- resaltar tu propia fila). Enmascarado igual que liga_clasificacion_publica_fn.

-- general
create or replace view public.liga_clasificacion_general as
with c as (
  select rank() over (order by total desc, pruebas desc, nombre) as posicion,
    clave, atleta_id, nombre, categoria, categoria_orden, p_atletismo, p_running, p_trail,
    p_triatlon, p_natacion, bonus, ajustes, total, pruebas, bonus_mensual, bonus_constancia,
    bonus_multideporte, disciplinas, finisher, finisher_falta
  from public.liga_clasificacion(public.liga_edicion_activa())
    as f(clave, atleta_id, nombre, categoria, categoria_orden, p_atletismo, p_running, p_trail,
         p_triatlon, p_natacion, bonus, ajustes, total, pruebas, bonus_mensual, bonus_constancia,
         bonus_multideporte, disciplinas, finisher, finisher_falta)
)
select c.posicion, c.clave, c.atleta_id,
  case when public.es_staff() then c.nombre
       when public.juego_es_menor(a.fecha_nacimiento) and pj.autoriza_parental_en is null
       then split_part(btrim(coalesce(a.nombre, c.nombre)), ' ', 1)
            || case when coalesce(a.apellidos,'') <> '' then ' ' || left(btrim(a.apellidos), 1) || '.' else '' end
       else c.nombre end as nombre,
  c.categoria, c.categoria_orden, c.p_atletismo, c.p_running, c.p_trail, c.p_triatlon, c.p_natacion,
  c.bonus, c.ajustes, c.total, c.pruebas, c.bonus_mensual, c.bonus_constancia, c.bonus_multideporte,
  c.disciplinas, c.finisher, c.finisher_falta
from c
left join public.atletas a       on a.id = c.atleta_id
left join public.perfil_juego pj on pj.atleta_id = c.atleta_id;

-- por categoría
create or replace view public.liga_clasificacion_por_categoria as
with c as (
  select categoria, categoria_orden,
    rank() over (partition by categoria order by total desc, pruebas desc, nombre) as posicion,
    clave, atleta_id, nombre, total, pruebas, bonus, ajustes, p_atletismo, p_running, p_trail, p_triatlon, p_natacion
  from public.liga_clasificacion(public.liga_edicion_activa())
    as f(clave, atleta_id, nombre, categoria, categoria_orden, p_atletismo, p_running, p_trail,
         p_triatlon, p_natacion, bonus, ajustes, total, pruebas, bonus_mensual, bonus_constancia,
         bonus_multideporte, disciplinas, finisher, finisher_falta)
)
select c.categoria, c.categoria_orden, c.posicion, c.clave, c.atleta_id,
  case when public.es_staff() then c.nombre
       when public.juego_es_menor(a.fecha_nacimiento) and pj.autoriza_parental_en is null
       then split_part(btrim(coalesce(a.nombre, c.nombre)), ' ', 1)
            || case when coalesce(a.apellidos,'') <> '' then ' ' || left(btrim(a.apellidos), 1) || '.' else '' end
       else c.nombre end as nombre,
  c.total, c.pruebas, c.bonus, c.ajustes, c.p_atletismo, c.p_running, c.p_trail, c.p_triatlon, c.p_natacion
from c
left join public.atletas a       on a.id = c.atleta_id
left join public.perfil_juego pj on pj.atleta_id = c.atleta_id;

-- por disciplina
create or replace view public.liga_clasificacion_por_disciplina as
with c as (
  select d.disciplina,
    rank() over (partition by d.disciplina order by d.puntos desc, cc.nombre) as posicion,
    cc.clave, cc.atleta_id, cc.nombre, cc.categoria, d.puntos
  from public.liga_clasificacion(public.liga_edicion_activa())
    as cc(clave, atleta_id, nombre, categoria, categoria_orden, p_atletismo, p_running, p_trail,
          p_triatlon, p_natacion, bonus, ajustes, total, pruebas, bonus_mensual, bonus_constancia,
          bonus_multideporte, disciplinas, finisher, finisher_falta)
  cross join lateral (values
    ('atletismo'::text, cc.p_atletismo), ('running'::text, cc.p_running), ('trail'::text, cc.p_trail),
    ('triatlon'::text, cc.p_triatlon), ('natacion'::text, cc.p_natacion)) d(disciplina, puntos)
  where d.puntos > 0
)
select c.disciplina, c.posicion, c.clave, c.atleta_id,
  case when public.es_staff() then c.nombre
       when public.juego_es_menor(a.fecha_nacimiento) and pj.autoriza_parental_en is null
       then split_part(btrim(coalesce(a.nombre, c.nombre)), ' ', 1)
            || case when coalesce(a.apellidos,'') <> '' then ' ' || left(btrim(a.apellidos), 1) || '.' else '' end
       else c.nombre end as nombre,
  c.categoria, c.puntos
from c
left join public.atletas a       on a.id = c.atleta_id
left join public.perfil_juego pj on pj.atleta_id = c.atleta_id;
