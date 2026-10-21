-- 423 · Natación: Excel de cobros por fechas para el responsable (Mario)
-- ---------------------------------------------------------------------------
-- Mario (21-oct): «querría calcular entre ambas plataformas [SportMember y la
-- app] cómo va la cosa… un excel exportando los de cada mes, o en períodos a
-- elegir (a veces cojo los recibos de fin de mes anterior y de posterior)».
--
-- natacion_cobros_exportar(desde, hasta) → los recibos de `pagos` de los
-- NADADORES (fichas con natacion_accesos) cuya fecha cae en el rango:
-- fecha de cobro si está pagado; si no, la de vencimiento (o la de creación).
--   · Solo conceptos de natación: fuera la cuota de socio, la municipal de
--     atletismo… (no es dinero de natación) y nada de otras personas: Mario sigue sin ver el dinero general (Dinero, mig 395).
--   · Los anulados salen marcados (para cuadrar), no se esconden.
-- Misma puerta que el resto de «Cuotas y cobros»: natacion_cuotas_puede().
-- ---------------------------------------------------------------------------
begin;

create or replace function public.natacion_cobros_exportar(p_desde date, p_hasta date)
returns table (
  fecha          date,
  estado         text,      -- pagado · pendiente · impagado · anulado
  nadador        text,
  tipo           text,      -- Máster · Escuela
  concepto       text,
  periodo        text,
  importe        numeric,
  metodo         text,
  numero_recibo  text,
  fecha_pago     date,
  vencimiento    date
)
language plpgsql stable security definer
set search_path to 'public'
as $$
#variable_conflict use_column
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede descargar los cobros de natación.' using errcode = '42501';
  end if;
  if p_desde is null or p_hasta is null then raise exception 'Faltan las fechas.'; end if;
  if p_hasta < p_desde then raise exception 'La fecha «hasta» es anterior a «desde».'; end if;
  if p_hasta - p_desde > 800 then raise exception 'El periodo es demasiado largo (máximo, unos dos años).'; end if;

  return query
  select coalesce(p.fecha_pago, p.fecha_vencimiento, (p.created_at at time zone 'Europe/Madrid')::date) as f,
         case when p.anulado then 'anulado' else coalesce(p.estado, 'pendiente') end,
         btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')),
         public._natacion_tipo_de(a.id),
         p.concepto,
         p.periodo,
         p.importe,
         p.metodo,
         p.numero_recibo,
         p.fecha_pago,
         p.fecha_vencimiento
    from public.pagos p
    join public.atletas a on a.id = p.atleta_id
   where exists (select 1 from public.natacion_accesos na where na.atleta_id = p.atleta_id)
     -- solo dinero de natación: conceptos de natación (cuotas, proporcional
     -- del alta) y la cuota de entrenamiento domiciliada de un nadador (Maia,
     -- de antes de la 395). Fuera socio, municipal de atletismo, etc.
     and (coalesce(p.concepto, '') ~* 'nataci' or coalesce(p.concepto, '') ~* '^cuota de entrenamiento')
     and coalesce(p.fecha_pago, p.fecha_vencimiento, (p.created_at at time zone 'Europe/Madrid')::date)
         between p_desde and p_hasta
   order by 1, 3;
end;
$$;
revoke all on function public.natacion_cobros_exportar(date, date) from public, anon;
grant execute on function public.natacion_cobros_exportar(date, date) to authenticated, service_role;

insert into public.salud_rpc_front (nombre, en_publica) values
  ('natacion_cobros_exportar', false)
on conflict (nombre) do nothing;

commit;
