-- ============================================================
-- 148 · EL DIARIO DE BIENESTAR DEL GRUPO PRO
-- ------------------------------------------------------------
-- QUÉ ES Y DE DÓNDE SALE
--
-- El entrenador del Grupo A pidió un diario diario de bienestar para
-- controlar la carga y prevenir lesiones: el cuestionario Hooper (sueño,
-- fatiga, dolor muscular, estrés y ánimo, del 1 al 7) y un semáforo de
-- dolor (verde / ámbar / rojo, con la zona). Y puso tres condiciones,
-- que son las que mandan sobre cómo está hecho esto:
--
--   1. SOLO PARA EL GRUPO A. Es el grupo de rendimiento, el que más paga,
--      y esto es parte de la distinción de ser Pro. No se le pide al
--      resto de la escuela ni a los adultos.
--   2. LO VE SOLO EL ENTRENADOR. Ni administración. Son datos de salud
--      de gente joven, y el club decidió que este dato vive dentro de la
--      relación entrenador–atleta y no sale de ahí.
--   3. VA JUNTO AL HOOPER. Un único gesto diario, no dos formularios.
--
-- POR QUÉ UN INTERRUPTOR EN EL GRUPO Y NO «GRUPO A» A FUEGO
--
-- Clavar el nombre «Grupo A» en el código lo ata a un nombre que puede
-- cambiar, y deja fuera cualquier otro grupo al que el club quiera darle
-- esto mañana. En vez de eso, el grupo lleva una casilla `pide_bienestar`.
-- Hoy se enciende para el Grupo A; el día que se quiera para otro, es
-- marcar la casilla, no reescribir una migración.
--
-- POR QUÉ UNA TABLA NUEVA Y NO AMPLIAR `registros_sesion`
--
-- Porque el bienestar es DIARIO e independiente de que haya entreno. Un
-- domingo de descanso también se duerme mal. `registros_sesion` cuelga de
-- una sesión; esto cuelga de un día. Una fila por atleta y día.
-- ============================================================

-- ------------------------------------------------------------
-- 1 · EL INTERRUPTOR
-- ------------------------------------------------------------
alter table grupos add column if not exists pide_bienestar boolean not null default false;

comment on column grupos.pide_bienestar is
  'Si es true, a los atletas de este grupo se les pide el diario de bienestar (Hooper + semáforo de dolor). Hoy solo el Grupo A.';

-- Se enciende para el Grupo A de competición. Por nombre y sección, no por
-- id: los ids no se pueden escribir en una migración de un repo público sin
-- acoplarla a esta base concreta.
update grupos set pide_bienestar = true
 where nombre = 'Grupo A' and seccion = 'competicion';

-- ------------------------------------------------------------
-- 2 · ¿A ESTE ATLETA SE LE PIDE BIENESTAR?
-- Lo usan la web (para enseñar el formulario) y las políticas de abajo
-- (para que no se cuele una fila de quien no debe). SECURITY DEFINER
-- porque mira `atleta_grupos`, que un atleta no puede leer entero.
-- ------------------------------------------------------------
create or replace function atleta_pide_bienestar(p_atleta uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1
      from atleta_grupos ag
      join grupos g on g.id = ag.grupo_id
     where ag.atleta_id = p_atleta
       and g.pide_bienestar
  );
$$;

-- Supabase revoca el EXECUTE que Postgres da por defecto, así que hay que
-- concederlo a mano: sin esto, la política de abajo que la usa falla con
-- «permission denied for function», y el atleta no puede ni guardar. Salió
-- probándolo, no leyéndolo.
grant execute on function atleta_pide_bienestar(uuid) to authenticated;

-- ------------------------------------------------------------
-- 3 · EL DIARIO
-- Una fila por atleta y día. Hooper del 1 al 7, semáforo con tres colores
-- y su zona, y las horas de sueño que ya se venían preguntando en la hoja
-- de la sesión (aquí es donde de verdad les toca vivir).
-- ------------------------------------------------------------
-- Se rehace por si una versión anterior la creó apuntando a `perfiles`:
-- está vacía siempre que corre esto, así que tirarla no pierde nada.
drop table if exists bienestar_diario cascade;

create table bienestar_diario (
  id             uuid primary key default gen_random_uuid(),
  -- ⚠️ REFERENCIA A `atletas`, NO A `perfiles`. El portal trabaja con la
  -- tabla `atletas` (una persona puede ser atleta y a la vez tener perfil
  -- de padre o de entrenador), y todo lo del atleta —registros_sesion,
  -- atleta_grupos— cuelga de `atletas.id`. Apuntar a `perfiles` dejaba
  -- fuera el caso del padre que entra por su hijo, y no casaba con
  -- `mis_atletas()`. Salió probándolo: `mi_perfil_id()` daba NULL para un
  -- atleta que entra por su familia.
  atleta_id      uuid not null references atletas(id) on delete cascade,
  fecha          date not null default current_date,

  -- Cuestionario Hooper. 1 = lo mejor, 7 = lo peor, como en el original.
  sueno_calidad  smallint check (sueno_calidad between 1 and 7),
  fatiga         smallint check (fatiga        between 1 and 7),
  dolor_muscular smallint check (dolor_muscular between 1 and 7),
  estres         smallint check (estres        between 1 and 7),
  animo          smallint check (animo         between 1 and 7),
  horas_sueno    numeric(3,1) check (horas_sueno >= 0 and horas_sueno <= 24),

  -- Semáforo de dolor. Verde = nada, ámbar = molestia que vigilar, rojo =
  -- parar. La zona es texto libre: «gemelo derecho», «lumbar».
  dolor_semaforo text check (dolor_semaforo in ('verde','ambar','rojo')),
  dolor_zona     text,

  nota           text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  -- Un día, una fila: si vuelve a abrir el diario, se corrige, no se duplica.
  unique (atleta_id, fecha)
);

comment on table bienestar_diario is
  'Diario de bienestar (Hooper + semáforo de dolor) del Grupo Pro. Una fila por atleta y día. Dato de salud: lo lee el atleta y su entrenador, nadie más.';

create index if not exists ix_bienestar_atleta_fecha on bienestar_diario (atleta_id, fecha desc);

alter table bienestar_diario enable row level security;

grant select, insert, update on bienestar_diario to authenticated;
-- anon NO: esto no es contenido público, es un dato de salud.

-- ------------------------------------------------------------
-- 4 · QUIÉN PUEDE QUÉ · aquí está la condición 2 («lo veo solo yo»)
--
-- LEER: el propio atleta (es su cuerpo) y su entrenador. NADIE MÁS. En
-- concreto, NO administración: es la única tabla del proyecto donde
-- `es_admin()` no abre la puerta, y es a propósito. El club lo pidió así.
--
-- ESCRIBIR: solo el atleta, solo su fila, y solo si es de un grupo que
-- pide bienestar. El `with check` corta que alguien se cree filas para
-- otro o desde un grupo que no toca.
-- ------------------------------------------------------------
-- `mis_atletas()` es «los atletas por los que puedo actuar»: yo mismo, mis
-- hijos si soy padre, y mis atletas si soy entrenador. Es el mismo cristal
-- con el que registros_sesion decide quién puede tocar qué.
drop policy if exists "atleta y su entrenador leen bienestar" on bienestar_diario;
create policy "atleta y su entrenador leen bienestar"
  on bienestar_diario for select
  using (
    atleta_id in (select mis_atletas())
    or soy_entrenador_de(atleta_id)   -- el entrenador del GRUPO, aunque no sea su entrenador directo
  );

drop policy if exists "el atleta escribe su bienestar" on bienestar_diario;
create policy "el atleta escribe su bienestar"
  on bienestar_diario for insert
  with check (
    atleta_id in (select mis_atletas())
    and atleta_pide_bienestar(atleta_id)
  );

drop policy if exists "el atleta corrige su bienestar" on bienestar_diario;
create policy "el atleta corrige su bienestar"
  on bienestar_diario for update
  using (atleta_id in (select mis_atletas()))
  with check (atleta_id in (select mis_atletas()) and atleta_pide_bienestar(atleta_id));

-- La hora de modificación se mantiene sola.
create or replace function bienestar_marca_hora()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists tg_bienestar_marca_hora on bienestar_diario;
create trigger tg_bienestar_marca_hora
  before update on bienestar_diario
  for each row execute function bienestar_marca_hora();
