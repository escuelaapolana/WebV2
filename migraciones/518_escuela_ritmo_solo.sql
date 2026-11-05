-- 518 · Escuela: el «Ritmo de inscripciones» se rellena SOLO (5-nov-2026).
-- El script de Google de Isa (BUENO ISA / BUENA ISA) ya manda sus filas a la
-- app dos veces al día (escuela-isa-sync). Desde ahora manda también la
-- «Marca temporal» de cada fila (campo `marca`, AAAA-MM-DD), y con eso se
-- rehace la curva día a día de la temporada en curso en escuela_inscripciones_dia:
--   · nuevas  = filas de la hoja de Inscripción (inscritos + bajas, como el Excel)
--   · renov   = filas de la hoja de Renovación
--   · día 1   = 2 de septiembre (lo de antes, preinscripciones de julio y
--               agosto, cuenta en el día 1, igual que en los Excel de otros años)
-- Temporada = la del día de hoy (de julio a junio): 2026.27, 2027.28…
-- Solo la llama la Edge (service_role) con el mismo token de la sincronización.
create or replace function public.escuela_ritmo_registrar(p_token text, p_filas jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_tok text;
  v_hoy date := (now() at time zone 'Europe/Madrid')::date;
  v_y int; v_ini date; v_temp text; v_dias int;
  v_n int;
begin
  select decrypted_secret into v_tok from vault.decrypted_secrets where name = 'escuela_sync_token';
  if v_tok is null or p_token is null or p_token <> v_tok then
    raise exception 'token' using errcode = '42501';
  end if;

  v_y := case when extract(month from v_hoy) >= 7 then extract(year from v_hoy)::int else extract(year from v_hoy)::int - 1 end;
  v_ini := make_date(v_y, 9, 2);
  v_temp := v_y::text || '.' || lpad(((v_y + 1) % 100)::text, 2, '0');
  v_dias := v_hoy - v_ini + 1;
  if v_dias < 1 then return jsonb_build_object('ok', true, 'temporada', v_temp, 'motivo', 'aún no empieza'); end if;
  v_dias := least(v_dias, 320);

  create temp table _m on commit drop as
  select x->>'hoja' hoja, (x->>'marca')::date marca
    from jsonb_array_elements(coalesce(p_filas, '[]')) x
   where x->>'hoja' in ('inscripcion', 'renovacion')
     and coalesce(x->>'marca', '') ~ '^\d{4}-\d{2}-\d{2}$'
     and btrim(coalesce(x->>'nombre', '') || coalesce(x->>'ap1', '')) <> '';
  select count(*) into v_n from _m;
  if v_n = 0 then return jsonb_build_object('ok', true, 'temporada', v_temp, 'motivo', 'sin marcas'); end if;

  delete from public.escuela_inscripciones_dia where temporada = v_temp and programa = 'escuela';
  insert into public.escuela_inscripciones_dia (temporada, n_dia, fecha, nuevas_acum, renov_acum, total_acum, nuevas_dia, renov_dia)
  select v_temp, d.n, d.f, d.nu, d.re, d.nu + d.re,
         d.nu - coalesce(lag(d.nu) over (order by d.n), 0),
         d.re - coalesce(lag(d.re) over (order by d.n), 0)
    from (select g.n, (v_ini + g.n - 1) f,
                 (select count(*) from _m where hoja = 'inscripcion' and marca <= v_ini + g.n - 1)::int nu,
                 (select count(*) from _m where hoja = 'renovacion'  and marca <= v_ini + g.n - 1)::int re
            from generate_series(1, v_dias) g(n)) d;

  return jsonb_build_object('ok', true, 'temporada', v_temp, 'dias', v_dias, 'filas', v_n);
end $$;
revoke execute on function public.escuela_ritmo_registrar(text, jsonb) from public, anon, authenticated;
grant execute on function public.escuela_ritmo_registrar(text, jsonb) to service_role;
