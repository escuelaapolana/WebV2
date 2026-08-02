-- ============================================================
-- 082 · MIS AVISOS · que el socio vea los avisos que le llegaron
-- ------------------------------------------------------------
-- (El 081 ya lo ocupa 081_avisos_urgentes.sql, que va de la franja
--  de la portada. Este es el siguiente número libre.)
--
-- QUÉ RESUELVE, EN CRISTIANO
--   Hasta hoy, cuando a alguien le sonaba el móvil con un aviso del
--   club y lo tocaba, se le abría el portal a secas: el aviso ya no
--   estaba en ninguna parte. Y en su pantalla de avisos el bloque
--   «lo que se te ha ido acumulando» salía siempre vacío, porque
--   `avisos_enviados` SOLO la puede leer el equipo del club (054, 6.3).
--
--   Aquí se arreglan las dos cosas con una sola pieza:
--
--   1) `mis_avisos()` · devuelve a cada persona los avisos que le
--      tocaron a ELLA, con el texto entero. Ni uno más.
--   2) `avisos_registrar()` acepta ahora el identificador ya decidido
--      (`p_id`), para que el propio aviso pueda llevar a su pantalla:
--      `portal/avisos/?id=<id>`. Sin esto no se puede, porque el
--      identificador nacía DESPUÉS de mandar el aviso, y para entonces
--      ya era tarde para meterlo en el enlace.
--
-- ⚠️ LO QUE NO SE PUEDE VER DESDE AQUÍ
--   · Los avisos de otra persona (ni el título).
--   · A cuántos móviles llegó, a cuántos no, quién lo mandó ni a quién
--     iba. Eso es del panel del club y aquí no sale.
--   · Los buzones de nadie: esta función no toca `avisos_suscripciones`.
--   · Y `anon` no la puede llamar. Ni con la clave pública en la mano.
--
-- ⚠️ Supabase reparte EXECUTE a PUBLIC de serie en cada función nueva
--   del esquema public. No basta con no conceder: hay que QUITAR y
--   después conceder solo a `authenticated`. Van seis incidentes en
--   este proyecto por esto.
--
-- Idempotente: se puede relanzar sin perder nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/082_mis_avisos.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · MIS AVISOS · los que me tocaron a mí
-- ------------------------------------------------------------
-- Quién recibe qué se decide con las MISMAS dos piezas que usa el
-- servidor para mandarlos (054, 5.3 y 5.4). Ni una regla nueva, para
-- que no puedan separarse con el tiempo y acabar enseñando aquí algo
-- que allí no se mandó:
--   · `avisos_perfiles_destino()` → a quién iba (todos, grupo, papel,
--     persona), con el grupo mirado como entonces: atletas, sus
--     familias y quien lo entrena.
--   · `avisos_quiere()`           → y de eso, lo que la persona quiere
--     recibir. Si apagó «noticias del club», aquí tampoco las ve.
--
-- Con `p_id` devuelve UNO solo, el que se ha tocado en el móvil, y
-- pasa por el mismo filtro: si no era para ti, no hay fila y la
-- pantalla dice que no lo encuentra. Que es la verdad.
drop function if exists public.mis_avisos(uuid, integer);
drop function if exists public.mis_avisos();

create function public.mis_avisos(
  p_id     uuid    default null,
  p_limite integer default 20
)
returns table (
  id         uuid,
  titulo     text,
  cuerpo     text,
  url        text,
  categoria  text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare v_perfil uuid;
begin
  -- Sin ficha del club no hay avisos que enseñar. Se devuelve vacío,
  -- que es distinto de fallar: la pantalla ya lo cuenta a su manera.
  v_perfil := public.mi_perfil_id();
  if v_perfil is null then
    return;
  end if;

  return query
    select a.id, a.titulo, a.cuerpo, a.url, a.categoria, a.created_at
      from public.avisos_enviados a
     where (p_id is null or a.id = p_id)
       and public.avisos_quiere(v_perfil, a.categoria)
       and exists (
             select 1
               from public.avisos_perfiles_destino(
                      a.publico, a.grupo_id, a.rol, a.perfil_destino) d
              where d = v_perfil)
     order by a.created_at desc
     limit greatest(least(coalesce(p_limite, 20), 50), 1);
end;
$function$;

comment on function public.mis_avisos(uuid, integer) is
  'Los avisos al móvil que le tocaron a QUIEN LLAMA, con el texto entero. Respeta a quién iba y lo que esa persona quiere recibir. No enseña los de otros, ni a cuántos llegó, ni quién lo mandó.';

-- El candado. Primero quitar —Supabase concede a PUBLIC de serie— y
-- después conceder solo a quien ha entrado en su cuenta.
revoke all on function public.mis_avisos(uuid, integer) from public;
revoke all on function public.mis_avisos(uuid, integer) from anon;
grant execute on function public.mis_avisos(uuid, integer) to authenticated;


-- ------------------------------------------------------------
-- 2 · REGISTRAR · con el identificador decidido de antemano
-- ------------------------------------------------------------
-- El aviso que se manda al móvil tiene que llevar dentro su propio
-- enlace, y ese enlace necesita el identificador. Como el aviso se
-- manda ANTES de apuntarlo en el historial, el identificador lo
-- decide la función del servidor (`aviso-enviar`) y lo pasa aquí.
-- Si no lo pasa —una versión antigua sin desplegar—, se genera como
-- siempre y no se rompe nada.
drop function if exists public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid);

create or replace function public.avisos_registrar(
  p_titulo    text,
  p_cuerpo    text,
  p_url       text,
  p_publico   text,
  p_categoria text,
  p_grupo     uuid,
  p_rol       text,
  p_perfil    uuid,
  p_texto     text,
  p_enviados  integer,
  p_fallidos  integer,
  p_autor     uuid,
  p_id        uuid default null
)
returns uuid
language plpgsql security definer set search_path to 'public'
as $function$
declare v_id uuid;
begin
  insert into public.avisos_enviados
    (id, titulo, cuerpo, url, publico, categoria, grupo_id, rol, perfil_destino,
     publico_texto, enviados, fallidos, creado_por)
  values
    (coalesce(p_id, gen_random_uuid()),
     p_titulo, p_cuerpo, nullif(btrim(coalesce(p_url,'')), ''), p_publico, p_categoria,
     p_grupo, p_rol, p_perfil, p_texto,
     greatest(coalesce(p_enviados,0),0), greatest(coalesce(p_fallidos,0),0), p_autor)
  returning id into v_id;
  return v_id;
end;
$function$;

comment on function public.avisos_registrar(text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid) is
  'Apunta en el historial un aviso ya mandado. Solo la llave de servicio. `p_id` viene decidido desde la función del servidor para que el propio aviso pueda enlazar a su pantalla.';

-- Escribe el historial: SOLO la llave de servicio. Ni anónimo, ni con
-- sesión, ni administrador. Si no, los números de «llegó a» se podrían
-- maquillar desde un navegador.
revoke all on function public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid)
  from public;
revoke all on function public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid)
  from anon;
revoke all on function public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid)
  from authenticated;
grant execute on function public.avisos_registrar(
  text, text, text, text, text, uuid, text, uuid, text, integer, integer, uuid, uuid)
  to service_role;

commit;


-- ============================================================
-- 3 · COMPROBACIÓN · quién puede llamar a qué
-- ------------------------------------------------------------
-- En `mis_avisos` debe salir SOLO `authenticated` (y postgres, que es
-- el dueño). En `avisos_registrar`, SOLO `service_role`.
-- ============================================================
select p.proname as funcion,
       coalesce(array_to_string(p.proacl, E'\n'), '(sin lista: lo puede llamar cualquiera ⚠️)') as quien_puede
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('mis_avisos','avisos_registrar')
 order by p.proname;
