-- 441 · El alta de socio engancha su cuenta a su ficha
-- ---------------------------------------------------------------------------
-- Andrés (23-oct): «David se hizo socio ayer, tiene que tener cuenta». La
-- tenía: el formulario de socio crea la cuenta al apuntarse (Edge socio-cuenta,
-- rol socio). Pero al crear la ficha desde el alta (alta_crear_ficha), la base
-- crea o reutiliza la ficha del atleta y NUNCA le pone `perfil_id`, así que la
-- cuenta y la ficha quedaban sueltas: el socio entraba y no veía lo suyo (ni
-- sus recibos para pagar). Pasaba en 4 de las 5 altas de socio por la web
-- (David López, Carlos Donat, Juan Rubio, María Aranzazu Coves); se enlazaron
-- a mano el mismo día.
--
-- Arreglo sin tocar alta_crear_ficha (270 líneas): un disparador en
-- altas_socio. Cuando el alta queda unida a su ficha (atleta_id), se busca la
-- cuenta con el MISMO correo y:
--   · se apunta en el alta (perfil_id), y
--   · se pone en la ficha SOLO si la ficha no tiene cuenta y esa cuenta no
--     está ya en otra ficha (nunca se pisa un enlace que exista).
-- Si algo falla, el alta se guarda igual: el enlace es un extra.
-- ---------------------------------------------------------------------------
begin;

create or replace function public.altas_socio_enlaza_cuenta()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_perfil uuid;
begin
  if new.atleta_id is null or nullif(btrim(coalesce(new.email, '')), '') is null then
    return new;
  end if;
  begin
    select p.id into v_perfil
      from public.perfiles p
     where lower(p.email) = lower(btrim(new.email))
     limit 1;
    if v_perfil is null then return new; end if;

    if new.perfil_id is null then new.perfil_id := v_perfil; end if;

    update public.atletas a
       set perfil_id = v_perfil
     where a.id = new.atleta_id
       and a.perfil_id is null
       and not exists (select 1 from public.atletas x where x.perfil_id = v_perfil);
  exception when others then
    raise warning 'altas_socio_enlaza_cuenta: no se pudo enlazar la cuenta: %', sqlerrm;
  end;
  return new;
end;
$$;
revoke all on function public.altas_socio_enlaza_cuenta() from public, anon, authenticated;

drop trigger if exists altas_socio_enlaza_cuenta on public.altas_socio;
create trigger altas_socio_enlaza_cuenta
  before insert or update of atleta_id on public.altas_socio
  for each row execute function public.altas_socio_enlaza_cuenta();

commit;
