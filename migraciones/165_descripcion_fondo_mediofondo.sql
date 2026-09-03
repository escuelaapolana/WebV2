-- ============================================================
-- 165 · Descripción del grupo «Fondo-Mediofondo» (adultos)
-- ------------------------------------------------------------
-- Al mover el grupo de la escuela a la sección de pista (migración 164)
-- se quedó con la descripción de cuando estaba en la escuela:
-- «2ª hora · entrena 5 días · grupo de selección (no entra en el reparto)».
-- Eso es jerga de la escuela (2ª hora, reparto) y no pinta nada en la
-- sección de adultos. Se le pone una descripción propia y sus pruebas,
-- en el mismo tono que Velocidad.
--
-- Es un grupo de ADULTOS; los mayores de la escuela pueden promocionar a él,
-- pero eso se cuenta en la página de la escuela, no aquí.
-- ============================================================
update public.grupos
   set descripcion = 'Medio fondo y fondo para adultos. Preparación de las pruebas de resistencia, en pista y en ruta, con trabajo de ritmo y series.',
       pruebas = E'800 m\n1500 m\n3000 m\n5000 m'
 where id = 'ae475335-f97c-4178-9022-014c257d0218'
   and nombre = 'Fondo-Mediofondo';
