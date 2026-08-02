-- ============================================================
-- 066 · Los menores no tienen perfil visible entre socios
-- ------------------------------------------------------------
-- Había dos cosas distintas usando el mismo interruptor, y eso
-- las hacía contradecirse:
--
--   1. Que el NOMBRE de un menor salga en las clasificaciones
--      públicas del club (récords, palmarés, ranking, Liga).
--      Eso sí se puede, con autorización de la familia. Es lo
--      que el club va a pedir desde el portal.
--
--   2. Que un menor tenga PERFIL VISIBLE para otros socios
--      (su ficha, sus medallas, su rango). Eso NO, y la
--      decisión es que no lo tiene NI CON permiso familiar:
--      sus medallas las ven su familia y su entrenador. Es la
--      conservadora y la que no da problemas.
--
-- La vista `miembros_juego` mezclaba las dos: dejaba visible a
-- un menor si tenía autorización parental. A partir de aquí un
-- menor no aparece, tenga o no autorización.
--
-- Efecto secundario bueno: `autoriza_parental_en` pasa a
-- significar UNA sola cosa —el permiso para las clasificaciones—
-- que es como ya lo usan `ranking_marcas` y la Liga.
-- Idempotente.
-- ============================================================

create or replace view public.miembros_juego as
  select a.id as atleta_id,
         case
           when coalesce(btrim(to_jsonb(p.*) ->> 'nombre_publico'), '') <> ''
             then btrim(to_jsonb(p.*) ->> 'nombre_publico')
           else btrim((a.nombre || ' ') || coalesce(a.apellidos, ''))
         end as nombre,
         to_jsonb(p.*) ->> 'foto_ruta' as foto_ruta,
         pj.puntos,
         (select count(*) from atleta_medallas am where am.atleta_id = a.id) as medallas,
         (select count(*) from reto_logros   rl where rl.atleta_id = a.id) as retos,
         (select jr.nombre
            from juego_rangos jr
           where jr.desde_puntos <= pj.puntos
           order by jr.desde_puntos desc
           limit 1) as rango
    from perfil_juego pj
    join atletas a on a.id = pj.atleta_id
    left join perfiles p on p.id = a.perfil_id
   where pj.participa
     and coalesce((to_jsonb(p.*) ->> 'perfil_visible')::boolean, true)
     and coalesce(a.estado, 'activo') <> 'baja'
     -- Aquí estaba el `OR pj.autoriza_parental_en is not null`: fuera.
     and public.juego_es_menor(a.fecha_nacimiento) = false;
