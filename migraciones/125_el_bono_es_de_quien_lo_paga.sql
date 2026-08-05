-- ============================================================
-- EL BONO ES DE QUIEN LO PAGA
-- ------------------------------------------------------------
-- Un entrenador entró en la app con su papel de atleta, abrió «Mis
-- bonos» de El Cubo y se encontró un desplegable con los atletas de su
-- grupo: podía ver sus bonos y, lo que es peor, GASTARLOS apuntándolos
-- a una clase. Eso son usos que ha pagado otra familia.
--
-- La causa: `mis_atletas()` significa tres cosas a la vez —yo, mis
-- hijos, y los que entreno—, y para casi todo está bien: un entrenador
-- tiene que ver la asistencia y la entrevista de los suyos. Pero para
-- el BOLSILLO no vale. Que alguien esté a mi cargo en la pista no me da
-- derecho a gastar lo que ha pagado su madre.
--
-- Así que se separa: para el dinero se usa una función más estrecha,
-- que solo dice que sí cuando el atleta soy yo o es hijo mío. El resto
-- de la app sigue usando la de siempre, sin cambios.
--
-- Y no depende del papel que lleves puesto, a propósito: aunque el
-- entrenador se ponga el sombrero de atleta o al revés, sigue sin poder
-- tocar el bono de nadie. Un permiso que se arregla cambiando de papel
-- no es un permiso.
-- ============================================================

create or replace function public.mis_atletas_bolsillo()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.atletas
   where perfil_id = public.mi_perfil_id()
      or perfil_padre_id = public.mi_perfil_id();
$$;

comment on function public.mis_atletas_bolsillo() is
  'Los atletas cuyo dinero es mío: yo mismo y mis hijos. A propósito NO '
  'incluye a los que entreno: llevarlos en la pista no da derecho a gastar '
  'sus bonos. Para todo lo demás sigue valiendo mis_atletas().';

revoke all on function public.mis_atletas_bolsillo() from public, anon;
grant execute on function public.mis_atletas_bolsillo() to authenticated;

-- ------------------------------------------------------------
-- LAS TABLAS DEL BOLSILLO
-- ------------------------------------------------------------

-- El bono de El Cubo: cuántos usos te quedan y cuándo caducan.
drop policy if exists "ver mi bono del cubo" on public.cubo_bonos;
create policy "ver mi bono del cubo" on public.cubo_bonos
  for select using (atleta_id in (select public.mis_atletas_bolsillo()));

-- El gasto de cada uso.
drop policy if exists "ver mis movimientos del cubo" on public.cubo_movimientos;
create policy "ver mis movimientos del cubo" on public.cubo_movimientos
  for select using (
    bono_id in (select id from public.cubo_bonos
                 where atleta_id in (select public.mis_atletas_bolsillo()))
  );

-- Y el otro bono, el de las actividades del club.
drop policy if exists "ver mis movimientos de bono" on public.bono_movimientos;
create policy "ver mis movimientos de bono" on public.bono_movimientos
  for select using (atleta_id in (select public.mis_atletas_bolsillo()));

-- Las reservas: apuntarse gasta un uso, así que es tan del bolsillo
-- como el bono.
drop policy if exists "ver mis reservas del cubo" on public.cubo_reservas;
create policy "ver mis reservas del cubo" on public.cubo_reservas
  for select using (atleta_id in (select public.mis_atletas_bolsillo()));

drop policy if exists "apuntarme al cubo" on public.cubo_reservas;
create policy "apuntarme al cubo" on public.cubo_reservas
  for insert with check (atleta_id in (select public.mis_atletas_bolsillo()));

drop policy if exists "cambiar mi reserva del cubo" on public.cubo_reservas;
create policy "cambiar mi reserva del cubo" on public.cubo_reservas
  for update using (atleta_id in (select public.mis_atletas_bolsillo()))
              with check (atleta_id in (select public.mis_atletas_bolsillo()));

drop policy if exists "borrar mi reserva del cubo" on public.cubo_reservas;
create policy "borrar mi reserva del cubo" on public.cubo_reservas
  for delete using (atleta_id in (select public.mis_atletas_bolsillo()));

-- ------------------------------------------------------------
-- Y LAS PUERTAS QUE SE SALTAN LAS REGLAS
--
-- Estas dos funciones son `security definer`, o sea que pasan por
-- encima de las reglas de arriba y comprueban por su cuenta. Si no se
-- cambiaran también, el agujero seguiría abierto por aquí.
-- ------------------------------------------------------------
do $$
declare v_src text;
begin
  -- Se reescribe solo el trozo que decide quién puede, dejando el resto
  -- de la función tal como está: es larga y hace muchas cosas (plazas,
  -- lista de espera, devolver el uso) que no tienen por qué tocarse.
  for v_src in
    select pg_get_functiondef(oid) from pg_proc
     where pronamespace = 'public'::regnamespace
       and proname in ('cubo_apuntarme','cubo_desapuntarme')
  loop
    execute replace(
      v_src,
      'p_atleta in (select public.mis_atletas())',
      'p_atleta in (select public.mis_atletas_bolsillo())'
    );
  end loop;
end $$;
