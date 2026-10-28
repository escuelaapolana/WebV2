-- 466 · Ropa Joma de natación: la tienda hace de ESCAPARATE
-- ---------------------------------------------------------------------------
-- Andrés (28-oct-2026): «lo de Joma, que salga en la tienda sin precios. Que
-- salga la dirección de donde se compra y ya está. Nosotros hacemos de
-- escaparate». Se compra directamente en SNSport (Loren lo acordó con ellos).
--   · productos.donde_comprar: si tiene texto, la prenda es de escaparate: la
--     tienda la enseña con foto, nombre y dónde se compra, SIN precio ni
--     «Añadir». No sale en el formulario de equipación.
--   · El catálogo de natación (mig 465) ya no fuerza equipacion_natacion en
--     las de escaparate.
-- Las Joma siguen APAGADAS: se encienden cuando esté subida la tienda nueva
-- (si no, saldrían con precio y botón de encargar).
-- ---------------------------------------------------------------------------
begin;

alter table public.productos add column if not exists donde_comprar text;
grant select (donde_comprar) on public.productos to anon, authenticated;
grant insert (donde_comprar), update (donde_comprar) on public.productos to authenticated;
comment on column public.productos.donde_comprar is '466 · Escaparate: dónde se compra (la tienda no la vende ni enseña precio; no sale en el formulario de equipación).';

update public.productos
   set donde_comprar = 'SNSport · C/ Médico Pascual Pérez, 20 · Alicante',
       equipacion_natacion = false
 where nombre like '%Joma%' and seccion = 'natacion';

-- Catálogo de natación: también el texto de «dónde se compra»; las de escaparate no van al formulario.
do $$
declare d text;
begin
  select pg_get_functiondef('public.natacion_ropa_producto_guardar(uuid,jsonb)'::regprocedure) into d;
  if position('equipacion_natacion = true' in d) = 0 then raise exception 'natacion_ropa_producto_guardar ha cambiado'; end if;
  d := replace(d, 'equipacion_natacion = true',
    'donde_comprar      = case when d ? ''donde_comprar'' then nullif(btrim(d ->> ''donde_comprar''), '''') else donde_comprar end,
    equipacion_natacion = (case when d ? ''donde_comprar'' then nullif(btrim(d ->> ''donde_comprar''), '''') else donde_comprar end) is null');
  execute d;
end $$;

create or replace function public.natacion_ropa_productos()
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la ropa de natación.' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', pr.id, 'nombre', pr.nombre, 'descripcion', pr.descripcion, 'precio', pr.precio,
                                        'categoria', pr.categoria, 'tallas', pr.tallas_disponibles, 'imagen', pr.imagen_url,
                                        'activo', pr.activo, 'formulario', pr.equipacion_natacion, 'seccion', pr.seccion,
                                        'editable', pr.seccion = 'natacion', 'donde_comprar', pr.donde_comprar)
                     order by pr.seccion <> 'natacion', coalesce(pr.categoria, '') = 'banador' desc, pr.orden nulls last, pr.nombre)
      from public.productos pr
     where pr.seccion = 'natacion' or pr.equipacion_natacion), '[]');
end;
$$;

commit;
