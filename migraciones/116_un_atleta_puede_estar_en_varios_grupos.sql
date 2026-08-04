-- ============================================================
-- 116 · Una persona puede estar en dos grupos
-- ------------------------------------------------------------
-- LO QUE FALLA, EN UNA FRASE
-- La ficha del atleta tiene UNA casilla de grupo, así que el club
-- solo puede escribir la mitad de la verdad: quien hace running en
-- La Tribu y además va a El Cubo, quien hace la escuela a primera
-- hora y fuerza a segunda, o quien entrena atletismo y gimnasio el
-- mismo día, cabe en la base una sola vez y en un solo sitio.
--
-- POR QUÉ SE ARREGLA AHORA Y NO EN OCTUBRE
-- En septiembre entran las fichas de verdad. Si esto se cambia
-- después, cada segunda pertenencia hay que meterla a mano, ficha
-- por ficha, mirando papeles que para entonces ya nadie tiene
-- delante. Ahora la base está prácticamente vacía de gente real y
-- el cambio no cuesta nada.
--
-- ------------------------------------------------------------
-- LA DECISIÓN DE FONDO: NO SE QUITA NADA, SE AÑADE AL LADO
-- `atletas.grupo_id` —la casilla de siempre— se queda donde está y
-- pasa a llamarse, de palabra, EL GRUPO PRINCIPAL. Los demás
-- grupos viven en una tabla nueva, `atleta_grupos`, que también
-- guarda el principal (para que quien pregunte «¿en qué grupos
-- está?» tenga una sola respuesta y no dos medias).
--
-- Esto no es pereza: se contaron las pantallas que leen esa
-- casilla y son CIEN sitios repartidos por veintidós ficheros
-- —las listas del entrenador, los entrenamientos, las cuotas, los
-- horarios, los informes, la ficha, el portal de la familia, el
-- del socio—. Y ESCRIBEN solo cuatro. Cambiar la casilla de sitio
-- obligaría a tocar los noventa a la vez, con todo lo que eso
-- rompe; dejarla quieta hace que los cien sigan funcionando
-- exactamente igual el día de la aplicación, y que las pantallas
-- se vayan pasando a la tabla nueva una a una, sin prisa.
--
-- Para que las dos digan lo mismo sin que nadie se acuerde de
-- copiarlo, hay dos disparadores que las mantienen atadas:
--
--   · si alguien cambia el grupo de la ficha (la casilla vieja),
--     ese grupo aparece solo en la tabla nueva marcado como
--     principal, y el que lo era antes deja de serlo;
--   · si en la tabla nueva se marca otro como principal, la
--     casilla vieja se pone sola a ese.
--
-- Se muerden la cola a propósito, y paran solas: cada una escribe
-- únicamente cuando el valor va a cambiar de verdad, así que el
-- rebote se apaga en el primer bote.
--
-- LO QUE LOS DISPARADORES NO HACEN
-- No sacan a nadie de un grupo. Dejar la casilla vieja en «(sin
-- grupo)» quiere decir «ya no tiene grupo principal», no «bórralo
-- de los otros dos». Sacar a alguien de un grupo es una decisión
-- que se toma, no un efecto secundario de otra cosa.
--
-- ------------------------------------------------------------
-- QUIÉN VE QUÉ (y por qué hay que tocarlo)
-- Hasta hoy, el entrenador de un grupo veía a los atletas cuya
-- CASILLA apuntaba a su grupo. Si el crío que va a El Cubo lo
-- tiene como segundo grupo, su entrenador de El Cubo no lo vería
-- por ninguna parte: ni en su lista, ni para pasarle lista. Estar
-- en dos grupos no serviría de nada.
--
-- Así que las reglas de acceso que decían «su grupo» pasan a
-- decir «cualquiera de sus grupos». Es lo mismo de antes más lo
-- que el club ya hacía en la pista y no cabía en la base. No se
-- abre nada a nadie nuevo: sigue haciendo falta ser el entrenador
-- de ESE grupo, o el coordinador de ESA sección.
--
-- ⚠️ LO QUE ESTA MIGRACIÓN NO TOCA, A PROPÓSITO
-- `soy_staff_de_atleta` —la puerta por la que se GUARDA la
-- asistencia y las notas— sigue diciendo lo de siempre: o eres
-- admin, o eres el entrenador escrito en la ficha del atleta. Ser
-- entrenador de uno de sus grupos deja verlo, pero no escribirle.
-- Ampliar eso es una decisión del club, no un efecto colateral de
-- esta migración, y se pregunta antes de tocarla.
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta. No borra ni una ficha.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LA TABLA: QUIÉN ESTÁ EN QUÉ GRUPO
-- ------------------------------------------------------------
-- Una fila por pertenencia. Si alguien está en tres grupos, tres
-- filas. La llave es la pareja atleta+grupo: apuntar dos veces a
-- la misma persona en el mismo grupo no puede pasar.
create table if not exists public.atleta_grupos (
  atleta_id  uuid        not null references public.atletas(id) on delete cascade,
  grupo_id   uuid        not null references public.grupos(id),
  -- El principal es el que sale en la casilla de siempre y el que
  -- usan las pantallas que todavía no saben de esta tabla.
  principal  boolean     not null default false,
  -- Desde cuándo entrena ahí. Sirve para no confundir «se apuntó
  -- en enero» con «lleva desde septiembre» al mirar una asistencia
  -- floja, que es la pregunta que se hace siempre.
  desde      date        not null default current_date,
  creado_en  timestamptz not null default now(),
  primary key (atleta_id, grupo_id)
);

comment on table public.atleta_grupos is
  'En qué grupos entrena cada atleta. Existe porque una persona puede estar en '
  'dos a la vez —running de La Tribu y El Cubo, primera y segunda hora de la '
  'escuela, atletismo y fuerza el mismo día— y la ficha solo tenía una casilla. '
  'El grupo principal también está aquí: esta tabla es la respuesta completa.';
comment on column public.atleta_grupos.principal is
  'El grupo que sale en la ficha (atletas.grupo_id) y el que leen las pantallas '
  'que todavía no saben de esta tabla. Solo uno por atleta.';
comment on column public.atleta_grupos.desde is
  'Desde cuándo entrena en ese grupo. Sin esto, una asistencia floja de quien '
  'llegó en febrero parece la de quien lleva desde septiembre.';

-- Un solo principal por persona, y lo dice la base: si dependiera
-- de que las pantallas se acuerden, tarde o temprano hay dos.
--
-- ⚠️ CÓMO SE CAMBIA EL PRINCIPAL: SE ASCIENDE, NO SE DEGRADA
-- Esta regla se comprueba fila a fila y al momento, así que marcar
-- el nuevo principal sin haber quitado antes el viejo la rompería.
-- Por eso hay un disparador —el de aquí abajo— que quita el
-- anterior ANTES de que el nuevo entre. La pantalla dice solo
-- «este es el principal» y no tiene que acordarse del otro.
create unique index if not exists ux_atleta_grupos_principal
  on public.atleta_grupos (atleta_id) where principal;

-- «¿Quién hay en este grupo?» es la pregunta de cada lista de cada
-- día. Sin este índice hay que leer la tabla entera para armarla.
create index if not exists idx_atleta_grupos_grupo
  on public.atleta_grupos (grupo_id);

-- ------------------------------------------------------------
-- 2 · LOS DOS DISPARADORES QUE LAS MANTIENEN ATADAS
-- ------------------------------------------------------------
-- De la ficha a la tabla nueva. Se dispara cuando alguien toca la
-- casilla de grupo por la vía de siempre (la ficha del panel, la
-- importación, el portal del entrenador).
create or replace function public.atleta_grupos_desde_la_ficha()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.grupo_id is not null then
    -- Primero se quita el principal al anterior y luego se le pone al
    -- nuevo. En este orden y no al revés: por un instante habría dos
    -- principales, y la base no lo consiente. El que deja de ser
    -- principal SIGUE en su grupo: cambiar cuál manda no es darse de
    -- baja del otro.
    update public.atleta_grupos
       set principal = false
     where atleta_id = new.id and grupo_id <> new.grupo_id and principal;

    -- El grupo de la ficha entra en la tabla y queda como principal.
    -- El `where` del final es lo que corta el rebote: si ya estaba
    -- marcado, no se escribe nada y el otro disparador no despierta.
    insert into public.atleta_grupos (atleta_id, grupo_id, principal)
    values (new.id, new.grupo_id, true)
    on conflict (atleta_id, grupo_id) do update
       set principal = true
     where public.atleta_grupos.principal is distinct from true;

  else
    -- «(Sin grupo)» en la ficha = ya no tiene principal. Los demás
    -- grupos donde esté se quedan como están, a propósito.
    update public.atleta_grupos
       set principal = false
     where atleta_id = new.id and principal;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_atleta_grupos_desde_la_ficha on public.atletas;
create trigger trg_atleta_grupos_desde_la_ficha
  after insert or update of grupo_id on public.atletas
  for each row execute function public.atleta_grupos_desde_la_ficha();

-- Marcar un principal quita el anterior, y lo hace ANTES de que el
-- nuevo se guarde. Sin esto, cambiar de principal sería un baile de
-- dos pasos que hay que dar en el orden exacto —quitar y poner— y
-- la pantalla que se equivocara de orden se comería un error de la
-- base sin entender por qué. Así, decir «este es el principal»
-- basta y sobra.
create or replace function public.atleta_grupos_un_solo_principal()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.principal then
    update public.atleta_grupos
       set principal = false
     where atleta_id = new.atleta_id
       and grupo_id <> new.grupo_id
       and principal;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_atleta_grupos_un_solo_principal on public.atleta_grupos;
create trigger trg_atleta_grupos_un_solo_principal
  before insert or update of principal on public.atleta_grupos
  for each row execute function public.atleta_grupos_un_solo_principal();

-- De la tabla nueva a la ficha. Se dispara cuando se apunta a
-- alguien en un grupo, se le cambia el principal o se le saca.
create or replace function public.ficha_desde_atleta_grupos()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'DELETE' then
    -- Si la ficha ya no existe (se está borrando el atleta entero y
    -- esto viene de arrastre), no hay nada que actualizar.
    if not exists (select 1 from public.atletas a where a.id = old.atleta_id) then
      return old;
    end if;
    -- Si al que se saca era el que salía en la ficha, la casilla no
    -- puede seguir apuntando a un grupo del que ya no forma parte: se
    -- queda con el más antiguo de los que le quedan, o vacía.
    update public.atletas a
       set grupo_id = (
             select ag.grupo_id
               from public.atleta_grupos ag
              where ag.atleta_id = old.atleta_id
              order by ag.principal desc, ag.desde, ag.grupo_id
              limit 1)
     where a.id = old.atleta_id and a.grupo_id = old.grupo_id;
    return old;
  end if;

  -- Se ha marcado un principal: la casilla de la ficha se pone a ese.
  -- El `is distinct from` es lo que corta el rebote hacia el otro
  -- disparador cuando ya valía lo mismo.
  if new.principal then
    update public.atletas a
       set grupo_id = new.grupo_id
     where a.id = new.atleta_id and a.grupo_id is distinct from new.grupo_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_ficha_desde_atleta_grupos on public.atleta_grupos;
create trigger trg_ficha_desde_atleta_grupos
  after insert or update or delete on public.atleta_grupos
  for each row execute function public.ficha_desde_atleta_grupos();

-- ------------------------------------------------------------
-- 3 · LO QUE YA HAY SE PASA A LA TABLA NUEVA
-- ------------------------------------------------------------
-- Sin esto, las pantallas nuevas verían el club entero sin grupo:
-- la tabla estaría vacía y todo el mundo «suelto». Cada ficha con
-- grupo pasa a tener su fila, marcada como principal, que es
-- exactamente lo que era hasta hoy.
--
-- `desde` se deja en la fecha de alta de la ficha cuando se sabe:
-- decir que todo el club entró en el grupo el día de la migración
-- sería inventarse un dato.
insert into public.atleta_grupos (atleta_id, grupo_id, principal, desde)
select a.id, a.grupo_id, true, coalesce(a.created_at::date, current_date)
  from public.atletas a
 where a.grupo_id is not null
on conflict (atleta_id, grupo_id) do nothing;

-- ------------------------------------------------------------
-- 4 · «¿EN QUÉ GRUPOS ESTÁ ESTA PERSONA?», EN UN SOLO SITIO
-- ------------------------------------------------------------
-- La usan las reglas de acceso de abajo. Va aparte, y no como un
-- trozo de consulta repetido en cada regla, por dos motivos: el
-- día que cambie la respuesta cambia en un sitio, y —más
-- importante— al ser `security definer` mira la tabla por debajo
-- de las reglas de acceso. Sin eso, una regla sobre `atletas` que
-- consultara `atleta_grupos`, cuya regla consulta `atletas`, se
-- llamaría a sí misma sin fin y Postgres cortaría la consulta.
--
-- Devuelve también el grupo de la casilla vieja: mientras las dos
-- convivan, la respuesta tiene que ser la suma, no una de las dos.
create or replace function public.grupos_del_atleta(p_atleta uuid)
returns setof uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select ag.grupo_id
    from public.atleta_grupos ag
   where ag.atleta_id = p_atleta
  union
  select a.grupo_id
    from public.atletas a
   where a.id = p_atleta and a.grupo_id is not null;
$$;

comment on function public.grupos_del_atleta(uuid) is
  'Todos los grupos en los que entrena una persona, incluido el principal. '
  'Una sola respuesta para las reglas de acceso y para las pantallas.';

-- Los grupos de la gente que uno tiene a su cargo (sus hijos, o él
-- mismo). Es lo que hace que el portal de un atleta que está en dos
-- grupos le enseñe los entrenamientos de los dos y no los de uno.
create or replace function public.mis_grupos_de_entreno()
returns setof uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select ag.grupo_id
    from public.atleta_grupos ag
   where ag.atleta_id in (select public.mis_atletas_entreno())
  union
  select a.grupo_id
    from public.atletas a
   where a.id in (select public.mis_atletas_entreno()) and a.grupo_id is not null;
$$;

create or replace function public.mis_grupos_de_familia()
returns setof uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select ag.grupo_id
    from public.atleta_grupos ag
   where ag.atleta_id in (select public.mis_atletas())
  union
  select a.grupo_id
    from public.atletas a
   where a.id in (select public.mis_atletas()) and a.grupo_id is not null;
$$;

comment on function public.mis_grupos_de_entreno() is
  'Los grupos donde entrena uno mismo. Con dos grupos, los dos.';
comment on function public.mis_grupos_de_familia() is
  'Los grupos donde entrenan uno mismo y sus hijos. Con dos grupos, los dos.';

-- ⚠️ EL PERMISO NO VIENE SOLO (migración 090): en esta base las
-- funciones nacen cerradas. Sin el grant, las reglas de acceso que
-- las llaman fallarían y nadie vería nada.
revoke execute on function public.grupos_del_atleta(uuid)     from public, anon;
revoke execute on function public.mis_grupos_de_entreno()     from public, anon;
revoke execute on function public.mis_grupos_de_familia()     from public, anon;
grant  execute on function public.grupos_del_atleta(uuid)     to authenticated;
grant  execute on function public.mis_grupos_de_entreno()     to authenticated;
grant  execute on function public.mis_grupos_de_familia()     to authenticated;

-- ------------------------------------------------------------
-- 5 · «SU GRUPO» PASA A SER «CUALQUIERA DE SUS GRUPOS»
-- ------------------------------------------------------------
-- Ninguna de estas reglas deja entrar a nadie nuevo: siguen
-- pidiendo ser el entrenador de ese grupo, el coordinador de esa
-- sección o el propio atleta. Lo único que cambia es que ya no se
-- mira una sola casilla.

-- El entrenador ve a los atletas de sus grupos.
drop policy if exists "entrenador ve atletas de sus grupos" on public.atletas;
create policy "entrenador ve atletas de sus grupos"
  on public.atletas for select to authenticated
  using (
    exists (
      select 1 from public.grupos g
       where g.entrenador_id = public.mi_perfil_id()
         and g.id in (select public.grupos_del_atleta(atletas.id))
    )
  );

-- El coordinador ve a los atletas de su sección.
drop policy if exists "coordinacion ve atletas de su seccion" on public.atletas;
create policy "coordinacion ve atletas de su seccion"
  on public.atletas for select to authenticated
  using (
    exists (
      select 1 from public.perfiles p
       where p.email = (auth.jwt() ->> 'email')
         and p.rol = 'coordinador'
         and p.seccion is not null
         and exists (
           select 1 from public.grupos g
            where g.seccion = p.seccion
              and g.id in (select public.grupos_del_atleta(atletas.id))
         )
    )
  );

-- Los entrenamientos y las sesiones de MIS grupos. Quien esté en
-- dos los ve de los dos; antes veía los de uno y del otro nada.
drop policy if exists "ver entrenamientos de mi grupo" on public.entrenamientos;
create policy "ver entrenamientos de mi grupo"
  on public.entrenamientos for select to authenticated
  using (grupo_id in (select public.mis_grupos_de_familia()));

drop policy if exists "ver sesiones de mi grupo" on public.sesiones;
create policy "ver sesiones de mi grupo"
  on public.sesiones for select to authenticated
  using (
    publicada = true
    and (
      (atletas_ids is null and grupo_id in (select public.mis_grupos_de_entreno()))
      or (atletas_ids is not null and exists (
            select 1 from unnest(sesiones.atletas_ids) x
             where x in (select public.mis_atletas_entreno())))
      or public.tengo_registro_en(id)
    )
  );

-- «¿Soy el entrenador de esta persona?» — la usan las notas, el
-- feedback y las pantallas del portal. Mismo cambio.
create or replace function public.soy_entrenador_de(p_atleta uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.atletas a
     where a.id = p_atleta and a.entrenador_id = public.mi_perfil_id()
  ) or exists (
    select 1 from public.grupos g
     where g.entrenador_id = public.mi_perfil_id()
       and g.id in (select public.grupos_del_atleta(p_atleta))
  );
$$;

-- ------------------------------------------------------------
-- 6 · QUIÉN PUEDE MIRAR Y TOCAR LA TABLA NUEVA
-- ------------------------------------------------------------
-- ⚠️ EN ESTA BASE LAS TABLAS NACEN ABIERTAS, al revés que las
-- funciones: al crearlas, Postgres le da a `anon` y a
-- `authenticated` permiso para todo. Así que lo primero es
-- quitárselo y volver a darlo medido.
alter table public.atleta_grupos enable row level security;

revoke all on table public.atleta_grupos from public;
revoke all on table public.atleta_grupos from anon;
grant select, insert, update, delete on table public.atleta_grupos to authenticated;

-- El visitante sin cuenta no tiene nada que hacer aquí: en qué
-- grupo entrena un menor no es información pública.
drop policy if exists "admin gestiona todo"                on public.atleta_grupos;
drop policy if exists "ver los grupos de mis atletas"      on public.atleta_grupos;
drop policy if exists "entrenador ve a los de sus grupos"  on public.atleta_grupos;
drop policy if exists "coordinacion ve los de su seccion"  on public.atleta_grupos;
drop policy if exists "dinero ve los grupos"               on public.atleta_grupos;
drop policy if exists "staff apunta en un grupo"           on public.atleta_grupos;
drop policy if exists "staff corrige el grupo"             on public.atleta_grupos;
drop policy if exists "staff saca de un grupo"             on public.atleta_grupos;

create policy "admin gestiona todo"
  on public.atleta_grupos for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

-- El atleta y su familia ven en qué grupos están ellos.
create policy "ver los grupos de mis atletas"
  on public.atleta_grupos for select to authenticated
  using (atleta_id in (select public.mis_atletas()));

-- El entrenador ve quién hay en los grupos que lleva. Y de esa
-- gente, TODOS sus grupos: saber que el crío que tienes el martes
-- también entrena el miércoles en otro sitio es justo lo que evita
-- cargarle de más. No le abre ninguna ficha nueva: es gente que ya
-- veía.
create policy "entrenador ve a los de sus grupos"
  on public.atleta_grupos for select to authenticated
  using (
    grupo_id in (select g.id from public.grupos g
                  where g.entrenador_id = public.mi_perfil_id())
    or public.soy_entrenador_de(atleta_id)
  );

-- El coordinador, los de su sección. Misma puerta que en `atletas`.
create policy "coordinacion ve los de su seccion"
  on public.atleta_grupos for select to authenticated
  using (
    exists (
      select 1 from public.perfiles p
       join public.grupos g on g.id = atleta_grupos.grupo_id
      where p.email = (auth.jwt() ->> 'email')
        and p.rol = 'coordinador'
        and p.seccion is not null
        and g.seccion = p.seccion
    )
  );

-- Quien lleva el dinero ya ve las fichas: la cuota depende del
-- grupo, y sin esto tendría que adivinarla.
create policy "dinero ve los grupos"
  on public.atleta_grupos for select to authenticated
  using (public.ve_dinero());

-- Apuntar, corregir y sacar: la MISMA puerta que para pasarle
-- lista a esa persona. Quien no puede lo uno, no puede lo otro.
create policy "staff apunta en un grupo"
  on public.atleta_grupos for insert to authenticated
  with check (public.soy_staff_de_atleta(atleta_id));

create policy "staff corrige el grupo"
  on public.atleta_grupos for update to authenticated
  using (public.soy_staff_de_atleta(atleta_id))
  with check (public.soy_staff_de_atleta(atleta_id));

create policy "staff saca de un grupo"
  on public.atleta_grupos for delete to authenticated
  using (public.soy_staff_de_atleta(atleta_id));

-- ------------------------------------------------------------
-- 7 · GUARDAR LOS GRUPOS DE UNA FICHA, DE UNA VEZ
-- ------------------------------------------------------------
-- Lo que llama la ficha del panel al pulsar «Guardar». Recibe la
-- lista ENTERA de grupos de esa persona y cuál es el principal, y
-- deja la base así: los que sobran fuera, los que faltan dentro.
--
-- Existe por lo mismo que `apo_pasar_lista` (migración 113): si la
-- pantalla tuviera que hacerlo en cuatro pasos —borra estos, mete
-- estos otros, marca el principal—, cualquier corte de conexión a
-- mitad dejaría a un crío fuera de su grupo sin que nadie se
-- entere. Aquí, o se hace todo o no se hace nada.
--
-- ⚠️ `security definer` con `search_path` clavado (migraciones 090
-- y 106). Como corre con los permisos del dueño se salta las
-- reglas de acceso, así que comprueba ella misma, y con la MISMA
-- puerta que la tabla.
create or replace function public.apo_grupos_de_atleta(
  p_atleta    uuid,
  p_grupos    uuid[],
  p_principal uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_grupos    uuid[] := coalesce(p_grupos, array[]::uuid[]);
  v_principal uuid   := p_principal;
  v_sobra     uuid;
  v_out       jsonb;
begin
  if p_atleta is null then
    raise exception 'Falta decir de qué atleta son los grupos';
  end if;
  if not exists (select 1 from public.atletas a where a.id = p_atleta) then
    raise exception 'Ese atleta no existe';
  end if;
  if not public.soy_staff_de_atleta(p_atleta) then
    raise exception 'No puedes cambiarle los grupos a este atleta';
  end if;

  -- Un grupo inventado se para aquí y no a mitad del guardado, para
  -- que la ficha no quede con la mitad de los grupos puestos.
  select x into v_sobra
    from unnest(v_grupos) x
   where not exists (select 1 from public.grupos g where g.id = x)
   limit 1;
  if v_sobra is not null then
    raise exception 'Ese grupo no existe: %', v_sobra;
  end if;

  if v_principal is not null and not (v_principal = any (v_grupos)) then
    raise exception 'El grupo principal tiene que ser uno de los suyos';
  end if;

  -- Si la pantalla no dice cuál es el principal, se respeta el que ya
  -- tenía mientras siga en la lista; y si no, el primero. Nunca se
  -- queda sin principal teniendo grupos: la ficha se vería «sin grupo»
  -- en las noventa pantallas que aún leen la casilla vieja.
  if v_principal is null and array_length(v_grupos, 1) > 0 then
    select a.grupo_id into v_principal
      from public.atletas a
     where a.id = p_atleta and a.grupo_id = any (v_grupos);
    if v_principal is null then v_principal := v_grupos[1]; end if;
  end if;

  -- 1 · fuera los que ya no están
  delete from public.atleta_grupos ag
   where ag.atleta_id = p_atleta
     and not (ag.grupo_id = any (v_grupos));

  -- 2 · dentro los nuevos (a los que ya estaban no se les toca el
  --     `desde`: llevan ahí desde cuando llevan)
  insert into public.atleta_grupos (atleta_id, grupo_id, principal)
  select p_atleta, x, false from unnest(v_grupos) x
  on conflict (atleta_id, grupo_id) do nothing;

  -- 3 · el principal, uno y solo uno. Primero se le quita al viejo y
  --     después se le pone al nuevo, en dos órdenes separadas: una
  --     sola que hiciera las dos cosas se pisaría a sí misma. Los
  --     disparadores dejan la casilla de la ficha diciendo lo mismo.
  update public.atleta_grupos ag
     set principal = false
   where ag.atleta_id = p_atleta
     and ag.principal
     and ag.grupo_id is distinct from v_principal;

  update public.atleta_grupos ag
     set principal = true
   where ag.atleta_id = p_atleta
     and ag.grupo_id = v_principal
     and not ag.principal;

  if v_principal is null then
    update public.atletas a set grupo_id = null
     where a.id = p_atleta and a.grupo_id is not null;
  end if;

  -- Se devuelve cómo ha quedado GUARDADO, para que la pantalla
  -- enseñe lo que hay en la base y no lo que ella creía.
  select coalesce(jsonb_agg(jsonb_build_object(
           'grupo_id', ag.grupo_id, 'principal', ag.principal, 'desde', ag.desde)
           order by ag.principal desc, ag.desde), '[]'::jsonb)
    into v_out
    from public.atleta_grupos ag
   where ag.atleta_id = p_atleta;

  return v_out;
end;
$$;

comment on function public.apo_grupos_de_atleta(uuid, uuid[], uuid) is
  'Deja los grupos de una persona tal y como se los pasas: los que sobran fuera, '
  'los que faltan dentro y uno marcado como principal. De una vez, para que un '
  'corte a mitad no deje a nadie fuera de su grupo sin que se note.';

revoke execute on function public.apo_grupos_de_atleta(uuid, uuid[], uuid) from public, anon;
grant  execute on function public.apo_grupos_de_atleta(uuid, uuid[], uuid) to authenticated;

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- nadie con grupo se ha quedado fuera de la tabla nueva
--   select count(*) from atletas a
--    where a.grupo_id is not null
--      and not exists (select 1 from atleta_grupos ag
--                       where ag.atleta_id = a.id and ag.grupo_id = a.grupo_id);
--   -- tiene que dar 0
--
--   -- nadie tiene dos principales
--   select atleta_id from atleta_grupos where principal
--    group by atleta_id having count(*) > 1;
--   -- tiene que salir vacío
--
--   -- el visitante sin cuenta no ve nada
--   begin; set local role anon;
--     select count(*) from atleta_grupos;   -- 0
--   rollback;
--
--   -- y con cuenta, solo lo suyo
--   begin; set local role authenticated;
--     set local request.jwt.claims to '{"email":"…","role":"authenticated"}';
--     select count(*) from atleta_grupos;
--   rollback;
-- ------------------------------------------------------------
