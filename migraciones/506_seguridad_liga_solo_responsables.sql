-- 506 · Liga solo para admin y responsables de liga (comunicación: Mario, José Luis).
-- Antes es_staff(): cualquier entrenador/junta cambiaba o borraba resultados y veía contactos.
-- Decisión de Andrés 1-nov-2026. Las ramas de atleta/familia (proponer, apuntarse) no cambian.

alter policy "liga ajustes gestiona el equipo" on public.liga_ajustes_puntos
  using ((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)))
  with check ((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)));

alter policy "liga baremo gestiona el equipo" on public.liga_baremo
  using ((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)))
  with check ((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)));

alter policy "liga categorias gestiona el equipo" on public.liga_categorias
  using ((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)))
  with check ((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)));

alter policy "liga participaciones alta del equipo" on public.liga_participaciones
  with check (((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)) OR ( SELECT es_responsable_liga() AS es_responsable_liga) OR ((estado = 'pendiente'::text) AND (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = ( SELECT mi_perfil_id() AS mi_perfil_id)) OR (atletas.perfil_padre_id = ( SELECT mi_perfil_id() AS mi_perfil_id))))))));

alter policy "liga participaciones borra el equipo" on public.liga_participaciones
  using (((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)) OR ( SELECT es_responsable_liga() AS es_responsable_liga) OR ((estado = 'pendiente'::text) AND (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = ( SELECT mi_perfil_id() AS mi_perfil_id)) OR (atletas.perfil_padre_id = ( SELECT mi_perfil_id() AS mi_perfil_id))))))));

alter policy "liga participaciones cambia el equipo" on public.liga_participaciones
  using (((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)) OR ( SELECT es_responsable_liga() AS es_responsable_liga) OR ((estado = 'pendiente'::text) AND (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = ( SELECT mi_perfil_id() AS mi_perfil_id)) OR (atletas.perfil_padre_id = ( SELECT mi_perfil_id() AS mi_perfil_id))))))))
  with check (((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)) OR ( SELECT es_responsable_liga() AS es_responsable_liga) OR ((estado = 'pendiente'::text) AND (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = ( SELECT mi_perfil_id() AS mi_perfil_id)) OR (atletas.perfil_padre_id = ( SELECT mi_perfil_id() AS mi_perfil_id))))))));

alter policy "liga participaciones lectura" on public.liga_participaciones
  using (((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)) OR ( SELECT es_responsable_liga() AS es_responsable_liga) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))));

alter policy "liga propuestas alta" on public.liga_propuestas_prueba
  with check (((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)) OR (propuesta_por IS NULL) OR (propuesta_por = ( SELECT mi_perfil_id() AS mi_perfil_id))));

alter policy "liga propuestas borra" on public.liga_propuestas_prueba
  using (((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)) OR ((estado = 'pendiente'::text) AND (propuesta_por = ( SELECT mi_perfil_id() AS mi_perfil_id)))));

alter policy "liga propuestas gestiona el equipo" on public.liga_propuestas_prueba
  using ((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)))
  with check ((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)));

alter policy "liga propuestas lectura" on public.liga_propuestas_prueba
  using (((( SELECT es_admin() AS es_admin) OR ( SELECT es_responsable_liga() AS es_responsable_liga)) OR (propuesta_por = ( SELECT mi_perfil_id() AS mi_perfil_id))));

CREATE OR REPLACE FUNCTION public.liga_atletas_nombres()
 RETURNS TABLE(id uuid, nombre text, apellidos text, fecha_nacimiento date)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select a.id, a.nombre, a.apellidos, a.fecha_nacimiento
  from public.atletas a
  where public.es_admin() or public.es_responsable_liga()
  order by a.apellidos, a.nombre
$function$;

CREATE OR REPLACE FUNCTION public.liga_contactos()
 RETURNS TABLE(atleta_id uuid, telefono text, email text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select a.id,
         coalesce(nullif(btrim(a.telefono),''), nullif(btrim(p.telefono),''), nullif(btrim(a.telefono_tutor),'')),
         coalesce(nullif(btrim(a.email),''), nullif(btrim(p.email),''), nullif(btrim(a.email_tutor),''))
    from public.atletas a
    left join public.perfiles p on p.id = a.perfil_id
   where (public.es_admin() or public.es_responsable_liga())
     and exists (select 1 from public.liga_participaciones lp
                   join public.liga_ediciones e on e.id = lp.edicion_id and e.activa
                  where lp.atleta_id = a.id)
$function$;
