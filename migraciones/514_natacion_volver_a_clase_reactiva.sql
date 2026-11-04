-- 514 · Natación: volver a meter a alguien en una clase lo REACTIVA.
-- Caso Kheira Ikram Farah (4-nov-2026): Mario la dio de baja (ficha en «baja»,
-- clases y código de acceso desactivados) y a los dos minutos la volvió a poner
-- en sus clases del martes y el viernes. Las clases quedaron bien, pero la ficha
-- seguía «de baja» y el código desactivado, y en Cuotas y cobros salía «de baja»
-- sin forma de activarla. Ahora, al quedar activa una inscripción (alta nueva,
-- desde la ficha, desde Gestión o reactivando una vieja):
--   · si la ficha estaba de baja → vuelve a «activo» (fecha_baja la limpia
--     atletas_sella_baja), y
--   · sus códigos de acceso de natación vuelven a estar activos.
create or replace function public.natacion_ins_reactiva()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if new.atleta_id is null or not new.activa then return new; end if;
  if tg_op = 'UPDATE' and old.activa and old.atleta_id is not distinct from new.atleta_id then return new; end if;

  if exists (select 1 from public.atletas where id = new.atleta_id and estado = 'baja') then
    perform set_config('apolana.via_natacion', '1', true);
    update public.atletas set estado = 'activo', updated_at = now() where id = new.atleta_id;
    perform set_config('apolana.via_natacion', '', true);
  end if;
  update public.natacion_accesos set activo = true
   where atleta_id = new.atleta_id and not activo;
  return new;
end $$;
revoke execute on function public.natacion_ins_reactiva() from public, anon, authenticated;

drop trigger if exists natacion_ins_reactiva_t on public.natacion_inscripciones;
create trigger natacion_ins_reactiva_t
  after insert or update of activa, atleta_id on public.natacion_inscripciones
  for each row execute function public.natacion_ins_reactiva();
