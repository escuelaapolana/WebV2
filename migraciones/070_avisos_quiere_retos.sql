-- ============================================================
-- 070 · avisos_quiere(): retos apagado también sin ficha
-- ------------------------------------------------------------
-- La 069 arregló la tabla, pero esta función respondía «sí» a
-- los avisos de retos cuando la persona todavía no tenía fila
-- de preferencias: quien nunca hubiera abierto la pantalla de
-- avisos los habría recibido igual, sin haberlos pedido.
-- Idempotente.
-- ============================================================

CREATE OR REPLACE FUNCTION public.avisos_quiere(p_perfil uuid, p_categoria text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case p_categoria
    when 'entrenos'      then coalesce((select p.entrenos      from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    when 'competiciones' then coalesce((select p.competiciones from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    when 'pagos'         then coalesce((select p.pagos         from public.avisos_preferencias p where p.perfil_id = p_perfil), true)
    when 'noticias'      then coalesce((select p.noticias      from public.avisos_preferencias p where p.perfil_id = p_perfil), false)
    when 'retos'         then coalesce((select p.retos         from public.avisos_preferencias p where p.perfil_id = p_perfil), false)
    else false
  end;
$function$;
