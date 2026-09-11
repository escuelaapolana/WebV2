-- 178 · Grupos de El Cubo (por turno) con sus horarios
-- ------------------------------------------------------------
-- Tres grupos fijos, uno por turno, cada uno con sus dos días. El alta
-- del Cubo asigna al socio al grupo de su turno. Idempotente: solo se
-- crean si aún no hay ningún grupo de sección «cubo».
-- ============================================================

begin;

do $$
begin
  if not exists (select 1 from public.grupos where seccion = 'cubo') then
    with g as (
      insert into public.grupos (nombre, seccion, horario, turno, plazas, activo, pide_bienestar)
      values
       ('El Cubo · L y X 17:30','cubo','Lunes y miércoles · 17:30–18:30','lunes-miercoles',12,true,false),
       ('El Cubo · M y J 17:30','cubo','Martes y jueves · 17:30–18:30','martes-jueves',12,true,false),
       ('El Cubo · L y X 18:45','cubo','Lunes y miércoles · 18:45–19:45','lunes-miercoles',12,true,false)
      returning id, nombre
    )
    insert into public.grupo_horarios (grupo_id, dia_semana, hora_inicio, hora_fin, lugar, activo)
    select g.id, v.dia, v.ini::time, v.fin::time, 'El Cubo', true
    from g join (values
      ('El Cubo · L y X 17:30',1,'17:30','18:30'),('El Cubo · L y X 17:30',3,'17:30','18:30'),
      ('El Cubo · M y J 17:30',2,'17:30','18:30'),('El Cubo · M y J 17:30',4,'17:30','18:30'),
      ('El Cubo · L y X 18:45',1,'18:45','19:45'),('El Cubo · L y X 18:45',3,'18:45','19:45')
    ) as v(nombre,dia,ini,fin) on v.nombre = g.nombre;
  end if;
end $$;

commit;
