-- 502 · Academia · Carga y contenidos: las correcciones de lectura («Revisar lectura…»)
-- se pueden guardar también en Academia AC98 real. Análisis y Carga ya se activaron con
-- el grupo real (commit f96ea86c), pero esta función seguía aceptando solo grupos de
-- prueba. El permiso sigue siendo academia_puede(grupo) y el historial por versión, igual.
CREATE OR REPLACE FUNCTION public.academia_estructura_guardar(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.sesiones%rowtype; e public.plan_filas_estructura%rowtype; v_ver int := nullif(p->>'sesion_version','')::int;
begin
  select * into s from public.sesiones where id = nullif(p->>'sesion_id','')::uuid;
  if s.id is null then raise exception 'Esa sesión no existe.'; end if;
  if not public.academia_puede(s.grupo_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if v_ver is null or nullif(p->>'fila_id','') is null or jsonb_typeof(p->'estructura') <> 'object' then raise exception 'Faltan datos de la fila.'; end if;
  if coalesce(p->>'estado','revisada') not in ('revisada','manual') then raise exception 'Estado no válido.'; end if;
  select * into e from public.plan_filas_estructura where sesion_id = s.id and sesion_version = v_ver and fila_id = p->>'fila_id' for update;
  if e.id is null then
    insert into public.plan_filas_estructura (grupo_id, sesion_id, sesion_version, fila_id, huella, estructura, estado, nota)
    values (s.grupo_id, s.id, v_ver, p->>'fila_id', coalesce(p->>'huella',''), p->'estructura', coalesce(p->>'estado','revisada'), nullif(btrim(coalesce(p->>'nota','')),''))
    returning * into e;
  else
    if nullif(p->>'version_base','')::int is distinct from e.version then
      return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado la lectura de esta fila: vuelve a abrirla. No se ha pisado nada.');
    end if;
    update public.plan_filas_estructura set huella = coalesce(p->>'huella', huella), estructura = p->'estructura', estado = coalesce(p->>'estado','revisada'),
           nota = nullif(btrim(coalesce(p->>'nota','')),'')
     where id = e.id returning * into e;
  end if;
  return jsonb_build_object('ok', true, 'estructura', to_jsonb(e));
end $function$;
