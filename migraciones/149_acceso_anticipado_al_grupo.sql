-- ============================================================
-- 149 · ACCESO ANTICIPADO AL GRUPO (antes de que empiece el club)
-- ------------------------------------------------------------
-- QUÉ RESUELVE
--
-- Andrés empieza a entrenar a los suyos antes de que arranque el club de
-- forma oficial, y quiere que entren ya a la app a ver los entrenamientos
-- sin pasar por el alta completa (nada de IBAN ni DNI). Y sin correos,
-- porque el envío en masa todavía no está montado.
--
-- El registro público de Supabase está DESACTIVADO a propósito
-- («signup_disabled»): las cuentas no se abren solas. Así que un
-- formulario abierto no puede crear cuentas por su cuenta. La cuenta la
-- crea una función de servidor (edge `acceso-grupo`), con la contraseña
-- que el atleta escribe en el formulario. Sin correo de por medio.
--
-- LA PUERTA · UN CÓDIGO DE GRUPO
--
-- Para que no se apunte cualquiera, el formulario pide un CÓDIGO que
-- Andrés comparte solo con sus atletas. Cada grupo puede tener el suyo en
-- `grupos.codigo_acceso`. La función mira el código, saca el grupo, crea
-- la ficha provisional y la mete ahí. Si el código no vale, no hace nada.
--
-- CÓMO SE UNIFICA LUEGO CON EL ALTA OFICIAL
--
-- La ficha se crea con el email del atleta. El mecanismo que ya existe
-- —`acceso_enganchar`, que corre al crear la cuenta— ata el login a
-- cualquier ficha con ese email. El día que la familia rellene el alta
-- oficial, esa ficha se completa (mismo email); lo que el atleta lleve
-- entrenado no se pierde porque cuelga de la MISMA ficha.
-- ============================================================

-- ------------------------------------------------------------
-- 1 · EL CÓDIGO DEL GRUPO
-- ------------------------------------------------------------
alter table grupos add column if not exists codigo_acceso text;

comment on column grupos.codigo_acceso is
  'Código que se pide en el formulario de acceso anticipado para entrar a este grupo. Lo comparte el entrenador solo con los suyos. Vacío = el grupo no admite acceso anticipado.';

-- Dos grupos no pueden compartir código: el código decide a qué grupo va
-- la ficha, así que tiene que ser único.
create unique index if not exists ux_grupos_codigo_acceso
  on grupos (lower(codigo_acceso)) where codigo_acceso is not null;

-- ------------------------------------------------------------
-- 2 · LA FICHA PROVISIONAL
-- Se marca para saber que entró por aquí y le falta el alta oficial. No
-- es un estado de baja: es una ficha viva, solo que a medio rellenar.
-- ------------------------------------------------------------
alter table atletas add column if not exists provisional boolean not null default false;
alter table atletas add column if not exists origen text;

comment on column atletas.provisional is
  'true = ficha creada por acceso anticipado (sin alta oficial todavía). Se completa cuando la familia hace la inscripción, por el mismo email.';
comment on column atletas.origen is
  'De dónde salió la ficha: "acceso_anticipado", "inscripcion", "importacion"…';

-- ------------------------------------------------------------
-- 3 · DEL CÓDIGO AL GRUPO
-- La usa la función de servidor (con la llave de servicio), no el
-- navegador: NO se concede a anon a propósito, para que desde fuera no se
-- pueda ir probando códigos hasta dar con uno.
-- ------------------------------------------------------------
create or replace function grupo_por_codigo(p_codigo text)
returns uuid
language sql stable security definer set search_path to 'public'
as $$
  select id from grupos
   where codigo_acceso is not null
     and lower(codigo_acceso) = lower(btrim(p_codigo))
     and coalesce(activo, true)
   limit 1;
$$;

-- ------------------------------------------------------------
-- 4 · EL GRUPO A DE ANDRÉS, LISTO PARA ACCESO ANTICIPADO
-- El código se puede cambiar cuando se quiera desde el panel; este es el
-- de partida. Andrés lo comparte por WhatsApp con sus atletas.
-- ------------------------------------------------------------
update grupos set codigo_acceso = 'GRUPOA-2026'
 where nombre = 'Grupo A' and seccion = 'competicion'
   and codigo_acceso is null;
