-- 313 · Cuotas domiciliadas también MENSUALES (caso Maia, natación)
-- ---------------------------------------------------------------------------
-- Hasta ahora `cuotas_entreno` solo sabía hacer la cuota TRIMESTRAL de los
-- adultos de Velocidad/Academia (oct/ene/abr, se para tras abril). La familia
-- de Maia Castro Domínguez (natación) quiere pagar por domiciliación y en
-- SportMember no se puede: 45 €/mes del 1-oct-2026 al 30-jun-2027.
--   · periodicidad: 'trimestral' (lo de siempre) o 'mensual'.
--   · fin: último día que cubre la cuota. Stripe cancela la suscripción ese
--     día (cancel_at), así que no se pasa ningún cargo después. NULL = la
--     regla de siempre de la trimestral (tras abril).
-- El IBAN lo mete la FAMILIA en la pantalla de Stripe; aquí no se guarda.
-- ---------------------------------------------------------------------------
begin;

alter table public.cuotas_entreno
  add column if not exists periodicidad text not null default 'trimestral',
  add column if not exists fin date;

alter table public.cuotas_entreno
  drop constraint if exists cuotas_entreno_periodicidad_check;
alter table public.cuotas_entreno
  add constraint cuotas_entreno_periodicidad_check
  check (periodicidad in ('trimestral', 'mensual'));

comment on column public.cuotas_entreno.periodicidad is
  'trimestral (oct/ene/abr) o mensual (el día 1 de cada mes; el mes en curso se cobra al domiciliar).';
comment on column public.cuotas_entreno.fin is
  'Último día que cubre la cuota: Stripe cancela la suscripción ese día. NULL = tras abril (trimestral).';

-- Maia Castro Domínguez · natación · 45 €/mes · oct-2026 → jun-2027
insert into public.cuotas_entreno
  (atleta_id, nombre, apellidos, email, concepto, importe_cent, periodicidad, fin, token)
select a.id, a.nombre, a.apellidos, 'nathaliegidron@gmail.com',
       'Cuota de natación · temporada 2026/27 (mensual)', 4500, 'mensual', date '2027-06-30',
       replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','')
  from public.atletas a
 where a.id = '0f3469be-5b96-482e-882a-4d7a0dc56cc8'
   and not exists (select 1 from public.cuotas_entreno c where c.atleta_id = a.id);

commit;
