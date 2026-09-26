-- 229 · Arreglos de seguridad (auditoría 26-sep)

-- ============================================================================
-- ALTO · liga_participaciones: la lectura estaba abierta a CUALQUIER cuenta
--   (policy USING(true)), y el formulario público guarda el contacto
--   (DNI/email/tel) de quien comunica una prueba en la columna `notas`. Eso
--   dejaba esos datos personales a la vista de los cientos de socios/atletas
--   logueados. Se acota: solo staff, o el interesado sobre SUS propias fichas.
--   (La clasificación NO usa esta tabla: tira de las vistas liga_clasificacion_*.)
-- ============================================================================
drop policy if exists "liga participaciones lectura" on public.liga_participaciones;
create policy "liga participaciones lectura" on public.liga_participaciones for select to authenticated
  using (public.es_staff() or atleta_id in (select public.mis_atletas()));

-- ============================================================================
-- BAJO · GRANT SELECT a anon sobrante en tablas sensibles (defensa en profundidad).
--   La RLS ya lo frena, pero el grant no debería estar (un error futuro de policy
--   = fuga inmediata). El front público NO lee estas tablas como anon: usa
--   funciones security definer o inserts sin select.
-- ============================================================================
revoke select on public.atletas                from anon;
revoke select on public.perfiles               from anon;
revoke select on public.pagos                  from anon;
revoke select on public.notas_atleta           from anon;
revoke select on public.lesiones_atleta        from anon;
revoke select on public.liga_participaciones   from anon;
revoke select on public.liga_propuestas_prueba from anon;

-- ============================================================================
-- BAJO · Muchas policies FOR ALL TO public llaman a es_escuela()/mis_atletas_bolsillo();
--   a un anónimo le devolvían "permission denied for function ..." (fuga del nombre
--   de función + fragilidad si algún insert público encadenara .select()). Con EXECUTE
--   para anon, esas funciones devuelven false sin sesión y el SELECT anónimo sale []
--   limpio.
-- ============================================================================
grant execute on function public.es_escuela()           to anon;
grant execute on function public.mis_atletas_bolsillo() to anon;

-- ============================================================================
-- BAJO · liga_comunicar_prueba devolvía `cruzada` (true/false) = oráculo para saber
--   si un DNI/email está en el padrón. El cruce se sigue haciendo en servidor (para
--   no duplicar ficha), pero se deja de chivar el resultado al navegador.
-- ============================================================================
create or replace function public.liga_comunicar_prueba(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_ed uuid; v_atleta uuid; v_nombre text; v_dni text; v_email text;
begin
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
  return jsonb_build_object('ok', true);
end $$;
