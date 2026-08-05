-- ============================================================
-- 132 · Un aviso «a los entrenadores» es para quien entrena
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Cuando el club manda un aviso a un papel («a los entrenadores»,
-- «a administración»), la base solo mira el papel PRINCIPAL de cada
-- persona. Quien tiene ese papel como segundo se queda fuera.
--
-- POR QUÉ PASA
-- La ficha guarda dos cosas distintas y hasta hoy se usaba solo una:
--
--   · `rol`   → el papel principal, el que contesta a «¿qué eres tú
--               en el club?». Es UNO solo.
--   · `roles` → la lista entera de papeles que esa persona TIENE.
--
-- El reparto de avisos preguntaba `p.rol = p_rol`, o sea, el
-- principal. Y en este club casi nadie tiene uno solo:
--
--   · El tesorero tiene nueve papeles, y su principal es `admin`.
--     Entrena un grupo, pero un aviso a los entrenadores no le llega.
--   · El presidente, igual.
--   · Quien lleve El Cubo lo más seguro es que entrene algo también.
--
-- Un aviso que no llega a quien tiene que llegar es peor que no
-- mandarlo: el club se queda tranquilo pensando que ya avisó.
--
-- LO QUE SE ENCONTRÓ AL MEDIRLO, Y ES PEOR DE LO QUE PARECÍA
-- Con las fichas de hoy, preguntando a la base papel por papel:
--
--     papel          les llegaba   tendría que llegarles
--     entrenadores        10                12
--     coordinadores        0                 2
--     atletas              2                 4
--     familias             0                 2
--
-- La fila de coordinadores es la que más asusta: un aviso a la
-- coordinación no llegaba HOY a nadie, ni un móvil, y la pantalla
-- decía «0 personas» sin que nadie se preguntara por qué. Los dos
-- coordinadores del club lo son como segundo papel.
--
-- LO QUE SE HACE AQUÍ
-- Una línea: en vez del papel principal se mira la lista de papeles.
--
--     antes:    p.rol = p_rol
--     ahora:    p_rol = any(coalesce(p.roles, array[p.rol]))
--
-- OJO CON LA DIFERENCIA ENTRE TENER UN PAPEL Y LLEVARLO PUESTO
-- En este club son cosas distintas, y esta migración solo toca una:
--
--   · Para RECIBIR un aviso cuenta lo que se TIENE. Si entrenas un
--     grupo, los avisos a entrenadores son tuyos aunque en ese
--     momento estés mirando el portal como atleta. El aviso no sabe
--     ni le importa qué pestaña tienes abierta.
--   · Para HACER algo —entrar en una pantalla, tocar un dato— cuenta
--     el papel que se LLEVA PUESTO (`rol_activo`). Eso ya funciona
--     así y aquí no se toca ni una coma: `es_admin`, `es_staff`,
--     `ve_dinero`, `avisos_puede_enviar` y las reglas de las tablas
--     siguen exactamente igual. Esta migración no abre ni una
--     pantalla, ni un dato, ni un botón a nadie.
--
-- Es el mismo criterio, palabra por palabra, que ya usan los avisos
-- de altas y pedidos (`novedades_destinatarios`, migración 120) y el
-- reparto de los avisos de dinero (`dinero_destinatarios`). Ahora hay
-- una sola forma de decidir a quién se avisa en toda la base, en vez
-- de dos.
--
-- POR QUÉ ESTE SITIO Y NO CINCO
-- Todo lo que reparte avisos pasa por esta misma función, así que se
-- arregla una vez y se arregla entero:
--
--   avisos_perfiles_destino          ← lo que se cambia aquí
--     └ avisos_destino_perfiles      (quita los grupos excluidos)
--         ├ avisos_destinatarios     los móviles a los que sale
--         ├ avisos_alcance           «va a llegar a N aparatos»
--         ├ avisos_personas          «va a llegar a N personas»
--         ├ mis_avisos               la bandeja del portal
--         └ avisos_marcar_leido      marcar como leído
--
-- DOS CONSECUENCIAS QUE HAY QUE SABER, PORQUE SE VAN A NOTAR
--
--   1. Quien lleva muchos papeles va a recibir bastante más. El
--      tesorero tiene nueve, así que casi cualquier aviso por papel
--      va a ser suyo. Es lo correcto —los tiene todos de verdad—
--      pero no es un efecto secundario: es la razón del cambio. Si
--      algún día molesta, lo que hay que quitar es el papel de la
--      ficha, no volver a esconder el aviso.
--
--   2. La bandeja del portal mira hacia atrás. `mis_avisos` recorre
--      los avisos de los últimos meses con esta misma regla, así que
--      avisos viejos dirigidos a un papel van a aparecer de golpe en
--      la bandeja de quien tendría que haberlos recibido. No se ha
--      mandado nada nuevo al móvil: solo se enseña lo que ya era
--      suyo. Es incómodo un día y honesto para siempre.
--
-- LO QUE NO CAMBIA, Y ES A PROPÓSITO
--   · Los avisos a un grupo, a una persona o a todo el club: ni se
--     rozan, no miran papeles.
--   · Quién puede MANDAR avisos: sigue siendo el papel que se lleva
--     puesto (`avisos_puede_enviar`), y sigue siendo administración
--     y tesorería.
--   · Las preferencias: quien haya apagado una categoría la sigue
--     teniendo apagada. `avisos_quiere` se aplica después, igual.
--   · Los grupos excluidos de un aviso: igual.
--   · Las fichas activas: si alguien está de baja (`activo = false`)
--     no recibe nada, tenga los papeles que tenga.
--
-- EL `coalesce` DEL FINAL
-- Es por si queda alguna ficha antigua con el papel de siempre
-- (`rol`) y todavía sin la lista (`roles`). Hoy no hay ninguna —se
-- comprobó, las quince fichas tienen su lista y el papel principal
-- está dentro—, pero se deja puesto porque cuesta nada y evita que
-- una importación vieja deje a alguien sin avisos sin que se note.
--
-- COMPROBADO CONTRA LA BASE, CON LOS NÚMEROS DELANTE
-- Se preguntó papel por papel, antes y después, y además se simuló
-- entrar como personas concretas (`request.jwt.claims` + `set role`)
-- para mirar su bandeja de verdad, no la teoría.
--
--   AVISO A LOS ENTRENADORES
--     antes ...........................................  10 personas
--     después .........................................  12 personas
--     los dos que entran son quienes tienen `entrenador`
--     como segundo papel y entrenan de verdad .........   sí
--
--   AVISO A LOS COORDINADORES
--     antes ...........................................   0 personas
--     después .........................................   2 personas
--
--   LA CARA DE «NO SE ABRE DE MÁS»
--     personas SIN el papel a las que ahora les llega ..   0
--     personas de baja a las que les llega .............   0
--     avisos a un grupo, a una persona o a todo el club:
--       diferencia entre antes y después ...............   0
--
-- Todo el fichero se puede volver a pasar las veces que haga falta.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- A qué PERSONAS va un aviso, antes de mirar preferencias
-- ------------------------------------------------------------
-- Igual que estaba (migración 054), palabra por palabra, salvo la
-- línea del papel.
--
--   · todos   → todo el club con la ficha activa
--   · grupo   → los atletas de ese grupo, sus familias y quien lo
--               entrena (si mañana no hay entreno, el entrenador
--               también quiere enterarse)
--   · rol     → todos los que TIENEN ese papel, sea el principal o
--               uno de los otros
--   · persona → una sola
create or replace function public.avisos_perfiles_destino(
  p_publico text,
  p_grupo   uuid default null,
  p_rol     text default null,
  p_perfil  uuid default null
)
returns setof uuid
language sql stable security definer set search_path to 'public'
as $function$
  select p.id
    from public.perfiles p
   where coalesce(p.activo, true)
     and (
       (p_publico = 'todos')
       -- LOS PAPELES QUE TIENE, no el que lleva puesto ahora mismo:
       -- quien está mirando el portal como atleta sigue entrenando a
       -- su grupo, y el aviso a los entrenadores es suyo igual.
       or (p_publico = 'rol'     and p_rol    is not null
           and p_rol = any(coalesce(p.roles, array[p.rol])))
       or (p_publico = 'persona' and p_perfil is not null and p.id  = p_perfil)
       or (p_publico = 'grupo'   and p_grupo  is not null and (
             exists (select 1 from public.atletas a
                      where a.grupo_id = p_grupo
                        and (a.perfil_id = p.id or a.perfil_padre_id = p.id))
             or exists (select 1 from public.grupos g
                         where g.id = p_grupo and g.entrenador_id = p.id)
           ))
     );
$function$;

comment on function public.avisos_perfiles_destino(text, uuid, text, uuid) is
  'A qué personas va un aviso. Cuando va dirigido a un papel se miran TODOS los papeles que cada uno tiene, no solo el principal: quien entrena un grupo recibe los avisos a entrenadores aunque en el club sea sobre todo otra cosa.';

-- Nace cerrada, como manda la migración 090. Desde el navegador no se
-- llama nunca: quien la usa es la función `aviso-enviar`, que entra
-- con la llave de servicio del club, y las funciones de la bandeja,
-- que son SECURITY DEFINER y ya deciden ellas qué enseñan.
revoke all on function public.avisos_perfiles_destino(text, uuid, text, uuid)
  from public, anon, authenticated;
grant execute on function public.avisos_perfiles_destino(text, uuid, text, uuid)
  to service_role;

commit;
