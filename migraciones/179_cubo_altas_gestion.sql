-- 179 · Gestión de las altas de El Cubo (aprobar / rechazar)
-- ------------------------------------------------------------
-- Enlaza cada alta con la cuenta que se creó (perfil_id / atleta_id) y
-- añade cubo_alta_marcar(): el club aprueba o rechaza, y eso se refleja
-- en la ficha del atleta (aprobada → activo · rechazada → baja).
-- Solo admin.
-- ============================================================

begin;

alter table public.cubo_altas
  add column if not exists perfil_id uuid,
  add column if not exists atleta_id uuid;

create or replace function public.cubo_alta_marcar(p_id uuid, p_estado text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v public.cubo_altas;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede gestionar las altas del Cubo.' using errcode = '42501';
  end if;
  if p_estado not in ('pendiente','aprobada','rechazada') then
    raise exception 'Estado no válido: %', p_estado using errcode = 'P0001';
  end if;

  update public.cubo_altas set estado = p_estado where id = p_id returning * into v;
  if not found then
    raise exception 'Esa alta ya no está.' using errcode = 'P0001';
  end if;

  -- Se refleja en la ficha del atleta, si el alta está enlazada.
  if v.atleta_id is not null then
    if p_estado = 'aprobada' then
      update public.atletas set estado = 'activo' where id = v.atleta_id and estado = 'prueba';
    elsif p_estado = 'rechazada' then
      update public.atletas set estado = 'baja' where id = v.atleta_id;
    end if;
  end if;

  return jsonb_build_object('ok', true, 'id', v.id, 'estado', v.estado);
end;
$function$;

grant execute on function public.cubo_alta_marcar(uuid, text) to authenticated;

commit;
