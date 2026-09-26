-- 227 · Comunicar prueba / proponer carrera desde la WEB PÚBLICA (sin login)
--
-- La página pública de la Liga tendrá los formularios. La persona pone SUS
-- datos (nombre, apellidos, DNI o email); estas funciones `security definer`
-- CRUZAN con el padrón de atletas (por DNI o email) para enlazar su ficha y NO
-- duplicar, e insertan la prueba como `pendiente` (la valida el club después).
-- Si no casan, va con `nombre_libre` y el contacto en `notas` para cruzarla a
-- mano. Callables por anon; las tablas siguen con su RLS (esto la salta como
-- definer, acotado a insertar pendiente).

-- ---------------------------------------------------------------------------
-- Comunicar una prueba
-- ---------------------------------------------------------------------------
create or replace function public.liga_comunicar_prueba(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_ed uuid; v_atleta uuid; v_nombre text; v_dni text; v_email text;
begin
  -- honeypot antispam: si un bot rellena el campo oculto, se traga sin insertar
  if coalesce(p->>'web','') <> '' then return jsonb_build_object('ok', true); end if;

  if coalesce(p->>'nombre','')='' or coalesce(p->>'apellidos','')=''
     or coalesce(p->>'competicion','')='' or coalesce(p->>'fecha','')=''
     or coalesce(p->>'baremo_id','')='' then
    return jsonb_build_object('ok', false, 'error', 'faltan_datos');
  end if;

  select id into v_ed from public.liga_ediciones where activa limit 1;
  if v_ed is null then return jsonb_build_object('ok', false, 'error', 'sin_edicion'); end if;

  v_dni   := nullif(regexp_replace(upper(coalesce(p->>'dni','')), '[^A-Z0-9]', '', 'g'), '');
  v_email := lower(nullif(btrim(coalesce(p->>'email','')), ''));

  -- Cruce con el padrón: primero por DNI, luego por email
  v_atleta := null;
  if v_dni is not null then
    select id into v_atleta from public.atletas
     where dni is not null and regexp_replace(upper(dni), '[^A-Z0-9]', '', 'g') = v_dni limit 1;
  end if;
  if v_atleta is null and v_email is not null then
    select id into v_atleta from public.atletas
     where email is not null and lower(email) = v_email limit 1;
  end if;

  v_nombre := btrim((p->>'nombre') || ' ' || (p->>'apellidos'));

  insert into public.liga_participaciones(
    edicion_id, atleta_id, nombre_libre, fecha, competicion, baremo_id, distancia_km,
    enlace_clasificacion, inscrito_como_club, con_ropa_club, estado, notas)
  values (
    v_ed, v_atleta,
    case when v_atleta is null then v_nombre else null end,
    (p->>'fecha')::date, btrim(p->>'competicion'), (p->>'baremo_id')::uuid,
    case when coalesce(p->>'km','') <> '' then (replace(p->>'km', ',', '.'))::numeric else null end,
    nullif(btrim(coalesce(p->>'enlace','')), ''),
    coalesce((p->>'club')::boolean, false), coalesce((p->>'ropa')::boolean, false),
    'pendiente',
    'Comunicada desde la web. '
      || case when v_atleta is null then 'SIN cruzar con el padrón (revisar). ' else 'Cruzada por DNI/email. ' end
      || 'Contacto: ' || v_nombre
      || coalesce(' · DNI ' || nullif(btrim(coalesce(p->>'dni','')), ''), '')
      || coalesce(' · ' || v_email, '')
      || coalesce(' · tel ' || nullif(btrim(coalesce(p->>'telefono','')), ''), ''));

  return jsonb_build_object('ok', true, 'cruzada', v_atleta is not null);
end $$;

-- ---------------------------------------------------------------------------
-- Proponer una carrera que falta
-- ---------------------------------------------------------------------------
create or replace function public.liga_proponer_carrera(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_ed uuid;
begin
  if coalesce(p->>'web','') <> '' then return jsonb_build_object('ok', true); end if;
  if coalesce(p->>'nombre','')='' then return jsonb_build_object('ok', false, 'error', 'faltan_datos'); end if;
  select id into v_ed from public.liga_ediciones where activa limit 1;

  insert into public.liga_propuestas_prueba(
    edicion_id, nombre, fecha, lugar, disciplina, modalidad_sugerida, enlace, estado, notas_club)
  values (
    v_ed, btrim(p->>'nombre'), nullif(btrim(coalesce(p->>'fecha','')), '')::date,
    nullif(btrim(coalesce(p->>'lugar','')), ''), nullif(btrim(coalesce(p->>'disciplina','')), ''),
    nullif(btrim(coalesce(p->>'modalidad','')), ''), nullif(btrim(coalesce(p->>'enlace','')), ''),
    'pendiente',
    'Propuesta desde la web. Por: ' || coalesce(nullif(btrim(coalesce(p->>'quien','')), ''), 'anónimo')
      || coalesce(' · ' || nullif(btrim(coalesce(p->>'contacto','')), ''), ''));

  return jsonb_build_object('ok', true);
end $$;

grant execute on function public.liga_comunicar_prueba(jsonb)  to anon, authenticated;
grant execute on function public.liga_proponer_carrera(jsonb)  to anon, authenticated;
