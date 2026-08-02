-- ============================================================
-- 050 · NOTAS DEL DÍA al pasar lista
-- ------------------------------------------------------------
-- QUÉ RESUELVE (encargo del dueño del club):
--   «En la asistencia que haya opción de añadir una nota. Por
--    ejemplo, hoy ha roto X y no ha hecho caso. Para que en el
--    futuro, si pasa algo, poder decirle a la madre: mira, este
--    día hizo esto, este día hizo esto...»
--
--   Es decir: apuntar la incidencia EN EL MOMENTO de pasar lista,
--   y poder sacar después el historial de un atleta día a día.
--
-- QUÉ AÑADE (todo sobre la tabla que YA existe, `notas_atleta`,
-- creada en migraciones/009_notas_privadas.sql):
--   · fecha    · el día AL QUE SE REFIERE la nota. No es lo mismo
--               que created_at (cuándo se escribió): una nota del
--               martes se puede apuntar el miércoles al corregir
--               la lista. El informe se ordena por `fecha`.
--   · tipo     · para poder contar «3 de comportamiento, 1 de
--               material» en la reunión con la familia.
--   · grupo_id · en qué grupo pasó, que un atleta puede entrenar
--               en varios sitios.
--   · Una policy de UPDATE que faltaba: sin ella una nota escrita
--     con prisa a pie de pista solo se podía borrar, no corregir.
--
-- QUÉ **NO** TOCA (a propósito, son datos de menores y de conducta):
--   · QUIÉN VE ESTAS NOTAS. Siguen siendo del equipo técnico y de
--     nadie más: admin o el entrenador de ESE atleta. Ni el atleta
--     ni su familia tienen ninguna policy que les dé acceso, y con
--     RLS activado «sin policy = sin acceso». Las policies de
--     SELECT/INSERT/DELETE de la 009 se quedan exactamente igual.
--   · La tabla `asistencia`: la nota va aparte. Así se puede
--     apuntar una incidencia aunque la lista todavía no se haya
--     guardado, y borrar o rehacer la lista no se lleva la nota
--     por delante.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/050_notas_asistencia.sql
-- (Es idempotente: se puede relanzar sin romper nada.)
-- ============================================================


-- =====================================================================
-- 1 · LAS TRES COLUMNAS NUEVAS
-- =====================================================================

alter table public.notas_atleta add column if not exists fecha date;
alter table public.notas_atleta add column if not exists tipo text;
alter table public.notas_atleta add column if not exists grupo_id uuid;

-- La fecha por defecto es hoy: al pasar lista casi siempre se apunta
-- lo que acaba de pasar, y así una nota nunca se queda sin día.
alter table public.notas_atleta alter column fecha set default current_date;

-- Tipo por defecto «otro»: las observaciones sueltas del portal del
-- entrenador (que no eligen tipo) siguen guardándose sin cambiar nada.
alter table public.notas_atleta alter column tipo set default 'otro';


-- =====================================================================
-- 2 · RELLENAR LO QUE YA HABÍA
-- ---------------------------------------------------------------------
-- Las notas antiguas no tenían día propio: se toma el de su created_at
-- (la fecha en que se escribieron), que es lo más cercano a la verdad.
-- =====================================================================

update public.notas_atleta
   set fecha = (created_at at time zone 'Europe/Madrid')::date
 where fecha is null
   and created_at is not null;

update public.notas_atleta set fecha = current_date where fecha is null;
update public.notas_atleta set tipo  = 'otro'      where tipo  is null or btrim(tipo) = '';

-- Ya no queda ninguna fila sin día, así que se puede exigir.
alter table public.notas_atleta alter column fecha set not null;


-- =====================================================================
-- 3 · REGLAS DE LOS DATOS
-- ---------------------------------------------------------------------
-- Los tipos son POCOS y en cristiano, para que se elijan de un toque a
-- pie de pista. Si algún día hay que añadir uno, se cambia aquí el
-- CHECK y el desplegable de las dos pantallas de pasar lista.
-- =====================================================================

alter table public.notas_atleta drop constraint if exists notas_atleta_tipo_check;
alter table public.notas_atleta add constraint notas_atleta_tipo_check
  check (tipo in ('comportamiento','lesion','material','familia','otro'));

-- El grupo es opcional (una nota puede venir de la ficha del atleta, sin
-- grupo). Si un día se borra el grupo, la nota se queda: lo que importa
-- es lo que pasó, no dónde estaba archivado.
alter table public.notas_atleta drop constraint if exists notas_atleta_grupo_id_fkey;
alter table public.notas_atleta add constraint notas_atleta_grupo_id_fkey
  foreign key (grupo_id) references public.grupos(id) on delete set null;


-- =====================================================================
-- 4 · ÍNDICE PARA EL INFORME
-- ---------------------------------------------------------------------
-- El informe siempre pide «las notas de ESTE atleta entre estas dos
-- fechas, de la más reciente a la más antigua». Este índice es justo eso.
-- =====================================================================

create index if not exists notas_atleta_atleta_fecha_idx
  on public.notas_atleta (atleta_id, fecha desc);


-- =====================================================================
-- 5 · PODER CORREGIR UNA NOTA (no solo borrarla)
-- ---------------------------------------------------------------------
-- Mismo círculo de siempre: admin o el entrenador de ESE atleta. El
-- WITH CHECK repite la condición para que nadie pueda mover una nota a
-- un atleta que no lleva. Nada de esto abre la puerta a la familia ni
-- al atleta: siguen sin ninguna policy.
-- =====================================================================

drop policy if exists "staff corrige notas privadas" on public.notas_atleta;
create policy "staff corrige notas privadas" on public.notas_atleta
for update to authenticated
using (
  public.es_admin()
  or atleta_id in (select id from public.atletas where entrenador_id = public.mi_perfil_id())
)
with check (
  public.es_admin()
  or atleta_id in (select id from public.atletas where entrenador_id = public.mi_perfil_id())
);


-- =====================================================================
-- 6 · QUÉ ES CADA COSA (se ve desde el propio gestor de la base)
-- =====================================================================

comment on table  public.notas_atleta is
  'Notas internas del equipo técnico sobre un atleta. Las escribe el entrenador al pasar lista o desde su portal. NO las ve ni el atleta ni su familia.';
comment on column public.notas_atleta.fecha is
  'Día AL QUE SE REFIERE la nota (el de la lista), no cuándo se escribió: eso es created_at.';
comment on column public.notas_atleta.tipo is
  'comportamiento · lesion · material · familia · otro';
comment on column public.notas_atleta.grupo_id is
  'Grupo en el que pasó, si la nota se apuntó al pasar lista.';
