-- 505 · Auditoría de seguridad 1-nov-2026 (base de datos, medios/regresiones)
-- 1) natacion_mi_plaza: vuelve el freno por IP para visitantes sin sesión
--    (se perdió en la mig 305). Parte de la definición viva en producción.
-- 2) ip_peticion()/ip_cliente(): la IP sale de cf-connecting-ip (la pone
--    Cloudflare; si el cliente la manda, Cloudflare rechaza la petición),
--    luego x-real-ip y, solo si faltan, el ÚLTIMO valor de x-forwarded-for
--    (el primero lo escribe el cliente y se puede falsear).
--    renovacion_ver ya no gasta el tope GLOBAL de altas (altas_hay_sitio)
--    por abrir la página: freno propio por IP con anti_spam.
-- 3) cubo-lista (Claudia) dejaba leer la fila entera de cubo_altas (DNI,
--    dirección, ids de Stripe). Ahora solo por RPC cubo_lista_altas() con las
--    columnas que usa portal/cubo-lista; fuera la política de lectura.
-- 4) productos: la lectura pública, solo de productos activos.
-- 5) sesiones: el atleta que apunta su propia sesión solo puede poner
--    grupo_id nulo o de sus grupos (también al corregirla).
-- 6) avisos_quiere(p_perfil, …): ya no la puede llamar cualquiera con sesión
--    para leer preferencias ajenas. Solo la usan funciones SECURITY DEFINER
--    del sistema (dueño postgres) y service_role, que siguen pudiendo.
-- 7) grupos.entrenador_id a anon: SE QUEDA. Lo piden páginas públicas
--    (encuentra-tu-grupo, assets/js/horarios.js) para poner el nombre del
--    entrenador. Sin cambios.
-- (No toca liga ni es_staff: decisión pendiente.)

begin;

-- ── 1) natacion_mi_plaza ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.natacion_mi_plaza(p_codigo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_acc public.natacion_accesos; v jsonb;
begin
  -- [505] Freno por IP para quien entra sin sesión (enlace mi-plaza): se
  -- perdió en la mig 305 al recrear la función.
  if auth.uid() is null then
    perform public.anti_spam('nat_mi_plaza', 60, interval '10 minutes');
  end if;

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
        ), '[]'::jsonb),
        'incorporaciones', coalesce((
          select jsonb_agg(jsonb_build_object(
              'fecha', r.fecha,
              'nombre', (select string_agg(case when o = 1 or length(w) <= 2 then w else left(w, 3) || '***' end, ' ' order by o)
                         from unnest(regexp_split_to_array(btrim(r.nombre), '\s+')) with ordinality as u(w, o)),
              'calle', r.calle
            ) order by r.fecha)
          from public.natacion_reservas r
          where r.franja_id = f.id and r.estado = 'reservada' and r.fecha >= current_date), '[]'::jsonb)
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
end $function$;

-- ── 2) IP del cliente ─────────────────────────────────────────────────
create or replace function public.ip_peticion()
 returns text
 language plpgsql
 stable
 set search_path to 'public'
as $function$
declare
  h    json;
  v_ip text;
begin
  begin
    h := nullif(current_setting('request.headers', true), '')::json;
  exception when others then
    return '';
  end;
  if h is null then
    return '';
  end if;
  -- cf-connecting-ip la pone Cloudflare (no se puede falsear); luego
  -- x-real-ip; y si no, el ÚLTIMO salto de x-forwarded-for (el primero lo
  -- escribe quien hace la petición).
  v_ip := coalesce(
    nullif(btrim(h ->> 'cf-connecting-ip'), ''),
    nullif(btrim(h ->> 'x-real-ip'), ''),
    nullif(btrim(regexp_replace(coalesce(h ->> 'x-forwarded-for', ''), '^.*,', '')), '')
  );
  return left(coalesce(v_ip, ''), 60);
exception when others then
  return '';
end;
$function$;

create or replace function public.ip_cliente()
 returns text
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare h json; v_ip text;
begin
  begin h := nullif(current_setting('request.headers', true), '')::json; exception when others then return null; end;
  if h is null then return null; end if;
  v_ip := coalesce(
    nullif(btrim(h ->> 'cf-connecting-ip'), ''),
    nullif(btrim(h ->> 'x-real-ip'), ''),
    nullif(btrim(regexp_replace(coalesce(h ->> 'x-forwarded-for', ''), '^.*,', '')), '')  -- último salto, no el primero
  );
  return left(v_ip, 60);
end $function$;

-- renovacion_ver: freno propio, fuera del tope global
CREATE OR REPLACE FUNCTION public.renovacion_ver(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_hash text := encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');
  v_r    public.renovaciones%rowtype;
  v_a    public.atletas%rowtype;
  v_g    public.grupos%rowtype;
  v_ant  public.renovaciones%rowtype;
begin
  -- [505] Abrir la página de renovar ya NO gasta el tope global de altas
  -- (altas_hay_sitio contaba cada visita y 150 visitas/hora bloqueaban las
  -- altas reales de todo el club). Freno solo por IP, aparte.
  begin
    perform public.anti_spam('renovacion_ver', 30, interval '10 minutes');
  exception when check_violation then
    return jsonb_build_object('ok', false, 'motivo', 'demasiados');
  end;

  select * into v_r from public.renovaciones
   where token_hash = v_hash and caduca_en > now() and respondida_en is null;

  if v_r.id is null then
    return jsonb_build_object('ok', false, 'motivo', 'no-vale');
  end if;

  select * into v_a from public.atletas where id = v_r.atleta_id;
  select * into v_g from public.grupos  where id = v_a.grupo_id;

  -- Lo que llevó el año pasado, si lo sabemos. El club ya lo sabe:
  -- que se note, en vez de volver a preguntarlo.
  select * into v_ant from public.renovaciones
   where atleta_id = v_r.atleta_id and respondida_en is not null
   order by respondida_en desc limit 1;

  return jsonb_build_object(
    'ok', true,
    'temporada', v_r.temporada,
    'nombre', trim(coalesce(v_a.nombre, '') || ' ' || coalesce(v_a.apellidos, '')),
    'nombre_corto', coalesce(v_a.nombre_corto, v_a.nombre),
    'ano_nacimiento', extract(year from v_a.fecha_nacimiento)::int,
    'grupo', v_g.nombre,
    'grupo_horario', v_g.horario,
    'turno', v_g.turno,
    'talla_camiseta', v_ant.talla_camiseta,
    'talla_sudadera', v_ant.talla_sudadera,
    'forma_pago', v_ant.forma_pago
  );
end;
$function$;

-- ── 3) cubo-lista: solo las columnas de su pantalla ───────────────────
create or replace function public.cubo_lista_altas()
 returns table (
   id uuid, nombre text, apellidos text, telefono text, horario text,
   atleta_id uuid, perfil_id uuid, estado text, lista_espera boolean,
   dias_semana smallint[]
 )
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select a.id, a.nombre, a.apellidos, a.telefono, a.horario,
         a.atleta_id, a.perfil_id, a.estado, a.lista_espera, a.dias_semana
    from public.cubo_altas a
   where ((select public.es_cubo_lista()) or (select public.es_admin()))
     and a.estado = 'aprobada';
$function$;

revoke all on function public.cubo_lista_altas() from public, anon;
grant execute on function public.cubo_lista_altas() to authenticated, service_role;

drop policy if exists "cubo-lista ve altas del cubo" on public.cubo_altas;

-- ── 4) productos: lo público, solo lo activo ──────────────────────────
alter policy "lectura publica" on public.productos
  using (activo and coalesce(categoria, '') <> 'banador');

-- ── 5) sesiones del atleta: grupo nulo o suyo ─────────────────────────
alter policy "el atleta apunta lo suyo" on public.sesiones
  with check (
    origen = 'atleta'
    and publicada = true
    and creado_por = (select public.mi_perfil_id())
    and coalesce(abierta_inscripcion, false) = false
    and atletas_ids is not null
    and array_length(atletas_ids, 1) = 1
    and atletas_ids[1] in (select public.mis_atletas_entreno())
    and (grupo_id is null or grupo_id in (select public.mis_grupos_de_entreno()))
  );

alter policy "el atleta corrige lo suyo" on public.sesiones
  with check (
    origen = 'atleta'
    and creado_por = (select public.mi_perfil_id())
    and atletas_ids is not null
    and array_length(atletas_ids, 1) = 1
    and atletas_ids[1] in (select public.mis_atletas_entreno())
    and (grupo_id is null or grupo_id in (select public.mis_grupos_de_entreno()))
  );

-- ── 6) avisos_quiere: solo sistema ────────────────────────────────────
-- La llaman avisos_personas, avisos_alcance, avisos_marcar_leido,
-- avisos_destinatarios, mis_avisos, novedades_destinatarios y
-- avisos_cola_movil_destinatarios: todas SECURITY DEFINER de postgres, así
-- que siguen funcionando. Ni el front ni ninguna Edge la llaman directa.
revoke all on function public.avisos_quiere(uuid, text) from public, anon, authenticated;
grant execute on function public.avisos_quiere(uuid, text) to service_role;

commit;
