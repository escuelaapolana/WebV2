-- 373 · Buscador del panel: resumen de cada persona sin abrir su ficha
-- ---------------------------------------------------------------------------
-- Andrés (15-oct): al escribir un nombre en «Buscar una pantalla o una persona»,
-- que debajo salga ya su sección, grupo, días y hora de entreno.
-- SECURITY INVOKER a propósito: cada uno solo ve lo que su RLS le deja (las
-- filas que no puede leer simplemente no salen en el resumen).
-- Devuelve una línea por persona: «Escuela atletismo · Azul 2 · L y X 17:30 ·
-- El Cubo · L y X 17:30 · Natación · Mar 18:30 C1, Vie 18:30 C1».
-- ---------------------------------------------------------------------------
begin;

create or replace function public._dia_corto(d int)
returns text language sql immutable as $$
  select (array['L','M','X','J','V','S','D'])[d];
$$;

create or replace function public.buscador_personas_resumen(p_ids uuid[])
returns table (atleta_id uuid, resumen text)
language sql stable security invoker set search_path to 'public' as $$
  with ids as (select unnest(p_ids) as id),
  -- Grupos (atletismo, Cubo, running…) con sus días y hora
  gr as (
    select ag.atleta_id, g.id gid, g.nombre, g.seccion, ag.principal,
           (select regexp_replace(string_agg(_dia_corto(h.dia_semana), ', ' order by h.dia_semana), ', ([^,]*)$', ' y \1')
              from grupo_horarios h where h.grupo_id = g.id and h.activo) as dias,
           (select to_char(min(h.hora_inicio), 'HH24:MI')
              from grupo_horarios h where h.grupo_id = g.id and h.activo) as hora
      from atleta_grupos ag join grupos g on g.id = ag.grupo_id
     where ag.atleta_id in (select id from ids)
  ),
  gr_txt as (
    select atleta_id,
           string_agg(
             case seccion when 'escuela' then 'Escuela atletismo' when 'cubo' then 'El Cubo'
                          when 'competicion' then 'Pista' when 'running' then 'Running'
                          else initcap(coalesce(seccion, 'Grupo')) end
             || ' · ' || regexp_replace(nombre, '^El Cubo · ', '')
             -- si el nombre ya lleva la hora («L y X 17:30»), no se repite
             || case when nombre ~ '\d{1,2}:\d{2}' or dias is null then ''
                     else ' · ' || dias || coalesce(' ' || hora, '') end,
             '  ·  ' order by principal desc, nombre) as t
      from gr group by atleta_id
  ),
  -- Natación: sus franjas fijas (día, hora y calle)
  na as (
    select ac.atleta_id,
           (array['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'])[f.dia] || ' ' || to_char(f.hora, 'HH24:MI')
             || coalesce(' ' || i.calle, '') as franja,
           f.dia, f.hora, i.tipo
      from natacion_accesos ac
      join natacion_inscripciones i on i.acceso_id = ac.id and i.activa
      join natacion_franjas f on f.id = i.franja_id
     where ac.atleta_id in (select id from ids)
  ),
  na_txt as (
    select atleta_id,
           case when bool_and(tipo = 'Escuela') then 'Escuela natación' else 'Natación' end
             || ' · ' || string_agg(franja, ', ' order by dia, hora) as t
      from na group by atleta_id
  )
  select i.id,
         nullif(concat_ws('  ·  ', g.t, n.t), '')
    from ids i
    left join gr_txt g on g.atleta_id = i.id
    left join na_txt n on n.atleta_id = i.id;
$$;

grant execute on function public.buscador_personas_resumen(uuid[]) to authenticated;
revoke all on function public.buscador_personas_resumen(uuid[]) from anon;

commit;

-- Arreglo (15-oct): faltaba el permiso de la función auxiliar → con sesión real
-- daba «permission denied for function _dia_corto» y el buscador decía
-- «Sin grupo ni horario» para todos.
grant execute on function public._dia_corto(int) to authenticated;
