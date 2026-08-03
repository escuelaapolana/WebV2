-- ============================================================
-- 093 · EL AÑO DE NACIMIENTO DE CADA GRUPO DE LA ESCUELA
-- ------------------------------------------------------------
-- POR QUÉ HACE FALTA
--
-- La escuela se reparte por edad, y en atletismo la edad se cuenta por
-- AÑO DE NACIMIENTO, no por años cumplidos. Dos niños del mismo año
-- entrenan juntos toda la temporada aunque se lleven once meses: el que
-- nació en enero y el que nació en diciembre. Cumplir años a mitad de
-- curso NO cambia a nadie de grupo, y esa es justo la gracia.
--
-- Por eso aquí se guarda el año tal cual —«Rojo 1 · 2023»— y no una
-- edad que el sistema tendría que calcular. Calcular la edad obligaría
-- a decidir con qué fecha se corta (hoy, 31 de diciembre, el día que
-- empieza la temporada), que es la discusión que se tiene todos los
-- septiembres con las familias. Guardando el año, esa pregunta
-- desaparece: no hay nada que calcular ni nada que discutir.
--
-- EL PRECIO DE ESTO es que en cada temporada nueva hay que subir todos
-- los años una posición. El club lo asume, pero no tiene por qué
-- hacerlo grupo a grupo: para eso está la función del final, que sube
-- de golpe los nueve y deja que después se retoque lo que haga falta.
--
-- DOS AÑOS, NO UNO. Normalmente cada color es un solo año (desde = hasta),
-- pero si un año vienen pocos niños el club junta dos edades en un
-- grupo. Con dos columnas eso se dice sin inventar nada.
--
-- VACÍO ES VÁLIDO. Los grupos de mayores (pista, running, natación) no
-- van por año de nacimiento: se quedan con los dos campos vacíos y la
-- web no enseña nada. Igual que el grupo de competición de primera
-- hora, que se forma eligiendo niños de varias edades.
--
-- SEGURIDAD: no hay que tocar permisos. `grupos` ya tiene lectura
-- pública (son los horarios que se enseñan sin cuenta) y escritura solo
-- de administración; una columna nueva hereda las políticas. La función
-- del final sí se cierra a mano, porque las funciones nacen abiertas
-- (migración 090) y esta cambia datos de todo el club.
--
-- Idempotente: se puede volver a pasar sin romper nada.
-- ============================================================


-- ------------------------------------------------------------
-- 1 · LAS DOS COLUMNAS
-- ------------------------------------------------------------
alter table public.grupos
  add column if not exists nacidos_desde smallint,
  add column if not exists nacidos_hasta smallint;

comment on column public.grupos.nacidos_desde is
  'Año de nacimiento de los niños del grupo (el más antiguo, si son dos años). Vacío en los grupos que no van por edad.';
comment on column public.grupos.nacidos_hasta is
  'Año de nacimiento más reciente del grupo. Si el grupo es de un solo año, es el mismo que nacidos_desde.';

-- Un año de verdad y en orden. El tope de arriba se deja generoso a
-- propósito: no es tarea de la base decidir hasta cuándo existe el club.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'grupos_anos_coherentes') then
    alter table public.grupos
      add constraint grupos_anos_coherentes check (
        (nacidos_desde is null or (nacidos_desde between 1900 and 2200)) and
        (nacidos_hasta is null or (nacidos_hasta between 1900 and 2200)) and
        (nacidos_desde is null or nacidos_hasta is null or nacidos_hasta >= nacidos_desde)
      );
  end if;
end $$;


-- ------------------------------------------------------------
-- 2 · EMPEZAR TEMPORADA: SUBIR TODOS LOS AÑOS DE UNA VEZ
-- ------------------------------------------------------------
-- En septiembre, «Rojo 1» deja de ser el de 2023 y pasa a ser el de
-- 2024; «Rojo 2», el de 2023; y así los nueve. Es siempre el mismo
-- gesto y siempre para todos, así que hacerlo grupo a grupo solo sirve
-- para equivocarse en uno.
--
-- Esta función suma un año (o los que se le digan) a todos los grupos
-- de una sección que tengan año puesto. Devuelve cuántos ha cambiado,
-- para poder decírselo a quien lo pulse. Después se retoca a mano lo
-- que haga falta: si un año no hay niños de una edad, ese grupo se
-- apaga; si se desborda, se duplica.
--
-- NO SE LLAMA AQUÍ. Esta migración solo la deja escrita. Quien la
-- ejecuta es una persona del club desde el panel, cuando decide que
-- empieza la temporada.
create or replace function public.grupos_avanza_temporada(
  p_seccion text default 'escuela',
  p_anos    integer default 1
)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_tocados integer;
begin
  -- Cambia los años de nacimiento de todo un club: solo administración.
  if not public.es_admin() then
    raise exception 'Solo la administración del club puede empezar temporada nueva.';
  end if;

  -- Un salto de más de unos pocos años es siempre un dedazo, y deshacerlo
  -- a mano son dieciocho campos. Mejor que no llegue a pasar.
  if p_anos is null or p_anos = 0 or abs(p_anos) > 5 then
    raise exception 'El salto de temporada tiene que ser de entre -5 y 5 años, y no cero.';
  end if;

  update public.grupos
     set nacidos_desde = nacidos_desde + p_anos,
         nacidos_hasta = nacidos_hasta + p_anos
   where seccion = p_seccion
     and (nacidos_desde is not null or nacidos_hasta is not null);

  get diagnostics v_tocados = row_count;
  return v_tocados;
end;
$function$;

comment on function public.grupos_avanza_temporada(text, integer) is
  'Sube un año (o los que se le digan) el año de nacimiento de todos los grupos de una sección. Es el gesto de «empezar temporada nueva» de la escuela. Solo administración.';

-- Las funciones nacen ejecutables por cualquiera (migración 090): se
-- cierra a quien no ha entrado y se abre solo a quien tiene cuenta, que
-- por dentro además tiene que ser administración.
revoke all     on function public.grupos_avanza_temporada(text, integer) from public;
revoke all     on function public.grupos_avanza_temporada(text, integer) from anon;
grant  execute on function public.grupos_avanza_temporada(text, integer) to authenticated;
