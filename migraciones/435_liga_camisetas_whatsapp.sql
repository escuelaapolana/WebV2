-- 435 · Liga: teléfono y enlace de cada finisher en la lista de tallas, para
-- mandar el recordatorio por WhatsApp desde admin/liga (Andrés: «si el lunes
-- no han contestado, les envío WhatsApp»). Solo admin y comunicación.
begin;
drop function if exists public.liga_camisetas_listar();
create function public.liga_camisetas_listar()
returns table (nombre text, email text, talla text, nota text, respondido_en timestamptz, avisado_en timestamptz,
               telefono text, enlace text)
language plpgsql stable security definer
set search_path to 'public'
as $$
begin
  if not (public.es_admin() or public.es_responsable_liga()) then
    raise exception 'Solo el club puede ver las tallas de la Liga.' using errcode = '42501';
  end if;
  return query
    select c.nombre, c.email, c.talla, c.nota, c.respondido_en, c.avisado_en,
           coalesce(nullif(btrim(a.telefono), ''), nullif(btrim(a.telefono_tutor), '')),
           'https://atletismoapolana.com/liga/camiseta/?t=' || c.token
      from public.liga_camisetas c
      join public.liga_ediciones e on e.id = c.edicion_id and e.activa
      left join public.atletas a on a.id = c.atleta_id
     where c.clave not like 'prueba-%'
     order by c.respondido_en is null, lower(c.nombre);
end;
$$;
revoke all on function public.liga_camisetas_listar() from public, anon;
grant execute on function public.liga_camisetas_listar() to authenticated, service_role;
commit;
