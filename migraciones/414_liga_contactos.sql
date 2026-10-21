-- 414 · Liga: contacto de los participantes para quien la gestiona (Mario, José Luis).
-- Andrés (21-oct-2026): en vez de darles el listado de socios, en la pantalla de la Liga
-- se ve el teléfono y el correo SOLO de quien ha comunicado pruebas en la edición activa,
-- para avisarle (p. ej. al rechazar una carrera). Mismo permiso que liga_atletas_nombres.
begin;
create or replace function public.liga_contactos()
returns table(atleta_id uuid, telefono text, email text)
language sql stable security definer set search_path = public as $$
  select a.id,
         coalesce(nullif(btrim(a.telefono),''), nullif(btrim(p.telefono),''), nullif(btrim(a.telefono_tutor),'')),
         coalesce(nullif(btrim(a.email),''), nullif(btrim(p.email),''), nullif(btrim(a.email_tutor),''))
    from public.atletas a
    left join public.perfiles p on p.id = a.perfil_id
   where (public.es_staff() or public.es_responsable_liga())
     and exists (select 1 from public.liga_participaciones lp
                   join public.liga_ediciones e on e.id = lp.edicion_id and e.activa
                  where lp.atleta_id = a.id)
$$;
revoke all on function public.liga_contactos() from public, anon;
grant execute on function public.liga_contactos() to authenticated;
commit;
