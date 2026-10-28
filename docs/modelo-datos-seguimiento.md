# Modelo de datos del seguimiento de Academia — PROPUESTA v2 (sin implementar)

> 28-oct-2026 · v2 con las decisiones de Andrés (revisadas con ChatGPT).
> Requisitos: [requisitos-panel-seguimiento.md](requisitos-panel-seguimiento.md) ·
> Histórico (fase 1, ya hecho): [historial-entrenos.md](historial-entrenos.md) ·
> Ejemplos de cálculo: [ejemplos-calculo-academia.md](ejemplos-calculo-academia.md).
> Ámbito: **Academia AC98**, en su propio mundo del panel.
> **No se construyen cálculos automáticos sobre definiciones ambiguas.**

## 0. Reglas que mandan todo lo demás

1. **La unidad es la fila del plan** (`sesiones.bloques[].filas[]`, con su `id`). El
   atleta sigue viendo el texto tal cual («3×30 flying (20+30) // 5′ C»); la
   estructura va aparte y no cambia lo que ve.
2. **Cada dato lleva cinco atributos separados** (nunca se mezclan en una «calidad»):

   | Atributo | Pregunta | Valores |
   |---|---|---|
   | **Autor** | ¿Quién lo registró? | `atleta` · `entrenador` · `importacion` · `asistente` (p. ej. ChatGPT) · `sistema` |
   | **Fuente** | ¿De dónde sale el valor? | `medicion` (con instrumento y método conocido) · `declaracion` (lo que alguien dice que hizo o usó: reps, kg, un tiempo sin método conocido) · `percepcion` (RPE, sensaciones, molestia) · `observacion` (lo que ve el entrenador) · `calculo` (lo calcula la app: estimación) |
   | **Método** | ¿Cómo se obtuvo? | `crono_manual` · `fotocelulas` · `gps` · `reloj` · `bascula` · `video` · `no_consta` · `no_aplica` |
   | **Correspondencia con el plan** | ¿Con qué plan casa? | `exacta` · `vigente_al_enviar` · `historica_sin_garantia` · `sobrescrita` · `sin_plan` |
   | **Completitud** | ¿Está entero? | `completo` · `incompleto` · `ausente` |

   Un atleta puede apuntar un tiempo de fotocélulas (autor `atleta`, método
   `fotocelulas`) y un entrenador uno manual (autor `entrenador`, método
   `crono_manual`). **Lo que escribe el atleta no es «manual» por defecto**: si no se
   sabe, `no_consta`.
3. **Cada magnitud va por separado**: metros, minutos, contactos, saltos, intentos,
   series, repeticiones y kg. **No hay un «volumen» único.**
4. **Un metro se cuenta una sola vez** en el total. Las exposiciones (clavos, arrastre)
   son **subconjuntos** de ese total, no se suman encima.
5. **Lo ambiguo queda pendiente** de revisión; nunca se inventan valores.
6. **Lo previsto sale de la versión que respondió el atleta**. Sin registro, lo
   realizado es `ausente`, no «hecho».

## 1. Qué existe, qué se amplía y qué es nuevo

| Pieza | Situación | Dónde |
|---|---|---|
| Plan por versión y versión respondida | **Existe** (fase 1) | `sesiones_versiones`, `sesiones.version`, `registros_sesion.sesion_version_id` / `version_vista` |
| Texto de cada fila + id estable | **Existe** | `bloques[].filas[].id / ejercicio / detalle` |
| Campos de fila: `series`, `distancia`, `ritmo`, `descanso`, `calzado`, `carga`, `desnivel_m` | **Existe, poco usado** | se leen como prescripción si están |
| ✓ por bloque (modo simple de Academia) | **Existe** | `solo_marcar` + lo marcado en `tiempos_reales` |
| Lo realizado por fila: series, tiempos, RIR, material, ejercicio cambiado | **Existe** | `tiempos_reales[fila_id]` (`series`, `rir`, `material`, `cambiado_por`) |
| Estado, % completado, RPE, duración, superficie, molestia, motivo | **Existe** | `registros_sesion` |
| Bienestar | **Existe** | `bienestar_diario` |
| Lesiones y restricciones | **Existe, sin uso** | `lesiones_atleta` |
| Ausencias | **Existe, sin uso** | `ausencias` (atleta, fecha, motivo, sesión) |
| Marcas, tests, RM | **Existe** | `marcas_atleta`, `test_resultados`, `rm_atleta` |
| Perfil deportivo | **Existe en la ficha** | `atletas` (pruebas, especialidades, perfil, pierna de ataque, pasos…) |
| Tipo de día y momento | **Ampliar** | `sesiones.clase_dia`, `sesiones.momento` (§9) |
| Disponibilidad no médica (viaje, estudios, trabajo) | **Ampliar** | `ausencias` (+ motivo tipificado) — **no** en lesiones (§9) |
| Estructura de cada fila (secuencia, componentes, tramos, cargas…) | **Nueva** | `plan_filas_estructura` + `plan_filas_estructura_cambios` (§2) |
| Catálogo de contenidos | **Nueva** | `entreno_contenidos` (§3) |
| Ejecución de cargas por serie | **Ampliar** (dentro del JSON) | `tiempos_reales[fila].series[].kg / lado / metodo` (§7) |
| Referencias de RM con variante | **Ampliar** | `rm_atleta` (+ variante, recorrido, unilateral, medido/estimado) (§7) |
| Objetivos por temporada | **Nueva** | `atleta_objetivos` + historial (§10) |
| Observaciones y decisiones con vigencia | **Ampliar** | `notas_atleta` (§10) |
| Condiciones de tests y marcas | **Ampliar** | `condiciones` en `test_resultados` y `marcas_atleta` (§8) |
| Sustituciones y motivo de cambio | **Ampliar** | `sesiones.sustituye_a`, `sesiones.motivo_cambio` (§5) |

## 2. Estructura de cada fila (nueva)

**Atada a la versión.** Cada interpretación pertenece a una fila **de una versión**
(`sesion_version_id` + `fila_id`). Para no repetir trabajo, se reutiliza la
interpretación de la versión anterior **solo si no ha cambiado ningún campo
relevante de la fila**. La comparación se hace con una huella sobre texto, detalle,
series, distancia, ritmo, descanso, calzado, carga y opcional, no solo sobre el
texto visible.

`plan_filas_estructura`:

| Campo | Para qué |
|---|---|
| `sesion_version_id`, `fila_id` | a qué fila de qué versión pertenece |
| `huella` | firma de todos los campos relevantes de la fila |
| `estructura` (jsonb) | la secuencia y sus componentes (abajo) |
| `estado` | `propuesta_auto` · `pendiente_revision` · `revisada` · `manual` |
| `dudas[]` | qué no se pudo leer («¿60 m incluye la entrada?») |
| `lector_version`, `revisado_por`, `revisado_en` | quién la propuso y quién la revisó |

`plan_filas_estructura_cambios` guarda **cada reclasificación**: antes, después,
autor, fecha y **motivo**. Así, si una reclasificación cambia un informe anterior, se
puede saber por qué.

### Secuencia y componentes

Un bloque es una **secuencia de componentes** que se repite N veces:

```
fila = { bloques: N, opcional: false,
         secuencia: [ componente, componente, … ],
         descanso: { entre_componentes, entre_bloques } }

componente = {
  tipo: carrera | fuerza | salto | tecnica | movilidad,
  reps (por bloque), lado: ambos | por_lado,
  tramos (carrera): [ { rol: entrada_progresiva | lanzado | arrastre | libre | trabajo, m } ],
  duracion: { s | min },
  intensidad: { forma, valor | rango, referencia },     // §4
  calzado: Z | C, superficie,
  carga: { prevista: … }                               // §7
  vallas: { altura_m, n_vallas, separacion_m, pasos },
  salto: { tipo, unidad: saltos | contactos },          // §6
  contenido_principal, etiquetas[]                      // §3
}
```

## 3. Clasificación de contenidos (`entreno_contenidos`, editable)

| Contenido | Familia semanal | Unidades |
|---|---|---|
| Aceleración y salidas de tacos | carrera rápida | m, reps, salidas |
| Fuerza horizontal y arrastres | carrera rápida · fuerza | m (con arrastre), reps, carga |
| Velocidad máxima | carrera rápida | m lanzados, reps |
| Resistencia a la velocidad | carrera rápida · metabólico | m, reps |
| Ritmo específico de competición | metabólico | m, reps, tiempos |
| Capacidad / potencia glucolítica (**intención prevista**) | metabólico | m, reps |
| Aeróbico: rodaje, intervalos, fartlek | metabólico | min; m solo si se miden o con ritmo (estimados) |
| Fuerza estructural / máxima / potencia / complementaria | fuerza | ejercicios, series, reps, kg, %RM |
| Pliometría y reactividad | impactos y saltos | saltos o contactos, tipo, carga |
| Técnica de carrera y de salidas | técnica | min, reps, intentos (sus metros no son carrera) |
| Técnica de vallas / altura / lanzamientos | técnica · impactos | intentos, vallas, batidas, saltos, lanzamientos |
| Movilidad, preventivos y recuperación | recuperación | min |

- **Principal** = el único que recibe las unidades de ese componente o tramo.
  **Etiquetas** = descripción («tacos», «test», «clavos»), sin sumar.
- **Series**: el contenido se decide con el **objetivo del bloque, la distancia, la
  intensidad, la recuperación y las referencias del atleta**. La app **propone** solo
  cuando tiene información suficiente; el entrenador revisa y corrige.
- **Flying**: el tramo **lanzado** se clasifica por objetivo e intensidad: **no todo
  lanzado es velocidad máxima**. La entrada es «entrada progresiva» (§5).
- «Glucolítico» es siempre **intención**: no se afirma lactato medido.

## 4. Intensidad: formas que no se confunden

| Forma | Ejemplo | Necesita referencia |
|---|---|---|
| `pct_vmax_medida` | 95 % de su velocidad máxima medida | sí: una Vmáx medida (fecha, método) |
| `pct_vmedia_marca` | 90 % de la velocidad media de su marca de 200 m | sí: la marca concreta |
| `pct_esfuerzo` | «al 90 %» orientativo | no |
| `ritmo` / `tiempo_objetivo` | 34–35″; 3:25–3:30/km | no |
| `rpe` / `rir` | RPE 7; RIR 3 | no |
| `pct_rm` | 60–65 % RM | sí: el RM de **esa variante** (§7) |

**Nuestros «al 90 %» se guardan como `pct_esfuerzo`.** Solo pasan a `%Vmáx` o a
`%marca` si se indica la referencia. Si falta, quedan como esfuerzo orientativo o
pendientes.

## 5. Carrera: total, principal, técnica y exposiciones

- **Carrera total** = toda la carrera prevista o realizada: calentamiento y vuelta a
  la calma corriendo incluidos.
- **Carrera principal** = la de la parte principal.
- **Técnica** aparte, con sus minutos, metros o repeticiones. **Los metros de
  skipping o de técnica no son metros de carrera.**
- **Flying**: la distancia total incluye la entrada. La entrada se registra como
  **entrada progresiva**, separada de los metros específicos de aceleración.
- **Exposiciones** (subconjuntos del total, no se suman encima): metros con clavos,
  metros con arrastre (y su carga), salidas de tacos.
- **Distancia por duración y ritmo** = `calculo` (estimada). **Si solo hay minutos, no
  se inventan kilómetros.**
- **Sustituciones**: `sesiones.sustituye_a` marca la sesión que reemplaza a otra; la
  original queda como «sustituida» y la nueva **no** es adicional. Dentro de una fila,
  `cambiado_por` (ya existe) marca el ejercicio cambiado. Motivo: del atleta,
  `motivo_no_hecho` / `nota_no_hecho`; del entrenador, `sesiones.motivo_cambio`.

## 6. Saltos, contactos y apoyos (no son equivalentes)

- **Saltos**: acciones discretas que se cuentan una a una (saltos al cajón, CMJ, drop
  jump, saltos completos de altura).
- **Contactos**: apoyos reactivos con el suelo en pliometría continua (pogos,
  multisaltos, comba). 2×6 pogos = 12 contactos.
- **Apoyos**: descriptor de ritmo técnico («3 apoyos entre vallas», «aproximación de
  5-7 apoyos»). **No es volumen.**
- Cada ejercicio de salto declara su unidad (`saltos` o `contactos`), y **no se suman
  entre sí**.
- **Bloques combinados**: «3 bloques de 3 sentadillas + 2 saltos» son **9 repeticiones
  de sentadilla y 6 saltos**, con su descanso entre componentes y entre bloques. **No
  son 15 repeticiones de fuerza.**

## 7. Cargas: prescripción y ejecución

- **Prescripción**: kg previstos y/o %RM, con la **referencia concreta**: qué RM
  (`rm_atleta`): variante, recorrido, fecha, y si es medido o estimado.
- **Ejecución**: kg realmente usados, **por serie** cuando cambien.
- **Unilaterales**: kg **por mancuerna** o **total**, dicho explícitamente;
  repeticiones **por lado**. **Nunca se traslada un RM bilateral a una variante
  unilateral.**
- **Trineo**: discos añadidos y, si se conoce, la masa total.
- Ampliación de `rm_atleta`: `variante`, `recorrido`, `unilateral`, `tipo`
  (`medido` · `estimado`), `metodo`.

## 8. Mediciones y condiciones

- **Método por sesión** (por defecto para sus tiempos) y **corrección por
  repetición**. Situación real: hasta ahora los tiempos de pista son manuales, las
  fotocélulas están pendientes de compra y no consta GPS. **En lo histórico, el
  método es `no_consta`.**
- `condiciones` en tests y marcas: cronometraje, viento, superficie, calzado,
  altura y separación de vallas, implemento y peso, variante de fuerza.
- **Comparables solo con las mismas condiciones.** Marcas oficiales, tests y
  referencias estimadas se muestran por separado, con su fecha.

## 9. Días: entreno, descanso, ausencia y sin planificar

- **Cuatro estados distintos**:
  - `clase_dia` en la sesión: `entreno` o `descanso`;
  - la **ausencia** va en `ausencias`;
  - **sin planificar** = no hay sesión.
- **Una ausencia no borra el entrenamiento previsto ni equivale a lesión.** El
  entreno queda como previsto y no realizado, con su motivo.
- **Disponibilidad no médica** (viajes, estudios, trabajo) va en `ausencias`, con el
  motivo tipificado: `viaje` · `estudios` · `trabajo` · `enfermedad` · `lesion` ·
  `otro`. Las **lesiones y restricciones** van en `lesiones_atleta`.
- **Momento** (`sesiones.momento`): `unica` · `manana` · `tarde` · `sin_especificar`.
  En lo histórico ambiguo, `sin_especificar`: **no se inventa mañana o tarde.**

## 10. Perfil, objetivos y decisiones

- **Perfil estable**: en `atletas`.
- **Situación temporal**: lesiones y restricciones (`lesiones_atleta`) y ausencias.
  Una restricción que llega a su fecha de revisión pasa a **pendiente de revisar**;
  **no** se da al atleta por recuperado automáticamente.
- **Objetivos** (`atleta_objetivos`, nueva):
  - por **temporada**, para cada una de las tres próximas;
  - por **prueba principal y secundarias**, con marca objetivo, competición o fecha
    y estado;
  - **con historial de cambios**: quién, cuándo y por qué.
- **Observaciones y decisiones**: ampliar `notas_atleta` con:
  - `clase` (`observacion` · `decision`);
  - `ambito`;
  - `motivo`;
  - `vigente_desde`, `vigente_hasta` y `revisar_el`;
  - `evidencias[]`, enlaces a los registros que la sustentan.

  Las decisiones las escribe el entrenador.

## 11. Previsto frente a realizado

- **Previsto** = estructura de la versión respondida, **separando lo obligatorio de
  lo opcional**.
- **Realizado**:
  - **Por fila o bloque**, cuando se puede identificar: ✓ del bloque en el modo
    simple, series apuntadas, tiempos, kg, RIR. Eso es lo que entra en el volumen
    por contenido.
  - **El % completado global** («70 %») se guarda como **declaración global**. **No se
    reparte** entre ejercicios ni capacidades multiplicando el plan: no sabemos qué
    bloques omitió.
  - **Un tiempo aislado no confirma todas las repeticiones.** Solo confirma esa
    repetición.
  - **Opcional**: solo cuenta si se confirma.
  - **Sin registro** → `ausente`.
- **Comparación por correspondencia**:
  - `exacta` → comparación exacta;
  - `vigente_al_enviar` → comparación probable, identificada;
  - `historica_sin_garantia` / `sobrescrita` → sin comparación exacta.

  Lo realizado de todos ellos (tiempos, RPE, duración, comentarios) **se sigue
  analizando** con sus límites. No se excluye el registro entero.

## 12. Implementación (cuando se apruebe)

1. Tipo de día, momento, ausencias tipificadas y relleno prudente de lo antiguo
   (lo dudoso queda pendiente o `sin_especificar`).
2. `entreno_contenidos`, `plan_filas_estructura` (+ cambios), ampliación de
   `rm_atleta`, objetivos y decisiones.
3. Lector de filas que **propone** y marca dudas, más una pantalla de revisión para el
   entrenador.
4. Los cálculos de volumen y tendencias, **solo** sobre lo validado en los
   ejemplos ([ejemplos-calculo-academia.md](ejemplos-calculo-academia.md)).
