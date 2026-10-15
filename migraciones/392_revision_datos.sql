-- 392 · Revisión de datos: fichas raras antes de que den guerra en los cobros
-- ---------------------------------------------------------------------------
-- Andrés (15-oct): «un informe de datos raros para limpiar fichas antes de
-- cobrar». Salió a raíz de Oliver Llopis, con la cuota a 0 € por error.
--
-- · revision_datos()  → filas (categoria, atleta_id, ref, nombre, detalle).
--     Solo admin (raise si no). `ref` es lo que se ignora: el id de la ficha,
--     salvo en «alta del Cubo sin ficha», donde no hay ficha y es el id del alta.
-- · revision_datos_ignorados → los falsos positivos que alguien marca con
--     «Ignorar» en admin/revision-datos. La RPC no los devuelve. Solo admin.
--
-- Qué cuenta como ficha ACTIVA: estado distinto de 'baja' y sin anonimizar.
-- Las fichas municipales (lista del Ayuntamiento) no entran en las comprobaciones
-- de contacto ni de tutor: vienen sin esos datos de origen.
-- ---------------------------------------------------------------------------
begin;

create table if not exists public.revision_datos_ignorados (
  categoria  text not null,
  -- id de la ficha (atletas.id); en 'cubo_sin_ficha' es el id de cubo_altas.
  -- Sin clave foránea a propósito: vale para los dos casos.
  atleta_id  uuid not null,
  nota       text,
  quien      uuid default auth.uid() references public.perfiles(id) on delete set null,
  cuando     timestamptz not null default now(),
  primary key (categoria, atleta_id)
);
comment on table public.revision_datos_ignorados is
  'Falsos positivos marcados con «Ignorar» en admin/revision-datos. revision_datos() no los devuelve. Solo admin.';

alter table public.revision_datos_ignorados enable row level security;
drop policy if exists "admin gestiona ignorados de revision" on public.revision_datos_ignorados;
create policy "admin gestiona ignorados de revision" on public.revision_datos_ignorados
  for all to authenticated
  using ((select public.es_admin()))
  with check ((select public.es_admin()));

revoke all on public.revision_datos_ignorados from anon, public;
grant select, insert, update, delete on public.revision_datos_ignorados to authenticated;


create or replace function public.revision_datos()
returns table (categoria text, atleta_id uuid, ref uuid, nombre text, detalle text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_ini date := case when extract(month from current_date) >= 9
                     then make_date(extract(year from current_date)::int, 9, 1)
                     else make_date(extract(year from current_date)::int - 1, 9, 1) end;
begin
  if not public.es_admin() then
    raise exception 'Solo administración puede ver la revisión de datos';
  end if;

  return query
  with act as (
    select a.*,
           trim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')) as nom,
           p.email as p_email, p.telefono as p_tel,
           pp.email as pp_email, pp.telefono as pp_tel
      from public.atletas a
      left join public.perfiles p  on p.id  = a.perfil_id
      left join public.perfiles pp on pp.id = a.perfil_padre_id
     where coalesce(a.estado, 'activo') <> 'baja'
       and a.anonimizado_en is null
  ),
  -- Nombre normalizado: sin tildes, sin mayúsculas, solo letras y un espacio.
  norm as (
    select act.id, act.nom, act.fecha_nacimiento,
           trim(regexp_replace(regexp_replace(lower(translate(act.nom,
             'áéíóúàèìòùäëïöüâêîôûñçÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÑÇ',
             'aeiouaeiouaeiouaeiouncaeiouaeiouaeiouaeiounc')), '[^a-z ]', ' ', 'g'), '\s+', ' ', 'g')) as k_nom,
           trim(regexp_replace(regexp_replace(lower(translate(coalesce(act.nombre,''),
             'áéíóúàèìòùäëïöüâêîôûñçÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÑÇ',
             'aeiouaeiouaeiouaeiouncaeiouaeiouaeiouaeiounc')), '[^a-z ]', ' ', 'g'), '\s+', ' ', 'g')) as k_n,
           trim(regexp_replace(regexp_replace(lower(translate(coalesce(act.apellidos,''),
             'áéíóúàèìòùäëïöüâêîôûñçÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÑÇ',
             'aeiouaeiouaeiouaeiouncaeiouaeiouaeiouaeiounc')), '[^a-z ]', ' ', 'g'), '\s+', ' ', 'g')) as k_ap,
           upper(regexp_replace(coalesce(act.dni,''), '[^0-9A-Za-z]', '', 'g')) as k_dni
      from act
     where act.nom not ilike '%(duplicado)%'
  ),
  filas as (
    -- 1 · Recibos de esta temporada a 0 € (no anulados, no rectificativos)
    select 'recibo_cero'::text as cat, a.id as aid, a.id as rid, a.nom as nm,
           (coalesce(pg.concepto,'Recibo')
             || coalesce(' · ' || pg.periodo, '')
             || coalesce(' · nº ' || pg.numero_recibo, '')
             || ' · ' || to_char(pg.importe, 'FM999990.00') || ' €'
             || ' · ' || coalesce(pg.estado,''))::text as det
      from public.pagos pg
      join act a on a.id = pg.atleta_id
     where not pg.anulado
       and pg.rectifica_a is null
       and pg.importe <= 0
       and coalesce(to_date(pg.periodo || '-01', 'YYYY-MM-DD'), pg.fecha_vencimiento, pg.created_at::date) >= v_ini

    union all
    -- 2 · Sin ningún correo (ficha, tutor ni cuenta)
    select 'sin_correo', a.id, a.id, a.nom,
           'Ni correo en la ficha, ni del tutor, ni de la cuenta'
      from act a
     where coalesce(a.tipo_membresia,'') <> 'municipal'
       and not (coalesce(a.email,'') like '%@%' or coalesce(a.email_tutor,'') like '%@%'
             or coalesce(a.p_email,'') like '%@%' or coalesce(a.pp_email,'') like '%@%')

    union all
    -- 3 · Sin ningún teléfono que valga (al menos 9 cifras)
    select 'sin_telefono', a.id, a.id, a.nom,
           case when coalesce(a.telefono, a.telefono_tutor) is not null
                then 'El teléfono que hay no parece válido: ' || coalesce(a.telefono, a.telefono_tutor)
                else 'Ni teléfono en la ficha, ni del tutor, ni de la cuenta' end
      from act a
     where coalesce(a.tipo_membresia,'') <> 'municipal'
       and not exists (
         select 1 from unnest(array[a.telefono, a.telefono_tutor, a.p_tel, a.pp_tel]) t(x)
          where length(regexp_replace(coalesce(t.x,''), '\D', '', 'g')) >= 9)

    union all
    -- 4 · Menores sin datos de tutor (ni nombre, ni correo, ni teléfono, ni cuenta de familia)
    select 'menor_sin_tutor', a.id, a.id, a.nom,
           'Tiene ' || extract(year from age(current_date, a.fecha_nacimiento))::int
             || ' años (nació el ' || to_char(a.fecha_nacimiento, 'DD/MM/YYYY') || ') y no hay tutor'
      from act a
     where a.fecha_nacimiento is not null
       and a.fecha_nacimiento > (current_date - interval '18 years')::date
       and a.fecha_nacimiento <= current_date
       and coalesce(a.tipo_membresia,'') <> 'municipal'
       and a.perfil_padre_id is null
       and coalesce(nullif(trim(a.nombre_tutor),''), nullif(trim(a.email_tutor),''), nullif(trim(a.telefono_tutor),'')) is null

    union all
    -- 5 · Posibles duplicados: mismo nombre, mismo DNI, o mismos apellidos +
    --     misma fecha de nacimiento + nombre que empieza igual (ANDRES/ANDRESS).
    --     Los gemelos (mismos apellidos y fecha, distinto nombre) NO salen.
    select 'duplicado', x.id, x.id, x.nom,
           string_agg(distinct
             case when x.k_nom = y.k_nom then 'Mismo nombre que otra ficha'
                  when x.k_dni = y.k_dni then 'Mismo DNI (' || x.k_dni || ') que ' || y.nom
                  else 'Mismos apellidos y fecha que ' || y.nom end, ' · ')
      from norm x
      join norm y on y.id <> x.id
       and (   (x.k_nom <> '' and x.k_nom = y.k_nom)
            or (length(x.k_dni) >= 6 and x.k_dni = y.k_dni)
            or (x.k_ap <> '' and x.k_ap = y.k_ap
                and x.fecha_nacimiento is not null and x.fecha_nacimiento = y.fecha_nacimiento
                and left(x.k_n, 4) = left(y.k_n, 4)))
     group by x.id, x.nom

    union all
    -- 6 · Sin ningún grupo y sin natación. Los socios «a secas» y los atletas
    --     que solo compiten (tipo 'atleta') no tienen por qué estar en un grupo.
    select 'sin_grupo', a.id, a.id, a.nom,
           'Ni en un grupo ni en natación'
             || coalesce(' · ' || coalesce(a.tipo_membresia, 'sin tipo'), '')
             || case when a.estado = 'prueba' then ' · de prueba' else '' end
      from act a
     where coalesce(a.tipo_membresia,'') not in ('socio','atleta')
       and not exists (select 1 from public.atleta_grupos ag where ag.atleta_id = a.id)
       and not exists (
         select 1 from public.natacion_inscripciones ni
          where ni.activa
            and (ni.atleta_id = a.id
                 or ni.acceso_id in (select na.id from public.natacion_accesos na
                                      where na.atleta_id = a.id and na.activo)))

    union all
    -- 7 · Socios sin número, o con un número que tiene otra ficha activa
    select 'socio_numero', a.id, a.id, a.nom,
           case when nullif(trim(a.numero_socio),'') is null then 'Es socio y no tiene número'
                else 'El número ' || trim(a.numero_socio) || ' lo tiene también ' ||
                  (select string_agg(b.nom, ', ') from act b
                    where b.id <> a.id and trim(b.numero_socio) = trim(a.numero_socio)) end
      from act a
     where (a.tipo_membresia = 'socio' or nullif(trim(a.numero_socio),'') is not null)
       and (nullif(trim(a.numero_socio),'') is null
            or exists (select 1 from act b where b.id <> a.id
                         and trim(b.numero_socio) = trim(a.numero_socio)))

    union all
    -- 8 · Altas del Cubo aprobadas sin ficha (aquí no hay atleta_id: ref = el alta)
    select 'cubo_sin_ficha', null::uuid, c.id,
           trim(coalesce(c.nombre,'') || ' ' || coalesce(c.apellidos,'')),
           'Alta aprobada el ' || to_char(c.created_at, 'DD/MM/YYYY') || ' · ' || coalesce(c.horario,'')
      from public.cubo_altas c
     where c.estado = 'aprobada'
       and c.atleta_id is null

    union all
    -- 9 · Fecha de nacimiento sospechosa
    select 'fecha_nacimiento', a.id, a.id, a.nom,
           case when a.fecha_nacimiento > current_date then 'Fecha en el futuro: '
                when a.fecha_nacimiento < (current_date - interval '100 years')::date then 'Más de 100 años: '
                else '1 de enero (¿puesta por defecto?): ' end
             || to_char(a.fecha_nacimiento, 'DD/MM/YYYY')
      from act a
     where a.fecha_nacimiento is not null
       and (a.fecha_nacimiento > current_date
            or a.fecha_nacimiento < (current_date - interval '100 years')::date
            or to_char(a.fecha_nacimiento, 'MM-DD') = '01-01')
  )
  select f.cat, f.aid, f.rid, f.nm, f.det
    from filas f
   where not exists (select 1 from public.revision_datos_ignorados i
                      where i.categoria = f.cat and i.atleta_id = f.rid)
   order by f.cat, f.nm;
end;
$$;

comment on function public.revision_datos() is
  'Informe de datos raros para admin/revision-datos (recibos a 0 €, sin contacto, menores sin tutor, duplicados, sin grupo, nº de socio, altas del Cubo sin ficha, fechas raras). Solo admin.';

revoke all on function public.revision_datos() from public, anon;
grant execute on function public.revision_datos() to authenticated;

commit;
