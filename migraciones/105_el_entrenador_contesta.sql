-- ============================================================
-- 105 · El entrenador contesta, y el atleta lo lee
-- ------------------------------------------------------------
-- LO QUE FALTABA
-- La tabla `feedback_entrenamientos` existe desde el principio.
-- Estaba VACÍA, no había ninguna pantalla para escribir en ella,
-- y el permiso solo dejaba entrar a administración: aunque
-- alguien hubiera escrito algo, el atleta no habría podido leerlo.
-- Las tres cosas se arreglan aquí y en las dos pantallas.
--
-- PARA QUÉ
-- Es lo que cierra «hablar con el atleta» sin que tengan que
-- coincidir en la pista. Y es lo que el club describió cuando
-- pidió el historial: «mira lo que hicimos hace un mes, hicimos
-- esto y ahora estamos haciendo esto». Sin una respuesta del
-- entrenador, el atleta apunta cómo le fue y no le contesta
-- nadie; a la cuarta semana deja de apuntar.
--
-- ============================================================
-- QUIÉN LEE QUÉ, QUE ES LA PARTE DELICADA
-- ------------------------------------------------------------
-- EL ATLETA SÍ, y solo lo suyo. Un comentario del entrenador
-- sobre un entrenamiento se escribe PARA que lo lea el atleta:
-- si no, es una nota interna, y esas ya tienen su sitio en
-- `notas_atleta`, que el atleta no ve (migración 009).
--
-- LA FAMILIA NO. El club lo decidió en la misma conversación en
-- la que dejó a las familias fuera del entrenamiento (migración
-- 100): no ven el entrenamiento ni ven el feedback. Este
-- comentario es las dos cosas a la vez. El permiso se apoya en
-- `mis_atletas_entreno()`, que es la lista de siempre SIN la vía
-- de `perfil_padre_id`: por ahí es por donde entran las familias
-- y por donde no van a entrar aquí.
--
-- ESCRIBIR, SOLO EL ENTRENADOR DE ESE ATLETA. No vale
-- `mis_atletas_entreno()` para esto, porque dentro está también
-- el propio atleta y podría escribirse sus propios comentarios de
-- entrenador. Se usa `soy_entrenador_de()` (migración 104), que
-- es exactamente esa pregunta.
--
-- Y CADA UNO FIRMA LO SUYO: un entrenador no puede editar ni
-- borrar el comentario de otro entrenador. Puede leerlo —lo
-- necesita para no repetirse— pero no cambiarlo.
--
-- ============================================================
-- CORREGIR, CON EL MISMO CRITERIO QUE LO DEMÁS
-- ------------------------------------------------------------
-- Igual que lo que apunta el atleta (migración 104): lo del mismo
-- día se retoca sin más, y lo de días anteriores deja rastro. Un
-- entrenador que matiza media hora después no está cambiando la
-- historia; uno que reescribe en septiembre lo que dijo en junio,
-- sí. Y quien lo lee tiene que poder notar la diferencia.
--
-- Aquí no hace falta mirar la fecha del entrenamiento, sino la
-- del propio comentario: se compara con el día en que se escribió.
--
-- ============================================================
-- IDEMPOTENTE
-- Columnas «if not exists», funciones «create or replace» y
-- políticas que se tiran antes de crearse. No borra nada.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LO QUE LE FALTABA A LA TABLA
-- ------------------------------------------------------------
alter table public.feedback_entrenamientos
  add column if not exists editado_en timestamptz;

comment on table public.feedback_entrenamientos is
  'La respuesta del entrenador a lo que el atleta apuntó de un entrenamiento. '
  'LA LEE EL ATLETA: no es una nota interna. Las notas internas van en '
  '`notas_atleta`, que el atleta no ve. Las familias no ven ni esto ni el '
  'entrenamiento (migración 100).';
comment on column public.feedback_entrenamientos.registro_id is
  'A qué se contesta: al registro de UN atleta en UN entrenamiento. Por ahí sale '
  'de quién es, y por eso el permiso puede ser tan estrecho.';
comment on column public.feedback_entrenamientos.entrenador_id is
  'Quien lo firma. Va a la vista junto al comentario («Nacho, tu entrenador»): un '
  'comentario sin cara detrás no lo lee nadie igual.';
comment on column public.feedback_entrenamientos.comentario is
  'Lo que le dice a su atleta. Texto libre y a mano, como todo lo demás.';
comment on column public.feedback_entrenamientos.editado_en is
  'Cuándo se retocó, si se retocó DESPUÉS del día en que se escribió. Retocarlo el '
  'mismo día no deja rastro: eso es terminar de escribir. Reescribir en septiembre '
  'lo que se dijo en junio, sí.';

-- La pregunta que se hace: «¿hay comentario para estos
-- registros?». La hace el atleta al abrir su semana (varios
-- registros de golpe) y el entrenador al abrir un entrenamiento.
create index if not exists idx_feedback_registro
  on public.feedback_entrenamientos (registro_id);

-- ------------------------------------------------------------
-- 2 · EL RASTRO DE LAS EDICIONES
-- ------------------------------------------------------------
-- `security definer` con el `search_path` clavado, como todos los
-- disparadores de esta base (ver migración 106). Este no llama a nada,
-- así que no estaba roto, pero se pone igual: un disparador que no
-- sigue la norma es el que un día llama a algo y falla sin avisar.
create or replace function public.apo_feedback_editado()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  -- Solo cuenta como edición si cambia el texto y si ya no estamos
  -- en el día en que se escribió. Poner la coma que faltaba diez
  -- minutos después no es rectificar.
  if new.comentario is distinct from old.comentario
     and (old.created_at at time zone 'Europe/Madrid')::date
         < (now() at time zone 'Europe/Madrid')::date then
    new.editado_en := now();
  else
    new.editado_en := old.editado_en;
  end if;
  -- Ni la firma ni la fecha original se mueven al editar: quien lo
  -- escribió lo escribió, y cuándo lo dijo por primera vez importa.
  new.entrenador_id := old.entrenador_id;
  new.created_at    := old.created_at;
  new.registro_id   := old.registro_id;
  return new;
end;
$$;

comment on function public.apo_feedback_editado() is
  'Deja constancia de cuándo se reescribió un comentario del entrenador, si fue en '
  'otro día distinto del que se escribió. Y clava la firma y la fecha original: al '
  'editar no se puede cambiar quién lo dijo ni cuándo lo dijo.';

drop trigger if exists trg_feedback_editado on public.feedback_entrenamientos;
create trigger trg_feedback_editado
  before update on public.feedback_entrenamientos
  for each row execute function public.apo_feedback_editado();

-- ------------------------------------------------------------
-- 3 · LOS PERMISOS
-- ------------------------------------------------------------
-- LEER: el atleta lo suyo y su entrenador. Las familias NO: la
-- vía `perfil_padre_id` no está dentro de `mis_atletas_entreno()`,
-- y esa es toda la diferencia entre las dos listas.
drop policy if exists "atleta lee lo suyo y su entrenador" on public.feedback_entrenamientos;
create policy "atleta lee lo suyo y su entrenador" on public.feedback_entrenamientos
  for select to authenticated
  using (
    registro_id in (
      select r.id from public.registros_sesion r
       where r.atleta_id in (select public.mis_atletas_entreno())
    )
  );

-- ESCRIBIR: solo el entrenador de ese atleta, y firmando con su
-- nombre. El `entrenador_id = mi_perfil_id()` no es un adorno: sin
-- él, un entrenador podría dejar un comentario firmado por otro.
drop policy if exists "entrenador escribe a su atleta" on public.feedback_entrenamientos;
create policy "entrenador escribe a su atleta" on public.feedback_entrenamientos
  for insert to authenticated
  with check (
    entrenador_id = public.mi_perfil_id()
    and registro_id in (
      select r.id from public.registros_sesion r
       where public.soy_entrenador_de(r.atleta_id)
    )
  );

-- CORREGIR Y RETIRAR: cada uno lo suyo. Un entrenador lee los
-- comentarios de los demás —los necesita para no repetirse— pero
-- no los cambia.
drop policy if exists "cada entrenador corrige lo suyo" on public.feedback_entrenamientos;
create policy "cada entrenador corrige lo suyo" on public.feedback_entrenamientos
  for update to authenticated
  using (entrenador_id = public.mi_perfil_id())
  with check (entrenador_id = public.mi_perfil_id());

drop policy if exists "cada entrenador retira lo suyo" on public.feedback_entrenamientos;
create policy "cada entrenador retira lo suyo" on public.feedback_entrenamientos
  for delete to authenticated
  using (entrenador_id = public.mi_perfil_id());

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- las cuatro políticas nuevas, más la de administración de siempre
--   select polname from pg_policy p join pg_class c on c.oid = p.polrelid
--    where c.relname = 'feedback_entrenamientos';
--
--   -- simulando papeles: la familia no puede ver ni uno
--   --   (ver la comprobación completa en el informe de la entrega)
--
--   -- comentarios retocados otro día
--   select id, created_at::date, editado_en::date
--     from feedback_entrenamientos where editado_en is not null;
-- ------------------------------------------------------------
