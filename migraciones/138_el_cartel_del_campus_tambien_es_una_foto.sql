-- ============================================================
-- 138 · El cartel del campus también es una foto
-- ------------------------------------------------------------
-- QUÉ CAMBIA, Y QUÉ NO
-- No cambia NADA de la base. Ni una columna, ni una función, ni un
-- dato. Los cuatro canales siguen siendo los mismos cuatro —web,
-- redes, mensajeria, medios— y se siguen guardando igual.
--
-- Lo que cambia es QUÉ CABE DENTRO DE «medios», y por lo tanto lo que
-- dicen los comentarios que dejó la 137.
--
-- ------------------------------------------------------------
-- EL HUECO QUE HABÍA
-- La 137 partió la pregunta de las fotos en dos: los canales que lleva
-- el club por un lado, y la prensa por otro. Al hacerlo quedó una cosa
-- sin sitio, y estaba escrita con un aviso en la política de privacidad:
-- esa política dice —y decía ya— que el segundo bloque incluye también
-- los carteles, los folletos y la memoria de la temporada. La pregunta
-- de la pantalla, en cambio, solo nombraba prensa, televisión y
-- revistas. O sea, el club estaba dando por consentido material impreso
-- suyo por el que no preguntaba en ningún sitio.
--
-- ------------------------------------------------------------
-- LO QUE SE HA DECIDIDO, Y POR QUÉ ASÍ
-- El material impreso del club entra en la SEGUNDA pregunta.
--
-- El motivo importa más que la decisión: lo que separa las dos
-- preguntas NO es quién publica, es si se puede dar marcha atrás. Un
-- cartel del campus repartido por los colegios, o una memoria en papel,
-- se parecen mucho más a una foto en el periódico que a una publicación
-- en Instagram, que se borra en diez segundos. Meterlo en el primer
-- bloque —el de «esto se puede quitar»— sería mentir.
--
-- La otra salida era quitarlo de la política. Se descartó: dejaría al
-- club sin poder poner la cara de un crío en el cartel del campus, que
-- es algo que hace todos los años y que ninguna familia esperaría tener
-- prohibido.
--
-- Y no es una idea nueva: el impreso de papel ya lo tenía así desde el
-- principio. Su apartado d) se llama «Medios de comunicación y material
-- del club» y enumera notas de prensa, carteles, folletos y memoria de
-- la temporada. Lo único que pasaba es que la web se había quedado
-- corta respecto al papel. Ahora dicen lo mismo.
--
-- ------------------------------------------------------------
-- POR QUÉ HACE FALTA ESTA MIGRACIÓN SI NO TOCA NINGÚN DATO
-- Por lo mismo que la 137: porque los comentarios de las columnas
-- decían que la segunda pregunta era «prensa, televisión o revistas», y
-- eso ya no es lo que se pregunta. Un comentario de columna es lo
-- primero que lee quien llegue dentro de dos años, y uno que miente es
-- peor que ninguno, porque se lo va a creer.
--
-- ------------------------------------------------------------
-- NO HAY NADA QUE MIGRAR, Y ESTÁ COMPROBADO
-- Antes de escribir esto se miró: no hay ni una sola ficha ni un solo
-- alta con «medios» guardado, en ninguna de las tres tablas. La segunda
-- pregunta se estrenó anoche y todavía no la ha contestado nadie. Así
-- que no hay ningún sí antiguo al que se le esté ensanchando el
-- significado por la espalda, que es lo único que habría que mirar con
-- cuidado aquí.
--
-- Y las altas viejas siguen igual que las dejó la 137: se les hizo UNA
-- pregunta, contestaron a esa, y lo que tienen guardado
-- —{web,redes,mensajeria} si dijeron que sí— es exactamente lo que
-- consintieron. Nunca traen «medios», y no se les añade.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/138_el_cartel_del_campus_tambien_es_una_foto.sql
-- ============================================================

begin;

comment on column public.atletas.permiso_imagen_ambitos is
  'Para qué canales vale el permiso: web, redes, mensajeria, medios. «medios» no es solo la '
  'prensa: es el apartado d) del impreso de papel entero —notas de prensa, televisión, revistas, '
  'y también los carteles, folletos y la memoria de la temporada que imprime el club—. Van juntos '
  'porque lo que los separa de los tres primeros no es quién publica, sino que una vez publicado o '
  'impreso ya no se puede retirar. Los formularios de alta de la web preguntan DOS cosas y las '
  'reparten en estos cuatro: «los canales del club» marca los tres primeros y «prensa, televisión '
  'o carteles» marca «medios». El impreso de papel los ofrece por separado. Las altas anteriores a '
  'agosto de 2026 se hicieron con una sola pregunta y por eso nunca traen «medios»: a eso no se '
  'les preguntó.';

comment on column public.altas_escuela_ninos.permiso_imagen_ambitos is
  'Para qué canales vale el permiso: web, redes, mensajeria, medios. El formulario pregunta dos '
  'cosas por cada hijo —los canales del club, y prensa, televisión o carteles— y las reparte en '
  'estos cuatro nombres. «medios» incluye el material impreso del club: carteles, folletos y '
  'memoria de la temporada. Las altas de antes de agosto de 2026 traen una sola respuesta y nunca '
  '«medios».';

comment on column public.altas_socio.permiso_imagen_ambitos is
  'Para qué canales vale el permiso: web, redes, mensajeria, medios. El formulario pregunta dos '
  'cosas —los canales del club, y prensa, televisión o carteles— y las reparte en estos cuatro '
  'nombres. «medios» incluye el material impreso del club: carteles, folletos y memoria de la '
  'temporada. Las altas de antes de agosto de 2026 traen una sola respuesta y nunca «medios».';

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE SIGUE SIN HABER NADA QUE MIGRAR
-- ------------------------------------------------------------
-- Tiene que salir 0 en las tres filas. Si algún día sale otra cosa, no
-- es un fallo: es que ya hay familias que han contestado a la segunda
-- pregunta, que es justo lo que se pretendía.
select 'atletas' as tabla, count(*) as con_medios
  from public.atletas where 'medios' = any(permiso_imagen_ambitos)
union all
select 'altas_escuela_ninos', count(*)
  from public.altas_escuela_ninos where 'medios' = any(permiso_imagen_ambitos)
union all
select 'altas_socio', count(*)
  from public.altas_socio where 'medios' = any(permiso_imagen_ambitos);
