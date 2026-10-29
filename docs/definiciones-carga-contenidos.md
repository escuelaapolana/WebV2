# Carga y contenidos — definiciones para aprobar (PROPUESTA, sin programar)

> 29-oct-2026 · Parte del [modelo v2](modelo-datos-seguimiento.md) y de los
> [ejemplos ya revisados](ejemplos-calculo-academia.md). **Nada de esto se calcula
> todavía ni se aplica a sesiones reales**: primero se aprueban las reglas.

## 0. Reglas comunes

1. **Cantidad y clasificación son cosas distintas.** Una cantidad (metros,
   repeticiones, kg…) puede ser válida aunque su contenido esté pendiente:
   «480 m confirmados · contenido: 360 m aceleración, 120 m pendiente».
2. **Cada unidad va por separado** (m, min, reps, series, kg, saltos, contactos,
   intentos, vallas, lanzamientos). No hay un «volumen» ni una «carga» únicos que
   mezclen unidades.
3. **Intención prevista ≠ respuesta observada.**
   - El **contenido** es la intención del plan (lo decide el entrenador o se propone
     con datos suficientes).
   - La **respuesta** es lo observado: tiempos, kg usados, RPE, % completado,
     molestias, comentarios.
   - **No se deduce un estímulo fisiológico** solo por la distancia ni por un «al
     90 %» orientativo («glucolítico» es siempre intención).
4. **Cuatro estados de una cantidad**:

   | Estado | Qué es | De dónde sale |
   |---|---|---|
   | **Previsto** | lo que pedía la versión que respondió el atleta (obligatorio y opcional por separado) | estructura de la fila |
   | **Confirmado** | se puede atribuir a esa fila o repetición sin ambigüedad | ✓ del bloque, series apuntadas, tiempo vinculado, kg por serie, toma del entrenador |
   | **Sin concretar** | estaba previsto y hay registro, pero no dice si se hizo esa parte | % global, «a medias», un tiempo suelto |
   | **Sin datos** | no hay registro | sesión «sin datos» (ni hecha ni no hecha) |

   Además: **no realizado** solo si alguien lo dice (el atleta o el entrenador), con
   su motivo. Lo **opcional** cuenta solo si se confirma.
5. **Contar una sola vez.** Cada cantidad tiene un **contenido principal** (el único
   que la suma). Las **etiquetas** (tacos, test, clavos…) describen, no suman. Las
   **exposiciones** (§6) son subconjuntos del total y nunca se suman encima.
6. **Cobertura siempre a la vista.** Toda cifra de una semana va con cuánto dato
   falta, para que una semana poco registrada no parezca una semana de poca carga
   (§7).
7. **Lo ambiguo queda pendiente** y se dice qué falta; nunca se completa con una
   suposición.

## 1. Carrera

Base común: los metros salen de la estructura de la fila (bloques × secuencia ×
tramos). **Carrera total** incluye calentamiento y vuelta a la calma corriendo;
**carrera principal**, solo la parte principal. La **entrada progresiva** de un
lanzado es carrera total, pero no aceleración ni velocidad máxima.
En todos los contenidos de carrera, **previsto** = la fila de la versión respondida;
**confirmado** = ✓ del bloque, repeticiones apuntadas o tiempo vinculado a esa
repetición; **sin concretar** = % global o tiempo suelto; **sin datos** = sin registro.

### 1.1 Aceleración (incluye salidas)
- **Incluye**: tramos desde parado o desde salida (tacos, de pie, 3 apoyos) con
  objetivo de acelerar; los metros libres tras un arrastre (A1).
- **Excluye**: la entrada progresiva de un lanzado; los metros con arrastre (son
  fuerza horizontal); progresivos de calentamiento.
- **Unidad**: m · reps · salidas.
- **Datos**: distancia del tramo, reps y tipo de salida.
- **Estados**: los comunes de carrera; las salidas se confirman con las reps.
- **Una sola vez**: un tramo es aceleración **o** velocidad máxima; las salidas de
  tacos son exposición (§6), no metros de más.
- **Ejemplo**: «4×30 m tacos // 3′ C» → 120 m de aceleración · 4 salidas de tacos ·
  120 m con clavos.
- **Ambiguo**: «4×40 progresivos» → ¿aceleración o técnica? Pendiente hasta que el
  título u objetivo del bloque lo diga.

### 1.2 Velocidad máxima
- **Incluye**: el tramo lanzado cuando la intención es velocidad máxima (título u
  objetivo del bloque, o intensidad con una referencia que se apruebe).
- **Excluye**: la entrada progresiva; lanzados con intención de ritmo o resistencia.
- **Unidad**: m lanzados · reps.
- **Datos**: entrada y tramo por separado; intención.
- **Estados**: los comunes; un tiempo del tramo confirma esa repetición.
- **Una sola vez**: total de la rep. = entrada + tramo (I1); solo el tramo es
  velocidad máxima.
- **Ejemplo**: «3×60 lanzados, entrada 20 m + tramo 60 m · velocidad máxima» →
  240 m totales · 60 m entrada progresiva · 180 m de velocidad máxima.
- **Ambiguo**: B1 «2×30 flying (20+30)» sin objetivo → 60 m lanzados con contenido
  pendiente (no se asume velocidad máxima); los metros sí cuentan.

### 1.3 Resistencia a la velocidad
- **Incluye**: repeticiones rápidas con poca recuperación o tramos largos a alta
  velocidad, si el entrenador lo indica (título u objetivo).
- **Excluye**: lo que no tenga esa intención explícita.
- **Unidad**: m · reps.
- **Datos**: distancia, reps, recuperación e intención.
- **Estados**: los comunes.
- **Una sola vez**: es contenido principal; «metabólico» es solo una familia para ver
  la semana.
- **Ejemplo**: «2×4×120 al 82–87 % // 2′ y 6′ · Resistencia a la velocidad» → 960 m.
- **Ambiguo**: «6×150 al 85 % // 3′» sin título → 900 m, contenido pendiente
  (resistencia o ritmo).

### 1.4 Ritmo específico de competición
- **Incluye**: tramos con tiempo objetivo sacado de la prueba del atleta.
- **Excluye**: «al 90 %» sin marca u objetivo de referencia.
- **Unidad**: m · reps · tiempo objetivo.
- **Datos**: tiempo objetivo y la marca u objetivo acordado de referencia.
- **Estados**: los comunes; el tiempo real se compara con el objetivo solo si está
  vinculado a esa repetición.
- **Una sola vez**: el tramo es ritmo específico, no también resistencia.
- **Ejemplo**: C1 «2×(250+150) 34–35″ / 19,5–20,5″ · Ritmo 400» → 800 m de ritmo
  específico (propuesta, porque el título lo dice).
- **Ambiguo**: el mismo texto sin título ni referencia → 800 m, contenido pendiente.

### 1.5 Capacidad / potencia glucolítica (solo intención)
- **Incluye**: lo que el entrenador marque con esa intención.
- **Excluye**: cualquier deducción por distancia, ritmo o RPE; nunca se habla de
  lactato.
- **Unidad**: m · reps.
- **Datos**: la intención escrita.
- **Estados**: los comunes.
- **Una sola vez**: contenido principal; no se suma también en resistencia.
- **Ejemplo**: «3×300 máximo // 10′ · glucolítico» → 900 m con intención glucolítica.
- **Ambiguo**: «3×300 fuerte» sin intención → 900 m, contenido pendiente.

### 1.6 Aeróbico (rodaje, intervalos, fartlek)
- **Incluye**: carrera continua o intervalos largos a ritmo de resistencia.
- **Excluye**: calentamiento y vuelta a la calma (1.7).
- **Unidad**: **min**; m solo si se miden (o km **estimados** con ritmo, marcados
  como estimación, H2).
- **Datos**: duración; distancia medida o ritmo.
- **Estados**: confirmado con la duración o la distancia declaradas; sin ellas, sin
  concretar.
- **Una sola vez**: el trote de recuperación entre series va en minutos, sin metros
  inventados (C2).
- **Ejemplo**: C2 «5×1000 en 3:25–3:30 // 2′ trote» → 5.000 m + 8 min de trote.
- **Ambiguo**: «20′ CC» sin ritmo → 20 min, sin km.

### 1.7 Calentamiento y vuelta a la calma corriendo
- **Incluye**: la carrera fuera de la parte principal.
- **Excluye**: drills (2.1) y progresivos con intención de aceleración.
- **Unidad**: min o m, lo que diga el plan.
- **Datos**: duración o distancia.
- **Estados**: los comunes.
- **Una sola vez**: cuenta en carrera total, no en la principal ni en contenidos de
  calidad.
- **Ejemplo**: «Calentamiento 12′ trote» → 12 min de carrera total.
- **Ambiguo**: «calentamiento habitual» → sin cantidad, pendiente.

## 2. Técnica

### 2.1 Técnica de carrera y de salidas (drills)
- **Incluye**: skipping, talones, A/B, multisaltos técnicos de carrera, salidas
  técnicas sin intención de velocidad.
- **Excluye**: sus metros **no son metros de carrera**.
- **Unidad**: min · reps · m de ejercicio (aparte de carrera).
- **Datos**: duración o reps.
- **Estados**: ✓ del bloque o minutos declarados; si no, sin concretar.
- **Una sola vez**: nunca entran en carrera total.
- **Ejemplo**: «Técnica 15′: skipping, talones, A-B» → 15 min de técnica de carrera.
- **Ambiguo**: «4×30 skipping + 20 m progresivo» → los 20 m, ¿aceleración o técnica?
  Pendiente.

### 2.2 Técnica de vallas
- **Incluye**: intentos con vallas, vallas franqueadas, ejercicios de paso.
- **Excluye**: metros, si no se conocen separación y final medido.
- **Unidad**: intentos · vallas franqueadas · m (solo si se conocen).
- **Datos**: altura, separación, distancia a la 1.ª y final medido (E1-E2).
- **Estados**: intentos confirmados con el ✓ o con los tiempos apuntados.
- **Una sola vez**: los metros de un intento son carrera **o** técnica según la
  intención, nunca las dos.
- **Ejemplo**: E2 «2×3 vallas a 0,84 m · 3 apoyos» → 2 intentos · 6 vallas · 0,84 m.
- **Ambiguo**: E1 sin altura ni separación → intentos y vallas sí; metros y
  comparación, pendientes.

### 2.3 Técnica de saltos y lanzamientos (de prueba)
- **Incluye**: batidas, saltos con carrera de su prueba, lanzamientos técnicos.
- **Excluye**: pliometría general (4.1) y lanzamientos de balón (4.2).
- **Unidad**: intentos (la carrera de impulso aparte, si se conoce).
- **Datos**: número de intentos y tipo; carrera de impulso si importa.
- **Estados**: intentos apuntados o ✓ del bloque.
- **Una sola vez**: un intento de salto con carrera no es también un «salto» de
  pliometría.
- **Ejemplo**: «6 batidas de altura con 5 apoyos» → 6 intentos de técnica de altura.
- **Ambiguo**: «saltos de longitud con 6 apoyos» sin número → pendiente.

## 3. Fuerza

### 3.1 Fuerza en gimnasio (estructural, máxima, potencia, complementaria)
- **Incluye**: ejercicios con carga o autocarga.
- **Excluye**: saltos (4.1) dentro de un bloque combinado; arrastres (3.2).
- **Unidad**: series · reps (por lado si es unilateral) · kg previstos y usados.
- **Datos**: ejercicio y variante; %RM con el RM **de esa variante** (medido o
  estimado); kg por serie; si los kg son por mancuerna o total.
- **Estados**: kg previstos solo si hay RM de esa variante (D1); confirmado con kg y
  reps apuntados por serie; sin ellos, sin concretar.
- **Una sola vez**: en un bloque combinado cada componente va en su unidad (D2:
  9 rep. de sentadilla + 6 saltos, no 15).
- **Ejemplo**: D1 «Cargada 4×3 al 60–65 % RM» con RM 80 kg medido → 12 rep. ·
  48–52 kg previstos (cálculo).
- **Ambiguo**: D4 RDL unilateral con solo RM bilateral → reps sí; kg ausentes.

### 3.2 Fuerza horizontal (arrastres)
- **Incluye**: los metros con trineo o arrastre.
- **Excluye**: los metros libres que siguen (son aceleración).
- **Unidad**: m con arrastre · reps · carga (discos añadidos y/o masa total).
- **Datos**: distancia, reps y carga, diciendo cuál de las dos.
- **Estados**: los comunes de carrera; la carga, confirmada solo si se apunta.
- **Una sola vez**: esos metros están en carrera total con contenido principal
  «fuerza horizontal» (A1: 60 m fuerza horizontal + 60 m aceleración = 120 m).
- **Ejemplo**: A1 → 60 m con arrastre, carga ausente.
- **Ambiguo**: A2 «12 kg» → ¿discos o masa total? Pendiente.

## 4. Saltos y lanzamientos (no de prueba)

### 4.1 Pliometría y reactividad
- **Incluye**: saltos discretos (cajón, CMJ, drop jump) y contactos reactivos (pogos,
  multisaltos, comba).
- **Excluye**: saltos con carrera de una prueba (2.3); «apoyos» como ritmo técnico.
- **Unidad**: **saltos** o **contactos**, según el ejercicio; no se suman entre sí.
- **Datos**: tipo, unidad, altura del cajón o carga si la hay.
- **Estados**: ✓ del bloque o series apuntadas.
- **Una sola vez**: un contacto no es también un salto; cada ejercicio, una unidad.
- **Ejemplo**: «2×6 pogos» → 12 contactos; «3×5 saltos al cajón 60 cm» → 15 saltos.
- **Ambiguo**: «3×10 multisaltos» → ¿10 contactos o 10 saltos? Pendiente hasta fijar
  la unidad del ejercicio.

### 4.2 Lanzamientos (balón medicinal, implementos de entrenamiento)
- **Incluye**: lanzamientos que no son de la técnica de una prueba.
- **Excluye**: lanzamientos técnicos de prueba (2.3).
- **Unidad**: lanzamientos · peso del implemento.
- **Datos**: número, peso, posición.
- **Estados**: ✓ del bloque o series apuntadas.
- **Una sola vez**: no cuentan como fuerza aunque vayan en el bloque de gimnasio.
- **Ejemplo**: «3×6 lanzamientos balón 4 kg» → 18 lanzamientos de 4 kg.
- **Ambiguo**: «lanzamientos de balón» sin peso → número sí; peso ausente.

## 5. Movilidad, preventivos y recuperación
- **Incluye**: movilidad, core, preventivos (isquios, tobillo…), estiramientos,
  rodillo.
- **Excluye**: fuerza con carga (3.1).
- **Unidad**: **min** si el plan los da; si no, ejercicios × series × reps. No se
  convierte una unidad en otra.
- **Datos**: duración o series y reps.
- **Estados**: ✓ (hecho o no hecho) cuando el plan no da cantidad.
- **Una sola vez**: un preventivo con carga se cuenta en su unidad, sin pasarlo a
  minutos.
- **Ejemplo**: «Core 10′ + nórdicos 3×5» → 10 min de core · 15 rep. de nórdicos
  (preventivo).
- **Ambiguo**: «preventivos» sin detalle → hecho o no hecho (✓), sin cantidad.

## 6. Exposiciones (subconjuntos: nunca se suman encima)

| Exposición | Unidad | Es parte de | Dato necesario | Estados |
|---|---|---|---|---|
| Metros con clavos | m | carrera total | calzado C en la fila | los de su carrera |
| Metros con arrastre | m (+ carga) | carrera total | arrastre y carga | los de su carrera |
| Salidas de tacos | salidas | aceleración | tipo de salida | las reps confirmadas |
| Vallas franqueadas | vallas, por altura | técnica de vallas o carrera | altura | los intentos confirmados |

- **Ejemplo**: B1 → 100 m de carrera total, de ellos 100 m con clavos.
- **Ambiguo**: una fila sin calzado → metros sí; «con clavos» no consta (no se supone
  Z ni C).

## 7. Cobertura: cuánto dato falta

Cada semana, por atleta y por unidad, se enseñan juntas cuatro cifras:

| | Previsto | Confirmado | Sin concretar | Sin datos |
|---|---|---|---|---|
| Carrera principal (m) | 3.200 | 1.840 | 480 | 880 |

y una línea de cobertura: «Sesiones con registro: 4 de 6 · cantidades confirmadas:
58 % de lo previsto». Así, 1.840 m con 58 % de cobertura **no** se lee como una semana
floja. **Contenido pendiente** se enseña aparte: «de los 1.840 m confirmados, 420 m
con contenido pendiente».

- No hay umbral que esconda cifras: con poca cobertura se ven igual, con el aviso.
- Una semana se compara con otra solo en lo confirmado y diciendo la cobertura de
  las dos.

## 8. Decisiones que necesito cerrar contigo

| # | Pregunta | Propuesta |
|---|---|---|
| 1 | ¿Qué basta para proponer «velocidad máxima» en un lanzado? | Título u objetivo del bloque que lo diga. Sin eso, pendiente. |
| 2 | ¿«Resistencia a la velocidad» y «ritmo específico» se proponen solos? | Solo con título u objetivo del bloque; el ritmo, además, con la marca u objetivo de referencia del atleta. |
| 3 | Progresivos y rectas de calentamiento: ¿carrera o técnica? | Carrera total (no principal) salvo que el bloque sea de técnica. |
| 4 | Multisaltos: ¿saltos o contactos? | Fijar la unidad en cada ejercicio del catálogo; sin fijar, pendiente. |
| 5 | Balón medicinal: ¿fuerza o lanzamientos? | Lanzamientos, con su peso. |
| 6 | Trote de recuperación entre series | Minutos; metros solo si se dan. |
| 7 | Arrastre: ¿qué carga se apunta? | Las dos: discos añadidos y masa total (si se sabe). |
| 8 | Familias para ver la semana (carrera rápida, metabólico, fuerza, impactos, técnica, recuperación) | Solo para agrupar a la vista; no suman distinto de sus contenidos. |
| 9 | RPE × duración (carga interna declarada) | **Fuera por ahora**. Si se usa más adelante, aparte y sin mezclarse con metros ni kg. |
| 10 | Cobertura | Siempre visible, sin umbral que esconda. |

## 9. Fuera de esta entrega
- Programar cálculos, clasificar sesiones reales o rellenar contenidos de lo antiguo.
- Proyecciones, tendencias, «carga» combinada o índices.
- Importar los Excel.
