-- 300 · Sello de «ya se le avisó del cobro» en el Cubo
-- Andrés (8-oct): quiere un botón para avisar SOLO a los nuevos (los que acaban
-- de entrar y se les acaba de abrir el cobro), sin re-mandar el correo a los que
-- ya lo recibieron. Para saber quién falta, cada alta guarda cuándo se le mandó
-- el correo «Ya puedes activar tu cuota» (cobro_avisado_en). Lo sella la Edge
-- cubo-cobro-aviso al enviarse. «Sin avisar» = cobro abierto + cobro_avisado_en null.

alter table public.cubo_altas
  add column if not exists cobro_avisado_en timestamptz;

-- Marcado inicial: a todos los que YA tienen el cobro abierto se les da por
-- avisados (recibieron el correo en la tanda de sept/oct o antes), MENOS los
-- recién activados que aún no lo han recibido: Eva Bonmatí, Cristina Mula y
-- Jimena González. Así el botón «avisar a los nuevos» apunta exactamente a ellos.
update public.cubo_altas
   set cobro_avisado_en = now()
 where cobro_abierto
   and cobro_avisado_en is null
   and id not in (
     '8c623e52-9b94-4d67-9f19-c436b61f956b',  -- Eva Bonmatí Soler
     '7c04a9da-09d9-4513-a3c5-151b2e84cfeb',  -- Cristina Mula
     'c1296f9f-66bc-4732-a88e-98b624ad1be9'   -- Jimena González
   );
