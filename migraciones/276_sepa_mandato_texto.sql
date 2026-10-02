-- 276_sepa_mandato_texto.sql
-- SEPA · deja PREPARADA la configuración del mandato de domiciliación con el
-- texto legal (el mismo que usa /socio/alta/) y los datos del acreedor del club.
--
-- Queda INACTIVA (activo=false) A PROPÓSITO: una orden SEPA no es válida sin el
-- IDENTIFICADOR DE ACREEDOR, que lo da el banco (lo pide Isa). En cuanto se
-- tenga, basta con:
--   update public.sepa_mandato_texto
--      set identificador_acreedor = 'ESxxZZZxxxxxxxxx', activo = true
--    where version = 'v1-2026';
-- y la firma de domiciliación se enciende sola (el flujo ya está montado y cada
-- mandato queda enlazado a su persona, mig 271).
--
-- Solo puede haber UNA fila activa (índice único ux_sepa_mandato_texto_activo).

begin;

insert into public.sepa_mandato_texto
  (version, texto, cif_acreedor, identificador_acreedor, acreedor_nombre, acreedor_direccion, activo)
select
  'v1-2026',
  'Mediante la aceptación de esta orden de domiciliación, el deudor (A) autoriza al acreedor a enviar instrucciones a la entidad del deudor para adeudar su cuenta y a la entidad para efectuar los adeudos en su cuenta siguiendo las instrucciones del acreedor. Como parte de sus derechos, el deudor está legitimado al reembolso por su entidad en los términos y condiciones del contrato suscrito con la misma. La solicitud de reembolso deberá realizarse en las siguientes 8 semanas que siguen a la fecha de adeudo en su cuenta. Puede obtener información adicional sobre sus derechos en su entidad financiera. Tipo de pago: recurrente.',
  'G-03845500',
  null,
  'Club Atletismo Apolana',
  'C/ Hondón de las Nieves, 4 · 03005 Alicante',
  false
where not exists (select 1 from public.sepa_mandato_texto where version = 'v1-2026');

commit;
