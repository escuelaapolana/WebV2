-- ===========================================================================
-- 539 · Natación · equipación: entregar y cobrar POR ARTÍCULO (26-nov-2026)
-- ---------------------------------------------------------------------------
-- Petición de Mario (vía Andrés): «poder marcar que entrega una sola cosa a una
-- persona aunque queden cosas pendientes» y «marcar que es de pago o no para
-- una persona».
--   · natacion_equip_lineas.entregado_en: ese artículo ya se ha dado. Cuando
--     están todos entregados, la familia pasa sola a «entregado».
--   · natacion_equip_lineas.sin_cargo: ese artículo no se cobra (regalo,
--     cortesía…). El total de la familia se recalcula y, si ya tenía enlace de
--     pago SIN pagar, su importe también (a 0 → el pago se anula). Si ya pagó,
--     no se toca el cobro: se avisa.
--   · natacion_equip_listar devuelve el id de cada línea y estos dos campos.
--   · natacion_equip_nuevo_set (chaqueta gratis) ya no suma lo que va sin cargo.
-- ===========================================================================
begin;

alter table public.natacion_equip_lineas
  add column if not exists entregado_en timestamptz,
  add column if not exists sin_cargo boolean not null default false;

create or replace function public._natacion_equip_recalcular(p_fam uuid) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare v_total numeric; v_f public.natacion_equip_familias%rowtype; v_p public.pagos%rowtype; v_aviso text;
begin
  select coalesce(sum(cantidad * precio_unitario) filter (where not sin_cargo), 0) into v_total
    from public.natacion_equip_lineas where familia_id = p_fam;
  update public.natacion_equip_familias set total = v_total where id = p_fam returning * into v_f;
  if v_f.pago_id is not null then
    select * into v_p from public.pagos where id = v_f.pago_id;
    if v_p.estado = 'pagado' then
      if v_p.importe <> v_total then v_aviso := 'Ya había pagado ' || v_p.importe || ' €: el cobro no se cambia (el pedido ahora suma ' || v_total || ' €).'; end if;
    elsif not coalesce(v_p.anulado, false) then
      if v_total > 0 then
        update public.pagos set importe = v_total where id = v_p.id;
      else
        update public.pagos set anulado = true, anulado_en = now(), anulado_motivo = 'Equipación: todo sin cargo (mig 539)' where id = v_p.id;
        update public.natacion_equip_familias set pago_id = null where id = p_fam;
      end if;
    end if;
  end if;
  return jsonb_build_object('total', v_total, 'aviso', v_aviso);
end $$;
revoke all on function public._natacion_equip_recalcular(uuid) from public, anon, authenticated;

create or replace function public.natacion_equip_linea_set(p_linea uuid, p_entregado boolean default null, p_sin_cargo boolean default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_l public.natacion_equip_lineas%rowtype; v_r jsonb := '{}'::jsonb; v_pend int;
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la natación o su ropa.' using errcode = '42501'; end if;
  select * into v_l from public.natacion_equip_lineas where id = p_linea for update;
  if not found then raise exception 'No encuentro ese artículo.'; end if;
  if p_entregado is not null then
    update public.natacion_equip_lineas set entregado_en = case when p_entregado then coalesce(entregado_en, now()) end where id = p_linea;
    select count(*) into v_pend from public.natacion_equip_lineas where familia_id = v_l.familia_id and entregado_en is null;
    if v_pend = 0 then
      update public.natacion_equip_familias set estado = 'entregado', entregado_en = coalesce(entregado_en, now()) where id = v_l.familia_id and estado <> 'entregado';
    elsif not p_entregado then
      -- se deshace una entrega de una familia ya cerrada: vuelve a «ha llegado» (o pagado)
      update public.natacion_equip_familias f set estado = case when exists (select 1 from public.pagos p where p.id = f.pago_id and p.estado = 'pagado') then 'pagado' else 'llegado' end,
             entregado_en = null
       where f.id = v_l.familia_id and f.estado = 'entregado';
    end if;
  end if;
  if p_sin_cargo is not null and p_sin_cargo <> v_l.sin_cargo then
    update public.natacion_equip_lineas set sin_cargo = p_sin_cargo where id = p_linea;
    v_r := public._natacion_equip_recalcular(v_l.familia_id);
  end if;
  return jsonb_build_object('ok', true) || v_r ||
         jsonb_build_object('estado', (select estado from public.natacion_equip_familias where id = v_l.familia_id));
end $$;
revoke all on function public.natacion_equip_linea_set(uuid, boolean, boolean) from public, anon;
grant execute on function public.natacion_equip_linea_set(uuid, boolean, boolean) to authenticated;

-- La chaqueta gratis recalcula sin contar lo que va sin cargo
create or replace function public.natacion_equip_nuevo_set(p_nadador uuid, p_nuevo boolean)
 returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_fam uuid;
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la natación o su ropa.' using errcode = '42501'; end if;
  update public.natacion_equip_nadadores set nuevo = coalesce(p_nuevo, false) where id = p_nadador returning familia_id into v_fam;
  if v_fam is null then raise exception 'No encuentro ese nadador.'; end if;
  if exists (select 1 from public.natacion_equip_familias where id = v_fam and estado in ('pendiente', 'pedido')) then
    update public.natacion_equip_lineas set precio_unitario = case when p_nuevo then 0 else public._natacion_equip_precio_sudadera() end
     where nadador_id = p_nadador and articulo = 'sudadera';
    perform public._natacion_equip_recalcular(v_fam);
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.natacion_equip_listar()
 returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.natacion_ropa_puede() then
    raise exception 'Solo quien lleva la natación o su ropa.' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', f.id, 'email', f.email, 'contacto', f.contacto, 'telefono', f.telefono, 'estado', f.estado, 'total', f.total,
      'enlace', 'https://atletismoapolana.com/natacion/equipacion/?t=' || f.token,
      'avisado_en', f.avisado_en, 'respondido_en', f.respondido_en, 'llegado_en', f.llegado_en, 'entregado_en', f.entregado_en,
      'pago_estado', p.estado, 'pago_enlace', case when p.token_pago is not null then 'https://atletismoapolana.com/pagar/?t=' || p.token_pago end,
      'nadadores', coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'nombre', n.nombre, 'tipo', n.tipo, 'nuevo', n.nuevo) order by n.nombre)
                               from public.natacion_equip_nadadores n where n.familia_id = f.id), '[]'),
      'lineas', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'nadador_id', l.nadador_id, 'articulo', l.articulo, 'nombre', l.nombre,
                                                               'talla', l.talla, 'cantidad', l.cantidad, 'precio', l.precio_unitario,
                                                               'entregado_en', l.entregado_en, 'sin_cargo', l.sin_cargo) order by l.nombre)
                            from public.natacion_equip_lineas l where l.familia_id = f.id), '[]')
    ) order by lower(coalesce(f.contacto, f.email)))
      from public.natacion_equip_familias f
      left join public.pagos p on p.id = f.pago_id
     where f.temporada = '2026/27' and f.email not like 'prueba-%'), '[]');   -- la familia de prueba no sale
end $$;

commit;
