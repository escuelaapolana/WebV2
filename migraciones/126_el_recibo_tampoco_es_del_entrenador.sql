-- ============================================================
-- EL RECIBO TAMPOCO ES DEL ENTRENADOR
-- ------------------------------------------------------------
-- La 125 tapó el agujero de los bonos de El Cubo. Al repasar el resto
-- del club aparece el mismo por otras tres puertas, todas de dinero:
--
--   1. Los RECIBOS. Un entrenador veía los recibos de todos los
--      atletas de su grupo: qué deben, cuánto, y si van atrasados.
--      En la base de hoy eso son 178 recibos de familias con las que
--      no tiene nada que ver.
--   2. Los PAGOS CON TARJETA. Lo mismo, pero además con el rastro de
--      la pasarela.
--   3. Los PEDIDOS DE LA TIENDA. Este era el peor de los tres: no era
--      mirar, era gastar. Un entrenador podía crear un pedido a
--      nombre de un atleta suyo, y la factura le llegaba a su familia.
--
-- Y una cuarta puerta, más discreta: la función `recibo()`, que
-- devuelve el papel del recibo entero. Ahí no solo va el importe: van
-- también el email y el teléfono de la madre o el padre. Eso no es
-- información de entrenamiento, es la agenda de una familia.
--
-- La causa es la de siempre: `mis_atletas()` mezcla a mis hijos con
-- los que entreno. Se cambia por `mis_atletas_bolsillo()`, que creó la
-- 125 y solo dice que sí cuando el atleta soy yo o es hijo mío.
--
-- Lo que NO se toca, a propósito: asistencia, faltas, entrevista de
-- entrada, notas, lesiones, carga, marcas y tests siguen igual. Eso el
-- entrenador lo necesita para entrenar, y quitárselo sería descubrir
-- en septiembre que no puede hacer su trabajo.
-- ============================================================

-- ------------------------------------------------------------
-- 1. LOS RECIBOS
--
-- Quien lleva las cuentas del club sigue viéndolos: tesorería,
-- contabilidad y administración tienen sus propias reglas aparte y no
-- pasan por aquí. Lo único que se cierra es la puerta lateral del
-- entrenador.
-- ------------------------------------------------------------
drop policy if exists "ver datos de mis atletas" on public.pagos;
create policy "ver datos de mis atletas" on public.pagos
  for select using (atleta_id in (select public.mis_atletas_bolsillo()));

-- ------------------------------------------------------------
-- 2. LOS PAGOS CON TARJETA
--
-- El primer trozo (el pago va a mi nombre) y el último (soy
-- administración) se dejan tal cual estaban; solo se estrecha el de
-- en medio.
-- ------------------------------------------------------------
drop policy if exists "ver mis pagos con tarjeta" on public.pagos_online;
create policy "ver mis pagos con tarjeta" on public.pagos_online
  for select using (
    perfil_id = public.mi_perfil_id()
    or atleta_id in (select public.mis_atletas_bolsillo())
    or public.es_admin()
  );

-- ------------------------------------------------------------
-- 3. LOS PEDIDOS DE LA TIENDA
--
-- El pedido se sigue creando a mi nombre, como antes. Lo que cambia es
-- a quién puedo ponerle la camiseta: solo a mí o a un hijo mío. Un
-- pedido sin atleta (para uno mismo) sigue valiendo igual.
-- ------------------------------------------------------------
drop policy if exists "socio crea sus pedidos" on public.pedidos;
create policy "socio crea sus pedidos" on public.pedidos
  for insert with check (
    perfil_id = public.mi_perfil_id()
    and estado = 'pendiente'
    and (atleta_id is null or atleta_id in (select public.mis_atletas_bolsillo()))
  );

-- ------------------------------------------------------------
-- 4. LA PUERTA QUE SE SALTA LAS REGLAS
--
-- `recibo()` es `security definer`: pasa por encima de las reglas de
-- arriba y comprueba por su cuenta. Si no se cambiara también, el
-- agujero seguiría abierto por aquí, y encima con los datos de
-- contacto de la familia dentro.
--
-- Se reescribe solo el trozo que decide quién puede, dejando el resto
-- de la función tal como está.
-- ------------------------------------------------------------
do $$
declare v_src text;
begin
  select pg_get_functiondef(oid) into v_src
    from pg_proc
   where pronamespace = 'public'::regnamespace
     and proname = 'recibo';

  if v_src is null then
    raise exception 'No está la función recibo(); esta migración esperaba encontrarla';
  end if;

  if position('p.atleta_id in (select public.mis_atletas())' in v_src) = 0 then
    raise exception 'La función recibo() no dice lo que esta migración esperaba; revísala a mano';
  end if;

  execute replace(
    v_src,
    'p.atleta_id in (select public.mis_atletas())',
    'p.atleta_id in (select public.mis_atletas_bolsillo())'
  );
end $$;
