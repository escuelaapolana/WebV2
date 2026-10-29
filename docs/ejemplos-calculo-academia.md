# Ejemplos de cálculo — resultados esperados (v3, 29-oct)

> 28-oct-2026 · Textos reales de la semana 9 de Academia. Reglas en
> [modelo-datos-seguimiento.md](modelo-datos-seguimiento.md) y, desde el 29-oct, en
> [definiciones-carga-contenidos.md](definiciones-carga-contenidos.md) (v3: medio y
> objetivo aparte, posición en la sesión, confirmación por magnitud). Los casos J son
> nuevos. Todos se comprueban con el motor de la primera versión (grupo PRUEBA).
> Cuando un valor no se puede saber, el resultado esperado es **«pendiente»** o
> **«ausente»**, no un número. Los kg de los ejemplos de RM son ilustrativos.

## A. Arrastre + libre

**A1** · «Bloque 1/3 a 3/3: 20 m trineo + 20 m libre // 90″ dentro y 3′ entre bloques Z»

| Concepto | Previsto |
|---|---|
| Estructura | 3 bloques × secuencia [20 m arrastre → 20 m libre]; 90″ entre componentes, 3′ entre bloques |
| Carrera total / principal | 120 m / 120 m |
| Metros con arrastre (exposición, dentro del total) | 60 m |
| Por objetivo y medio (v3) | Objetivo del bloque si lo declara el entrenador (p. ej. «Aceleración» → 120 m de aceleración); si no, **pendiente**. Medio: **60 m con arrastre** (dentro de los 120 m), 60 m libres. «Fuerza horizontal» solo si el entrenador la pone como objetivo de esos 60 m. |
| Carga | trineo, **kg ausente** → pendiente |
| Calzado | Z (zapatillas) |

**A2** · «3x40 arrastre ligero (12kg) // 3′ Z»
- 120 m de carrera, todos con arrastre; Fuerza horizontal 120 m.
- Carga «12 kg»: **duda**, ¿son discos añadidos o la masa total del trineo? Queda
  pendiente hasta que se aclare. No se asume ninguna de las dos.

## B. Flying

**B1** · «2×30 flying (20+30) // 5′ C»

| Concepto | Previsto |
|---|---|
| Carrera total | **100 m** |
| Entrada progresiva | **40 m** (no cuenta como aceleración) |
| Lanzados | **60 m** → contenido según objetivo e intensidad: el texto no los da → **pendiente de revisión** (no se asume velocidad máxima) |
| Metros con clavos (exposición) | **100 m**, dentro de los 100 m, no se suman otra vez |

**B2** · «3x30 flying (30+30) // 6′ C» → total 180 m · entrada progresiva 90 m ·
lanzados 90 m (contenido pendiente) · clavos 180 m.

**B3** · «3×60 (20+60) lanzados en 7,20–7,40″» → **duda**: ¿los 60 m incluyen la
entrada o se suman (80 m por rep.)? **No se calcula** hasta resolverlo. Intensidad:
`tiempo_objetivo` 7,20–7,40″ (del tramo lanzado, a confirmar).

## C. Bloques de series

**C1** · «Bloque 1/2 y 2/2: 250 (34-35″) + 150 (19,5-20,5″) // 4′ y 8′ Z»

| Concepto | Previsto |
|---|---|
| Estructura | 2 bloques × [250 → 150]; 4′ entre componentes, 8′ entre bloques |
| Carrera principal | **800 m** (no 4×200 ni 1×800) |
| Intensidad | `tiempo_objetivo`: 34–35″ en el 250 y 19,5–20,5″ en el 150 |
| Contenido | Si el entrenador titula el bloque «Ritmo 400» → **propuesta**: ritmo específico. Si no, **pendiente** (hace falta la referencia del atleta en 400). |
| Vista detallada | «Ritmo 400 · 2×(250+150) · 34–35″ / 19,5–20,5″ · Z» |

**C2** · «5x1000 en 3:25-3:30 // 2′ trote suave Z» → carrera principal 5.000 m ·
`ritmo` 3:25–3:30/km · **4 recuperaciones previstas** de 2′ de trote: **8 minutos**
de carrera total como recuperación entre esfuerzos, sin metros (no se inventan) ·
objetivo propuesto: aeróbico (intervalos). En realizado solo cuentan las
recuperaciones confirmadas (J5).

**C3** · «6x150 al 85% // 3′ Z» → 900 m · intensidad `pct_esfuerzo` 85 %
(**no** «85 % de Vmáx», porque no hay referencia).

## D. Gimnasio

**D1** · «Cargada completa 4x3 al 60-65% RM // 2′»
- 4 series × 3 rep. = **12 rep.** · Fuerza (potencia).
- kg previstos: **solo si existe un RM de «cargada completa»** en `rm_atleta`. Ejemplo: RM 80 kg medido el 10-oct → 48–52 kg (fuente `calculo`). Sin ese RM: kg **ausentes**.
- Realizado: kg por serie si se apuntan (fuente `declaracion`, método `no_aplica`).

**D2** · «Media sentadilla + saltos al cajón: 3 bloques de 3 + 2 saltos; sentadilla 75-80% RM // 3′»
- **9 rep. de media sentadilla** (fuerza) + **6 saltos al cajón** (saltos, unidad
  `saltos`, altura del cajón: no consta). **No son 15 repeticiones de fuerza.**
- Descanso: 3′ entre bloques; entre componentes **no consta** → pendiente si importa.
- %RM con referencia «media sentadilla». No vale el RM de sentadilla completa.

**D3** · «Búlgaras con salto 3×5/pierna · RIR 3» → 15 rep. **por pierna** (30 en
total, mostrado como 3×5/pierna) · intensidad `rir` 3 · kg sin prescribir.

**D4** · «RDL unilateral con mancuerna 2×5/pierna al 50-60% RM unilateral» →
10 rep. por pierna. Necesita un RM **unilateral** de RDL. **Si solo hay RM
bilateral, kg ausentes** (nunca se traslada). Al apuntar kg: indicar si son por
mancuerna o en total.

## E. Vallas

**E1** · «2x primera valla // 3′ Z» + «2x dos vallas // 4′ Z» + «2x tres vallas // 5′ C»

| Concepto | Previsto |
|---|---|
| Intentos | **6** |
| Vallas franqueadas | 2 + 4 + 6 = **12** |
| Altura y separación | **ausentes** → pendiente (sin ellas no se compara con otras sesiones) |
| Metros | **no se calculan** (separación desconocida) |
| Calzado | Z en los 4 primeros intentos; C en los 2 últimos |

**E2** · «2x3 vallas a 0,84 m · 3 apoyos // 3′» → 2 intentos · 6 vallas · altura
0,84 m · «3 apoyos» = descriptor de ritmo, **no volumen**. Se compara solo con otras
sesiones a 0,84 m y la misma separación.

## F. Ejecución parcial

**F1** · Plan «2×4×120 al 82-87 %» (960 m). El atleta marca «a medias, 60 %», con el
✓ del bloque 1 y no el del bloque 2, y comenta «Paré en la 6.ª por el isquio».
- **% global 60** → se guarda como declaración global. **No** se calcula 0,6 × 960.
- Se muestra **«480 m confirmados; resto sin concretar»** (bloque 1). Nunca «480 m»
  a secas como si fuera todo lo que hizo.
- El comentario sugiere una repetición más del bloque 2 → **propuesta para confirmar**,
  no se cuenta sola.
- Molestia: dato del atleta, con su zona, enlazado al registro.

**F2** · Plan «6x150 al 85 %»; el atleta apunta **un solo tiempo** (21,5″) y nada más.
- Si ese tiempo está vinculado sin ambigüedad a una repetición de 150 m: confirma
  **1 rep. (150 m)**. Si no se sabe a qué repetición o distancia corresponde: no
  confirma ninguna.
- Las demás: **sin concretar** (no se dan por hechas).

**F3** · Plan con «6.º opcional si homogéneo + técnica buena + RPE ≤6».
- Previsto: 5 obligatorias + 1 opcional, **separadas**.
- Realizado: la 6.ª solo cuenta si el atleta la confirma.

**F4** · Sin registro del atleta → la sesión queda **«sin datos»**: ni hecha ni no
hecha.

## G. Datos antiguos

**G1** · Registro `historica_sin_garantia` (septiembre): RPE 8, «muy cansado»,
tiempos con clave de bloque `cc`.
- RPE y comentario: **sí se usan** (autor `atleta`, fuente `percepcion`).
- Tiempos: dato **de la sesión**, no de una fila; fuente `declaracion`, método `no_consta`.
- Previsto/realizado: **sin comparación exacta**. El plan guardado se muestra como
  referencia, con su aviso.

**G2** · Registro `sobrescrita` → igual que G1, con el aviso «el plan cambió después
de este registro».

**G3** · Registro `vigente_al_enviar` → comparación **probable**, marcada como tal.

## H. Cálculo frente a estimación, método y comparabilidad

**H1** · Dos repeticiones de 150 m confirmadas → **300 m** por cálculo, **no
estimado** (exacto a partir de datos confirmados). Datos de origen: las dos
repeticiones.

**H2** · «45′ CC a 4:55–5:15/km» sin distancia medida → minutos **45** (dato); km
**8,6–9,2 estimados** (cálculo estimado), marcados como estimación y con su origen. Si
solo hay «45′ CC» sin ritmo → **sin km**.

**H3** · Tiempos del 23-oct: Andrés confirmó que todos fueron **manuales** → método
`crono_manual` para ese día. Los de otros días sin confirmar → `no_consta` (no se
extiende).

**H4** · 30 m lanzado: 3,58 (12-sep, método no consta) y 3,52 (10-oct, método no
consta) → se muestran ambos con **«comparabilidad limitada: método no consta»**, nunca
como «mismas condiciones».

## I. Lanzados con notación explícita

**I1** · «3×60 lanzados, entrada 20 m + tramo 60 m» → **240 m** totales · entrada
progresiva 60 m · lanzados 180 m.

## J. Casos nuevos (29-oct)

**J1 · Fuerza sin kg** · «Media sentadilla 3×5 al 75 % RM»; el atleta marca las 3
series hechas, sin kg → **15 reps confirmadas** · carga **desconocida** · cargas: 0 de
3 series realizadas con kg.

**J2 · Solo kg** · la misma fila; el atleta apunta «80 kg» en la serie 1 sin marcarla
hecha ni poner reps → carga conocida en la serie 1 · **reps sin concretar** (apuntar
kg no confirma las reps previstas).

**J3 · Datos duplicados** · «4x20 m salidas // 3′ C»; el atleta marca las 4
repeticiones y el entrenador apunta las 4 en su toma → **4 reps (80 m) confirmadas,
una vez**, con las dos fuentes a la vista. Si el entrenador apunta la 4.ª como no
realizada → 3 confirmadas (60 m) + **1 en discrepancia (20 m)**, sin sumar ni elegir.

**J4 · Opcional no concretado** · plan «5x150 + 1 opcional»; el atleta marca la fila
hecha → **5 obligatorias confirmadas** (750 m) · opcional: **sin concretar** (fuera del
compromiso; no cuenta mientras no se confirme como hecho o no hecho).

**J5 · Recuperaciones** · «5x1000 // 2′ trote»; el atleta apunta las 5 series y 2
descansos → 5.000 m confirmados · recuperaciones: 2 de 4 confirmadas, **2 sin
concretar**.

**J6 · Sesión declarada completa** (regla §0.6) · sin datos por fila → lo obligatorio
de su versión en **«completa» (declaración global)**, aparte de lo confirmado · kg,
tiempos, opcionales y recuperaciones: sin concretar. Con una parte **desmarcada**, esa
parte queda sin concretar. En un **registro antiguo sin garantía de versión**, nada se
reparte: todo sin concretar.

**J14 · Objetivo de la sesión** · sesión «Aceleración» con calentamiento «10′ CC +
movilidad + técnica», «Core y preventivos de isquio» y «Media sentadilla 3×5» → el
calentamiento sigue siendo calentamiento, el core preventivo y la fuerza sin objetivo;
las partes de carrera de la parte principal reciben «aceleración» como **propuesta**
(de la sesión), no como declarada. Si el bloque se titula «Aceleración», entonces sí
es declarado para sus partes de carrera.

**J7 · A medias** · «a medias, 70 %» sin filas → todo **sin concretar**, con la
declaración global «70 %»; no se calcula 0,7 × previsto.

**J8 · Adicional** · fila «libre» «Correr suave · 3 km en 18:14» → **3 km adicionales
declarados** (no previstos) · objetivo pendiente · no es GPS.

**J9 · Sin registro** → previsto = **plan vigente, sin respuesta** · realizado: sin
datos (ni hecho ni no hecho).

**J10 · No realizada** · «no la he hecho: viaje» → lo obligatorio **no realizado**
(motivo «viaje»); resultado conocido = sí.

**J11 · Ritmo 400 declarado** · sesión con objetivo «Ritmo 400», sin objetivo de 400
en la ficha → objetivo declarado: ritmo específico 400 · referencia: pendiente ·
adecuación: no evaluada.

**J12 · «15′ CC + técnica»** (calentamiento) → 15 min de carrera, posición
calentamiento · técnica **sin cantidad** (hecho o no hecho), no metros.

**J13 · Pogos** · «2×10 pogos» → **20 contactos** (bilateral: un contacto por toma
de tierra, no dos).
