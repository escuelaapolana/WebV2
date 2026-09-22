-- 200 · Abrir/cerrar el cobro del Cubo por persona (solo admin)
-- El club decide, alta por alta, a quién le aparece «Pagar la cuota». Con
-- p_todos_aprobados = true, abre (o cierra) de golpe a TODOS los aprobados
-- salvo los ids de p_excepto (p. ej. los de prueba). No cobra nada: solo
-- muestra/oculta el botón de pago (el pago es autoservicio con tarjeta).
create or replace function public.cubo_cobro_abrir(
  p_id uuid default null,
  p_abierto boolean default true,
  p_todos_aprobados boolean default false,
  p_excepto uuid[] default '{}'
)
 returns integer
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_n integer := 0;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede abrir el cobro del Cubo.' using errcode = '42501';
  end if;

  if p_todos_aprobados then
    update public.cubo_altas
       set cobro_abierto = coalesce(p_abierto, true)
     where estado = 'aprobada'
       and not (id = any(coalesce(p_excepto, '{}')));
    get diagnostics v_n = row_count;
    return v_n;
  end if;

  if p_id is null then
    raise exception 'Falta el id del alta.' using errcode = 'P0001';
  end if;
  update public.cubo_altas
     set cobro_abierto = coalesce(p_abierto, true)
   where id = p_id;
  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'Esa alta ya no está.' using errcode = 'P0001';
  end if;
  return v_n;
end;
$function$;

grant execute on function public.cubo_cobro_abrir(uuid, boolean, boolean, uuid[]) to authenticated;
