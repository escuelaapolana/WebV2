-- 434 · Liga: tallas de la camiseta «Finisher» (Andrés, 22-oct-2026)
-- ---------------------------------------------------------------------------
-- «Para los atletas de la liga que ya han ganado la camiseta, que rellenen y
-- nos digan la talla.» Cada finisher (liga_clasificacion_general.finisher)
-- tiene una fila con un enlace propio /liga/camiseta/?t=… donde elige talla
-- (sin cuenta). Le llega por correo (Edge liga-camiseta-correo). La lista la
-- ven admin y comunicación (liga_camisetas_listar) en admin/liga.
-- ---------------------------------------------------------------------------
begin;

create table if not exists public.liga_camisetas (
  id            uuid primary key default gen_random_uuid(),
  edicion_id    uuid not null references public.liga_ediciones(id),
  atleta_id     uuid references public.atletas(id) on delete set null,
  clave         text not null,                 -- la de la clasificación (atleta o nombre libre)
  nombre        text not null,
  email         text,
  token         text not null unique,
  talla         text check (talla is null or talla in ('XS','S','M','L','XL','XXL','3XL')),
  nota          text check (nota is null or length(nota) <= 300),
  respondido_en timestamptz,
  avisado_en    timestamptz,
  created_at    timestamptz not null default now(),
  unique (edicion_id, clave)
);
alter table public.liga_camisetas enable row level security;
revoke all on public.liga_camisetas from anon, authenticated;
comment on table public.liga_camisetas is '434 · Talla de la camiseta Finisher de la Liga, por enlace propio (token).';

-- Crea las filas de los finisher que aún no la tienen (edición activa). Idempotente.
create or replace function public.liga_camisetas_preparar()
returns integer
language plpgsql security definer
set search_path to 'public'
as $$
declare v_ed uuid; v_n int;
begin
  select id into v_ed from public.liga_ediciones where activa order by id desc limit 1;
  if v_ed is null then return 0; end if;
  insert into public.liga_camisetas (edicion_id, atleta_id, clave, nombre, email, token)
  select v_ed, c.atleta_id, c.clave, c.nombre,
         lower(coalesce(nullif(btrim(a.email), ''), nullif(btrim(a.email_tutor), ''),
                        (select nullif(btrim(pf.email), '') from public.perfiles pf where pf.id = coalesce(a.perfil_id, a.perfil_padre_id)))),
         replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')
    from public.liga_clasificacion_general c
    left join public.atletas a on a.id = c.atleta_id
   where c.finisher and c.clave is not null
  on conflict (edicion_id, clave) do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke all on function public.liga_camisetas_preparar() from public, anon, authenticated;
grant execute on function public.liga_camisetas_preparar() to service_role;

-- Página pública: qué hay guardado para ese enlace.
create or replace function public.liga_camiseta_publica(p_token text)
returns jsonb
language sql stable security definer
set search_path to 'public'
as $$
  select jsonb_build_object('nombre', initcap(lower(split_part(btrim(c.nombre), ' ', 1))),
                            'talla', c.talla, 'nota', c.nota, 'respondido', c.respondido_en is not null)
    from public.liga_camisetas c
   where length(coalesce(p_token, '')) >= 40 and c.token = p_token
   limit 1;
$$;
revoke all on function public.liga_camiseta_publica(text) from public;
grant execute on function public.liga_camiseta_publica(text) to anon, authenticated, service_role;

-- Página pública: guardar la talla (se puede cambiar las veces que haga falta).
create or replace function public.liga_camiseta_guardar(p_token text, p_talla text, p_nota text default null)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_id uuid;
begin
  if coalesce(p_talla, '') not in ('XS','S','M','L','XL','XXL','3XL') then
    raise exception 'Elige una talla de la lista.' using errcode = 'P0001';
  end if;
  update public.liga_camisetas
     set talla = p_talla,
         nota = nullif(left(btrim(coalesce(p_nota, '')), 300), ''),
         respondido_en = now()
   where length(coalesce(p_token, '')) >= 40 and token = p_token
  returning id into v_id;
  if v_id is null then raise exception 'Este enlace no es válido.' using errcode = 'P0001'; end if;
  return jsonb_build_object('ok', true, 'talla', p_talla);
end;
$$;
revoke all on function public.liga_camiseta_guardar(text, text, text) from public;
grant execute on function public.liga_camiseta_guardar(text, text, text) to anon, authenticated, service_role;

-- Panel (admin y comunicación): quién ha contestado y qué talla.
create or replace function public.liga_camisetas_listar()
returns table (nombre text, email text, talla text, nota text, respondido_en timestamptz, avisado_en timestamptz)
language plpgsql stable security definer
set search_path to 'public'
as $$
begin
  if not (public.es_admin() or public.es_responsable_liga()) then
    raise exception 'Solo el club puede ver las tallas de la Liga.' using errcode = '42501';
  end if;
  return query
    select c.nombre, c.email, c.talla, c.nota, c.respondido_en, c.avisado_en
      from public.liga_camisetas c
      join public.liga_ediciones e on e.id = c.edicion_id and e.activa
     where c.clave not like 'prueba-%'   -- la fila de prueba de Andrés no cuenta
     order by c.respondido_en is null, lower(c.nombre);
end;
$$;
revoke all on function public.liga_camisetas_listar() from public, anon;
grant execute on function public.liga_camisetas_listar() to authenticated, service_role;

insert into public.salud_rpc_front (nombre, en_publica) values
  ('liga_camiseta_publica', true), ('liga_camiseta_guardar', true), ('liga_camisetas_listar', false)
on conflict (nombre) do nothing;

select public.liga_camisetas_preparar();
commit;
