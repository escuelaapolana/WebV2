-- ============================================================
-- 137 · El permiso de las fotos son dos preguntas
-- ------------------------------------------------------------
-- QUÉ CAMBIA, Y QUÉ NO
-- No cambia NADA de la base. Ni una columna, ni una función, ni un
-- dato. Los cuatro canales siguen siendo los mismos cuatro —web,
-- redes, mensajeria, medios— y se siguen guardando igual.
--
-- Lo que ha cambiado es CÓMO SE PREGUNTA. Hasta hoy los formularios de
-- alta de la web hacían una sola pregunta —«¿podemos publicar fotos
-- tuyas?»— y de un solo sí salían tres canales marcados de golpe. Eso
-- tenía dos problemas:
--
--   1. La ley pide consentimiento específico. Metidas cosas distintas
--      en la misma casilla, la familia no elige: se traga el paquete
--      entero. Y con menores eso se mira con más lupa.
--   2. La política de privacidad publicada prometía, dos veces, que se
--      puede decir que sí a unos canales y que no a otros. En el papel
--      era verdad; en la web no lo era.
--
-- Desde hoy se preguntan DOS cosas, en el alta de la escuela y en la
-- de socio:
--
--   · «¿En los canales del club?»  → marca web, redes y mensajeria.
--   · «¿Y en prensa, televisión o revistas?» → marca medios.
--
-- Dos y no cuatro porque web, redes y mensajería son lo mismo en la
-- práctica: los lleva el club, y si una foto está en Instagram y en la
-- web es la misma decisión. Los medios no: ahí la foto sale del club,
-- va a un periódico o a una televisión que no controla nadie de aquí y
-- no se puede retirar. Esa sí es una decisión distinta de verdad.
--
-- ------------------------------------------------------------
-- POR QUÉ HACE FALTA ESTA MIGRACIÓN SI NO TOCA NINGÚN DATO
-- Porque el comentario de la columna decía otra cosa, y un comentario
-- de una columna es lo primero que lee quien llega dentro de dos años.
-- Ponía que el formulario de la web «pregunta uno solo que vale por los
-- tres primeros y nunca por medios». Eso ya no es cierto: ahora sí
-- puede llegar «medios» desde la web. Dejarlo escrito mal es peor que
-- no escribirlo, porque quien lo lea se fiará.
--
-- ------------------------------------------------------------
-- LAS ALTAS DE ANTES NO SE TOCAN, Y ES A PROPÓSITO
-- A esas familias se les hizo UNA pregunta, y contestaron a esa. Lo que
-- tienen guardado —{web,redes,mensajeria} si dijeron que sí— es
-- exactamente lo que consintieron. Añadirles «medios» ahora sería
-- inventarse un sí que nadie les pidió, y encima el que no tiene marcha
-- atrás. Se quedan como están, y en las pantallas se lee sin trampa:
-- «Sí, para la web, redes sociales y grupos de mensajería».
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/137_el_permiso_de_las_fotos_son_dos_preguntas.sql
-- ============================================================

begin;

comment on column public.atletas.permiso_imagen_ambitos is
  'Para qué canales vale el permiso: web, redes, mensajeria, medios. Los formularios de alta '
  'de la web preguntan DOS cosas y las reparten en estos cuatro: «los canales del club» marca '
  'los tres primeros y «prensa, televisión o revistas» marca «medios». El impreso de papel los '
  'ofrece por separado. Las altas anteriores a agosto de 2026 se hicieron con una sola pregunta '
  'y por eso nunca traen «medios»: a eso no se les preguntó.';

comment on column public.altas_escuela_ninos.permiso_imagen_ambitos is
  'Para qué canales vale el permiso: web, redes, mensajeria, medios. El formulario pregunta dos '
  'cosas por cada hijo —los canales del club, y prensa y televisión— y las reparte en estos '
  'cuatro nombres. Las altas de antes de agosto de 2026 traen una sola respuesta y nunca «medios».';

comment on column public.altas_socio.permiso_imagen_ambitos is
  'Para qué canales vale el permiso: web, redes, mensajeria, medios. El formulario pregunta dos '
  'cosas —los canales del club, y prensa y televisión— y las reparte en estos cuatro nombres. '
  'Las altas de antes de agosto de 2026 traen una sola respuesta y nunca «medios».';

-- Y el texto literal de la pregunta, que ahora son dos y se guardan
-- las dos en la misma casilla, separadas por un punto medio. Se guarda
-- porque el día que alguien discuta qué consintió, lo que vale no es lo
-- que la web pregunte entonces sino lo que ponía cuando contestó.
comment on column public.altas_escuela_ninos.texto_imagen is
  'La pregunta literal que se le hizo a la familia, tal y como estaba en la pantalla el día que '
  'contestó. Desde agosto de 2026 son dos preguntas y van las dos aquí.';

comment on column public.altas_socio.texto_imagen is
  'La pregunta literal que se le hizo, tal y como estaba en la pantalla el día que contestó. '
  'Desde agosto de 2026 son dos preguntas y van las dos aquí.';

commit;

-- ------------------------------------------------------------
-- CÓMO QUEDA LA COSA
-- ------------------------------------------------------------
-- Con qué combinaciones hay altas guardadas. Antes de hoy solo puede
-- salir «{web,redes,mensajeria}» y «{}»: las demás empiezan a aparecer
-- según vayan entrando altas nuevas.
select coalesce(array_to_string(permiso_imagen_ambitos, '+'), 'sin lista') as canales,
       count(*) as fichas
  from public.atletas
 where permiso_imagen is not null
 group by 1
 order by 2 desc;
