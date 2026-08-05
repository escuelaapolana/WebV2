-- ============================================================
-- 125 · Las marcas también las apunta el entrenador
-- ------------------------------------------------------------
-- LO QUE PIDE EL CLUB, CON SUS PALABRAS
--   «Me deja añadir RM pero no mejor marca. ¿Por qué solo RM?»
--
-- Lo dijo mirando la ficha de un atleta en su móvil, donde los dos
-- bloques van uno detrás del otro: «Mejores marcas», que solo se
-- leía, y «Repeticiones máximas», con su formulario entero.
--
-- POR QUÉ NO PODÍA
-- No era la pantalla: era esta base. Sobre `marcas_atleta` solo
-- había dos permisos de escritura, y los dos decían `mis_atletas()`,
-- que es «el atleta, su familia y el entrenador que figura en SU
-- ficha». El entrenador que lleva el GRUPO no estaba: podía ver las
-- marcas de los suyos y no escribir ni una.
--
-- Y el club funciona al revés de eso. Las marcas de competición no
-- se las apunta el chaval desde el sofá: las toma quien está en la
-- pista con el cronómetro, que es el entrenador del grupo. Que un
-- atleta pueda apuntarse las suyas está bien y se queda; que su
-- entrenador no pueda es el fallo.
--
-- QUÉ SE USA PARA DECIR «SU ENTRENADOR»
-- `soy_entrenador_de()` (104, ampliada en 116), que ya es la puerta
-- de los RM, de las observaciones y de los comentarios del feedback.
-- Dice que sí cuando el atleta está a tu nombre en su ficha O
-- cuando entrena en alguno de tus grupos. Usar la misma en las
-- marcas es lo que evita que «mi atleta» acabe queriendo decir tres
-- cosas distintas según la tabla.
--
-- ------------------------------------------------------------
-- Y TAMBIÉN SE ARREGLA LA LECTURA, PORQUE SI NO EL ARREGLO ES PEOR
-- Si solo se abre la escritura, el entrenador de un grupo apunta un
-- 51.30, la base lo guarda, y al volver a mirar la ficha la marca no
-- está: no puede leerla. Eso se ve como «no se ha guardado» y acaba
-- con la misma marca metida cuatro veces. Así que quien puede
-- escribirla puede leerla, y punto.
--
-- ¿Es abrir de más? No: son marcas deportivas de gente de sus
-- grupos, que ya salen en el ranking del club y en los resultados de
-- las competiciones. No hay aquí ni un teléfono, ni una dirección,
-- ni una molestia, ni una nota de la familia. Lo delicado de un
-- atleta vive en otras tablas y esas no se tocan.
--
-- LO QUE NO CAMBIA
--   · La familia sigue viendo las marcas de sus hijos, como hasta
--     hoy (`mis_atletas()` la incluye y se queda dentro).
--   · Nadie más entra: quien no es del club sigue viendo solo la
--     vista `ranking_marcas` (058), que va tapada.
--   · Borrar sigue siendo cosa de administración. Una marca vieja
--     no estorba y una mal metida se corrige apuntando la buena;
--     lo que no se puede es que un mal día desaparezca del
--     historial de un chaval sin que quede rastro.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- LEER · el atleta, su familia y su entrenador (el de la ficha
-- y el del grupo).
-- ------------------------------------------------------------
drop policy if exists "ver datos de mis atletas" on public.marcas_atleta;
create policy "ver datos de mis atletas" on public.marcas_atleta
  for select to authenticated
  using (
    atleta_id in (select public.mis_atletas())
    or public.soy_entrenador_de(atleta_id)
  );

-- ------------------------------------------------------------
-- ESCRIBIR · su entrenador apunta y corrige.
-- Insert y update por separado, y ningún delete: es la misma
-- forma que tienen las notas del feedback. Borrar no hace falta
-- para apuntar una marca, y sí hace falta que el historial no se
-- pueda vaciar desde un móvil a las nueve de la noche.
-- ------------------------------------------------------------
drop policy if exists "el entrenador apunta la marca"  on public.marcas_atleta;
create policy "el entrenador apunta la marca" on public.marcas_atleta
  for insert to authenticated
  with check (public.soy_entrenador_de(atleta_id));

drop policy if exists "el entrenador corrige la marca" on public.marcas_atleta;
create policy "el entrenador corrige la marca" on public.marcas_atleta
  for update to authenticated
  using (public.soy_entrenador_de(atleta_id))
  with check (public.soy_entrenador_de(atleta_id));

commit;
