-- 444 · Natación equipación: textos del correo que escribe Mario
-- ---------------------------------------------------------------------------
-- Mario (26-oct-2026): «Prefiero que me prepare en el panel la opción de
-- enviar formulario a Máster por un lado, a Escuela por otro, e individual para
-- los nuevos que puedan incorporarse. ¿Es posible personalizar el texto que les
-- llegará, y que pueda revisarlo / modificarlo antes del envío?»
--
-- Tres textos (asunto + cuerpo), uno por envío:
--   · escuela → envío a las familias de la Escuela (las mixtas van aquí)
--   · master  → envío a los nadadores Máster
--   · nuevo   → envío a UNA familia (los que se incorporan más tarde)
-- En el cuerpo: {nombre} (nombre de pila de quien recibe), {nadadores} (los
-- nadadores de esa familia) y {enlace} (su enlace; si falta, se pone al final).
-- La Edge natacion-equipacion-correo los lee de aquí (o del envío mismo).
-- ---------------------------------------------------------------------------
begin;

create table if not exists public.natacion_equip_textos (
  clave      text primary key check (clave in ('escuela', 'master', 'nuevo')),
  asunto     text not null check (length(btrim(asunto)) between 1 and 200),
  cuerpo     text not null check (length(btrim(cuerpo)) between 1 and 6000),
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table public.natacion_equip_textos is '444 · Textos del correo de equipación de natación (Escuela, Máster, nuevos) que edita Mario.';

alter table public.natacion_equip_textos enable row level security;
drop policy if exists "equip textos gestor" on public.natacion_equip_textos;
create policy "equip textos gestor" on public.natacion_equip_textos
  for all to authenticated
  using ((select public.natacion_cuotas_puede()))
  with check ((select public.natacion_cuotas_puede()));
revoke all on public.natacion_equip_textos from anon;
grant select, insert, update on public.natacion_equip_textos to authenticated;

insert into public.natacion_equip_textos (clave, asunto, cuerpo) values
('escuela', 'Equipación de la Escuela de Natación: elige las tallas',
'Hola, {nombre}:

Estamos preparando los pedidos de equipación de la Escuela de Natación de esta temporada. En este enlace puedes elegir las tallas de {nadadores} y, si queréis, encargar bañadores del club u otras prendas:
{enlace}

Rellénalo antes del 2 de noviembre, que es cuando hacemos el pedido. La camiseta oficial y el gorro son gratis para todos, y la chaqueta es gratis para quien se incorpora este año. Si queréis más de una camiseta, cada una de más cuesta 15 €.

No se paga nada ahora: lo que haya que pagar se paga cuando llegue la ropa, antes de recogerla.

Si tienes cualquier duda, contesta a este correo.'),
('master', 'Equipación de natación Máster: elige tus tallas',
'Hola, {nombre}:

Estamos preparando los pedidos de equipación de natación Máster de esta temporada. En este enlace puedes elegir tus tallas y, si quieres, encargar bañadores del club u otras prendas:
{enlace}

Rellénalo antes del 2 de noviembre, que es cuando hacemos el pedido. La camiseta oficial y el gorro son gratis, y la chaqueta es gratis si te incorporas este año. Si quieres más de una camiseta, cada una de más cuesta 15 €.

No se paga nada ahora: lo que haya que pagar se paga cuando llegue la ropa, antes de recogerla.

Si tienes cualquier duda, contesta a este correo.'),
('nuevo', 'Bienvenida a la natación de Apolana: tu equipación',
'Hola, {nombre}:

¡Bienvenidos a la natación de Apolana! En este enlace puedes elegir las tallas de la equipación de {nadadores} y, si queréis, encargar bañadores del club u otras prendas:
{enlace}

Como es vuestro primer año, la camiseta oficial, el gorro y la chaqueta son gratis. Si queréis más de una camiseta, cada una de más cuesta 15 €.

No se paga nada ahora: lo que haya que pagar se paga cuando llegue la ropa, antes de recogerla.

Si tienes cualquier duda, contesta a este correo.')
on conflict (clave) do nothing;

commit;
