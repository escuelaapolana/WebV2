# Panel de seguimiento de atletismo — requisitos pendientes

> **Estado:** pendiente. Visión completa recibida el 28-oct-2026; **no se construye todavía**.
> Antes hay que revisar qué datos estructurados hacen falta y dividir el panel en fases.
> La fase 1 (protección del histórico) ya está hecha: ver «Base que ya existe».

## Ámbito y dónde vive

- **Es para Academia AC98** (el grupo de velocistas): el registro de entrenos, el
  feedback y todo este seguimiento se diseñan para ese grupo (Andrés, 28-oct-2026).
- **Vivirá en un mundo propio «Academia AC98»** dentro del panel por mundos
  (`assets/js/mundos.js`), con toda la información por atleta. Hoy Academia va
  dentro de «Atletismo pista». Crear ese mundo forma parte de la primera versión
  del panel, no de la fase 1.

## Objetivo

Unificar en la app la planificación de atletismo, el feedback y el seguimiento
por atleta, con **Supabase como registro principal** (sustituye al control maestro
en Excel).

## Prioridad inicial

1. **Resumen del grupo.**
2. **Ficha individual** del atleta.
3. **Previsto frente a realizado.**
4. **Volumen por contenido.**

## Principios (obligatorios en todas las fases)

- **Toda conclusión automática enlaza con sus registros de origen**: la sesión
  (y la versión respondida), el registro del atleta, el bienestar del día…
- **Se distingue lo real de lo estimado.** Lo que apunta el atleta o el entrenador
  es real. Lo que se calcula (por ejemplo, volumen = plan × % completado) es una
  estimación y se marca como tal.
- **Se señala la información incompleta**: registros que faltan, datos sin rellenar
  y registros antiguos cuyo plan no está garantizado (`version_garantia`
  `sin_garantia` / `sobrescrita`).
- **Las decisiones y la publicación de entrenamientos siguen pasando por Andrés.**
  El panel (y cualquier asistente) propone o deja borradores; no publica ni decide.

## Base que ya existe (fase 1, migs 458-459, 28-oct-2026)

- `sesiones_versiones`: cada versión de cada sesión, inmutable, con fecha y autor.
- `registros_sesion.sesion_version_id`: la versión que respondió cada atleta (fija).
  `version_garantia` + `version_nota` en los registros anteriores al historial.
- `registros_sesion_versiones`: valores anteriores de cada corrección del feedback.
- Las sesiones con registros se archivan (`archivada_en`); no se borran en cascada.
- Lo demás: `registros_sesion` (estado, % completado, RPE, molestia y zona,
  duración, tiempos por fila, marcas en texto), `bienestar_diario`,
  `lesiones_atleta`, `notas_atleta`, `marcas_atleta`, `test_resultados`,
  `rm_atleta`, `microciclos`.

## Por decidir antes de construir

- Qué datos estructurados faltan (p. ej., perfil deportivo, objetivos, decisiones
  del entrenador; cómo medir el «contenido» de cada fila para el volumen).
- División en fases del panel.

## Propuesta completa (Andrés, 28-oct-2026)

### Objetivo

Ver de un vistazo qué está haciendo cada atleta, cómo tolera el entrenamiento y si
está mejorando. El análisis reúne planificación, ejecución real, feedback del
atleta, observaciones del entrenador, bienestar, marcas y tests.
**Supabase es el registro principal. Excel y PDF son formatos de exportación**, sin
versiones paralelas de la información.

### 1. Resumen del grupo

Una fila por atleta con: última sesión prevista y realizada; RPE, sensaciones y
molestias comunicadas; disponibilidad actual; próxima sesión y objetivo;
competición próxima; datos pendientes de completar.

Avisos concretos y explicables (falta feedback, más volumen del previsto, ha
comunicado molestias, ha faltado a varias sesiones…). **Nada de puntuaciones o
semáforos sin explicar qué datos los justifican.**

### 2. Volumen por contenido

Cada bloque con un **objetivo principal y etiquetas secundarias**; la clasificación
la puede revisar y corregir el entrenador. Contenidos iniciales:

- Aceleración y salidas de tacos.
- Fuerza horizontal y arrastres.
- Velocidad máxima.
- Resistencia a la velocidad.
- Ritmo específico de competición.
- Capacidad o potencia glucolítica **como intención prevista** (sin afirmar que se ha medido lactato).
- Carrera aeróbica, rodaje, intervalos y fartlek.
- Fuerza estructural, máxima, potencia y complementaria.
- Pliometría y reactividad.
- Técnica básica de carrera y técnica de salidas.
- Técnica específica de vallas, altura y lanzamientos.
- Movilidad, preventivos y recuperación.

Unidades por contenido: **carrera** en metros, km, minutos y repeticiones; **fuerza**
en ejercicios, series, repeticiones, kg y %RM si hay una referencia válida;
**saltos** en contactos, tipo de salto y carga; **técnica** en minutos, repeticiones
o intentos. **No sumar todo en una única medida de volumen.** Un bloque puede tener
varias etiquetas, pero sus metros no se duplican en el total.

### 3. Previsto frente a realizado

Comparar series, metros y minutos; ritmos prescritos y tiempos reales; descansos
previstos y reales (si se registran); cargas y ejercicios; calzado y superficie;
sesiones sustituidas, añadidas, incompletas o no realizadas, y el motivo del
cambio. **Una sesión que sustituye a otra no cuenta como adicional.** El plan que vio
el atleta se conserva por versión. **Nunca asumir que lo previsto se realizó porque
no haya feedback.**

### 4. Ficha individual de evolución

Prueba principal y secundarias; perfil deportivo; objetivos de temporada y a tres
años; marcas oficiales y tests; aceleración, velocidad lanzada y capacidad de
sostener la velocidad; parciales acumulados y por tramo; regularidad entre
repeticiones; fuerza, saltos y otros indicadores de su especialidad; fecha y
condiciones de cada medición.

**Separar mediciones reales, referencias estimadas y objetivos.** No mezclar
cronometraje manual con fotocélulas, ni distintas alturas de vallas, implementos o
variantes de ejercicio como si fueran equivalentes.

### 5. Respuesta al entrenamiento

Relacionar lo realizado con RPE y duración, sensaciones, bienestar y respuesta al
día siguiente, observaciones técnicas del entrenador y evolución del rendimiento.
Tendencias **con sus registros de origen** (p. ej., «ha completado varias sesiones por
encima del ritmo previsto con esfuerzo moderado»). **No convertir observaciones en
aumentos de carga ni atribuir causas que los datos no demuestran.**

Las aportaciones del entrenador distinguen: **observación, decisión, motivo, fecha de
entrada en vigor y, si corresponde, fin de vigencia.**

### 6. Distribución semanal

Calendario con el objetivo de cada día y la exigencia prevista, diferenciando
carrera rápida, trabajo metabólico, fuerza, impactos y saltos, técnica y
recuperación. Detectar acumulaciones de estímulos exigentes y contenidos sin cubrir
por ausencias o cambios. **No reducir la carga a un único número.**

### 7. Exposición específica

Metros y días con clavos; metros con arrastre y carga utilizada; salidas de tacos;
flying (distancia de entrada y tramo lanzado por separado); vallas (altura,
separación, número de vallas, pasos e intentos); altura (aproximaciones, batidas y
saltos completos); lanzamientos (implemento, peso e intentos).

### 8. Resumen semanal automático

Qué estaba previsto y qué se hizo; qué capacidades se trabajaron y cuáles quedaron
sin cubrir; cómo respondió cada atleta; qué información falta; qué decisiones debe
revisar el entrenador para la semana siguiente. **Cada conclusión enlaza con lo que
la sustenta. Mostrar la cobertura del feedback: ausencia de datos no es ausencia de
problemas.**

### 9. Datos estructurados sin complicar la app

El atleta sigue viendo textos sencillos («3×30 flying (20+30) // 5′ C»), pero la app
entiende sus componentes: bloques, series y repeticiones; distancia de entrada y de
trabajo; duración; intensidad y su referencia; descansos dentro y entre bloques;
calzado, superficie y carga; objetivo principal y etiquetas secundarias.
Reutilizar campos e identificadores existentes. **Si la interpretación automática es
ambigua, pide revisión o queda pendiente; nunca inventa valores.**

### 10. Control del entrenador

Automatizar registro, cálculos y resúmenes. **Las propuestas de cambios quedan como
borradores: el entrenador revisa y publica.** Permisos por atleta y grupo; los
análisis usan solo la información necesaria, sin exponer datos personales ajenos a
su función.

### Orden propuesto

1. Cerrar la fase 1 (aviso de sesión archivada, recuperación de la copia externa,
   caso «abre v1 → el entrenador cambia → envía feedback»). No borrar el respaldo.
2. Presentar el modelo de datos y las reglas de clasificación y cálculo, sin implementar.
3. Revisar ejemplos reales: arrastre + libre, flying, bloques de series, gimnasio y vallas.
4. Implementar perfil, objetivos, decisiones y los campos estructurados necesarios.
5. Primera versión del panel: resumen del grupo, ficha individual, previsto frente a
   realizado y volumen por contenido.
6. Después: tendencias, resúmenes automáticos y acceso de un asistente externo.

La propuesta de modelo debe distinguir **qué existe ya, qué hay que ampliar y qué
requiere una tabla nueva**, e incluir cómo se tratan los registros antiguos
incompletos sin inventar información.

## Organización del mundo «Academia AC98» (Andrés, 28-oct-2026)

Mundo propio del panel, junto a los demás. **Centro de planificación y seguimiento**
de los atletas de Academia. Reutiliza atletas, sesiones, feedback, tests y demás
registros de Supabase: **ni otra app ni datos duplicados**. Mantiene el histórico
(fase 1) y los permisos.

1. **Hoy**: quién entrena y qué hace cada uno; ausencias y disponibilidad; feedback
   pendiente y avisos relevantes con su motivo; acceso rápido a la sesión y a la
   ficha de cada atleta.
2. **Planificación**: vista principal en **tabla, atletas en filas y días en
   columnas**; el nombre del atleta visible en todas las tarjetas; dobles sesiones
   separadas en **mañana y tarde**; distinguir **entrenamiento, descanso, ausencia y
   sin planificar** (no contarlos todos como sesiones); abrir el detalle, editar
   borradores, **comparar cambios** y **publicar**; conservar versiones y su relación
   con el feedback. (Problema actual: la vista semanal muestra muchas tarjetas con
   títulos iguales y «solo para 1», sin decir de qué atleta son.)
3. **Atletas**: ficha individual con perfil deportivo y pruebas, objetivos de
   temporada y a 3 años, disponibilidad habitual, decisiones vigentes,
   planificación, ejecución, feedback, bienestar, tests, marcas y competiciones;
   **situaciones temporales separadas del perfil estable**. Todo lo relevante sin
   salir de la ficha.
4. **Feedback**: plan respondido y trabajo realizado juntos; tiempos, RPE, duración,
   molestias y comentarios; observaciones y decisiones del entrenador; filtros por
   atleta, fecha, sesión y «pendiente de revisar»; historial de correcciones y
   señal de datos antiguos sin garantía.
5. **Carga y contenidos**: lo de §2, §6 y §8 de la propuesta (volumen previsto y
   realizado por capacidad, unidades propias, sin dobles conteos, distribución
   semanal, tendencias, cobertura de datos, conclusiones enlazadas a su origen).
6. **Tests y marcas**: resultados, evolución y objetivos; parciales por tramo y
   acumulados; mediciones reales, estimaciones y objetivos separados; condiciones
   (cronometraje, viento, altura de vallas, implementos, variantes de fuerza).
7. **Competiciones**: calendario y competiciones objetivo; pruebas previstas por
   atleta; resultados y relación con la planificación.

**Accesos:** administración y entrenadores autorizados de Academia. Los atletas
siguen viendo solo lo suyo en su portal. **Añadir el mundo no amplía por sí solo
permisos sobre otros grupos.**

**Trabajo con ChatGPT:** consultar el seguimiento y cargar borradores mediante una
conexión autorizada (ver [integracion-chatgpt.md](integracion-chatgpt.md)): sin
duplicados, detectando cambios hechos entretanto, conservando el histórico, y
publicar como operación aparte bajo instrucción de Andrés. **No se presupone que la
conexión exista; no se comparten credenciales en el chat.**

**Prioridad:** entrada «Academia AC98», vista semanal clara, ficha individual y
feedback integrado. Después, volumen y tendencias sobre las definiciones de datos
acordadas. Pocas pantallas claras, tablas compactas, detalle al abrir cada elemento.
