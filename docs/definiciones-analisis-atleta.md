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
   grupo (`academia_grupos.revision_cercana_dias`). Con la fecha de
   **Europe/Madrid**: antes de hoy, **«Revisión vencida»**; hoy, **«Revisar hoy»**;
   después y dentro del plazo, **«Próxima revisión»** (también en el resumen de la
   ficha). Ninguno cierra la decisión: sigue vigente hasta que alguien la revisa.
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
   aprobado lo devuelve a propuesta. Antes de aprobar se enseña la versión guardada
   entera (total, tramos, subdivisiones, sumas, fundamento, limitaciones, origen y
   versión) con el aviso: **cuadrar matemáticamente no es estar validado
   deportivamente**. El modelo ficticio de PRUEBA se etiqueta **«PRUEBA: origen
   ChatGPT simulado»** (`chatgpt_simulado`, solo admitido en grupos de prueba).

## Revisión del PDF (29-oct) · cómo queda

- Gráficas: la explicación coincide con el eje («más arriba = mejor (menos tiempo)»).
- Diferencias uniformes: «+0,40 s respecto al objetivo» (también en Tests y marcas).
- «0» = cero de verdad · «—» = no aplica · «sin dato» = no hay registro.
- «Sin resultados registrados», salvo que se sepa que no hubo competiciones.
- Sesiones futuras: **«Por llegar»**. Sesiones pasadas con el feedback aún en plazo:
  **«Pendiente de registro · en plazo»**. Ninguna es falta de registro ni baja la cobertura exigible.
- Trabajo por estado: con detalle · por «completa» · adicional · no realizado · en
  discrepancia · sin concretar · sin datos · por llegar; lo adicional puede superar lo previsto.
- Nada de «poco» o «insuficiente» sin referencia acordada para ese atleta y fase.
- Progresos y fortalezas con datos (sin causas), además de diferencias y pendientes.
- Sesiones comparables: todas las repeticiones en orden, con la prescripción comparada
  (distancias, repeticiones, recuperaciones, intensidad) y las condiciones.
- Parciales: Real / Modelo / Diferencia y la diferencia acumulada en cada paso.
- Cobertura de kg por series (no por repeticiones).
- Móvil: «Merece atención» antes de las gráficas y resumen breve.
- Prueba principal o secundaria a elegir; los parciales solo donde aplican (carreras).

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
| 1 | Ficha de Álex → «Análisis» → prueba **200 m lisos**. | Periodo 5 oct – 1 nov y hora del cálculo. Cuatro frases; «Cómo responde»: mejor 22,60, +0,40 s respecto al objetivo; evolución 22,95 → 22,78 → 22,60; «bloque 1/2…» 7 oct 34,8 · 20,4; 14 oct 34,6 · 20,3; 21 oct 34,4 · 20,2 (RPE 8 · 8 · 8). «Conviene revisar»: 1 vencida (26 oct), 1 próxima (12 nov), modelo sin aprobar, parciales de un intento. |
| 2 | «ver datos ›» de «Cómo responde». | Entran 22,95 · 22,78 · 22,60 (la mejor); aparte 22,84 (viento +2,6) y 22,1 (manual). |
| 3 | Gráficas. | Marcas sin unir con la línea del objetivo 22,20; parciales +0,10 · +0,10 · +0,15 · +0,05 con «propuesta de ChatGPT · sin aprobar». |
| 4 | Merece atención. | Observado (100–150, +0,15, un intento, modelo sin aprobar) · Por comprobar (mié 28 sin registro) · Decisión («Sin clavos…», revisión vencida el 26 oct, sigue vigente). |
| 5 | Plegables. | Trabajo por semanas con huecos; «Bloque 1/2» y «2/2» por separado, «comparabilidad por confirmar» (falta salida y método); cobertura N de M (%) sin avisos; aspectos en 3 grupos; referencias sin estimación. |
| 6 | «Modelo de parciales…» → «Aprobar la versión guardada» (solo administración). | Antes de aprobar enseña la versión guardada entera, la comprobación de la base y el aviso «cuadrar no es validar». La aprobación la hace Andrés cuando lo decida. |
| 7 | Grupo real. | En la ficha no aparece «Análisis». |

**Resultado tras la revisión del PDF · 29-oct, versión 20261029163119, sesión de Andrés:**
en vivo, 200 m lisos con «+0,40 s respecto al objetivo», evolución, todas las repeticiones,
tabla Real / Modelo / Diferencia con el acumulado (+0,10 → +0,20 → +0,35 → +0,40), modelo
«PRUEBA: origen ChatGPT simulado», móvil con «Merece atención» antes de las gráficas y sin
desplazamiento lateral. La revisión previa a la aprobación se abrió y se cerró **sin
aprobar** (en la base sigue `propuesta`, versión 2). Corregido después: las limitaciones
salían dos veces y «preparado por tú» (commit siguiente).

**Resultado · 29-oct, versión 20261029151416, sesión de Andrés:** pasos 1–5 y 7 **pasan**
tal como están escritos (en el grupo real no sale «Análisis» ni forzando `fs=analisis`).
Paso 6: el botón «Aprobar la versión guardada» le aparece a Andrés; **la aprobación la
hace él** (es su validación), no se ha pulsado.

## Antes de activar con atletas reales (autorización aparte de Andrés)

Alcance de la v1 **cerrado** el 29-oct. Ya comprobado: motor (47 comprobaciones), banco
local (PC y 375 px), en vivo con sesión (PRUEBA), aislamiento (en el grupo real no
aparece ni forzando `fs=analisis`).

Falta, sin rediseñar:
1. OK de Andrés y decidir con qué grupo (Academia AC98) y qué atletas.
2. Quitar la condición `ST.g.es_prueba` (pestaña y carga de datos) para ese grupo, y la
   frase «Primera versión, solo con el grupo de prueba». Carga y contenidos, que da las
   cifras de trabajo, también está solo en PRUEBA: va en el mismo paso.
3. Leer los datos reales sin escribir nada: registros antiguos «sin garantía de versión»
   (no reparten «completa»), perfiles con pruebas sin confirmar en el catálogo (sin
   prueba elegible no hay gráficas), atletas sin objetivo acordado.
4. Repasar con 2–3 atletas reales en vivo, solo lectura, y apuntar lo que no cuadre.
5. Confirmar las fechas de la temporada de planificación (siguen provisionales).

## Pendiente

- Activación con atletas reales: ver arriba.
- Que ChatGPT pueda leer modelos y proponerlos por su conexión de prueba: propuesta
  en docs/propuesta-conexion-modelos-parciales.md (sin activar).
