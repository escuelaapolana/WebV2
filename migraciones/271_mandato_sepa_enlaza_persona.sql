-- 271_mandato_sepa_enlaza_persona.sql
-- SEPA · que un mandato firmado DESDE EL PORTAL quede enlazado a la persona.
--
-- Hasta ahora firmar_mandato_sepa guardaba titular+IBAN+firma pero NO perfil_id
-- ni atleta_id (las columnas existen pero quedaban vacías), así que no se sabía
-- de quién era un mandato firmado desde el portal. Para poder recoger los IBAN
-- de Velocidad/Academia hace falta saberlo.
--
-- Cambio mínimo y seguro:
--   · perfil_id := auth.uid()  → en el portal es la persona con sesión; en el
--     alta pública (anónima) es null, como hasta ahora. NO se fía del navegador.
--   · atleta_id := el que venga en p, SOLO si es un atleta de esa persona.
-- Todo lo demás (validaciones, honeypot, texto de la base) queda igual.

begin;

create or replace function public.firmar_mandato_sepa(p jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_iban   text := upper(replace(coalesce(p ->> 'iban', ''), ' ', ''));
  v_texto  public.sepa_mandato_texto%rowtype;
  v_firma  text := coalesce(p ->> 'firma_png', '');
  v_ref    text;
  v_segundos int := coalesce((p ->> 'segundos')::int, 0);
  v_perfil uuid := auth.uid();
  v_atleta uuid := nullif(p ->> 'atleta_id', '')::uuid;
begin
  if public.texto_de_fuera(p ->> 'apellido_de_soltera', 100) is not null
     or v_segundos < 6 then
    return jsonb_build_object('ok', true, 'referencia', public.referencia_corta('SEPA'));
  end if;

  if not public.altas_hay_sitio('sepa') then
    return jsonb_build_object('ok', false, 'motivo', 'demasiados',
      'mensaje', 'Ahora mismo no podemos recoger más órdenes. Prueba dentro de un rato.');
  end if;

  select * into v_texto from public.sepa_mandato_texto where activo limit 1;
  if v_texto.id is null then
    return jsonb_build_object('ok', false, 'motivo', 'sin-texto',
      'mensaje', 'Todavía no se puede firmar aquí. Escríbenos y lo hacemos contigo.');
  end if;

  if v_iban !~ '^[A-Z]{2}[0-9A-Z]{13,32}$' then
    return jsonb_build_object('ok', false, 'motivo', 'iban',
      'mensaje', 'Revisa el número de cuenta: un IBAN español son 24 caracteres y empieza por ES.');
  end if;

  if public.texto_de_fuera(p ->> 'titular', 140) is null then
    return jsonb_build_object('ok', false, 'motivo', 'titular',
      'mensaje', 'Falta el nombre del titular de la cuenta.');
  end if;

  if v_firma !~ '^data:image/png;base64,' or length(v_firma) < 800 then
    return jsonb_build_object('ok', false, 'motivo', 'firma',
      'mensaje', 'Falta la firma. Dibújala con el dedo en el recuadro.');
  end if;
  if length(v_firma) > 400000 then
    return jsonb_build_object('ok', false, 'motivo', 'firma',
      'mensaje', 'La firma no se ha podido guardar. Bórrala y vuelve a intentarlo.');
  end if;

  -- El atleta solo se enlaza si es de esta persona (no se fía de lo que llegue).
  if v_atleta is not null and v_perfil is not null then
    if not exists (
      select 1 from public.atletas a
      where a.id = v_atleta
        and (a.perfil_id = v_perfil or a.perfil_padre_id = v_perfil)
    ) then
      v_atleta := null;
    end if;
  else
    v_atleta := null;
  end if;

  v_ref := public.referencia_corta('SEPA');

  insert into public.mandatos_sepa (
    referencia, origen, alta_escuela_id, alta_socio_id, perfil_id, atleta_id,
    titular, iban, direccion, cp, localidad, tipo_pago,
    lugar_firma, firma_png, texto_mandato,
    cif_acreedor, identificador_acreedor, ip, navegador
  ) values (
    v_ref,
    coalesce(public.texto_de_fuera(p ->> 'origen', 20), 'portal'),
    nullif(p ->> 'alta_escuela_id', '')::uuid,
    nullif(p ->> 'alta_socio_id', '')::uuid,
    v_perfil,
    v_atleta,
    public.texto_de_fuera(p ->> 'titular', 140),
    v_iban,
    public.texto_de_fuera(p ->> 'direccion', 200),
    public.texto_de_fuera(p ->> 'cp', 10),
    public.texto_de_fuera(p ->> 'localidad', 80),
    coalesce(public.texto_de_fuera(p ->> 'tipo_pago', 20), 'recurrente'),
    coalesce(public.texto_de_fuera(p ->> 'lugar_firma', 60), 'Alicante'),
    v_firma,
    v_texto.texto,
    v_texto.cif_acreedor,
    v_texto.identificador_acreedor,
    public.ip_peticion(),
    public.navegador_peticion()
  );

  return jsonb_build_object('ok', true, 'referencia', v_ref);
end;
$function$;

commit;
