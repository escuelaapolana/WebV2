-- 279 · Natación: enlazar una ficha suelta (sin acceso) desde la app.
-- Las faltas se guardan por acceso_id; si una inscripción no tiene acceso
-- (p. ej. importada a mano), no se le puede marcar falta. Este RPC le crea
-- (o reutiliza) su acceso y engancha todas sus fichas sueltas, para que el
-- responsable lo resuelva él mismo sin tocar la base. Caso que lo motivó:
-- Azucena (ficha importada sin código de acceso).

create or replace function public.natacion_enlazar_ficha(p_inscripcion uuid)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
declare v_atleta uuid; v_nombre text; v_acceso uuid; v_codigo text;
begin
  if not (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;

  select atleta_id, nombre into v_atleta, v_nombre
    from public.natacion_inscripciones where id = p_inscripcion;
  if not found then return jsonb_build_object('ok', false, 'msg', 'Ficha no encontrada.'); end if;

  -- ¿Ya tiene acceso por su atleta? (lo reutiliza; no duplica)
  if v_atleta is not null then
    select id into v_acceso from public.natacion_accesos
      where atleta_id = v_atleta and activo limit 1;
  end if;

  -- Si no, crea uno con código único (igual que el alta de nadador).
  if v_acceso is null then
    loop
      v_codigo := upper(substr(md5(random()::text), 1, 8));
      exit when not exists (select 1 from public.natacion_accesos where codigo = v_codigo);
    end loop;
    insert into public.natacion_accesos (codigo, nombre, atleta_id, activo)
    values (v_codigo, upper(coalesce(nullif(btrim(v_nombre), ''), '(sin nombre)')), v_atleta, true)
    returning id into v_acceso;
  end if;

  -- Engancha esta ficha; si tiene atleta, también sus otras fichas sueltas.
  if v_atleta is not null then
    update public.natacion_inscripciones set acceso_id = v_acceso
     where atleta_id = v_atleta and acceso_id is null;
  else
    update public.natacion_inscripciones set acceso_id = v_acceso
     where id = p_inscripcion and acceso_id is null;
  end if;

  return jsonb_build_object('ok', true);
end $function$;

grant execute on function public.natacion_enlazar_ficha(uuid) to authenticated;
