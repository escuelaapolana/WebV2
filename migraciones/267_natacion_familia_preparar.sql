-- ============================================================
-- 267 · Preparar el envío de correo a UNA familia de natación
-- ------------------------------------------------------------
-- Para el botón «✉ Enviar acceso» de un nadador ya existente (sin
-- tener que recrearlo): dado su CÓDIGO de acceso, dice a qué correo
-- hay que escribir, de qué tipo es (Escuela/Máster) y si la familia
-- YA tiene cuenta. Si NO la tiene, deja preparado el token de
-- invitación (igual que el alta). El front decide entonces qué Edge
-- llamar: `correo-natacion-horarios` si ya tiene cuenta, o
-- `familia-invitar` (solo_a) si hay que invitarla a crearla.
--
-- Permiso: solo gestor de natación (soy_gestor_natacion()).
-- ============================================================

create or replace function public.natacion_familia_preparar(p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_acceso  uuid;
  v_atleta  uuid;
  v_tipo    text;
  v_email   text;
  v_tiene   boolean;
  v_token   text;
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Sin permiso.' using errcode = '42501';
  end if;

  select id, atleta_id into v_acceso, v_atleta
  from public.natacion_accesos where upper(codigo) = upper(btrim(p_codigo)) and activo limit 1;
  if v_acceso is null then
    raise exception 'No hay ningún acceso con ese código.';
  end if;

  -- Tipo: si tiene alguna inscripción de Máster activa, es máster; si no, escuela.
  v_tipo := case when exists (
      select 1 from public.natacion_inscripciones
      where acceso_id = v_acceso and activa and tipo = 'Máster'
    ) then 'Máster' else 'Escuela' end;

  -- Correo: en escuela el del tutor; en máster el propio.
  if v_atleta is not null then
    if v_tipo = 'Máster' then
      select lower(nullif(btrim(coalesce(email, '')), '')) into v_email from public.atletas where id = v_atleta;
    else
      select lower(nullif(btrim(coalesce(email_tutor, '')), '')) into v_email from public.atletas where id = v_atleta;
    end if;
  end if;

  if v_email is null or v_email = '' then
    raise exception 'Este nadador no tiene correo guardado (añádelo en su ficha antes de enviar).';
  end if;

  v_tiene := exists (select 1 from public.perfiles where lower(email) = v_email);

  if not v_tiene then
    select token into v_token from public.familia_invitaciones
    where lower(email_tutor) = v_email and usado_en is null and caduca_en > now()
    order by creado_en desc limit 1;
    if v_token is null then
      loop
        v_token := replace(gen_random_uuid()::text, '-', '');
        exit when not exists (select 1 from public.familia_invitaciones where token = v_token);
      end loop;
      insert into public.familia_invitaciones (token, email_tutor, nota)
      values (v_token, v_email,
              'aviso ' || (case when v_tipo = 'Máster' then 'máster' else 'escuela natación' end)
              || ' ' || to_char(now(), 'YYYY-MM-DD'));
    end if;
  end if;

  return jsonb_build_object(
    'email', v_email, 'tipo', v_tipo, 'ya_tiene_cuenta', v_tiene, 'token', v_token
  );
end;
$$;

revoke all on function public.natacion_familia_preparar(text) from public, anon;
grant execute on function public.natacion_familia_preparar(text) to authenticated;
