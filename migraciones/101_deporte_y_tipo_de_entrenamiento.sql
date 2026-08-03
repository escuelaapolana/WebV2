-- ============================================================
-- 101 · El deporte por un lado y el tipo de entrenamiento por otro
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- `sesiones.tipo` guarda hoy dos preguntas distintas en la misma
-- casilla: DÓNDE se entrena (pista, natacion, gym, continuo) y QUÉ
-- papel juega ese día (activacion, competicion, descanso).
--
-- CÓMO SE NOTA
-- «Activación» aparece en los dos sitios: es un valor de `tipo` y
-- también un valor de `rol`. Cuando el mismo nombre está en dos
-- listas, es que las listas no son la misma cosa. Y el entrenador
-- lo dijo con sus palabras: si un día hace pesas y luego sale a
-- hacer series, hoy tiene que elegir una de las dos y mentir.
--
-- LOS DOS EJES QUE QUEDAN
--
--   1 · DEPORTE — a qué vas hoy.
--       atletismo · natacion · fuerza · cubo
--
--       · «atletismo» se come la pista Y la carrera continua. El
--         club lo confirmó: la carrera continua se hace en el
--         atletismo, y en la pista también. La diferencia entre
--         una y otra sigue viva en el `tipo` de siempre (ver más
--         abajo), que es de donde salen los formatos de descanso.
--       · «fuerza» NO se llama «gimnasio», y es a propósito: si
--         pone gimnasio, alguien piensa «yo no tengo gimnasio,
--         ¿dónde lo hago?». Se nombra por lo que se entrena, no
--         por dónde se entrena; con unas mancuernas en casa
--         también es fuerza.
--       · «cubo» va aparte de «fuerza» aunque las dos huelan a
--         sala: El Cubo es una clase con horario y plaza a la que
--         uno se apunta, no un entrenamiento que manda el
--         entrenador.
--
--       Y se pueden marcar DOS deportes, porque hay días que son
--       dos de verdad: gimnasio y después series, como
--       transferencia, sin irse a casa en medio. Por eso hay un
--       deporte principal y un segundo opcional. El atleta tiene
--       que ver los dos o se presenta sin las zapatillas de
--       clavos, y en su historial ese día cuenta para los dos.
--
--       REGLA QUE CONVIENE DEJAR ESCRITA: el deporte es de la
--       sesión entera, no de cada ejercicio. Si en El Cubo
--       calientan corriendo, sigue siendo El Cubo. La pregunta que
--       responde este campo es «¿a qué vas hoy?», no «¿qué
--       ejercicios haces?».
--
--   2 · TIPO DE ENTRENAMIENTO — qué papel juega el día. Es uno
--       solo, el del trabajo principal, aunque haya dos deportes.
--
--       Comunes a todo:  normal · activacion · descarga ·
--                        rehabilitador · descanso · competicion
--       Solo atletismo:  calidad · ultimo_toque
--       Solo fuerza:     fuerza_maxima · potencia · pliometria ·
--                        hipertrofia · resistencia_fuerza ·
--                        movilidad · core_preventivo
--       Solo natación:   tecnica · velocidad · umbral · aerobico ·
--                        recuperacion · puesta_a_punto
--
--       «rehabilitador» lo pidió el club: quien vuelve de lesión
--       no está haciendo un entrenamiento normal flojito, está
--       haciendo otra cosa, y su historial tiene que decirlo.
--
--       «puesta_a_punto» (natación) y «ultimo_toque» (atletismo)
--       NO son lo mismo y por eso son dos valores: el último toque
--       es el día de antes; la puesta a punto son una o dos
--       semanas bajando volumen.
--
-- POR QUÉ EL CHECK ADMITE TODA LA LISTA Y NO SOLO LA DEL DEPORTE
-- Ofrecerle «último toque» a una sesión de pesas no tiene sentido,
-- y por eso el desplegable de la pantalla se adapta al deporte.
-- Pero la base no puede ser tan estricta, por un motivo muy
-- concreto: hay 39 entrenamientos de NATACIÓN guardados con
-- `rol = calidad_fuerte`, o sea, días fuertes de agua. «Calidad»
-- es de atletismo en la lista nueva, y no hay forma de saber si
-- aquel día fue velocidad, umbral o técnica. Inventarlo sería
-- falsear el historial; tirarlo sería perder la única información
-- que hay (que fue un día duro). Así que se conserva tal cual y
-- es la pantalla, no la base, la que decide qué ofrecer.
--
-- POR QUÉ NO SE BORRA `tipo` NI `rol`
-- Hay 361 entrenamientos guardados y ocho pantallas que leen esos
-- dos campos: las calles de la piscina, la carga y el bienestar,
-- el calendario del club, el portal del atleta, el de la familia,
-- el generador automático de entrenamientos y el importador de
-- texto del entrenador. Cambiarles el valor de debajo las rompe
-- todas a la vez.
--
-- Así que los campos viejos se quedan, con su valor de siempre, y
-- los nuevos se ponen al lado. Un disparador mantiene las dos
-- parejas de acuerdo en las dos direcciones:
--
--   · quien escriba a la antigua (el generador automático, la
--     pantalla de calles, el importador) rellena `tipo` y `rol`, y
--     el disparador deduce `deporte` y `tipo_entrenamiento`;
--   · quien escriba a la nueva (el planificador) rellena los ejes,
--     y el disparador deduce `tipo` y `rol` para que las pantallas
--     viejas sigan viendo lo que esperan.
--
-- Nadie se queda sin dato y nada se pierde por el camino.
--
-- IDEMPOTENTE
-- Se puede lanzar tantas veces como haga falta: las columnas se
-- crean si no están, las restricciones se rehacen, y el relleno de
-- los 361 solo toca las filas que aún no tienen los ejes puestos.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · Las dos columnas nuevas (más el segundo deporte)
-- ------------------------------------------------------------
alter table public.sesiones add column if not exists deporte            text;
alter table public.sesiones add column if not exists deporte_2          text;
alter table public.sesiones add column if not exists tipo_entrenamiento text;

comment on column public.sesiones.deporte is
  'A qué va el atleta ese día: atletismo (pista y carrera continua), natacion, '
  'fuerza (no se dice «gimnasio»: se puede hacer en casa) o cubo. Es de la '
  'sesión entera, no de cada ejercicio.';
comment on column public.sesiones.deporte_2 is
  'Segundo deporte del mismo día, opcional, para las sesiones que de verdad son '
  'dos (fuerza y después series, como transferencia). El atleta necesita ver los '
  'dos y en su historial el día cuenta para los dos.';
comment on column public.sesiones.tipo_entrenamiento is
  'Qué papel juega el día: normal, activacion, calidad, descarga, rehabilitador, '
  'descanso, competicion… Uno solo, el del trabajo principal, aunque haya dos '
  'deportes. La pantalla ofrece solo los que encajan con el deporte elegido.';

-- ------------------------------------------------------------
-- 2 · Rellenar los 361 que ya están guardados
--     Solo se tocan las filas que todavía no tienen los ejes: así
--     una segunda pasada no pisa nada que alguien haya corregido
--     a mano después.
-- ------------------------------------------------------------

-- 2.a · EL DEPORTE
--   pista y continuo → atletismo   ·   natacion → natacion
--   gym → fuerza
--   Los tres que no dicen deporte (activacion, competicion,
--   descanso) se deducen por la sección del grupo, que es el dato
--   más fiable que hay: un grupo de la sección natación entrena en
--   el agua. Si la sección tampoco lo aclara se deja en atletismo,
--   que es el caso corriente del club, y queda apuntado en el
--   inventario de abajo para poder repasarlo a ojo.
update public.sesiones s
   set deporte = case
         when s.tipo in ('pista', 'continuo') then 'atletismo'
         when s.tipo = 'natacion'             then 'natacion'
         when s.tipo = 'gym'                  then 'fuerza'
         else (select case
                        when g.seccion in ('natacion', 'escuela-natacion') then 'natacion'
                        when g.seccion = 'cubo'                            then 'cubo'
                        else 'atletismo'
                      end
                 from public.grupos g where g.id = s.grupo_id)
       end
 where s.deporte is null;

-- Los que se quedaron sin grupo del que tirar: atletismo, que es
-- lo que más hay, y dicho aquí para que no parezca deducido.
update public.sesiones set deporte = 'atletismo'
 where deporte is null;

-- 2.b · EL TIPO DE ENTRENAMIENTO
--   Cuando el `tipo` viejo ya decía el papel del día (activacion,
--   competicion, descanso), ese manda: es lo que el entrenador
--   escribió. Si no, se traduce el `rol`, que es exactamente este
--   mismo eje con otros nombres. Y si no hay ni una cosa ni otra
--   (28 entrenamientos sin rol), queda «normal», que es lo que
--   significa no haber dicho nada.
update public.sesiones s
   set tipo_entrenamiento = case
         when s.tipo = 'descanso'         then 'descanso'
         when s.tipo = 'competicion'      then 'competicion'
         when s.tipo = 'activacion'       then 'activacion'
         when s.rol  = 'calidad_fuerte'   then 'calidad'
         when s.rol  = 'secundaria'       then 'normal'
         when s.rol  = 'activacion'       then 'activacion'
         when s.rol  = 'ultimo_toque_48h' then 'ultimo_toque'
         when s.rol  = 'descarga'         then 'descarga'
         when s.rol  = 'competicion'      then 'competicion'
         else 'normal'
       end
 where s.tipo_entrenamiento is null;

-- ------------------------------------------------------------
-- 3 · Las restricciones
-- ------------------------------------------------------------
alter table public.sesiones drop constraint if exists sesiones_deporte_check;
alter table public.sesiones add  constraint sesiones_deporte_check
  check (deporte is null or deporte in ('atletismo', 'natacion', 'fuerza', 'cubo'));

alter table public.sesiones drop constraint if exists sesiones_deporte_2_check;
alter table public.sesiones add  constraint sesiones_deporte_2_check
  check (deporte_2 is null or deporte_2 in ('atletismo', 'natacion', 'fuerza', 'cubo'));

-- Un día no puede ser «atletismo y atletismo», y no puede haber
-- segundo deporte sin primero: sería un día sin deporte principal.
alter table public.sesiones drop constraint if exists sesiones_dos_deportes_distintos;
alter table public.sesiones add  constraint sesiones_dos_deportes_distintos
  check (deporte_2 is null or (deporte is not null and deporte_2 <> deporte));

alter table public.sesiones drop constraint if exists sesiones_tipo_entrenamiento_check;
alter table public.sesiones add  constraint sesiones_tipo_entrenamiento_check
  check (tipo_entrenamiento is null or tipo_entrenamiento in (
    -- comunes a todos los deportes
    'normal', 'activacion', 'descarga', 'rehabilitador', 'descanso', 'competicion',
    -- atletismo
    'calidad', 'ultimo_toque',
    -- fuerza
    'fuerza_maxima', 'potencia', 'pliometria', 'hipertrofia',
    'resistencia_fuerza', 'movilidad', 'core_preventivo',
    -- natación
    'tecnica', 'velocidad', 'umbral', 'aerobico', 'recuperacion', 'puesta_a_punto'
  ));

-- El `rol` viejo se queda con su lista de siempre, y además se le
-- deja sitio al vocabulario nuevo. No es que vayamos a escribirlo
-- ahí —el disparador traduce al vocabulario viejo—, es que si otra
-- pantalla lo hace por su cuenta, es mejor que se guarde a que
-- reviente al guardar un entrenamiento.
alter table public.sesiones drop constraint if exists sesiones_rol_check;
alter table public.sesiones add  constraint sesiones_rol_check
  check (rol is null or rol in (
    'calidad_fuerte', 'secundaria', 'activacion', 'ultimo_toque_48h', 'descarga', 'competicion',
    'normal', 'rehabilitador', 'descanso', 'calidad', 'ultimo_toque',
    'fuerza_maxima', 'potencia', 'pliometria', 'hipertrofia',
    'resistencia_fuerza', 'movilidad', 'core_preventivo',
    'tecnica', 'velocidad', 'umbral', 'aerobico', 'recuperacion', 'puesta_a_punto'
  ));

-- ------------------------------------------------------------
-- 4 · El disparador que mantiene las dos parejas de acuerdo
--     Mientras queden pantallas escribiendo a la antigua y
--     pantallas escribiendo a la nueva, la traducción tiene que
--     estar en un único sitio, y ese sitio es la base: si se
--     escribe en cada pantalla, se escribe distinta en cada una.
-- ------------------------------------------------------------
create or replace function public.apo_sesiones_dos_ejes()
returns trigger
language plpgsql
as $$
declare
  v_seccion text;
begin
  select g.seccion into v_seccion from public.grupos g where g.id = new.grupo_id;

  -- --- de lo viejo a lo nuevo ---
  if new.deporte is null and new.tipo is not null then
    new.deporte := case
      when new.tipo in ('pista', 'continuo') then 'atletismo'
      when new.tipo = 'natacion'             then 'natacion'
      when new.tipo = 'gym'                  then 'fuerza'
      when v_seccion in ('natacion', 'escuela-natacion') then 'natacion'
      when v_seccion = 'cubo'                            then 'cubo'
      else 'atletismo'
    end;
  end if;

  if new.tipo_entrenamiento is null then
    new.tipo_entrenamiento := case
      when new.tipo = 'descanso'         then 'descanso'
      when new.tipo = 'competicion'      then 'competicion'
      when new.tipo = 'activacion'       then 'activacion'
      when new.rol  = 'calidad_fuerte'   then 'calidad'
      when new.rol  = 'secundaria'       then 'normal'
      when new.rol  = 'activacion'       then 'activacion'
      when new.rol  = 'ultimo_toque_48h' then 'ultimo_toque'
      when new.rol  = 'descarga'         then 'descarga'
      when new.rol  = 'competicion'      then 'competicion'
      when new.tipo is not null          then 'normal'
      else null
    end;
  end if;

  -- --- de lo nuevo a lo viejo ---
  -- El `tipo` viejo mezclaba deporte y papel del día, así que se
  -- reconstruye igual de mezclado: primero el papel cuando el
  -- papel era lo que se guardaba, y si no, el deporte.
  -- En atletismo se distingue pista de continuo por la sección del
  -- grupo, porque de ahí salen los formatos de recuperación: un
  -- continuo de montaña se escribe por desnivel, no por series.
  if new.tipo is null and new.deporte is not null then
    new.tipo := case
      when new.deporte = 'natacion' then 'natacion'
      when new.deporte in ('fuerza', 'cubo') then 'gym'
      when new.tipo_entrenamiento in ('descanso', 'competicion', 'activacion')
           then new.tipo_entrenamiento
      when v_seccion in ('running', 'montana', 'triatlon') then 'continuo'
      else 'pista'
    end;
  end if;

  if new.rol is null and new.tipo_entrenamiento is not null then
    new.rol := case new.tipo_entrenamiento
      when 'calidad'      then 'calidad_fuerte'
      when 'normal'       then 'secundaria'
      when 'activacion'   then 'activacion'
      when 'ultimo_toque' then 'ultimo_toque_48h'
      when 'descarga'     then 'descarga'
      when 'competicion'  then 'competicion'
      else null      -- rehabilitador y los propios de cada deporte no tienen
                     -- equivalente viejo: mejor vacío que traducido a mentira
    end;
  end if;

  return new;
end;
$$;

comment on function public.apo_sesiones_dos_ejes() is
  'Mantiene de acuerdo el par viejo (tipo, rol) y el nuevo (deporte, '
  'tipo_entrenamiento) mientras convivan pantallas que escriben de las dos '
  'maneras. Solo rellena huecos: nunca pisa un valor que ya venga puesto.';

drop trigger if exists trg_sesiones_dos_ejes on public.sesiones;
create trigger trg_sesiones_dos_ejes
  before insert or update on public.sesiones
  for each row execute function public.apo_sesiones_dos_ejes();

-- ------------------------------------------------------------
-- 5 · Un índice para lo que se va a preguntar de verdad
--     «Cuántos días de cada deporte llevo» es la pregunta del
--     historial del atleta, y se hace por deporte y fecha.
-- ------------------------------------------------------------
create index if not exists idx_sesiones_deporte_fecha
  on public.sesiones (deporte, fecha);

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- el reparto de los 361 por deporte
--   select deporte, count(*) from sesiones group by 1 order by 2 desc;
--
--   -- el reparto por tipo de entrenamiento
--   select tipo_entrenamiento, count(*) from sesiones group by 1 order by 2 desc;
--
--   -- ninguno debe quedar sin deporte ni sin tipo
--   select count(*) from sesiones where deporte is null or tipo_entrenamiento is null;
--
--   -- los que hubo que deducir por la sección del grupo, para
--   -- repasarlos a ojo cuando el club quiera
--   select s.fecha, g.nombre, s.tipo, s.titulo, s.deporte
--     from sesiones s left join grupos g on g.id = s.grupo_id
--    where s.tipo in ('activacion', 'competicion', 'descanso')
--    order by s.fecha;
-- ------------------------------------------------------------
