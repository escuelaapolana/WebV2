-- 293 · Fix del «Rechazar» de un alta del Cubo (cubo_alta_marcar)
-- Antes, la rama 'rechazada' hacía `grupo_id = v.grupo_id`, pero `cubo_altas`
-- NO tiene columna grupo_id → al rechazar un alta con ficha daba ERROR. Y
-- además ponía al atleta entero en `estado='baja'`, lo cual está mal si esa
-- persona es socio/escuela que solo vino a probar el Cubo.
--
-- Arreglo:
--   · El grupo del Cubo se resuelve por el HORARIO del alta (nombre del grupo).
--   · Se le saca SOLO de ese grupo (borra su fila en atleta_grupos; el trigger
--     ya recoloca el grupo_id de la ficha al que le quede, o a vacío).
--   · La ficha se da de baja SOLO si es puramente del Cubo (tipo_membresia
--     'cubo') y no le queda ningún otro grupo. Si es socio/escuela, no se toca.

create or replace function public.cubo_alta_marcar(p_id uuid, p_estado text)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v       public.cubo_altas;
  v_grupo uuid;
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
      -- Grupo del Cubo que correspondía a esta alta (por su horario = nombre).
      select g.id into v_grupo
        from public.grupos g
       where g.seccion = 'cubo' and g.nombre = v.horario
       limit 1;

      -- Sacarle SOLO de ese grupo del Cubo (no toca otros grupos suyos).
      -- El trigger de atleta_grupos recoloca el grupo_id de la ficha.
      if v_grupo is not null then
        delete from public.atleta_grupos
         where atleta_id = v.atleta_id and grupo_id = v_grupo;
      end if;

      -- Baja de la FICHA solo si es puramente del Cubo y ya no le queda
      -- ningún grupo (si es socio/escuela que probó el Cubo, se respeta).
      if coalesce((select a.tipo_membresia from public.atletas a where a.id = v.atleta_id), '') = 'cubo'
         and not exists (select 1 from public.atleta_grupos ag where ag.atleta_id = v.atleta_id) then
        update public.atletas set estado = 'baja' where id = v.atleta_id;
      end if;
    end if;
  end if;

  return jsonb_build_object('ok', true, 'id', v.id, 'estado', v.estado);
end;
$function$;
