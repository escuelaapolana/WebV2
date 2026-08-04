-- ============================================================
-- 107 · El banco de ejercicios se abre, y cabe lo que se hizo de más
-- ------------------------------------------------------------
-- DOS COSAS DE LA MISMA FAMILIA, las dos vistas usando la app de
-- verdad, y las dos el mismo principio: NO ENCERRAR AL QUE ESCRIBE.
--
-- ============================================================
-- PARTE 1 · EL BANCO DE EJERCICIOS ES ABIERTO
-- ------------------------------------------------------------
-- El entrenador: «no puedo escribir un ejercicio que no esté en la
-- lista. Es solo un desplegable».
--
-- Y el acuerdo con el club era el contrario: se escribe lo que
-- sea. Lo que el sistema reconozca, lo aprovecha (el % de RM, lo
-- que hiciste la última vez); lo que no, se guarda y se enseña
-- tal cual y no pasa nada.
--
-- POR QUÉ IMPORTA MÁS DE LO QUE PARECE
-- Un banco cerrado no sobrevive a la primera semana. El día que el
-- entrenador quiera meter algo que no está —y pasa el primer día—
-- se atasca, y acaba escribiéndolo en las notas para saltarse el
-- sistema. A partir de ahí ese ejercicio NO EXISTE para la app: ni
-- historial, ni progresión, ni porcentajes. El dato se pierde por
-- haber querido tenerlo ordenado.
--
-- LO QUE HACE FALTA EN LA BASE: que un entrenador pueda añadir un
-- ejercicio al catálogo. Hasta hoy solo podía administración, así
-- que «añádelo al banco» era imposible aunque la pantalla lo
-- ofreciera. El catálogo se llena USÁNDOLO, no sentándose a
-- escribir doscientos ejercicios antes de empezar.
--
-- Añadir sí; retocar y borrar, no: si un entrenador pudiera
-- renombrar un ejercicio del catálogo, se llevaría por delante el
-- historial de todos los demás, que cuelga del NOMBRE.
--
-- ============================================================
-- PARTE 2 · LO QUE EL ATLETA HIZO Y NADIE LE HABÍA PUESTO
-- ------------------------------------------------------------
-- El club: «Remo con mancuernas, hay que añadirlo». Sale de un
-- entrenamiento real: hizo un remo con mancuerna que no estaba en
-- el entrenamiento, y hoy eso solo cabe en las notas.
--
-- No es rehacer el entrenamiento: es CONTAR LO QUE HIZO, que es
-- justo el dato que queremos. Sigue sin poder borrar ni cambiar lo
-- que puso el entrenador: añadir lo de más, sí; quitar lo que le
-- mandaron, no.
--
-- CÓMO SE GUARDA: sin tabla nueva y sin columna nueva. Otra
-- entrada más en `registros_sesion.tiempos_reales`, con una llave
-- que no puede chocar con ningún id de fila y una marca que dice
-- de dónde salió:
--
--   { "extra:<uuid>": {
--       "anadido_por_atleta": true,
--       "ejercicio": "Remo con mancuerna",
--       "medida":    "peso_reps",
--       "series":  [ {"hecha":true,"peso":22,"reps":12} ],
--       "tiempos": [ "22 kg × 12" ]
--     } }
--
-- ⚠️ Y AQUÍ ESTÁ LO QUE HABÍA QUE ARREGLAR SÍ O SÍ
-- `apo_series_hechas` cuenta las series con ✓ de TODAS las
-- entradas, y el estado del día sale de comparar ese número con
-- las series que mandaba el entrenador. Si lo añadido contara,
-- pasaría esto:
--
--   mandadas 10 · hechas 5 · añade 6 series de remo
--   → 11 >= 10 → el día sale «completo»
--
-- Es decir: se saltó la mitad del entrenamiento y la app diría que
-- lo hizo entero. Sería la misma mentira hacia arriba que vino a
-- arreglar la migración 103, entrando por otra puerta.
--
-- Así que lo añadido NO cuenta para saber si se hizo lo mandado.
-- Cuenta como trabajo hecho —se ve en el día, en el historial y en
-- «la última vez» de ese ejercicio— pero no completa lo que el
-- entrenador puso. Son dos preguntas distintas y hay que
-- responderlas por separado.
--
-- IDEMPOTENTE: `create or replace` y políticas que se tiran antes
-- de crearse. No borra nada.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · EL CATÁLOGO SE LLENA USÁNDOLO
-- ------------------------------------------------------------
-- Cualquiera del equipo técnico puede añadir un ejercicio. No
-- puede editarlos ni borrarlos: el historial de todo el club
-- cuelga del nombre, y renombrar uno sería reescribir el pasado de
-- gente que no está delante.
drop policy if exists "el equipo tecnico anade ejercicios" on public.ejercicios;
create policy "el equipo tecnico anade ejercicios" on public.ejercicios
  for insert to authenticated
  with check (public.es_staff());

-- Quién lo añadió y cuándo. No es burocracia: cuando dentro de un
-- año aparezcan tres ejercicios casi iguales («Remo mancuerna»,
-- «Remo con mancuernas», «Remo unilateral»), esto es lo que dice a
-- quién preguntar antes de tocar nada.
alter table public.ejercicios add column if not exists creado_por uuid references public.perfiles(id);
alter table public.ejercicios add column if not exists created_at timestamptz default now();

comment on column public.ejercicios.creado_por is
  'Quién lo añadió desde el planificador, si no venía en el catálogo original. '
  'Sirve para saber a quién preguntar el día que haya que ordenar los parecidos.';

-- Dos ejercicios con el mismo nombre son un doble clic, no dos
-- ejercicios. Se compara sin mayúsculas ni espacios de sobra
-- porque «Remo con mancuerna» y «remo con mancuerna » son el mismo
-- para cualquiera que lo lea.
create unique index if not exists ejercicios_nombre_unico
  on public.ejercicios (lower(btrim(nombre)));

-- ------------------------------------------------------------
-- 2 · LO AÑADIDO NO COMPLETA LO MANDADO
-- ------------------------------------------------------------
-- Misma función de la migración 103, con una sola línea nueva: la
-- que se salta las entradas que puso el atleta por su cuenta.
create or replace function public.apo_series_hechas(p_tiempos jsonb)
returns integer
language plpgsql
immutable
as $$
declare
  v_ej    jsonb;
  v_serie jsonb;
  v_txt   jsonb;
  v_n     integer := 0;
begin
  if p_tiempos is null or jsonb_typeof(p_tiempos) <> 'object' then
    return 0;
  end if;

  for v_ej in select value from jsonb_each(p_tiempos) loop
    if jsonb_typeof(v_ej) <> 'object' then
      continue;
    end if;

    -- ⚠️ LO QUE AÑADIÓ EL ATLETA NO SE CUENTA AQUÍ.
    -- Este número solo responde a «¿cuánto de LO MANDADO se hizo?».
    -- Si contara lo añadido, alguien que se salta media sesión y
    -- luego hace seis series de remo por su cuenta saldría como que
    -- entrenó el día entero. El remo se ve igual en su día y en su
    -- historial: lo que no hace es tapar lo que se quedó sin hacer.
    if coalesce((v_ej ->> 'anadido_por_atleta')::boolean, false) then
      continue;
    end if;

    if jsonb_typeof(v_ej -> 'series') = 'array' then
      -- Forma nueva: manda el ✓, y solo el ✓.
      for v_serie in select * from jsonb_array_elements(v_ej -> 'series') loop
        if jsonb_typeof(v_serie) = 'object' and (v_serie ->> 'hecha') = 'true' then
          v_n := v_n + 1;
        end if;
      end loop;
    elsif jsonb_typeof(v_ej -> 'tiempos') = 'array' then
      -- Forma vieja: no hay ✓, pero un tiempo escrito es una serie
      -- hecha. Así los registros de antes no aparecen de golpe como
      -- entrenamientos a medias, que sería una mentira nueva.
      for v_txt in select * from jsonb_array_elements(v_ej -> 'tiempos') loop
        if jsonb_typeof(v_txt) = 'string' and btrim(v_txt #>> '{}') <> '' then
          v_n := v_n + 1;
        end if;
      end loop;
    end if;
  end loop;

  return v_n;
end;
$$;

comment on function public.apo_series_hechas(jsonb) is
  'Cuenta las series con ✓ de lo que MANDÓ EL ENTRENADOR. Desde la migración 107 '
  'se salta lo que el atleta añadió por su cuenta: eso es trabajo hecho y se ve, '
  'pero no completa el entrenamiento que estaba puesto, o media sesión saltada '
  'quedaría tapada por seis series de remo.';

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- un entrenador puede añadir al banco; el atleta no
--   --   set local role authenticated;
--   --   set local request.jwt.claims = '{"email":"…entrenador…"}';
--   --   insert into ejercicios (nombre, tipo, categoria) values ('Remo con mancuerna','gym','fuerza');
--
--   -- lo añadido por el atleta no infla el recuento
--   select public.apo_series_hechas(
--     '{"a":{"series":[{"hecha":true}]},
--       "extra:1":{"anadido_por_atleta":true,"series":[{"hecha":true},{"hecha":true}]}}'::jsonb);
--   -- debe devolver 1, no 3
--
--   -- qué se ha añadido por su cuenta, y en qué días
--   select r.atleta_id, e.value->>'ejercicio' as anadido
--     from registros_sesion r, jsonb_each(r.tiempos_reales) e
--    where (e.value->>'anadido_por_atleta')::boolean;
-- ------------------------------------------------------------
