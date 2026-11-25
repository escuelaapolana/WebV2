-- ============================================================
-- 531 · Escuela · los niños nuevos entran ya con grupo y se avisa por correo
-- ------------------------------------------------------------
-- 17-nov-2026 (pedido desde la cuenta de Andrés): «cuando entren nuevos usuarios
-- de alta tras rellenar el formulario, asígnales tú el grupo directamente y
-- mándame al correo los nombres y su grupo, para comunicárselo a los padres».
--
-- · _escuela_grupo_para(nacimiento, turno): de los grupos de verdad de ese turno
--   (activos, con entrenador y con 3 niños o más), el que tiene a los niños de la
--   edad más parecida (mediana de sus fechas de nacimiento). Los años guardados
--   en grupos.nacidos_desde/hasta NO sirven (están corridos). Si dos grupos son
--   de la misma edad (diferencia < 120 días), va al que tiene menos niños y se
--   dice cuál era el otro (también si la diferencia es de menos de 180 días). Probada
--   con los 400 niños que ya tienen grupo: a las 17:30 el 66 % cae justo en su grupo
--   (77 % contando el otro que se propone) y a las 18:30 el 91 %; los demás, en un
--   grupo paralelo de su mismo año.
-- · escuela_isa_sincronizar: la ficha nueva entra con ese grupo (antes, sin grupo)
--   y el resumen lleva el grupo, la alternativa, el aviso y el contacto de la familia.
-- · escuela_avisos_destinos: a quién le llega el correo de los nuevos con su grupo
--   (lo manda la Edge escuela-isa-sync). Las direcciones se meten por psql, NO en
--   este fichero (el repo es público). Solo el admin la ve.
-- ============================================================
begin;

create table if not exists public.escuela_avisos_destinos (
  email      text primary key check (email = lower(btrim(email)) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  nombre     text,
  activo     boolean not null default true,
  creado_en  timestamptz not null default now()
);
alter table public.escuela_avisos_destinos enable row level security;
revoke all on public.escuela_avisos_destinos from anon;
grant select, insert, update, delete on public.escuela_avisos_destinos to authenticated;
drop policy if exists "destinos escuela: solo admin" on public.escuela_avisos_destinos;
create policy "destinos escuela: solo admin" on public.escuela_avisos_destinos
  for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));

create or replace function public._escuela_grupo_para(p_nacimiento date, p_turno text)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
declare
  t      text := lower(translate(coalesce(p_turno, ''), 'áéíóúÁÉÍÓÚ', 'aeiouAEIOU'));
  v_dias text;
  v_hora text;
  v_c    jsonb;
  v_el   jsonb;
  v_otro jsonb;
  v_aviso text;
begin
  if p_nacimiento is null then
    return jsonb_build_object('aviso', 'Sin fecha de nacimiento: elegir el grupo a mano.');
  end if;
  v_dias := case when t ~ 'lunes' then 'L' when t ~ 'martes' then 'M' end;
  v_hora := substring(t from '(1[0-9]:[0-5][0-9])');
  if v_dias is null or v_hora is null then
    return jsonb_build_object('aviso', 'No se entiende el turno del formulario: elegir el grupo a mano.');
  end if;

  -- Grupos de verdad de ese turno (activos, con entrenador y con niños) y la edad
  -- real de sus niños (la mediana de las fechas de nacimiento): los años que
  -- tienen guardados los grupos no cuadran con quién hay dentro.
  with cand as (
    select g.id, g.nombre, g.horario, g.plazas, count(*) n,
           percentile_disc(0.5) within group (order by a.fecha_nacimiento) mediana
      from public.grupos g
      join public.atleta_grupos ag on ag.grupo_id = g.id
      join public.atletas a on a.id = ag.atleta_id
     where g.seccion = 'escuela' and g.activo and g.entrenador_id is not null
       and a.estado in ('activo', 'prueba') and a.fecha_nacimiento is not null
       and (case when lower(translate(coalesce(g.horario, ''), 'áéíóúÁÉÍÓÚ', 'aeiouAEIOU')) ~ '^\s*lunes' then 'L'
                 when lower(translate(coalesce(g.horario, ''), 'áéíóúÁÉÍÓÚ', 'aeiouAEIOU')) ~ '^\s*martes' then 'M' end) = v_dias
       and substring(g.horario from '(1[0-9]:[0-5][0-9])') = v_hora
     group by g.id, g.nombre, g.horario, g.plazas
    having count(*) >= 3
  )
  select jsonb_agg(jsonb_build_object('grupo_id', id, 'grupo', nombre, 'horario', horario, 'ninos', n, 'plazas', plazas,
                                      'dist', abs(p_nacimiento - mediana))
                   order by abs(p_nacimiento - mediana), n)
    into v_c from cand;

  if v_c is null then
    return jsonb_build_object('aviso', 'No hay ningún grupo de ese turno con niños: elegir el grupo a mano.');
  end if;

  v_el := v_c -> 0;
  v_otro := v_c -> 1;
  -- Dos grupos de la misma edad (p. ej. Azul 1 y Azul 2 de martes/jueves):
  -- va al que tenga menos niños, y se dice cuál era el otro.
  if v_otro is not null and (v_otro ->> 'dist')::int - (v_el ->> 'dist')::int < 120 then
    if (v_otro ->> 'ninos')::int < (v_el ->> 'ninos')::int then
      v_el := v_c -> 1; v_otro := v_c -> 0;
    end if;
  elsif v_otro is null or (v_otro ->> 'dist')::int - (v_el ->> 'dist')::int >= 180 then
    v_otro := null;              -- (entre 120 y 180 días se queda el más parecido, pero se dice el otro)
  end if;

  if (v_el ->> 'dist')::int > 548 then
    v_aviso := 'Su edad no encaja bien en ningún grupo de ese turno: revisarlo.';
  end if;

  return jsonb_build_object('grupo_id', v_el -> 'grupo_id', 'grupo', v_el ->> 'grupo', 'horario', v_el ->> 'horario',
                            'ninos', (v_el ->> 'ninos')::int, 'plazas', (v_el ->> 'plazas')::int,
                            'alternativa', v_otro ->> 'grupo', 'aviso', v_aviso);
end $$;

revoke all on function public._escuela_grupo_para(date, text) from public, anon, authenticated;
grant execute on function public._escuela_grupo_para(date, text) to service_role;

CREATE OR REPLACE FUNCTION public.escuela_isa_sincronizar(p_token text, p_filas jsonb, p_aplicar boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_tok text;
  r record;
  v_cambios jsonb := '[]';
  v_nuevos  jsonb := '[]';
  v_dudas   jsonb := '[]';
  v_id uuid;
  v_g  jsonb;
  v_n int := 0;
begin
  select decrypted_secret into v_tok from vault.decrypted_secrets where name = 'escuela_sync_token';
  if v_tok is null or p_token is null or p_token <> v_tok then
    raise exception 'token' using errcode = '42501';
  end if;

  -- 1 · Filas → estado que dice cada hoja
  create temp table _f on commit drop as
  select (x->>'hoja') hoja, (x->>'fila')::int fila,
         btrim(coalesce(x->>'nombre','')) nombre,
         btrim(regexp_replace(coalesce(x->>'ap1','')||' '||coalesce(x->>'ap2',''), '\s+', ' ', 'g')) apellidos,
         nullif(x->>'nacimiento','')::date nacimiento,
         array(select lower(c) from jsonb_array_elements_text(coalesce(x->'colores','[]')) c) colores,
         x->>'turno' turno, x->>'sexo' sexo, x->>'dni' dni, x->>'tutor' tutor, x->>'telefono' telefono,
         x->>'email' email, x->>'direccion' direccion, x->>'obs' obs,
         nullif(x->>'completa','') completa   -- (mig 448) cómo está la fila ENTERA: verde | rojo | otro | parcial | nada
    from jsonb_array_elements(p_filas) x
   where btrim(coalesce(x->>'nombre','')) <> '';
  get diagnostics v_n = row_count;

  alter table _f add column dice text;
  update _f set dice = case hoja
      when 'inscripcion' then case
           -- (mig 448, Andrés 27-oct) Alta = la fila ENTERA en verde; baja = entera en
           -- rojo; con solo unas celdas en verde (p. ej. el nombre) sigue de PRUEBA.
           when completa = 'verde' then 'activo'
           when completa = 'rojo' then 'baja'
           when completa = 'otro' then null
           when completa in ('parcial', 'nada') then 'prueba'
           -- Script antiguo (sin «completa»): el rojo es baja y sin color es prueba;
           -- con algo de verde no se sabe si la fila está entera → no se decide.
           when colores && array['#f4cccc'] then 'baja'
           when colores && array['#d5a6bd'] then null
           when colores && array['#d9ead3','#93c47d','#b6d7a8'] then null
           else 'prueba' end
      when 'renovacion' then case when colores && array['#d9ead3','#93c47d','#b6d7a8'] then 'activo' end
      when 'municipal' then 'activo'      -- Andrés 20-oct: los municipales son altas directas (sin prueba)
      when 'municipal_baja' then case when colores && array['#e06666','#cc0000','#ea9999','#f4cccc'] then 'baja' end
    end
   where true;
  delete from _f where dice is null;  -- (PostgREST exige WHERE en update/delete: los demás llevan uno)

  -- 2 · Casar con las fichas de la escuela (escuela o municipal)
  alter table _f add column atleta_id uuid, add column n_cand int;
  update _f f set n_cand = c.n, atleta_id = case when c.n = 1 then c.id end
    from (select f2.hoja, f2.fila, count(a.id) n, (array_agg(a.id))[1] id
            from _f f2
            left join public.atletas a
              on public._nombre_norm(a.nombre||' '||coalesce(a.apellidos,'')) = public._nombre_norm(f2.nombre||' '||f2.apellidos)
             and (a.tipo_membresia in ('escuela','municipal') or 'escuela' = any(coalesce(a.secciones,'{}')))
             and not (a.estado = 'baja' and coalesce(a.observaciones,'') ilike '%duplicado%')  -- fichas duplicadas archivadas
             and (f2.nacimiento is null or a.fecha_nacimiento is null or a.fecha_nacimiento = f2.nacimiento)
           group by f2.hoja, f2.fila) c
   where c.hoja = f.hoja and c.fila = f.fila;

  -- 2a · Equivalencias a mano (mandan sobre todo lo demás)
  update _f f set n_cand = 1, atleta_id = al.atleta_id
    from public.escuela_sync_alias al
   where al.nombre_norm = public._nombre_norm(f.nombre||' '||f.apellidos);

  -- 2b · Segunda pasada para nombres mal escritos («Sánchex», «No tiene segundo
  --      apellido»…): misma fecha de nacimiento + primer nombre + primer apellido.
  update _f f set n_cand = c.n, atleta_id = case when c.n = 1 then c.id end
    from (select f2.hoja, f2.fila, count(a.id) n, (array_agg(a.id))[1] id
            from _f f2
            join public.atletas a
              on f2.nacimiento is not null and a.fecha_nacimiento = f2.nacimiento
             and split_part(public._nombre_norm(a.nombre),' ',1) = split_part(public._nombre_norm(f2.nombre),' ',1)
             and split_part(public._nombre_norm(a.apellidos),' ',1) = split_part(public._nombre_norm(f2.apellidos),' ',1)
             and (a.tipo_membresia in ('escuela','municipal') or 'escuela' = any(coalesce(a.secciones,'{}')))
             and not (a.estado = 'baja' and coalesce(a.observaciones,'') ilike '%duplicado%')  -- fichas duplicadas archivadas
           where f2.n_cand = 0
           group by f2.hoja, f2.fila) c
   where c.hoja = f.hoja and c.fila = f.fila;

  -- El rojo de «Respuestas» de municipales solo cuenta si el niño NO sale en
  -- ninguna otra hoja (si está en la hoja buena o se pasó a la escuela, manda eso).
  delete from _f b
   where b.hoja = 'municipal_baja'
     and exists (select 1 from _f o where o.hoja <> 'municipal_baja'
                   and ((b.atleta_id is not null and o.atleta_id = b.atleta_id)
                     or public._nombre_norm(o.nombre||' '||o.apellidos) = public._nombre_norm(b.nombre||' '||b.apellidos)));

  for r in select * from _f where n_cand > 1 loop
    v_dudas := v_dudas || jsonb_build_object('tipo','varias fichas','hoja',r.hoja,'fila',r.fila,'nombre',r.nombre||' '||r.apellidos);
  end loop;

  -- 3 · Qué dice el conjunto de hojas para cada ficha
  for r in
    select a.id, a.nombre||' '||coalesce(a.apellidos,'') nom, a.estado,
           bool_or(f.dice='activo') hay_activo, bool_or(f.dice='baja') hay_baja, bool_or(f.dice='prueba') hay_prueba,
           string_agg(distinct f.hoja||' fila '||f.fila, ', ') de
      from _f f join public.atletas a on a.id = f.atleta_id
     where not exists (select 1 from public.escuela_sync_alias al where al.atleta_id = a.id and al.no_tocar)
     group by a.id, a.nombre, a.apellidos, a.estado
  loop
    if r.hay_activo and r.estado = 'prueba' then
      v_cambios := v_cambios || jsonb_build_object('tipo','confirmado','atleta_id',r.id,'nombre',r.nom,'de',r.de);
      if p_aplicar then update public.atletas set estado = 'activo' where id = r.id and estado = 'prueba'; end if;
    elsif r.hay_baja and not r.hay_activo and r.estado is distinct from 'baja' then
      v_cambios := v_cambios || jsonb_build_object('tipo','baja','atleta_id',r.id,'nombre',r.nom,'de',r.de,
        'grupos',(select coalesce(jsonb_agg(g.nombre),'[]') from public.atleta_grupos ag join public.grupos g on g.id=ag.grupo_id
                   where ag.atleta_id=r.id and g.seccion='escuela'));
      if p_aplicar then
        update public.atletas set estado = 'baja', fecha_baja = coalesce(fecha_baja, now()),
               observaciones = concat_ws(E'\n', nullif(btrim(observaciones),''), 'Baja según BUENO ISA (comprobación diaria '||to_char(now() at time zone 'Europe/Madrid','DD-MM-YYYY')||')')
         where id = r.id;
        delete from public.atleta_grupos ag using public.grupos g
         where ag.atleta_id = r.id and g.id = ag.grupo_id and g.seccion = 'escuela';
      end if;
    elsif r.hay_prueba and not r.hay_activo and not r.hay_baja and r.estado = 'activo' then
      -- (mig 448) En el Excel no está en alta (fila sin acabar de pintar): vuelve a prueba.
      v_cambios := v_cambios || jsonb_build_object('tipo','a prueba','atleta_id',r.id,'nombre',r.nom,'de',r.de);
      if p_aplicar then update public.atletas set estado = 'prueba' where id = r.id and estado = 'activo'; end if;
    elsif r.estado = 'baja' and (r.hay_activo or r.hay_prueba) and not r.hay_baja then
      v_dudas := v_dudas || jsonb_build_object('tipo','de baja en la app pero no en el Excel','atleta_id',r.id,'nombre',r.nom,'de',r.de);
    elsif r.hay_baja and r.hay_activo and r.estado is distinct from 'baja' then
      v_dudas := v_dudas || jsonb_build_object('tipo','en rojo en una hoja y en verde en otra','atleta_id',r.id,'nombre',r.nom,'de',r.de);
    end if;
  end loop;

  -- 4 · Filas nuevas (sin ficha) que no son baja → ficha CON grupo (mig 531):
  --     el de su turno cuyos niños tienen la edad más parecida (_escuela_grupo_para).
  for r in
    select distinct on (public._nombre_norm(nombre||' '||apellidos)) *
      from _f where n_cand = 0 and dice in ('activo','prueba')
     order by public._nombre_norm(nombre||' '||apellidos), (dice='activo') desc
  loop
    -- si en otra hoja la misma persona está de baja, no se crea
    continue when exists (select 1 from _f b where b.dice='baja'
                           and public._nombre_norm(b.nombre||' '||b.apellidos) = public._nombre_norm(r.nombre||' '||r.apellidos));
    v_g := public._escuela_grupo_para(r.nacimiento, r.turno);
    v_nuevos := v_nuevos || jsonb_build_object('nombre', initcap(lower(r.nombre))||' '||initcap(lower(r.apellidos)),
                  'estado', r.dice, 'hoja', r.hoja, 'fila', r.fila, 'nacimiento', r.nacimiento, 'turno', r.turno,
                  'grupo', v_g->>'grupo', 'grupo_horario', v_g->>'horario', 'grupo_ninos', (v_g->>'ninos')::int,
                  'alternativa', v_g->>'alternativa', 'aviso_grupo', v_g->>'aviso',
                  'tutor', nullif(btrim(coalesce(r.tutor,'')),''), 'telefono', nullif(btrim(coalesce(r.telefono,'')),''));
    if p_aplicar then
      insert into public.atletas (nombre, apellidos, fecha_nacimiento, sexo, dni, estado, tipo_membresia, secciones,
                                  nombre_tutor, email_tutor, telefono_tutor, direccion, observaciones, origen)
      values (initcap(lower(r.nombre)), initcap(lower(r.apellidos)), r.nacimiento,
              case lower(coalesce(r.sexo,'')) when 'masculino' then 'hombre' when 'femenino' then 'mujer' end,
              nullif(nullif(btrim(r.dni),''),'0'), r.dice,
              case when r.hoja like 'municipal%' then 'municipal' else 'escuela' end, array['escuela'],
              r.tutor, r.email, r.telefono, r.direccion,
              concat_ws(' · ', 'Alta automática desde BUENO ISA ('||r.hoja||', fila '||r.fila||')', 'Turno: '||r.turno,
                        case when nullif(btrim(r.obs),'') is not null then 'Formulario: '||r.obs end,
                        case when v_g->>'grupo_id' is not null
                             then 'Grupo puesto solo: '||(v_g->>'grupo')||' (por la edad; se cambia en el panel si no encaja)'
                             else 'SIN GRUPO: asignar en el panel' end),
              'sync-isa')
      returning id into v_id;
      if v_g->>'grupo_id' is not null then
        insert into public.atleta_grupos (atleta_id, grupo_id, principal) values (v_id, (v_g->>'grupo_id')::uuid, true);
      end if;
    end if;
  end loop;

  insert into public.escuela_sync_log (aplicado, resumen)
  values (p_aplicar, jsonb_build_object('filas', v_n, 'cambios', v_cambios, 'nuevos', v_nuevos, 'dudas', v_dudas));

  return jsonb_build_object('ok', true, 'aplicado', p_aplicar, 'filas', v_n,
                            'cambios', v_cambios, 'nuevos', v_nuevos, 'dudas', v_dudas);
end $function$;

commit;
