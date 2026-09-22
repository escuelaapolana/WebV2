-- 201 · Pagos puntuales del Cubo («ponle un pago y le sale en la app»)
-- El club le pone a una persona un pago (concepto + importe). A esa persona
-- le aparece en su portal del Cubo como «pago pendiente» y lo paga con tarjeta
-- (Stripe Checkout). Al pagar, se marca cobrado. El IMPORTE lo fija el club y
-- vive aquí; la función de pago lo lee de esta tabla, nunca del navegador.
create table if not exists public.cubo_cobros (
  id uuid primary key default gen_random_uuid(),
  alta_id uuid references public.cubo_altas(id) on delete cascade,
  perfil_id uuid,
  concepto text not null,
  importe_cent integer not null check (importe_cent > 0 and importe_cent <= 100000),
  estado text not null default 'pendiente',            -- pendiente | pagado | cancelado
  stripe_session_id text,
  stripe_payment_intent text,
  creado_por uuid default auth.uid(),
  created_at timestamptz not null default now(),
  pagado_en timestamptz,
  cancelado_en timestamptz
);
create index if not exists cubo_cobros_perfil_idx on public.cubo_cobros(perfil_id) where estado = 'pendiente';

alter table public.cubo_cobros enable row level security;
drop policy if exists cubo_cobros_admin on public.cubo_cobros;
create policy cubo_cobros_admin on public.cubo_cobros for all to authenticated
  using (public.es_admin()) with check (public.es_admin());
drop policy if exists cubo_cobros_propia_lee on public.cubo_cobros;
create policy cubo_cobros_propia_lee on public.cubo_cobros for select to authenticated
  using (perfil_id = public.mi_perfil_id());
grant select, insert, update on public.cubo_cobros to authenticated;

-- Poner un pago (solo admin). Devuelve la fila creada.
create or replace function public.cubo_cobro_poner(p_alta_id uuid, p_concepto text, p_importe numeric)
 returns public.cubo_cobros
 language plpgsql security definer set search_path to 'public'
as $$
declare
  v public.cubo_cobros;
  v_perfil uuid;
  v_cent integer := round(coalesce(p_importe,0) * 100);
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede poner pagos.' using errcode = '42501';
  end if;
  if public.texto_de_fuera(p_concepto, 120) is null then
    raise exception 'Falta el concepto del pago.' using errcode = 'P0001';
  end if;
  if v_cent < 1 or v_cent > 100000 then
    raise exception 'Importe no válido (entre 0,01 y 1000 €).' using errcode = 'P0001';
  end if;
  select perfil_id into v_perfil from public.cubo_altas where id = p_alta_id;
  if not found then
    raise exception 'Esa alta ya no está.' using errcode = 'P0001';
  end if;
  insert into public.cubo_cobros (alta_id, perfil_id, concepto, importe_cent)
  values (p_alta_id, v_perfil, public.texto_de_fuera(p_concepto, 120), v_cent)
  returning * into v;
  return v;
end; $$;

-- Cancelar un pago pendiente (solo admin).
create or replace function public.cubo_cobro_cancelar(p_id uuid)
 returns void
 language plpgsql security definer set search_path to 'public'
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede cancelar pagos.' using errcode = '42501';
  end if;
  update public.cubo_cobros set estado = 'cancelado', cancelado_en = now()
   where id = p_id and estado = 'pendiente';
  if not found then
    raise exception 'Ese pago ya no está pendiente.' using errcode = 'P0001';
  end if;
end; $$;

grant execute on function public.cubo_cobro_poner(uuid, text, numeric) to authenticated;
grant execute on function public.cubo_cobro_cancelar(uuid) to authenticated;
