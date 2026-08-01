-- ============================================================
-- 030 · RECIBOS DE VERDAD: número correlativo, anulación y rectificativo
-- ------------------------------------------------------------
-- De dónde venimos:
--   public.pagos guardaba el importe, el estado y poco más. No había
--   número de recibo, así que el portal de familias solo podía enseñar
--   un "justificante informativo" sin identificar, y en el panel se
--   podía borrar un cobro ya hecho sin dejar rastro.
--
-- Lo que hace esta migración:
--   1) Añade a public.pagos el número de recibo y los campos de
--      anulación / rectificación.
--   2) NUMERA EN LA BASE DE DATOS, no en el navegador: formato
--      AAAA/NNNN (2026/0001, 2026/0002…), reiniciando cada año
--      natural, con un cerrojo que impide que dos cobros a la vez se
--      lleven el mismo número.
--   3) Blinda el documento: un recibo con número NO se borra y NO se
--      renumera. Si hay que corregirlo se ANULA (con motivo y fecha)
--      y, si procede, se emite un RECTIFICATIVO que apunta al
--      original. Esto lo imponen disparadores, así que se cumple
--      aunque alguien entre por otro camino (SQL a pelo, la API…).
--   4) Deja una función de lectura, public.recibo(id), para que la
--      página imprimible /recibo/ pinte el documento tanto si lo mira
--      el club como si lo mira la familia, sin poder ver recibos
--      ajenos.
--
-- LO QUE NO HACE (a propósito):
--   · No convierte esto en facturación fiscal. Un recibo del club es
--     un justificante de cobro de una cuota, no una factura con IVA.
--     Por eso no hay serie fiscal, ni base imponible, ni impuestos.
--   · No toca la remesa SEPA (sigue pendiente, como decía la 024).
--   · No abre ningún permiso nuevo a las familias: siguen pudiendo
--     LEER sus recibos y nada más.
-- ============================================================


-- ------------------------------------------------------------
-- 1) COLUMNAS NUEVAS EN public.pagos
-- ------------------------------------------------------------
alter table public.pagos add column if not exists numero_recibo  text;
alter table public.pagos add column if not exists anulado        boolean not null default false;
alter table public.pagos add column if not exists anulado_motivo text;
alter table public.pagos add column if not exists anulado_en     timestamptz;
alter table public.pagos add column if not exists rectifica_a    uuid references public.pagos(id);

comment on column public.pagos.numero_recibo  is 'Número del recibo, AAAA/NNNN. Lo pone sola la base de datos al marcar el cobro. Nunca se cambia ni se reutiliza.';
comment on column public.pagos.anulado        is 'Un recibo emitido no se borra: se anula. Solo lo pone la función anular_recibo().';
comment on column public.pagos.anulado_motivo is 'Por qué se anuló. Es obligatorio para poder anular.';
comment on column public.pagos.anulado_en     is 'Cuándo se anuló.';
comment on column public.pagos.rectifica_a    is 'Si este recibo corrige a otro anulado, aquí va el id del original.';

-- El número es único en toda la tabla (los nulos no estorban: un recibo
-- que todavía no se ha cobrado no tiene número).
create unique index if not exists pagos_numero_recibo_unico
  on public.pagos (numero_recibo);

-- Un original solo puede tener UN rectificativo.
create unique index if not exists pagos_rectifica_a_unico
  on public.pagos (rectifica_a) where rectifica_a is not null;

create index if not exists idx_pagos_anulado on public.pagos (anulado);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'pagos_numero_recibo_formato_check') then
    alter table public.pagos add constraint pagos_numero_recibo_formato_check
      check (numero_recibo is null or numero_recibo ~ '^[0-9]{4}/[0-9]{4,}$');
  end if;

  -- No se puede anular sin decir por qué ni sin dejar la fecha.
  if not exists (select 1 from pg_constraint where conname = 'pagos_anulado_coherente_check') then
    alter table public.pagos add constraint pagos_anulado_coherente_check
      check (
        (anulado = false and anulado_motivo is null and anulado_en is null)
        or
        (anulado = true and coalesce(btrim(anulado_motivo), '') <> '' and anulado_en is not null)
      );
  end if;

  -- Un recibo no puede rectificarse a sí mismo.
  if not exists (select 1 from pg_constraint where conname = 'pagos_rectifica_a_no_mismo_check') then
    alter table public.pagos add constraint pagos_rectifica_a_no_mismo_check
      check (rectifica_a is null or rectifica_a <> id);
  end if;
end $$;


-- ------------------------------------------------------------
-- 2) EL CONTADOR · una fila por año natural
-- ------------------------------------------------------------
-- Se usa una tabla y no una secuencia de Postgres a propósito:
-- una secuencia se salta números cuando una transacción se deshace
-- (nextval no vuelve atrás) y habría huecos en la numeración, que es
-- justo lo que no puede tener un talonario. Con una tabla, el número
-- se coge dentro de la misma transacción que el cobro: si el cobro no
-- se llega a guardar, el número tampoco se gasta.
create table if not exists public.recibo_contador (
  anio            integer primary key,
  ultimo          integer not null default 0,
  actualizado_en  timestamptz not null default now()
);

comment on table public.recibo_contador is 'Último número de recibo usado en cada año. Solo lo toca siguiente_numero_recibo(); nadie más tiene permiso.';

-- Nadie entra aquí desde la web: RLS activo y CERO policies, más los
-- permisos quitados a mano. Solo las funciones "security definer"
-- (que corren como dueño de la tabla) pueden moverlo.
alter table public.recibo_contador enable row level security;
revoke all on table public.recibo_contador from anon, authenticated;


-- ------------------------------------------------------------
-- 3) COGER EL SIGUIENTE NÚMERO · aquí está el cerrojo
-- ------------------------------------------------------------
-- Dos cobros marcados en el mismo instante desde dos navegadores
-- distintos NO pueden llevarse el mismo número. Se blinda por partida
-- doble:
--
--   a) pg_advisory_xact_lock(año): el segundo se queda esperando en la
--      puerta hasta que el primero termina su transacción. Es el mismo
--      cerrojo que usan las plazas de El Cubo (migración 020).
--   b) el INSERT ... ON CONFLICT DO UPDATE sobre la fila del año, que
--      además bloquea esa fila hasta el commit.
--
-- Cualquiera de los dos bastaría; juntos no hay forma de colarse.
create or replace function public.siguiente_numero_recibo(p_anio integer default null)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_anio integer := coalesce(p_anio, extract(year from current_date)::integer);
  v_n    integer;
begin
  if v_anio < 2000 or v_anio > 2999 then
    raise exception 'Año fuera de rango para numerar un recibo: %', v_anio using errcode = 'P0001';
  end if;

  -- Cerrojo por año: se suelta solo al terminar la transacción.
  perform pg_advisory_xact_lock(hashtextextended('recibo:' || v_anio::text, 0));

  insert into public.recibo_contador (anio, ultimo, actualizado_en)
  values (v_anio, 1, now())
  on conflict (anio) do update
     set ultimo = recibo_contador.ultimo + 1,
         actualizado_en = now()
  returning ultimo into v_n;

  return v_anio::text || '/' || lpad(v_n::text, 4, '0');
end;
$function$;

-- Que nadie la llame desde fuera: gastaría números para nada.
revoke all on function public.siguiente_numero_recibo(integer) from public, anon, authenticated;


-- ------------------------------------------------------------
-- 4) DISPARADOR · numerar al cobrar
-- ------------------------------------------------------------
-- Regla: en cuanto un recibo queda en estado "pagado" se le pone
-- fecha de cobro (hoy, si no la traía) y número de recibo. El año del
-- número es el de la fecha de cobro, para que el talonario cuadre con
-- la contabilidad del ejercicio.
--
-- El número NO se puede dictar desde fuera: si alguien intenta crear
-- un recibo con un número puesto a mano, se rechaza.
create or replace function public.pagos_numera()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if TG_OP = 'INSERT' and NEW.numero_recibo is not null then
    raise exception 'El número de recibo lo pone la base de datos, no se escribe a mano.'
      using errcode = 'P0001';
  end if;

  if NEW.estado = 'pagado' then
    if NEW.fecha_pago is null then
      NEW.fecha_pago := current_date;
    end if;
    if NEW.numero_recibo is null then
      NEW.numero_recibo := public.siguiente_numero_recibo(
        extract(year from NEW.fecha_pago)::integer
      );
    end if;
  end if;

  return NEW;
end;
$function$;

drop trigger if exists trg_pagos_numera on public.pagos;
create trigger trg_pagos_numera
  before insert or update on public.pagos
  for each row execute function public.pagos_numera();


-- ------------------------------------------------------------
-- 5) DISPARADOR · un recibo emitido es un documento, no un borrador
-- ------------------------------------------------------------
-- En cuanto un recibo tiene número:
--   · no se puede borrar,
--   · no se puede renumerar ni quedarse sin número,
--   · no se pueden cambiar los datos que salen impresos (atleta,
--     concepto, importe, periodo, fecha de cobro, forma de cobro y
--     estado). Para corregir: anular y, si procede, rectificativo.
--   · sí se pueden retocar las notas internas, la cuenta y la fecha de
--     vencimiento, que no forman parte del documento.
--
-- Y la anulación solo entra por la puerta buena: la función
-- anular_recibo(). Un UPDATE directo poniendo anulado = true se
-- rechaza.
--
-- El disparador se llama trg_pagos_protege y va DESPUÉS de
-- trg_pagos_numera por orden alfabético, que es justo lo que hace
-- falta: primero se numera, luego se comprueba.
create or replace function public.pagos_protege()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_orig public.pagos;
begin
  -- ---------- BORRAR ----------
  if TG_OP = 'DELETE' then
    if OLD.numero_recibo is not null then
      raise exception 'El recibo % ya está emitido: no se borra. Anúlalo indicando el motivo y, si procede, emite un rectificativo.',
        OLD.numero_recibo using errcode = 'P0001';
    end if;
    return OLD;
  end if;

  -- ---------- CREAR ----------
  if TG_OP = 'INSERT' then
    if NEW.anulado then
      raise exception 'No se puede crear un recibo ya anulado.' using errcode = 'P0001';
    end if;
  else
  -- ---------- MODIFICAR ----------
    if OLD.numero_recibo is not null then

      if NEW.numero_recibo is distinct from OLD.numero_recibo then
        raise exception 'El recibo % no se puede renumerar ni quedarse sin número.',
          OLD.numero_recibo using errcode = 'P0001';
      end if;

      if NEW.estado is distinct from OLD.estado
         or NEW.atleta_id  is distinct from OLD.atleta_id
         or NEW.concepto   is distinct from OLD.concepto
         or NEW.importe    is distinct from OLD.importe
         or NEW.periodo    is distinct from OLD.periodo
         or NEW.fecha_pago is distinct from OLD.fecha_pago
         or NEW.metodo     is distinct from OLD.metodo
         or NEW.rectifica_a is distinct from OLD.rectifica_a then
        raise exception 'El recibo % ya está emitido: sus datos no se cambian. Anúlalo y emite un rectificativo.',
          OLD.numero_recibo using errcode = 'P0001';
      end if;

    end if;

    -- La anulación, solo por la puerta buena
    if NEW.anulado is distinct from OLD.anulado then
      if OLD.anulado then
        raise exception 'Un recibo anulado no se puede desanular.' using errcode = 'P0001';
      end if;
      if coalesce(current_setting('apolana.anulando', true), '') <> 'si' then
        raise exception 'Para anular un recibo hay que usar anular_recibo(id, motivo).'
          using errcode = 'P0001';
      end if;
      if NEW.numero_recibo is null then
        raise exception 'Solo se anula un recibo que ya esté emitido con número.' using errcode = 'P0001';
      end if;
    elsif OLD.anulado
      and (NEW.anulado_motivo is distinct from OLD.anulado_motivo
        or NEW.anulado_en     is distinct from OLD.anulado_en) then
      raise exception 'El motivo y la fecha de anulación no se retocan después.' using errcode = 'P0001';
    end if;
  end if;

  -- ---------- RECTIFICATIVO: a quién puede apuntar ----------
  if NEW.rectifica_a is not null
     and (TG_OP = 'INSERT' or NEW.rectifica_a is distinct from OLD.rectifica_a) then

    select * into v_orig from public.pagos where id = NEW.rectifica_a;
    if not found then
      raise exception 'El recibo que se quiere rectificar no existe.' using errcode = 'P0001';
    end if;
    if v_orig.numero_recibo is null then
      raise exception 'Solo se rectifica un recibo que llegó a emitirse con número.' using errcode = 'P0001';
    end if;
    if not v_orig.anulado then
      raise exception 'Antes de rectificar el recibo % hay que anularlo.',
        v_orig.numero_recibo using errcode = 'P0001';
    end if;
    if v_orig.rectifica_a is not null then
      raise exception 'No se encadenan rectificativos: el recibo % ya es un rectificativo.',
        v_orig.numero_recibo using errcode = 'P0001';
    end if;
  end if;

  return NEW;
end;
$function$;

drop trigger if exists trg_pagos_protege on public.pagos;
create trigger trg_pagos_protege
  before insert or update or delete on public.pagos
  for each row execute function public.pagos_protege();


-- ------------------------------------------------------------
-- 6) ANULAR UN RECIBO
-- ------------------------------------------------------------
-- Solo administración. Pide motivo. Deja la fecha. No borra nada:
-- el recibo sigue ahí, con su número, marcado como anulado.
create or replace function public.anular_recibo(p_pago_id uuid, p_motivo text)
returns public.pagos
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_pago public.pagos;
begin
  if not public.es_admin() then
    raise exception 'Solo administración puede anular un recibo.' using errcode = '42501';
  end if;
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception 'Hay que decir por qué se anula el recibo.' using errcode = 'P0001';
  end if;

  select * into v_pago from public.pagos where id = p_pago_id for update;
  if not found then
    raise exception 'Ese recibo no existe.' using errcode = 'P0001';
  end if;
  if v_pago.numero_recibo is null then
    raise exception 'Ese recibo todavía no se ha emitido (no tiene número). Si sobra, se borra sin más.'
      using errcode = 'P0001';
  end if;
  if v_pago.anulado then
    raise exception 'El recibo % ya estaba anulado.', v_pago.numero_recibo using errcode = 'P0001';
  end if;

  -- Permiso de un solo uso, válido solo dentro de esta transacción.
  perform set_config('apolana.anulando', 'si', true);

  update public.pagos
     set anulado        = true,
         anulado_motivo = btrim(p_motivo),
         anulado_en     = now()
   where id = p_pago_id
  returning * into v_pago;

  perform set_config('apolana.anulando', '', true);

  return v_pago;
end;
$function$;

grant execute on function public.anular_recibo(uuid, text) to authenticated;


-- ------------------------------------------------------------
-- 7) EMITIR UN RECTIFICATIVO
-- ------------------------------------------------------------
-- Se emite sobre un recibo ya anulado y copia sus datos, dejando
-- cambiar el importe y el concepto (que es lo que suele estar mal).
-- Nace ya cobrado, así que el disparador le pone número al vuelo.
--
-- Si lo que hay que devolver es dinero, el importe puede ir en
-- negativo: el recibo queda como abono y el documento lo enseña tal
-- cual.
create or replace function public.emitir_rectificativo(
  p_pago_id  uuid,
  p_importe  numeric default null,
  p_concepto text    default null,
  p_nota     text    default null
)
returns public.pagos
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_orig  public.pagos;
  v_nuevo public.pagos;
begin
  if not public.es_admin() then
    raise exception 'Solo administración puede emitir un rectificativo.' using errcode = '42501';
  end if;

  select * into v_orig from public.pagos where id = p_pago_id for update;
  if not found then
    raise exception 'Ese recibo no existe.' using errcode = 'P0001';
  end if;
  if v_orig.numero_recibo is null then
    raise exception 'Solo se rectifica un recibo que llegó a emitirse con número.' using errcode = 'P0001';
  end if;
  if not v_orig.anulado then
    raise exception 'Antes de rectificar el recibo % hay que anularlo.', v_orig.numero_recibo
      using errcode = 'P0001';
  end if;
  if exists (select 1 from public.pagos where rectifica_a = v_orig.id) then
    raise exception 'El recibo % ya tiene su rectificativo emitido.', v_orig.numero_recibo
      using errcode = 'P0001';
  end if;

  insert into public.pagos (
    atleta_id, concepto, importe, estado, fecha_vencimiento, fecha_pago,
    periodo, cuenta, metodo, notas, rectifica_a
  ) values (
    v_orig.atleta_id,
    coalesce(nullif(btrim(p_concepto), ''), v_orig.concepto),
    coalesce(p_importe, v_orig.importe),
    'pagado',
    v_orig.fecha_vencimiento,
    current_date,
    v_orig.periodo,
    v_orig.cuenta,
    v_orig.metodo,
    coalesce(nullif(btrim(p_nota), ''), 'Rectificativo del recibo ' || v_orig.numero_recibo),
    v_orig.id
  )
  returning * into v_nuevo;

  return v_nuevo;
end;
$function$;

grant execute on function public.emitir_rectificativo(uuid, numeric, text, text) to authenticated;


-- ------------------------------------------------------------
-- 8) LEER UN RECIBO PARA IMPRIMIRLO · public.recibo(id)
-- ------------------------------------------------------------
-- La usa /recibo/?id=... Vale igual para el club y para la familia:
-- la propia función comprueba quién pregunta.
--   · administración: cualquier recibo.
--   · atleta o familia: solo los de SUS atletas (mis_atletas()).
--   · cualquier otro caso: devuelve nulo y la página dice
--     "no disponible". Nunca se enseñan datos ajenos.
--
-- Devuelve solo lo que va impreso. Las notas internas del club
-- ("devuelto el 5, la familia paga por transferencia") NO salen.
create or replace function public.recibo(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v jsonb;
begin
  select jsonb_build_object(
    'id',              p.id,
    'numero_recibo',   p.numero_recibo,
    'emitido_en',      p.created_at,
    'fecha_pago',      p.fecha_pago,
    'fecha_vencimiento', p.fecha_vencimiento,
    'estado',          p.estado,
    'concepto',        p.concepto,
    'periodo',         p.periodo,
    'importe',         p.importe,
    'metodo',          p.metodo,
    'anulado',         p.anulado,
    'anulado_motivo',  p.anulado_motivo,
    'anulado_en',      p.anulado_en,
    'es_rectificativo',    (p.rectifica_a is not null),
    'rectifica_a_numero',  o.numero_recibo,
    'rectifica_a_fecha',   o.fecha_pago,
    'rectificado_por_id',     r.id,
    'rectificado_por_numero', r.numero_recibo,
    'atleta', case when a.id is null then null else jsonb_build_object(
        'nombre',    a.nombre,
        'apellidos', a.apellidos,
        'categoria', a.categoria,
        'licencia',  a.licencia
      ) end,
    'familia', case when f.id is null then null else jsonb_build_object(
        'nombre',    f.nombre,
        'apellidos', f.apellidos,
        'email',     f.email,
        'telefono',  f.telefono
      ) end
  )
  into v
  from public.pagos p
  left join public.atletas  a on a.id = p.atleta_id
  left join public.perfiles f on f.id = coalesce(a.perfil_padre_id, a.perfil_id)
  left join public.pagos    o on o.id = p.rectifica_a
  left join public.pagos    r on r.rectifica_a = p.id
  where p.id = p_id
    and (
      public.es_admin()
      or (p.atleta_id is not null and p.atleta_id in (select public.mis_atletas()))
    );

  return v;
end;
$function$;

grant execute on function public.recibo(uuid) to authenticated;


-- ------------------------------------------------------------
-- 9) PERMISOS (RLS) · lo que puede cada uno
-- ------------------------------------------------------------
-- No hace falta añadir NADA a public.pagos:
--
--   · "ver datos de mis atletas" (SELECT) ya deja a la familia leer
--     sus recibos, con las columnas nuevas incluidas.
--   · NO existe ninguna policy de INSERT / UPDATE / DELETE para
--     atletas o familias, así que no pueden tocar numero_recibo, ni
--     estado, ni anulado. Postgres les corta antes incluso de llegar
--     a los disparadores.
--   · Administración entra por "admin gestiona todo" (es_admin()) y
--     aun así se topa con los disparadores: tampoco ella puede borrar
--     un recibo emitido ni cambiarle el número.
--
-- Se deja escrito aquí para que quede constancia y por si algún día
-- alguien añade una policy de escritura: el blindaje de verdad está en
-- los disparadores, no en las policies.
alter table public.pagos enable row level security;


-- ============================================================
-- 10) CÓMO SE COMPRUEBA QUE ESTO FUNCIONA
-- ------------------------------------------------------------
-- (a) Que dos cobros a la vez NUNCA se llevan el mismo número.
--     Se lanzan varias conexiones de psql en paralelo, cada una
--     insertando un recibo ya cobrado, y luego se cuenta:
--
--       for i in $(seq 1 12); do
--         .secrets/psql.sh -c "insert into public.pagos
--            (concepto, importe, estado, periodo)
--            values ('PRUEBA CONCURRENCIA', 1.00, 'pagado', '2026-07');" &
--       done; wait
--
--       select count(*), count(distinct numero_recibo)
--         from public.pagos where concepto = 'PRUEBA CONCURRENCIA';
--       -- las dos cifras tienen que coincidir: ni un repetido
--
--       select max(split_part(numero_recibo,'/',2)::int) -
--              min(split_part(numero_recibo,'/',2)::int) + 1
--         from public.pagos where concepto = 'PRUEBA CONCURRENCIA';
--       -- tiene que ser igual al número de inserciones: ni un hueco
--
-- (b) Que la familia no puede tocar nada. En una transacción que se
--     deshace al final (rollback), haciéndose pasar por el atleta:
--
--       begin;
--       set local role authenticated;
--       set local request.jwt.claims = '{"email":"atleta2@apolana.test"}';
--       update public.pagos set numero_recibo = '2026/9999';  -- 0 filas
--       update public.pagos set estado = 'pagado';            -- 0 filas
--       update public.pagos set anulado = true;               -- 0 filas
--       delete from public.pagos;                             -- 0 filas
--       rollback;
--
--     Todas devuelven "UPDATE 0" / "DELETE 0": la familia LEE sus
--     recibos y no puede escribir ni una coma.
-- ============================================================
