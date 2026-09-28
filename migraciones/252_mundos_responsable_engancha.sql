-- 252 · Que «dar acceso a un mundo» funcione de verdad
-- ---------------------------------------------------------------------------
-- PROBLEMA (José Luis Picazo, resp. de comunicación): al darle el mundo en
-- «gestión de mundos» se le crea la fila en responsable_seccion, PERO su papel
-- seguía siendo 'atleta'. El conmutador de vistas solo enseña «Responsable» si
-- 'responsable' está en sus ROLES, así que no tenía por dónde entrar al mundo.
-- Y la Liga (es_responsable_liga) solo miraba admin/coordinador, ignorando al
-- responsable de comunicación. Resultado: el mundo se ve en «gestión» pero no
-- sirve. Se arreglan las dos cosas de raíz (vale para CUALQUIER responsable).
-- ---------------------------------------------------------------------------
begin;

-- 1) mis_papeles(): si tienes alguna sección como responsable, tu lista de
--    ROLES incluye 'responsable' (aunque tu rol principal sea atleta). Así el
--    conmutador de vistas te ofrece «Responsable» y puedes entrar a tu mundo.
create or replace function public.mis_papeles()
returns jsonb language sql stable security definer set search_path = 'public' as $$
  select jsonb_build_object(
    'nombre',    btrim(coalesce(p.nombre,'') || ' ' || coalesce(p.apellidos,'')),
    'principal', p.rol,
    'activo',    coalesce(p.rol_activo, p.papel_al_entrar, p.rol),
    'elegido',   p.rol_activo,
    'al_entrar', p.papel_al_entrar,
    'roles',     to_jsonb(
      case when exists (select 1 from public.responsable_seccion rs where rs.perfil_id = p.id)
        then (select array_agg(distinct r) from unnest(coalesce(p.roles, array[p.rol]) || array['responsable']) r)
        else coalesce(p.roles, array[p.rol])
      end),
    'responsable', coalesce(
      (select jsonb_agg(rs.seccion order by rs.seccion)
         from public.responsable_seccion rs where rs.perfil_id = p.id),
      '[]'::jsonb)
  )
    from public.perfiles p
   where p.email = (auth.jwt() ->> 'email')
   limit 1;
$$;

-- 2) es_responsable_liga(): además de admin/coordinador, el responsable de
--    COMUNICACIÓN gestiona la Liga (validar/publicar). La Liga vive dentro del
--    mundo de comunicación, así que quien lo lleva puede con ella.
create or replace function public.es_responsable_liga()
returns boolean language sql stable security definer set search_path = 'public' as $$
  select exists (
    select 1 from public.perfiles p
     where p.email = (auth.jwt() ->> 'email')
       and coalesce(p.activo, true)
       and coalesce(p.rol_activo, p.rol) in ('admin', 'coordinador')
  ) or public.soy_responsable('comunicacion');
$$;

commit;
