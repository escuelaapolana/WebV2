-- ============================================================================
-- 400 · Escuela: pasar lista los entrenadores de grupo (martes/jueves, prueba)
-- ----------------------------------------------------------------------------
-- 1) El entrenador de un grupo (grupos.entrenador_id) VE los avisos de falta
--    («no viene») de los niños de su grupo. Antes solo los veía el staff de la
--    ficha o el papel escuela.
-- 2) Dos datos nuevos en la ficha, para la lista del entrenador:
--    · escuela_dias smallint[]: si solo viene ALGUNOS días de su grupo
--      (1=lunes … 7=domingo). Null = todos los días del grupo.
--    · aviso_salud text: lo que el entrenador DEBE saber (alergias, etc.).
--    Se rellenan con las observaciones del listado de martes/jueves (20-oct).
-- 3) Fuera de grupos de la escuela dos fichas que no son de esos niños:
--    Iván Rubido González (adulto del Cubo, estaba en Rojo 3) y Martín Muñoz
--    Eslava (nacido en 2013, estaba en Rojo 1a, grupo de 2022-2023).
-- ============================================================================
begin;

alter table public.atletas add column if not exists escuela_dias smallint[];
alter table public.atletas add column if not exists aviso_salud text;
comment on column public.atletas.escuela_dias is 'Escuela: días de la semana que viene si NO son todos los de su grupo (1=lunes…7=domingo). Null = todos.';
comment on column public.atletas.aviso_salud is 'Escuela: aviso que ve el entrenador al pasar lista (alergias, necesidades…).';

drop policy if exists "entrenador de grupo ve los avisos de falta" on public.ausencias;
create policy "entrenador de grupo ve los avisos de falta" on public.ausencias
  for select to authenticated using (public.soy_entrenador_de(atleta_id));

update public.atletas set escuela_dias = '{2}' where id = '0d6f24a8-be22-47c9-88b8-a63e033cda19' and escuela_dias is distinct from '{2}';  -- Gabriel Andrés Plana
update public.atletas set escuela_dias = '{4}' where id = '18faaf52-599e-421a-a912-cd3aa805f4c6' and escuela_dias is distinct from '{4}';  -- Sara Riera Agulló
update public.atletas set escuela_dias = '{2}' where id = '9ce65c2e-5d04-4e17-9b55-d4cc3d208b08' and escuela_dias is distinct from '{2}';  -- Lucía Domínguez Esplá
update public.atletas set escuela_dias = '{4}' where id = 'c8eac940-34c7-4c7d-9012-4e5fd530770f' and escuela_dias is distinct from '{4}';  -- Pelayo Izquierdo Serrano
update public.atletas set escuela_dias = '{4}' where id = '36f87eb6-4de0-45e8-bc84-be4284248079' and escuela_dias is distinct from '{4}';  -- Sandra Cacho Hernández
update public.atletas set escuela_dias = '{2}' where id = '740f8909-b1fe-459f-aa6f-5903c5e598be' and escuela_dias is distinct from '{2}';  -- Adrián Garcia de Dionisio Gathy
update public.atletas set escuela_dias = '{2}' where id = 'f91e9fa8-c7ef-4834-b31e-db55bc9af740' and escuela_dias is distinct from '{2}';  -- Adrian Sanchez Fuentes
update public.atletas set escuela_dias = '{2}' where id = '60982b88-107f-4c37-894b-3951d54bbf66' and escuela_dias is distinct from '{2}';  -- Leonor Lladosa Pardo
update public.atletas set aviso_salud = 'Niño con necesidades especiales' where id = 'a30e7554-e73d-486a-bd3f-e609dccef771' and aviso_salud is null;  -- Shaddaï-Maël Prat Amugu
update public.atletas set aviso_salud = 'Alérgico a los frutos secos' where id = 'b46c6b5c-f1d8-4fe0-abd4-c69a44f8ec1f' and aviso_salud is null;  -- Martín Garibaldi Sánchez
update public.atletas set aviso_salud = 'Sangra por la nariz, alérgico al polen/polvo/olores fuertes' where id = '3882346f-51e2-4d24-af76-3e001f5b7ccd' and aviso_salud is null;  -- Leandro Mendoza Montilla

delete from public.atleta_grupos ag using public.atletas a, public.grupos g
 where ag.atleta_id = a.id and g.id = ag.grupo_id and g.seccion = 'escuela'
   and ((a.nombre = 'Iván' and a.apellidos = 'Rubido González' and a.tipo_membresia = 'cubo')
     or (upper(a.nombre) = 'MARTÍN' and upper(a.apellidos) = 'MUÑOZ ESLAVA' and a.fecha_nacimiento = '2013-12-11'));

commit;
