-- NNN · Endurecer el acceso público de natación (código de familias + huecos)
-- ---------------------------------------------------------------------------
-- Cierra dos hallazgos de la revisión de seguridad, SIN cambiar comportamiento
-- para el uso legítimo:
--   1) Freno anti-spam (fail-open, como el resto) en las funciones que puede
--      llamar CUALQUIERA por código: natacion_mi_plaza (lectura, evita
--      enumerar códigos a lo bruto) y marcar/quitar ausencia (escrituras).
--      Solo se limita al público anónimo (auth.uid() is null), como en mig 192.
--   2) natacion_quitar_ausencia solo borra ausencias puestas por la FAMILIA
--      (origen='familia'): la familia ya no puede deshacer una baja que puso
--      el monitor (origen='monitor') ni un aviso del máster (origen='aviso').
--   3) natacion_huecos_calle recibe el mismo gate que su hermana natacion_huecos
--      (staff), MÁS una excepción para el propio nadador máster: si no, se
--      rompería el autoservicio de bonos (mig 251), que la llama internamente
--      con un usuario que NO es staff. Cierra que cualquier autenticado
--      (socio, cubo, escuela) pudiera leer la ocupación por calle.
--
-- Se preservan: security definer, search_path y los grants existentes.
-- NO se toca el enmascarado de nombres de menores ('companeros' en
-- natacion_mi_plaza): eso se decide con Mario (ver informe).
-- ---------------------------------------------------------------------------
begin;

-- 1) Ver mi plaza por código — + freno anti-spam para el público anónimo.
--    (Cuerpo IDÉNTICO al vivo, incluido el enmascarado de 'companeros'.)
create or replace function public.natacion_mi_plaza(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_acc public.natacion_accesos; v jsonb;
begin
  if auth.uid() is null then perform public.anti_spam('nat_mi_plaza', 60, interval '10 minutes'); end if;
  select * into v_acc from public.natacion_accesos where codigo = p_codigo and activo;
  if not found then return null; end if;
  select jsonb_build_object(
    'nombre', v_acc.nombre,
    'franjas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'franja_id', f.id, 'dia', f.dia, 'hora', to_char(f.hora,'HH24:MI'),
        'grupo', f.grupo, 'calle', i.calle, 'nivel', i.nivel,
        'companeros', coalesce((
          select jsonb_agg(masc order by masc)
          from (
            select (
              select string_agg(case when o = 1 or length(w) <= 2 then w else left(w, 3) || '***' end, ' ' order by o)
              from unnest(regexp_split_to_array(btrim(i2.nombre), '\s+')) with ordinality as u(w, o)
            ) as masc
            from public.natacion_inscripciones i2
            where i2.franja_id = f.id and i2.activa
              and i2.acceso_id is distinct from v_acc.id
          ) z
        ), '[]'::jsonb)
      ) order by f.dia, f.hora)
      from public.natacion_inscripciones i
      join public.natacion_franjas f on f.id = i.franja_id
      where i.acceso_id = v_acc.id and i.activa), '[]'::jsonb),
    'ausencias', coalesce((
      select jsonb_agg(jsonb_build_object('franja_id', a.franja_id, 'fecha', a.fecha) order by a.fecha)
      from public.natacion_ausencias a
      where a.acceso_id = v_acc.id and a.fecha >= current_date), '[]'::jsonb)
  ) into v;
  return v;
end $$;

-- 2) Avisar de que un día no viene — + freno anti-spam para el público anónimo.
create or replace function public.natacion_marcar_ausencia(p_codigo text, p_franja uuid, p_fecha date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_acc uuid;
begin
  if auth.uid() is null then perform public.anti_spam('nat_ausencia', 40, interval '10 minutes'); end if;
  select id into v_acc from public.natacion_accesos where codigo = p_codigo and activo;
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'codigo'); end if;
  if p_fecha < current_date then return jsonb_build_object('ok', false, 'error', 'fecha'); end if;
  if not exists (select 1 from public.natacion_inscripciones where acceso_id = v_acc and franja_id = p_franja and activa) then
    return jsonb_build_object('ok', false, 'error', 'franja');
  end if;
  insert into public.natacion_ausencias(acceso_id, franja_id, fecha)
    values (v_acc, p_franja, p_fecha)
    on conflict (acceso_id, franja_id, fecha) do nothing;
  return jsonb_build_object('ok', true);
end $$;

-- 3) Deshacer (sí que va a venir) — + freno anti-spam y SOLO ausencias de la
--    familia (origen='familia'): no puede borrar la baja que puso el monitor.
create or replace function public.natacion_quitar_ausencia(p_codigo text, p_franja uuid, p_fecha date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_acc uuid;
begin
  if auth.uid() is null then perform public.anti_spam('nat_ausencia', 40, interval '10 minutes'); end if;
  select id into v_acc from public.natacion_accesos where codigo = p_codigo and activo;
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'codigo'); end if;
  delete from public.natacion_ausencias
   where acceso_id = v_acc and franja_id = p_franja and fecha = p_fecha and origen = 'familia';
  return jsonb_build_object('ok', true);
end $$;

grant execute on function public.natacion_mi_plaza(text)                    to anon, authenticated;
grant execute on function public.natacion_marcar_ausencia(text, uuid, date) to anon, authenticated;
grant execute on function public.natacion_quitar_ausencia(text, uuid, date) to anon, authenticated;

-- 4) Huecos por calle — mismo gate de staff que natacion_huecos, MÁS el propio
--    nadador máster (autoservicio de bonos, mig 251, la llama internamente).
create or replace function public.natacion_huecos_calle(p_franja uuid, p_fecha date)
returns table(calle text, cupo int, ocupados int, huecos int)
language sql stable security definer set search_path = 'public' as $$
  with f as (
    select cupos, calles from public.natacion_franjas
    where id = p_franja
      and (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')
           or exists (select 1 from public.natacion_master_yo()))
  ),
  calles as (
    select k as calle, (v)::int as cupo
    from f, jsonb_each_text((select cupos from f)) as e(k, v)
  )
  select c.calle, c.cupo,
    ( (select count(*) from public.natacion_inscripciones i
         where i.franja_id = p_franja and i.activa and i.calle = c.calle)
      - (select count(*) from public.natacion_ausencias au
           join public.natacion_inscripciones i2 on i2.acceso_id = au.acceso_id and i2.franja_id = au.franja_id and i2.activa
         where au.franja_id = p_franja and au.fecha = p_fecha and i2.calle = c.calle)
      + (select count(*) from public.natacion_reservas r
           where r.franja_id = p_franja and r.fecha = p_fecha and r.calle = c.calle and r.estado = 'reservada')
    )::int as ocupados,
    ( c.cupo
      - ( (select count(*) from public.natacion_inscripciones i
             where i.franja_id = p_franja and i.activa and i.calle = c.calle)
          - (select count(*) from public.natacion_ausencias au
               join public.natacion_inscripciones i2 on i2.acceso_id = au.acceso_id and i2.franja_id = au.franja_id and i2.activa
             where au.franja_id = p_franja and au.fecha = p_fecha and i2.calle = c.calle) )
      - (select count(*) from public.natacion_reservas r
           where r.franja_id = p_franja and r.fecha = p_fecha and r.calle = c.calle and r.estado = 'reservada')
    )::int as huecos
  from calles c
  order by c.calle;
$$;
revoke all on function public.natacion_huecos_calle(uuid, date) from public, anon;
grant execute on function public.natacion_huecos_calle(uuid, date) to authenticated;

commit;
