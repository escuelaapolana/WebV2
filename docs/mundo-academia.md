# Mundo «Academia AC98» — PROPUESTA v2 (sin construir)

> 28-oct-2026 · v2 con las decisiones de Andrés (revisadas con ChatGPT).
> Requisitos: [requisitos-panel-seguimiento.md](requisitos-panel-seguimiento.md) ·
> Modelo: [modelo-datos-seguimiento.md](modelo-datos-seguimiento.md) ·
> Ejemplos: [ejemplos-calculo-academia.md](ejemplos-calculo-academia.md) ·
> Conexión: [integracion-chatgpt.md](integracion-chatgpt.md).
> Maqueta local (datos ficticios, plan real de la semana 9): `portal/_maqueta-academia/`.

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
| Grupos de trabajo del día | Etiqueta por sesión/atleta (p. ej. `grupo_trabajo`); **forma por decidir** (§Pendientes). |
| Revisión del feedback | `registros_sesion.revisado_en` / `revisado_por`; plazo de respuesta configurable. |
| Revisiones de sesiones publicadas | `sesiones_revisiones` (también la usa ChatGPT). |
| Objetivos y decisiones | `atleta_objetivos` (+ historial), ampliar `notas_atleta`. |
| Texto detallado de la casilla | Del plan: la «parte principal» resumida (sin cálculos). |

## Decisiones que siguen pendientes

1. **Grupos de trabajo de «Hoy»**: ¿los marca el entrenador en cada sesión (p. ej. un
   campo «grupo de trabajo») o se deducen de que tengan el mismo plan ese día?
2. **Plazo para el feedback**: ¿cuántas horas después de la sesión pasa a «feedback
   pendiente»? (Propuesta: a las 22:00 del mismo día.)
3. **«12 kg» en el arrastre**: ¿discos añadidos o masa total? (Cambia la exposición
   a carga.)
4. **«3×60 (20+60) lanzados»**: ¿los 60 m incluyen la entrada?
5. **Altura y separación de vallas**: ¿se indican siempre en el plan? Sin ellas, las
   sesiones de vallas no se comparan entre sí.
6. **Más entrenadores con acceso a Academia**: ¿hace falta ya? Implica tocar
   permisos.
7. **Fotocélulas**: cuando lleguen, ¿quién apunta el método por sesión?

## Fases (prioridad: Semana y Hoy)

1. **Base de datos mínima**: `clase_dia`, `momento` (con `sin_especificar`),
   ausencias tipificadas, `revisado_*`. Relleno prudente de lo antiguo.
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
