-- 268_cobro_a_grupo.sql
-- Cobros · «Cobrar a un grupo»: crear de una vez un recibo (pagos) por cada
-- atleta de un grupo. Base del centro de cobros (Bloque 1 CAPA A).
--
-- Reutiliza la tabla `pagos` (libro de recibos, mig 030). Añade `lote` para
-- poder identificar/deshacer la tanda entera. El cobro individual ya existe
-- («+ Nuevo recibo» inserta un pagos de una persona); lo nuevo es el GRUPO.
--
-- Gate: es_admin() o puede_girar() (tesorería). SECURITY DEFINER.
-- Dedupe: no duplica si el atleta ya tiene un recibo NO anulado con el mismo
-- concepto y (si se da) el mismo periodo.

begin;

-- 1) Etiqueta de tanda (para ver/deshacer el lote entero)
alter table public.pagos add column if not exists lote uuid;
create index if not exists pagos_lote_idx on public.pagos (lote) where lote is not null;

-- 2) RPC: cobrar a todos los atletas de un grupo
create or replace function public.cobro_grupo_crear(
  p_grupo       uuid,
  p_concepto    text,
  p_importe     numeric,
  p_cuenta      text  default null,
  p_periodo     text  default null,
  p_vencimiento date  default null,
  p_metodo      text  default 'domiciliado',
  p_notas       text  default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_lote     uuid := gen_random_uuid();
  v_creados  int  := 0;
  v_omitidos int  := 0;
  v_candidatos int := 0;
  v_concepto text := btrim(coalesce(p_concepto, ''));
  v_periodo  text := nullif(btrim(coalesce(p_periodo, '')), '');
begin
  if not (public.es_admin() or public.puede_girar()) then
    raise exception 'Sin permiso para girar cobros.' using errcode = '42501';
  end if;
  if p_grupo is null then
    raise exception 'Falta el grupo.';
  end if;
  if v_concepto = '' then
    raise exception 'Falta el concepto.';
  end if;
  if p_importe is null or p_importe <= 0 then
    raise exception 'El importe debe ser mayor que 0.';
  end if;

  -- Atletas activos del grupo (excluye bajas)
  select count(*) into v_candidatos
  from public.atletas a
  where a.grupo_id = p_grupo
    and coalesce(a.estado, 'activo') <> 'baja';

  -- Inserta un recibo por atleta que NO tenga ya uno igual sin anular
  with nuevos as (
    insert into public.pagos
      (atleta_id, concepto, importe, estado, cuenta, periodo,
       fecha_vencimiento, metodo, notas, lote)
    select a.id, v_concepto, p_importe, 'pendiente',
           nullif(btrim(coalesce(p_cuenta,'')),''), v_periodo,
           p_vencimiento, nullif(btrim(coalesce(p_metodo,'')),''),
           nullif(btrim(coalesce(p_notas,'')),''), v_lote
    from public.atletas a
    where a.grupo_id = p_grupo
      and coalesce(a.estado, 'activo') <> 'baja'
      and not exists (
        select 1 from public.pagos p
        where p.atleta_id = a.id
          and p.anulado = false
          and lower(btrim(p.concepto)) = lower(v_concepto)
          and coalesce(p.periodo,'') = coalesce(v_periodo,'')
      )
    returning 1
  )
  select count(*) into v_creados from nuevos;

  v_omitidos := v_candidatos - v_creados;

  return jsonb_build_object(
    'lote',       v_lote,
    'creados',    v_creados,
    'omitidos',   v_omitidos,
    'candidatos', v_candidatos,
    'total',      round(v_creados * p_importe, 2)
  );
end;
$$;

revoke all on function public.cobro_grupo_crear(uuid, text, numeric, text, text, date, text, text) from public, anon;
grant execute on function public.cobro_grupo_crear(uuid, text, numeric, text, text, date, text, text) to authenticated;

commit;
