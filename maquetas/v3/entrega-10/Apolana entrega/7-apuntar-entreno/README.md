# 7 · Apuntar el entreno · zona del atleta

Para quien implementa. Las seis piezas que faltaban, todas dentro de la misma pantalla: el
atleta apuntando lo que ha hecho hoy.

**Archivo visual:** `Apuntar entreno Apolana.html`. Cuatro móviles: **1a** fuerza en reposo ·
**1b** escribiendo un ejercicio nuevo · **1c** pista · **1d** natación. Debajo, las piezas 2 a 6
con sus medidas.

---

## La decisión que ordena todo: escribir siempre gana

El campo del ejercicio es **texto libre**. Las sugerencias ayudan; nunca cierran. Los dos
problemas que el club ya tuvo —el desplegable cerrado y el buscador arriba de la pantalla—
vienen de invertir eso.

Y la fila **sabe de qué deporte habla**: no hay selector de tipo, lo decide el bloque en el que
está el atleta.

| Deporte | Columnas |
|---|---|
| **Fuerza** | Serie · Reps · Kg · **RIR** (54 px) |
| **Pista** | Serie · Distancia · Tiempo · Descanso — **sin RIR** |
| **Natación** | Serie · Metros · Tiempo · Descanso — **el material va en chips** |

### Los rangos se quedan como rangos

«35-45 min», «45-60 s», «20-30 s» son el plan y se muestran **tal cual, en gris, sobre la
tabla**. Lo que el atleta escribe es un número suyo en la casilla.

**Nunca se rellena la casilla con la media del rango.** Es el error que ya se cometió: después
nadie sabe si el 40 lo puso él o lo puso la app.

### La notación del plan es la del club

Fuerza: **`3×8×60 kg (RIR 2)`** — series × reps × peso, RIR entre paréntesis.
Y el resumen de lo hecho usa la misma forma: **`Hecho: 3×9 (RIR 1)`**, para que se lean uno
contra otro de un vistazo.

Pista: `4×300 al 85 % · desc. 3 min`. Natación: `8×50 m · desc. 20-30 s`.

---

## 1 · La fila del ejercicio · la que manda

**Un ejercicio es una tarjeta. Una serie es una fila.**

Tarjeta: radio 12 px, borde `#E4DCCB`, fondo blanco.

1. **Nombre** 17 px peso 500 `#2E4256`.
2. **Plan** debajo, 14px/1.35 `#6E6656` con la cifra en `#4A4437`.
3. **Chip de tope** a la derecha (pieza 6).
4. **Cabecera de columnas**: 12 px peso 500, `letter-spacing: 0.05em`, mayúsculas, `#6E6656`.
5. **Filas de serie**: casillas de **46 px**, radio 8 px, borde `#C6BEAE`, texto 16-17 px
   centrado. Número de serie en 34 px.
6. **Pie**: «+ Serie» y «Lo cambié» (o «Metros / km» en pista), botones perfilados de 44 px.

### Las series del plan vienen ya creadas

Si el plan dice 3×8, aparecen **tres filas**. Nadie pulsa «+ Serie» tres veces para hacer lo
que estaba escrito.

### El arrastre en gris · esto es lo que hace que se use

La serie siguiente viene **rellenada con lo de la anterior en `#A79E8B`** sobre fondo
`#FBF9F4`.

- Si el atleta **no la toca**, se guarda tal cual.
- Si **escribe**, el valor pasa a `#2E4256`.
- Casilla activa: borde `1.5px solid #2F72AB`.

Apuntar una serie cuesta **dos toques, no ocho**. En pista se arrastra también la distancia: en
4×300 solo se teclea el tiempo.

### «Apuntar solo el total»

Enlace al pie de la tabla cuando el plan tiene **más de cuatro series**: «Quedan 6 series de
50 · **apuntar solo el total**». Ocho de 50 son ocho filas y nadie sale del agua a rellenarlas.
Vale para natación y para pista.

---

## 2 · Las sugerencias

**Dentro de la fila, debajo del campo.** La fila crece en su sitio; el resto de la pantalla no
se mueve. Nunca un buscador arriba.

- Aparecen a partir de **dos letras**, con la parte escrita en **negrita**.
- Filas de **46 px**. Máximo cinco visibles, y se desplaza dentro del bloque.
- **Dos grupos**, con cabecera sobre `#F1EADC` (12 px, `letter-spacing: 0.06em`, mayúsculas):
  1. **«Los que ya haces»** — con el tope a la derecha en 13 px `#6E6656`.
  2. **«Del catálogo del club · [bloque]»** — filtrado por el bloque actual.
- Pie del bloque, sobre `#FBF9F4`: **«Si no es ninguno, sigue escribiendo y pulsa Listo: se
  guarda tal cual.»**

Esa última frase es la que garantiza que escribir gana. Sin ella, la lista parece obligatoria.

**Los 193 nunca se muestran de golpe.** El orden —lo tuyo primero, el catálogo después— es lo
que hace que no haga falta recorrerlos.

---

## 3 · Añadir al banco

**Aparece después de apuntar, no antes**, y solo si el nombre no existe en el catálogo.

Franja de una línea sobre `#F1EADC`, radio 10 px, padding 12px 15px:

- Texto: «"Zancada patinador" no está en el catálogo.» 15px/1.45 `#4A4437`.
- Botón **«Guardar»**: 44 px, radio 8 px, **perfilado** (borde `#C6BEAE`, fondo blanco, texto
  `#2F6FA8`). **Nunca azul sólido** — la mayoría de las veces no se pulsa.
- Debajo, 14px/1.45 `#6E6656`: «Si no lo guardas, el ejercicio se apunta igual. Solo es para que
  la próxima vez salga solo.»

---

## 4 · La caja del RIR

RIR = repeticiones en reserva. **Va por serie**, decisión explícita del club.

- Columna de **54 px**, la más estrecha, a la derecha de los kilos. Alto 46 px.
- Al tocarla, teclado propio: **0 a 4 en botones de 44 px**, más «5+». No el teclado numérico
  del sistema, que es lento para un solo dígito.
- **Vacío se muestra «—», nunca «0».** Cero significa «al fallo» y es un dato distinto de no
  haberlo puesto.
- **Solo en fuerza.** En pista y natación esa columna es el descanso.

---

## 5 · «Lo cambié por»

Cuando el atleta hace otro ejercicio en lugar del planificado. Pasa constantemente.

**Banda en la cabecera de la tarjeta**, fondo `#FDF6EA`, borde inferior `#EBD9B8`:

- Etiqueta «Lo cambié» en 12 px peso 500, `letter-spacing: 0.05em`, mayúsculas, `#8A5207`.
- Al lado: «tocaba ~~jalón al pecho~~» — **el planificado tachado**, 14px/1.35 `#4A4437`.

**El título de la tarjeta es lo que se hizo de verdad** («Dominadas»). Así el historial dice
dominadas, que es lo que pasó, sin perder qué tocaba — el bug que originó esta pieza.

El motivo es **opcional y de una línea** («No había máquina libre»), en la línea de contexto
bajo el nombre.

Se entra por el botón **«Lo cambié»** del pie de la tarjeta, que abre el mismo campo de texto
libre con sus sugerencias.

---

## 6 · Tu tope

**Chip verde a la derecha del nombre**, no un bloque: `#EDF5EE`, borde `#CBE0CE`, texto
`#2F5C39` 12 px peso 500.

- «Tu tope 92,5» en kilos si el ejercicio lleva peso.
- «Tu tope 11» en repeticiones si es corporal.
- «Tu mejor 38,1» en pista, con la marca de referencia.

**Se mira de reojo al empezar la serie y no debe robar sitio.** Aparece también a la derecha de
cada sugerencia del grupo «los que ya haces».

---

## Natación · el material

**No es una columna: son chips del ejercicio**, bajo la línea del plan. Las palas y el pull
buoy se ponen **una vez para las ocho series**, no ocho veces. Una columna de material sería la
más ancha y la más repetida de la tabla.

- Chip puesto: `#EAF2F9`, texto `#1E4E78`, 13 px peso 500.
- Añadir: chip con **borde discontinuo** `#C6BEAE`, texto «+ material» `#6E6656`.

La cabecera de la pantalla lleva **los metros totales** —«2.400 m en total · 1.200
apuntados»—, porque en natación el volumen es la cifra que se mira, no el número de ejercicios.

> **Decisión menor pendiente:** en el calentamiento de natación conviven la columna «Material»
> con un guion y los chips en los ejercicios con material. Si el club prefiere una sola forma,
> se quedan **solo los chips** y la columna desaparece.

---

## Cómo se siente

- **Móvil primero**, de pie, con una mano, entre máquinas o en la pista.
- **Nada pulsable por debajo de 44 px.**
- **Nada de cronómetros, animaciones ni celebraciones.** Cuanto más se parezca a una libreta,
  mejor. La usan chavales de doce años y padres de cincuenta.
- Sin monoespaciada: las cifras van en IBM Plex Sans, centradas en su casilla.

---

## Tokens

Los mismos del paquete 5 y 6. Los propios de esta pantalla:

| Uso | Hex |
|---|---|
| Valor arrastrado sin confirmar | **`#A79E8B`** sobre fondo `#FBF9F4` |
| Casilla activa | borde `#2F72AB` a 1.5 px |
| Borde de casilla | `#C6BEAE` |
| Cabecera de grupo en sugerencias | fondo `#F1EADC` |
| Chip de tope | `#EDF5EE` · borde `#CBE0CE` · texto `#2F5C39` |
| Banda «Lo cambié» | `#FDF6EA` · borde `#EBD9B8` · texto `#8A5207` |
| Chip de material | `#EAF2F9` · texto `#1E4E78` |
| Botón «Terminar la sesión» | `#2F72AB` |

---

## Lo que hace falta del club

1. **Los 193 ejercicios con su bloque** (tren inferior, superior, core…) **y su unidad** (kilos,
   corporal, tiempo). Sin eso las sugerencias no se pueden agrupar y vuelve la lista larga, que
   es el problema que se quería resolver.
2. **Quién aprueba lo que entra en el banco.** Si entra sin revisar, en un año hay
   «sentadilla», «sentadillas» y «squat» como tres ejercicios distintos, y los topes se parten
   entre los tres.
3. **El catálogo de material de natación** (palas, pull buoy, tabla, aletas, tubo…), para que
   los chips salgan de una lista y no escritos a mano.

## Orden de trabajo

1. **La tarjeta de fuerza con el arrastre en gris.** Es el 80 % del valor: si esto funciona, la
   app se usa.
2. **El campo de texto libre con sugerencias.** Sin agrupar todavía si el catálogo no está
   etiquetado.
3. **RIR, tope y «lo cambié».** Las tres son añadidos sobre la tarjeta ya hecha.
4. **Pista y natación.** Mismas columnas cambiadas, más los chips de material.
5. **«Añadir al banco»** y «apuntar solo el total». Las dos son atajos, no requisitos.
