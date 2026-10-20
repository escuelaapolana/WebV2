-- 408 · «Eliminar» una alta del Cubo fallaba siempre: «column "grupo_id" does not
-- exist» (cubo_altas ya no tiene grupo_id: el grupo es grupos.nombre = horario).
-- Además ponía a la persona de BAJA aunque tuviera otra alta (un duplicado).
-- Ahora: la saca del grupo de esa alta (atleta_grupos) y solo la da de baja si no
-- le queda ninguna otra alta del Cubo pendiente o aprobada. Lo demás, igual.
begin;
create or replace function public.cubo_alta_eliminar(p_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_sub text; v_atleta uuid; v_horario text; v_filas int; v_otra boolean;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede borrar altas del Cubo' using errcode = '42501';
  end if;
  select stripe_subscription_id, atleta_id, horario into v_sub, v_atleta, v_horario
    from public.cubo_altas where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'no-esta');
  end if;
  if v_sub is not null then
    return jsonb_build_object('ok', false, 'motivo', 'con-suscripcion',
      'mensaje', 'Esta persona tiene la cuota activa. Dale antes a «Dar de baja» (cancela el cobro) y luego bórrala.');
  end if;
  if v_atleta is not null then
    select exists (select 1 from public.cubo_altas o
                    where o.atleta_id = v_atleta and o.id <> p_id
                      and coalesce(o.estado,'pendiente') in ('pendiente','aprobada')) into v_otra;
    if not v_otra then
      -- fuera del grupo del Cubo de esta alta y de baja (como antes)
      delete from public.atleta_grupos ag using public.grupos g
       where ag.atleta_id = v_atleta and g.id = ag.grupo_id and g.seccion = 'cubo' and g.nombre = v_horario;
      update public.atletas set estado = 'baja' where id = v_atleta and tipo_membresia = 'cubo';
    end if;
  end if;
  delete from public.cubo_altas where id = p_id;
  get diagnostics v_filas = row_count;
  return jsonb_build_object('ok', v_filas > 0);
end $$;
commit;
