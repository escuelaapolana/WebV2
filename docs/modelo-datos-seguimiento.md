# Modelo de datos del seguimiento de Academia — PROPUESTA (sin implementar)

> 28-oct-2026 · Para revisar con Andrés antes de construir nada.
> Requisitos: [requisitos-panel-seguimiento.md](requisitos-panel-seguimiento.md) ·
> Base ya hecha (historial): [historial-entrenos.md](historial-entrenos.md).
> Ámbito: **Academia AC98**, en su propio mundo del panel.

## 0. Reglas que manda todo lo demás

1. **La unidad es la fila del plan** (`sesiones.bloques[].filas[]`, con su `id`). El
   atleta sigue viendo el texto tal cual («3×30 flying (20+30) // 5′ C»); la
   estructura va aparte y no cambia lo que ve.
2. **Cada número lleva su calidad**: `medido` (instrumento: fotocélula, GPS),
   `declarado` (lo escribe el atleta o el entrenador), `estimado` (lo calcula la
   app) o `ausente`. Nunca se presenta una estimación como dato.
3. **Cada magnitud va por separado**: metros, minutos, contactos, intentos, series,
   repeticiones y kg. **No hay un «volumen» único.**
4. **Un metro se cuenta una sola vez**: pertenece a un único tramo con un único
   contenido principal. Las etiquetas secundarias describen, no suman.
5. **Lo ambiguo queda pendiente** de revisión; no se inventan valores.
6. **Lo previsto sale de la versión que respondió el atleta** (`sesion_version_id`).
   Sin registro, lo realizado es `ausente`, no «hecho».

## 1. Qué existe, qué se amplía y qué es nuevo

| Pieza | Situación | Dónde |
|---|---|---|
| Plan por versión (lo que vio el atleta) | **Existe** (fase 1) | `sesiones_versiones`, `registros_sesion.sesion_version_id` |
| Texto de cada fila + id estable | **Existe** | `bloques[].filas[].id / ejercicio / detalle` |
| Campos de fila sueltos: `series`, `distancia`, `ritmo`, `descanso`, `calzado`, `carga`, `desnivel_m` | **Existe, poco usado** (en 3.206 filas de Academia: series 236, distancia 177, calzado 23, ritmo 22, descanso 13, carga 4) | se leen como «prescripción declarada» si están |
| Lo realizado por fila: series hechas, tiempos, RIR, material, ejercicio cambiado (`cambiado_por`) | **Existe** | `registros_sesion.tiempos_reales[fila_id]` |
| Estado de la sesión, % completado, RPE, duración, superficie, molestia y zona, motivo de no hacerla, mañana/tarde | **Existe** | `registros_sesion` |
| Bienestar diario | **Existe** | `bienestar_diario` |
| Disponibilidad y restricciones vigentes (lesión/molestia) | **Existe, sin uso** | `lesiones_atleta` (zona, restricción, disponibilidad, fechas) |
| Marcas, tests, RM | **Existe** | `marcas_atleta` (`contexto`), `test_resultados` (`intentos`, `mejor`), `rm_atleta` |
| Perfil deportivo | **Existe en la ficha** | `atletas`: pruebas principal/secundarias, especialidades, perfil velocista, pierna de ataque, pasos entre vallas, hace gym, contexto entrenador/atleta, aviso de salud |
| Estructura de cada fila (componentes, tramos, intensidad, descansos, carga…) | **Nueva tabla** | `plan_filas_estructura` (§2) |
| Catálogo de contenidos (objetivo principal / etiquetas / familia semanal) | **Nueva tabla** | `entreno_contenidos` (§3) |
| Objetivos de temporada y a 3 años | **Nueva tabla** | `atleta_objetivos` (§6) |
| Observaciones y decisiones con vigencia y motivo | **Ampliar** | `notas_atleta` (§6) |
| Condiciones de cada medición (cronometraje, viento, superficie, implemento…) | **Ampliar** | `test_resultados.condiciones`, `marcas_atleta.condiciones` (§5) |
| Sesión que sustituye a otra; motivo de un cambio del plan | **Ampliar** | `sesiones.sustituye_a`, `sesiones.motivo_cambio` (§4) |
| Cronometraje de cada tiempo apuntado | **Ampliar** (dentro del JSON) | `tiempos_reales[fila].series[].crono` (§5) |

## 2. Estructura de cada fila: `plan_filas_estructura` (nueva)

Una interpretación **por fila y por texto**: si el texto de la fila no cambia entre
versiones, vale la misma; si cambia, hay otra. Así la estructura queda atada a lo
que el atleta vio, sin crear versiones nuevas de la sesión al clasificar.

| Campo | Para qué |
|---|---|
| `fila_id`, `texto_hash` (único juntos), `sesion_id` | a qué fila y a qué texto exacto se refiere |
| `componentes` (jsonb) | la prescripción desmontada (abajo) |
| `contenido_principal`, `etiquetas[]` | clasificación (§3) |
| `estado` | `auto` · `pendiente_revision` · `revisado` · `manual` |
| `dudas[]` | qué no se pudo leer («¿200 m a qué % de su marca?») |
| `origen`, `revisado_por`, `revisado_en` | lectura automática (versión del lector) o entrenador |

`componentes`: una fila puede tener **varios componentes** (p. ej. sentadilla + saltos
al cajón), y cada componente varios **tramos** (entrada + lanzado; arrastre + libre).

```
componente = {
  tipo: carrera | fuerza | salto | tecnica | movilidad,
  bloques, series, reps,                 // 2×4×200 → bloques 2, series 4
  tramos: [ { rol: entrada|trabajo|arrastre|libre, m, contenido } ],
  duracion: { s | min },                 // cuestas 8″, CC 35′
  intensidad: { forma: %vmax|ritmo|tiempo|%RM|RPE|RIR|zona, valor/rango, referencia },
  descanso: { entre_reps, entre_bloques, tipo: pasivo|andando|trote },
  calzado: Z|C, superficie, carga: { tipo: trineo|barra|mancuerna|chaleco, kg | %PC | %RM },
  vallas: { altura_m, n_vallas, separacion_m, pasos, intentos },
  saltos: { tipo: pogo|cmj|drop|cajón|multisalto, contactos },
  opcional: true|false                   // «6.º opcional si…»
}
```

## 3. Clasificación: `entreno_contenidos` (nueva, editable)

Catálogo inicial (el de la propuesta), cada uno con su **familia** para la
distribución semanal y sus **magnitudes** permitidas:

| Contenido | Familia semanal | Magnitudes |
|---|---|---|
| Aceleración y salidas de tacos | carrera rápida | m, reps, salidas |
| Fuerza horizontal y arrastres | carrera rápida · fuerza | m, reps, kg / %PC |
| Velocidad máxima | carrera rápida | m (tramo lanzado), reps |
| Resistencia a la velocidad | carrera rápida · metabólico | m, reps |
| Ritmo específico de competición | metabólico | m, reps, tiempos |
| Capacidad / potencia glucolítica (**intención prevista**) | metabólico | m, reps, min |
| Aeróbico: rodaje, intervalos, fartlek | metabólico | min, m (estimados si solo hay ritmo) |
| Fuerza estructural / máxima / potencia / complementaria | fuerza | ejercicios, series, reps, kg, %RM |
| Pliometría y reactividad | impactos y saltos | contactos, tipo, carga |
| Técnica de carrera y de salidas | técnica | min, reps, intentos |
| Técnica de vallas / altura / lanzamientos | técnica · impactos | intentos, vallas, batidas, lanzamientos |
| Movilidad, preventivos y recuperación | recuperación | min |

- **Principal** = el único que recibe los metros/minutos/contactos de ese tramo.
- **Etiquetas** = descripción («tacos», «con clavos», «test»), sin sumar.
- La propone la lectura automática **solo cuando la regla es clara**; si depende de
  la intensidad relativa (p. ej. un 200 m sin %), queda `pendiente_revision`.
- **«Glucolítico» es siempre intención**: no se afirma lactato medido.

## 4. Previsto frente a realizado

- **Previsto** = componentes de las filas de la **versión respondida**.
- **Realizado**, por orden de preferencia y con su calidad:
  1. Lo apuntado por fila (`tiempos_reales`: series hechas, tiempos, kg, RIR) →
     `declarado` (o `medido` si el tiempo es de células).
  2. Si solo hay estado/% de la sesión → `estimado` (= previsto × %). **Nunca las dos
     cosas a la vez** para la misma fila.
  3. Sin registro → `ausente` (no «hecho»).
- **Sustituciones**: `sesiones.sustituye_a` (nueva) marca la sesión que reemplaza a
  otra; la original cuenta como «sustituida» y la nueva no es «adicional». Dentro de
  una fila, `cambiado_por` (ya existe) marca el ejercicio cambiado.
- **Motivo del cambio**: del atleta, `motivo_no_hecho` / `nota_no_hecho` (existen); del
  entrenador, `sesiones.motivo_cambio` (nuevo; queda en cada versión).
- **Opcionales**: solo cuentan si hay realizado declarado.
- Registros **sin plan exacto** (`version_garantia` ≠ exacta): sus datos realizados
  (RPE, tiempos, molestias) valen; quedan **fuera** del cumplimiento del plan.

## 5. Mediciones y condiciones

- `tiempos_reales[fila].series[].crono` (nuevo, dentro del JSON): `manual` por
  defecto (lo escribe el atleta) o `celulas`.
- `test_resultados.condiciones` y `marcas_atleta.condiciones` (nuevo jsonb):
  cronometraje, viento, superficie, calzado, altura de valla / implemento / variante.
- **Comparables solo con las mismas condiciones**: no se mezclan manual y células,
  ni alturas de valla, ni implementos o variantes de ejercicio.
- Marcas oficiales (`contexto = competicion`), tests y referencias estimadas (p. ej.
  un %RM calculado) se guardan y se muestran **por separado**.

## 6. Perfil, objetivos y decisiones

- **Perfil deportivo**: se queda en `atletas` (ya tiene pruebas, especialidades,
  perfil, pierna de ataque, pasos…). Solo se ordena cómo se muestra.
- **Disponibilidad actual y restricciones**: `lesiones_atleta` (ya existe), lo
  temporal separado del perfil.
- **Objetivos**: `atleta_objetivos` (nueva): horizonte (temporada / 3 años), prueba,
  marca objetivo, competición y fecha, estado, notas, autor.
- **Observaciones y decisiones**: ampliar `notas_atleta` (ya existe, solo la ve el
  cuerpo técnico) con `clase` (observación / decisión), `ambito` (carga, técnica,
  salud, competición), `motivo`, `vigente_desde`, `vigente_hasta` y `evidencias[]`
  (ids de registros/versiones que la sustentan). Una decisión la escribe el
  entrenador; la app nunca la crea sola.

## 7. Ejemplos reales de Academia (cómo quedarían)

**a) Arrastre + libre** — «Bloque 1/2: 30 m trineo + 30 m libre // 2′ dentro y 4′ entre bloques Z»
- carrera, tramos: 30 m `arrastre` → *Fuerza horizontal*; 30 m `libre` → *Aceleración*.
- descanso 2′ dentro, 4′ entre bloques; calzado Z; carga: trineo, **kg ausente** → duda.
- Totales: carrera 60 m (una vez); metros con arrastre 30 m (exposición aparte).
- «4x20 m arrastres + 4x30 m @95% + 3x60 m @90-95% + 2x150 m en 25-26''» = **una fila,
  cuatro componentes**, cada uno con su contenido; no se suman entre magnitudes.

**b) Flying** — «2x30 flying (20+30) // 5' C»
- carrera, 2 reps; tramos: 20 m `entrada` → *Aceleración* (o etiqueta «entrada», a
  decidir); 30 m `trabajo` → *Velocidad máxima*. Calzado C (clavos).
- Totales: carrera 100 m; velocidad máxima 60 m; entrada 40 m (por separado).
- «3×60 (20+60) lanzados en 7,20–7,40"» → ¿60 m incluye la entrada o se suma? **duda →
  revisión** (no se inventa).

**c) Bloques de series** — «2x4x200 m en 56-60'' · Z» / «2x3x150 m al 85-88% // 2'30"-3' entre 150 y 5' entre bloques»
- bloques 2 × series 4 × 200 m = 1.600 m (se respeta 2×4, nunca 8×200).
- Intensidad: tiempo objetivo 56-60″ (o 85-88 %). El contenido (resistencia a la
  velocidad / glucolítico / ritmo) depende de la referencia del atleta → si no hay
  regla clara, `pendiente_revision`.
- Realizado: los tiempos apuntados por serie; si faltan series, `declarado` parcial.

**d) Gimnasio** — «Cargada completa 4x3 al 60-65% RM // 2′» · «Media sentadilla + saltos al cajón 3x3+2 al 75-80% RM // 3′»
- fuerza: cargada completa, 4×3, %RM 60-65 → kg **estimados** solo si hay RM válido de
  *ese* ejercicio en `rm_atleta`; si no, `ausente`.
- Segunda fila = dos componentes: fuerza (media sentadilla 3×3 @75-80 %RM) +
  pliometría (saltos al cajón 3×2 = 6 contactos).
- Realizado: kg y RIR si el atleta los apunta (`declarado`).

**e) Vallas** — «2x3 vallas a 0,84 m · 3 apoyos // 3'» · «4-5 aproximaciones a 1ª valla // 3'»
- técnica de vallas: 2 intentos × 3 vallas = 6 vallas franqueadas; altura 0,84 m;
  3 apoyos; separación **ausente** (no se estiman metros).
- «4-5 aproximaciones» → intentos 4-5 (rango previsto); realizado si se apunta.
- Se agrupa siempre por altura y separación: 0,84 m y 0,991 m no se comparan.

## 8. Registros antiguos (sin inventar)

- La estructura se puede calcular sobre la versión «inicial», pero se marca
  `plan no garantizado` y no entra en previsto frente a realizado.
- Tiempos con claves de bloque (`cc`, `mov`, `tec`…) → no se asignan a filas: lo
  realizado por fila queda `ausente`; se usan el RPE y lo demás de la sesión.
- Correcciones anteriores al 28-oct: solo el contador.

## 9. Lo que se implementaría en el paso 3 (cuando lo aprobemos)

1. Tablas `entreno_contenidos`, `plan_filas_estructura`, `atleta_objetivos`.
2. Ampliar `notas_atleta`, `sesiones` (`sustituye_a`, `motivo_cambio`),
   `test_resultados` / `marcas_atleta` (`condiciones`) y `tiempos_reales` (`crono`).
3. Un lector de filas que proponga componentes y marque dudas, más una pantalla para
   que el entrenador revise y corrija la clasificación.
4. Permisos como el resto: entrenador de su grupo, atleta lo suyo.

## Preguntas para decidir

1. En un flying, ¿la **entrada** cuenta como *Aceleración* o solo como «metros de
   entrada» sin contenido?
2. ¿Qué referencia usamos para decidir el contenido de las series (marca del atleta
   en esa distancia, ritmo objetivo, %)? ¿Lo clasificas tú siempre en las series?
3. ¿Los metros de calentamiento y técnica entran en «carrera» o van aparte?
4. ¿Hay fotocélulas o GPS en algún entreno para tener datos «medidos»?
5. ¿Quieres apuntar los kg del trineo y de las pesas en cada sesión, o basta con el
   %RM previsto?
