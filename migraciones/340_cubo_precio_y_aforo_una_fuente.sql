-- 340 · El Cubo: precio y aforo salen de UN solo sitio
-- ------------------------------------------------------------
-- QUÉ PASABA (auditoría 13-oct)
--   El precio del Cubo (reducido 20/30 · general 30/40 €, 1/2 días) estaba
--   escrito a mano en 4 sitios: el formulario `cubo/apuntarse` (JS), la Edge
--   `cubo-alta`, la RPC `cubo_autoapuntarme` y la vieja `cubo_alta_crear`.
--   La tabla `tarifas` (la que el club edita en Panel → Tarifas y la que
--   enseña la web) solo tenía los de 2 días y nadie la leía al apuntarse.
--   El aforo igual: formulario/Edge/RPC usan `cubo_config.limite_grupo` (20)
--   y los grupos tienen `grupos.plazas` = 18.
--
-- QUÉ HACE
--   1) Tarifas de 1 día (reducido 20 · general 30 = lo que HOY cobra el
--      formulario). Van SIN sección para que NO salgan en la web pública
--      (hoy la web no las enseña; si un día se quieren publicar, basta
--      ponerles sección «cubo» en Panel → Tarifas).
--   2) `cubo_precio(p_dias, p_reducido)`: el precio mensual, leído de
--      `tarifas` (la versión vigente). La usan la Edge `cubo-alta` y
--      `cubo_autoapuntarme`. `cubo_precios()` da los 4 de golpe para el
--      formulario público (anónimo: `tarifas` ya es de lectura pública).
--        reducido (escuela o socio) · 1 día → cubo-1dia-reducido   (20)
--        reducido (escuela o socio) · 2 días → cubo-padres-escuela (30)
--        general                    · 1 día → cubo-1dia            (30)
--        general                    · 2 días → cubo-padres         (40)
--   3) Aforo: `cubo_aforo(grupo)` y `cubo_turno_lleno(horario)`. Una sola
--      regla para Edge, RPC y panel. Interruptor `cubo_config.aforo_por_grupo`:
--        false (HOY, mismo comportamiento) → `cubo_config.limite_grupo` (20)
--        true                            → `grupos.plazas` de cada grupo (18)
--      ⚠ Falta que Andrés diga cuál es el bueno (18 o 20). Cambiarlo es:
--        update cubo_config set aforo_por_grupo = true where id = 1;
--   4) `cubo_autoapuntarme` usa las dos funciones (mismo resultado que hoy).
--   5) Se borra `cubo_alta_crear(jsonb)`: nadie la llama desde el 11-sep
--      (el formulario pasó a la Edge `cubo-alta`), guardaba `horario` en otro
--      formato, no aplicaba el reducido a socios y la podía llamar cualquiera
--      SIN sesión (anon) saltándose el anti-spam de la Edge.
--
-- ORDEN DE DESPLIEGUE: esta migración ANTES que la Edge `cubo-alta` y que la
-- web (cubo/apuntarse, admin/cubo-altas), que ya llaman a estas funciones.
-- ============================================================
begin;

-- ---------- 1 · Tarifas de 1 día (importes de hoy, sin tocar) ----------
insert into public.tarifas (clave, ambito, concepto, seccion, dias, importe_socio,
                            periodicidad, vigente_desde, notas, orden, activo)
select 'cubo-1dia', 'cubo', 'El Cubo · adultos · 1 día', null, '1 sesión', 30.00,
       'mensual', date '2026-07-31',
       'Cuota de quien viene un solo día por semana. La usa el alta del Cubo (formulario y portal). Sin sección para que no salga en la web.',
       11, true
where not exists (select 1 from public.tarifas where clave = 'cubo-1dia');

insert into public.tarifas (clave, ambito, concepto, seccion, dias, importe_socio,
                            periodicidad, vigente_desde, notas, orden, activo)
select 'cubo-1dia-reducido', 'cubo', 'El Cubo · 1 día · hijo en la escuela o socio', null, '1 sesión', 20.00,
       'mensual', date '2026-07-31',
       'Precio reducido (familia de la escuela o socio del club) para un solo día por semana. La usa el alta del Cubo. Sin sección para que no salga en la web.',
       21, true
where not exists (select 1 from public.tarifas where clave = 'cubo-1dia-reducido');

-- ---------- 2 · Precio: una sola función ----------
create or replace function public.cubo_precio(p_dias int, p_reducido boolean)
returns integer
language sql stable security definer set search_path to 'public'
as $$
  -- €/mes enteros (cubo_altas.precio_mes es integer). NULL si no hay tarifa
  -- vigente: quien llama NO debe inventarse un precio (la Edge y la RPC
  -- paran el alta con un mensaje).
  select round(t.importe_socio)::int
    from public.tarifas t
   where p_dias in (1, 2)
     and t.clave = case
           when coalesce(p_reducido, false) then
             case when p_dias = 1 then 'cubo-1dia-reducido' else 'cubo-padres-escuela' end
           else
             case when p_dias = 1 then 'cubo-1dia' else 'cubo-padres' end
         end
     and t.activo
     and t.importe_socio is not null
     and t.vigente_desde <= current_date
     and (t.vigente_hasta is null or t.vigente_hasta > current_date)
   order by t.vigente_desde desc
   limit 1;
$$;

comment on function public.cubo_precio(int, boolean) is
  'Cuota mensual del Cubo (€) según días (1/2) y si es reducido (escuela o socio). ÚNICA fuente: tabla tarifas (cubo-1dia, cubo-1dia-reducido, cubo-padres, cubo-padres-escuela).';

create or replace function public.cubo_precios()
returns jsonb
language sql stable security definer set search_path to 'public'
as $$
  select jsonb_build_object(
    'reducido', jsonb_build_object('1', public.cubo_precio(1, true),  '2', public.cubo_precio(2, true)),
    'general',  jsonb_build_object('1', public.cubo_precio(1, false), '2', public.cubo_precio(2, false))
  );
$$;

comment on function public.cubo_precios() is
  'Los 4 precios del Cubo para el formulario público: {reducido:{1,2}, general:{1,2}}. Lee cubo_precio().';

revoke all on function public.cubo_precio(int, boolean) from public;
revoke all on function public.cubo_precios() from public;
grant execute on function public.cubo_precio(int, boolean) to anon, authenticated, service_role;
grant execute on function public.cubo_precios() to anon, authenticated, service_role;

-- ---------- 3 · Aforo: una sola regla ----------
alter table public.cubo_config
  add column if not exists aforo_por_grupo boolean not null default false;

comment on column public.cubo_config.aforo_por_grupo is
  'false = el aforo de cada grupo del Cubo es limite_grupo (global). true = el de grupos.plazas de cada grupo (si está vacío, limite_grupo). Lo leen cubo_aforo()/cubo_turno_lleno().';

create or replace function public.cubo_aforo(p_grupo uuid)
returns integer
language sql stable security definer set search_path to 'public'
as $$
  select case
           when coalesce(c.aforo_por_grupo, false)
             then coalesce((select g.plazas::int from public.grupos g where g.id = p_grupo), c.limite_grupo, 20)
           else coalesce(c.limite_grupo, 20)
         end
    from (select 1) x
    left join public.cubo_config c on c.id = 1;
$$;

comment on function public.cubo_aforo(uuid) is
  'Plazas de un grupo del Cubo antes de lista de espera. Fuente según cubo_config.aforo_por_grupo.';

-- ¿Está lleno el turno? Misma cuenta que hacían la Edge y la RPC: altas de
-- ese turno con plaza (no lista de espera, no rechazadas).
create or replace function public.cubo_turno_lleno(p_horario text)
returns boolean
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_grupo uuid;
  v_lim   int;
  v_ocup  int;
begin
  select id into v_grupo from public.grupos
   where seccion = 'cubo' and nombre = p_horario limit 1;
  v_lim := public.cubo_aforo(v_grupo);
  select count(*) into v_ocup from public.cubo_altas
   where horario = p_horario and not lista_espera and estado <> 'rechazada';
  return coalesce(v_lim, 0) > 0 and v_ocup >= v_lim;
end;
$$;

-- Aforo de cada grupo del Cubo, para el panel (admin/cubo-altas).
create or replace function public.cubo_aforos()
returns table (grupo_id uuid, aforo integer, por_grupo boolean)
language sql stable security definer set search_path to 'public'
as $$
  select g.id, public.cubo_aforo(g.id),
         coalesce((select c.aforo_por_grupo from public.cubo_config c where c.id = 1), false)
    from public.grupos g
   where g.seccion = 'cubo';
$$;

revoke all on function public.cubo_aforo(uuid) from public;
revoke all on function public.cubo_turno_lleno(text) from public;
revoke all on function public.cubo_aforos() from public;
grant execute on function public.cubo_aforo(uuid) to authenticated, service_role;
grant execute on function public.cubo_turno_lleno(text) to authenticated, service_role;
grant execute on function public.cubo_aforos() to authenticated, service_role;

-- ---------- 4 · cubo_autoapuntarme lee precio y aforo de ahí ----------
-- Idéntica a la 291 salvo los dos bloques marcados (precio y aforo).
create or replace function public.cubo_autoapuntarme(p_slot text, p_dias int, p_dia int default 0)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_email    text := lower(auth.jwt() ->> 'email');
  v_perfil   uuid;
  v_nombre   text; v_apellidos text; v_tel text;
  v_horario  text;            -- nombre del grupo (El Cubo · …)
  v_grupo    uuid;
  v_act      boolean;
  v_slotdias int[];
  v_diassem  int[];
  v_reducido boolean;
  v_precio   int;
  v_atleta   uuid;
  v_espera   boolean := false;
  v_id       uuid;
begin
  if v_email is null then
    return jsonb_build_object('ok', false, 'error', 'Tienes que iniciar sesión.');
  end if;
  select id, nombre, apellidos, telefono
    into v_perfil, v_nombre, v_apellidos, v_tel
    from perfiles where lower(email) = v_email;
  if v_perfil is null then
    return jsonb_build_object('ok', false, 'error', 'No encontramos tu cuenta.');
  end if;

  -- slot → grupo + días del turno
  v_horario := case p_slot
    when 'lx-1730' then 'El Cubo · L y X 17:30'
    when 'mj-1730' then 'El Cubo · M y J 17:30'
    when 'lx-1845' then 'El Cubo · L y X 18:45'
    else null end;
  if v_horario is null then
    return jsonb_build_object('ok', false, 'error', 'Elige un horario de la lista.');
  end if;
  if p_dias not in (1, 2) then
    return jsonb_build_object('ok', false, 'error', 'Indica si vienes uno o dos días.');
  end if;
  v_slotdias := case when p_slot like 'mj%' then array[2,4] else array[1,3] end;
  -- 2 días = los dos del turno; 1 día = el que eligió (si no cuadra, queda null
  -- y en la lista de Claudia se le ven los dos hasta marcarlo).
  v_diassem := case
    when p_dias = 2 then v_slotdias
    when p_dia = any(v_slotdias) then array[p_dia]
    else null end;

  -- grupo (existe y está activo)
  select id, coalesce(activo, true) into v_grupo, v_act
    from grupos where seccion = 'cubo' and nombre = v_horario limit 1;
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Ese grupo no está disponible.');
  end if;

  -- ¿ya está apuntado a ESTE grupo? (no duplicar)
  if exists (select 1 from cubo_altas
               where perfil_id = v_perfil and horario = v_horario
                 and estado <> 'rechazada'
                 and coalesce(suscripcion_estado, '') <> 'cancelada') then
    return jsonb_build_object('ok', false, 'error', 'Ya estás apuntado a ese grupo.');
  end if;

  -- precio reducido si es familia de escuela o socio
  v_reducido := exists (
    select 1 from atletas a
     where (a.perfil_id = v_perfil or a.perfil_padre_id = v_perfil)
       and a.tipo_membresia in ('socio', 'escuela'));
  -- [340] precio: de la tabla tarifas (cubo_precio), no escrito aquí
  v_precio := public.cubo_precio(p_dias, v_reducido);
  if v_precio is null then
    return jsonb_build_object('ok', false, 'error', 'Ahora mismo no podemos calcular la cuota. Escríbenos y te apuntamos.');
  end if;

  -- [340] aforo: misma regla que el formulario (cubo_turno_lleno)
  v_espera := public.cubo_turno_lleno(v_horario);

  -- ficha: reaprovecha la suya; si no tiene, se crea tipo cubo
  select id into v_atleta from atletas where perfil_id = v_perfil limit 1;
  if v_atleta is null then
    insert into atletas (perfil_id, nombre, apellidos, email, telefono, tipo_membresia, estado)
    values (v_perfil, coalesce(v_nombre, ''), coalesce(v_apellidos, ''),
            v_email, v_tel, 'cubo', 'prueba')
    returning id into v_atleta;
  end if;

  -- alta PENDIENTE (Andrés la aprueba → de prueba → tracker)
  insert into cubo_altas (nombre, apellidos, telefono, horario, dias, dias_semana,
                          precio_mes, estado, perfil_id, atleta_id, lista_espera,
                          es_escuela, es_socio)
  values (coalesce(v_nombre, ''), coalesce(v_apellidos, ''), coalesce(v_tel, ''),
          v_horario, p_dias, v_diassem, v_precio, 'pendiente',
          v_perfil, v_atleta, v_espera, false, v_reducido)
  returning id into v_id;

  -- enganche al grupo para que lo vea en su app (salvo lista de espera).
  -- Directo en atleta_grupos (ignora duplicado); y si la ficha no tenía grupo
  -- principal, se lo ponemos (el disparador deja ese como principal).
  if not v_espera then
    insert into atleta_grupos (atleta_id, grupo_id, principal)
    values (v_atleta, v_grupo, false)
    on conflict (atleta_id, grupo_id) do nothing;
    update atletas set grupo_id = v_grupo where id = v_atleta and grupo_id is null;
  end if;

  -- papel del Cubo, sin quitarle los que tenga
  update perfiles
     set roles = coalesce(roles, case when rol is not null then array[rol] else '{}'::text[] end) || array['cubo-atleta']
   where id = v_perfil and not ('cubo-atleta' = any(coalesce(roles, '{}'::text[])));

  return jsonb_build_object('ok', true, 'lista_espera', v_espera, 'grupo', v_horario);
end;
$$;

grant execute on function public.cubo_autoapuntarme(text, int, int) to authenticated;

-- ---------- 5 · Fuera la vieja cubo_alta_crear (muerta y abierta a anon) ----------
drop function if exists public.cubo_alta_crear(jsonb);

commit;
