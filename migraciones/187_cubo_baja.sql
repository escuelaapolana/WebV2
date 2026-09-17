-- 187 · Baja de la cuota de El Cubo (opción B: el padre la pide, el club la hace)
-- ------------------------------------------------------------
-- El padre no cancela su suscripción por su cuenta: la SOLICITA desde el
-- portal (marca `baja_solicitada`), y el club la ejecuta desde el panel
-- (cancela la suscripción en Stripe con la función `cubo-baja`). Así el club
-- controla las bajas. La solicitud la hace una función SECURITY DEFINER
-- (el padre no tiene UPDATE directo sobre cubo_altas).
-- ============================================================
begin;

alter table public.cubo_altas
  add column if not exists baja_solicitada timestamptz;

-- El padre pide la baja de SU cuota (si la tiene activa).
create or replace function public.cubo_baja_solicitar()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v public.cubo_altas;
begin
  update public.cubo_altas
     set baja_solicitada = coalesce(baja_solicitada, now())
   where perfil_id = public.mi_perfil_id()
     and suscripcion_estado = 'activa'
   returning * into v;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'sin_cuota_activa');
  end if;
  return jsonb_build_object('ok', true);
end; $$;

grant execute on function public.cubo_baja_solicitar() to authenticated;

commit;
