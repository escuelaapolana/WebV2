-- ============================================================
-- 130 · El enlace del grupo de WhatsApp de las familias
-- ------------------------------------------------------------
-- DE DÓNDE SALE ESTO
--   «Quizás un botón para que se unan directamente al grupo de
--    WhatsApp.»
-- La idea es buena y resuelve de raíz el problema de la pantalla
-- final: en vez de prometer que alguien escribirá, se da la puerta.
--
-- ------------------------------------------------------------
-- ⚠️ POR QUÉ EL BOTÓN NO ESTÁ EN LA PANTALLA FINAL DEL FORMULARIO
-- Esto es lo importante de todo el archivo, y si algún día alguien
-- quiere «mejorarlo» poniéndolo ahí, que lea esto antes.
--
-- UN ENLACE DE INVITACIÓN DE WHATSAPP NO PREGUNTA QUIÉN ERES. Quien
-- lo tiene, entra. Y el formulario de alta lo puede rellenar
-- cualquiera desde internet, sin comprobar nada: no hay contraseña,
-- ni correo confirmado, ni pago por medio.
--
-- Si el enlace saliera al terminar el formulario, cualquiera apunta a
-- un niño inventado, pulsa el botón y se mete en el grupo de las
-- familias de la escuela: madres y padres de menores, sus teléfonos y
-- las fotos que se comparten ahí dentro. No hay letra pequeña que
-- arregle eso.
--
-- Así que el enlace NO viaja al navegador de quien se apunta. Sale
-- por dos sitios y solo por dos:
--   · en el correo del resumen, que llega al buzón que la familia
--     dejó y que además queda escrito para dentro de dos semanas;
--   · en el panel, para que quien escribe ese correo lo copie.
--
-- ------------------------------------------------------------
-- ⚠️ Y POR QUÉ NO BASTA CON QUE EL ALTA ESTÉ REVISADA
-- Era lo primero que se pensó, y no vale. El grupo que el formulario
-- le enseña a la familia es PROVISIONAL —lo dice la propia pantalla—
-- hasta que el club cierra los repartos de septiembre. Un alta puede
-- estar revisada y el crío acabar en otro color una semana después.
--
-- Y meter a una familia en el grupo equivocado no es un despiste que
-- se arregla luego: sacar a alguien de un grupo de WhatsApp es a mano
-- e incómodo, y mientras tanto ha visto los teléfonos y las fotos de
-- veinte familias con las que no tiene nada que ver. Es el mismo daño
-- que estamos evitando arriba, solo que por descuido en vez de por
-- mala fe.
--
-- ASÍ QUE EL ENLACE SE DA CUANDO EL GRUPO ES DEFINITIVO, y eso en
-- esta app tiene un momento exacto y ya existente: cuando alguien del
-- club convierte el alta en ficha y le elige grupo de verdad
-- (`alta_crear_ficha`, migración 121). A partir de ahí el grupo del
-- niño está en su ficha, decidido por una persona, y es el que manda.
--
-- Las dos condiciones, juntas:
--   1. el alta está revisada  → alguien del club la ha mirado;
--   2. el niño ya tiene ficha → alguien le ha elegido grupo.
-- En la práctica la segunda arrastra a la primera, porque crear la
-- ficha del último hermano deja el alta revisada sola. Se comprueban
-- las dos igualmente: el día que eso cambie, esto no se abre solo.
--
-- ------------------------------------------------------------
-- 🔒 EL ENLACE NO SE ESCRIBE EN EL CÓDIGO. NUNCA.
-- Ni aquí, ni en un HTML, ni «de ejemplo». Este repositorio es
-- público y un enlace al grupo de familias de menores del club no
-- puede quedar en el histórico de nadie. Se guarda en la base y se
-- rellena desde `admin/grupos/`, que es donde el club lleva sus
-- grupos.
--
-- Y si un grupo no tiene enlace puesto, NO SE DICE NADA. Nada de
-- «pídeselo a tu entrenador»: eso es otra promesa, y ya hemos tenido
-- bastantes.
--
-- ------------------------------------------------------------
-- NADA PERSONAL AQUÍ DENTRO, NI UN ENLACE DE VERDAD
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta. No borra ni una ficha.
-- ============================================================

begin;

-- ============================================================
-- 1 · LA CASILLA DEL ENLACE, EN EL GRUPO
-- ------------------------------------------------------------
-- Va en `grupos` y no en un sitio aparte porque es del grupo: cada
-- uno tiene el suyo, y los dos turnos del mismo color son grupos
-- distintos con familias distintas, así que también tienen chats
-- distintos.
-- ============================================================
alter table public.grupos
  add column if not exists whatsapp_enlace text;

comment on column public.grupos.whatsapp_enlace is
  'El enlace de invitación al grupo de WhatsApp de las familias de este grupo. '
  'SE RELLENA A MANO desde admin/grupos/ y NO SE ESCRIBE NUNCA EN EL CÓDIGO: el '
  'repositorio es público. Quien tiene un enlace de estos entra al chat sin que '
  'nadie le pregunte quién es, así que no sale del panel ni del correo del '
  'resumen; jamás al navegador de quien está rellenando el formulario de alta. '
  'Vacío quiere decir que ese grupo todavía no tiene chat, y entonces no se dice '
  'nada: no se promete lo que no hay.';


-- ============================================================
-- 2 · LA TABLA `grupos` SE LEE EN PÚBLICO · HAY QUE TAPAR ESTO
-- ------------------------------------------------------------
-- ESTO ES UN AGUJERO QUE HABÍA QUE CERRAR ANTES DE GUARDAR NADA.
-- `grupos` tiene una regla que dice «lectura publica ... true»: la
-- web enseña los horarios y el formulario de alta lee los grupos sin
-- haber entrado con ninguna cuenta. Perfecto para el horario, y
-- catastrófico para esta columna: guardar el enlace en esa tabla, sin
-- más, sería publicarlo.
--
-- Postgres no deja esconder una columna con las reglas de fila, así
-- que se hace de la única forma que funciona de verdad: se le QUITA a
-- todo el mundo el permiso de leer `grupos` a pelo y se le da columna
-- por columna, con todas menos esta. Quien lea la tabla desde la web
-- sigue viendo lo de siempre; si pide `whatsapp_enlace`, le dicen que
-- no.
--
-- Es el mismo camino que la 115 con el DNI y el IBAN: el dato no se
-- esconde al dibujar la pantalla —eso lo salta cualquiera con F12—,
-- no sale de la base.
-- ============================================================
do $$
declare
  v_papel text;
  v_cols  text;
begin
  -- Todas las columnas de `grupos` menos la del enlace, escritas de
  -- una en una. Se saca de la propia tabla para que el día que se
  -- añada una columna nueva esto no se quede corto sin avisar.
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
    into v_cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'grupos'
     and column_name <> 'whatsapp_enlace';

  foreach v_papel in array array['anon', 'authenticated'] loop
    execute format('revoke select on public.grupos from %I', v_papel);
    execute format('grant select (%s) on public.grupos to %I', v_cols, v_papel);
  end loop;
end $$;

-- Escribirlo sigue siendo cosa de administración, y de eso ya se
-- encargan las reglas de fila de siempre («admin gestiona todo»).
grant insert, update, delete on public.grupos to authenticated;
grant all on public.grupos to service_role;


-- ============================================================
-- 3 · QUIÉN VE EL ENLACE, Y CON QUÉ CONDICIONES
-- ------------------------------------------------------------
-- Administración y tesorería, que son quienes escriben el correo del
-- resumen. Y NO devuelve el enlace por las buenas: devuelve por qué
-- todavía no toca, para que el panel pueda decirlo en castellano en
-- vez de dejar un hueco que nadie entiende.
--
-- Se pide de UN niño, no de un grupo: así la condición de «su grupo
-- ya es definitivo» se comprueba de verdad, con su ficha delante.
-- ============================================================
create or replace function public.alta_enlace_familias(p_nino_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_alta_est text;
  v_atleta   uuid;
  v_grupo    uuid;
  v_nombre   text;
  v_enlace   text;
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración y tesorería pueden ver este enlace';
  end if;

  select a.estado, n.atleta_id
    into v_alta_est, v_atleta
    from public.altas_escuela_ninos n
    join public.altas_escuela a on a.id = n.alta_id
   where n.id = p_nino_id;

  if v_alta_est is null then
    return jsonb_build_object('ok', false, 'motivo', 'no-esta');
  end if;

  -- Todavía no se ha mirado quién es esta familia.
  if v_alta_est <> 'revisada' then
    return jsonb_build_object('ok', false, 'motivo', 'sin-revisar');
  end if;

  -- Y todavía no hay ficha, así que su grupo sigue siendo el
  -- provisional que le enseñó el formulario. Mandarle el enlace ahora
  -- es meterle en el chat del que a lo mejor no es su grupo.
  if v_atleta is null then
    return jsonb_build_object('ok', false, 'motivo', 'sin-ficha');
  end if;

  -- El grupo de la FICHA, no el del alta: el de la ficha lo eligió una
  -- persona del club y es el que manda.
  select a.grupo_id into v_grupo from public.atletas a where a.id = v_atleta;
  if v_grupo is null then
    select ag.grupo_id into v_grupo
      from public.atleta_grupos ag
     where ag.atleta_id = v_atleta and ag.principal
     limit 1;
  end if;

  if v_grupo is null then
    return jsonb_build_object('ok', false, 'motivo', 'sin-grupo');
  end if;

  select g.nombre, g.whatsapp_enlace into v_nombre, v_enlace
    from public.grupos g where g.id = v_grupo;

  -- Ese grupo no tiene chat puesto. Se dice tal cual y no se inventa
  -- ninguna alternativa: prometer que se lo pida a alguien es
  -- exactamente el tipo de frase que estamos quitando de la web.
  if v_enlace is null or btrim(v_enlace) = '' then
    return jsonb_build_object('ok', false, 'motivo', 'grupo-sin-enlace',
                              'grupo', v_nombre);
  end if;

  return jsonb_build_object('ok', true, 'grupo', v_nombre, 'enlace', btrim(v_enlace));
end;
$$;

comment on function public.alta_enlace_familias(uuid) is
  'El enlace al grupo de WhatsApp de las familias que le toca a un niño de un '
  'alta, y solo cuando su grupo ya es DEFINITIVO: alta revisada y ficha creada. '
  'Antes de eso el grupo es provisional y el enlace metería a la familia en el '
  'chat equivocado. Si no toca, dice por qué, para poder explicarlo.';

revoke all on function public.alta_enlace_familias(uuid) from public;
grant execute on function public.alta_enlace_familias(uuid) to authenticated;

commit;

-- Que la API se entere de la columna nueva sin esperar a que se le
-- ocurra sola.
notify pgrst, 'reload schema';
