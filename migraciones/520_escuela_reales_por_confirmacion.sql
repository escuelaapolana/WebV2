-- 520 · Ritmo de inscripciones: «Nuevas reales» por FECHA DE CONFIRMACIÓN
-- desde el 5-nov-2026 (Andrés). Cada pasada de la comprobación de Isa (9:00 y
-- 12:30) guarda una foto del día: cuántas nuevas inscripciones están de alta
-- (fila entera en verde). Desde la primera foto, la curva de reales sale de las
-- fotos (sube el día que Isa las pone en verde y baja con las bajas); antes de
-- esa fecha sigue saliendo del día en que se rellenó el formulario, porque ese
-- dato (cuándo se confirmó cada uno) no existe.
create table if not exists public.escuela_reales_dia (
  temporada text not null,
  fecha     date not null,
  reales    int  not null,
  primary key (temporada, fecha)
);
alter table public.escuela_reales_dia enable row level security;
drop policy if exists "admin lee reales dia" on public.escuela_reales_dia;
create policy "admin lee reales dia" on public.escuela_reales_dia
  for select to authenticated using ((select es_admin()));

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
  select x->>'hoja' hoja, (x->>'marca')::date marca, coalesce(x->>'completa', '') = 'verde' real
    from jsonb_array_elements(coalesce(p_filas, '[]')) x
   where x->>'hoja' in ('inscripcion', 'renovacion')
     and coalesce(x->>'marca', '') ~ '^\d{4}-\d{2}-\d{2}$'
     and btrim(coalesce(x->>'nombre', '') || coalesce(x->>'ap1', '')) <> '';
  select count(*) into v_n from _m;
  if v_n = 0 then return jsonb_build_object('ok', true, 'temporada', v_temp, 'motivo', 'sin marcas'); end if;

  -- (mig 520) Foto de HOY: cuántas nuevas están de alta ahora mismo. Desde que
  -- hay fotos, las «reales» de cada día salen de la última foto (= fecha de
  -- confirmación); antes, del día en que rellenaron el formulario.
  insert into public.escuela_reales_dia (temporada, fecha, reales)
  values (v_temp, v_hoy, (select count(*) from _m where hoja = 'inscripcion' and real))
  on conflict (temporada, fecha) do update set reales = excluded.reales;

  delete from public.escuela_inscripciones_dia where temporada = v_temp and programa = 'escuela';
  insert into public.escuela_inscripciones_dia (temporada, n_dia, fecha, nuevas_acum, renov_acum, total_acum, nuevas_dia, renov_dia, reales_acum)
  select v_temp, d.n, d.f, d.nu, d.re, d.nu + d.re,
         d.nu - coalesce(lag(d.nu) over (order by d.n), 0),
         d.re - coalesce(lag(d.re) over (order by d.n), 0),
         d.rl
    from (select g.n, (v_ini + g.n - 1) f,
                 (select count(*) from _m where hoja = 'inscripcion' and marca <= v_ini + g.n - 1)::int nu,
                 (select count(*) from _m where hoja = 'renovacion'  and marca <= v_ini + g.n - 1)::int re,
                 coalesce((select r.reales from public.escuela_reales_dia r
                            where r.temporada = v_temp and r.fecha <= v_ini + g.n - 1 order by r.fecha desc limit 1),
                          (select count(*) from _m where hoja = 'inscripcion' and real and marca <= v_ini + g.n - 1))::int rl
            from generate_series(1, v_dias) g(n)) d;

  return jsonb_build_object('ok', true, 'temporada', v_temp, 'dias', v_dias, 'filas', v_n);
end $$;
revoke execute on function public.escuela_ritmo_registrar(text, jsonb) from public, anon, authenticated;
grant execute on function public.escuela_ritmo_registrar(text, jsonb) to service_role;
