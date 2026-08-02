-- ============================================================
-- 053 · PAGAR CON TARJETA · la fontanería (sin pantallas todavía)
-- ------------------------------------------------------------
-- QUÉ RESUELVE
--   Hoy todo lo que no es la cuota (el bono de El Cubo, la licencia
--   federativa, la ropa) se paga por transferencia: la persona
--   transfiere, alguien del club mira el banco days después y
--   entonces le da los usos del bono. Con tarjeta eso se acaba:
--   se paga, Stripe avisa, y **los usos se añaden en el acto**.
--
-- QUÉ SE PAGA CON TARJETA Y QUÉ NO
--   SÍ  → bonos de El Cubo, licencias federativas, ropa del club.
--   NO  → las cuotas. Siguen domiciliadas en el banco, como hasta
--         ahora. Esta migración no toca `pagos` ni `recibos`.
--
-- ⚠️ NACE APAGADO
--   `pagos_config.activo = false`. Mientras esté apagado ninguna
--   pantalla enseña botones de pagar y la función que crea la
--   sesión de pago se niega a crearla. Cuando el club abra la
--   cuenta de Stripe, se enciende desde el panel y ya está.
--
-- ⚠️ AQUÍ NO HAY NI UNA CLAVE
--   Las claves de Stripe (la secreta y la del webhook) viven en las
--   variables de entorno de Supabase, NUNCA en esta tabla ni en el
--   repositorio, que es público. La tabla de configuración solo
--   guarda interruptores: encendido/apagado, prueba/real y textos.
--
-- LO IMPORTANTE DE TODO EL ARCHIVO · TRES CANDADOS
--   1) El importe lo calcula la BASE, nunca el navegador. La función
--      `pagos_iniciar()` lee el precio del catálogo (o del producto
--      de la tienda) y de ahí no se sale. Es el mismo fallo que ya
--      se corrigió en la tienda: si el precio lo manda el navegador,
--      cualquiera se compra un bono por un céntimo.
--   2) El estado de un pago NO se puede tocar desde el navegador.
--      `authenticated` solo tiene permiso de LECTURA sobre
--      `pagos_online`, y encima no existe ninguna policy de escritura.
--      Lo escribe el webhook, que va con la llave de servicio.
--   3) Los usos del bono NO se pueden dar dos veces. Stripe reintenta
--      sus avisos: es normal recibir el mismo dos o tres veces. Hay
--      tres cierres encadenados, explicados en el apartado 6.
--
-- Idempotente: se puede relanzar sin perder nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/053_pagos_tarjeta.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · CONFIGURACIÓN · una sola fila, solo interruptores
-- ------------------------------------------------------------
create table if not exists public.pagos_config (
  -- Una fila y solo una: el `check (id = 1)` lo impide de raíz.
  id                  smallint primary key default 1 check (id = 1),

  -- El interruptor general. FALSE hasta que el club tenga cuenta de
  -- Stripe: con esto apagado no se puede crear ni un solo cobro.
  activo              boolean not null default false,

  -- 'prueba' → tarjetas de mentira, no se mueve un euro.
  -- 'real'   → dinero de verdad.
  -- Es solo una etiqueta para saber en qué modo se está: lo que
  -- manda de verdad es qué clave de Stripe hay puesta en Supabase.
  modo                text not null default 'prueba' check (modo in ('prueba','real')),

  -- ¿La comisión de la tarjeta la paga el club o se le suma a quien
  -- paga? FALSE = la paga el club (llega un poco menos de lo cobrado).
  repercutir_comision boolean not null default false,

  -- Texto que verá la gente junto al botón de pagar («El cargo
  -- aparecerá como…», «si algo falla, escribe a…»). Lo edita el panel.
  texto_ayuda         text,

  updated_at          timestamptz not null default now()
);

comment on table public.pagos_config is
  'Interruptores del pago con tarjeta (una sola fila). NO guarda claves: las de Stripe van en las variables de entorno de Supabase.';
comment on column public.pagos_config.activo is
  'Interruptor general. Con false no se crea ningún cobro y ninguna pantalla enseña botones de pagar.';

-- Columnas por si la tabla ya existía de una pasada anterior.
alter table public.pagos_config add column if not exists activo              boolean not null default false;
alter table public.pagos_config add column if not exists modo                text not null default 'prueba';
alter table public.pagos_config add column if not exists repercutir_comision boolean not null default false;
alter table public.pagos_config add column if not exists texto_ayuda         text;
alter table public.pagos_config add column if not exists updated_at          timestamptz not null default now();

-- La fila única. `do nothing`: si ya está, no se pisa lo que el club haya puesto.
insert into public.pagos_config (id) values (1) on conflict (id) do nothing;

drop trigger if exists pagos_config_updated_at on public.pagos_config;
create trigger pagos_config_updated_at
  before update on public.pagos_config
  for each row execute function public.handle_updated_at();


-- ------------------------------------------------------------
-- 2 · CATÁLOGO · qué se puede pagar y cuánto vale (el precio REAL)
-- ------------------------------------------------------------
-- Esta tabla es la que evita el fallo clásico: el navegador solo dice
-- «quiero pagar la clave bono-cubo-10»; el importe sale de aquí.
--
-- Un artículo puede poner el precio de dos maneras:
--   · `importe_centimos` a pelo (bonos, licencias); o
--   · `producto_id` apuntando a la tienda, y entonces el precio es el
--     de `productos.precio`, así no hay dos precios de la misma prenda.
create table if not exists public.pagos_articulos (
  id                  uuid primary key default gen_random_uuid(),

  -- Nombre corto y estable con el que lo pide el navegador. Ej.: 'bono-cubo-10'.
  clave               text not null unique,

  tipo                text not null check (tipo in ('bono','licencia','ropa','otro')),

  -- Cómo se llama en la pantalla y en el recibo de Stripe.
  titulo              text not null,
  descripcion         text,

  -- En CÉNTIMOS enteros, que es como trabaja Stripe y como no hay
  -- líos de redondeo: 55,00 € = 5500.
  importe_centimos    integer check (importe_centimos > 0),

  -- Si apunta a un producto de la tienda, el precio sale de ahí.
  producto_id         uuid references public.productos(id) on delete set null,

  -- Solo para tipo 'bono': cuántos usos añade y cuántos días dura.
  bono_usos           integer check (bono_usos > 0),
  bono_caducidad_dias integer check (bono_caducidad_dias > 0),

  -- ¿Hace falta decir para qué atleta es? (un bono, sí; la ropa, no)
  exige_atleta        boolean not null default false,

  activo              boolean not null default true,
  orden               integer not null default 100,
  updated_at          timestamptz not null default now(),

  constraint pagos_articulos_tiene_precio
    check (importe_centimos is not null or producto_id is not null),
  constraint pagos_articulos_bono_con_usos
    check (tipo <> 'bono' or bono_usos is not null)
);

comment on table public.pagos_articulos is
  'Qué se puede pagar con tarjeta y cuánto vale. El importe del cobro SIEMPRE sale de aquí (o del producto enlazado), nunca del navegador.';

create index if not exists pagos_articulos_activo_orden_idx
  on public.pagos_articulos (activo, orden);

drop trigger if exists pagos_articulos_updated_at on public.pagos_articulos;
create trigger pagos_articulos_updated_at
  before update on public.pagos_articulos
  for each row execute function public.handle_updated_at();


-- ------------------------------------------------------------
-- 3 · LOS PAGOS · una fila por intento de pago
-- ------------------------------------------------------------
create table if not exists public.pagos_online (
  id                    uuid primary key default gen_random_uuid(),

  -- El código que se enseña a la persona y que viaja a Stripe:
  -- 'APO-260802-K3F9QP'. Único, para poder cruzarlo sin dudas.
  referencia            text not null unique,

  -- Para quién es (un bono es de un atleta concreto) y quién paga.
  atleta_id             uuid references public.atletas(id) on delete set null,
  perfil_id             uuid references public.perfiles(id) on delete set null,

  -- Qué se está pagando, en cristiano: «Bono de 10 usos · El Cubo».
  concepto              text not null,
  tipo                  text not null check (tipo in ('bono','licencia','ropa','otro')),

  -- En céntimos, como Stripe.
  importe_centimos      integer not null check (importe_centimos > 0),
  moneda                text not null default 'eur',

  -- iniciado   → se abrió la pasarela, aún no consta cobrado
  -- pagado     → Stripe confirmó el cobro
  -- fallido    → la tarjeta no pasó
  -- cancelado  → se dejó a medias o caducó la sesión
  -- reembolsado→ se devolvió el dinero
  estado                text not null default 'iniciado'
                        check (estado in ('iniciado','pagado','fallido','reembolsado','cancelado')),

  stripe_session_id     text,
  stripe_payment_intent text,

  -- Cajón para lo que haga falta guardar del pedido (usos del bono,
  -- talla de la prenda, clave del artículo…). Nunca datos de tarjeta:
  -- el número de la tarjeta NO pasa por aquí ni por la web del club.
  metadatos             jsonb not null default '{}'::jsonb,

  creado_en             timestamptz not null default now(),
  pagado_en             timestamptz,

  -- Cuándo se aplicó el efecto (dar los usos del bono). Es el sello
  -- que impide repetirlo. Ver apartado 6.
  aplicado_en           timestamptz
);

comment on table public.pagos_online is
  'Pagos con tarjeta (bonos de El Cubo, licencias, ropa). NO las cuotas: esas van domiciliadas. El estado solo lo cambia el webhook de Stripe, nunca el navegador.';
comment on column public.pagos_online.aplicado_en is
  'Cuándo se aplicó el efecto del pago (p. ej. dar los usos del bono). Sirve de sello anti-duplicados.';

-- Columnas por si la tabla venía de una pasada anterior.
alter table public.pagos_online add column if not exists stripe_session_id     text;
alter table public.pagos_online add column if not exists stripe_payment_intent text;
alter table public.pagos_online add column if not exists metadatos             jsonb not null default '{}'::jsonb;
alter table public.pagos_online add column if not exists pagado_en             timestamptz;
alter table public.pagos_online add column if not exists aplicado_en           timestamptz;

create index if not exists pagos_online_perfil_idx  on public.pagos_online (perfil_id, creado_en desc);
create index if not exists pagos_online_atleta_idx  on public.pagos_online (atleta_id, creado_en desc);
create index if not exists pagos_online_estado_idx  on public.pagos_online (estado, creado_en desc);
-- Una sesión de Stripe no puede corresponder a dos pagos distintos.
create unique index if not exists pagos_online_sesion_unica
  on public.pagos_online (stripe_session_id) where stripe_session_id is not null;


-- ------------------------------------------------------------
-- 4 · AVISOS DE STRIPE YA ATENDIDOS
-- ------------------------------------------------------------
-- Stripe reintenta sus avisos (webhooks) hasta que le contestas que
-- sí. Es normalísimo recibir el mismo dos o tres veces. Aquí se
-- apunta cada aviso por su identificador: el segundo intento se
-- reconoce al instante y no vuelve a hacer nada.
create table if not exists public.pagos_eventos_stripe (
  evento_id   text primary key,
  tipo        text,
  pago_id     uuid references public.pagos_online(id) on delete set null,
  resultado   text,
  recibido_en timestamptz not null default now()
);

comment on table public.pagos_eventos_stripe is
  'Avisos de Stripe ya atendidos. Primer candado contra dar dos veces los usos de un bono.';


-- ------------------------------------------------------------
-- 5 · EL ENGANCHE CON EL BONO DE EL CUBO
-- ------------------------------------------------------------
-- El bono de El Cubo ya existe (migración 020) y funciona por USOS:
-- `cubo_bonos` guarda el paquete comprado y un disparador le añade
-- solo su movimiento de alta (+N usos) en `cubo_movimientos`. Así que
-- aquí NO hay que inventar nada: basta con crear la fila de
-- `cubo_bonos` y los usos aparecen solos, al momento.
--
-- La columna nueva dice de qué pago con tarjeta salió ese bono, y el
-- índice único es el candado de verdad: **un pago no puede generar
-- dos bonos**, lo intente quien lo intente y las veces que sea.
alter table public.cubo_bonos
  add column if not exists pago_online_id uuid references public.pagos_online(id) on delete set null;

create unique index if not exists cubo_bonos_pago_online_unico
  on public.cubo_bonos (pago_online_id) where pago_online_id is not null;

comment on column public.cubo_bonos.pago_online_id is
  'De qué pago con tarjeta salió este bono. Con índice único: un pago = un bono, nunca dos.';


-- ------------------------------------------------------------
-- 6 · LAS FUNCIONES · aquí vive toda la lógica
-- ------------------------------------------------------------

-- 6.1 ¿Está encendido el pago con tarjeta?
--     Lo puede preguntar cualquiera (también quien no ha entrado):
--     es un sí/no, no enseña nada más. Sirve para que ninguna
--     pantalla pinte un botón de pagar que no lleve a ningún sitio.
create or replace function public.pagos_disponible()
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select coalesce((select c.activo from public.pagos_config c where c.id = 1), false);
$function$;

grant execute on function public.pagos_disponible() to anon, authenticated;


-- 6.2 El precio de un artículo, en céntimos. Del catálogo o, si
--     apunta a la tienda, del precio del producto.
create or replace function public.pagos_precio(p_clave text)
returns integer
language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(a.importe_centimos, round(p.precio * 100)::int)
    from public.pagos_articulos a
    left join public.productos p on p.id = a.producto_id
   where a.clave = p_clave and a.activo;
$function$;

grant execute on function public.pagos_precio(text) to authenticated;


-- 6.3 Qué comisión se suma si el club decide repercutirla.
--     Tarjeta europea: en torno al 1,5 % + 0,25 €. Para que al club
--     le entre limpio el precio de tarifa hay que cobrar
--     (neto + 25) / (1 - 0,015), redondeando hacia arriba.
create or replace function public.pagos_con_comision(p_centimos integer)
returns integer
language sql immutable
as $function$
  select ceil((p_centimos + 25)::numeric / 0.985)::int;
$function$;


-- 6.4 ABRIR UN PAGO.
--     La llama la función `pago-crear` con la llave de servicio. El
--     importe se calcula AQUÍ: quien la llama solo dice qué clave
--     quiere. Aunque alguien se colara en la función de Stripe, no
--     podría cambiar el precio.
create or replace function public.pagos_iniciar(
  p_clave     text,
  p_perfil    uuid,
  p_atleta    uuid default null,
  p_metadatos jsonb default '{}'::jsonb
)
returns public.pagos_online
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_cfg     public.pagos_config;
  v_art     public.pagos_articulos;
  v_importe integer;
  v_ref     text;
  v_meta    jsonb;
  v_pago    public.pagos_online;
begin
  select * into v_cfg from public.pagos_config where id = 1;
  if not found or not v_cfg.activo then
    raise exception 'El pago con tarjeta todavía no está activado.' using errcode = 'P0001';
  end if;

  select * into v_art from public.pagos_articulos where clave = p_clave and activo;
  if not found then
    raise exception 'Eso no se puede pagar con tarjeta.' using errcode = 'P0001';
  end if;

  -- EL PRECIO, DE LA BASE. Nunca de quien llama.
  v_importe := public.pagos_precio(p_clave);
  if v_importe is null or v_importe <= 0 then
    raise exception 'Ese artículo no tiene precio puesto.' using errcode = 'P0001';
  end if;
  if v_cfg.repercutir_comision then
    v_importe := public.pagos_con_comision(v_importe);
  end if;

  if v_art.exige_atleta and p_atleta is null then
    raise exception 'Hay que decir de qué atleta es.' using errcode = 'P0001';
  end if;

  -- Referencia legible y única: APO-AAMMDD-XXXXXX
  v_ref := 'APO-' || to_char(now(), 'YYMMDD') || '-' ||
           upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  -- Se guarda de dónde salió y, si es bono, cuántos usos hay que dar.
  -- Lo guardamos NOSOTROS, no el navegador: al confirmar el pago se
  -- leerá de aquí, así que tiene que ser de fiar.
  v_meta := coalesce(p_metadatos, '{}'::jsonb) || jsonb_build_object(
    'clave',    v_art.clave,
    'articulo', v_art.id,
    'usos',     v_art.bono_usos,
    'caducidad_dias', v_art.bono_caducidad_dias,
    'comision_repercutida', v_cfg.repercutir_comision
  );

  insert into public.pagos_online
    (referencia, atleta_id, perfil_id, concepto, tipo, importe_centimos, metadatos)
  values
    (v_ref, p_atleta, p_perfil, v_art.titulo, v_art.tipo, v_importe, v_meta)
  returning * into v_pago;

  return v_pago;
end;
$function$;


-- 6.5 APLICAR EL EFECTO DEL PAGO.
--     Hoy solo los bonos tienen efecto automático: se crea el bono de
--     El Cubo y el disparador de la migración 020 le mete los usos.
--     Licencia y ropa se quedan «pagado» y los ve el club en el panel.
--
--     ANTI-DUPLICADOS (el punto crítico del encargo), en tres capas:
--       a) `pagos_eventos_stripe` · el mismo aviso de Stripe no entra dos veces.
--       b) `aplicado_en` · si ya está sellado, se sale sin hacer nada,
--          y la fila se lee con FOR UPDATE, así que dos avisos a la vez
--          hacen cola en vez de pisarse.
--       c) índice único en `cubo_bonos.pago_online_id` · aunque
--          fallaran las dos anteriores, la base RECHAZA el segundo
--          bono. Es un candado físico, no una comprobación.
create or replace function public.pagos_aplicar_efecto(p_pago uuid)
returns text
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_pago   public.pagos_online;
  v_usos   integer;
  v_dias   integer;
  v_bono   uuid;
begin
  select * into v_pago from public.pagos_online where id = p_pago for update;
  if not found then return 'no-existe'; end if;
  if v_pago.estado <> 'pagado' then return 'no-pagado'; end if;
  if v_pago.aplicado_en is not null then return 'ya-aplicado'; end if;

  if v_pago.tipo = 'bono' then
    v_usos := nullif(v_pago.metadatos ->> 'usos', '')::int;
    v_dias := nullif(v_pago.metadatos ->> 'caducidad_dias', '')::int;

    if v_pago.atleta_id is null or v_usos is null or v_usos <= 0 then
      -- No se puede dar el bono, pero el dinero SÍ ha entrado: se deja
      -- constancia y lo resuelve el club a mano desde el panel.
      update public.pagos_online
         set metadatos = metadatos || jsonb_build_object('aviso', 'Pago cobrado sin datos para dar el bono; revisar a mano.')
       where id = p_pago;
      return 'sin-datos';
    end if;

    insert into public.cubo_bonos (atleta_id, usos_totales, precio, fecha_compra, caducidad, activo, notas, pago_online_id)
    values (v_pago.atleta_id,
            v_usos,
            round(v_pago.importe_centimos::numeric / 100, 2),
            current_date,
            case when v_dias is not null then current_date + v_dias else null end,
            true,
            'Pagado con tarjeta · ' || v_pago.referencia,
            v_pago.id)
    on conflict (pago_online_id) where pago_online_id is not null do nothing
    returning id into v_bono;

    if v_bono is null then
      -- El candado (c) ha saltado: ese pago ya tenía su bono.
      update public.pagos_online set aplicado_en = coalesce(aplicado_en, now()) where id = p_pago;
      return 'ya-aplicado';
    end if;
  end if;

  update public.pagos_online set aplicado_en = now() where id = p_pago;
  return 'aplicado';
end;
$function$;


-- 6.6 CONFIRMAR UN PAGO · lo único que llama el webhook.
--     Devuelve un resumen en jsonb para poder registrarlo en el log.
create or replace function public.pagos_confirmar(
  p_referencia text,
  p_session    text default null,
  p_intent     text default null,
  p_evento     text default null
)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_pago    public.pagos_online;
  v_efecto  text;
  v_filas   integer;
begin
  -- CAPA (a): ¿ya se atendió este aviso de Stripe?
  if p_evento is not null then
    insert into public.pagos_eventos_stripe (evento_id, tipo)
    values (p_evento, 'confirmar')
    on conflict (evento_id) do nothing;
    get diagnostics v_filas = row_count;
    if v_filas = 0 then
      return jsonb_build_object('ok', true, 'repetido', true, 'motivo', 'aviso ya atendido');
    end if;
  end if;

  select * into v_pago from public.pagos_online where referencia = p_referencia for update;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'no existe ese pago');
  end if;

  -- CAPA (b): si ya estaba cobrado y aplicado, no se repite nada.
  if v_pago.estado = 'pagado' and v_pago.aplicado_en is not null then
    if p_evento is not null then
      update public.pagos_eventos_stripe
         set pago_id = v_pago.id, resultado = 'ya-aplicado' where evento_id = p_evento;
    end if;
    return jsonb_build_object('ok', true, 'repetido', true, 'referencia', v_pago.referencia);
  end if;

  update public.pagos_online
     set estado                = 'pagado',
         pagado_en             = coalesce(pagado_en, now()),
         stripe_session_id     = coalesce(p_session, stripe_session_id),
         stripe_payment_intent = coalesce(p_intent, stripe_payment_intent)
   where id = v_pago.id;

  v_efecto := public.pagos_aplicar_efecto(v_pago.id);

  if p_evento is not null then
    update public.pagos_eventos_stripe
       set pago_id = v_pago.id, resultado = v_efecto where evento_id = p_evento;
  end if;

  return jsonb_build_object('ok', true, 'repetido', false,
                            'referencia', v_pago.referencia,
                            'tipo', v_pago.tipo,
                            'efecto', v_efecto);
end;
$function$;


-- 6.7 MARCAR UN PAGO QUE NO SALIÓ (fallido, cancelado, reembolsado).
--     No toca los que ya están cobrados, salvo para reembolsarlos.
create or replace function public.pagos_marcar(
  p_referencia text,
  p_estado     text,
  p_evento     text default null
)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_pago  public.pagos_online;
  v_filas integer;
begin
  if p_estado not in ('fallido','cancelado','reembolsado') then
    raise exception 'Ese estado no se puede poner desde aquí.' using errcode = 'P0001';
  end if;

  if p_evento is not null then
    insert into public.pagos_eventos_stripe (evento_id, tipo)
    values (p_evento, 'marcar:' || p_estado)
    on conflict (evento_id) do nothing;
    get diagnostics v_filas = row_count;
    if v_filas = 0 then
      return jsonb_build_object('ok', true, 'repetido', true);
    end if;
  end if;

  select * into v_pago from public.pagos_online where referencia = p_referencia for update;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'no existe ese pago');
  end if;

  -- Un pago ya cobrado solo puede pasar a 'reembolsado'.
  if v_pago.estado = 'pagado' and p_estado <> 'reembolsado' then
    return jsonb_build_object('ok', true, 'sin_cambios', true, 'estado', v_pago.estado);
  end if;

  update public.pagos_online set estado = p_estado where id = v_pago.id;

  if p_evento is not null then
    update public.pagos_eventos_stripe
       set pago_id = v_pago.id, resultado = p_estado where evento_id = p_evento;
  end if;

  return jsonb_build_object('ok', true, 'estado', p_estado, 'referencia', v_pago.referencia);
end;
$function$;


-- Las tres de arriba mueven dinero y usos: SOLO las puede llamar la
-- llave de servicio (las funciones del servidor). Ni el navegador de
-- un socio ni el de un administrador llegan a ellas.
revoke all on function public.pagos_iniciar(text, uuid, uuid, jsonb)   from public, anon, authenticated;
revoke all on function public.pagos_aplicar_efecto(uuid)               from public, anon, authenticated;
revoke all on function public.pagos_confirmar(text, text, text, text)  from public, anon, authenticated;
revoke all on function public.pagos_marcar(text, text, text)           from public, anon, authenticated;
grant execute on function public.pagos_iniciar(text, uuid, uuid, jsonb)  to service_role;
grant execute on function public.pagos_aplicar_efecto(uuid)              to service_role;
grant execute on function public.pagos_confirmar(text, text, text, text) to service_role;
grant execute on function public.pagos_marcar(text, text, text)          to service_role;


-- ------------------------------------------------------------
-- 7 · EL CATÁLOGO QUE VE LA WEB
-- ------------------------------------------------------------
-- Lista limpia de lo que se puede pagar, con el precio ya resuelto.
-- Sin `security_invoker` a propósito: así una pantalla puede enseñar
-- «Bono de 10 usos · 55,00 €» sin necesitar permisos sobre la tienda.
drop view if exists public.pagos_catalogo cascade;
create view public.pagos_catalogo as
  select a.clave,
         a.tipo,
         a.titulo,
         a.descripcion,
         coalesce(a.importe_centimos, round(p.precio * 100)::int) as importe_centimos,
         a.bono_usos,
         a.bono_caducidad_dias,
         a.exige_atleta,
         a.orden
    from public.pagos_articulos a
    left join public.productos p on p.id = a.producto_id
   where a.activo
     and coalesce(a.importe_centimos, round(p.precio * 100)::int) > 0;

-- Igual que con las tablas: primero quitar lo que Supabase reparte
-- solo, y después conceder únicamente la lectura.
revoke all on public.pagos_catalogo from anon;
revoke all on public.pagos_catalogo from authenticated;
revoke all on public.pagos_catalogo from public;
grant select on public.pagos_catalogo to authenticated;


-- ------------------------------------------------------------
-- 8 · CANDADOS (RLS)
-- ------------------------------------------------------------

-- 8.1 PAGOS · cada uno ve LOS SUYOS. Nadie escribe desde el navegador.
alter table public.pagos_online enable row level security;

drop policy if exists "ver mis pagos con tarjeta" on public.pagos_online;
create policy "ver mis pagos con tarjeta"
  on public.pagos_online
  for select
  to authenticated
  using (
    perfil_id = public.mi_perfil_id()
    or atleta_id in (select public.mis_atletas())
    or public.es_admin()
  );

-- Fíjate en lo que NO hay: ni una policy de insert, update o delete.
-- Y abajo, ni un grant de escritura. Doble candado: aunque alguien
-- creara una policy por error, sin el GRANT no podría escribir.
--
-- ⚠️ OJO CON ESTO: Supabase reparte por su cuenta permiso TOTAL a
-- `anon` y a `authenticated` sobre cualquier tabla nueva del esquema
-- public. Así que no basta con «no conceder»: hay que QUITAR primero
-- y conceder después solo lo justo. Sin este revoke, `authenticated`
-- se quedaría con INSERT, UPDATE y DELETE sobre los pagos.
revoke all on public.pagos_online from anon;
revoke all on public.pagos_online from authenticated;
revoke all on public.pagos_online from public;
grant select on public.pagos_online to authenticated;


-- 8.2 CONFIGURACIÓN · la lee cualquiera con sesión, la cambia el admin.
alter table public.pagos_config enable row level security;

drop policy if exists "lectura pagos_config con sesion" on public.pagos_config;
create policy "lectura pagos_config con sesion"
  on public.pagos_config for select to authenticated using (true);

drop policy if exists "admin cambia pagos_config" on public.pagos_config;
create policy "admin cambia pagos_config"
  on public.pagos_config for update to authenticated
  using (public.es_admin()) with check (public.es_admin());

revoke all on public.pagos_config from anon;
revoke all on public.pagos_config from authenticated;
revoke all on public.pagos_config from public;
-- Ni insert ni delete: la fila es una y no se toca.
grant select, update on public.pagos_config to authenticated;


-- 8.3 CATÁLOGO · lo lee quien tiene sesión, lo gestiona el admin.
alter table public.pagos_articulos enable row level security;

drop policy if exists "lectura catalogo de pagos" on public.pagos_articulos;
create policy "lectura catalogo de pagos"
  on public.pagos_articulos for select to authenticated using (true);

drop policy if exists "admin gestiona catalogo de pagos" on public.pagos_articulos;
create policy "admin gestiona catalogo de pagos"
  on public.pagos_articulos for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

revoke all on public.pagos_articulos from anon;
revoke all on public.pagos_articulos from authenticated;
revoke all on public.pagos_articulos from public;
-- Aquí sí hace falta escritura: el admin da de alta licencias y ropa
-- desde el panel. Quién puede de verdad lo decide la policy de arriba.
grant select, insert, update, delete on public.pagos_articulos to authenticated;


-- 8.4 AVISOS DE STRIPE · solo administración, y solo de lectura.
alter table public.pagos_eventos_stripe enable row level security;

drop policy if exists "admin ve los avisos de stripe" on public.pagos_eventos_stripe;
create policy "admin ve los avisos de stripe"
  on public.pagos_eventos_stripe for select to authenticated using (public.es_admin());

revoke all on public.pagos_eventos_stripe from anon;
revoke all on public.pagos_eventos_stripe from authenticated;
revoke all on public.pagos_eventos_stripe from public;
grant select on public.pagos_eventos_stripe to authenticated;


-- ------------------------------------------------------------
-- 9 · CATÁLOGO DE ARRANQUE · los dos bonos de El Cubo
-- ------------------------------------------------------------
-- Los precios NO son secretos (están en la web y en las tarifas), así
-- que aquí sí pueden ir. Son los mismos que ya se le cobran hoy a la
-- gente por el bono de El Cubo: 10 usos = 55 €, 20 usos = 95 €.
-- Solo se insertan si faltan: si el club los cambia desde el panel,
-- relanzar esta migración NO se los pisa.
--
-- Licencias y ropa se dan de alta desde el panel cuando el club diga
-- los precios (la ropa puede apuntar a su producto de la tienda y
-- así el precio no se escribe dos veces).
insert into public.pagos_articulos
  (clave, tipo, titulo, descripcion, importe_centimos, bono_usos, bono_caducidad_dias, exige_atleta, orden)
select * from (values
  ('bono-cubo-10', 'bono', 'Bono de 10 usos · El Cubo',
   'Diez clases dirigidas de El Cubo. Los usos se añaden en el momento de pagar.', 5500, 10, 365, true, 10),
  ('bono-cubo-20', 'bono', 'Bono de 20 usos · El Cubo',
   'Veinte clases dirigidas de El Cubo. Los usos se añaden en el momento de pagar.', 9500, 20, 365, true, 20)
) as d(clave, tipo, titulo, descripcion, importe_centimos, bono_usos, bono_caducidad_dias, exige_atleta, orden)
where not exists (select 1 from public.pagos_articulos a where a.clave = d.clave);

commit;


-- ============================================================
-- 10 · COMPROBACIÓN RÁPIDA
-- ============================================================
select 'config' as que, activo::text as valor_1, modo as valor_2,
       repercutir_comision::text as valor_3
  from public.pagos_config
union all
select 'catalogo', clave, titulo, (importe_centimos::numeric/100)::text
  from public.pagos_catalogo
order by 1, 2;

-- Quién puede tocar los pagos (aquí NO debe salir «anon», y
-- «authenticated» solo puede tener SELECT).
select table_name, grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema = 'public'
   and table_name in ('pagos_online','pagos_config','pagos_articulos','pagos_eventos_stripe')
 order by table_name, grantee, privilege_type;
