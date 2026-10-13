-- 330 · Natación: la ocupación de un día sale de UN solo sitio.
--
-- Auditoría 13-oct-2026. La ocupación diaria de natación se calculaba 4 veces
-- y cada una decía una cosa:
--   · calendario_club y natacion_huecos restaban TODAS las ausencias de la
--     franja (también las de gente que ya no está inscrita).
--   · natacion_huecos_calle solo las de inscritos activos.
--   · natacion_huecos tomaba el cupo de `cupos` o, si no, calles×8.
--   · natacion_reservar miraba el hueco TOTAL de la franja: colocaba un bono
--     en una calle llena si otra calle tenía sitio (Stéfano, Vaso martes 17:30).
--
-- ┌─ LA REGLA (única; la aplica natacion_ocupacion) ──────────────────────────┐
-- │ Por franja + calle + día:                                                │
-- │   fijos     = inscripciones activas en esa calle                         │
-- │   bajas     = «no viene» de ESOS inscritos ese día (natacion_ausencias)  │
-- │   reservas  = incorporaciones por bono/cambio ese día (estado reservada) │
-- │   ocupados  = fijos − bajas + reservas                                   │
-- │   cupo      = el de `natacion_franjas.cupos` para esa calle (0 si la     │
-- │               calle no está en cupos: NO hay plan B de calles×8)         │
-- │   huecos    = cupo − ocupados   (0 si el día está cancelado)             │
-- │   cancelado = festivo/cierre vía hay_excepcion (sección de la franja)    │
-- │ Sin fecha (p_fecha NULL) = la foto «de siempre»: solo fijos (lo que usa  │
-- │ el semáforo de la web, mig 331).                                         │
-- │ Hueco de la FRANJA = suma de los huecos POSITIVOS de sus calles (una     │
-- │ calle pasada de cupo no se come el sitio de otra) − incorporaciones sin  │
-- │ calle.                                                                   │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- Clasificación escuela / adultos (también UNA regla, la usan calendario_club
-- y la web pública):
--   es_escuela = el nombre de la franja dice «escuela» o «perfeccion»
--                (la de «Perfeccionamiento» del lunes 19:30 es de la escuela:
--                todos sus inscritos son tipo Escuela).
--   es_master  = la franja admite máster (`admite_master`) o su nombre dice
--                «máster».
--   seccion    = 'escuela-natacion' si es solo escuela; si no, 'natacion'.
--
-- Quién la usa (mismas firmas de siempre):
--   natacion_huecos(fecha), natacion_huecos_calle(franja, fecha),
--   natacion_reservar(...) [ahora comprueba la CALLE: elige la suya con
--   hueco o no reserva], natacion_incorporar_manual(...) [pasar lista: no
--   bloquea, pero pone su calle si no la dan y avisa si queda sobre cupo],
--   y en la 331/332 el semáforo y calendario_club.
--
-- No toca datos (ni inscripciones ni cupos).

-- ─────────────────────────────────────────────────────────────────────────
-- 1 · Clasificación escuela / adultos
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.natacion_es_escuela(p_grupo text)
returns boolean
language sql immutable
set search_path to 'public'
as $$
  select coalesce(p_grupo, '') ~* '(escuela|perfeccion)';
$$;

create or replace function public.natacion_es_master(p_grupo text, p_admite_master boolean)
returns boolean
language sql immutable
set search_path to 'public'
as $$
  select coalesce(p_admite_master, false) or coalesce(p_grupo, '') ~* 'm[aá]ster';
$$;

create or replace function public.natacion_franja_seccion(p_grupo text, p_admite_master boolean)
returns text
language sql immutable
set search_path to 'public'
as $$
  select case when public.natacion_es_escuela(p_grupo)
               and not public.natacion_es_master(p_grupo, p_admite_master)
              then 'escuela-natacion' else 'natacion' end;
$$;

comment on function public.natacion_franja_seccion(text, boolean) is
  'Mig 330 · sección de una franja de natación: escuela-natacion si es solo escuela; natacion si admite adultos (incluye las mixtas).';

-- Puras y sin datos: las puede llamar cualquiera (las usa la vista pública).
grant execute on function public.natacion_es_escuela(text) to anon, authenticated;
grant execute on function public.natacion_es_master(text, boolean) to anon, authenticated;
grant execute on function public.natacion_franja_seccion(text, boolean) to anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 2 · El núcleo: ocupación por franja + calle (+ día)
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.natacion_ocupacion(p_fecha date default null, p_franja uuid default null)
returns table(
  franja_id uuid, dia smallint, hora time without time zone, grupo text,
  seccion text, es_escuela boolean, es_master boolean,
  calle text, en_cupos boolean, cupo integer,
  fijos integer, bajas integer, reservas integer, ocupados integer, huecos integer,
  cancelado boolean)
language sql stable
set search_path to 'public'
as $$
  with fr as (
    select f.id, f.dia, f.hora, f.grupo, f.cupos,
           public.natacion_es_escuela(f.grupo) as es_esc,
           public.natacion_es_master(f.grupo, f.admite_master) as es_mas,
           public.natacion_franja_seccion(f.grupo, f.admite_master) as secc
      from public.natacion_franjas f
     where (p_franja is null or f.id = p_franja)
       and (p_franja is not null or coalesce(f.activa, true))
       and (p_fecha is null or f.dia = extract(isodow from p_fecha)::smallint)
  ),
  fr2 as (
    select fr.*,
           case when p_fecha is null then false
                else public.hay_excepcion(p_fecha, null, 'natacion', null)
                  or (fr.secc = 'escuela-natacion'
                      and public.hay_excepcion(p_fecha, null, 'escuela-natacion', null))
           end as canc
      from fr
  ),
  cup as (
    select fr2.id as franja_id, e.key as calle,
           case when e.value ~ '^\s*\d+\s*$' then btrim(e.value)::int else 0 end as cupo
      from fr2, jsonb_each_text(coalesce(fr2.cupos, '{}'::jsonb)) as e(key, value)
  ),
  ins as (
    select i.franja_id, i.calle,
           count(*)::int as fijos,
           count(*) filter (
             where p_fecha is not null and i.acceso_id is not null and exists (
               select 1 from public.natacion_ausencias a
                where a.franja_id = i.franja_id and a.acceso_id = i.acceso_id
                  and a.fecha = p_fecha))::int as bajas
      from public.natacion_inscripciones i
     where i.activa and i.franja_id in (select id from fr2)
     group by i.franja_id, i.calle
  ),
  res as (
    select r.franja_id, nullif(btrim(r.calle), '') as calle, count(*)::int as reservas
      from public.natacion_reservas r
     where p_fecha is not null and r.fecha = p_fecha and r.estado = 'reservada'
       and r.franja_id in (select id from fr2)
     group by r.franja_id, nullif(btrim(r.calle), '')
  ),
  calles as (
    select c.franja_id, c.calle from cup c
    union select i.franja_id, i.calle from ins i
    union select r.franja_id, r.calle from res r
  )
  select fr2.id, fr2.dia, fr2.hora, fr2.grupo,
         fr2.secc, fr2.es_esc, fr2.es_mas,
         ca.calle,
         (cup.calle is not null)                                   as en_cupos,
         coalesce(cup.cupo, 0)                                     as cupo,
         coalesce(ins.fijos, 0)                                    as fijos,
         coalesce(ins.bajas, 0)                                    as bajas,
         coalesce(res.reservas, 0)                                 as reservas,
         (coalesce(ins.fijos, 0) - coalesce(ins.bajas, 0) + coalesce(res.reservas, 0)) as ocupados,
         case when fr2.canc then 0
              else coalesce(cup.cupo, 0)
                   - (coalesce(ins.fijos, 0) - coalesce(ins.bajas, 0) + coalesce(res.reservas, 0))
         end                                                       as huecos,
         fr2.canc
    from fr2
    left join calles ca on ca.franja_id = fr2.id      -- franja sin calles: 1 fila vacía
    left join cup  on cup.franja_id = fr2.id and cup.calle = ca.calle
    left join ins  on ins.franja_id = fr2.id and ins.calle = ca.calle
    left join res  on res.franja_id = fr2.id and res.calle is not distinct from ca.calle
   order by fr2.dia, fr2.hora, public._num_calle(ca.calle) nulls first, ca.calle;
$$;

comment on function public.natacion_ocupacion(date, uuid) is
  'Mig 330 · LA ocupación de natación por franja+calle(+día). fijos − bajas de inscritos + reservas; cupo de cupos; festivo vía hay_excepcion. Sin fecha = solo fijos (semáforo).';

-- Interna: la llaman las funciones SECURITY DEFINER de abajo. Nadie más.
revoke all on function public.natacion_ocupacion(date, uuid) from public, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 3 · natacion_huecos (misma firma): resumen por franja
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.natacion_huecos(p_fecha date)
returns table(franja_id uuid, dia smallint, hora time without time zone, grupo text,
              cupo integer, fijos integer, bajas integer, reservas integer, huecos integer)
language sql stable security definer
set search_path to 'public'
as $$
  select o.franja_id, o.dia, o.hora, o.grupo,
         coalesce(sum(o.cupo) filter (where o.en_cupos), 0)::int,
         sum(o.fijos)::int,
         sum(o.bajas)::int,
         sum(o.reservas)::int,
         case when bool_or(o.cancelado) then 0
              else greatest(0,
                     coalesce(sum(greatest(o.huecos, 0)) filter (where o.en_cupos), 0)
                     - coalesce(sum(o.ocupados) filter (where o.calle is null), 0))
         end::int
    from public.natacion_ocupacion(p_fecha) o
   where (public.es_admin() or public.es_staff()
          or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
   group by o.franja_id, o.dia, o.hora, o.grupo
   order by o.hora;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4 · natacion_huecos_calle (misma firma): por calle de cupos
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.natacion_huecos_calle(p_franja uuid, p_fecha date)
returns table(calle text, cupo integer, ocupados integer, huecos integer)
language sql stable security definer
set search_path to 'public'
as $$
  select o.calle, o.cupo, o.ocupados, o.huecos
    from public.natacion_ocupacion(p_fecha, p_franja) o
   where o.en_cupos
     and (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')
          or exists (select 1 from public.natacion_master_yo()))
   order by o.calle;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 5 · ¿En qué calle va alguien que se incorpora un día? (bono / cambio)
--     Una en la que ya nada como fijo (la que más repite) y, si no, la más
--     alta a la que llega por número (como el bono máster). Solo calles de
--     cupos CON hueco ese día. NULL si no hay ninguna.
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public._natacion_calle_para(p_acceso uuid, p_franja uuid, p_fecha date)
returns text
language sql stable
set search_path to 'public'
as $$
  with mio as (
    select max(public._num_calle(i.calle)) as maxnum
      from public.natacion_inscripciones i
     where i.acceso_id = p_acceso and i.activa
  )
  select o.calle
    from public.natacion_ocupacion(p_fecha, p_franja) o
    cross join mio
    cross join lateral (
      select count(*) as n from public.natacion_inscripciones i
       where i.acceso_id = p_acceso and i.activa and i.calle = o.calle) s
   where o.en_cupos and o.huecos > 0
     and (s.n > 0 or public._num_calle(o.calle) <= coalesce(mio.maxnum, 1))
   order by (s.n > 0) desc, s.n desc, public._num_calle(o.calle) desc nulls last
   limit 1;
$$;

revoke all on function public._natacion_calle_para(uuid, uuid, date) from public, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 5b · REGLA DE NIVEL (Andrés, 13-oct): con bono solo se va a tu calle o a
--      una de MENOS nivel. C1 → solo C1; C2 → C2 y C1; C3 → C3, C2 y C1.
--      Una calle en la que ya nada como fijo siempre vale (p. ej. el Vaso).
--      Sin calle fija conocida, se le trata como C1.
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public._natacion_puede_calle(p_acceso uuid, p_calle text)
returns boolean
language sql stable
set search_path to 'public'
as $$
  select exists (select 1 from public.natacion_inscripciones i
                  where i.acceso_id = p_acceso and i.activa and i.calle = p_calle)
      or coalesce(public._num_calle(p_calle) <=
           coalesce((select max(public._num_calle(i.calle)) from public.natacion_inscripciones i
                      where i.acceso_id = p_acceso and i.activa), 1), false);
$$;

revoke all on function public._natacion_puede_calle(uuid, text) from public, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 6 · natacion_reservar (misma firma): ahora mira el hueco de la CALLE
--     · p_calle dada  → esa calle tiene que existir en cupos y tener hueco.
--     · p_calle NULL  → su calle (_natacion_calle_para). Si ninguna de las
--       suyas tiene hueco, NO se reserva (antes se colaba en una llena).
--     · Día cancelado (festivo/cierre) → no se reserva.
--     · Ya fijo de esa franja o ya reservado ese día → no se duplica.
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.natacion_reservar(p_franja uuid, p_fecha date, p_acceso_id uuid, p_calle text default null)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_saldo int; v_nombre text; v_calle text; v_h int; v_mis text;
begin
  if not (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;
  select saldo, nombre into v_saldo, v_nombre from public.natacion_abonos where acceso_id = p_acceso_id;
  if v_saldo is null then return jsonb_build_object('ok', false, 'msg', 'Esa persona no tiene abono. Dale clases primero.'); end if;
  if v_saldo <= 0 then return jsonb_build_object('ok', false, 'msg', 'No le quedan clases de abono.'); end if;

  if not exists (select 1 from public.natacion_franjas f
                  where f.id = p_franja and coalesce(f.activa, true)
                    and f.dia = extract(isodow from p_fecha)::smallint) then
    return jsonb_build_object('ok', false, 'msg', 'Esa franja no existe ese día.'); end if;

  if exists (select 1 from public.natacion_ocupacion(p_fecha, p_franja) o where o.cancelado) then
    return jsonb_build_object('ok', false, 'msg', 'Ese día no hay natación (festivo o cierre).'); end if;

  if exists (select 1 from public.natacion_inscripciones i
              where i.franja_id = p_franja and i.acceso_id = p_acceso_id and i.activa) then
    return jsonb_build_object('ok', false, 'msg', 'Ya es fijo de esa franja.'); end if;
  if exists (select 1 from public.natacion_reservas r
              where r.franja_id = p_franja and r.fecha = p_fecha
                and r.acceso_id = p_acceso_id and r.estado = 'reservada') then
    return jsonb_build_object('ok', false, 'msg', 'Ya tiene esa sesión reservada.'); end if;

  p_calle := nullif(btrim(coalesce(p_calle, '')), '');
  if p_calle is not null then
    select o.huecos into v_h
      from public.natacion_ocupacion(p_fecha, p_franja) o
     where o.en_cupos and o.calle = p_calle;
    if not found then
      return jsonb_build_object('ok', false, 'msg', 'Esa calle no existe en esa franja.'); end if;
    if not public._natacion_puede_calle(p_acceso_id, p_calle) then
      return jsonb_build_object('ok', false, 'msg',
        'Por su nivel no puede ir a la calle ' || p_calle || ': con bono solo a su calle o a una de menos nivel.'); end if;
    if v_h <= 0 then
      return jsonb_build_object('ok', false, 'msg', 'La calle ' || p_calle || ' está completa ese día.'); end if;
    v_calle := p_calle;
  else
    v_calle := public._natacion_calle_para(p_acceso_id, p_franja, p_fecha);
    if v_calle is null then
      select string_agg(distinct i.calle, ', ') into v_mis
        from public.natacion_inscripciones i where i.acceso_id = p_acceso_id and i.activa;
      return jsonb_build_object('ok', false, 'msg',
        'No hay hueco en su calle ese día' || coalesce(' (nada en ' || v_mis || ')', '') ||
        '. Prueba otra franja.'); end if;
  end if;

  insert into public.natacion_reservas(franja_id, fecha, acceso_id, nombre, calle, creada_por)
    values (p_franja, p_fecha, p_acceso_id,
            coalesce(v_nombre, (select nombre from public.natacion_accesos where id = p_acceso_id)),
            v_calle, public.mi_perfil_id());
  update public.natacion_abonos set saldo = saldo - 1, updated_at = now() where acceso_id = p_acceso_id;
  return jsonb_build_object('ok', true, 'calle', v_calle,
    'msg', 'Reserva hecha en la calle ' || v_calle || '. Le queda(n) ' || (v_saldo - 1) || ' clase(s).');
end $$;

-- ─────────────────────────────────────────────────────────────────────────
-- 7 · natacion_incorporar_manual (misma firma, pasar lista «ha venido»):
--     NO se bloquea (la persona está en la piscina), pero
--     · sin calle → se le pone la suya si tiene hueco (_natacion_calle_para);
--     · si su calle queda por encima del cupo ese día, el mensaje lo avisa.
--     Idéntica a la 307 en todo lo demás.
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.natacion_incorporar_manual(p_franja uuid, p_fecha date, p_acceso_id uuid, p_calle text default null)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_nombre text; v_saldo int; v_calle text; v_o record; v_aviso text := '';
begin
  if not (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.');
  end if;
  if p_franja is null or p_fecha is null or p_acceso_id is null then
    return jsonb_build_object('ok', false, 'msg', 'Faltan datos.');
  end if;
  select nombre into v_nombre from public.natacion_accesos where id = p_acceso_id;
  if v_nombre is null then
    return jsonb_build_object('ok', false, 'msg', 'Esa persona no existe.');
  end if;
  if exists (select 1 from public.natacion_inscripciones i
             where i.franja_id = p_franja and i.acceso_id = p_acceso_id and i.activa) then
    return jsonb_build_object('ok', false, 'msg', v_nombre || ' ya es fijo de esa franja.');
  end if;
  if exists (select 1 from public.natacion_reservas r
             where r.franja_id = p_franja and r.fecha = p_fecha
               and r.acceso_id = p_acceso_id and r.estado = 'reservada') then
    return jsonb_build_object('ok', true, 'msg', v_nombre || ' ya estaba en la lista.');
  end if;
  v_calle := coalesce(nullif(btrim(coalesce(p_calle, '')), ''),
                      public._natacion_calle_para(p_acceso_id, p_franja, p_fecha));
  insert into public.natacion_reservas(franja_id, fecha, acceso_id, nombre, calle, creada_por)
    values (p_franja, p_fecha, p_acceso_id, v_nombre, v_calle, public.mi_perfil_id());
  select saldo into v_saldo from public.natacion_abonos where acceso_id = p_acceso_id;
  if coalesce(v_saldo, 0) > 0 then
    update public.natacion_abonos set saldo = saldo - 1, updated_at = now() where acceso_id = p_acceso_id;
  end if;
  if v_calle is not null and not public._natacion_puede_calle(p_acceso_id, v_calle) then
    v_aviso := ' Ojo: la calle ' || v_calle || ' es de más nivel que la suya.';
  end if;
  if v_calle is not null then
    select o.cupo, o.ocupados, o.en_cupos into v_o
      from public.natacion_ocupacion(p_fecha, p_franja) o where o.calle = v_calle;
    if found and (not v_o.en_cupos or v_o.ocupados > v_o.cupo) then
      v_aviso := v_aviso || ' Ojo: la calle ' || v_calle || ' queda por encima de su cupo ese día (' ||
                 v_o.ocupados || ' de ' || v_o.cupo || ').';
    end if;
  end if;
  return jsonb_build_object('ok', true, 'calle', v_calle,
    'msg', v_nombre || ' añadido a la lista' ||
           case when v_calle is not null then ' (calle ' || v_calle || ')' else '' end ||
           case when coalesce(v_saldo,0) > 0 then ' (usa 1 bono)' else '' end || '.' || v_aviso);
end $$;
