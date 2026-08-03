-- ============================================================
-- 087 · El mismo agujero del TRUNCATE, pero en los archivos
-- ------------------------------------------------------------
-- La migración 074 quitó el permiso de VACIAR TABLAS (TRUNCATE) en el
-- esquema `public`, porque TRUNCATE **se salta las reglas de acceso
-- (RLS) enteras**: da igual lo bien puestas que estén las políticas,
-- quien tiene TRUNCATE borra la tabla de golpe.
--
-- Pero los archivos (fotos de la web, fotos de perfil, fotos de los
-- atletas, justificantes de la Liga, propuestas de Instagram y los
-- documentos de los socios) no viven en `public`: viven en el esquema
-- `storage`, que Supabase gestiona aparte. Y ahí seguía el agujero:
-- `anon` y `authenticated` tenían TRUNCATE sobre `storage.objects` y
-- `storage.buckets`. Comprobado en vivo (y revertido): como visitante
-- SIN CUENTA, una sola orden `truncate storage.objects` dejaba la
-- tabla a cero, es decir, **el club sin una sola foto ni documento**,
-- sin rastro y sin nada que recuperar.
--
-- POR QUÉ NO SE ARREGLA COMO EL 074 (con un REVOKE)
-- Esas tablas no son nuestras: las creó y las posee `supabase_storage_
-- admin`. Nuestro usuario `postgres` aquí NO es superusuario ni
-- pertenece a ese rol, así que el `revoke truncate ...` se acepta sin
-- dar error pero **no hace nada** (solo puedes revocar lo que tú
-- concediste). Lo peligroso es justo eso: parece arreglado y no lo
-- está. Por eso aquí NO usamos REVOKE.
--
-- QUÉ HACEMOS EN SU LUGAR
-- Un candado que sí podemos poner: un disparador `BEFORE TRUNCATE` que
-- corta el intento antes de que borre nada. Salta solo cuando quien lo
-- intenta es `anon` o `authenticated` (los papeles con los que habla
-- el navegador), así que NO estorba a Supabase, que trabaja con otros
-- papeles (`supabase_storage_admin`, `service_role`) y nunca vacía
-- estas tablas en su funcionamiento normal. Nadie de fuera puede
-- quitar el candado: para borrar el disparador hay que ser dueño de la
-- tabla, y ni `anon` ni `authenticated` lo son.
--
-- Nota: el borrado normal de archivos (uno a uno, desde la web o el
-- panel) NO es TRUNCATE, así que sigue funcionando igual. Esto solo
-- bloquea el «vaciar la tabla entera de golpe».
-- Idempotente.
-- ============================================================

-- La función del candado. No es SECURITY DEFINER a propósito: corre con
-- el papel de quien lanza el TRUNCATE, y así puede comprobar quién es.
create or replace function public.storage_bloquea_truncate()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('anon', 'authenticated') then
    raise exception
      'Vaciar los archivos del club no está permitido desde la web.'
      using errcode = '42501';
  end if;
  return null;
end;
$$;

-- Se cuelga el candado de cada tabla de archivos donde anon/authenticated
-- tenían TRUNCATE. Cada una va en su propio bloque con captura de errores:
-- si alguna no existe o no nos deja ponerlo, se avisa por consola pero la
-- migración no se rompe.
do $$
declare
  t text;
  tablas text[] := array['objects', 'buckets', 'buckets_analytics'];
begin
  foreach t in array tablas loop
    begin
      execute format('drop trigger if exists ztrg_no_truncate on storage.%I', t);
      execute format(
        'create trigger ztrg_no_truncate before truncate on storage.%I '
        'for each statement execute function public.storage_bloquea_truncate()', t);
      raise notice 'Candado anti-TRUNCATE puesto en storage.%', t;
    exception when others then
      raise notice 'No se pudo poner el candado en storage.% (%). Se deja constancia.', t, sqlerrm;
    end;
  end loop;
end $$;
