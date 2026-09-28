-- 246 · Acceso de familias + natación "de uno mismo"
-- ---------------------------------------------------------------------------
-- Problema: las tablas de natación (natacion_franjas/inscripciones/accesos)
-- solo las lee staff/responsable (RLS). Por eso un ATLETA en su rol no ve su
-- propia natación (ni en el calendario), y una FAMILIA con cuenta no ve la de
-- sus hijos. El Cubo sí funciona porque grupo_horarios tiene una política
-- "lee su grupo" por persona; natación no tenía equivalente.
--
-- Solución (aditiva, sin abrir las tablas): funciones SECURITY DEFINER que
-- devuelven SOLO lo de uno mismo y lo de sus hijos, más el andamiaje del
-- acceso de familias (token de invitación, marcar falta, editar contacto).
-- Menores: nunca se expone la tabla entera; cada función acota por persona.
-- ---------------------------------------------------------------------------
begin;

-- 1) MIS HIJOS: fichas cuyas cuentas-tutor soy yo.
create or replace function public.mis_hijos()
returns setof uuid
language sql stable security definer set search_path = 'public' as $$
  select id from public.atletas where perfil_padre_id = public.mi_perfil_id();
$$;
revoke all on function public.mis_hijos() from public, anon;
grant execute on function public.mis_hijos() to authenticated;

-- 2) MIS PLAZAS DE NATACIÓN: mis franjas y las de mis hijos (nunca de otros).
--    Devuelve lo justo para pintar el horario; el nombre que va es el del
--    propio nadador/hijo (dato de la familia), no el de compañeros.
create or replace function public.natacion_mis_plazas()
returns jsonb
language sql stable security definer set search_path = 'public' as $$
  -- La ficha del nadador puede colgar de la inscripción (escuela) o del
  -- acceso/código (máster). Y una inscripción puede ir directa a un perfil.
  with mias as (
    select i.id as ins_id, i.franja_id, i.calle, i.nivel, i.tipo, i.acceso_id,
           coalesce(i.atleta_id, ac.atleta_id) as atleta_id
    from public.natacion_inscripciones i
    left join public.natacion_accesos ac on ac.id = i.acceso_id
    left join public.atletas a on a.id = coalesce(i.atleta_id, ac.atleta_id)
    where i.activa
      and (
        (a.id is not null and (a.perfil_id = public.mi_perfil_id()
                            or a.perfil_padre_id = public.mi_perfil_id()))
        or i.perfil_id = public.mi_perfil_id()
      )
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'franja_id', f.id,
      'dia',       f.dia,
      'hora',      to_char(f.hora, 'HH24:MI'),
      'grupo',     f.grupo,
      'calle',     m.calle,
      'nivel',     m.nivel,
      'tipo',      m.tipo,
      'atleta_id', m.atleta_id,
      'de',        (select btrim(a2.nombre || ' ' || coalesce(a2.apellidos, ''))
                      from public.atletas a2 where a2.id = m.atleta_id),
      -- Compañeros de esa franja, con los apellidos en asteriscos (nombre entero).
      'companeros', coalesce((
        select jsonb_agg(masc order by masc) from (
          select (select string_agg(case when o = 1 or length(w) <= 2 then w else left(w, 3) || '***' end, ' ' order by o)
                  from unnest(regexp_split_to_array(btrim(i2.nombre), '\s+')) with ordinality as u(w, o)) as masc
          from public.natacion_inscripciones i2
          where i2.franja_id = f.id and i2.activa and i2.id <> m.ins_id
            and (m.acceso_id is null or i2.acceso_id is distinct from m.acceso_id)
        ) z), '[]'::jsonb),
      -- Faltas ya avisadas de aquí en adelante (para pintarlas marcadas).
      'ausencias', coalesce((
        select jsonb_agg(a3.fecha order by a3.fecha)
        from public.natacion_ausencias a3
        where a3.acceso_id = m.acceso_id and a3.franja_id = f.id and a3.fecha >= current_date), '[]'::jsonb)
    ) order by f.dia, f.hora), '[]'::jsonb)
  from mias m
  join public.natacion_franjas f on f.id = m.franja_id;
$$;
revoke all on function public.natacion_mis_plazas() from public, anon;
grant execute on function public.natacion_mis_plazas() to authenticated;

-- 3) INVITACIONES DE FAMILIA por TOKEN (enlace con contraseña directa).
--    La cuenta se crea con el email del tutor que ya está en las fichas.
--    Solo la Edge (service_role) lee/escribe esta tabla; nadie por RLS.
create table if not exists public.familia_invitaciones (
  token       text primary key,
  email_tutor text not null,
  creado_en   timestamptz not null default now(),
  caduca_en   timestamptz not null default now() + interval '60 days',
  usado_en    timestamptz,
  usado_por   uuid,
  nota        text
);
create index if not exists idx_familia_inv_email on public.familia_invitaciones (lower(email_tutor));
alter table public.familia_invitaciones enable row level security;
-- Sin políticas para authenticated/anon: nadie la ve. La Edge usa service_role.
drop policy if exists "familia_inv admin" on public.familia_invitaciones;
create policy "familia_inv admin" on public.familia_invitaciones
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

-- 4) La familia ve la ficha de sus hijos (dejar explícito en repo).
drop policy if exists "familia ve a sus hijos" on public.atletas;
create policy "familia ve a sus hijos" on public.atletas
  for select to authenticated using (id in (select public.mis_hijos()));

-- 5) MARCAR / QUITAR FALTA de natación de un hijo (o de uno mismo).
--    Resuelve el acceso desde la inscripción del hijo en esa franja.
create or replace function public.natacion_familia_ausencia(p_atleta uuid, p_franja uuid, p_fecha date)
returns jsonb
language plpgsql security definer set search_path = 'public' as $$
declare v_acc uuid;
begin
  if not exists (select 1 from public.atletas a
                 where a.id = p_atleta
                   and (a.perfil_id = public.mi_perfil_id()
                     or a.perfil_padre_id = public.mi_perfil_id())) then
    return jsonb_build_object('ok', false, 'msg', 'No es tu hijo/a.');
  end if;
  if p_fecha < current_date then
    return jsonb_build_object('ok', false, 'msg', 'Ese día ya pasó.');
  end if;
  select i.acceso_id into v_acc
    from public.natacion_inscripciones i
   where i.atleta_id = p_atleta and i.franja_id = p_franja and i.activa
   limit 1;
  if v_acc is null then
    return jsonb_build_object('ok', false, 'msg', 'No está en esa franja.');
  end if;
  if not exists (select 1 from public.natacion_ausencias
                 where acceso_id = v_acc and franja_id = p_franja and fecha = p_fecha) then
    insert into public.natacion_ausencias(acceso_id, franja_id, fecha, origen)
    values (v_acc, p_franja, p_fecha, 'familia');
  end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.natacion_familia_ausencia(uuid, uuid, date) from public, anon;
grant execute on function public.natacion_familia_ausencia(uuid, uuid, date) to authenticated;

create or replace function public.natacion_familia_quitar_ausencia(p_atleta uuid, p_franja uuid, p_fecha date)
returns jsonb
language plpgsql security definer set search_path = 'public' as $$
declare v_acc uuid;
begin
  if not exists (select 1 from public.atletas a
                 where a.id = p_atleta
                   and (a.perfil_id = public.mi_perfil_id()
                     or a.perfil_padre_id = public.mi_perfil_id())) then
    return jsonb_build_object('ok', false, 'msg', 'No es tu hijo/a.');
  end if;
  select i.acceso_id into v_acc
    from public.natacion_inscripciones i
   where i.atleta_id = p_atleta and i.franja_id = p_franja and i.activa
   limit 1;
  if v_acc is not null then
    delete from public.natacion_ausencias
     where acceso_id = v_acc and franja_id = p_franja and fecha = p_fecha and origen = 'familia';
  end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.natacion_familia_quitar_ausencia(uuid, uuid, date) from public, anon;
grant execute on function public.natacion_familia_quitar_ausencia(uuid, uuid, date) to authenticated;

-- 6) EDITAR CONTACTO de un hijo (o de uno mismo). Solo campos de contacto;
--    el email_tutor (su acceso) NO se toca desde aquí.
create or replace function public.familia_edita_contacto(
  p_atleta uuid, p_telefono text, p_nombre_tutor text, p_telefono_tutor text)
returns jsonb
language plpgsql security definer set search_path = 'public' as $$
begin
  if not exists (select 1 from public.atletas a
                 where a.id = p_atleta
                   and (a.perfil_id = public.mi_perfil_id()
                     or a.perfil_padre_id = public.mi_perfil_id())) then
    return jsonb_build_object('ok', false, 'msg', 'No es tu hijo/a.');
  end if;
  update public.atletas set
     telefono       = nullif(btrim(coalesce(p_telefono, telefono)), ''),
     nombre_tutor   = nullif(btrim(coalesce(p_nombre_tutor, nombre_tutor)), ''),
     telefono_tutor = nullif(btrim(coalesce(p_telefono_tutor, telefono_tutor)), '')
   where id = p_atleta;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.familia_edita_contacto(uuid, text, text, text) from public, anon;
grant execute on function public.familia_edita_contacto(uuid, text, text, text) to authenticated;

commit;
