-- 041_seguridad.sql
-- Cierra tres fallos de la auditoría RLS (docs/auditoria-seguridad.md):
--   1) [ALTA]  vistas sesiones_agenda y cubo_clases_ocupacion sin security_invoker
--   2) [ALTA]  cubo_es_gestor() daba mando del Cubo a CUALQUIER entrenador
--   3) [MEDIA] el cliente fijaba el precio de su pedido
-- Idempotente: se puede aplicar más de una vez sin efectos raros.

begin;

-- ============================================================================
-- FALLO 1 (ALTA) · Vistas sin security_invoker = RLS saltada (hasta anónimos)
-- ============================================================================
-- DECISIÓN Y PORQUÉ (se tratan las dos vistas distinto a propósito):
--
--   AVISO DE ALCANCE (efecto secundario asumido): la home pública (index.html)
--   y la página pública /calendario usaban estas vistas para pintar el
--   calendario a visitantes SIN cuenta. Tras este cambio esas dos pantallas
--   dejan de mostrar la agenda a quien no ha iniciado sesión. Es lo que pide la
--   auditoría: no regalar a Internet la agenda completa de todos los grupos.
--   Las pantallas del PORTAL (portal/calendario, portal/cubo, portal/entrenador)
--   y El Cubo, que se consultan con sesión iniciada, siguen funcionando.
--
-- · cubo_clases_ocupacion -> SECURITY INVOKER = true.
--     La tabla base `cubo_clases` ya deja leer a cualquier 'authenticated'
--     (política "ver clases del cubo" USING true) y NO tiene política para
--     'anon'. Con invoker, el miembro sigue viendo todas las clases del Cubo y
--     el anónimo pasa a ver 0 filas. Limpio y sin exponer nada de más.
--
-- · sesiones_agenda -> se queda como SECURITY DEFINER (invoker=false) y se
--     RETIRA el acceso del rol 'anon' (REVOKE). ¿Por qué NO invoker aquí?
--     Porque sesiones_agenda es una vista CURADA: enseña solo
--     fecha/hora/lugar/grupo/ocupación, nunca el contenido del entrenamiento.
--     Con invoker, un atleta solo vería su propio grupo, así que habría que
--     abrir SELECT de la tabla base `sesiones` a 'authenticated'... y eso
--     expondría a CUALQUIER miembro columnas que la vista oculta a propósito
--     (`bloques` = ejercicios/series, `nota_razonamiento`) de TODOS los grupos.
--     Sería cambiar una fuga (anónimo) por otra (miembros leen el entrenamiento
--     ajeno). En su lugar: la vista sigue mostrando el calendario curado del
--     club a los miembros, el anónimo pierde el acceso, y el contenido íntegro
--     de cada sesión sigue protegido por la RLS de `sesiones` (cada quien ve
--     solo su grupo). Por eso NO se añade ninguna política nueva a `sesiones`.
--
-- El recuento de apuntados/ocupación se calcula con funciones SECURITY DEFINER:
-- así es correcto también cuando cubo_clases_ocupacion corre como invoker (un
-- atleta no puede contar reservas ajenas por RLS). Las funciones solo devuelven
-- un número (no filas ajenas, no nombres).

-- (b) Funciones de recuento — cuentan de verdad, sin filtrar por RLS.
create or replace function public.sesion_num_apuntados(p_sesion uuid)
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::int from public.sesion_inscripciones where sesion_id = p_sesion;
$$;

create or replace function public.cubo_clase_ocupadas(p_clase uuid)
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::int from public.cubo_reservas
   where clase_id = p_clase and estado in ('reservada','asistida','no_asistida');
$$;

create or replace function public.cubo_clase_en_espera(p_clase uuid)
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::int from public.cubo_reservas
   where clase_id = p_clase and estado = 'lista_espera';
$$;

-- Solo los usuarios con sesión pueden calcular estos recuentos (el anónimo no
-- debe poder sondear la ocupación ni siquiera llamando a la función).
revoke all on function public.sesion_num_apuntados(uuid) from public;
revoke all on function public.cubo_clase_ocupadas(uuid)  from public;
revoke all on function public.cubo_clase_en_espera(uuid) from public;
grant execute on function public.sesion_num_apuntados(uuid) to authenticated;
grant execute on function public.cubo_clase_ocupadas(uuid)  to authenticated;
grant execute on function public.cubo_clase_en_espera(uuid) to authenticated;

-- Vistas recreadas con las MISMAS columnas (mismo nombre/orden/tipo), pero
-- usando las funciones definer para el recuento en vez de subconsultas.
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
         case when s.plazas is null then null
              else greatest(0, s.plazas - public.sesion_num_apuntados(s.id))::int end as libres
    from public.sesiones s
    left join public.grupos g on g.id = s.grupo_id
   where coalesce(s.publicada, false)
     and (s.atletas_ids is null or coalesce(s.abierta_inscripcion, false));

create or replace view public.cubo_clases_ocupacion as
  select c.id as clase_id,
         c.fecha,
         c.hora_inicio,
         c.hora_fin,
         c.titulo,
         c.notas,
         c.activa,
         c.plazas,
         coalesce(nullif(trim(p.nombre || ' ' || coalesce(p.apellidos, '')), ''), c.monitor_nombre) as monitor,
         public.cubo_clase_ocupadas(c.id)  as ocupadas,
         public.cubo_clase_en_espera(c.id) as en_espera,
         greatest(0, c.plazas - public.cubo_clase_ocupadas(c.id))::int as libres
    from public.cubo_clases c
    left join public.perfiles p on p.id = c.monitor_id;

-- cubo_clases_ocupacion: invoker (anón ve 0 por RLS; miembro ve todo el Cubo).
alter view public.cubo_clases_ocupacion set (security_invoker = true);

-- sesiones_agenda: sigue definer (vista curada) pero SIN el rol anónimo.
alter view public.sesiones_agenda set (security_invoker = false);
revoke all on public.sesiones_agenda from anon;
revoke all on public.sesiones_agenda from public;
grant select on public.sesiones_agenda to authenticated;

-- Se RETIRA cualquier política amplia sobre la tabla base `sesiones`: no debe
-- abrirse el contenido de las sesiones (bloques/nota_razonamiento) a todos los
-- miembros. El calendario del club llega por la vista curada, no por la tabla.
drop policy if exists "miembros ven agenda publicada" on public.sesiones;


-- ============================================================================
-- FALLO 2 (ALTA) · cubo_es_gestor() convertía a CUALQUIER entrenador en gestor
-- ============================================================================
-- DECISIÓN Y PORQUÉ:
-- Antes: es_admin() OR rol in ('admin','coordinador','entrenador') -> todo
-- entrenador del club mandaba sobre bonos/reservas/movimientos/clases de El
-- Cubo. Ahora es gestor SOLO quien de verdad lo gestiona:
--   · admin, y
--   · quien está asignado a El Cubo: el/los entrenador(es) de un grupo de
--     sección 'cubo' (grupos.entrenador_id) o un monitor de sus clases
--     (cubo_clases.monitor_id).
-- Se incluye al monitor de clases porque "quien de verdad gestiona El Cubo"
-- también son sus monitores (p. ej. Álvaro Peñalver imparte clases del Cubo sin
-- ser el entrenador del grupo); dejarlo fuera rompería su gestión legítima. Un
-- entrenador de atletismo ajeno al Cubo (sin grupo 'cubo' ni clases) deja de
-- tener acceso.
create or replace function public.cubo_es_gestor()
returns boolean language sql stable security definer set search_path = public as $$
  select public.es_admin() or exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and (
        exists (select 1 from public.grupos g
                 where g.seccion = 'cubo' and g.entrenador_id = p.id)
        or exists (select 1 from public.cubo_clases c
                    where c.monitor_id = p.id)
      )
  );
$$;


-- ============================================================================
-- FALLO 3 (MEDIA) · El socio ponía el precio de su propio pedido
-- ============================================================================
-- DECISIÓN Y PORQUÉ:
-- El servidor pasa a ser la única autoridad sobre importes:
--   · BEFORE INSERT/UPDATE en pedido_items: precio_unitario = productos.precio
--     (se ignora lo que mande el cliente).
--   · AFTER INSERT/UPDATE/DELETE en pedido_items: pedidos.total se recalcula
--     como la suma de cantidad*precio_unitario de sus líneas.
--   · BEFORE INSERT en pedidos: el total nace recalculado desde las líneas
--     (0 al crear, porque las líneas se insertan después), así el total que
--     manda el cliente no cuenta.
-- Los triggers son SECURITY DEFINER porque el socio no tiene política UPDATE
-- sobre pedidos; recalcular el total exige saltar la RLS (con dueño postgres).

create or replace function public.pedido_item_fija_precio()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_precio numeric;
begin
  select precio into v_precio from public.productos where id = new.producto_id;
  if v_precio is null then
    raise exception 'Producto % inexistente o sin precio', new.producto_id;
  end if;
  new.precio_unitario := v_precio;   -- el cliente no decide el precio
  return new;
end;
$$;

create or replace function public.pedido_recalcula_total()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_pedido uuid;
begin
  v_pedido := coalesce(new.pedido_id, old.pedido_id);
  update public.pedidos p
     set total = coalesce((select sum(i.cantidad * i.precio_unitario)
                             from public.pedido_items i
                            where i.pedido_id = v_pedido), 0)
   where p.id = v_pedido;
  -- si un UPDATE movió la línea a otro pedido, recalcula también el de origen
  if tg_op = 'UPDATE' and old.pedido_id is distinct from new.pedido_id then
    update public.pedidos p
       set total = coalesce((select sum(i.cantidad * i.precio_unitario)
                               from public.pedido_items i
                              where i.pedido_id = old.pedido_id), 0)
     where p.id = old.pedido_id;
  end if;
  return null;
end;
$$;

create or replace function public.pedido_total_cero_al_crear()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- al crear el pedido aún no hay líneas: el total lo fijan luego los items
  new.total := coalesce((select sum(i.cantidad * i.precio_unitario)
                           from public.pedido_items i
                          where i.pedido_id = new.id), 0);
  return new;
end;
$$;

drop trigger if exists trg_pedido_item_precio on public.pedido_items;
create trigger trg_pedido_item_precio
  before insert or update on public.pedido_items
  for each row execute function public.pedido_item_fija_precio();

drop trigger if exists trg_pedido_item_total on public.pedido_items;
create trigger trg_pedido_item_total
  after insert or update or delete on public.pedido_items
  for each row execute function public.pedido_recalcula_total();

drop trigger if exists trg_pedido_total_crear on public.pedidos;
create trigger trg_pedido_total_crear
  before insert on public.pedidos
  for each row execute function public.pedido_total_cero_al_crear();

commit;
