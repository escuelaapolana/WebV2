-- Catálogo de pruebas (atletismo + natación) para desplegables y para saber
-- si en cada prueba "más es mejor" (distancia/puntos) o "menos es mejor" (tiempo).
create table if not exists public.pruebas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  disciplina text,          -- velocidad, vallas, medio fondo, fondo, marcha, salto, lanzamiento, combinada, natación
  ambito text not null,     -- atletismo | natacion
  unidad text not null,     -- tiempo | distancia | puntos
  mas_es_mejor boolean not null default false,
  orden int default 0,
  activa boolean default true
);

alter table public.pruebas enable row level security;
drop policy if exists "catalogo pruebas lectura" on public.pruebas;
create policy "catalogo pruebas lectura" on public.pruebas for select using (true);
drop policy if exists "admin gestiona pruebas" on public.pruebas;
create policy "admin gestiona pruebas" on public.pruebas for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

insert into public.pruebas (nombre, disciplina, ambito, unidad, mas_es_mejor, orden) values
  -- Atletismo · velocidad
  ('60 m lisos','velocidad','atletismo','tiempo',false,10),
  ('100 m lisos','velocidad','atletismo','tiempo',false,11),
  ('150 m lisos','velocidad','atletismo','tiempo',false,12),
  ('200 m lisos','velocidad','atletismo','tiempo',false,13),
  ('300 m lisos','velocidad','atletismo','tiempo',false,14),
  ('400 m lisos','velocidad','atletismo','tiempo',false,15),
  -- Atletismo · vallas
  ('60 m vallas','vallas','atletismo','tiempo',false,20),
  ('100 m vallas','vallas','atletismo','tiempo',false,21),
  ('110 m vallas','vallas','atletismo','tiempo',false,22),
  ('400 m vallas','vallas','atletismo','tiempo',false,23),
  -- Atletismo · medio fondo
  ('800 m','medio fondo','atletismo','tiempo',false,30),
  ('1.000 m','medio fondo','atletismo','tiempo',false,31),
  ('1.500 m','medio fondo','atletismo','tiempo',false,32),
  ('Milla','medio fondo','atletismo','tiempo',false,33),
  ('3.000 m','medio fondo','atletismo','tiempo',false,34),
  ('3.000 m obstáculos','medio fondo','atletismo','tiempo',false,35),
  -- Atletismo · fondo
  ('5.000 m','fondo','atletismo','tiempo',false,40),
  ('10.000 m','fondo','atletismo','tiempo',false,41),
  ('Media maratón','fondo','atletismo','tiempo',false,42),
  ('Maratón','fondo','atletismo','tiempo',false,43),
  -- Atletismo · marcha
  ('3.000 m marcha','marcha','atletismo','tiempo',false,50),
  ('5.000 m marcha','marcha','atletismo','tiempo',false,51),
  ('10.000 m marcha','marcha','atletismo','tiempo',false,52),
  -- Atletismo · saltos
  ('Salto de longitud','salto','atletismo','distancia',true,60),
  ('Triple salto','salto','atletismo','distancia',true,61),
  ('Salto de altura','salto','atletismo','distancia',true,62),
  ('Salto con pértiga','salto','atletismo','distancia',true,63),
  -- Atletismo · lanzamientos
  ('Lanzamiento de peso','lanzamiento','atletismo','distancia',true,70),
  ('Lanzamiento de disco','lanzamiento','atletismo','distancia',true,71),
  ('Lanzamiento de jabalina','lanzamiento','atletismo','distancia',true,72),
  ('Lanzamiento de martillo','lanzamiento','atletismo','distancia',true,73),
  -- Atletismo · combinadas
  ('Pentatlón','combinada','atletismo','puntos',true,80),
  ('Heptatlón','combinada','atletismo','puntos',true,81),
  ('Decatlón','combinada','atletismo','puntos',true,82),
  -- Natación · libre
  ('50 m libres','libre','natacion','tiempo',false,110),
  ('100 m libres','libre','natacion','tiempo',false,111),
  ('200 m libres','libre','natacion','tiempo',false,112),
  ('400 m libres','libre','natacion','tiempo',false,113),
  ('800 m libres','libre','natacion','tiempo',false,114),
  ('1.500 m libres','libre','natacion','tiempo',false,115),
  -- Natación · espalda
  ('50 m espalda','espalda','natacion','tiempo',false,120),
  ('100 m espalda','espalda','natacion','tiempo',false,121),
  ('200 m espalda','espalda','natacion','tiempo',false,122),
  -- Natación · braza
  ('50 m braza','braza','natacion','tiempo',false,130),
  ('100 m braza','braza','natacion','tiempo',false,131),
  ('200 m braza','braza','natacion','tiempo',false,132),
  -- Natación · mariposa
  ('50 m mariposa','mariposa','natacion','tiempo',false,140),
  ('100 m mariposa','mariposa','natacion','tiempo',false,141),
  ('200 m mariposa','mariposa','natacion','tiempo',false,142),
  -- Natación · estilos
  ('100 m estilos','estilos','natacion','tiempo',false,150),
  ('200 m estilos','estilos','natacion','tiempo',false,151),
  ('400 m estilos','estilos','natacion','tiempo',false,152)
on conflict (nombre) do nothing;
