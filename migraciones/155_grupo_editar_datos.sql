-- ============================================================
-- 155 · «Editar» de Grupos podía abrir de nuevo
-- ------------------------------------------------------------
-- QUÉ PASABA
--   El botón «Editar» de Grupos leía la fila entera del grupo, y ahí
--   va `whatsapp_enlace`, el enlace del grupo de WhatsApp de las
--   familias. Esa columna, A PROPÓSITO, no tiene permiso de lectura
--   para el cliente: así el enlace no lo ve cualquiera. Pero se quedó
--   sin darle permiso NI a quien tiene papeles, así que «Editar»
--   fallaba con «permission denied for table grupos» para todos,
--   administración incluida.
--
-- CÓMO SE ARREGLA
--   No se puede dar permiso de esa columna a «authenticated» a secas,
--   porque los grupos son de lectura pública y entonces el WhatsApp lo
--   vería cualquier usuario logueado. Se da por una función con llave
--   de definidor que ANTES comprueba el papel: administración, o la
--   escuela para sus secciones. Solo a esos les devuelve la fila (con
--   el WhatsApp). Es el mismo camino que ya usa `alta_enlace_familias`.
-- ============================================================

create or replace function public.grupo_editar_datos(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v jsonb;
begin
  if not (public.es_admin() or public.es_escuela()) then
    raise exception 'Solo administración o la escuela pueden editar grupos';
  end if;

  select to_jsonb(g) into v
  from public.grupos g
  where g.id = p_id
    and (public.es_admin() or g.seccion = any (public.escuela_secciones()));

  return v; -- null si no existe o no es de su sección
end;
$$;

grant execute on function public.grupo_editar_datos(uuid) to authenticated;
