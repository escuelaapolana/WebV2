-- 405 · Andrés (20-oct-2026):
--  · María Escribano Gago (Azul 2 M/J, listado de Joan) = «Rocío Escribano Gago» del
--    formulario municipal, que sale en ROJO en Respuestas: «es la misma y no está de
--    baja». Ficha municipal activa en Azul 2 + equivalencia que la comprobación diaria
--    respeta sin tocarle el estado.
--  · Mario Avilés Segura es de 2015 y chico: la fila de BUENA ISA lleva los datos de su
--    hermana Lena (5-8-2019, femenino); los suyos (4-12-2015, masculino) están en
--    Respuestas fila 86. Se corrige su ficha y la de Lena, y se apunta la equivalencia.
begin;
insert into public.atletas (nombre, apellidos, fecha_nacimiento, sexo, dni, estado, tipo_membresia, secciones,
                            nombre_tutor, email_tutor, telefono_tutor, direccion, observaciones, origen)
select 'María', 'Escribano Gago', '2020-04-06', 'mujer', '17611174M', 'activo', 'municipal', array['escuela'],
       'Raquel Aida Gago Díaz', 'raquelrgd92@gmail.com', '654371201', 'Av. Cardenal Francisco Álvarez P16 T11, 03005, Alicante',
       'En el formulario municipal figura como «Rocío Escribano Gago» (en rojo en Respuestas). Andrés 20-oct-2026: es la misma niña y NO está de baja.',
       'cuadre-municipal-2026-10-20'
 where not exists (select 1 from public.atletas where nombre = 'María' and apellidos = 'Escribano Gago');
insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select a.id, '0833f3d7-b760-416b-9677-0dcf07aba7db', true from public.atletas a      -- Azul 2 M/J
 where a.nombre = 'María' and a.apellidos = 'Escribano Gago'
   and not exists (select 1 from public.atleta_grupos x where x.atleta_id = a.id and x.grupo_id = '0833f3d7-b760-416b-9677-0dcf07aba7db');
insert into public.escuela_sync_alias (nombre_norm, atleta_id, nota, no_tocar)
select public._nombre_norm('Rocio Escribano Gago'), a.id, 'Es María Escribano Gago; el rojo de Respuestas no es baja (Andrés 20-oct-2026).', true
  from public.atletas a where a.nombre = 'María' and a.apellidos = 'Escribano Gago'
on conflict (nombre_norm) do update set atleta_id = excluded.atleta_id, no_tocar = true;

update public.atletas
   set fecha_nacimiento = '2015-12-04', sexo = 'hombre',
       observaciones = replace(observaciones, ' · OJO: el formulario dice 2019 y «femenino»; el listado del entrenador dice 2015 (revisar)',
                               ' · Nacimiento corregido 20-oct-2026 (4-12-2015, chico): la fila de BUENA ISA lleva los datos de su hermana Lena')
 where id = '7884196e-3b5d-48a6-8531-2aa19709e700';
update public.atletas set fecha_nacimiento = coalesce(fecha_nacimiento, '2019-08-05'), sexo = coalesce(sexo, 'mujer')
 where id = 'fad71518-20a8-4dc6-a651-0de6d18f5cce';
insert into public.escuela_sync_alias (nombre_norm, atleta_id, nota)
values (public._nombre_norm('Mario Aviles Segura'), '7884196e-3b5d-48a6-8531-2aa19709e700',
        'BUENA ISA trae los datos de nacimiento de Lena en la fila de Mario')
on conflict (nombre_norm) do nothing;
commit;
