-- 239 · Natación: límites por calle (cupos) + semáforo automático (con forzado)
--
-- "Plazas y vacantes" pasa a ser poner CUÁNTOS caben en cada calle. Las vacantes
-- y el semáforo que ve la web se calculan solos (cupo total − apuntados), y se
-- puede FORZAR a mano cuando haga falta. `semaforo` sigue siendo el valor que lee
-- la web (natacion_vacantes); ahora lo mantiene un trigger.

alter table public.natacion_franjas
  add column if not exists cupos jsonb not null default '{}'::jsonb;         -- {"C1":10,"C2":10,...}
alter table public.natacion_franjas
  add column if not exists semaforo_forzado text;                            -- null = automático
alter table public.natacion_franjas drop constraint if exists natacion_franjas_semaforo_forzado_check;
alter table public.natacion_franjas add constraint natacion_franjas_semaforo_forzado_check
  check (semaforo_forzado is null or semaforo_forzado = any (array['verde','ambar','rojo']));

-- Recalcula el semáforo efectivo de una franja y lo guarda en `semaforo`.
create or replace function public.natacion_recalcular_semaforo(p_franja uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v public.natacion_franjas; v_cupo int; v_ocup int; v_libre int; v_efectivo text;
begin
  select * into v from public.natacion_franjas where id = p_franja;
  if not found then return; end if;
  select coalesce(sum((value)::int), 0) into v_cupo
    from jsonb_each_text(coalesce(v.cupos, '{}'::jsonb))
   where value ~ '^[0-9]+$';
  if v.semaforo_forzado is not null then
    v_efectivo := v.semaforo_forzado;
  elsif v_cupo = 0 then
    v_efectivo := v.semaforo;                 -- sin límites: se respeta lo que hubiera
  else
    select count(*) into v_ocup from public.natacion_inscripciones where franja_id = p_franja and activa;
    v_libre := v_cupo - v_ocup;
    v_efectivo := case when v_libre <= 0 then 'rojo' when v_libre <= 2 then 'ambar' else 'verde' end;
  end if;
  update public.natacion_franjas set semaforo = v_efectivo
   where id = p_franja and semaforo is distinct from v_efectivo;
end $$;

-- Al cambiar las inscripciones, recalcular la(s) franja(s) afectada(s).
create or replace function public.natacion_ins_recalc() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if TG_OP = 'DELETE' then
    perform public.natacion_recalcular_semaforo(OLD.franja_id);
    return OLD;
  end if;
  perform public.natacion_recalcular_semaforo(NEW.franja_id);
  if TG_OP = 'UPDATE' and NEW.franja_id is distinct from OLD.franja_id then
    perform public.natacion_recalcular_semaforo(OLD.franja_id);
  end if;
  return NEW;
end $$;
drop trigger if exists natacion_ins_recalc_t on public.natacion_inscripciones;
create trigger natacion_ins_recalc_t
  after insert or update or delete on public.natacion_inscripciones
  for each row execute function public.natacion_ins_recalc();

-- Al cambiar cupos o el forzado, recalcular (no re-dispara: solo escribe `semaforo`).
create or replace function public.natacion_franja_recalc() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  perform public.natacion_recalcular_semaforo(NEW.id);
  return NEW;
end $$;
drop trigger if exists natacion_franja_recalc_t on public.natacion_franjas;
create trigger natacion_franja_recalc_t
  after update of cupos, semaforo_forzado on public.natacion_franjas
  for each row execute function public.natacion_franja_recalc();
