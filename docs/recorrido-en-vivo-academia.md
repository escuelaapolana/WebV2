# Recorrido en vivo · Academia (ficha, Tests y marcas, Competiciones, Carga)

Para comprobarlo en la web **con la sesión iniciada** (unos 30 minutos). **Alcance congelado el 29-oct**: no se añaden funciones antes de este recorrido; solo se corrige lo que falle. Hasta
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

**Pasos 7–10: el mismo caso, en 200 m** (los tiempos de 60 m de antes, 7,20 / 7,18 /
7,15, ya no se usan aquí; el 60 m solo aparece en el paso 14, que es otro caso). Prueba
**200 m lisos** · unidad **segundos** · temporada de planificación **2026/27** (solo
para el objetivo del paso 7) · condiciones: **viento +1,2 m/s**, cronometraje
**electrónico de competición**, resultado **oficial**, ronda **final**, lugar «Pista
ficticia (PRUEBA)».

- **Categoría**: sale de la **fecha de nacimiento ficticia de Álex (10-05-2001)** y de la
  **fecha del resultado (25-10-2026)** → temporada federativa 2026 → **Sénior**. La
  temporada de planificación no interviene (comprobado en la base:
  `categoria_federativa('2001-05-10','2026-10-25')` = Sénior, regla RFEA 2026 verificada).
- **Valores**: objetivo 22,40 → 22,20 · resultado 22,61 → 22,60 · parciales de **4 tramos
  de 50 m (0–50, 50–100, 100–150, 150–200 = 200 m exactos)**: 6,05 + 5,45 + 5,55 + 5,65 =
  22,70 (no cuadra, +0,10) → con 5,55 en el último, 22,60 (cuadra).

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
| 20 | Mira «Cobertura». | Feedback **2 de 3** (el jueves 29 aún en plazo no cuenta); Resultado conocido · repeticiones **25 de 30** («25 solo por «completa»»); distancia **340 de 1.140 m** («340 m solo por «completa»»); Cargas **0 de 6** con «**6 realizadas solo por «completa» (declaración global, sin kg)**»: la ejecución viene de la declaración global y se ve; Método **0 de 0**. | | | |

## Resultado · 29-oct-2026 (sesión de Andrés, versión 0bc7ed60)

Hecho en el navegador integrado con la sesión de Andrés (admin), escritorio y 375 px.
Las escrituras, solo en «Academia AC98 · PRUEBA»: comprobado después en la base que
**ninguna fila escrita hoy es de un atleta o competición real** (marcas 3, parciales 4,
objetivo 1, inscripciones 3, plan de competición 2, competición 1 de prueba, lectura 1).
Un visitante anónimo no ve ni la competición de prueba ni sus inscripciones.

| # | Observado | Pasa / Falla |
|---|---|---|
| 1 | En móvil la banda sale abreviada («Prueba · ficticio»), en escritorio completa. En Hoy los atletas salen solo con el nombre; «Ficticio (prueba)» en la ficha. | Pasa |
| 2 | «Categoría federativa hoy: Sénior», «Temporada de planificación: 2026/27», sin avisos de lectura. **No decía que 2026/27 es provisional** (en la base, `confirmada = false`). | **Falla** → corregido (ver abajo), repetir tras subir |
| 3 | «200» sin confirmar en el catálogo; **«100» sale como «ambigua»** (es una de las 6 ambiguas: más exacto que lo que esperaba el guion). «Sin registrar» donde no hay datos. | Pasa |
| 4 | 14 protocolos con «Falta para comparar»; 6 ambiguas. «Ver usos…» de «60» enseña **nombres** de otros grupos: es lo previsto para un **admin** (`soy_admin_de_verdad`); «Atleta de otro grupo» es lo que ve quien no tiene permiso sobre ese atleta. | Pasa |
| 5 | Leyenda A/B/C con «Ninguna prioridad cambia el entrenamiento». En «I Control ST»: «Datos públicos del evento…» y «Academia … no se publican», separados. Mes y Mínimas sin errores. | Pasa |
| 6 | Calendario público sin «PRUEBA»; anónimo: 0 competiciones de prueba (había 0 de prueba y 82 reales). | Pasa |
| 7 | Fila nueva «200 m lisos» con **22,20 acordado** · «1 cambio»; historial «era «22,40»». La fila «200» intacta. | Pasa |
| 8 | Grupo «condiciones no constan · método: electrónico de competición · oficial»: **22,61**, 1,2 m/s, **Sénior · calculada al guardar** (base: `categoria_origen = calculada`), fuente «no consta»; «Objetivo 2026/27: 22,20 acordado» y «+0,41 s respecto al acordado». | Pasa |
| 9 | Igual: «Ya estaba guardado (misma huella de importación): no se duplica». Con 22,60: «Ya estaba importado con otros datos (22,61 el 25/10/2026)… ¿Corregir…?» → «Corregido» → **22,60 · corregido (1)**; un solo resultado. | Pasa |
| 10 | Vienen 4 tramos de 50 m (0–200). «suma 22,70 frente al total 22,60: **+0,1 s: no cuadra**»; con 5,55: «suma 22,60 … **cuadra**». En la base, 4 tramos, ningún cero; el 5,65 queda en el historial. | Pasa |
| 11 | «Prueba · no se publica»; no pidió confirmar ningún cambio público; anónimo no la ve. | Pasa |
| 12 | A (Álex, propósito control) y C (Bruno) en el mismo evento; «⚠ 60 m lisos a las 17:00 y 60 m vallas a las 17:15: 15 min entre una y otra. Aviso: no se cambia nada.»; «Interno de Academia: no se publica». | Pasa |
| 13 | Sin motivo: «Escribe el motivo de cada prueba que no se hizo o se cancela» y no guarda. Con motivo: «60 m lisos No participó «prueba»». | Pasa |
| 14 | «Oficial 7,15 final» y «No oficial 7,05 manual»; inscripción → **Realizado**; mejor marca oficial sigue 7,15. En Tests y marcas, dos grupos («se ven juntos, no se comparan»). | Pasa |
| 15 | «fecha cambiada», «Antes era el 7 nov 2026», «⚠ … su día (7 nov 2026) queda fuera de las fechas de la competición» (las dos de Álex). Después «Cancelada» con su explicación; «2 cambios en el historial»; las 3 inscripciones intactas (base). | Pasa |
| 16 | Web sin «Control PRUEBA». A 375 px, ficha, Tests y marcas y Competiciones sin desplazamiento lateral (ancho de página = 375). | Pasa |
| 17 | Carrera total 1.140 / 340 / 800; aceleración 220; objetivo pendiente 120; ritmo específico 800 sin datos; fuerza 18 reps / 6 series y cajón 6 por «completa». Grupo real: «De momento funciona solo con el grupo «Academia AC98 · PRUEBA»». | Pasa |
| 18 | «Completa»: 12 filas, 340 m = lun 26 220 + mar 27 120, todas «fuente: atleta (declaración global: sesión completa)». «Sin datos»: mié 28, 4 filas (250+150+250+150). | Pasa |
| 19 | «Lectura corregida (queda en su historial)»; fila «Lectura corregida». Aceleración **220 → 340**, sin «Objetivo pendiente»; Carrera total **1.140 / 340 / 800**; fuerza, saltos y minutos iguales. Clasificación **0 → 120 de 340**, lectura **0 → 1 de 14**; feedback y resultado conocido sin cambios. | Pasa |
| 20 | Feedback 2 de 3; repeticiones 25 de 30 («25 solo por «completa»»); distancia 340 de 1.140 («340 m solo por «completa»»); **Cargas 0 de 6 · «6 realizadas solo por «completa» (declaración global, sin kg)»**; método 0 de 0. | Pasa |

## Incidencias

**Fallos funcionales** (se corrigen antes de validar):

| Paso | Qué pasa | Datos para reproducirlo | Estado |
|---|---|---|---|
| 2 | La cabecera de la ficha no decía que la temporada de planificación es provisional. | Álex (PRUEBA); `temporadas_planificacion` 2026/27 con `confirmada = false`. | Corregido en el código: «(provisional: fechas por confirmar)». **Repetir el paso 2 tras subirlo.** |

**Mejoras de comodidad** (para después; alcance congelado):

| Paso | Qué mejorar |
|---|---|
| 9 | La diferencia sale «+0,4 s» en vez de «+0,40 s» (con 22,61 salía +0,41). |
| 10 | Corregir un tramo deja en el historial los 4 tramos como «borrados» (se guarda el intento entero); el dato está, pero cuesta leerlo. |
| 13 | «Escribe el motivo…» sale solo como aviso flotante, no junto a la casilla. |
| 14 | El resultado propone la fecha de la competición aunque sea futura (7 nov) sin avisar. |
| 16 | En el resumen de la ficha, «Pendiente: Objetivo 2026/27 sin registrar: 100, 200» convive con «200 m lisos: 22,20»: el «200» del perfil aún no está emparejado con el catálogo. Se resuelve al confirmar «200» en el Catálogo. |
| — | Navegación duplicada (lateral + pestañas arriba) que resta espacio. *(ChatGPT)* |
| — | Ficha: «Objetivo» y «Próximas competiciones» son tarjetas muy altas aunque tengan una línea; ajustarlas al contenido. *(ChatGPT)* |
| — | Dentro de la ficha de Álex el lateral marca «Hoy»: debería marcar Atletas. *(ChatGPT)* |
| — | Feedback: cabecera, explicaciones y filtros dejan el primer registro al fondo; acortar y agrupar filtros. *(ChatGPT)* |
| — | «Desde» y «hasta» en líneas separadas: mantenerlas como un intervalo. *(ChatGPT)* |
| — | Tests y marcas: «＋ Resultado», «Parciales» e historial son acciones pequeñas; darles más presencia sin añadir botones. *(ChatGPT)* |

Cuando los 20 pasos pasen (y los fallos estén corregidos y repetidos), la ficha, Tests
y marcas, Competiciones y Carga y contenidos quedan verificadas con sesión iniciada.
