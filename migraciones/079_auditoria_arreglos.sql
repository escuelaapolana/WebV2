-- ============================================================
-- 079 · Arreglos confirmados de la auditoría hostil
-- ------------------------------------------------------------
-- Tres agujeros que los equipos de ataque ejecutaron de verdad
-- (en transacción, revertido). Aquí se cierran.
-- Idempotente.
-- ============================================================

-- 1 · EL CUBO · clases gratis / usos infinitos (fraude económico)
-- ------------------------------------------------------------
-- `cubo_devolver_uso` y `cubo_consumir_uso` estaban abiertas a
-- cualquiera (anon/authenticated). Un atleta podía llamar
-- directamente a `cubo_devolver_uso` sobre su propia reserva y
-- recuperar el uso del bono SIN cancelar la clase: el saldo subía
-- 4→5 con la reserva aún activa. Repetido, el bono no se agota
-- nunca = el club regala clases.
-- La app NO llama a estas funciones (lo hacen los disparadores,
-- que corren como postgres), así que retirarles el permiso al
-- cliente no rompe nada.
revoke execute on function public.cubo_devolver_uso(uuid, text)   from anon, authenticated, public;
revoke execute on function public.cubo_consumir_uso(uuid, boolean) from anon, authenticated, public;

-- 2 · NOTICIAS · los borradores sin publicar se veían sin cuenta
-- ------------------------------------------------------------
-- Había dos políticas de lectura: una correcta (`publicada=true`)
-- y otra `USING(true)` que la anulaba, así que un anónimo veía
-- también los borradores. Fuera la de `true`; se queda la buena.
drop policy if exists "lectura publica" on public.noticias;
-- (la política «Noticias publicas visibles» con `publicada=true` se conserva)

-- 3 · EL CUBO · la vista de ocupación filtraba el APELLIDO del monitor
-- ------------------------------------------------------------
-- `cubo_clases_ocupacion` daba nombre y apellidos del monitor a
-- cualquier visitante sin cuenta, cuando el resto del club solo
-- enseña el nombre de pila (como `entrenadores_publicos`). Se deja
-- solo el nombre de pila.
create or replace view public.cubo_clases_ocupacion as
  select c.id as clase_id, c.fecha, c.hora_inicio, c.hora_fin, c.titulo,
         c.notas, c.activa, c.plazas,
         coalesce(nullif(btrim(split_part(coalesce(p.nombre, c.monitor_nombre), ' ', 1)), ''),
                  split_part(coalesce(c.monitor_nombre, ''), ' ', 1)) as monitor,
         cubo_clase_ocupadas(c.id)  as ocupadas,
         cubo_clase_en_espera(c.id) as en_espera,
         greatest(0, c.plazas - cubo_clase_ocupadas(c.id)) as libres
    from cubo_clases c
    left join perfiles p on p.id = c.monitor_id;
-- Que la vista nueva no herede permisos de más de Supabase:
revoke all on public.cubo_clases_ocupacion from anon, authenticated, public;
grant select on public.cubo_clases_ocupacion to anon, authenticated;
