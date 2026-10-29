-- 477 · Natación · solicitudes: «no estamos interesados» + un horario a la vez → revisar
-- -----------------------------------------------------------------------------
-- (29-oct-2026) En la 1.ª lectura de los Excel reales salieron respuestas de la
-- escuela que marcan a la vez «No estamos interesados… desde OCTUBRE'26» y un
-- horario. Se lee el horario pero queda la duda (→ «por revisar», no alta sola).
-- También «no estamos interesados» (plural) cuenta como «no le interesa».
-- Y se vuelve a leer lo ya guardado (anteriores y por revisar) con la regla nueva.
-- -----------------------------------------------------------------------------

create or replace function public._nat_sol_franjas(p_pide text, p_tipo text, out franjas uuid[], out duda text)
 language plpgsql stable set search_path to 'public'
as $$
declare
  t       text := public._nat_sol_norm(p_pide);
  nombres text[] := array['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
  bonito  text[] := array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  tok     text;
  d       int;
  dias    int[] := '{}';
  pares   text[] := '{}';
  par     text;
  vio_dia boolean := false;
  ult_h   boolean := false;
  v_ids   uuid[];
  v_n     int;
  v_lab   text;
begin
  franjas := '{}';
  if t = '' then duda := 'No dice qué día ni a qué hora quiere venir.'; return; end if;
  if t ~ 'no (estoy|estamos) interesad' and t !~ '\d{1,2}[:.h]\d{2}' then
    duda := 'Dice que no le interesa este curso: «' || btrim(p_pide) || '».'; return;
  end if;
  -- marca «no estamos interesados» Y un horario a la vez: se lee el horario, pero lo mira Andrés
  if t ~ 'no (estoy|estamos) interesad' then
    duda := 'Marca a la vez que no le interesa este curso y un horario: confírmalo con la familia.';
  end if;
  t := regexp_replace(t, '(\d{1,2})[.h](\d{2})', '\1:\2', 'g');
  t := regexp_replace(t, '(^|[^:\d])(\d{1,2}) ?(h|horas)\M', '\1\2:00', 'g');   -- «a las 19 h» (no «19:30 horas»)
  foreach tok in array regexp_split_to_array(t, '[^a-z0-9:]+') loop
    d := array_position(nombres, regexp_replace(tok, '(sabado|domingo)s$', '\1'));
    if d is not null then dias := dias || d; vio_dia := true; ult_h := false; continue; end if;
    if tok ~ '^\d{1,2}:\d{2}$' then
      if array_length(dias, 1) is not null then
        foreach d in array dias loop pares := pares || (d::text || '|' || tok); end loop;
        dias := '{}';
      elsif not vio_dia and not ult_h then
        pares := pares || ('0|' || tok);         -- solo la hora
      end if;                                    -- («de 19:30 a 20:30»: la 2.ª hora no cuenta)
      ult_h := true;
    end if;
  end loop;
  foreach d in array dias loop pares := pares || (d::text || '|'); end loop;   -- días sin hora
  if array_length(pares, 1) is null then
    duda := 'No entiendo qué horario pide: «' || btrim(p_pide) || '».'; return;
  end if;

  foreach par in array pares loop
    select array_agg(f.id order by f.hora) into v_ids
      from public.natacion_franjas f
     where coalesce(f.activa, true)
       and case when p_tipo = 'Máster' then public.natacion_es_master(f.grupo, f.admite_master)
                else public.natacion_es_escuela(f.grupo) end
       and (split_part(par, '|', 1) = '0' or f.dia = split_part(par, '|', 1)::int)
       and (split_part(par, '|', 2) = '' or f.hora = split_part(par, '|', 2)::time);
    v_n := coalesce(array_length(v_ids, 1), 0);
    v_lab := btrim(case when split_part(par, '|', 1) = '0' then '' else bonito[split_part(par, '|', 1)::int] end
                   || ' ' || split_part(par, '|', 2));
    if v_n = 1 then
      if not (v_ids[1] = any(franjas)) then franjas := franjas || v_ids[1]; end if;
    elsif v_n = 0 then
      duda := concat_ws(' ', duda, 'No hay franja de ' || case when p_tipo = 'Máster' then 'máster' else 'escuela' end
                                   || ' el ' || v_lab || '.');
    else
      duda := concat_ws(' ', duda, 'El ' || v_lab || ' hay varias horas: elige cuál.');
    end if;
  end loop;
end $$;

update public.natacion_solicitudes s
   set franjas_pedidas = coalesce(x.franjas, '{}'), motivo = x.duda, actualizado_en = now()
  from public.natacion_solicitudes s2
  cross join lateral public._nat_sol_franjas(s2.pide, s2.origen) x
 where s2.id = s.id and s.estado in ('anterior', 'revisar') and s.pide is not null
   and (s.motivo is distinct from x.duda or s.franjas_pedidas is distinct from coalesce(x.franjas, '{}'));
