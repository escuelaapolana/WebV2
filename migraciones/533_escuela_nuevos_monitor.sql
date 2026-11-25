-- ============================================================
-- 533 · Escuela · el correo de los nuevos lleva el monitor y el nombre de pila
-- ------------------------------------------------------------
-- 17-nov-2026: «cuando me los envíes, pon el nombre del monitor y adjunta el
-- mensaje ya personalizado para cada uno». El mensaje lo arma la Edge
-- escuela-isa-sync con estos datos (grupo, monitor = nombre del entrenador del
-- grupo, días y horas de grupos.horario).
-- ============================================================
begin;

create or replace function public.escuela_nuevos_pendientes()
returns jsonb
language sql stable security definer
set search_path to 'public'
as $$
  select coalesce(jsonb_agg(x order by x->>'creado', x->>'nombre'), '[]'::jsonb)
    from (
      select jsonb_build_object(
               'atleta_id', a.id,
               'creado', q.creado_en,
               'nombre', btrim(a.nombre || ' ' || coalesce(a.apellidos, '')),
               'nombre_pila', btrim(a.nombre),
               'estado', a.estado,
               'nacimiento', a.fecha_nacimiento,
               'turno', nullif(btrim(substring(a.observaciones from 'Turno: ([^·]*)')), ''),
               'grupo', g.nombre,
               'grupo_horario', g.horario,
               'monitor', nullif(btrim(coalesce(g.monitor, '')), ''),
               'grupo_ninos', (select count(*) from public.atleta_grupos ag2 join public.atletas a2 on a2.id = ag2.atleta_id
                                where ag2.grupo_id = g.id and a2.estado in ('activo', 'prueba')),
               'alternativa', case when q.alternativa is distinct from g.nombre then q.alternativa end,
               'aviso_grupo', case when g.id is null then coalesce(q.aviso, 'Sin grupo: elegirlo en el panel.') end,
               'tutor', nullif(btrim(coalesce(a.nombre_tutor, '')), ''),
               'telefono', nullif(btrim(coalesce(a.telefono_tutor, a.telefono, '')), '')
             ) x
        from public.escuela_nuevos_aviso q
        join public.atletas a on a.id = q.atleta_id
        left join lateral (
          select g.id, g.nombre, g.horario, p.nombre monitor
            from public.atleta_grupos ag join public.grupos g on g.id = ag.grupo_id
            left join public.perfiles p on p.id = g.entrenador_id
           where ag.atleta_id = a.id and g.seccion = 'escuela'
           order by ag.principal desc nulls last limit 1) g on true
       where q.avisado_en is null
         and a.estado in ('activo', 'prueba') and a.anonimizado_en is null
    ) s
$$;

revoke all on function public.escuela_nuevos_pendientes() from public, anon, authenticated;
grant execute on function public.escuela_nuevos_pendientes() to service_role;

commit;
