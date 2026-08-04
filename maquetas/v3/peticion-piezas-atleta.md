# Petición al maquetador · las piezas que faltan en la zona del atleta

Club Atletismo Apolana. Zona del atleta de la app (móvil primero).

Faltan seis piezas y **todas viven dentro de la misma pantalla**: el atleta
apuntando lo que ha hecho hoy. Por eso la primera es la que manda: las otras
cinco son partes de ella.

---

## 0 · Contexto, para que se entienda qué se está apuntando

En el club no todos hacen lo mismo. Hay **atletas de pista**, **nadadores** y
gente que hace **entrenamiento de fuerza** (lo llamamos así, no «gimnasio»,
porque no todo el mundo tiene uno). Un mismo atleta puede hacer pista el lunes
y fuerza el martes.

Eso cambia lo que se apunta:

- **En pista**: series, distancias (metros o kilómetros, se puede cambiar),
  tiempos y descansos. Se escriben rangos: «rodaje suave de 35-45 min»,
  «descanso 45-60 s». **Los rangos se quedan como rangos**: convertirlos en un
  número es un error que ya cometimos.
- **En fuerza**: repeticiones y **kilos**, con su unidad a la vista.
- **En natación**: metros, series y material.

Un ejercicio de fuerza **no pide tiempo**, y uno de pista no pide kilos. La
pantalla tiene que saber de qué está hablando.

La referencia que le gusta al club para la parte de fuerza es la app **Hevy**.

---

## 1 · El atleta añadiendo un ejercicio · **la que más urge**

La fila donde el atleta escribe un ejercicio que no estaba planificado, o
cambia uno por otro.

Lo esencial:

- **Se escribe, no se elige de una lista cerrada.** Esto es innegociable: si
  alguien hace un ejercicio que no está en el catálogo, tiene que poder
  escribirlo. Ya tuvimos un desplegable y fue un problema.
- **La fila se rellena donde está**, sin subir a un buscador arriba del todo.
  Antes había uno y obligaba a subir y bajar por cada ejercicio; se quitó por
  eso.
- Dentro de esa fila caben las cinco piezas de abajo.

## 2 · Las sugerencias

Al escribir, salen sugerencias **al lado, en la propia fila**. Sin tapar lo que
se está escribiendo y sin obligar a mover la pantalla.

Hay 193 ejercicios en el catálogo, así que la lista tiene que estar agrupada de
alguna forma: bajar hasta abajo buscando uno es lo que ya no funcionaba.

## 3 · «Añadir al banco»

Cuando alguien escribe un ejercicio que no existe, se le ofrece **guardarlo en
el catálogo** para que la próxima vez salga solo.

Es una franja pequeña, discreta, que aparece solo cuando hace falta. No debe
parecer un botón importante: la mayoría de las veces no se pulsa.

## 4 · La caja del RIR

**RIR** = repeticiones en reserva. Cuántas más habría podido hacer.

Dos cosas fijadas por el club:

- **Va en cada ejercicio, no al final de la sesión.** Fue explícito.
- Es un número pequeño (normalmente de 0 a 4) y se pone rápido, con el pulgar,
  entre serie y serie. No debe costar más que apuntar los kilos.

## 5 · La franja de «lo cambié por»

Cuando el atleta hace **otro ejercicio en lugar del que tocaba**. Pasa
constantemente: no hay máquina libre, o el entrenador lo cambia sobre la marcha.

Tiene que verse **qué estaba planificado y qué se hizo de verdad**, sin que una
cosa borre a la otra. Antes el historial decía «jalón al pecho» cuando lo que se
hizo fueron **dominadas**, y ese dato era falso — de ahí viene esta pieza.

## 6 · El bloque de repeticiones máximas

El récord propio de ese ejercicio: cuántas repeticiones o cuántos kilos se
llegaron a hacer. Sirve para saber por dónde anda uno al empezar la serie.

---

## Cómo tiene que sentirse

- **Móvil primero.** Esto se usa de pie, en la pista o entre máquinas, con una
  mano y a veces con prisa.
- **Nada que se pulse por debajo de 44 px.**
- Con el mismo aire que las pantallas del panel ya entregadas (entrega 9):
  esos colores y esas tarjetas gustaron.
- Y una cosa de fondo: la app la van a usar chavales de doce años y padres de
  cincuenta. Cuanto menos haya que aprender, mejor.
