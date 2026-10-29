# Recorrido en vivo · Academia (ficha, Tests y marcas, Competiciones, Carga)

Para comprobarlo en la web **con la sesión iniciada** (unos 30 minutos). Hasta
completarlo, estas pantallas **no se dan por verificadas**. Todo con el grupo
**«Academia AC98 · PRUEBA»** (selector arriba a la derecha).

## Cómo anotar

En cada paso: **Esperado** (ya escrito) · **Observado** (lo que sale) · **Pasa / Falla**
· **Incidencia** (si falla, qué falta). Al final, las incidencias van en dos listas
separadas: **fallos funcionales** (algo hace mal su trabajo o da una cifra errónea) y
**mejoras de comodidad** (funciona, pero cuesta). Si algo falla, **no se borra nada**:
los datos ficticios se quedan para reproducirlo, se corrige y se repite el paso antes
de darlo por validado.

## Datos ficticios y cómo se reconocen

- **Grupo «Academia AC98 · PRUEBA»** (grupo de prueba): banda «Grupo de prueba · datos
  ficticios». Sus atletas se apellidan **«Ficticio (prueba)»**.
- **Álex (prueba)**: nacido el **10-05-2001**, hombre → **Sénior** en 2026 (RFEA 2026,
  verificada). En su perfil: «100» y «200» (textos sin confirmar en el catálogo).
- **Competiciones de prueba**: etiqueta **«Prueba · no se publica»**; no salen en la
  web, ni en el portal, ni en recuentos.
- **Resultados de prueba**: atleta ficticio y huella `prueba-vivo-…`.
- No se toca ninguna competición real ni ningún atleta real. Nada se borra.

## A · Navegación y lectura (no se escribe nada)

| # | Qué hacer | Esperado | Observado | Pasa / Falla | Incidencia |
|---|---|---|---|---|---|
| 1 | Academia → selector de grupo → **Academia AC98 · PRUEBA**. | Banda «Grupo de prueba · datos ficticios». Atletas «Ficticio (prueba)». | | | |
| 2 | Semana → toca **Álex** → su ficha. | «Categoría federativa hoy: **Sénior**» y «Temporada de planificación **2026/27**» (provisional); ningún aviso «No se ha podido leer todo». | | | |
| 3 | En la ficha, abre Perfil, Decisiones, Objetivos, Historial y Marcas. | En Objetivos, filas «100» y «200» marcadas «sin confirmar en el catálogo»; donde no hay datos, «sin registrar». | | | |
| 4 | Tests y marcas: Por atleta, Por prueba, Protocolos y Catálogo (solo mirar). Catálogo → «60» → «Ver usos…». | Protocolos con «Falta para comparar». Seis ambiguas pendientes. Los usos de otros grupos salen como «Atleta de otro grupo». | | | |
| 5 | Competiciones: Próximas, Mes y Mínimas. | Leyenda A/B/C con «Ninguna prioridad cambia el entrenamiento». En una competición real, lo público y lo de Academia salen separados. No se toca ninguna real. | | | |
| 6 | Otra pestaña: `atletismoapolana.com/calendario/`. | Referencia: no hay ninguna competición «PRUEBA». | | | |

## B · Escrituras, solo en el grupo PRUEBA

**Pasos 7–10: el mismo caso.** Prueba **200 m lisos** · unidad **segundos** · temporada
de planificación **2026/27** · temporada federativa **2026** · categoría **Sénior**
(calculada) · condiciones: **viento +1,2 m/s**, cronometraje **electrónico de
competición**, resultado **oficial**, ronda **final**, lugar «Pista ficticia (PRUEBA)».

| # | Qué hacer | Esperado | Observado | Pasa / Falla | Incidencia |
|---|---|---|---|---|---|
| 7 | Ficha de Álex → Objetivos → fila «200» → casilla **2026/27** → «Prueba del catálogo»: **200 m lisos** → Objetivo acordado **22,40** → Guardar. Abre otra vez esa casilla (ahora en la fila «200 m lisos») y pon **22,20** → Guardar. | Fila nueva «200 m lisos» con **22,20 acordado**; al abrirla, «Historial de cambios (1)»: era 22,40. La fila «200» del perfil sigue igual (su texto no cambia). | | | |
| 8 | Tests y marcas → Por atleta → Álex → «＋ Resultado»: prueba **200 m lisos**; resultado **22,61**; fecha **25/10/2026**; procedencia **Competición**; ¿Oficial? **Oficial (acta)**; ronda **final**; método **Electrónico de competición**; viento **1,2**; lugar **Pista ficticia (PRUEBA)**; huella **prueba-vivo-1**; categoría vacía → Guardar. | En «200 m lisos», grupo «condiciones no constan · método: electrónico de competición · oficial»: **22,61**, viento 1,2 m/s, categoría **Sénior · calculada al guardar**, fuente «no consta». Arriba: «Objetivo 2026/27: **22,20** acordado» y la diferencia con su limitación. | | | |
| 9 | Repite el paso 8 **igual**. Después, otra vez con huella **prueba-vivo-1** pero resultado **22,60**. | Igual: «Ya estaba guardado (misma huella de importación): no se duplica» (sigue habiendo **un** resultado). Con 22,60: pregunta «Ya estaba importado con otros datos (22,61)… ¿Corregir?» → Aceptar → «Corregido» → el resultado pasa a **22,60** con «corregido (1)». | | | |
| 10 | En ese resultado → «Parciales» → intento 1, los cuatro tramos de 50 m: **6,05 · 5,45 · 5,55 · 5,65** → Guardar. Después ábrelo otra vez, cambia el último (150–200) a **5,55** → Guardar. | Primero: suma **22,70** frente a 22,60 → «**+0,10 s: no cuadra**». Después: suma **22,60** → «**cuadra**». Un tramo vacío no se guarda (no es un cero). | | | |
| 11 | Competiciones → «＋ Competición de prueba…»: `Control PRUEBA (ficticio)`, una fecha próxima, Alicante. | Sale con «Prueba · no se publica». No pide confirmar un cambio público. | | | |
| 12 | En ella, «＋ Atleta…»: Álex, prioridad **A**, propósito **Control**, pruebas **60 m lisos 17:00** y **60 m vallas 17:15**. Otra vez «＋ Atleta…»: Bruno, prioridad **C**, **60 m lisos** «Previsto». | Dos prioridades distintas en el mismo evento. Aviso «… a las 17:00 y … a las 17:15: 15 min entre una y otra» sin cambiar nada. El cuadro dice «Interno de Academia: no se publica». | | | |
| 13 | Bruno → «Editar…» → estado «No participó» sin motivo → Guardar; luego motivo «prueba» → Guardar. | Sin motivo: «Escribe el motivo…» y no guarda. Con motivo: guardado, a la vista como «No participó «prueba»». | | | |
| 14 | En la prueba de Álex (60 m lisos), «＋ Resultado» **7,15**, Oficial, ronda final, huella `prueba-vivo-2`, marcando «realizado»; después otro **7,05**, «No oficial (tiempo del entrenador u otro)», método manual. | Los dos en la competición (Oficial 7,15 · No oficial 7,05); la inscripción pasa a **Realizado**; en Tests y marcas, en **grupos distintos** (oficial / no oficial). | | | |
| 15 | «Nombre, fecha, lugar o estado…» de la competición de prueba: cambia la fecha (+1 día); después estado **Cancelada**. | «Fecha cambiada», aviso de que el día de las pruebas queda fuera; luego «Cancelada». Inscripciones intactas; historial con los dos cambios. | | | |
| 16 | Recarga el calendario de la web (paso 6). En el móvil, repite los pasos 2, 8 y 12. | En la web no aparece «Control PRUEBA». En el móvil se lee todo sin desplazar de lado. | | | |

## C · Carga y contenidos (solo grupo PRUEBA)

**Álex, semana del 26 oct al 1 nov** (usa ‹ si ya es otra semana). Cifras calculadas
con los datos de PRUEBA a 29-oct; si se hace después de las 22:00 del jueves 29, el
jueves pasa a contar en el feedback (2 de 4).

| # | Qué hacer | Esperado | Observado | Pasa / Falla | Incidencia |
|---|---|---|---|---|---|
| 17 | Menú → **Carga y contenidos**, grupo PRUEBA, Álex. Después cambia al grupo real. | Carrera total: previsto **1.140 m** · «Completa» (declaración global) **340 m** · sin datos **800 m**; sin «Confirmado registrado» (no hay detalle por fila). Aceleración **220 m** (propuesta de la sesión); objetivo pendiente **120 m**; ritmo específico **800 m** sin datos. Fuerza **18 reps / 6 series** por «completa»; saltos cajón **6**. Con el grupo real: «De momento funciona solo con el grupo de prueba». | | | |
| 18 | Toca «Carrera total · «Completa»» y «Ritmo específico · Sin datos». | Lista de las filas: lun 26 y mar 27 con «fuente: atleta (declaración global: sesión completa)»; mié 28, «sin datos». | | | |
| 19 | Anota las cifras de Carrera total y de Cobertura. «Sesiones y lectura de cada fila» → mar 27 → «Transferencia: 2x60 al 80% // 3′ Z» → «Revisar lectura…» → objetivo **Aceleración** → «Guardar la corrección». | **Cambia solo la clasificación**: Aceleración **220 → 340 m**, desaparece «Objetivo pendiente», la fila dice «Corregida». **No cambian** las cantidades ni la ejecución: Carrera total sigue **1.140 / 340 / 800**; Fuerza, saltos y minutos iguales. Cobertura: Clasificación **0 → 120 de 340 m**; Lectura del plan **0 → 1 de 14**; Feedback y Resultado conocido **sin cambios**. | | | |
| 20 | Mira «Cobertura». | Feedback **2 de 3** (el jueves 29 aún en plazo no cuenta); Resultado conocido · repeticiones **25 de 30** («25 solo por «completa»»); distancia **340 de 1.140 m** («340 m solo por «completa»»); Cargas **0 de 6** (series hechas sin kg); Método **0 de 0**. | | | |

## Incidencias

**Fallos funcionales** (se corrigen antes de validar):

| Paso | Qué pasa | Datos para reproducirlo | Estado |
|---|---|---|---|
| | | | |

**Mejoras de comodidad** (para después):

| Paso | Qué mejorar |
|---|---|
| | |

Cuando los 20 pasos pasen (y los fallos estén corregidos y repetidos), la ficha, Tests
y marcas, Competiciones y Carga y contenidos quedan verificadas con sesión iniciada.
