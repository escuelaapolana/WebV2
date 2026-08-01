-- Escuela o socio: por defecto se calcula por la edad, pero se puede fijar a mano
-- para las excepciones (p. ej. un nacido en 2009 que ya es socio del club).
-- null = automático por año de nacimiento; 'escuela' / 'socio' = fijado a mano.
alter table public.atletas add column if not exists tipo_membresia text
  check (tipo_membresia is null or tipo_membresia in ('escuela','socio'));
