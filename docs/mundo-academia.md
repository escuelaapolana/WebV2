# Mundo «Academia AC98» — v1 funcional (Semana y Hoy)

> 28-oct-2026 · v2 con las decisiones de Andrés (revisadas con ChatGPT). **Semana y
> Hoy construidos** (ver §Estado); ficha, objetivos, cargas y cálculos, pendientes.
> Requisitos: [requisitos-panel-seguimiento.md](requisitos-panel-seguimiento.md) ·
> Modelo: [modelo-datos-seguimiento.md](modelo-datos-seguimiento.md) ·
> Ejemplos: [ejemplos-calculo-academia.md](ejemplos-calculo-academia.md) ·
> Conexión: [integracion-chatgpt.md](integracion-chatgpt.md).
> Maqueta local (datos ficticios, plan real de la semana 9): `portal/_maqueta-academia/`.

## Estado (28-oct-2026)

**Construido:** `portal/academia/` (mundo «Academia AC98» en `assets/js/mundos.js`),
sobre la base mínima (mig 462) y el grupo de prueba con datos ficticios (mig 463).

- **Semana**: tabla atletas × días con nombres y cabecera fijos, columna de hoy,
  ‹ Anterior · Esta semana · Siguiente ›, filtros por atleta y por grupo de trabajo,
  Compacta/Detallada, mañana y tarde, tipos de día, sustituciones, archivadas con
  registro, resumen por día (atletas / sesiones / descansos / ausencias / sin
  planificar / borradores) y «Publicar borradores (N)…» con confirmación. La tabla
  se ajusta al alto de la pantalla: el resumen siempre se ve y no tapa la última fila.
- **Tres estados con texto**: Borrador · Realizada / Parcial · % / No realizada /
  «Sin datos · feedback pendiente» (solo vencido el plazo, nunca antes de que acabe
  la sesión) · Feedback nuevo · Revisar: molestia · Revisión pendiente · «Plan cambiado
  después · v1 → v2».
- **Hoy**: cifras (atletas entrenan · sesiones · ausencias · descansos · borradores ·
  que revisar · sin feedback), ‹ día ›, Por atleta (hoy + ayer) o Por grupos de
  trabajo; «Pendiente de revisar» con origen: revisiones y avisos uno a uno, el
  feedback sin avisos, lo que no tiene respuesta y «falta tu registro» plegados con
  su número. **No hay «marcar todo como revisado»** (28-oct, Andrés): revisado
  significa leído.
- **Grupos de trabajo**: los crea el entrenador (por sesión o por bloque); la app
  solo sugiere (misma intención y título) y nunca agrupa sola. Un grupo por bloque
  solo cubre ese bloque; el resto sigue siendo individual.
- **Detalle**: lateral (PC) o pantalla completa (móvil), anterior/siguiente del día;
  versión y publicación; intención (objetivo y exigencia: en borrador se guarda
  directa con candado de versión; publicada → revisión pendiente); revisión
  pendiente con antes/ahora emparejados, aplicar (versión N+1) o descartar; lo que
  hizo y **el plan que respondió completo**, cambios respecto a él (solo
  diferencias) y plan actual plegado; marcar/quitar revisado; observaciones del día
  (privadas, `notas_atleta`); enlaces a Planificar y a la ficha.
- **Imprimir**: el día por grupos de trabajo (lo común una vez, lo distinto por
  atleta) y el resto individual, con ritmos, recuperaciones y calzado; **sin avisos
  de salud ni notas privadas salvo que se marque**.
- **iPhone**: Semana con los 7 días a la vista (domingo incluido) y debajo sus
  atletas, o la semana de un atleta; filtros y leyenda plegados; Hoy con el resumen
  de avisos desplegable; nada desborda a lo ancho; la barra inferior no tapa.

**Cómo se validó:** banco de pruebas local (`portal/_maqueta-academia/real.html`, no
se sube) que carga la misma página con los datos del grupo PRUEBA exportados con los
permisos de Andrés; los siete casos (doble sesión, ausencia que conserva lo previsto,
parcial, feedback nuevo y revisado, publicada con revisión pendiente, grupo con
ritmos individuales, impresión e iPhone) en PC y a 390 px. Las escrituras de verdad
(revisado, revisión crear/aplicar, grupos de trabajo, observación, intención con
candado, publicar) se probaron en la base como Andrés en transacciones deshechas, y
sin permiso (otro responsable) no se ve ni se escribe nada.

**Ajustes del 28-oct (mig 464):**
- **Seguimiento por atleta** («Seguimiento…» en Semana, y en el detalle): feedback
  del atleta (por defecto) · registro del entrenador · feedback no requerido. Nadie
  sale del seguimiento ni se borra nada; la elección de cada persona la hace Andrés.
  - *Registro del entrenador* (`academia_registros_entrenador`): realizada / parcial
    (%) / no realizada + observación, atado a la versión de la sesión. Consta como
    declaración del entrenador: **sin RPE ni sensaciones del atleta**. Si falta
    pasado el plazo: «Sin datos · falta tu registro».
  - *No requerido*: «Sin datos · feedback no requerido», sin pendiente. Si el atleta
    responde, se ve igual.
- **Feedback cambiado tras revisarlo**: vuelve a pendiente y guarda quién y cuándo
  revisó la versión anterior (`revision_anterior_*`, más el historial de correcciones).
- **Semana en PC** pliega la lateral del panel (sin cambiar la preferencia guardada).
  Números y distancias sin partir.
- **Casilla detallada**: una línea por fila del plan (series, ritmos, recuperaciones y
  calzado); la exigencia, solo en el detalle.
- **iPhone**: cabecera y controles compactos (filtros plegados; el nombre abre su
  semana) y más margen bajo la última tarjeta para la barra flotante.

## Navegación

```
Panel ─ tira de mundos (PLEGABLE) ─ … · Atletismo pista · [Academia AC98] · …
                              │
                              ├─ Hoy            (entrada: individual · por grupos de trabajo)
                              ├─ Semana         (tabla atletas × días: compacta · detallada)
                              ├─ Atletas        (lista → ficha)
                              ├─ Feedback       (plan respondido + realizado, filtros)
                              ├─ Tests y marcas
                              ├─ Competiciones
                              └─ Carga y contenidos   ← cuando el modelo esté validado
Detalle de una sesión = panel lateral (PC) · pantalla completa (móvil).
```

## Criterios de diseño

- **Identidad azul del club**, con:
  - menos sombras y menos cajas decorativas;
  - texto secundario más grande y con más contraste;
  - **el color, solo para información útil** (estado, avisos).
- **Tira de mundos plegable y menú de Academia compacto**, para dar ancho al
  entrenamiento.
- **Jerarquía**: atleta → sesión → trabajo → avisos.
- **Estados con texto**, no solo color o símbolos: cada uno tiene su etiqueta y su
  explicación accesible.
- **Pocas pantallas.** Se reutilizan datos y funciones existentes.

## Semana (vista principal)

- **Tabla atletas × días**:
  - nombres y cabecera de días **fijos al desplazarse**;
  - **columna de hoy** destacada suavemente;
  - «‹ Anterior · **Esta semana** · Siguiente ›»;
  - filtros por **atleta** y por **grupo de trabajo**;
  - **Compacta / Detallada**.
- **Mañana y tarde** separadas en la casilla; «sin especificar» cuando no consta.
- **Detallada**: se entiende la sesión sin abrirla, por ejemplo «Ritmo 400 ·
  2×(250+150) · 34–35″ / 19,5–20,5″ · Z». No se queda en títulos genéricos como
  «Fuerza-potencia».
- **Tres dimensiones de estado, separadas y con texto**:
  1. **Publicación**: borrador · publicada.
  2. **Ejecución**: realizada · parcial · no realizada · sin datos.
  3. **Revisión**: feedback pendiente · feedback nuevo · aviso que revisar.

  Un ✓ de feedback **no** significa «entrenamiento completado». El feedback se marca
  como pendiente **solo cuando ha pasado el plazo para responder**.
- **Tipos de día**: entreno · descanso · ausencia (con su motivo) · sin planificar.
  Una ausencia no borra lo previsto.
- **Resúmenes**: separan **atletas** de **sesiones**; los descansos y las ausencias
  **no cuentan** como entrenamientos.

## Hoy

- **Dos vistas**: individual y **por grupos de trabajo** (p. ej. «aceleración: Álex y
  Bruno»). Cada grupo se despliega con su entrenamiento y las diferencias de cada
  atleta. Es la versión digital del resumen que se imprime para dirigir la sesión.
- **Acciones**: imprimir el entrenamiento de hoy · abrir sesión · añadir observación
  · ver ficha · **pasar lista** (lo que ya existe).
- **Pendiente de revisar**: hechos concretos con su origen (qué registro, de cuándo).
  Las decisiones cuya fecha de revisión llega **quedan pendientes**: no desaparecen
  ni dan al atleta por recuperado.
- Cifras que separan **atletas** de **sesiones** (p. ej. «9 atletas · 10 sesiones»
  si hay dobles).

## Detalle de una sesión

- **Arriba**: atleta, fecha y sesión.
- **Contenido según el momento**:
  - si ya entrenó: lo realizado y su feedback, junto al plan respondido;
  - si aún no: el plan actual.
- **Observación del entrenador**, y la opción de añadirla.
- **«Ver cambios respecto al plan respondido»**: desplegable con **solo las
  diferencias** resaltadas. La comparación completa de versiones, solo si se pide.
- **Navegación**: cierre visible, atleta anterior/siguiente y pantalla completa en
  móvil.
- **Editar y publicar dicen sobre qué versión actúan** (p. ej. «Editar la versión 2 ·
  borrador»).

## Ficha del atleta

- Perfil estable separado de la **situación temporal** («Ahora»).
- Objetivos **por temporada** (las tres próximas, prueba principal y secundarias).
- Decisiones vigentes, con su motivo y vigencia. Al llegar la fecha de revisión,
  pasan a **pendiente de revisar**.
- Marcas y tests **con fecha y condiciones**, y las últimas mediciones comparables.
- **Evolución de las últimas 4 semanas**:
  - sesiones realizadas, cobertura del feedback, volumen por contenido, RPE y
    molestias;
  - se incorpora **cuando el modelo de cálculo esté validado**, sin estimaciones
    ocultas. Hasta entonces, el hueco dice que está pendiente.

## Móvil (iPhone)

- **Hoy**: grupos y atletas desplegables.
- **Semana**: se elige un día y debajo salen sus atletas, con la opción de ver la
  semana de un atleta. **No se encoge la tabla de 7 días.**
- **Ficha**: una columna, pestañas desplazables.
- **Detalle**: pantalla completa.
- Texto legible sin ampliar y controles cómodos para usar en pista.

## Qué se reutiliza y qué falta

| Se reutiliza | De dónde |
|---|---|
| Mundos, lateral, móvil | `assets/js/mundos.js` |
| Sesiones, versiones, feedback, correcciones, archivadas | fase 1 |
| Planificar, copiar semana, plantillas, pasar lista | `portal/entrenador` |
| Feedback por día, ficha, notas, RM | `portal/entrenador` |
| Lesiones, carga y bienestar, tests, competiciones | `portal/lesiones`, `portal/carga`, `portal/tests`, `admin/competiciones` |

| Falta | Cambio |
|---|---|
| Entrada y acceso | Nuevo mundo; admin y entrenador de Academia. Más entrenadores: tabla `grupo_entrenadores` + 3 funciones de permiso, solo para Academia (aparte, con visto bueno). |
| Tipo de día, momento, ausencias | `sesiones.clase_dia`, `sesiones.momento` (con `sin_especificar`), `ausencias` con motivo tipificado; relleno prudente de lo antiguo. |
| Grupos de trabajo del día | Hecho: `grupos_trabajo` + `grupos_trabajo_miembros` (sesión entera o un bloque). |
| Revisión del feedback | `registros_sesion.revisado_en` / `revisado_por`; plazo de respuesta configurable. |
| Revisiones de sesiones publicadas | `sesiones_revisiones` (también la usa ChatGPT). |
| Objetivos y decisiones | `atleta_objetivos` (+ historial), ampliar `notas_atleta`. |
| Texto detallado de la casilla | Del plan: la «parte principal» resumida (sin cálculos). |

## Decisiones tomadas (v2 → v3, 28-oct)

- **Grupos de trabajo**: los decide el entrenador cada día; la app solo sugiere. Por
  sesión o por bloque. Cada atleta conserva su prescripción y su registro.
- **Plazo del feedback**: configurable (propuesta: 22:00 del mismo día). **Nunca se
  marca retraso antes de que termine la sesión.**
- **Arrastre «12 kg»**: los antiguos quedan pendientes; para lo nuevo, dos campos:
  discos añadidos y masa total.
- **Lanzados**: notación explícita «3×60 lanzados, entrada 20 m + tramo 60 m». Los
  antiguos ambiguos, pendientes.
- **Vallas**: altura, separación, distancia a la 1.ª y punto final de medición, con
  plantillas cuyos valores se guardan en cada versión.
- **Acceso**: de momento, admin y entrenador autorizado de Academia (sin cambios de
  permisos).
- **Método de cronometraje**: lo elige quien registra; se corrige por repetición; no
  se asumirán fotocélulas al comprarlas.
- **Intención visible**: objetivo breve y exigencia prevista (baja/media/alta,
  neuromuscular/metabólica) en cada sesión.

## Revisar frente a sustituir

| | **Revisión** | **Sustitución** |
|---|---|---|
| Cuándo | Cambia el contenido de la **misma** sesión prevista (mismo atleta, día y franja, misma intención): ajustar series, ritmos, ejercicios… | La sesión prevista se reemplaza por **otra distinta**: otro día, otro tipo de trabajo, o el atleta hizo otro entrenamiento en su lugar. |
| Cómo | Mismo `id`, **versión nueva**. Si está publicada: revisión en borrador vinculada; al aplicarla, versión nueva de la misma sesión. | Sesión **nueva** con `sustituye_a` = la original. La original queda «sustituida». |
| Recuento | Una sola sesión. | La original no cuenta como «no realizada», ni la nueva como adicional. En la semana se ve la nueva con «sustituye a…». |
| Lo realizado | Queda atado a la versión que respondió el atleta. | **No se sustituye una sesión que ya tiene registros**: lo realizado le pertenece. En ese caso se revisa, o se añade una sesión adicional explícita. |

## Fases (prioridad: Semana y Hoy)

1. **Base de datos mínima**: `clase_dia`, `momento` (con `sin_especificar`),
   ausencias tipificadas, `revisado_*`, objetivo y exigencia, grupos de trabajo,
   revisiones de publicadas, `sustituye_a`, plazo de feedback. Relleno prudente de lo
   antiguo.
2. **Mundo «Academia AC98» + Semana** (compacta y detallada, tres estados, mañana y
   tarde, filtros, detalle con cambios respecto al plan respondido, publicar con
   versión). Acceso solo de admin y del entrenador de Academia.
3. **Hoy** (individual y por grupos, pendiente de revisar, imprimir, pasar lista).
4. **Ficha** (perfil · «Ahora» · objetivos por temporada · decisiones · marcas y tests
   con condiciones) y **Feedback** integrado.
5. **Conexión con ChatGPT**: prueba real paso a paso con datos ficticios.
6. **Modelo de cálculo** (estructura de filas, contenidos, cargas) → **Carga y
   contenidos**, evolución de 4 semanas y tendencias. Solo sobre lo validado.

Las mejoras visuales no esperan al análisis avanzado; los cálculos automáticos sí
esperan a que las definiciones estén cerradas.
