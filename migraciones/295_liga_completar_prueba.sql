-- 295 · Liga: que el atleta COMPLETE/CORRIJA su propia prueba (añadir el enlace)
-- Mario: «yo pensaba que esto le salía a él y podía modificar». El atleta ve en
-- «Mis pruebas» que su prueba está pendiente o «no validada» (p.ej. «pendiente de
-- que mande el enlace» o «no apareces en la clasificación»), pero NO podía
-- arreglarlo → había que avisarle a mano. Con esto, el propio atleta añade el
-- enlace de la clasificación y la prueba vuelve a «pendiente» para que el club la
-- valide. Una pendiente ya la puede editar por RLS; una «no_validada» no (la RLS
-- exige estado='pendiente'), por eso va por esta función (SECURITY DEFINER) con
-- comprobación de que la prueba es suya (o de su hijo/a).

create or replace function public.liga_completar_prueba(p_id uuid, p_enlace text)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare v_mio boolean;
begin
  if coalesce(btrim(p_enlace), '') = '' then
    return jsonb_build_object('ok', false, 'error', 'Pon el enlace de la clasificación.');
  end if;
  select exists (
    select 1 from public.liga_participaciones lp
    where lp.id = p_id
      and lp.estado in ('pendiente', 'no_validada')
      and lp.atleta_id in (
        select a.id from public.atletas a
        where a.perfil_id = public.mi_perfil_id() or a.perfil_padre_id = public.mi_perfil_id()
      )
  ) into v_mio;
  if not v_mio then
    return jsonb_build_object('ok', false, 'error', 'No es tu prueba, o ya está validada.');
  end if;

  update public.liga_participaciones
     set enlace_clasificacion = btrim(p_enlace),
         estado = 'pendiente',
         validada = false,
         motivo_no_validada = null
   where id = p_id;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.liga_completar_prueba(uuid, text) to authenticated;
