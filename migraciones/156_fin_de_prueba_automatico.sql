-- ============================================================
-- 156 · La fecha de fin de prueba se pone sola (2 semanas)
-- ------------------------------------------------------------
-- QUÉ HACE
--   Cuando una ficha pasa a estado «prueba», si no tiene puesta la
--   fecha en que acaba la prueba, se le ponen 2 semanas (14 días)
--   desde hoy. Y cuando deja de estar en prueba (se queda = activo, o
--   se va = baja), esa fecha se borra, que ya no pinta nada.
--
-- POR QUÉ EN LA BASE Y NO EN LA PANTALLA
--   Así vale para todos los caminos por igual: lo cambies a mano en el
--   panel de Atletas, o —más adelante— cuando la inscripción cree la
--   ficha en prueba ella sola. Un único sitio, sin repetir la regla.
--
--   Las 2 semanas son el caso normal (niños: cuatro entrenos; mayores:
--   tres días por semana). Si a alguien hay que darle más, se le puede
--   poner otra fecha a mano y el disparador la respeta (solo actúa si
--   está vacía).
-- ============================================================

create or replace function public.atletas_fin_de_prueba()
returns trigger
language plpgsql
as $$
begin
  if new.estado = 'prueba' then
    if new.fecha_prueba_fin is null then
      new.fecha_prueba_fin := current_date + 14;
    end if;
  else
    -- Fuera de prueba, la fecha no aplica.
    new.fecha_prueba_fin := null;
  end if;
  return new;
end;
$$;

drop trigger if exists atletas_fin_de_prueba on public.atletas;
create trigger atletas_fin_de_prueba
before insert or update on public.atletas
for each row execute function public.atletas_fin_de_prueba();
