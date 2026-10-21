-- 420 · Andrés (21-oct-2026): se vuelven a mostrar la chaqueta de chándal y la parka; la
-- «Camiseta del club» (15 €) lleva foto de camiseta de TIRANTES, no la de competición.
begin;
update public.productos set activo = true where nombre in ('Chaqueta de chándal', 'Parka del club');
update public.productos set imagen_url = 'tienda-camiseta-tirantes-mujer-frente.jpg' where nombre = 'Camiseta del club';
commit;
