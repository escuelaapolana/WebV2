-- 186 · Interruptor del cobro de El Cubo
-- ------------------------------------------------------------
-- Permite abrir las cuentas del Cubo YA (los padres se apuntan y ven sus
-- horarios) y ABRIR EL COBRO más tarde (cuando Stripe esté en real). Mientras
-- `cobro_abierto` sea false, el portal enseña «los pagos se abrirán pronto» y
-- NO muestra el botón de pagar ni el aviso de pago pendiente. Al ponerlo en
-- true, aparece el botón. Es una tabla de UNA sola fila (id=1).
-- ============================================================
begin;

create table if not exists public.cubo_config (
  id            smallint primary key default 1,
  cobro_abierto boolean  not null default false,
  actualizado   timestamptz not null default now(),
  constraint cubo_config_una_fila check (id = 1)
);

insert into public.cubo_config (id, cobro_abierto)
  values (1, false)
  on conflict (id) do nothing;

alter table public.cubo_config enable row level security;

-- Lo lee todo el mundo (no es dato sensible); solo el admin lo cambia.
drop policy if exists cubo_config_lee_todos on public.cubo_config;
create policy cubo_config_lee_todos on public.cubo_config
  for select using (true);

drop policy if exists cubo_config_cambia_admin on public.cubo_config;
create policy cubo_config_cambia_admin on public.cubo_config
  for update using (public.es_admin()) with check (public.es_admin());

grant select on public.cubo_config to anon, authenticated;
grant update on public.cubo_config to authenticated;

commit;
