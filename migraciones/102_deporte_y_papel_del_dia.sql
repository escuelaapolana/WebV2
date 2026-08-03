-- ============================================================
-- 102 · El deporte por un lado y el papel del día por otro
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
--   2 · PAPEL DEL DÍA — qué pinta esa sesión en la temporada.
--       ajuste · carga · impacto · recuperacion · activacion ·
--       tapering · competicion · descanso · rehabilitador
--
--       Estos nombres NO son nuestros: son los que el dueño del
--       club ya escribe en su planificación anual. «Ajuste,
--       carga, impacto, recuperación o activación —si es al
--       principio del mesociclo o el microciclo— y tapering.» Se
--       usan tal cual, porque una lista que el entrenador ya tiene
--       en la cabeza no hay que enseñársela.
--
--       Los tres últimos los añadimos nosotros porque son días que
--       existen y no encajaban en ninguno: la competición, el día
--       libre y el de quien vuelve de una lesión. «Rehabilitador»
--       lo pidió el club expresamente: quien vuelve de lesión no
--       está haciendo un entrenamiento normal flojito, está
--       haciendo otra cosa, y su historial tiene que decirlo.
--
--       Es UNA sola lista para los cuatro deportes, y esa es su
--       gracia: una sesión de pesas puede ser de carga o de
--       recuperación igual que una de natación puede ser de
--       impacto o de tapering. Aunque el día tenga dos deportes,
--       el papel es uno: el del trabajo principal.
--
-- LO QUE NO SE MONTA, Y POR QUÉ (que no haya que volver a buscarlo)
-- Hubo una lista más, de CONTENIDO por deporte, y se decidió no
-- montarla como campo. El motivo, del club y compartido: el papel
-- del día es justo lo que NO se deduce leyendo los ejercicios, y
-- por eso merece casilla propia; el contenido sí se deduce. Quien
-- escribe «sentadilla 4×5 al 85 %» ya está diciendo que es fuerza
-- máxima, y marcarlo otra vez en un desplegable es trabajo
-- repetido a las once de la noche de un martes.
--
-- Las listas quedan aquí escritas, SIN USAR A PROPÓSITO, por si
-- más adelante se quiere etiquetar el contenido para el análisis
-- de final de temporada:
--
--   FUERZA:   fuerza máxima · potencia · pliometría y multisaltos ·
--             hipertrofia · resistencia a la fuerza · movilidad ·
--             core y preventivo
--             («explosivo» y «potencia» son lo mismo en la
--             literatura y van juntos; «pliometría» va aparte
--             porque en velocidad es trabajo con entidad propia)
--   NATACIÓN: técnica · velocidad · umbral · aeróbico o fondo ·
--             recuperación · puesta a punto
--             (PROVISIONAL: sale de la literatura, no del club. El
--             club la va a revisar con el responsable de la
--             sección, así que dala por no confirmada)
--   ATLETISMO: sin lista. El club no la ha dado y no se inventa.
--   EL CUBO:   sin lista.
--
-- POR QUÉ NO SE BORRA `tipo` NI `rol`
-- Hay 361 entrenamientos guardados y ocho sitios que leen esos dos
-- campos: las calles de la piscina, la carga y el bienestar, el
-- calendario del club, el portal del atleta, el de la familia, el
-- generador automático de entrenamientos y el importador de texto
-- del entrenador. Cambiarles el valor de debajo los rompe todos a
-- la vez.
--
-- Así que los campos viejos se quedan, con su valor de siempre, y
-- los nuevos se ponen al lado. Un disparador mantiene las dos
-- parejas de acuerdo en las dos direcciones:
--
--   · quien escriba a la antigua (el generador automático, la
--     pantalla de calles, el importador) rellena `tipo` y `rol`, y
--     el disparador deduce `deporte` y `papel_dia`;
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
-- 1 · Las columnas nuevas
-- ------------------------------------------------------------
alter table public.sesiones add column if not exists deporte   text;
alter table public.sesiones add column if not exists deporte_2 text;
alter table public.sesiones add column if not exists papel_dia text;

comment on column public.sesiones.deporte is
  'A qué va el atleta ese día: atletismo (pista y carrera continua), natacion, '
  'fuerza (no se dice «gimnasio»: se puede hacer en casa) o cubo. Es de la '
  'sesión entera, no de cada ejercicio.';
comment on column public.sesiones.deporte_2 is
  'Segundo deporte del mismo día, opcional, para las sesiones que de verdad son '
  'dos (fuerza y después series, como transferencia). El atleta necesita ver los '
  'dos y en su historial el día cuenta para los dos.';
comment on column public.sesiones.papel_dia is
  'Qué pinta la sesión en la temporada, con los nombres que el club ya usa en su '
  'planificación anual: ajuste, carga, impacto, recuperacion, activacion, '
  'tapering, más competicion, descanso y rehabilitador. Uno solo por día, el del '
  'trabajo principal, y el mismo para los cuatro deportes.';

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
--   que es el caso corriente del club, y queda apuntado en la
--   consulta de repaso del final para poder mirarlo a ojo.
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

-- 2.b · EL PAPEL DEL DÍA
--   Cuando el `tipo` viejo ya decía el papel (activacion,
--   competicion, descanso), ese manda: es lo que el entrenador
--   escribió. Si no, se traduce el `rol`, que era este mismo eje
--   con otras palabras:
--
--     calidad_fuerte   → impacto      (la sesión clave de la semana)
--     secundaria       → carga        (el día de trabajo corriente)
--     descarga         → recuperacion (bajar para asimilar)
--     ultimo_toque_48h → tapering     (el club dice que en atletismo
--                                      a esto se le llama tapering)
--     activacion       → activacion
--     competicion      → competicion
--
--   Y si no hay ni `tipo` que lo diga ni `rol` (28 entrenamientos),
--   queda «carga», que es lo que significa un día de entrenamiento
--   sobre el que nadie dijo nada especial.
--
--   AVISO PARA EL CLUB: la pareja calidad_fuerte→impacto y
--   secundaria→carga es la lectura más razonable de las palabras
--   viejas, pero no la dictó nadie. Si el entrenador prefiere otra,
--   se corrige con un solo update sobre esta columna; no hace falta
--   volver a migrar nada.
update public.sesiones s
   set papel_dia = case
         when s.tipo = 'descanso'         then 'descanso'
         when s.tipo = 'competicion'      then 'competicion'
         when s.tipo = 'activacion'       then 'activacion'
         when s.rol  = 'calidad_fuerte'   then 'impacto'
         when s.rol  = 'secundaria'       then 'carga'
         when s.rol  = 'descarga'         then 'recuperacion'
         when s.rol  = 'ultimo_toque_48h' then 'tapering'
         when s.rol  = 'activacion'       then 'activacion'
         when s.rol  = 'competicion'      then 'competicion'
         else 'carga'
       end
 where s.papel_dia is null;

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

alter table public.sesiones drop constraint if exists sesiones_papel_dia_check;
alter table public.sesiones add  constraint sesiones_papel_dia_check
  check (papel_dia is null or papel_dia in (
    -- las seis del club, tal como las escribe en su planificación anual
    'ajuste', 'carga', 'impacto', 'recuperacion', 'activacion', 'tapering',
    -- las tres que faltaban: días que existen y no encajaban en ninguna
    'competicion', 'descanso', 'rehabilitador'
  ));

-- El `rol` viejo se queda con su lista de siempre, y además se le
-- deja sitio al vocabulario nuevo. Hace falta de verdad: hay
-- papeles del día («ajuste», «rehabilitador») que no tienen
-- equivalente viejo, y el disparador los copia tal cual antes que
-- traducirlos a una mentira.
alter table public.sesiones drop constraint if exists sesiones_rol_check;
alter table public.sesiones add  constraint sesiones_rol_check
  check (rol is null or rol in (
    'calidad_fuerte', 'secundaria', 'activacion', 'ultimo_toque_48h', 'descarga', 'competicion',
    'ajuste', 'carga', 'impacto', 'recuperacion', 'tapering', 'descanso', 'rehabilitador'
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

  if new.papel_dia is null then
    new.papel_dia := case
      when new.tipo = 'descanso'         then 'descanso'
      when new.tipo = 'competicion'      then 'competicion'
      when new.tipo = 'activacion'       then 'activacion'
      when new.rol  = 'calidad_fuerte'   then 'impacto'
      when new.rol  = 'secundaria'       then 'carga'
      when new.rol  = 'descarga'         then 'recuperacion'
      when new.rol  = 'ultimo_toque_48h' then 'tapering'
      when new.rol  = 'activacion'       then 'activacion'
      when new.rol  = 'competicion'      then 'competicion'
      -- si el rol ya viene con vocabulario nuevo, se respeta
      when new.rol in ('ajuste', 'carga', 'impacto', 'recuperacion',
                       'tapering', 'descanso', 'rehabilitador') then new.rol
      when new.tipo is not null          then 'carga'
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
      when new.deporte = 'natacion'          then 'natacion'
      when new.deporte in ('fuerza', 'cubo') then 'gym'
      when new.papel_dia in ('descanso', 'competicion', 'activacion')
                                             then new.papel_dia
      when v_seccion in ('running', 'montana', 'triatlon') then 'continuo'
      else 'pista'
    end;
  end if;

  if new.rol is null and new.papel_dia is not null then
    new.rol := case new.papel_dia
      when 'impacto'      then 'calidad_fuerte'
      when 'carga'        then 'secundaria'
      when 'recuperacion' then 'descarga'
      when 'tapering'     then 'ultimo_toque_48h'
      when 'activacion'   then 'activacion'
      when 'competicion'  then 'competicion'
      -- «ajuste», «descanso» y «rehabilitador» no tenían equivalente
      -- viejo: se copian tal cual, que es más honrado que forzarlos
      else new.papel_dia
    end;
  end if;

  return new;
end;
$$;

comment on function public.apo_sesiones_dos_ejes() is
  'Mantiene de acuerdo el par viejo (tipo, rol) y el nuevo (deporte, papel_dia) '
  'mientras convivan pantallas que escriben de las dos maneras. Solo rellena '
  'huecos: nunca pisa un valor que ya venga puesto.';

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

-- ------------------------------------------------------------
-- 6 · Que la familia y el calendario público también lo vean
--     La familia no lee `sesiones` (migración 100): lee la vista
--     `sesiones_agenda`, que enseña el cuándo y el dónde pero
--     nunca el contenido. Si los ejes nuevos no salen por ahí, un
--     padre seguiría leyendo «continuo» y «calidad_fuerte» cuando
--     su hijo ya ve «Atletismo · Impacto». Las columnas nuevas se
--     añaden al final, que es como se puede reemplazar una vista
--     sin tirarla y sin romper a quien ya la usa.
-- ------------------------------------------------------------
create or replace view public.sesiones_agenda as
  select s.id as sesion_id,
         s.fecha,
         s.hora,
         s.titulo,
         s.tipo,
         s.rol,
         s.lugar,
         s.grupo_id,
         g.nombre  as grupo,
         g.seccion,
         coalesce(s.abierta_inscripcion, false) as abierta_inscripcion,
         s.abierta_a,
         s.plazas,
         public.sesion_num_apuntados(s.id) as apuntados,
         case when s.plazas is null then null::integer
              else greatest(0, s.plazas - public.sesion_num_apuntados(s.id)) end as libres,
         s.deporte,
         s.deporte_2,
         s.papel_dia
    from public.sesiones s
    left join public.grupos g on g.id = s.grupo_id
   where coalesce(s.publicada, false)
     and (s.atletas_ids is null or coalesce(s.abierta_inscripcion, false));

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- el reparto de los 361 por deporte
--   select deporte, count(*) from sesiones group by 1 order by 2 desc;
--
--   -- el reparto por papel del día
--   select papel_dia, count(*) from sesiones group by 1 order by 2 desc;
--
--   -- ninguno debe quedar sin deporte ni sin papel
--   select count(*) from sesiones where deporte is null or papel_dia is null;
--
--   -- los que hubo que deducir por la sección del grupo, para
--   -- repasarlos a ojo cuando el club quiera
--   select s.fecha, g.nombre, s.tipo, s.titulo, s.deporte
--     from sesiones s left join grupos g on g.id = s.grupo_id
--    where s.tipo in ('activacion', 'competicion', 'descanso')
--    order by s.fecha;
-- ------------------------------------------------------------
