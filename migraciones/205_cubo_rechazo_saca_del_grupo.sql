-- 205 · Rechazar o eliminar un alta del Cubo SACA a la persona del grupo
-- Al apuntarse al Cubo se crea ya la ficha de atleta en el grupo del horario
-- elegido (estado 'prueba'). Si el club rechaza o elimina esa solicitud, la
-- persona tiene que salir del grupo para que la entrenadora no la siga viendo.
-- Antes: rechazar la ponía en 'baja' pero la dejaba en el grupo; eliminar no
-- tocaba la ficha. Ahora: baja + se le quita el grupo del Cubo (solo si su
-- grupo principal ES el de esta alta, para no tocar a un niño de la escuela
-- que además venga al Cubo).

create or replace function public.cubo_alta_marcar(p_id uuid, p_estado text)
 returns jsonb
 language plpgsql security definer set search_path to 'public'
as $function$
declare v public.cubo_altas;
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

  if v.atleta_id is not null then
    if p_estado = 'aprobada' then
      update public.atletas set estado = 'activo' where id = v.atleta_id and estado = 'prueba';
    elsif p_estado = 'rechazada' then
      -- Baja y fuera del grupo del Cubo (si es su grupo principal).
      update public.atletas
         set estado = 'baja',
             grupo_id = case when grupo_id = v.grupo_id then null else grupo_id end
       where id = v.atleta_id;
    end if;
  end if;

  return jsonb_build_object('ok', true, 'id', v.id, 'estado', v.estado);
end;
$function$;

create or replace function public.cubo_alta_eliminar(p_id uuid)
 returns jsonb
 language plpgsql security definer set search_path to 'public'
as $function$
declare v_sub text; v_atleta uuid; v_grupo uuid; v_filas int;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede borrar altas del Cubo' using errcode = '42501';
  end if;
  select stripe_subscription_id, atleta_id, grupo_id into v_sub, v_atleta, v_grupo
    from public.cubo_altas where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'no-esta');
  end if;
  if v_sub is not null then
    return jsonb_build_object('ok', false, 'motivo', 'con-suscripcion',
      'mensaje', 'Esta persona tiene la cuota activa. Dale antes a «Dar de baja» (cancela el cobro) y luego bórrala.');
  end if;
  -- Saca a la persona del grupo del Cubo antes de borrar la solicitud.
  if v_atleta is not null then
    update public.atletas
       set estado = 'baja',
           grupo_id = case when grupo_id = v_grupo then null else grupo_id end
     where id = v_atleta;
  end if;
  delete from public.cubo_altas where id = p_id;
  get diagnostics v_filas = row_count;
  return jsonb_build_object('ok', v_filas > 0);
end;
$function$;
