-- =====================================================================
-- 067_retos_propios.sql  ·  LOS RETOS QUE SE PONE UNO MISMO
-- =====================================================================
-- Para qué sirve:
--
--   045 trajo los retos DEL CLUB: los propone el club, dan puntos y
--   suben de rango. Esto es lo contrario y convive con aquello: un reto
--   que se pone uno solo, para verse mejorar. «Catorce días de entreno
--   este mes.» Nada más.
--
-- LAS CINCO REGLAS, que son el motivo de todo lo de abajo
--   1. Los tuyos van en navy y los del club en ámbar. Los tuyos, sin
--      icono y SIN PUNTOS; los del club, con su icono y su «+40».
--   2. Sin puntos a propósito. Si un reto propio diera puntos,
--      cualquiera se pondría «entrenar 1 día» y subiría de rango. Por
--      eso aquí NO hay ninguna columna de puntos y nada toca
--      perfil_juego.puntos ni juego_rangos.
--   3. Se cuentan solos, con lo que el club ya apunta cada día. NADA de
--      apuntar a mano: un reto que hay que ir marcando se abandona en
--      dos semanas. Por eso no existe ninguna columna de «llevo X»: el
--      valor se calcula siempre, cada vez que se mira.
--   4. El objetivo se propone con el historial de esa persona («el mes
--      pasado hiciste 11, tu mejor mes 15»). De ahí sale
--      retos_propios_historial().
--   5. Máximo tres a la vez, y se pueden editar o borrar sin dar
--      explicaciones. Un reto personal que no se puede quitar deja de
--      ser un reto y pasa a ser un reproche.
--
-- LO QUE NO HACE, Y ES PARTE DEL DISEÑO
--   · No da puntos ni sube de rango.
--   · NO SALE EN NINGÚN SITIO DEL CLUB. No hay ninguna vista pública,
--     ni entra en miembros_juego, ni en la clasificación.
--   · NO LO VE EL ENTRENADOR. Ojo con esto: mis_atletas() incluye a los
--     atletas de un entrenador, así que aquí NO se puede usar. La
--     guardia es reto_propio_mio(), que solo mira la cuenta de la propia
--     persona y la de su familia.
--   · Tampoco lo ve el administrador. Es a propósito.
--
-- QUÉ SE SABE CONTAR DE VERDAD (y qué no)
--   días de entreno  · SÍ · los días que consta que entrenaste: lista
--                      pasada por el entrenador (asistencia.presente) o
--                      entreno contado por ti (registros_sesion).
--   metros a nado    · SÍ · la suma de las series por su distancia de
--                      los entrenos de natación en los que constas.
--   competiciones    · SÍ · competiciones distintas con la inscripción
--                      confirmada.
--   kilómetros       · NO · las distancias de un entreno se escriben en
--                      texto libre y mezclan minutos, metros, kilómetros
--                      y «40 min en bici». No hay de dónde sacar un
--                      total honesto, así que no se ofrece.
--   desnivel         · NO · no existe en ninguna tabla. Un contador que
--                      siempre marca cero es peor que no ofrecerlo.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/067_retos_propios.sql
-- Se puede volver a lanzar las veces que haga falta: no rompe nada.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. DE QUÉ DÍA A QUÉ DÍA CUENTA UN RETO PROPIO
-- ---------------------------------------------------------------------
-- Los del club tienen su propio reto_rango() con semana, mes, temporada
-- y fechas sueltas. Los propios solo ofrecen tres plazos —este mes, este
-- trimestre y la temporada— y el trimestre va pegado a la temporada
-- deportiva, no al año natural: septiembre-noviembre, diciembre-febrero,
-- marzo-mayo y junio-agosto. Por eso hace falta esta función aparte.
create or replace function public.reto_propio_rango(p_periodo text, p_hoy date default current_date)
returns table (desde date, hasta date)
language sql stable
as $function$
  with ini as (
    select case p_periodo
             when 'trimestre' then
               (date_trunc('month', p_hoy::timestamp)
                 - ((((extract(month from p_hoy)::int - 9 + 12) % 12) % 3) * interval '1 month'))::date
             when 'temporada' then
               case when extract(month from p_hoy) >= 9
                    then make_date(extract(year from p_hoy)::int,     9, 1)
                    else make_date(extract(year from p_hoy)::int - 1, 9, 1) end
             else date_trunc('month', p_hoy::timestamp)::date
           end as d
  )
  select d,
         case p_periodo
           when 'trimestre' then (d + interval '3 months' - interval '1 day')::date
           when 'temporada' then (d + interval '1 year'   - interval '1 day')::date
           else                  (d + interval '1 month'  - interval '1 day')::date
         end
    from ini;
$function$;

comment on function public.reto_propio_rango(text,date) is
  'Convierte el plazo de un reto propio (mes/trimestre/temporada) en dos fechas. El trimestre va pegado a la temporada deportiva: sep-nov, dic-feb, mar-may, jun-ago.';


-- ---------------------------------------------------------------------
-- 2. LOS METROS DE UN ENTRENO DE NATACIÓN
-- ---------------------------------------------------------------------
-- Los entrenos se guardan en sesiones.bloques, y cada fila lleva sus
-- series («8») y su distancia escrita a mano («100 m», «1.500 m»,
-- «4 x 25 m»). Aquí se suman solo las filas que de verdad son metros:
-- «10 min», «30 s», «12 rep» o «1 vez» se dejan fuera, porque sumarlas
-- daría un total falso.
create or replace function public.reto_propio_metros(p_bloques jsonb)
returns numeric
language plpgsql immutable
as $function$
declare
  v_total numeric := 0;
  b jsonb; f jsonb;
  d text; v_series numeric; v_mult numeric; v_metros numeric;
begin
  if p_bloques is null or jsonb_typeof(p_bloques) <> 'array' then
    return 0;
  end if;

  for b in select * from jsonb_array_elements(p_bloques) loop
    if jsonb_typeof(coalesce(b -> 'filas', 'null'::jsonb)) <> 'array' then
      continue;
    end if;
    for f in select * from jsonb_array_elements(b -> 'filas') loop
      -- El punto de los miles es de la escritura, no del número: «1.500 m».
      d := replace(btrim(coalesce(f ->> 'distancia', '')), '.', '');

      v_mult := 1;
      -- «4 x 25 m» dentro de una misma fila.
      if d ~ '^[0-9]+[[:space:]]*[xX×][[:space:]]*[0-9]+[[:space:]]*m$' then
        v_mult := (regexp_replace(d, '^([0-9]+)[[:space:]]*[xX×].*$', '\1'))::numeric;
        d      := regexp_replace(d, '^[0-9]+[[:space:]]*[xX×][[:space:]]*', '');
      end if;

      -- Solo metros. «10 min», «30 s», «5 km» y «400 m vallas» se caen aquí.
      if d !~ '^[0-9]+[[:space:]]*m$' then
        continue;
      end if;
      v_metros := (regexp_replace(d, '[[:space:]]*m$', ''))::numeric;

      v_series := case when coalesce(f ->> 'series', '') ~ '^[0-9]+$'
                       then (f ->> 'series')::numeric else 1 end;

      v_total := v_total + v_mult * v_metros * v_series;
    end loop;
  end loop;

  return v_total;
end;
$function$;

comment on function public.reto_propio_metros(jsonb) is
  'Metros de un entreno de natación: series por distancia de cada fila. Las filas que no están escritas en metros no suman.';


-- ---------------------------------------------------------------------
-- 3. EL CONTADOR · cuánto llevas de verdad entre dos fechas
-- ---------------------------------------------------------------------
-- Es el corazón del «se cuentan solos». No lo llama nadie desde el
-- navegador: va con security definer porque tiene que leer sesiones y
-- asistencias, y devolvería datos de cualquiera si se pudiera llamar
-- con un atleta ajeno. Quien comprueba de quién es cada cosa son las
-- funciones del punto 6, que sí están abiertas.
create or replace function public.reto_propio_valor(
  p_atleta uuid, p_metrica text, p_desde date, p_hasta date)
returns numeric
language plpgsql stable security definer set search_path to 'public'
as $function$
declare v numeric := 0;
begin
  if p_atleta is null or p_desde is null or p_hasta is null then
    return 0;
  end if;

  if p_metrica = 'dias_entreno' then
    -- Un día cuenta si el entrenador te pasó lista o si contaste tú el
    -- entreno. Días distintos: dos entrenos el mismo día son un día.
    select count(*) into v from (
      select a.fecha as f
        from public.asistencia a
       where a.atleta_id = p_atleta
         and a.presente is true
         and a.fecha between p_desde and p_hasta
      union
      select s.fecha
        from public.registros_sesion r
        join public.sesiones s on s.id = r.sesion_id
       where r.atleta_id = p_atleta
         and s.fecha between p_desde and p_hasta
    ) dias;

  elsif p_metrica = 'metros_natacion' then
    select coalesce(sum(public.reto_propio_metros(s.bloques)), 0) into v
      from public.sesiones s
     where s.tipo = 'natacion'
       and s.fecha between p_desde and p_hasta
       and ( exists (select 1 from public.asistencia a
                      where a.sesion_id = s.id and a.atleta_id = p_atleta and a.presente is true)
          or exists (select 1 from public.registros_sesion r
                      where r.sesion_id = s.id and r.atleta_id = p_atleta) );

  elsif p_metrica = 'competiciones' then
    select count(distinct ca.competicion_id) into v
      from public.competicion_atleta ca
      join public.competiciones c on c.id = ca.competicion_id
     where ca.atleta_id = p_atleta
       and ca.estado = 'confirmada'
       and c.fecha_inicio between p_desde and p_hasta;
  end if;

  return coalesce(v, 0);
end;
$function$;

comment on function public.reto_propio_valor(uuid,text,date,date) is
  'Cuánto lleva una persona en una métrica de reto propio entre dos fechas. Uso interno: nadie la llama desde el navegador.';


-- ---------------------------------------------------------------------
-- 4. DE QUIÉN ES ESTE RETO
-- ---------------------------------------------------------------------
-- ⚠️ Aquí está el punto delicado de toda la migración.
--
-- El resto del proyecto usa mis_atletas() para decir «los míos», pero
-- esa función incluye `entrenador_id = mi_perfil_id()`: con ella, un
-- entrenador vería los retos personales de todos sus atletas. Y estos
-- retos NO los ve el entrenador. Tampoco el administrador.
--
-- Así que la guardia es esta y solo esta: la cuenta de la propia
-- persona y la de su familia, que es la que le lleva el portal a un
-- menor. Ni es_staff(), ni es_admin(), ni entrenador_id.
create or replace function public.reto_propio_mio(p_atleta uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select p_atleta is not null
     and public.mi_perfil_id() is not null
     and exists (
           select 1 from public.atletas a
            where a.id = p_atleta
              and (a.perfil_id       = public.mi_perfil_id()
                or a.perfil_padre_id = public.mi_perfil_id())
         );
$function$;

comment on function public.reto_propio_mio(uuid) is
  'Verdadero solo para la cuenta de esa persona o la de su familia. A propósito NO cubre a entrenadores ni a administración: los retos propios no los ve el club.';


-- ---------------------------------------------------------------------
-- 5. LA TABLA
-- ---------------------------------------------------------------------
-- No hay columna de puntos (regla 2) ni columna de progreso (regla 3):
-- lo que llevas se calcula, nunca se guarda, así que no se puede
-- inflar a mano ni quedarse desfasado.
create table if not exists public.retos_propios (
  id          uuid primary key default gen_random_uuid(),
  atleta_id   uuid not null references public.atletas(id) on delete cascade,
  metrica     text not null,
  objetivo    numeric not null,
  periodo     text not null,
  -- El plazo se congela el día que se pone el reto: «este mes» quiere
  -- decir ESTE, y cuando se acaba el reto se cierra en vez de empezar
  -- otra vez de cero sin avisar.
  -- Con valor por defecto para que la pantalla no tenga ni que mandarlos:
  -- los pone la guardia de abajo a partir del plazo elegido.
  desde       date not null default current_date,
  hasta       date not null default current_date,
  creado_en   timestamptz not null default now(),
  actualizado timestamptz not null default now()
);

-- Por si la tabla venía de una versión anterior de este archivo sin ellos.
alter table public.retos_propios alter column desde set default current_date;
alter table public.retos_propios alter column hasta set default current_date;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'retos_propios_metrica_check') then
    alter table public.retos_propios add constraint retos_propios_metrica_check
      check (metrica in ('dias_entreno','metros_natacion','competiciones'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'retos_propios_periodo_check') then
    alter table public.retos_propios add constraint retos_propios_periodo_check
      check (periodo in ('mes','trimestre','temporada'));
  end if;
  -- Un objetivo de cero no es un reto, y uno de un millón tampoco.
  if not exists (select 1 from pg_constraint where conname = 'retos_propios_objetivo_check') then
    alter table public.retos_propios add constraint retos_propios_objetivo_check
      check (objetivo > 0 and objetivo <= 1000000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'retos_propios_fechas_check') then
    alter table public.retos_propios add constraint retos_propios_fechas_check
      check (hasta >= desde);
  end if;
end $$;

create index if not exists idx_retos_propios_atleta on public.retos_propios (atleta_id, hasta desc);

comment on table  public.retos_propios is
  'Un reto que se pone una persona a sí misma. No da puntos, no sube de rango y no lo ve nadie más: ni el entrenador, ni administración, ni el resto del club.';
comment on column public.retos_propios.metrica is
  'Qué se cuenta: dias_entreno · metros_natacion · competiciones. Kilómetros y desnivel no se ofrecen porque no hay de dónde sacarlos.';
comment on column public.retos_propios.desde is
  'Primer día del plazo, congelado el día que se puso el reto.';
comment on column public.retos_propios.hasta is
  'Último día del plazo. Pasado ese día el reto se cierra: no se reinicia solo.';


-- ---------------------------------------------------------------------
-- 5 bis. GUARDIA DE LA TABLA
-- ---------------------------------------------------------------------
-- Tres cosas, y las tres las decide la base de datos y no el navegador:
--   · el plazo se calcula aquí, no se acepta el que llegue de fuera;
--   · el reto no cambia de dueño ni de fecha de creación al editarlo;
--   · máximo tres en marcha a la vez (regla 5). Un reto ya conseguido
--     NO ocupa sitio: si has llegado a tu objetivo, puedes ponerte el
--     siguiente sin tener que borrar el que acabas de ganar.
create or replace function public.retos_propios_guardia()
returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_rango record;
  v_enmarcha int;
begin
  new.actualizado := now();

  if tg_op = 'INSERT' then
    new.creado_en := now();
    select r.desde, r.hasta into v_rango from public.reto_propio_rango(new.periodo, current_date) r;
    new.desde := v_rango.desde;
    new.hasta := v_rango.hasta;
  else
    new.atleta_id := old.atleta_id;
    new.creado_en := old.creado_en;
    if new.periodo is distinct from old.periodo then
      select r.desde, r.hasta into v_rango from public.reto_propio_rango(new.periodo, current_date) r;
      new.desde := v_rango.desde;
      new.hasta := v_rango.hasta;
    else
      new.desde := old.desde;
      new.hasta := old.hasta;
    end if;
  end if;

  if tg_op = 'INSERT' then
    select count(*) into v_enmarcha
      from public.retos_propios r
     where r.atleta_id = new.atleta_id
       and r.hasta >= current_date
       and public.reto_propio_valor(r.atleta_id, r.metrica, r.desde, r.hasta) < r.objetivo;
    if v_enmarcha >= 3 then
      raise exception 'Ya llevas tres retos en marcha. Quita uno y te pones este.'
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_retos_propios_guardia on public.retos_propios;
create trigger trg_retos_propios_guardia
before insert or update on public.retos_propios
for each row execute function public.retos_propios_guardia();


-- ---------------------------------------------------------------------
-- 6. LO QUE SÍ SE LLAMA DESDE LA PANTALLA
-- ---------------------------------------------------------------------

-- 6.1 Cómo va cada uno de mis retos. Se calcula al vuelo, siempre.
create or replace function public.retos_propios_progreso(p_atleta uuid)
returns table (reto_id uuid, valor numeric)
language plpgsql stable security definer set search_path to 'public'
as $function$
begin
  -- El «is null» va dentro de reto_propio_mio(): un nulo no es un permiso.
  if not public.reto_propio_mio(p_atleta) then
    raise exception 'Los retos que se pone uno mismo solo los ve esa persona.';
  end if;
  return query
    select r.id, public.reto_propio_valor(p_atleta, r.metrica, r.desde, r.hasta)
      from public.retos_propios r
     where r.atleta_id = p_atleta;
end;
$function$;

comment on function public.retos_propios_progreso(uuid) is
  'Cuánto lleva esa persona en cada uno de sus retos propios. Solo para su propia cuenta o la de su familia.';

-- 6.2 EL HISTORIAL, que es lo que hace que el objetivo no se ponga al azar
-- Para cada plazo devuelve lo que lleva ahora, lo que hizo en el plazo
-- anterior y su mejor plazo, con la fecha en que empezó ese mejor plazo
-- para que la pantalla lo escriba en cristiano («tu mejor mes, junio»).
create or replace function public.retos_propios_historial(p_atleta uuid, p_metrica text)
returns table (periodo text, actual numeric, anterior numeric, mejor numeric, mejor_desde date)
language plpgsql stable security definer set search_path to 'public'
as $function$
declare
  v_per text;
  v_cuantos int;
  i int;
  v_ini date; v_fin date; v_v numeric;
  v_atras interval;
begin
  if not public.reto_propio_mio(p_atleta) then
    raise exception 'El historial de una persona solo lo ve ella.';
  end if;
  if p_metrica not in ('dias_entreno','metros_natacion','competiciones') then
    return;
  end if;

  foreach v_per in array array['mes','trimestre','temporada'] loop
    v_cuantos := case v_per when 'mes' then 12 when 'trimestre' then 4 else 3 end;
    v_atras   := case v_per when 'mes' then interval '1 month'
                            when 'trimestre' then interval '3 months'
                            else interval '1 year' end;

    select r.desde, r.hasta into v_ini, v_fin from public.reto_propio_rango(v_per, current_date) r;
    actual   := public.reto_propio_valor(p_atleta, p_metrica, v_ini, v_fin);
    anterior := 0;
    mejor    := 0;
    mejor_desde := null;

    for i in 1..v_cuantos loop
      select r.desde, r.hasta into v_ini, v_fin
        from public.reto_propio_rango(v_per, (current_date - (i * v_atras))::date) r;
      v_v := public.reto_propio_valor(p_atleta, p_metrica, v_ini, v_fin);
      if i = 1 then anterior := v_v; end if;
      if v_v > mejor then mejor := v_v; mejor_desde := v_ini; end if;
    end loop;

    periodo := v_per;
    return next;
  end loop;
end;
$function$;

comment on function public.retos_propios_historial(uuid,text) is
  'Historial de esa persona en una métrica: lo que lleva ahora, el plazo anterior y su mejor plazo. Sirve para proponer un objetivo alcanzable en vez de un número al azar.';


-- ---------------------------------------------------------------------
-- 7. REGLAS DE SEGURIDAD (RLS)
-- ---------------------------------------------------------------------
-- Cada uno ve y toca los suyos. Nadie más: ni el entrenador, ni
-- administración, ni el resto del club. Sin política para es_staff() ni
-- para es_admin() a propósito.
alter table public.retos_propios enable row level security;

drop policy if exists "retos propios: solo los suyos" on public.retos_propios;
create policy "retos propios: solo los suyos" on public.retos_propios
for select to authenticated
using (public.reto_propio_mio(atleta_id));

drop policy if exists "retos propios: se los pone uno mismo" on public.retos_propios;
create policy "retos propios: se los pone uno mismo" on public.retos_propios
for insert to authenticated
with check (public.reto_propio_mio(atleta_id));

drop policy if exists "retos propios: los edita uno mismo" on public.retos_propios;
create policy "retos propios: los edita uno mismo" on public.retos_propios
for update to authenticated
using (public.reto_propio_mio(atleta_id))
with check (public.reto_propio_mio(atleta_id));

-- Sin dar explicaciones: se quita y ya está (regla 5).
drop policy if exists "retos propios: los quita uno mismo" on public.retos_propios;
create policy "retos propios: los quita uno mismo" on public.retos_propios
for delete to authenticated
using (public.reto_propio_mio(atleta_id));


-- ---------------------------------------------------------------------
-- 8. PERMISOS DE VERDAD, NO SOLO POLÍTICAS
-- ---------------------------------------------------------------------
-- ⚠️ Supabase reparte permisos solo a `anon` y `authenticated` sobre
-- todo lo que se crea (alter default privileges … grant all). Las
-- políticas de arriba no sirven de nada si el permiso de tabla está mal
-- dado, así que aquí se quita todo y se vuelve a dar lo justo. En este
-- proyecto se ha escapado cuatro veces: no se borre este bloque.
--
-- Ojo también con `authenticated`: de fábrica se le da TODO, y ese todo
-- incluye TRUNCATE, que se salta las reglas de RLS y vaciaría la tabla
-- entera de un tirón. Por eso se le quita también a él y se le devuelven
-- las cuatro operaciones de siempre y ni una más.
revoke all on public.retos_propios from public, anon, authenticated;
grant select, insert, update, delete on public.retos_propios to authenticated;

-- Las de cálculo interno no las llama nadie desde fuera.
revoke all on function public.reto_propio_valor(uuid,text,date,date) from public, anon, authenticated;
revoke all on function public.reto_propio_metros(jsonb)              from public, anon, authenticated;

-- Y las que sí se llaman, solo con la sesión abierta.
revoke all on function public.reto_propio_rango(text,date)           from public, anon;
revoke all on function public.reto_propio_mio(uuid)                  from public, anon;
revoke all on function public.retos_propios_progreso(uuid)           from public, anon;
revoke all on function public.retos_propios_historial(uuid,text)     from public, anon;

grant execute on function public.reto_propio_rango(text,date)        to authenticated;
grant execute on function public.reto_propio_mio(uuid)               to authenticated;
grant execute on function public.retos_propios_progreso(uuid)        to authenticated;
grant execute on function public.retos_propios_historial(uuid,text)  to authenticated;

commit;


-- --- Comprobación rápida ---------------------------------------------
-- 1) Los permisos REALES de la tabla, que es lo que se escapa.
select grantee, string_agg(privilege_type, ', ' order by privilege_type) as permisos
  from information_schema.role_table_grants
 where table_schema = 'public' and table_name = 'retos_propios'
   and grantee in ('anon','authenticated','public')
 group by grantee
 order by grantee;

-- 2) Quién puede ejecutar cada función.
select p.proname,
       coalesce(has_function_privilege('anon',          p.oid, 'execute'), false) as anon,
       coalesce(has_function_privilege('authenticated', p.oid, 'execute'), false) as autenticado
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('reto_propio_rango','reto_propio_metros','reto_propio_valor',
                     'reto_propio_mio','retos_propios_progreso','retos_propios_historial')
 order by p.proname;

-- 3) Las políticas: ninguna puede nombrar a es_staff ni a es_admin.
select policyname, cmd, qual, with_check
  from pg_policies
 where schemaname = 'public' and tablename = 'retos_propios'
 order by policyname;

-- 4) Los tres plazos, tal y como salen hoy.
select p as plazo, r.desde, r.hasta
  from unnest(array['mes','trimestre','temporada']) p,
       lateral public.reto_propio_rango(p, current_date) r;
