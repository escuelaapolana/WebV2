-- 260 · Competiciones de la escuela de natación (Liga FNCV + autonómicos, temp. 2026/27).
-- Amplía el CHECK de competiciones.ambito para admitir 'escuela-natacion' (ámbito propio,
-- separado del de Máster='natacion') e inserta las ~30 jornadas. Idempotente.
begin;
alter table public.competiciones drop constraint if exists competiciones_ambito_check;
alter table public.competiciones add constraint competiciones_ambito_check
  check (ambito = any (array['atletismo','natacion','pista','running','triatlon','escolar','montana','escuela-natacion']));
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '1ª Jornada Liga Infantil y Mayores', 'Pilar de la Horadada', '2026-10-24'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1781_LIGAINFYMAYORES1__%20jORNADA%20Pilar%20Horadada%20_2_.pdf', 'Categorías: Infantil, Junior, Absoluto · Horario: 10:00 y 16:00', 0, false
where not exists (select 1 from competiciones where nombre='1ª Jornada Liga Infantil y Mayores' and sede='Pilar de la Horadada' and fecha_inicio='2026-10-24'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '1ª Jornada Liga Infantil y Mayores', 'Petrer', '2026-10-24'::date, '2026-10-25', null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1782_LIGAINFYMAYORES1__%20jORNADA%20PETRER%20_2_.pdf', 'Categorías: Infantil, Junior, Absoluto · Horario: 16:00 y 10:00', 0, false
where not exists (select 1 from competiciones where nombre='1ª Jornada Liga Infantil y Mayores' and sede='Petrer' and fecha_inicio='2026-10-24'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '1ª Jornada Liga Benjamín', 'Pilar de la Horadada · Piscina Municipal', '2026-11-07'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1785_LIGA%20BENJAMIN%201__Jornada%20_1_.pdf', 'Categorías: Benjamín · Horario: 10:00', 0, false
where not exists (select 1 from competiciones where nombre='1ª Jornada Liga Benjamín' and sede='Pilar de la Horadada · Piscina Municipal' and fecha_inicio='2026-11-07'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '1ª Jornada Liga Alevín', 'Petrer · Piscina Municipal', '2026-11-07'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1786_LIGAALEVIN%201__%20Jornada%20Petrer%20_2_.pdf', 'Categorías: Alevín · Horario: 16:00', 0, false
where not exists (select 1 from competiciones where nombre='1ª Jornada Liga Alevín' and sede='Petrer · Piscina Municipal' and fecha_inicio='2026-11-07'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '2ª Jornada Liga Infantil y Mayores', 'Petrer · Piscina Municipal', '2026-11-21'::date, '2026-11-22', null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1808_LIGAINFYMAYORES2__%20jORNADA%20Petrer%20_2_.pdf', 'Categorías: Infantil, Junior, Absoluto · Horario: 16:00 y 10:00', 0, false
where not exists (select 1 from competiciones where nombre='2ª Jornada Liga Infantil y Mayores' and sede='Petrer · Piscina Municipal' and fecha_inicio='2026-11-21'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '2ª Jornada Liga Infantil y Mayores', 'San Vicente · Piscina Municipal', '2026-11-21'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1809_LIGAINFYMAYORES2__%20jORNADA%20San%20Vicente%20_2_.pdf', 'Categorías: Infantil, Junior, Absoluto · Horario: 10:00 y 17:00', 0, false
where not exists (select 1 from competiciones where nombre='2ª Jornada Liga Infantil y Mayores' and sede='San Vicente · Piscina Municipal' and fecha_inicio='2026-11-21'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select 'Fase Territorial Larga Distancia', 'Castellón · Piscina Olímpica (25 m / 10 calles)', '2026-11-28'::date, null, null, 'escuela-natacion', null, 'Categorías: Absoluto, Junior, Infantil · Horario: 17:00 (calentamiento 15:30)', 0, false
where not exists (select 1 from competiciones where nombre='Fase Territorial Larga Distancia' and sede='Castellón · Piscina Olímpica (25 m / 10 calles)' and fecha_inicio='2026-11-28'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '2ª Jornada Liga Benjamín · 1ª Prebenjamín', 'Alicante · Monte Tossal', '2026-12-12'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1837_LIGA%20BENJAMIN%202__Jornada%20Tossal%20_1_.pdf', 'Categorías: Prebenjamín, Benjamín · Horario: 10:00', 0, false
where not exists (select 1 from competiciones where nombre='2ª Jornada Liga Benjamín · 1ª Prebenjamín' and sede='Alicante · Monte Tossal' and fecha_inicio='2026-12-12'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '2ª Jornada Liga Alevín', 'Petrer · Piscina Municipal', '2026-12-12'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1840_LIGAALEVIN%202__%20Jornada%20Petrer%20_2_.pdf', 'Categorías: Alevín · Horario: 16:00', 0, false
where not exists (select 1 from competiciones where nombre='2ª Jornada Liga Alevín' and sede='Petrer · Piscina Municipal' and fecha_inicio='2026-12-12'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '2ª Jornada Liga Benjamín · 1ª Prebenjamín', 'Petrer · Piscina Municipal', '2026-12-13'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1836_LIGA%20BENJAMIN%202__Jornada%20Petrer%20_1_.pdf', 'Categorías: Prebenjamín, Benjamín · Horario: 10:00', 0, false
where not exists (select 1 from competiciones where nombre='2ª Jornada Liga Benjamín · 1ª Prebenjamín' and sede='Petrer · Piscina Municipal' and fecha_inicio='2026-12-13'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '3ª Jornada Liga Infantil y Mayores', 'Pilar de la Horadada · Piscina Municipal', '2026-12-19'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1817_LIGAINFYMAYORES3__%20jORNADA%20PILAR%20DE%20LA%20Horadada%20_3_.pdf', 'Categorías: Infantil, Junior, Absoluto · Horario: 10:00 y 16:00', 0, false
where not exists (select 1 from competiciones where nombre='3ª Jornada Liga Infantil y Mayores' and sede='Pilar de la Horadada · Piscina Municipal' and fecha_inicio='2026-12-19'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select 'Fase Provincial Alevín · Jocs Esportius', 'Sede por definir', '2027-01-16'::date, '2027-01-17', null, 'escuela-natacion', null, 'Categorías: Alevín', 0, false
where not exists (select 1 from competiciones where nombre='Fase Provincial Alevín · Jocs Esportius' and sede='Sede por definir' and fecha_inicio='2027-01-16'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select 'Campeonato Autonómico Junior y Absoluto de Invierno 2027', 'Sede por definir', '2027-02-06'::date, '2027-02-07', null, 'escuela-natacion', null, 'Categorías: Absoluto, Junior, Infantil', 0, false
where not exists (select 1 from competiciones where nombre='Campeonato Autonómico Junior y Absoluto de Invierno 2027' and sede='Sede por definir' and fecha_inicio='2027-02-06'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '3ª Jornada Liga Benjamín', 'San Vicente · Piscina Municipal', '2027-02-13'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1854_LIGA%20BENJAMIN%203__Jornada%20San%20Vicente%20_1_.pdf', 'Categorías: Benjamín · Horario: 10:00', 0, false
where not exists (select 1 from competiciones where nombre='3ª Jornada Liga Benjamín' and sede='San Vicente · Piscina Municipal' and fecha_inicio='2027-02-13'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '3ª Jornada Liga Alevín', 'Petrer · Piscina Municipal', '2027-02-13'::date, '2027-02-14', null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1855_LIGAALEVIN%203__%20Jornada%20Petrer%20_2_.pdf', 'Categorías: Alevín · Horario: 16:00 y 10:00', 0, false
where not exists (select 1 from competiciones where nombre='3ª Jornada Liga Alevín' and sede='Petrer · Piscina Municipal' and fecha_inicio='2027-02-13'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select 'Campeonato Autonómico Infantil de Invierno 2027', 'Sede por definir', '2027-02-20'::date, '2027-02-21', null, 'escuela-natacion', null, 'Categorías: Infantil', 0, false
where not exists (select 1 from competiciones where nombre='Campeonato Autonómico Infantil de Invierno 2027' and sede='Sede por definir' and fecha_inicio='2027-02-20'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '4ª Jornada Liga Benjamín · 2ª Prebenjamín', 'San Vicente · Piscina Municipal', '2027-03-06'::date, '2027-03-07', null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1860_LIGA%20BENJAMIN%204__Jornada%20San%20Vicente%20_1_.pdf', 'Categorías: Prebenjamín, Benjamín · Horario: 10:00', 0, false
where not exists (select 1 from competiciones where nombre='4ª Jornada Liga Benjamín · 2ª Prebenjamín' and sede='San Vicente · Piscina Municipal' and fecha_inicio='2027-03-06'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '4ª Jornada Liga Alevín', 'Petrer · Piscina Municipal', '2027-03-06'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1864_LIGAALEVIN%204__%20Jornada%20Petrer%20_3_.pdf', 'Categorías: Alevín · Horario: 16:00', 0, false
where not exists (select 1 from competiciones where nombre='4ª Jornada Liga Alevín' and sede='Petrer · Piscina Municipal' and fecha_inicio='2027-03-06'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '4ª Jornada Liga Benjamín · 2ª Prebenjamín', 'Sax · Piscina Municipal', '2027-03-06'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1917_LIGA%20BENJAMIN%204__Jornada%20Sax%20_1_.pdf', 'Categorías: Prebenjamín, Benjamín · Horario: 10:00', 0, false
where not exists (select 1 from competiciones where nombre='4ª Jornada Liga Benjamín · 2ª Prebenjamín' and sede='Sax · Piscina Municipal' and fecha_inicio='2027-03-06'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '4ª Jornada Liga Infantil y Mayores', 'Torrevieja · Piscina Municipal', '2027-04-03'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1872_LIGAINFYMAYORES4__%20jORNADA%20Torrevieja%20_1_.pdf', 'Categorías: Infantil, Junior, Absoluto · Horario: 10:00 y 16:00', 0, false
where not exists (select 1 from competiciones where nombre='4ª Jornada Liga Infantil y Mayores' and sede='Torrevieja · Piscina Municipal' and fecha_inicio='2027-04-03'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '4ª Jornada Liga Infantil y Mayores', 'Petrer · Piscina Municipal', '2027-04-03'::date, '2027-04-04', null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1873_LIGAINFYMAYORES4__%20jORNADA%20Petrer%20_1_.pdf', 'Categorías: Infantil, Junior, Absoluto · Horario: 16:00 y 10:00', 0, false
where not exists (select 1 from competiciones where nombre='4ª Jornada Liga Infantil y Mayores' and sede='Petrer · Piscina Municipal' and fecha_inicio='2027-04-03'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '5ª Jornada Liga Alevín', 'Pilar de la Horadada · Piscina Municipal', '2027-04-17'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1874_LIGAALEVIN%205__%20Jornada%20Pilar%20de%20la%20Horadada%20_2_.pdf', 'Categorías: Alevín · Horario: 10:00', 0, false
where not exists (select 1 from competiciones where nombre='5ª Jornada Liga Alevín' and sede='Pilar de la Horadada · Piscina Municipal' and fecha_inicio='2027-04-17'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '5ª Jornada Liga Benjamín', 'Petrer · Piscina Municipal', '2027-04-17'::date, null, null, 'escuela-natacion', null, 'Categorías: Benjamín · Horario: 16:00', 0, false
where not exists (select 1 from competiciones where nombre='5ª Jornada Liga Benjamín' and sede='Petrer · Piscina Municipal' and fecha_inicio='2027-04-17'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '6ª Jornada Liga Benjamín · 3ª Prebenjamín', 'Alicante · Monte Tossal', '2027-05-15'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1888_LIGA%20BENJAMIN%206__Jornada%20Tossal%20_1_.pdf', 'Categorías: Prebenjamín, Benjamín · Horario: 10:00', 0, false
where not exists (select 1 from competiciones where nombre='6ª Jornada Liga Benjamín · 3ª Prebenjamín' and sede='Alicante · Monte Tossal' and fecha_inicio='2027-05-15'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '6ª Jornada Liga Benjamín · 3ª Prebenjamín', 'San Vicente · Piscina Municipal', '2027-05-15'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1889_LIGA%20BENJAMIN%206__Jornada%20San%20Vicente%20_1_.pdf', 'Categorías: Prebenjamín, Benjamín · Horario: 10:00', 0, false
where not exists (select 1 from competiciones where nombre='6ª Jornada Liga Benjamín · 3ª Prebenjamín' and sede='San Vicente · Piscina Municipal' and fecha_inicio='2027-05-15'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '6ª Jornada Liga Alevín', 'Ondara · Piscina Municipal', '2027-05-15'::date, '2027-05-16', null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1895_LIGAALEVIN%206__%20Jornada%20Ondara%20_2_.pdf', 'Categorías: Alevín · Horario: 16:00 y 10:00', 0, false
where not exists (select 1 from competiciones where nombre='6ª Jornada Liga Alevín' and sede='Ondara · Piscina Municipal' and fecha_inicio='2027-05-15'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '5ª Jornada Liga Infantil y Mayores', 'Torrevieja · Piscina Municipal', '2027-05-22'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1882_LIGAINFYMAYORES5__%20jORNADA%20Torrevieja%20_3_.pdf', 'Categorías: Infantil, Junior, Absoluto · Horario: 10:00 y 16:00', 0, false
where not exists (select 1 from competiciones where nombre='5ª Jornada Liga Infantil y Mayores' and sede='Torrevieja · Piscina Municipal' and fecha_inicio='2027-05-22'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select '5ª Jornada Liga Infantil y Mayores', 'San Vicente · Piscina Municipal', '2027-05-22'::date, null, null, 'escuela-natacion', 'https://www.fncv.es/archivos//natacion/competiciones/normativas/cas/1883_LIGAINFYMAYORES26_27-%205jornada%20SAN%20vICENTE%20_2_.pdf', 'Categorías: Infantil, Junior, Absoluto · Horario: 10:00 y 17:00', 0, false
where not exists (select 1 from competiciones where nombre='5ª Jornada Liga Infantil y Mayores' and sede='San Vicente · Piscina Municipal' and fecha_inicio='2027-05-22'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select 'Control Libre Alevín Verano', 'Torrevieja · Piscina Municipal', '2027-05-29'::date, '2027-05-30', null, 'escuela-natacion', null, 'Categorías: Alevín · Horario: 10:00 y 16:00', 0, false
where not exists (select 1 from competiciones where nombre='Control Libre Alevín Verano' and sede='Torrevieja · Piscina Municipal' and fecha_inicio='2027-05-29'::date and ambito='escuela-natacion');
insert into competiciones (nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, circular_url, notas, coste, inscripcion_abierta)
select 'Final Relevos Prebenjamín y Benjamín', 'San Vicente · Piscina Municipal', '2027-06-12'::date, null, null, 'escuela-natacion', null, 'Categorías: Prebenjamín, Benjamín · Horario: 10:30', 0, false
where not exists (select 1 from competiciones where nombre='Final Relevos Prebenjamín y Benjamín' and sede='San Vicente · Piscina Municipal' and fecha_inicio='2027-06-12'::date and ambito='escuela-natacion');
select count(*) as competiciones_escuela_natacion from competiciones where ambito='escuela-natacion';
commit;
