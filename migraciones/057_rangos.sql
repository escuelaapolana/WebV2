-- =====================================================================
-- 057_rangos.sql  ·  EL EMBLEMA DE CADA RANGO
-- =====================================================================
-- Para qué sirve:
--
--   Los siete rangos se dibujan con un disco y un número romano
--   (I … VII). Hasta ahora la pantalla solo recibía el NOMBRE del rango
--   («Bronce»), así que para saber qué número y qué color le tocaba a
--   cada uno no le quedaba más remedio que comparar nombres. Eso se
--   rompe el día que el club renombre un rango desde el panel, que es
--   justo lo que 045 prometía que se podía hacer sin tocar la web.
--
--   Aquí se añade `rango_clave`: la etiqueta estable del emblema. El
--   nombre y los puntos de corte siguen siendo del club y se pueden
--   cambiar cuando quiera; el disco y su número van pegados a esta
--   clave y no se mueven.
--
-- QUÉ NO CAMBIA
--   · No se toca ninguna fila existente más que para rellenarle esta
--     etiqueta nueva a partir del orden que ya tenía.
--   · No se toca ninguna vista, ninguna función ni ninguna regla RLS.
--   · No se toca el interruptor de la clasificación: sigue apagado.
--
-- ES OPCIONAL A PROPÓSITO
--   La columna admite nulo. Si algún día el club añade un rango octavo
--   desde el panel y no le pone etiqueta, no falla nada: la pantalla
--   deduce el número romano del `orden`, como hace de reserva.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/057_rangos.sql
-- Se puede volver a lanzar las veces que haga falta: no rompe nada.
-- =====================================================================

begin;

alter table public.juego_rangos add column if not exists rango_clave text;

-- Se rellena solo la primera vez, y solo lo que esté vacío: si el club
-- ya ha cambiado alguna etiqueta a mano, se respeta tal cual está.
update public.juego_rangos
   set rango_clave = case orden
                       when 1 then 'I'    when 2 then 'II'   when 3 then 'III'
                       when 4 then 'IV'   when 5 then 'V'    when 6 then 'VI'
                       when 7 then 'VII'  when 8 then 'VIII' when 9 then 'IX'
                       when 10 then 'X'
                     end
 where rango_clave is null
   and orden between 1 and 10;

do $$
begin
  -- Dos rangos no pueden llevar el mismo emblema: se verían iguales.
  if not exists (select 1 from pg_constraint where conname = 'juego_rangos_clave_emblema_unica') then
    alter table public.juego_rangos add constraint juego_rangos_clave_emblema_unica unique (rango_clave);
  end if;
  -- Un número romano y nada más: ni nombres, ni cifras, ni frases.
  if not exists (select 1 from pg_constraint where conname = 'juego_rangos_clave_emblema_check') then
    alter table public.juego_rangos add constraint juego_rangos_clave_emblema_check
      check (rango_clave is null or rango_clave ~ '^[IVXL]{1,8}$');
  end if;
end $$;

comment on column public.juego_rangos.rango_clave is
  'Etiqueta estable del emblema del rango (I … VII): el número romano del disco. El club puede renombrar el rango o mover sus puntos sin que el disco cambie. Si está vacía, la pantalla usa el orden.';

commit;


-- --- Comprobación rápida ---------------------------------------------
select rango_clave, clave, nombre, desde_puntos, orden
  from public.juego_rangos
 order by orden;
