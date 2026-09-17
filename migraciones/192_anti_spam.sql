-- 192 · Anti-spam para los formularios públicos
-- --------------------------------------------------------------------
-- Los formularios que puede rellenar cualquiera (anónimo) no tenían freno:
-- solicitudes de inscripción, mensajes al club y altas del Cubo. Se añade un
-- límite por IP con ventana de tiempo. Es FAIL-OPEN: si no se conoce la IP no
-- se bloquea a nadie (mejor dejar pasar que cortar a un socio legítimo). A los
-- usuarios con sesión (auth.uid() no nulo) no se les limita: solo al público.
-- (Las altas del Cubo se controlan en la Edge Function cubo-alta, que sí ve la
-- IP real del cliente; aquí van los dos formularios de inserción directa.)

create table if not exists public.rate_limit_log (
  id uuid primary key default gen_random_uuid(),
  ip text not null,
  accion text not null,
  creado_en timestamptz not null default now()
);
create index if not exists rate_limit_log_busca on public.rate_limit_log (accion, ip, creado_en);
alter table public.rate_limit_log enable row level security;
-- Sin políticas para el front: solo lo tocan funciones SECURITY DEFINER y el
-- service_role (Edge). Se conceden los permisos mínimos.
grant select, insert, delete on public.rate_limit_log to service_role;

-- IP del cliente, leída de las cabeceras que Supabase expone a Postgres.
create or replace function public.ip_cliente()
  returns text language plpgsql stable security definer set search_path to 'public' as $$
declare h json; xff text;
begin
  begin h := current_setting('request.headers', true)::json; exception when others then return null; end;
  if h is null then return null; end if;
  xff := coalesce(h->>'cf-connecting-ip', h->>'x-real-ip', h->>'x-forwarded-for');
  if xff is null or btrim(xff) = '' then return null; end if;
  return btrim(split_part(xff, ',', 1));   -- "ip_cliente, proxy…" → la primera
end $$;

-- Comprueba el límite y registra el intento. Lanza excepción si se pasa.
create or replace function public.anti_spam(p_accion text, p_max int, p_ventana interval)
  returns void language plpgsql security definer set search_path to 'public' as $$
declare v_ip text; v_n int;
begin
  v_ip := public.ip_cliente();
  if v_ip is null then return; end if;                 -- fail-open
  select count(*) into v_n from public.rate_limit_log
    where accion = p_accion and ip = v_ip and creado_en > now() - p_ventana;
  if v_n >= p_max then
    raise exception 'Demasiados envíos desde tu conexión. Espera unos minutos y vuelve a probar.'
      using errcode = 'check_violation';
  end if;
  insert into public.rate_limit_log(ip, accion) values (v_ip, p_accion);
  if random() < 0.02 then      -- limpieza oportunista y barata
    delete from public.rate_limit_log where creado_en < now() - interval '1 day';
  end if;
end $$;

grant execute on function public.ip_cliente() to anon, authenticated;
grant execute on function public.anti_spam(text, int, interval) to anon, authenticated;

-- Triggers en los dos formularios de inserción directa (solo público anónimo).
create or replace function public.tg_anti_spam_solicitud()
  returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then perform public.anti_spam('solicitud', 5, interval '10 minutes'); end if;
  return new;
end $$;
drop trigger if exists anti_spam_solicitud on public.solicitudes_inscripcion;
create trigger anti_spam_solicitud before insert on public.solicitudes_inscripcion
  for each row execute function public.tg_anti_spam_solicitud();

create or replace function public.tg_anti_spam_mensaje()
  returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then perform public.anti_spam('mensaje', 5, interval '10 minutes'); end if;
  return new;
end $$;
drop trigger if exists anti_spam_mensaje on public.mensajes;
create trigger anti_spam_mensaje before insert on public.mensajes
  for each row execute function public.tg_anti_spam_mensaje();
