-- ============================================================
-- 157 · «Repartir la escuela» ignora a quien ya tiene grupo
-- ------------------------------------------------------------
-- Antes: cualquiera con tipo_membresia='escuela' entraba en el
-- reparto, aunque ya estuviera colocado en un grupo de fuera de la
-- escuela (p. ej. Grupo A). Por eso salía Ander en «sin grupo».
-- Ahora: aparece quien está en un grupo de escuela (para moverlo) o
-- quien es de escuela y NO tiene todavía NINGÚN grupo. Si ya tiene
-- grupo, está colocado y no se reparte.
-- ============================================================

CREATE OR REPLACE FUNCTION public.apo_reparto_escuela()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_out jsonb;
begin
  if not public.apo_puede_repartir() then
    raise exception 'Esta pantalla es de administración.';
  end if;

  with grupos_escuela as (
    -- Los dieciocho: sección escuela y con turno. Los grupos de
    -- escuela sin turno (el de competición, los apagados de antes)
    -- no son columnas del tablero.
    select g.id, g.nombre, g.turno, g.plazas, g.horario,
           g.nacidos_desde, g.nacidos_hasta, g.entrenador_id
      from public.grupos g
     where g.seccion = 'escuela' and g.turno is not null
  ),
  anios as (
    select min(nacidos_desde) as desde, max(nacidos_hasta) as hasta
      from grupos_escuela
  ),
  universo as (
    select a.id, a.nombre, a.apellidos, a.sexo, a.fecha_nacimiento,
           a.grupo_id, a.perfil_padre_id
      from public.atletas a
     where coalesce(a.estado, 'activo') <> 'baja'
       and (
         -- Ya está en un grupo de ESCUELA: es una columna del tablero,
         -- así que aparece (colocado) para poder moverlo de sitio.
         exists (select 1 from grupos_escuela g
                  where g.id = a.grupo_id
                     or exists (select 1 from public.atleta_grupos ag
                                 where ag.atleta_id = a.id and ag.grupo_id = g.id))
         -- O es de la escuela y TODAVÍA no tiene NINGÚN grupo: hay que
         -- repartirlo. Si ya tiene grupo —aunque sea uno de fuera de la
         -- escuela, como Grupo A—, está colocado y NO se reparte.
         or (
           a.grupo_id is null
           and not exists (select 1 from public.atleta_grupos ag where ag.atleta_id = a.id)
           and (
             exists (select 1 from public.altas_escuela_ninos n where n.atleta_id = a.id)
             or a.tipo_membresia = 'escuela'
             or (a.fecha_nacimiento is not null
                 and extract(year from a.fecha_nacimiento)
                     between (select desde from anios) and (select hasta from anios))
           )
         )
       )
  ),
  -- Los grupos de cada niño, de los que son columna del tablero.
  -- Se suma la casilla vieja de la ficha porque, mientras las dos
  -- convivan, la respuesta completa es la suma (migración 116).
  suyos as (
    select u.id as atleta_id, ag.grupo_id, bool_or(ag.principal) as principal
      from universo u
      join public.atleta_grupos ag on ag.atleta_id = u.id
     group by 1, 2
    union
    select u.id, u.grupo_id, true
      from universo u
     where u.grupo_id is not null
       and not exists (select 1 from public.atleta_grupos ag
                        where ag.atleta_id = u.id and ag.grupo_id = u.grupo_id)
  ),
  -- Hermanos. Dos maneras de saberlo, las dos valen: comparten
  -- padre o madre en la ficha, o los apuntaron en la misma alta.
  -- Se agrupa por una clave en vez de cruzar todos con todos:
  -- con cuatrocientos niños, cruzar todos con todos son ciento
  -- sesenta mil comparaciones para nada.
  claves as (
    select u.id as atleta_id, 'padre:' || u.perfil_padre_id::text as clave
      from universo u where u.perfil_padre_id is not null
    union all
    select n.atleta_id, 'alta:' || n.alta_id::text
      from public.altas_escuela_ninos n
     where n.atleta_id in (select id from universo)
  ),
  hermanos as (
    select distinct c1.atleta_id, c2.atleta_id as hermano_id
      from claves c1
      join claves c2 on c2.clave = c1.clave and c2.atleta_id <> c1.atleta_id
  ),
  -- «Con quién le gustaría estar», tal y como lo escribió la
  -- familia al apuntarse. Si hay varias altas del mismo niño manda
  -- la última: es la que refleja lo que pidió este año.
  amigos as (
    select distinct on (n.atleta_id) n.atleta_id, n.amigos, n.turno
      from public.altas_escuela_ninos n
     where n.atleta_id in (select id from universo)
     order by n.atleta_id, n.created_at desc
  )
  select jsonb_build_object(
    'grupos', (
      select coalesce(jsonb_agg(jsonb_build_object(
                'id', g.id,
                'nombre', g.nombre,
                'turno', g.turno,
                'plazas', g.plazas,
                'horario', g.horario,
                'desde', g.nacidos_desde,
                'hasta', g.nacidos_hasta,
                'entrenador', (select p.nombre from public.perfiles p where p.id = g.entrenador_id)
              ) order by g.nombre, g.turno), '[]'::jsonb)
        from grupos_escuela g
    ),
    'ninos', (
      select coalesce(jsonb_agg(jsonb_build_object(
                'id', u.id,
                'nombre', u.nombre,
                'apellidos', coalesce(u.apellidos, ''),
                'sexo', u.sexo,
                'anio', extract(year from u.fecha_nacimiento)::int,
                'grupos', (select coalesce(jsonb_agg(s.grupo_id), '[]'::jsonb)
                             from suyos s where s.atleta_id = u.id),
                'principal', (select s.grupo_id from suyos s
                               where s.atleta_id = u.id and s.principal limit 1),
                'hermanos', (select coalesce(jsonb_agg(h.hermano_id), '[]'::jsonb)
                               from hermanos h where h.atleta_id = u.id),
                'amigos', (select coalesce(to_jsonb(am.amigos), '[]'::jsonb)
                             from amigos am where am.atleta_id = u.id),
                'turno_pedido', (select am.turno from amigos am where am.atleta_id = u.id)
              ) order by u.nombre, u.apellidos), '[]'::jsonb)
        from universo u
    )
  ) into v_out;

  return v_out;
end;
$function$

;
