-- 433 · Tienda: filtro por SECCIÓN (Andrés, 22-oct-2026: «que tenga un filtro por sección»)
-- productos.seccion: 'club' (ropa del club, para todos) · 'atletismo' (competición)
-- · 'triatlon' · 'natacion'. La tienda enseña chips con las que tengan algo y
-- acepta /tienda/?seccion=triatlon para mandar el enlace ya filtrado a un grupo.
-- `productos` tiene permisos por columna: la nueva necesita su grant (si no,
-- el select('*') del panel falla).
begin;
alter table public.productos add column if not exists seccion text not null default 'club'
  check (seccion in ('club', 'atletismo', 'triatlon', 'natacion'));
grant select (seccion) on public.productos to anon, authenticated;
grant insert (seccion), update (seccion) on public.productos to authenticated;

update public.productos set seccion = 'triatlon'  where nombre ilike 'mono de triatl%';
update public.productos set seccion = 'atletismo' where seccion = 'club' and categoria = 'equipacion' and nombre not ilike 'mono de triatl%';
commit;
