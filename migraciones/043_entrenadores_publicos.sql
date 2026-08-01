-- ============================================================
-- 043 · El nombre del entrenador, visible en la web pública
-- ------------------------------------------------------------
-- Decisión del club: en la página de horarios ("El día en el club")
-- se quiere ver QUIÉN entrena cada grupo. Hasta ahora un visitante sin
-- cuenta no podía leer nada de `perfiles`, así que el dato no salía.
--
-- Se abre lo MÍNIMO: una vista con el id y el nombre de quien lleva un
-- grupo. NO se expone el correo, ni el teléfono, ni el rol, ni ningún
-- otro dato personal, y solo aparece quien está asignado a un grupo
-- activo (nadie más del club).
-- ============================================================

create or replace view public.entrenadores_publicos as
  select distinct
         p.id,
         p.nombre
    from public.perfiles p
    join public.grupos g on g.entrenador_id = p.id
   where g.activo;

-- Vista curada a propósito (SECURITY DEFINER): enseña solo esas dos
-- columnas, así que puede leerla cualquiera que visite la web.
alter view public.entrenadores_publicos set (security_invoker = false);

grant select on public.entrenadores_publicos to anon, authenticated;
