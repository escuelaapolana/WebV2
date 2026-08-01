-- ============================================================
-- 029 · TIENDA DEL CLUB · catálogo real y pedidos del socio
-- ------------------------------------------------------------
-- Hasta ahora la tienda era decorado: la página /tienda/ pintaba
-- trece prendas escritas a mano en el HTML, la tabla `productos`
-- estaba vacía y el "carrito" no guardaba nada. Y aunque
-- `pedidos` y `pedido_items` existían desde el principio, ningún
-- socio podía crear un pedido ni ver los suyos, porque las únicas
-- policies eran las de administración (ver 024).
--
-- Esta migración hace tres cosas:
--
--   1) Siembra el catálogo con la ropa que YA estaba escrita en
--      /tienda/index.html (mismos nombres, mismos precios, mismas
--      tallas) y con las fotos que ya están en /assets/img/.
--   2) Añade dos columnas pequeñas a `productos` para poder
--      reproducir la página tal y como está: las tallas que se han
--      quedado sin existencias y el orden en que se enseñan.
--   3) Abre lo justo en RLS: cada persona ve y crea SUS pedidos y
--      nada más. Cambiar el estado sigue siendo cosa del club.
--
-- LO QUE NO HACE (a propósito):
--   · No toca precios ni datos de productos que ya existan: el
--      sembrado solo inserta lo que falta (por nombre).
--   · No hay pasarela de pago. El pedido no cobra nada: se paga
--      con la cuota o al recogerlo en el container. Por eso NO se
--      guarda ningún dato bancario ni estado de pago aquí.
--   · No toca el stock por unidades. El club no lo lleva prenda a
--      prenda; `stock` se queda como está.
--   · No añade policies de UPDATE ni de DELETE para el socio: una
--      vez enviado el pedido, solo el club lo mueve.
-- ============================================================


-- ------------------------------------------------------------
-- 1) PRODUCTOS · dos columnas que faltaban
-- ------------------------------------------------------------
-- `tallas_disponibles` (text[]) ya existía y es la que usa la web.
--
-- tallas_agotadas · la página enseña algunas tallas en gris ("de
--   esta no queda"). Sin esta columna habría que borrar la talla
--   del catálogo, y entonces el club perdería el dato de que esa
--   prenda sí se vende en esa talla. Con ella, la talla se sigue
--   viendo pero no se puede añadir al carrito.
-- orden · para que el catálogo salga agrupado como en la web
--   (equipación de competición primero, luego ropa de abrigo y al
--   final complementos) y no por orden alfabético.

alter table public.productos add column if not exists tallas_agotadas text[];
alter table public.productos add column if not exists orden integer default 100;


-- ------------------------------------------------------------
-- 2) CATÁLOGO · la ropa del club
-- ------------------------------------------------------------
-- Origen de los datos: /tienda/index.html (nombres, precios y
-- tallas tal cual estaban escritos) y /assets/img/tienda-*.jpg
-- (fotos ya subidas al repo). No se inventa ningún precio nuevo.
--
-- Idempotente: solo inserta el producto si no hay ya uno con ese
-- nombre, así que se puede volver a pasar sin duplicar nada ni
-- pisar lo que haya tocado el club desde el panel.

with datos (orden, nombre, categoria, precio, tallas_disponibles, tallas_agotadas, imagen_url) as (
  values
    ( 1, 'Camiseta de competición',      'equipacion', 22.00, array['S','M','L','XL'],      array['XL'], 'tienda-camiseta-competicion.jpg'),
    ( 2, 'Camiseta de tirantes · hombre','equipacion', 20.00, array['S','M','L'],           null::text[], 'tienda-camiseta-tirantes-hombre.jpg'),
    ( 3, 'Camiseta de tirantes · mujer', 'equipacion', 20.00, array['XS','S','M','L'],      null::text[], 'tienda-camiseta-tirantes-mujer.jpg'),
    ( 4, 'Top de competición',           'equipacion', 22.00, array['XS','S','M','L'],      array['L'],  'tienda-top-competicion.jpg'),
    ( 5, 'Mono de velocidad',            'equipacion', 48.00, array['S','M','L'],           null::text[], 'tienda-mono-velocidad.jpg'),
    ( 6, 'Malla corta · hombre',         'ropa',       18.00, array['S','M','L'],           null::text[], 'tienda-malla-corta-hombre.jpg'),
    ( 7, 'Culotte · mujer',              'ropa',       18.00, array['XS','S','M','L'],      null::text[], 'tienda-culotte-mujer.jpg'),
    ( 8, 'Sudadera con capucha',         'ropa',       34.00, array['S','M','L','XL'],      null::text[], 'tienda-sudadera-capucha.jpg'),
    ( 9, 'Chaqueta de chándal',          'ropa',       38.00, array['S','M','L','XL'],      null::text[], 'tienda-chaqueta-chandal.jpg'),
    (10, 'Pantalón de chándal',          'ropa',       28.00, array['S','M','L','XL'],      null::text[], 'tienda-pantalon-chandal.jpg'),
    (11, 'Parka del club',               'ropa',       55.00, array['M','L','XL'],          null::text[], 'tienda-parka.jpg'),
    (12, 'Braga de cuello',              'accesorio',   9.00, array['ÚNICA'],               null::text[], 'tienda-braga-cuello.jpg'),
    (13, 'Mochila con zapatillero',      'accesorio',  24.00, array['ÚNICA'],               null::text[], 'tienda-mochila.jpg')
)
insert into public.productos (nombre, categoria, precio, tallas_disponibles, tallas_agotadas, imagen_url, orden, activo)
select d.nombre, d.categoria, d.precio, d.tallas_disponibles, d.tallas_agotadas, d.imagen_url, d.orden, true
  from datos d
 where not exists (select 1 from public.productos p where p.nombre = d.nombre);


-- ------------------------------------------------------------
-- 3) RLS · PRODUCTOS: los ve todo el mundo
-- ------------------------------------------------------------
-- La tienda es una página pública de la web: quien entra sin
-- cuenta tiene que poder ver qué hay y cuánto vale. Solo se ve;
-- crear y editar productos sigue siendo de administración.

alter table public.productos enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'productos'
                    and policyname = 'lectura publica') then
    create policy "lectura publica" on public.productos
      for select using (true);
  end if;
end $$;


-- ------------------------------------------------------------
-- 4) RLS · PEDIDOS: cada uno los suyos
-- ------------------------------------------------------------
-- Un pedido es una compra con nombre y apellidos: quién pidió qué
-- talla y cuánto se le va a cobrar. Se abre lo mínimo:
--
--   VER    · solo los pedidos cuyo perfil_id es el mío.
--   CREAR  · solo a mi nombre, siempre en estado 'pendiente' y,
--            si se indica atleta, solo uno de los míos (mi propia
--            ficha o la de un hijo), que es lo que devuelve
--            mis_atletas().
--   CAMBIAR / BORRAR · nada. Mover un pedido a preparando, listo o
--            entregado es del club. Si alguien se equivoca, lo
--            cancela administración desde /admin/pedidos/.

alter table public.pedidos enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'pedidos'
                    and policyname = 'socio ve sus pedidos') then
    create policy "socio ve sus pedidos" on public.pedidos
      for select to authenticated
      using (perfil_id = public.mi_perfil_id());
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'pedidos'
                    and policyname = 'socio crea sus pedidos') then
    create policy "socio crea sus pedidos" on public.pedidos
      for insert to authenticated
      with check (
        perfil_id = public.mi_perfil_id()
        and estado = 'pendiente'
        and (atleta_id is null or atleta_id in (select public.mis_atletas()))
      );
  end if;
end $$;


-- ------------------------------------------------------------
-- 5) RLS · PEDIDO_ITEMS: las líneas siguen a su pedido
-- ------------------------------------------------------------
-- Una línea de pedido no tiene dueño propio: lo hereda del pedido
-- al que cuelga. Para no repetir la consulta en cada policy (y
-- para que no dependa de en qué orden evalúa Postgres las reglas
-- de la tabla `pedidos`), se usa una función SECURITY DEFINER, el
-- mismo patrón que ya usan es_admin() y mis_atletas().

create or replace function public.es_mi_pedido(p_pedido uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.pedidos x
     where x.id = p_pedido
       and x.perfil_id = public.mi_perfil_id()
  );
$$;

grant execute on function public.es_mi_pedido(uuid) to authenticated;

alter table public.pedido_items enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'pedido_items'
                    and policyname = 'socio ve sus lineas') then
    create policy "socio ve sus lineas" on public.pedido_items
      for select to authenticated
      using (public.es_mi_pedido(pedido_id));
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'pedido_items'
                    and policyname = 'socio crea sus lineas') then
    create policy "socio crea sus lineas" on public.pedido_items
      for insert to authenticated
      with check (public.es_mi_pedido(pedido_id));
  end if;
end $$;


-- ------------------------------------------------------------
-- 6) Índice para la pantalla del socio
-- ------------------------------------------------------------
-- /portal/tienda/ pide "mis pedidos, del más nuevo al más viejo".

create index if not exists idx_pedidos_perfil_fecha
  on public.pedidos (perfil_id, created_at desc);

create index if not exists idx_productos_orden
  on public.productos (orden) where activo;
