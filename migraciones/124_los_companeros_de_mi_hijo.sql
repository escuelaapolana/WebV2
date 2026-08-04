-- ============================================================
-- 124 · En qué grupo está mi hijo y quiénes son sus compañeros
-- ------------------------------------------------------------
-- LO QUE PIDE EL CLUB, CON SUS PALABRAS
--   «Cada familia tiene que poder ver el grupo de su hijo y a sus
--    compañeros (con asteriscos para evitar decir el nombre).»
--
-- PARA QUÉ SIRVE ESTO DE VERDAD
-- Un padre quiere saber si su hija está con su amiga. Para eso le
-- basta RECONOCER un nombre que ya se sabe: ve «Lu*** Mar***» y
-- piensa «esa es Lucía Martínez», porque ya sabía que Lucía existe.
-- Lo que NO puede pasar es que ese mismo padre se lleve de aquí la
-- lista con el nombre y los apellidos de veinte menores del club.
--
-- Es decir: lo que se enseña tiene que ser RECONOCIBLE, no LEGIBLE.
--
-- ------------------------------------------------------------
-- POR QUÉ SE TAPA AQUÍ Y NO AL PINTAR LA PANTALLA
-- Esta es la decisión importante de todo el fichero.
--
-- Si el nombre entero viaja al navegador y los asteriscos se ponen
-- al dibujar la lista, la protección es un dibujo: cualquiera que
-- abra la consola del navegador —o mire la respuesta de la red— se
-- lleva los nombres completos de todos los críos del grupo. No hace
-- falta saber programar; hace falta saber pulsar F12.
--
-- Así que el nombre se corta ANTES DE SALIR DE LA BASE. Lo que se
-- manda al móvil del padre son ya los asteriscos: el nombre entero
-- no llega, no porque se esconda, sino porque nunca se envía.
--
-- Es lo mismo que ya hace el club en otros sitios:
--   · `contactos_publicos` (085) tapa teléfonos y correos;
--   · las vistas del panel de altas (115) tapan el DNI y el IBAN;
--   · `ranking_marcas` (058) deja el nombre en blanco cuando no hay
--     autorización de la familia.
-- Este fichero sigue exactamente ese camino.
--
-- ------------------------------------------------------------
-- CÓMO QUEDA UN NOMBRE TAPADO
-- Tres letras y tres asteriscos, en el nombre y en el primer
-- apellido:            Nombre Apellido  ->  Nom*** Ape***
--
-- Los asteriscos son SIEMPRE TRES, largo el nombre o corto. Si
-- fueran uno por letra escondida, la lista estaría diciendo cuántas
-- letras tiene cada nombre, que es un dato de más y gratis.
--
-- Y estos son los casos raros, que en un club de 200 críos salen
-- todos tarde o temprano:
--
--   · NOMBRES CORTOS. «Ana» no se puede quedar en «Ana***», porque
--     eso no tapa nada: es el nombre entero con adorno. La regla es
--     que SIEMPRE tiene que quedar escondida por lo menos una letra.
--     Ana -> An***     Jose -> Jos***     Jo -> J***
--
--   · NOMBRES COMPUESTOS. «María del Carmen» se queda en «Mar***»:
--     solo la primera palabra. Enseñar las dos («Mar*** del Car***»)
--     sería dar más de lo que hace falta para reconocer a alguien.
--
--   · APELLIDOS CON PALABRAS PEQUEÑAS: «de la Fuente», «del Río»,
--     «San Martín». Esas palabritas se dejan tal cual y se tapa la
--     primera palabra que de verdad dice quién es:
--         de la Fuente -> de la Fue***
--         del Río      -> del Rí***
--     Taparlas a ellas sería lo peor de los dos mundos: «de***» no
--     lo distingue de «del Pozo» ni de «Díaz», así que no sirve para
--     reconocer a nadie, y aun así se está enseñando algo.
--
--   · SEGUNDO APELLIDO. No sale nunca, ni tapado. Con el nombre y el
--     primer apellido ya se reconoce a quien se conoce; el segundo
--     solo añade rastro. Y así, de paso, a quien no tiene segundo
--     apellido no se le nota: todo el mundo sale igual.
--
-- ------------------------------------------------------------
-- QUIÉN SALE EN LA LISTA Y QUIÉN NO
--   · Solo los compañeros de LOS GRUPOS DE MI HIJO. De cualquier
--     otro grupo del club no se ve ni una fila.
--   · Un atleta puede estar en varios grupos (tabla `atleta_grupos`,
--     de la 116), así que «los compañeros» son los de CADA UNO de
--     sus grupos, no los de uno solo.
--   · Dos turnos con el mismo nombre («Azul 1 · lunes y miércoles» y
--     «Azul 1 · martes y jueves») SON GRUPOS DISTINTOS y aquí se
--     tratan como tales: cada uno con su gente. Juntarlos sería
--     decirle a un padre que su hija entrena con una amiga a la que
--     no ve nunca, que es justo lo contrario de lo que se busca.
--   · Quien está de baja no sale: ya no es compañero de nadie.
--   · Quien pidió no aparecer (`perfiles.perfil_visible = false`) no
--     sale tampoco, ni tapado. Es el único sitio donde alguien ha
--     dicho expresamente «a mí no me saquéis», y se respeta.
--
-- SOBRE LA AUTORIZACIÓN PARENTAL DEL RANKING (`perfil_juego`)
-- Aquí NO se pide, y es una decisión, no un olvido. Esa autorización
-- existe para poder publicar el NOMBRE DE VERDAD de un menor en una
-- clasificación que ve cualquiera desde internet. Esto es otra cosa:
-- el nombre no se publica —va tapado— y no lo ve cualquiera, sino
-- las familias de ese mismo grupo, que ya se cruzan en la pista todos
-- los martes. Pedir la misma autorización dejaría la lista vacía y la
-- pantalla no serviría para nada.
--
-- ------------------------------------------------------------
-- LO QUE NO SE ENSEÑA, A PROPÓSITO
-- Del compañero SOLO se dice el nombre tapado. Ni la edad, ni el año
-- de nacimiento, ni la categoría, ni el sexo, ni si viene a entrenar,
-- ni sus marcas, ni su ficha. Solo que existe y que está en ese
-- grupo. Esto encaja con lo que el club ya decidió en la 100: la
-- familia ve lo suyo (pagos, calendario, marcas de su hijo) y del
-- resto de niños, nada.
--
-- LA CLAVE QUE SALE NO SE PUEDE CRUZAR CON EL RANKING
-- Cada compañero sale con una `clave` para que la pantalla pueda
-- reconocer que dos filas son la misma persona en dos grupos. Esa
-- clave se calcula con una palabra propia de esta vista, distinta de
-- la que usa `ranking_marcas`. Si fuera la misma, alguien podría
-- juntar las dos listas y ponerle al nombre tapado la categoría, el
-- sexo y las marcas del ranking. Con palabras distintas, las dos
-- listas no casan.
--
-- IDEMPOTENTE · se puede pasar las veces que haga falta.
-- ============================================================

begin;

-- ============================================================
-- 1 · TAPAR UNA PALABRA
-- ------------------------------------------------------------
-- Deja las tres primeras letras y pone tres asteriscos. Con la
-- condición de que nunca se enseñe la palabra entera: si tiene tres
-- letras o menos, se enseña una menos de las que tiene.
-- ============================================================
create or replace function public.palabra_tapada(p_palabra text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select case
           when p_palabra is null or btrim(p_palabra) = '' then null
           -- `least(3, largo - 1)` es la regla entera: como mucho tres
           -- letras, y siempre una menos de las que hay. Para una
           -- palabra de una sola letra da cero, o sea «***» y nada más.
           else left(btrim(p_palabra), least(3, length(btrim(p_palabra)) - 1)) || '***'
         end;
$$;

comment on function public.palabra_tapada(text) is
  'Deja ver las tres primeras letras de una palabra y tapa el resto con tres '
  'asteriscos, siempre los mismos tres para no ir diciendo cuántas letras tiene. '
  'Nunca enseña la palabra entera: «Ana» sale «An***».';


-- ============================================================
-- 2 · TAPAR UN APELLIDO
-- ------------------------------------------------------------
-- Un apellido español puede empezar por palabras que no dicen quién
-- es nadie: «de», «la», «del», «San»… Esas se dejan como están y se
-- tapa la primera palabra con contenido. El segundo apellido se
-- tira: aquí no hace falta.
-- ============================================================
create or replace function public.apellido_tapado(p_apellidos text)
returns text
language plpgsql
immutable
set search_path to 'public'
as $$
declare
  -- Las palabritas de enlace de los apellidos. No se tapan porque
  -- taparlas no protege a nadie (hay cientos de «de la …») y en
  -- cambio deja el apellido irreconocible.
  particulas constant text[] := array[
    'de','del','la','las','lo','los','el','y','e','i',
    'da','das','do','dos','du','des','der','den','van','von',
    'di','della','dello','degli','san','santa','santo','sant',
    'bin','ibn','al'
  ];
  palabras text[];
  palabra  text;
  delante  text := '';
begin
  if p_apellidos is null or btrim(p_apellidos) = '' then
    return null;
  end if;

  palabras := regexp_split_to_array(btrim(p_apellidos), '\s+');

  foreach palabra in array palabras loop
    if lower(palabra) = any (particulas) then
      -- Palabrita de enlace: se enseña tal cual y se sigue mirando.
      delante := delante || palabra || ' ';
    else
      -- La primera palabra de verdad: se tapa y se acaba aquí. Lo que
      -- venga detrás (el segundo apellido) no sale ni tapado.
      return delante || public.palabra_tapada(palabra);
    end if;
  end loop;

  -- Si el apellido entero fueran palabritas de enlace —no debería
  -- pasar nunca, pero la base no se fía— se tapa la primera y ya.
  return public.palabra_tapada(palabras[1]);
end;
$$;

comment on function public.apellido_tapado(text) is
  'Tapa el primer apellido dejando ver tres letras. Las palabras de enlace («de '
  'la», «del», «San») se dejan enteras porque no identifican a nadie y sin ellas '
  'el apellido no se reconoce. El segundo apellido no sale ni tapado.';


-- ============================================================
-- 3 · EL NOMBRE ENTERO, TAPADO
-- ------------------------------------------------------------
-- Del nombre, la primera palabra; del apellido, lo de arriba.
-- ============================================================
create or replace function public.nombre_tapado(p_nombre text, p_apellidos text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select nullif(btrim(concat_ws(' ',
    -- Solo la primera palabra del nombre: «María del Carmen» -> «Mar***».
    public.palabra_tapada((regexp_split_to_array(btrim(coalesce(p_nombre, '')), '\s+'))[1]),
    public.apellido_tapado(p_apellidos)
  )), '');
$$;

comment on function public.nombre_tapado(text, text) is
  'El nombre de una persona a medio tapar, para enseñarlo a quien ya la conoce '
  'sin darle el nombre a quien no: «Nombre Apellido» sale «Nom*** Ape***».';


-- ============================================================
-- 4 · LA LISTA: MIS GRUPOS Y LA GENTE QUE HAY EN ELLOS
-- ------------------------------------------------------------
-- Va con `security_invoker = false`, o sea: la vista mira la base con
-- los permisos de quien la creó, no con los de quien pregunta. Tiene
-- que ser así porque una familia NO puede leer la ficha de los hijos
-- de los demás —y no se le va a abrir—, pero para poder taparle el
-- nombre a un compañero hay que leerlo antes.
--
-- Lo que sujeta esto es el `where` de abajo, que es la única puerta:
-- solo salen filas de los grupos donde está alguno de MIS atletas.
-- Si quien pregunta no tiene ninguno —o no ha iniciado sesión—,
-- `mis_atletas()` no devuelve nada, `mis_grupos` se queda vacío y la
-- vista entera devuelve cero filas. Cerrada por defecto.
-- ============================================================
drop view if exists public.mis_companeros;

create view public.mis_companeros
with (security_invoker = false) as
with mis_grupos as (
  -- Los grupos donde entrena alguno de mis hijos. `atleta_grupos` es
  -- la respuesta completa desde la 116: el grupo principal y los otros.
  select distinct ag.grupo_id
    from public.atleta_grupos ag
   where ag.atleta_id in (select public.mis_atletas())
),
mios as (
  -- Los hijos de quien pregunta, para poder marcarlos en la lista.
  select m as id from public.mis_atletas() m
)
select
  g.id                                      as grupo_id,
  g.nombre                                  as grupo,
  g.turno,
  g.horario,
  g.seccion,
  -- Para que la pantalla sepa que dos filas son la misma persona en
  -- dos grupos distintos, sin darle el identificador de nadie. La
  -- palabra «companeros» de delante es la que impide cruzar esta
  -- lista con la del ranking, que usa otra.
  substr(md5('companeros·' || a.id::text), 1, 12) as clave,
  -- Aquí es donde se tapa. Lo que sale de la base ya son asteriscos.
  coalesce(public.nombre_tapado(a.nombre, a.apellidos), '***') as nombre,
  (m.id is not null)                        as es_mio,
  -- El identificador solo cuando es hijo de quien pregunta: eso ya lo
  -- tiene. De los demás no sale, para que la pantalla no pueda ir a
  -- buscarlos a ninguna otra parte.
  case when m.id is not null then a.id end  as atleta_id
from mis_grupos mg
join public.grupos g          on g.id = mg.grupo_id
join public.atleta_grupos ag2 on ag2.grupo_id = mg.grupo_id
join public.atletas a         on a.id = ag2.atleta_id
left join public.perfiles pe  on pe.id = a.perfil_id
left join mios m              on m.id = a.id
where
  -- Un hijo de quien pregunta sale SIEMPRE, aunque esté de baja o haya
  -- pedido no aparecer. Esas dos cosas le tapan de cara a los demás, no
  -- de cara a su propia familia; y si se le escondiera, la pantalla no
  -- sabría a cuál de los hijos pertenece cada grupo.
  m.id is not null
  or (
    coalesce(a.estado, 'activo') <> 'baja'    -- quien se fue no es compañero de nadie
    and coalesce(pe.perfil_visible, true)     -- quien pidió no salir, no sale
  );

comment on view public.mis_companeros is
  'Los grupos donde entrena cada hijo de quien pregunta y quién más hay en ellos, '
  'con el nombre a medio tapar («Nom*** Ape***»). El nombre se corta AQUÍ, no en '
  'la pantalla: lo que viaja al navegador ya son asteriscos. De cada compañero no '
  'se dice nada más: ni edad, ni categoría, ni asistencia, ni marcas.';


-- ============================================================
-- 5 · QUIÉN PUEDE LEERLA
-- ------------------------------------------------------------
-- Con la sesión iniciada y nadie más. Un visitante sin sesión no
-- sacaría nada igualmente (la vista le devolvería cero filas), pero
-- ni se le deja preguntar.
-- ============================================================
revoke all on public.mis_companeros from public;
revoke all on public.mis_companeros from anon;
grant select on public.mis_companeros to authenticated;

revoke all on function public.palabra_tapada(text)        from public;
revoke all on function public.apellido_tapado(text)       from public;
revoke all on function public.nombre_tapado(text, text)   from public;
grant execute on function public.palabra_tapada(text)      to authenticated;
grant execute on function public.apellido_tapado(text)     to authenticated;
grant execute on function public.nombre_tapado(text, text) to authenticated;

commit;
