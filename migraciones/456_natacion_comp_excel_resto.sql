-- 456 · Natación · Competiciones: el Excel saca la lista que estás viendo
-- ---------------------------------------------------------------------------
-- Paloma (28-oct-2026, por Mario): «cuando estoy en "Resto de la categoría" el
-- Excel me saque a los niños que están ahí, y cuando estoy en Convocados, los
-- que ya están. Ahora saca los convocados, pero los otros no.»
--
-- natacion_comp_excel lleva ahora `p_que`:
--   'convocados' (por defecto, lo de siempre) · 'resto' = los de la categoría
--   que siguen en la escuela y NO están convocados (lo mismo que la pestaña).
-- De paso, la licencia se mira en la temporada de la jornada (antes iba fija
-- '2026/27').
-- ---------------------------------------------------------------------------
begin;

drop function if exists public.natacion_comp_excel(uuid);

create or replace function public.natacion_comp_excel(p_jornada uuid, p_que text default 'convocados')
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare j public.natacion_comp_jornadas;
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into j from public.natacion_comp_jornadas where id = p_jornada;
  if not found then raise exception 'Esa jornada ya no existe.' using errcode = 'P0001'; end if;

  if p_que = 'resto' then
    return coalesce((
      with cats as (select * from public.natacion_comp_categorias c where c.temporada = j.temporada and c.clave = any(j.categorias)),
      encat as (select a.id from public.atletas a
                 where a.id in (select public._natacion_comp_ninos())
                   and exists (select 1 from cats c where extract(year from a.fecha_nacimiento) between c.desde_anio and c.hasta_anio))
      select jsonb_agg(jsonb_build_object('nombre', a.nombre, 'apellidos', a.apellidos, 'sexo', a.sexo, 'fecha_nacimiento', a.fecha_nacimiento,
          'dni', a.dni, 'sip', fl.sip, 'foto_carnet', fl.foto_carnet, 'nombre_tutor', a.nombre_tutor, 'dni_tutor', fl.dni_tutor,
          'telefono_tutor', a.telefono_tutor, 'email_tutor', a.email_tutor, 'direccion', a.direccion,
          'nivel', (select string_agg(distinct i.nivel, ', ') from public.natacion_inscripciones i where i.atleta_id = a.id and i.activa),
          'licencia', coalesce(l.tramitada, false)) order by a.apellidos, a.nombre)
      from public.atletas a
      left join public.natacion_licencias l on l.atleta_id = a.id and l.temporada = j.temporada
      left join public.natacion_ficha_licencia fl on fl.atleta_id = a.id
      where a.id in (select id from encat)
        and not exists (select 1 from public.natacion_comp_convocados x
                         where x.jornada_id = j.id and x.atleta_id = a.id and x.convocado)), '[]');
  end if;

  return coalesce((select jsonb_agg(jsonb_build_object('nombre', a.nombre, 'apellidos', a.apellidos, 'sexo', a.sexo, 'fecha_nacimiento', a.fecha_nacimiento,
      'dni', a.dni, 'sip', fl.sip, 'foto_carnet', fl.foto_carnet, 'nombre_tutor', a.nombre_tutor, 'dni_tutor', fl.dni_tutor,
      'telefono_tutor', a.telefono_tutor, 'email_tutor', a.email_tutor, 'direccion', a.direccion,
      'pruebas', x.pruebas, 'respuesta', x.respuesta, 'nota', x.nota, 'licencia', coalesce(l.tramitada, false)) order by a.apellidos, a.nombre)
    from public.natacion_comp_convocados x join public.atletas a on a.id = x.atleta_id
    left join public.natacion_licencias l on l.atleta_id = a.id and l.temporada = j.temporada
    left join public.natacion_ficha_licencia fl on fl.atleta_id = a.id
    where x.jornada_id = p_jornada and x.convocado), '[]');
end $function$;

revoke all on function public.natacion_comp_excel(uuid, text) from public, anon;
grant execute on function public.natacion_comp_excel(uuid, text) to authenticated, service_role;

commit;
