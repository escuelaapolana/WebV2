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
   revisión»** (en los próximos 21 días) y **«revisión vencida»** (la fecha ya ha
   llegado, también si es hoy: igual que en el resumen de la ficha). Ninguna
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

## Cómo está hecho (v1, 29-oct)

- Motor: `assets/js/academia-analisis.js` (marcas comparables, parciales frente al
  modelo, sesiones comparables, revisiones, cobertura); 39 comprobaciones con node.
  Usa el motor de Carga (`construirCarga(aid, desde, hasta)`) para trabajo y cobertura.
- Pantalla: `portal/academia/` · ficha → «Análisis» (solo si el grupo es de prueba).
- Base: mig 496 (modelo de parciales con origen, limitaciones y aprobación;
  `objetivo_parciales_comprobar`, `objetivo_parciales_aprobar` solo administración;
  `academia_grupos.revision_cercana_dias`). Datos ficticios de Álex: mig 497.
- «Bloque 1/2» y «Bloque 2/2» con la misma prescripción se comparan cada uno con el
  suyo; una fila «250 + 150» se compara entera (el 250 con el 250).

## Recorrido en vivo (con sesión, grupo PRUEBA, Álex)

| # | Qué hacer | Esperado |
|---|---|---|
| 1 | Ficha de Álex → «Análisis». | Periodo 5 oct – 1 nov y hora del cálculo. Cuatro frases; «Cómo responde»: mejor 22,60 a 0,40 s; «Bloque 1/2…» 1.er tiempo 34,8 → 34,6 → 34,4 (RPE 8 · 8 · 8). «Conviene revisar»: 1 vencida (26 oct), 1 próxima (12 nov), modelo sin aprobar, parciales de un intento. |
| 2 | «ver datos ›» de «Cómo responde». | Entran 22,95 · 22,78 · 22,60 (la mejor); aparte 22,84 (viento +2,6) y 22,1 (manual). |
| 3 | Gráficas. | Marcas sin unir con la línea del objetivo 22,20; parciales +0,10 · +0,10 · +0,15 · +0,05 con «propuesta de ChatGPT · sin aprobar». |
| 4 | Merece atención. | Observado (100–150, +0,15, un intento, modelo sin aprobar) · Por comprobar (mié 28 sin registro) · Decisión («Sin clavos…», revisión vencida el 26 oct, sigue vigente). |
| 5 | Plegables. | Trabajo por semanas con huecos; «Bloque 1/2» y «2/2» por separado, «comparabilidad por confirmar» (falta salida y método); cobertura N de M (%) sin avisos; aspectos en 3 grupos; referencias sin estimación. |
| 6 | «Modelo de parciales…» → «Aprobar la versión guardada» (solo administración). | Se aprueba la versión guardada; el modelo pasa a «aprobado … versión N». Cambiarlo y guardarlo lo devuelve a propuesta. |
| 7 | Grupo real. | En la ficha no aparece «Análisis». |

**Resultado · 29-oct, versión 20261029151416, sesión de Andrés:** pasos 1–5 y 7 **pasan**
tal como están escritos (en el grupo real no sale «Análisis» ni forzando `fs=analisis`).
Paso 6: el botón «Aprobar la versión guardada» le aparece a Andrés; **la aprobación la
hace él** (es su validación), no se ha pulsado.

## Pendiente

- Activación con atletas reales (OK de Andrés).
- Que ChatGPT pueda registrar la propuesta de modelo por su conexión de prueba
  (hoy la registra Andrés marcándola «de ChatGPT»).
- Los ajustes de la «revisión del PDF» que mencionó ChatGPT (no llegaron).
