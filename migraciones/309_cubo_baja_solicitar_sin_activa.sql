-- 309 · «Solicitar la baja» del Cubo también para quien aún NO ha activado
-- Antes cubo_baja_solicitar solo valía con suscripción activa, así que quien
-- tenía el cobro abierto pero no había pagado (de prueba) no podía pedir la
-- baja desde el portal (le pasó a Juan). Ahora vale con cuota activa O con el
-- cobro abierto. Solo marca la solicitud (baja_solicitada); el club la tramita.
create or replace function public.cubo_baja_solicitar()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v public.cubo_altas;
begin
  update public.cubo_altas
     set baja_solicitada = coalesce(baja_solicitada, now())
   where perfil_id = public.mi_perfil_id()
     and (suscripcion_estado = 'activa' or cobro_abierto = true)
   returning * into v;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'sin_cuota');
  end if;
  return jsonb_build_object('ok', true);
end; $$;
grant execute on function public.cubo_baja_solicitar() to authenticated;
