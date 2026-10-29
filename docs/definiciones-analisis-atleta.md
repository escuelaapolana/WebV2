# Análisis del atleta · definiciones (v1, 29-oct-2026)

Cerradas por Andrés (vía ChatGPT) el 29-oct. Maqueta con datos ficticios:
https://claude.ai/artifact/RwECJZi7dvtHWqZKpgeaiQ. Primera versión **solo en grupos
de prueba**; activarla con atletas reales necesita su OK explícito.

## Qué es

Una pestaña de la ficha (`?v=ficha&a=…&fs=analisis`) que **solo lee**: no guarda
conclusiones, no cambia entrenamientos y no genera decisiones.

- **Primera pantalla**: resumen en 4 frases (qué preparamos · trabajo registrado ·
  cómo responde · qué revisar), dos gráficas (marcas comparables con el objetivo;
  parciales reales frente al modelo) y hasta 3 asuntos. El resto, plegado.
- Cada frase lleva su **periodo**, la **hora del cálculo** y abre los datos de los
  que sale. Si faltan datos, lo dice.

## Hechos, hipótesis y decisiones

- **Observado**: un resultado o una evolución respaldados por registros, con el
  número de casos y su límite.
- **Por comprobar**: huecos, discrepancias, mediciones incompletas,
  comparabilidad por confirmar. Siempre como algo que falta saber.
- **Decisión del entrenador**: solo las de `atleta_decisiones` (acción, motivo,
  fecha de revisión). La app no propone ni genera decisiones.
- Nunca: convertir un comentario aislado, un RPE alto o una semana sin registros
  en una deficiencia; inferir lesiones o causas médicas; puntuaciones, radares o
  semáforos sin criterio.

## Reglas cerradas

1. **Tres sesiones** comparables permiten mostrar una **evolución descriptiva
   inicial**, nunca afirmar un patrón automáticamente. Se muestra siempre el
   número de sesiones, de intentos y las condiciones comparadas.
2. **Cobertura**: siempre **N de M y porcentaje**. **Sin umbral de aviso** (el 70 %
   no está justificado). Lo pendiente o incompleto se ve siempre, sea cual sea el
   porcentaje.
3. **Revisión cercana**: **21 días**, criterio organizativo **configurable** por
   grupo (`academia_grupos.revision_cercana_dias`). Se separan **«próxima
   revisión»** (dentro del plazo) y **«revisión vencida»** (fecha pasada). Ninguna
   finaliza una decisión: sigue vigente hasta que alguien la revisa.
4. **Sesiones comparables**: se compara el **bloque o ejercicio relevante**, no el
   número de versión ni necesariamente la sesión entera. Se miran distancias,
   repeticiones, bloques, recuperaciones, intensidad prescrita, salida, calzado,
   superficie y método de medición; en fuerza, además, ejercicio, variante y
   recorrido; en vallas, altura y separaciones. Si falta una condición relevante:
   **«comparabilidad por confirmar»** (se enseña, no se descarta). Un cambio de
   título o de nota no impide comparar.
5. **Modelo de parciales**: lo **define y valida Andrés**. ChatGPT puede preparar
   una **propuesta** identificada como tal (origen, fundamento y limitaciones); no
   pasa a objetivo acordado ni a modelo vigente automáticamente. Se guardan autor,
   fecha, versión y aprobación (quién, cuándo, qué versión). Para aprobarlo, los
   tramos principales tienen que ser seguidos desde 0, sumar el total, y cada
   subdivisión tiene que cubrir su tramo y sumar su tiempo. Editar un modelo
   aprobado lo devuelve a propuesta.

## Marcas comparables

Misma prueba del catálogo, mismo tipo de cronometraje (electrónico / fotocélulas /
manual / vídeo no se mezclan), oficial frente a no oficial por separado, mismas
condiciones (vallas, peso…) y viento legal (≤ +2,0 m/s) donde cuenta. Lo que no
entra se enseña **aparte, con el motivo**. Los huecos de fechas no se unen con
líneas.

## Trabajo y cobertura

El mismo motor de Carga y contenidos (`assets/js/academia-carga.js`), por semanas:
previsto · confirmado con detalle · solo por «completa» (declaración global) · sin
datos (hueco, no cero). Metros, minutos, repeticiones, kilos y contactos nunca se
suman entre sí. Una discrepancia pendiente no se da como valor resuelto.

## Referencias

Se distinguen medición real, objetivo individual acordado, referencia externa
(con su fuente) y estimación de un modelo. Sin equivalencias del tipo «para correr
21 s necesita saltar X» sin un modelo identificado y revisado.

## Pendiente

- Activación con atletas reales (OK de Andrés).
- Que ChatGPT pueda registrar la propuesta de modelo por su conexión de prueba
  (hoy la registra Andrés marcándola «de ChatGPT»).
- Los ajustes de la «revisión del PDF» que mencionó ChatGPT (no llegaron).
