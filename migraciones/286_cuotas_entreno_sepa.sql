-- 286 · Cuotas de ENTRENO por SUSCRIPCIÓN SEPA (trimestral, 3 cargos).
-- --------------------------------------------------------------------
-- QUÉ ES
--   Los adultos de Velocidad/Academia pagan el entrenamiento por trimestres
--   (oct, ene, abr) por DOMICILIACIÓN SEPA. En vez de recibos sueltos, es una
--   SUSCRIPCIÓN de Stripe: meten el IBAN UNA vez y Stripe cobra solo cada
--   trimestre. Tras el cargo de ABRIL la suscripción se cancela sola (en junio
--   NO se pasa nada). SEPA en vez de tarjeta: mucha menos comisión.
--
--   Cada atleta recibe un ENLACE por correo (token, sin login) que abre la
--   pantalla de Stripe para firmar el mandato. El webhook (cubo-webhook, que ya
--   recibe los eventos de la cuenta Stripe de Apolana) anota el estado aquí y
--   registra cada cobro liquidado en `pagos`.
--
-- Mes del cargo → trimestre:  10 = 1º (oct-dic), 1 = 2º (ene-mar), 4 = 3º (abr-jun).

create table if not exists public.cuotas_entreno (
  id                     uuid primary key default gen_random_uuid(),
  atleta_id              uuid not null references public.atletas(id) on delete cascade,
  perfil_id              uuid,
  nombre                 text,
  apellidos              text,
  email                  text not null,
  concepto               text not null,
  importe_cent           integer not null check (importe_cent > 0),
  meses                  integer[] not null default '{10,1,4}',
  token                  text not null unique,
  cobro_abierto          boolean not null default true,
  stripe_customer_id     text,
  stripe_subscription_id text,
  suscripcion_estado     text not null default 'pendiente'
                           check (suscripcion_estado in ('pendiente','activa','impago','cancelada')),
  cancel_programado      boolean not null default false,
  ultimo_cobro           timestamptz,
  proximo_cobro          timestamptz,
  nota                   text,
  created_at             timestamptz not null default now()
);

create index if not exists idx_cuotas_entreno_atleta on public.cuotas_entreno(atleta_id);
create index if not exists idx_cuotas_entreno_token  on public.cuotas_entreno(token);
create index if not exists idx_cuotas_entreno_sub    on public.cuotas_entreno(stripe_subscription_id);
create index if not exists idx_cuotas_entreno_cli    on public.cuotas_entreno(stripe_customer_id);

alter table public.cuotas_entreno enable row level security;

drop policy if exists "admin gestiona cuotas entreno" on public.cuotas_entreno;
create policy "admin gestiona cuotas entreno" on public.cuotas_entreno
  to authenticated using (es_admin() or es_staff()) with check (es_admin() or es_staff());

-- --- Siembra de los 6 (Bella NO: su pago es único, se queda como recibo) ---
-- El token es dos uuid pegados sin guiones (64 hex, imposible de adivinar).
insert into public.cuotas_entreno (atleta_id, perfil_id, nombre, apellidos, email, concepto, importe_cent, token)
select a.id, a.perfil_id, a.nombre, a.apellidos,
       coalesce(nullif(btrim(a.email),''), nullif(btrim(a.email_tutor),'')),
       'Cuota de entrenamiento · temporada 2026/27 (trimestral)',
       (a.cuota_importe * 100)::int,
       replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','')
from public.atletas a
where a.id in (
  '0762c205-7fed-43ee-a213-1be4f1caa6d9',  -- Juan Asensi   250
  '3e0355ca-c758-40f4-8959-795980e95ba9',  -- Mateo Brián   250
  '9a458727-4596-4451-af2e-2f4862bb7310',  -- Esther del Castillo 180
  '54ce1fdd-ecd3-452c-897a-b02f4ea86ab0',  -- Dante Diez    180
  'a7757c8b-08ac-45d0-8ecc-71d556187e78',  -- Pablo Olivares 120
  '1d88667c-e570-4df8-ba1f-cf478de617fe'   -- Luna Payero   180
)
and not exists (select 1 from public.cuotas_entreno c where c.atleta_id = a.id);

-- --- Fuera los recibos-placeholder de octubre de esos 6 (estaban pendientes,
--     sin emitir: los sustituye el SEPA). Bella NO se toca. ---
delete from public.pagos
where numero_recibo is null
  and estado = 'pendiente'
  and concepto ilike 'Cuota de entreno · 1er trimestre%'
  and atleta_id in (
    '0762c205-7fed-43ee-a213-1be4f1caa6d9','3e0355ca-c758-40f4-8959-795980e95ba9',
    '9a458727-4596-4451-af2e-2f4862bb7310','54ce1fdd-ecd3-452c-897a-b02f4ea86ab0',
    'a7757c8b-08ac-45d0-8ecc-71d556187e78','1d88667c-e570-4df8-ba1f-cf478de617fe'
  );
