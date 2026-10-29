# Carga y contenidos — definiciones para aprobar (PROPUESTA v2, sin programar)

> 29-oct-2026 · Parte del [modelo v2](modelo-datos-seguimiento.md) y de los
> [ejemplos ya revisados](ejemplos-calculo-academia.md). **Nada de esto se calcula
> todavía ni se aplica a sesiones reales**: primero se aprueban las reglas.
> Objetivo: ver cuánto se ha trabajado de cada contenido y **con qué calidad de
> información**, sin inventar una precisión que los registros no tienen.

## 1. Tres cosas separadas en cada dato

Cada cantidad se guarda y se enseña con tres capas que **no se mezclan**:

| Capa | Qué dice | Ejemplo |
|---|---|---|
| **Cantidad** | número y unidad | 60 m · 6 reps · 12 contactos · 3×5 a 80 kg |
| **Clasificación** | **medio** (cómo se hizo) + **objetivo** (para qué) + etiquetas, con su estado de revisión | medio: arrastre 10 kg · objetivo: aceleración · revisada |
| **Procedencia** | autor, fuente, ¿estimado?, método, correspondencia con el plan, completitud (modelo v2 §0) | atleta · declaración · no estimado · no consta · exacta · completo |

- **Una clasificación pendiente no esconde la cantidad**: «60 m confirmados ·
  objetivo pendiente».
- Estados de la clasificación: `propuesta_auto` · `pendiente_revision` · `revisada` ·
  `manual` (modelo v2 §2). Cambiarla deja historial y no toca la cantidad.
- **Cada unidad va por separado** (m, min, reps, series, kg, saltos, contactos,
  intentos, vallas, lanzamientos). No hay un «volumen» ni una «carga» únicos.
- **Intención ≠ respuesta.** El objetivo es la **intención prevista** (la escribe o la
  revisa el entrenador). La **respuesta observada** son los tiempos, los kg usados, el
  RPE, el % completado, las molestias. **No se deduce un estímulo fisiológico** de la
  distancia ni de un «al 90 %» orientativo («glucolítico» es siempre intención).

## 2. Previsto y realizado: dos dimensiones distintas

| Dimensión | Qué es | Sale de |
|---|---|---|
| **Previsto** | lo que pedía la versión que respondió el atleta; obligatorio y opcional por separado | la estructura de la fila |
| **Realizado confirmado** | lo que se puede atribuir sin ambigüedad a una fila o repetición, **o** trabajo adicional apuntado | ✓ del bloque, series apuntadas, tiempo vinculado, kg por serie, toma del entrenador |
| **Adicional** | realizado confirmado que **no estaba previsto** (más reps, otra fila, sesión extra) | registro del atleta o del entrenador |
| **No realizado** | alguien dice que no se hizo (con su motivo) | atleta o entrenador |
| **Sin concretar** | había previsto y hay registro, pero no dice qué parte se hizo | % global, «a medias», un tiempo suelto |
| **Sin datos** | no hay registro | — |

- **Lo confirmado puede ser menor, igual o mayor que lo previsto.** Lo de más se
  enseña como **adicional**, separado; nunca se recorta al plan.
- **El total realizado** de una sesión o semana solo es **conocido** cuando cada parte
  prevista está confirmada o declarada no realizada. Si no, se escribe **«480 m
  confirmados; total realizado desconocido»**.
- **Lo que falta nunca es cero** ni se rellena con el plan. «Sin datos» no es «no
  hecho».
- Lo **opcional** solo cuenta si se confirma; si no, no está «pendiente» de nada.

## 3. Medio y objetivo

- **Medio** = cómo se hizo: carrera libre, arrastre (con su carga), cuesta, salida de
  tacos, con vallas, calzado (clavos o zapatillas), implemento, cajón…
- **Objetivo** = para qué: aceleración, velocidad máxima, resistencia a la velocidad,
  ritmo específico, glucolítico (intención), aeróbico, técnica, fuerza…
- **Los metros se cuentan una vez**, con su objetivo; el medio los describe. Así se
  puede ver «metros de aceleración (de ellos, con arrastre: 60 m)» y «metros con
  arrastre (objetivo: aceleración 60 m)» sin contar dos veces.
- Ejemplo A1 «3 × (20 m trineo + 20 m libre)»: 120 m de carrera · objetivo
  aceleración 120 m · de ellos **60 m con arrastre** (carga: pendiente) · 120 m con
  zapatillas. Si el entrenador quiere que el trineo cuente como «fuerza horizontal»,
  lo pone como objetivo de esos 60 m, y los metros siguen siendo los mismos.

## 4. Carrera

**Carrera total** = toda la carrera, con calentamiento y vuelta a la calma corriendo.
**Carrera principal** = la de la parte principal. La **entrada progresiva** de un
lanzado es carrera total, pero no aceleración ni velocidad máxima. **Una carrera
completa con objetivo técnico sigue siendo carrera** (§5).

Para todos los objetivos de carrera: **previsto** = la fila de la versión respondida;
**confirmado** = ✓ del bloque, reps apuntadas o tiempo vinculado a esa repetición;
**sin concretar** = % global o tiempo suelto; **sin datos** = sin registro.

### 4.1 Aceleración
- **Incluye**: tramos desde parado o salida (tacos, de pie, 3 apoyos) con objetivo de
  acelerar, sea cual sea el medio (libre, arrastre, cuesta).
- **Excluye**: la entrada progresiva de un lanzado; los progresivos de calentamiento.
- **Unidad**: m · reps · salidas.
- **Datos**: distancia del tramo, reps, tipo de salida, medio.
- **Una sola vez**: un tramo tiene un solo objetivo (aceleración **o** velocidad
  máxima); las salidas de tacos y el arrastre son medio, no metros de más.
- **Ejemplo**: «4×30 m tacos // 3′ C» → 120 m de aceleración · medio: tacos (4
  salidas) · clavos 120 m.
- **Ambiguo**: «4×40 progresivos» → 160 m de carrera; ¿aceleración o calentamiento?
  Objetivo pendiente.

### 4.2 Velocidad máxima
- **Incluye**: el tramo lanzado cuando el objetivo es velocidad máxima (decisión 1).
- **Excluye**: la entrada progresiva; lanzados con objetivo de ritmo o resistencia.
- **Unidad**: m lanzados · reps.
- **Datos**: entrada y tramo por separado; objetivo.
- **Una sola vez**: total de la rep. = entrada + tramo (I1); solo el tramo es
  velocidad máxima.
- **Ejemplo**: «3×60 lanzados, entrada 20 + tramo 60 · velocidad máxima» → 240 m de
  carrera · 60 m entrada progresiva · 180 m de velocidad máxima.
- **Ambiguo**: B1 «2×30 flying (20+30)» sin objetivo → 100 m de carrera (40 m entrada
  progresiva + 60 m lanzados), **objetivo de los 60 m pendiente**.

### 4.3 Resistencia a la velocidad
- **Incluye**: lo que tenga ese objetivo escrito (decisión 2).
- **Excluye**: series rápidas sin ese objetivo.
- **Unidad**: m · reps. **Datos**: distancia, reps, recuperación, objetivo.
- **Una sola vez**: «metabólico» es una familia para ver la semana, no otra suma.
- **Ejemplo**: «2×4×120 al 82–87 % · Resistencia a la velocidad» → 960 m.
- **Ambiguo**: «6×150 al 85 % // 3′» sin objetivo → 900 m, objetivo pendiente.

### 4.4 Ritmo específico de competición
- **Incluye**: tramos con tiempo objetivo sacado de la prueba del atleta.
- **Excluye**: «al 90 %» sin marca u objetivo de referencia.
- **Unidad**: m · reps · tiempo objetivo.
- **Datos**: tiempo objetivo + la marca u objetivo acordado de referencia.
- **Una sola vez**: el tramo es ritmo específico, no también resistencia.
- **Ejemplo**: C1 «2×(250+150) 34–35″ / 19,5–20,5″ · Ritmo 400» → 800 m de ritmo
  específico.
- **Ambiguo**: el mismo texto sin objetivo ni referencia → 800 m, objetivo pendiente.

### 4.5 Glucolítico (solo intención)
- **Incluye**: lo que el entrenador marque con esa intención. **Excluye**: cualquier
  deducción por distancia, ritmo o RPE; nunca «lactato».
- **Unidad**: m · reps. **Datos**: la intención escrita.
- **Ejemplo**: «3×300 máximo // 10′ · glucolítico» → 900 m con esa intención.
- **Ambiguo**: «3×300 fuerte» → 900 m, objetivo pendiente.

### 4.6 Aeróbico (rodaje, intervalos, fartlek)
- **Incluye**: carrera continua o intervalos largos con ese objetivo.
- **Excluye**: calentamiento y vuelta a la calma (4.7).
- **Unidad**: **min**; m solo si se miden (o km **estimados** con el ritmo, marcados
  como estimación, H2).
- **Datos**: duración; distancia medida o ritmo.
- **Una sola vez**: el trote de recuperación va en minutos (decisión 7).
- **Ejemplo**: C2 «5×1000 en 3:25–3:30 // 2′ trote» → 5.000 m + 8 min de trote.
- **Ambiguo**: «20′ CC» sin ritmo → 20 min, sin km.

### 4.7 Calentamiento y vuelta a la calma corriendo
- **Incluye**: la carrera fuera de la parte principal. **Excluye**: los ejercicios
  técnicos (5.1).
- **Unidad**: min o m. **Una sola vez**: carrera total, no principal.
- **Ejemplo**: «Calentamiento 12′ trote» → 12 min de carrera total.
- **Ambiguo**: «calentamiento habitual» → sin cantidad (pendiente), no cero.

## 5. Técnica: ejercicios técnicos y carreras con objetivo técnico

Dos cosas distintas; la palabra «técnica» **no quita la distancia de carrera**:

| | Ejercicio técnico | Carrera con objetivo técnico |
|---|---|---|
| Qué es | skipping, talones, A/B, rebotes, multisaltos técnicos | carreras completas con objetivo técnico (postura, frecuencia, relajación) |
| ¿Metros de carrera? | **no** | **sí** (carrera total y, si va en la parte principal, principal) |
| Unidad | reps · min · m de ejercicio (aparte) | m · reps |
| Objetivo | técnica de carrera | técnica de carrera |

### 5.1 Ejercicio técnico (drills)
- **Incluye**: skipping, talones, A/B, rebotes, multisaltos técnicos.
- **Excluye**: carreras completas (5.2).
- **Unidad**: reps · min · m de ejercicio (nunca carrera).
- **Datos**: duración o reps. **Estados**: ✓ o minutos declarados.
- **Una sola vez**: sus metros no entran en carrera.
- **Ejemplo**: «Técnica 15′: skipping, talones, A-B» → 15 min de ejercicio técnico.
- **Ambiguo**: «4×(30 skipping + 20 progresivo)» → 120 m de skipping (ejercicio) y
  80 m de carrera con objetivo pendiente (decisión 4).

### 5.2 Carrera con objetivo técnico
- **Incluye**: «4×60 relajado · técnica», «rectas técnicas 6×80».
- **Excluye**: drills.
- **Unidad**: m · reps. **Datos**: distancia, reps, objetivo.
- **Una sola vez**: son metros de carrera con objetivo «técnica de carrera»; no se
  cuentan también en aceleración.
- **Ejemplo**: «6×80 rectas técnicas Z» → 480 m de carrera · objetivo técnica.
- **Ambiguo**: «6×80 rectas» sin objetivo → 480 m de carrera, objetivo pendiente.

### 5.3 Técnica de vallas
- **Incluye**: intentos con vallas, vallas franqueadas, ejercicios de paso.
- **Unidad**: intentos · vallas (por altura) · m solo si se conocen separación y
  final medido.
- **Datos**: altura, separación, distancia a la 1.ª, final medido (E1-E2).
- **Una sola vez**: si se conocen los metros, son carrera con objetivo técnica de
  vallas (o el que diga el bloque), no dos veces.
- **Ejemplo**: E2 «2×3 vallas a 0,84 m · 3 apoyos» → 2 intentos · 6 vallas a 0,84 m.
- **Ambiguo**: E1 sin altura ni separación → intentos y vallas sí; metros y
  comparación, pendientes.

### 5.4 Técnica de saltos y lanzamientos de prueba
- **Incluye**: batidas, saltos con carrera de su prueba, lanzamientos técnicos.
- **Unidad**: intentos por modalidad (§7), y la carrera de impulso si se conoce.
- **Ejemplo**: «6 batidas de altura con 5 apoyos» → 6 intentos de batida de altura.
- **Ambiguo**: «saltos de longitud con 6 apoyos» sin número → pendiente.

## 6. Fuerza

### 6.1 Fuerza en gimnasio (estructural, máxima, potencia, complementaria)
- **Incluye**: ejercicios con carga o autocarga.
- **Excluye**: los saltos de un bloque combinado (§7).
- **Unidad**: series · reps (por lado si es unilateral) · kg previstos y usados.
- **Datos**: ejercicio y variante; %RM con el RM **de esa variante** (medido o
  estimado); kg por serie; si los kg son por mancuerna o total.
- **Estados**: kg previstos solo con RM de esa variante (D1); confirmado con kg y reps
  por serie; si no, sin concretar.
- **Una sola vez**: cada componente de un bloque combinado en su unidad (D2: 9 rep. de
  sentadilla + 6 saltos, no 15).
- **Ejemplo**: D1 «Cargada 4×3 al 60–65 % RM», RM 80 kg medido → 12 rep. · 48–52 kg
  previstos (cálculo).
- **Ambiguo**: D4 RDL unilateral con solo RM bilateral → reps sí; kg ausentes.

### 6.2 Arrastres
- Son **medio** (§3): sus metros son carrera con su objetivo (aceleración, fuerza
  horizontal…), con la **carga** (decisión 8).

## 7. Saltos y lanzamientos (no de prueba)

Cada acción conserva **modalidad, unidad, implemento o carga y lado**. Solo se suman
acciones **de la misma modalidad y unidad**:

| Modalidad (ejemplos) | Unidad | Implemento / carga |
|---|---|---|
| Salto al cajón | saltos | altura del cajón |
| CMJ, SJ | saltos | sin carga / chaleco kg |
| Drop jump | saltos | altura de caída |
| Pogos, comba | contactos | — |
| Multisaltos horizontales | contactos o saltos (decisión 5) | — |
| Lanzamiento de balón | lanzamientos | peso del balón, posición |

- **Una sola vez y sin equivalencias**: 12 pogos y 15 saltos al cajón son «12
  contactos de pogos» y «15 saltos al cajón de 60 cm», nunca «27 saltos».
- **Ejemplo**: «2×6 pogos + 3×5 cajón 60 cm» → 12 contactos (pogos) · 15 saltos
  (cajón, 60 cm).
- **Ambiguo**: «3×10 multisaltos» → ¿contactos o saltos? Pendiente (decisión 5).
- **Lanzamientos**: «3×6 balón 4 kg de espaldas» → 18 lanzamientos · balón 4 kg ·
  de espaldas. Sin peso → número sí, peso ausente.

## 8. Movilidad, preventivos y recuperación
- **Incluye**: movilidad, core, preventivos, estiramientos, rodillo.
- **Excluye**: fuerza con carga (6.1).
- **Unidad**: **min** si el plan los da; si no, ejercicios × series × reps. No se
  convierte una unidad en otra.
- **Estados**: ✓ (hecho o no hecho) si el plan no da cantidad.
- **Ejemplo**: «Core 10′ + nórdicos 3×5» → 10 min de core · 15 rep. de nórdicos.
- **Ambiguo**: «preventivos» sin detalle → hecho o no hecho, sin cantidad.

## 9. Medios y exposiciones (describen; no se suman encima)

| Medio / exposición | Unidad | Es parte de | Dato necesario |
|---|---|---|---|
| Clavos | m | carrera total | calzado de la fila |
| Arrastre | m + carga | carrera total | arrastre y carga |
| Cuesta | m + pendiente | carrera total | pendiente (si se sabe) |
| Salidas de tacos | salidas | la carrera de esa fila | tipo de salida |
| Vallas | vallas por altura | carrera o técnica | altura |

- **Ambiguo**: fila sin calzado → metros sí; «con clavos» **no consta** (no se supone).

## 10. Cobertura: varios indicadores, nunca uno mezclado

Cada indicador tiene su numerador y su denominador, **por atleta y periodo**. Se
enseñan por separado y con sus números (no solo el %):

| Indicador | Numerador | Denominador | Fuera |
|---|---|---|---|
| **Feedback** | sesiones previstas con registro (del atleta o, si su seguimiento es por el entrenador, del entrenador) | sesiones de entreno publicadas para el atleta cuyo plazo de feedback ya pasó | descansos; días con ausencia declarada (se cuentan aparte) |
| **Repeticiones** (por objetivo) | reps previstas obligatorias con resultado conocido (confirmadas o declaradas no hechas) | reps previstas obligatorias | opcionales y adicionales (aparte) |
| **Distancia** (por objetivo) | m previstos obligatorios con resultado conocido | m previstos obligatorios | adicionales (aparte) |
| **Clasificación** | m (o reps) confirmados con objetivo revisado | m (o reps) confirmados | — |
| **Cargas** | series previstas con carga y kg apuntados | series previstas con carga | — |
| **Método** (tiempos) | tiempos con método conocido | tiempos apuntados | — |

Ejemplo de una semana de un atleta:

| | Previsto | Confirmado | Adicional | Total realizado |
|---|---|---|---|---|
| Aceleración (m) | 360 | 300 | 0 | desconocido (60 m sin concretar) |
| Velocidad máxima (m) | 180 | 180 | 0 | 180 m (conocido) |
| Objetivo pendiente (m) | 120 | 120 | 30 | 150 m |

Cobertura: feedback 4 de 5 sesiones · distancia 600 de 660 m previstos con resultado
conocido · clasificación 480 de 630 m confirmados revisados · cargas 6 de 8 series.

- Con poca cobertura las cifras se ven igual, con su aviso: una semana poco
  registrada no se lee como una semana de poca carga.
- Dos semanas se comparan solo en lo confirmado y enseñando la cobertura de las dos.

## 11. Las diez decisiones que necesito cerrar contigo

**1. ¿Qué basta para proponer «velocidad máxima» en un lanzado?**
Propuesta: que el título u objetivo del bloque lo diga. Sin eso, objetivo pendiente
(los metros cuentan).
Ejemplo: «Bloque Vmáx: 3×30 flying (20+30)» → 90 m de velocidad máxima + 60 m de
entrada progresiva. «3×30 flying (20+30)» sin título → 90 m lanzados con objetivo
pendiente.

**2. ¿«Resistencia a la velocidad» y «ritmo específico» se proponen solos?**
Propuesta: solo con título u objetivo del bloque; el ritmo, además, con la marca u
objetivo acordado de referencia en la ficha.
Ejemplo: «2×(250+150) · Ritmo 400» con objetivo acordado en 400 m → propuesta «ritmo
específico» (a revisar). Sin objetivo de 400 en la ficha → 800 m, objetivo pendiente.

**3. Progresivos y rectas de calentamiento: ¿carrera o técnica?**
Propuesta: carrera total (no principal) con objetivo «calentamiento», salvo que el
bloque sea de técnica o de aceleración.
Ejemplo: «Calentamiento: 10′ trote + 4×80 progresivos» → 10 min + 320 m de carrera
total; ninguno cuenta como aceleración.

**4. ¿Cuándo una carrera con «técnica» es carrera y cuándo ejercicio técnico?**
Propuesta: ejercicio técnico = drills del catálogo (skipping, A/B…); todo lo demás
que sea correr de verdad es carrera con objetivo técnico.
Ejemplo: «4×(30 skipping + 20 progresivo)» → 120 m de skipping (ejercicio técnico) +
80 m de carrera; «6×80 rectas técnicas» → 480 m de carrera con objetivo técnica.

**5. Multisaltos: ¿saltos o contactos?**
Propuesta: cada ejercicio del catálogo fija su unidad: pogos y comba en contactos;
multisaltos horizontales en contactos (cada apoyo); saltos al cajón, CMJ y drop jump
en saltos. Sin unidad fijada, pendiente.
Ejemplo: «3×10 multisaltos horizontales» → 30 contactos de multisaltos; no se suman
con «15 saltos al cajón».

**6. Balón medicinal: ¿fuerza o lanzamientos?**
Propuesta: lanzamientos, con peso y posición; no cuentan como series de fuerza
aunque vayan en el bloque de gimnasio.
Ejemplo: «3×6 balón 4 kg de espaldas» → 18 lanzamientos de 4 kg (de espaldas).

**7. Trote de recuperación entre series**
Propuesta: minutos de carrera total; metros solo si se dan.
Ejemplo: «5×1000 // 2′ trote» → 5.000 m + 8 min de trote (sin metros inventados).

**8. Arrastres: medio, carga y objetivo**
Propuesta: medio «arrastre» siempre, con dos cargas (discos añadidos y masa total, la
que se sepa); objetivo el del bloque (aceleración por defecto si el bloque es de
aceleración; si no, pendiente). Los metros, una vez.
Ejemplo: A1 → 120 m de aceleración, de ellos 60 m con arrastre (carga pendiente). A2
«3×40 arrastre (12 kg)» → 120 m con arrastre; «12 kg» pendiente de saber si son discos
o masa total.

**9. Familias para ver la semana**
Propuesta: carrera rápida (aceleración, velocidad máxima), metabólico (resistencia,
ritmo, glucolítico, aeróbico), fuerza, impactos (saltos y lanzamientos por
modalidad), técnica, recuperación. Solo agrupan a la vista; no suman distinto de sus
contenidos ni mezclan unidades.
Ejemplo: «Carrera rápida: 300 m aceleración + 180 m velocidad máxima» (no «480 m de
carrera rápida» a secas si una parte está sin concretar).

**10. Cobertura: indicadores y plazo**
Propuesta: los seis indicadores del §10, por separado, y una sesión cuenta en el
denominador de feedback cuando ha pasado su plazo (el del grupo, hoy 22:00 del día).
Ejemplo: lunes con plazo vencido y sin registro → cuenta como «sin feedback»; el
miércoles de hoy, aún en plazo → no cuenta todavía.

## 12. Fuera de esta entrega
- Programar cálculos, clasificar sesiones reales o rellenar contenidos de lo antiguo.
- Proyecciones, tendencias, carga combinada, índices y RPE × duración.
- Importar los Excel. La conexión de ChatGPT sigue limitada a PRUEBA.
