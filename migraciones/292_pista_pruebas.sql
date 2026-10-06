-- 292 · Pruebas de atletismo en pista (leads de prueba)
-- Quien quiere venir a PROBAR el atletismo en pista rellena un formulario
-- CORTO (nombre, teléfono, qué día, y si es peque: edad + tutor). NO crea
-- cuenta ni ficha: es solo un lead para que el club sepa quién está de prueba.
-- Cuando decidan quedarse, se les pasa el formulario de socio (eso sí crea
-- cuenta) y a partir de ahí se les abre el cobro. Aquí solo el seguimiento.

create table if not exists public.pista_pruebas (
  id            uuid primary key default gen_random_uuid(),
  nombre        text not null,
  telefono      text not null,
  dia_preferido text,
  es_menor      boolean not null default false,
  edad          int,
  tutor         text,
  nota          text,
  seccion       text not null default 'pista',
  estado        text not null default 'nueva'
                check (estado in ('nueva','contactado','convertido','descartado')),
  created_at    timestamptz not null default now()
);

alter table public.pista_pruebas enable row level security;

-- El club (admin) lo gestiona entero; el staff (responsables) lo ve y gestiona.
-- El alta pública NO entra por aquí: la mete la Edge `pista-prueba` con la
-- clave de servicio (salta RLS), con su anti-spam.
drop policy if exists "pista_pruebas admin" on public.pista_pruebas;
create policy "pista_pruebas admin" on public.pista_pruebas
  for all using (public.es_admin()) with check (public.es_admin());

drop policy if exists "pista_pruebas staff" on public.pista_pruebas;
create policy "pista_pruebas staff" on public.pista_pruebas
  for all using (public.es_staff()) with check (public.es_staff());

create index if not exists idx_pista_pruebas_estado on public.pista_pruebas (estado, created_at desc);
