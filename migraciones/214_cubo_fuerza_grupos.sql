-- 214 · Grupos y horarios de la PRUEBA GRATIS de fuerza del Cubo (octubre)
-- Tres turnos gratuitos (viernes, sábado, domingo). Se crean como grupos del
-- Cubo (precio 0, aforo 20) con su horario semanal en grupo_horarios, para que
-- salgan en el portal del cubo-atleta y en el calendario. Idempotente.
insert into public.grupos (nombre, seccion, horario, turno, plazas, activo, descripcion) values
 ('El Cubo · Fuerza gratis · Viernes 18:30', 'cubo', 'Viernes · 18:30–19:30', null, 20, true, 'Entrenamiento de fuerza en grupo, gratuito (prueba de octubre), dirigido por entrenador.'),
 ('El Cubo · Fuerza gratis · Sábado 9:00',   'cubo', 'Sábado · 9:00–10:30',   null, 20, true, 'Entrenamiento de fuerza en grupo, gratuito (prueba de octubre), dirigido por entrenador.'),
 ('El Cubo · Fuerza gratis · Domingo 9:00',  'cubo', 'Domingo · 9:00–10:30',  null, 20, true, 'Entrenamiento de fuerza en grupo, gratuito (prueba de octubre), dirigido por entrenador.')
on conflict do nothing;

-- Horario semanal de cada grupo (día: lunes=1 … viernes=5, sábado=6, domingo=7).
insert into public.grupo_horarios (grupo_id, dia_semana, hora_inicio, hora_fin, lugar, origen, activo, apagado_a_mano)
select g.id, v.dia, v.ini::time, v.fin::time, 'El Cubo (fuerza)', 'texto', true, false
from (values
  ('El Cubo · Fuerza gratis · Viernes 18:30', 5, '18:30', '19:30'),
  ('El Cubo · Fuerza gratis · Sábado 9:00',   6, '09:00', '10:30'),
  ('El Cubo · Fuerza gratis · Domingo 9:00',  7, '09:00', '10:30')
) as v(nombre, dia, ini, fin)
join public.grupos g on g.nombre = v.nombre
where not exists (
  select 1 from public.grupo_horarios gh where gh.grupo_id = g.id and gh.dia_semana = v.dia
);
