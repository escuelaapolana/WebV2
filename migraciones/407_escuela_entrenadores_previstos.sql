-- 407 · Escuela (Andrés, 20-oct-2026):
--  · Adrián García de Dionisio viene SOLO martes y miércoles.
--  · Quién lleva cada grupo de las 17:30. Solo Cristian tiene cuenta de entrenador:
--    a él se le asigna ya (Verde 1 L/X); el resto se guarda en grupos.entrenador_previsto
--    para que el panel lo diga («será Paula») hasta que se den de alta y se les asigne.
begin;
update public.atletas set escuela_dias = '{2,3}'
 where public._nombre_norm(nombre||' '||apellidos) = 'adrian garcia de dionisio gathy';

alter table public.grupos add column if not exists entrenador_previsto text;
comment on column public.grupos.entrenador_previsto is 'Escuela: quién va a llevar el grupo mientras no tiene cuenta (se muestra en admin/escuela-grupos).';

update public.grupos g set entrenador_previsto = v.quien
  from (values
    -- lunes y miércoles 17:30
    ('26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid, 'Laura Fuentes'),
    ('7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid, 'Noelia López'),
    ('e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid, 'Paula Caballero'),
    ('1949f211-ed08-495b-9e75-c8a398a0e681'::uuid, 'Alejandro Sanchís'),
    ('78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid, 'Joan Pellín'),
    ('335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid, 'Carles Cobollo'),
    ('b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid, 'Carla Arwen'),
    ('af8c1675-905f-4548-979b-3409fc2b25a4'::uuid, 'Cristian Rodríguez'),
    -- martes y jueves 17:30
    ('85b804bd-b180-4881-b95b-857821e4f137'::uuid, 'Laura Fuentes'),
    ('00ec2abf-346e-4e3a-9895-73c55b40b07d'::uuid, 'Noelia López'),
    ('629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid, 'Paula Caballero'),
    ('74567283-d08e-4c41-8427-f64633ea9745'::uuid, 'Alejandro Sanchís'),
    ('0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid, 'Joan Pellín'),
    ('c98add51-8636-4f01-b290-9e849a7fc935'::uuid, 'Mateo Brián'),
    ('ec084bfe-6906-4f06-8523-b708a7fc2efe'::uuid, 'Dante Diez'),
    ('d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid, 'Carles Cobollo'),
    ('e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid, 'Carla Arwen'),
    ('d93016a6-ba64-45b4-ac83-2756d5337729'::uuid, 'Cristian Rodríguez')
  ) v(id, quien)
 where g.id = v.id;

-- Cristian ya tiene cuenta de entrenador: Verde 1 de lunes y miércoles
update public.grupos set entrenador_id = 'afcf4d39-b892-459e-bfd2-d115faa5bf57'
 where id = 'af8c1675-905f-4548-979b-3409fc2b25a4' and entrenador_id is null;
commit;
