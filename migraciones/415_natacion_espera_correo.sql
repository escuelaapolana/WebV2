-- 415 · Natación · lista de espera: además del aviso en la app y el push, CORREO a
-- cada persona de la lista cuando se libera un hueco (Edge natacion-espera-correo).
-- Caso: Silvia (lista de espera del martes 19:30) se «avisó» el 20-oct pero no se
-- enteró: no tenía notificaciones. Mario: «que les llegue un aviso al correo».
-- Si el correo falla, el aviso de la app sigue saliendo (no rompe el «no voy»).
begin;
CREATE OR REPLACE FUNCTION public.natacion_espera_avisar(p_franja uuid, p_fecha date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_rec    record;
  v_n      integer := 0;
  v_franja text;
  v_cuando text := to_char(p_fecha, 'DD/MM');
  v_ids    uuid[] := '{}';
begin
  select coalesce(nullif(btrim(f.grupo), ''), 'Natación') || ' · ' || to_char(f.hora, 'HH24:MI')
    into v_franja
  from public.natacion_franjas f where f.id = p_franja;
  if v_franja is null then return 0; end if;

  for v_rec in
    select le.id, le.perfil_id
    from public.natacion_lista_espera le
    where le.franja_id = p_franja
      and le.activa
      and le.perfil_id is not null
      and (le.avisado_en is null or le.avisado_en < now() - interval '1 hour')
  loop
    perform public.avisos_registrar(
      'Se ha liberado un hueco en natación',
      'Hay sitio en ' || v_franja || ' el ' || v_cuando || '. El primero que reserve se lo queda.',
      'natacion/',
      'persona', 'entrenos',
      null, null, v_rec.perfil_id,
      'Lista de espera', 0, 0, null, null, 'importante', null, true, '{}'
    );
    perform public.avisos_cola_movil_poner('nat_hueco', v_rec.perfil_id);
    update public.natacion_lista_espera set avisado_en = now() where id = v_rec.id;
    v_ids := v_ids || v_rec.perfil_id;
    v_n := v_n + 1;
  end loop;
  -- (mig 415) Además, CORREO a cada uno (Edge natacion-espera-correo): el aviso
  -- de la app y el push no llegan a quien no tiene las notificaciones activadas.
  if v_n > 0 then
    begin
      perform public.cron_llamar_edge('natacion-espera-correo',
        jsonb_build_object('franja_id', p_franja, 'fecha', p_fecha, 'perfil_ids', to_jsonb(v_ids)), null);
    exception when others then
      raise warning 'natacion_espera_avisar: no se pudo pedir el correo: %', sqlerrm;
    end;
  end if;
  return v_n;
end;
$function$;
commit;
