-- 416 · Natación · lista de espera: correo de confirmación al apuntarse («ya estás en la
-- lista; te llegará otro correo cuando quede un hueco»). Andrés, 21-oct-2026: «un correo
-- cuando lo solicita y otro cuando queda vacante, para no gastar SMS». Si el correo
-- falla, apuntarse sigue funcionando.
begin;
CREATE OR REPLACE FUNCTION public.natacion_espera_apuntarse(p_franja uuid, p_atleta uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_perfil uuid := public.mi_perfil_id();
  v_nombre text;
  v_id     uuid;
begin
  if v_perfil is null then
    raise exception 'Entra en tu cuenta para apuntarte a la lista de espera.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.natacion_franjas where id = p_franja and activa) then
    raise exception 'Esa franja no existe.' using errcode = 'P0001';
  end if;
  -- El atleta solo si es suyo (o de un hijo); si no, se guarda sin atleta.
  if p_atleta is not null and not exists (
    select 1 from public.atletas a
    where a.id = p_atleta and (a.perfil_id = v_perfil or a.perfil_padre_id = v_perfil)
  ) then
    p_atleta := null;
  end if;

  select nullif(btrim(coalesce(p.nombre, '') || ' ' || coalesce(p.apellidos, '')), '')
    into v_nombre from public.perfiles p where p.id = v_perfil;
  if p_atleta is not null then
    select nullif(btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')), '')
      into v_nombre from public.atletas a where a.id = p_atleta;
  end if;

  update public.natacion_lista_espera
     set activa = true,
         nombre = coalesce(v_nombre, nombre),
         avisado_en = null
   where franja_id = p_franja and perfil_id = v_perfil
     and coalesce(atleta_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(p_atleta, '00000000-0000-0000-0000-000000000000'::uuid)
   returning id into v_id;

  if v_id is null then
    insert into public.natacion_lista_espera (franja_id, perfil_id, atleta_id, nombre, activa)
    values (p_franja, v_perfil, p_atleta, v_nombre, true)
    returning id into v_id;
  end if;

  -- (mig 416) Correo de confirmación: «ya estás en la lista de espera» (Andrés, 21-oct).
  begin
    perform public.cron_llamar_edge('natacion-espera-correo',
      jsonb_build_object('tipo', 'apuntado', 'franja_id', p_franja, 'perfil_ids', jsonb_build_array(v_perfil)), null);
  exception when others then
    raise warning 'natacion_espera_apuntarse: no se pudo pedir el correo: %', sqlerrm;
  end;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$function$;
commit;
