-- ============================================================
-- 062 · La clasificación pública de la Liga y los menores
-- ------------------------------------------------------------
-- La página /liga/ es pública y enseñaba NOMBRE Y APELLIDOS
-- COMPLETOS de cada participante, sin mirar la edad ni pedir
-- autorización de la familia. Con la Liga en marcha, eso deja
-- en Internet una lista de niños del club con nombre, apellidos
-- y franja de edad, actualizada sola.
--
-- En el juego de retos esto ya estaba bien resuelto: un menor
-- solo aparece si consta la autorización parental. Aquí se
-- aplica el mismo criterio, que además es el que el club ha
-- decidido pedir a las familias desde el portal.
--
--   · Persona adulta            → nombre completo
--   · Menor CON autorización    → nombre completo
--   · Menor SIN autorización    → nombre de pila e inicial
--   · Sin fecha de nacimiento   → se trata como menor
--                                 (lo decide juego_es_menor)
--
-- Idempotente.
-- ============================================================

create or replace function public.liga_clasificacion_publica_fn()
returns table(posicion bigint, nombre text, categoria text, categoria_orden integer,
              p_atletismo integer, p_running integer, p_trail integer, p_triatlon integer,
              p_natacion integer, bonus integer, ajustes integer, total integer,
              pruebas integer, finisher boolean)
language sql
stable security definer
set search_path to 'public'
as $function$
  select rank() over (order by c.total desc, c.pruebas desc, c.nombre) as posicion,
         case
           when public.juego_es_menor(a.fecha_nacimiento)
                and pj.autoriza_parental_en is null
           then split_part(btrim(coalesce(a.nombre, c.nombre)), ' ', 1)
                || case when coalesce(a.apellidos, '') <> ''
                        then ' ' || left(btrim(a.apellidos), 1) || '.'
                        else '' end
           else c.nombre
         end                                                        as nombre,
         c.categoria, c.categoria_orden,
         c.p_atletismo, c.p_running, c.p_trail, c.p_triatlon, c.p_natacion,
         c.bonus, c.ajustes, c.total, c.pruebas, c.finisher
    from public.liga_clasificacion(public.liga_edicion_activa()) c
    left join public.atletas a      on a.id  = c.atleta_id
    left join public.perfil_juego pj on pj.atleta_id = c.atleta_id;
$function$;
