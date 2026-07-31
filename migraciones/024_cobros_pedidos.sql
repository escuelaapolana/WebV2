-- ============================================================
-- 024 · COBROS (recibos) y PEDIDOS de ropa
-- ------------------------------------------------------------
-- Tapa dos huecos del panel:
--
--   A) El Inicio del panel avisa de impagos, pero no había ninguna
--      pantalla donde ver un recibo ni marcarlo como cobrado.
--      -> /admin/cobros/
--
--   B) El contador "ropa pendiente" se calcula de pedidos/pedido_items,
--      pero no había forma de crear ni de mover un pedido, así que
--      siempre salía 0.
--      -> /admin/pedidos/
--
-- NO se crea ninguna tabla nueva: public.pagos, public.pedidos y
-- public.pedido_items ya existen y se respetan tal cual están
-- (incluidos sus CHECK de estado). Aquí solo se añaden las columnas
-- que faltaban para poder trabajar de verdad, unos índices y las
-- policies de administración, todo de forma idempotente.
--
-- LO QUE ESTA MIGRACIÓN NO HACE (a propósito):
--   · No toca la remesa SEPA. La maqueta 11c ("Pasar las cuotas del
--     mes") pide mandatos firmados, IBAN por cuenta y generación del
--     fichero de remesa. Eso mueve dinero de verdad y se hará más
--     adelante, con el dueño del club delante. Por eso aquí NO hay
--     columna de mandato ni de IBAN.
--   · No añade ninguna policy nueva para atletas ni para familias.
--     Los recibos y los pedidos son dinero y datos personales: se
--     quedan como están, solo administración escribe.
-- ============================================================


-- ------------------------------------------------------------
-- 1) PAGOS · columnas que faltaban para gestionar un recibo
-- ------------------------------------------------------------
-- La tabla ya traía: concepto, importe, estado (pagado / pendiente /
-- impagado), fecha_vencimiento, fecha_pago y notas. Faltaban tres
-- datos que se piden en cuanto te sientas a cobrar:
--
--   metodo  · cómo se cobró (la maqueta habla de domiciliación, y en
--             el club también se cobra a mano por transferencia o en
--             efectivo). Sin esto no se sabe qué recibo hay que meter
--             en la remesa y cuál ya se cobró por otra vía.
--   periodo · a qué mes pertenece el recibo, en formato AAAA-MM.
--             Es lo que permite filtrar "las cuotas de agosto"
--             (maqueta 11c) sin depender de la fecha de vencimiento,
--             que se puede aplazar.
--   cuenta  · escuela o club. La maqueta 11c lo pinta como columna
--             CUENTA en la tabla de recibos y separa las dos remesas
--             por ahí. Se deja preparado ya para no tener que tocar
--             datos viejos cuando se haga la remesa.

alter table public.pagos add column if not exists metodo  text;
alter table public.pagos add column if not exists periodo text;
alter table public.pagos add column if not exists cuenta  text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'pagos_metodo_check') then
    alter table public.pagos add constraint pagos_metodo_check
      check (metodo is null or metodo in ('domiciliado','transferencia','efectivo','tarjeta','otro'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'pagos_cuenta_check') then
    alter table public.pagos add constraint pagos_cuenta_check
      check (cuenta is null or cuenta in ('escuela','club'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'pagos_periodo_formato_check') then
    alter table public.pagos add constraint pagos_periodo_formato_check
      check (periodo is null or periodo ~ '^[0-9]{4}-(0[1-9]|1[0-2])$');
  end if;
end $$;

-- Los recibos que ya existían se quedan con su periodo puesto a partir
-- del mes en que vencen, para que aparezcan en los filtros desde el
-- primer día y no haya un cajón de "sin periodo".
update public.pagos
   set periodo = to_char(fecha_vencimiento, 'YYYY-MM')
 where periodo is null
   and fecha_vencimiento is not null;

create index if not exists idx_pagos_estado    on public.pagos (estado);
create index if not exists idx_pagos_atleta    on public.pagos (atleta_id);
create index if not exists idx_pagos_periodo   on public.pagos (periodo);
create index if not exists idx_pagos_vencimiento on public.pagos (fecha_vencimiento);


-- ------------------------------------------------------------
-- 2) PEDIDOS · cuándo se entregó
-- ------------------------------------------------------------
-- El CHECK de estado ya existía y NO se toca:
--   pendiente · preparando · listo · entregado · cancelado
-- Solo falta poder anotar el día en que la prenda se entregó de
-- verdad, que es lo que pregunta el club cuando reparte equipaciones.

alter table public.pedidos add column if not exists fecha_entrega date;

create index if not exists idx_pedidos_estado     on public.pedidos (estado);
create index if not exists idx_pedidos_atleta     on public.pedidos (atleta_id);
create index if not exists idx_pedidos_perfil     on public.pedidos (perfil_id);
create index if not exists idx_pedido_items_pedido on public.pedido_items (pedido_id);


-- ------------------------------------------------------------
-- 3) RLS · administración lee y escribe; nadie más toca esto
-- ------------------------------------------------------------
-- Las tres tablas ya tienen RLS activo y una policy "admin gestiona
-- todo" con es_admin(). Se comprueba y, si en alguna base de datos
-- faltara, se crea. Es idempotente: si ya está, no hace nada.

alter table public.pagos        enable row level security;
alter table public.pedidos      enable row level security;
alter table public.pedido_items enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'pagos'
                    and policyname = 'admin gestiona todo') then
    create policy "admin gestiona todo" on public.pagos
      for all to authenticated using (es_admin()) with check (es_admin());
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'pedidos'
                    and policyname = 'admin gestiona todo') then
    create policy "admin gestiona todo" on public.pedidos
      for all to authenticated using (es_admin()) with check (es_admin());
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'pedido_items'
                    and policyname = 'admin gestiona todo') then
    create policy "admin gestiona todo" on public.pedido_items
      for all to authenticated using (es_admin()) with check (es_admin());
  end if;
end $$;

-- Recordatorio de por qué NO se añade nada para el atleta:
--   · public.pagos ya tiene "ver datos de mis atletas", que solo deja
--     ver los recibos cuyo atleta_id sale de mis_atletas(). Un atleta
--     ve los suyos y ninguno más.
--   · public.pedidos y public.pedido_items NO tienen ninguna policy de
--     lectura para atletas: hoy un atleta no ve ningún pedido, ni el
--     suyo. Se deja así a propósito hasta que exista la pantalla del
--     portal que lo necesite; abrirlo "por si acaso" sería abrir datos
--     de compras de todo el club.
