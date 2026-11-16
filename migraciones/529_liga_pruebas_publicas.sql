-- 529 · Liga: las pruebas de cada persona, en público
--
-- En la web (/liga/) se busca a alguien y solo salía su fila de la
-- clasificación. José Luis: «la gente me pide lo que tiene una persona».
-- Esta función devuelve las pruebas VALIDADAS de la edición activa con los
-- puntos que cuentan de verdad (regla de las dos mejores por competición en
-- atletismo y natación; relevos fuera), y el nombre tal y como sale en la
-- clasificación pública (menores sin autorización: nombre + inicial), para
-- que la página las cuelgue de su fila.

create or replace function public.liga_pruebas_publicas_fn()
returns table(nombre text, fecha date, competicion text, disciplina text,
              modalidad text, puntos integer, cuenta boolean)
language sql
stable
security definer
set search_path to 'public'
as $$
  with base as (
    select pa.id,
           coalesce(pa.atleta_id::text, 'libre:' || lower(btrim(pa.nombre_libre))) as clave,
           pa.atleta_id,
           coalesce(nullif(btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')), ''),
                    btrim(pa.nombre_libre))                                        as nombre_c,
           pa.fecha, pa.competicion, pa.disciplina, pa.modalidad,
           public.liga_disciplina_principal(pa.disciplina)                         as principal,
           lower(btrim(pa.competicion))                                            as competicion_k,
           coalesce(pa.puntos_aplicados, 0)                                        as puntos_brutos,
           a.nombre as a_nombre, a.apellidos as a_apellidos, a.fecha_nacimiento
      from public.liga_participaciones pa
      left join public.atletas a on a.id = pa.atleta_id
     where pa.edicion_id = public.liga_edicion_activa()
       and pa.validada
       and not pa.es_relevo
  ),
  ordenadas as (
    select b.*,
           case when b.principal in ('atletismo', 'natacion')
                then row_number() over (partition by b.clave, b.principal, b.competicion_k
                                        order by b.puntos_brutos desc, b.id)
                else 1 end as puesto
      from base b
  )
  select case
           when public.juego_es_menor(o.fecha_nacimiento) and pj.autoriza_parental_en is null
           then split_part(btrim(coalesce(o.a_nombre, o.nombre_c)), ' ', 1)
                || case when coalesce(o.a_apellidos, '') <> ''
                        then ' ' || left(btrim(o.a_apellidos), 1) || '.' else '' end
           else o.nombre_c
         end,
         o.fecha, o.competicion, o.disciplina, o.modalidad,
         case when o.puesto > 2 then 0 else o.puntos_brutos end,
         o.puesto <= 2
    from ordenadas o
    left join public.perfil_juego pj on pj.atleta_id = o.atleta_id
   order by 1, o.fecha desc;
$$;

revoke all on function public.liga_pruebas_publicas_fn() from public;
grant execute on function public.liga_pruebas_publicas_fn() to anon, authenticated, service_role;

comment on function public.liga_pruebas_publicas_fn() is
  'Pruebas validadas de la edición activa, por persona, con los puntos que cuentan. Para la página pública /liga/ (al tocar un nombre).';
