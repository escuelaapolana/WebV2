-- 290 · El Cubo: tracker de prueba
-- Dos marcas que Andrés lleva a mano cuando alguien de prueba decide quedarse.
-- OJO: ninguna de las dos quita la prueba. Lo que quita la prueba es PAGAR
-- (suscripcion_estado='activa'), igual que antes. Esto es solo seguimiento para
-- no perderse (¿le escribí?, ¿lo metí al WhatsApp?, ¿le abrí el cobro?).

alter table public.cubo_altas
  add column if not exists confirmado_sigue timestamptz,
  add column if not exists en_whatsapp boolean not null default false;

comment on column public.cubo_altas.confirmado_sigue is
  'Cuándo el de prueba confirmó que se queda (seguimiento; NO quita la prueba, pagar sí).';
comment on column public.cubo_altas.en_whatsapp is
  'Marcado a mano: ya está en el grupo de WhatsApp del Cubo.';

-- Marca/desmarca un paso del tracker. Gestor del Cubo o admin.
create or replace function public.cubo_prueba_paso(p_id uuid, p_paso text, p_on boolean)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
begin
  if not public.cubo_es_gestor() then
    return jsonb_build_object('ok', false, 'error', 'Sin permiso');
  end if;

  if p_paso = 'confirmado' then
    update public.cubo_altas
       set confirmado_sigue = case when p_on then now() else null end
     where id = p_id;
  elsif p_paso = 'whatsapp' then
    update public.cubo_altas
       set en_whatsapp = coalesce(p_on, false)
     where id = p_id;
  else
    return jsonb_build_object('ok', false, 'error', 'paso no válido');
  end if;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'no encontrada');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.cubo_prueba_paso(uuid, text, boolean) to authenticated;
