-- ============================================================
-- 075 · Poder retirar un nombre de récords y palmarés
-- ------------------------------------------------------------
-- En récords y palmarés los nombres se escriben a mano, en texto
-- libre, así que no se cruzan con la ficha del atleta y la regla
-- de menores de la 062 no los alcanza. Hay marcas de chavales
-- Sub-18 con nombre y apellidos en una página pública.
--
-- El club tiene la autorización de imagen firmada de todos, y un
-- récord es un reconocimiento: los nombres se quedan. Pero hasta
-- hoy la única forma de quitar uno habría sido **borrar el récord
-- entero**, que es absurdo porque la marca existió.
--
-- Con esta casilla, el club decide marca a marca. Nace marcada
-- (se sigue viendo todo igual que hasta ahora) y, si algún día
-- una familia lo pide, se desmarca y pasa a «Sergio R.» sin
-- perder el récord.
--
-- El recorte se hace en la BASE, no en la página: así vale
-- también para lo que se imprime y lo que se exporta.
-- Idempotente.
-- ============================================================

alter table public.records_club
  add column if not exists nombre_publico boolean not null default true;
alter table public.palmares
  add column if not exists nombre_publico boolean not null default true;

comment on column public.records_club.nombre_publico is
  'Si se desmarca, en la web sale nombre e inicial en vez del nombre completo. La marca no se toca.';
comment on column public.palmares.nombre_publico is
  'Si se desmarca, en la web sale nombre e inicial en vez del nombre completo. El resultado no se toca.';

-- Nombre de pila + inicial del primer apellido: «Sergio Redondo del Río» → «Sergio R.»
create or replace function public.nombre_recortado(p_nombre text)
returns text
language sql immutable
set search_path to 'public'
as $$
  select case
    when coalesce(btrim(p_nombre), '') = '' then p_nombre
    when position(' ' in btrim(p_nombre)) = 0 then btrim(p_nombre)
    else split_part(btrim(p_nombre), ' ', 1) || ' ' ||
         left(split_part(btrim(p_nombre), ' ', 2), 1) || '.'
  end;
$$;

revoke all on function public.nombre_recortado(text) from public, anon;
grant execute on function public.nombre_recortado(text) to anon, authenticated;

-- Las vistas que lee la web: el nombre ya sale recortado si toca,
-- así que ninguna página puede enseñar de más por descuido.
create or replace view public.records_club_publico as
  select r.id, r.prueba, r.categoria, r.marca,
         case when r.nombre_publico then r.atleta
              else public.nombre_recortado(r.atleta) end as atleta,
         r.anyo, r.sede, r.competicion, r.orden
    from public.records_club r;

create or replace view public.palmares_publico as
  select p.id, p.anyo, p.competicion, p.prueba, p.categoria, p.posicion,
         case when p.nombre_publico then p.atleta
              else public.nombre_recortado(p.atleta) end as atleta,
         p.ambito, p.sede
    from public.palmares p;

-- Ojo: Supabase reparte permisos de serie sobre lo nuevo. Aquí se
-- recorta a lo justo: leer, y nada más.
revoke all on public.records_club_publico from anon, authenticated, public;
revoke all on public.palmares_publico     from anon, authenticated, public;
grant select on public.records_club_publico to anon, authenticated;
grant select on public.palmares_publico     to anon, authenticated;
