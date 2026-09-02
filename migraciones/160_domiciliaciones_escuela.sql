-- ============================================================
-- 160 · Lista de domiciliaciones para la contable
-- ------------------------------------------------------------
-- La contable necesita, para pasar los recibos domiciliados de cada
-- niño de escuela ya confirmado: nombre del niño, fecha de nacimiento,
-- DNI del niño (o su SIP), nombre y DNI del tutor, domicilio e IBAN.
--
-- Todo eso vive en el alta de escuela (altas_escuela + sus niños), que
-- se enlaza con la ficha por atleta_id. Se saca por una función con
-- llave de definidor porque ahí hay DNIs e IBAN: solo administración o
-- tesorería pueden pedirla. Devuelve los de las fichas ACTIVAS (los
-- confirmados), que son los que hay que domiciliar.
-- ============================================================

create or replace function public.domiciliaciones_escuela()
returns table (
  nino text,
  fecha_nacimiento date,
  dni_nino text,
  sip_nino text,
  tutor text,
  tutor_dni text,
  domicilio text,
  iban text
)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración o tesorería pueden ver las domiciliaciones';
  end if;

  return query
  select
    nullif(trim(concat_ws(' ', n.nombre_pila, n.apellido1, n.apellido2)), ''),
    n.fecha_nacimiento,
    n.dni,
    n.sip,
    nullif(trim(concat_ws(' ', e.tutor_nombre_pila, e.tutor_apellido1, e.tutor_apellido2)), ''),
    e.tutor_dni,
    nullif(trim(concat_ws(', ', e.direccion, e.cp, e.localidad)), ''),
    e.iban
  from public.altas_escuela_ninos n
  join public.altas_escuela e on e.id = n.alta_id
  join public.atletas a on a.id = n.atleta_id
  where coalesce(a.estado, 'activo') = 'activo'
  order by e.tutor_apellido1 nulls last, n.apellido1 nulls last;
end;
$$;

grant execute on function public.domiciliaciones_escuela() to authenticated;
