-- ============================================================
-- 532 · Escuela · el correo de los nuevos con su grupo, una vez al día a las 11:00
-- ------------------------------------------------------------
-- 17-nov-2026: «tras actualizarlos y meterlos en grupo, si hay nuevos me los
-- pasas todos los días a las 11h; si no los hay, no». La sincronización de BUENO
-- ISA (8:00 y ~11:30) crea la ficha con grupo (mig 531) y la deja en la cola
-- escuela_nuevos_aviso; a las 11:00 (hora de Madrid) la Edge escuela-isa-sync
-- (modo avisar_nuevos, con x-cron-secret) manda UN correo con los pendientes a
-- escuela_avisos_destinos y los marca como avisados. Sin pendientes, no sale nada.
-- El grupo del correo es el que tenga el niño EN ESE MOMENTO (si alguien lo ha
-- cambiado en el panel, sale el nuevo).
-- ============================================================
begin;

create table if not exists public.escuela_nuevos_aviso (
  atleta_id   uuid primary key references public.atletas(id) on delete cascade,
  alternativa text,                 -- otro grupo de la misma edad, si lo había
  aviso       text,                 -- p. ej. «no se entiende el turno»
  creado_en   timestamptz not null default now(),
  avisado_en  timestamptz
);
alter table public.escuela_nuevos_aviso enable row level security;
revoke all on public.escuela_nuevos_aviso from anon;
grant select on public.escuela_nuevos_aviso to authenticated;
drop policy if exists "aviso de nuevos: solo admin" on public.escuela_nuevos_aviso;
create policy "aviso de nuevos: solo admin" on public.escuela_nuevos_aviso
  for select to authenticated using ((select public.es_admin()));

-- Los pendientes, con su grupo de AHORA y el contacto de la familia.
create or replace function public.escuela_nuevos_pendientes()
returns jsonb
language sql stable security definer
set search_path to 'public'
as $$
  select coalesce(jsonb_agg(x order by x->>'creado', x->>'nombre'), '[]'::jsonb)
    from (
      select jsonb_build_object(
               'atleta_id', a.id,
               'creado', q.creado_en,
               'nombre', btrim(a.nombre || ' ' || coalesce(a.apellidos, '')),
               'estado', a.estado,
               'nacimiento', a.fecha_nacimiento,
               'turno', nullif(btrim(substring(a.observaciones from 'Turno: ([^·]*)')), ''),
               'grupo', g.nombre,
               'grupo_horario', g.horario,
               'grupo_ninos', (select count(*) from public.atleta_grupos ag2 join public.atletas a2 on a2.id = ag2.atleta_id
                                where ag2.grupo_id = g.id and a2.estado in ('activo', 'prueba')),
               'alternativa', case when q.alternativa is distinct from g.nombre then q.alternativa end,
               'aviso_grupo', case when g.id is null then coalesce(q.aviso, 'Sin grupo: elegirlo en el panel.') end,
               'tutor', nullif(btrim(coalesce(a.nombre_tutor, '')), ''),
               'telefono', nullif(btrim(coalesce(a.telefono_tutor, a.telefono, '')), '')
             ) x
        from public.escuela_nuevos_aviso q
        join public.atletas a on a.id = q.atleta_id
        left join lateral (
          select g.id, g.nombre, g.horario from public.atleta_grupos ag join public.grupos g on g.id = ag.grupo_id
           where ag.atleta_id = a.id and g.seccion = 'escuela'
           order by ag.principal desc nulls last limit 1) g on true
       where q.avisado_en is null
         and a.estado in ('activo', 'prueba') and a.anonimizado_en is null
    ) s
$$;

create or replace function public.escuela_nuevos_marcar(p_ids uuid[])
returns integer
language plpgsql security definer
set search_path to 'public'
as $$
declare v_n int;
begin
  update public.escuela_nuevos_aviso set avisado_en = now()
   where atleta_id = any(coalesce(p_ids, '{}')) and avisado_en is null;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

revoke all on function public.escuela_nuevos_pendientes() from public, anon, authenticated;
revoke all on function public.escuela_nuevos_marcar(uuid[]) from public, anon, authenticated;
grant execute on function public.escuela_nuevos_pendientes() to service_role;
grant execute on function public.escuela_nuevos_marcar(uuid[]) to service_role;

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
                  'grupo', v_g->>'grupo', 'grupo_horario', v_g->>'horario', 'grupo_ninos', (v_g->>'ninos')::int + 1,
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
      -- (mig 532) a la cola del correo diario de las 11:00 («N niños nuevos con su grupo»)
      insert into public.escuela_nuevos_aviso (atleta_id, alternativa, aviso)
      values (v_id, v_g->>'alternativa', v_g->>'aviso')
      on conflict (atleta_id) do nothing;
    end if;
  end loop;

  insert into public.escuela_sync_log (aplicado, resumen)
  values (p_aplicar, jsonb_build_object('filas', v_n, 'cambios', v_cambios, 'nuevos', v_nuevos, 'dudas', v_dudas));

  return jsonb_build_object('ok', true, 'aplicado', p_aplicar, 'filas', v_n,
                            'cambios', v_cambios, 'nuevos', v_nuevos, 'dudas', v_dudas);
end $function$;

-- Cada día a las 11:00 de Madrid (9:00 o 10:00 UTC según el horario de verano;
-- cron_llamar_edge solo llama a la que cae en las 11).
select cron.schedule('apolana-escuela-nuevos', '0 9,10 * * *',
  $c$ select public.cron_llamar_edge('escuela-isa-sync', '{"avisar_nuevos": true}'::jsonb, 11) $c$);

commit;
