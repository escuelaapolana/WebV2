-- 269_cobro_grupo_por_persona.sql
-- Cobros · «Cobrar a un grupo» pero con el importe y la periodicidad de CADA
-- persona (no todos pagan lo mismo). Base: paso 2 del centro de cobros.
--
-- · Guarda en la ficha del atleta su cuota (cuánto y cada cuánto) para que la
--   próxima vez salga ya rellena: atletas.cuota_importe + cuota_periodicidad.
-- · RPC cobro_grupo_lineas: recibe una línea por persona {atleta_id, importe,
--   periodicidad} y crea un `pagos` por cada una (con dedupe por concepto+periodo),
--   opcionalmente recordando la cuota en la ficha. Reutiliza pagos.lote (mig 268).
--
-- Gate: es_admin() o puede_girar(). SECURITY DEFINER.

begin;

-- 1) La cuota recordada de cada atleta (cuánto paga y cada cuánto)
alter table public.atletas add column if not exists cuota_importe      numeric;
alter table public.atletas add column if not exists cuota_periodicidad text;

-- 2) RPC: crear un recibo por persona con su propio importe
create or replace function public.cobro_grupo_lineas(
  p_concepto      text,
  p_periodo       text,
  p_vencimiento   date,
  p_cuenta        text,
  p_metodo        text,
  p_lineas        jsonb,                 -- [{atleta_id, importe, periodicidad}]
  p_guardar_cuota boolean default true,
  p_notas         text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_lote     uuid := gen_random_uuid();
  v_rec      jsonb;
  v_atleta   uuid;
  v_importe  numeric;
  v_per      text;
  v_creados  int := 0;
  v_omitidos int := 0;
  v_total    numeric := 0;
  v_concepto text := btrim(coalesce(p_concepto,''));
  v_periodo  text := nullif(btrim(coalesce(p_periodo,'')),'');
begin
  if not (public.es_admin() or public.puede_girar()) then
    raise exception 'Sin permiso para girar cobros.' using errcode = '42501';
  end if;
  if v_concepto = '' then
    raise exception 'Falta el concepto.';
  end if;
  if p_lineas is null or jsonb_typeof(p_lineas) <> 'array' or jsonb_array_length(p_lineas) = 0 then
    raise exception 'No hay personas a las que cobrar.';
  end if;

  for v_rec in select * from jsonb_array_elements(p_lineas) loop
    v_atleta  := nullif(v_rec->>'atleta_id','')::uuid;
    v_importe := nullif(v_rec->>'importe','')::numeric;
    v_per     := nullif(btrim(coalesce(v_rec->>'periodicidad','')),'');
    -- Sin atleta o sin importe válido: se salta en silencio
    if v_atleta is null or v_importe is null or v_importe <= 0 then
      continue;
    end if;
    -- Dedupe: ya tiene un recibo igual sin anular (mismo concepto + periodo)
    if exists (
      select 1 from public.pagos p
      where p.atleta_id = v_atleta
        and p.anulado = false
        and lower(btrim(p.concepto)) = lower(v_concepto)
        and coalesce(p.periodo,'') = coalesce(v_periodo,'')
    ) then
      v_omitidos := v_omitidos + 1;
      continue;
    end if;

    insert into public.pagos
      (atleta_id, concepto, importe, estado, cuenta, periodo,
       fecha_vencimiento, metodo, notas, lote)
    values
      (v_atleta, v_concepto, v_importe, 'pendiente',
       nullif(btrim(coalesce(p_cuenta,'')),''), v_periodo,
       p_vencimiento, nullif(btrim(coalesce(p_metodo,'')),''),
       nullif(btrim(coalesce(p_notas,'')),''), v_lote);

    v_creados := v_creados + 1;
    v_total   := v_total + v_importe;

    if p_guardar_cuota then
      update public.atletas
         set cuota_importe = v_importe, cuota_periodicidad = v_per
       where id = v_atleta;
    end if;
  end loop;

  return jsonb_build_object(
    'lote',     v_lote,
    'creados',  v_creados,
    'omitidos', v_omitidos,
    'total',    round(v_total, 2)
  );
end;
$$;

revoke all on function public.cobro_grupo_lineas(text, text, date, text, text, jsonb, boolean, text) from public, anon;
grant execute on function public.cobro_grupo_lineas(text, text, date, text, text, jsonb, boolean, text) to authenticated;

commit;
