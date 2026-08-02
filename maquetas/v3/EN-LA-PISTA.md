# En la pista · herramienta de campo

Maqueta: `Panel Apolana pista.dc.html` (39a móvil · 39b escritorio)
Antes: `KIT.md`, `CARACTER-Y-PANEL.md`, `REDISENO-APP.md`

Pasar lista con una mano, de pie y con sol. Es **modo trabajo**, así que va en
navy completo (`#22303D`), sin barra de pestañas.

---

## 1 · Pasar lista en el móvil · 39a

### Tres estados, no dos
Es lo único que esta pantalla tiene que resolver: distinguir «he marcado que
falta» de «aún no he llegado a este».

| Estado | Tratamiento |
|---|---|
| **Ha venido** | Fondo `rgba(255,255,255,0.14)` + círculo verde macizo `#3F7A4C` con visto |
| **No ha venido** | Fila atenuada (borde `0.16`, texto `0.62`) + círculo con **cruz** |
| **Sin marcar** | Contorno limpio (borde `0.32`), nombre en blanco, «sin marcar» a la derecha |

**El recuento dice «11 marcados de 14»**, no «9 / 14». Al entrenador le importa
cuántos le quedan por resolver, no cuántos han venido. Y al final de la lista:
«9 atletas más · 3 sin marcar».

### Medidas
- **Filas de 56 px**, más altas que el mínimo de 48 a propósito: se pulsa con el
  pulgar mirando a los críos, no al móvil
- **Toda la fila cambia de estado.** No hay casilla que acertar
- Círculo de estado a 34 px

### Lo que sale en la propia fila
**Lesión y periodo de prueba, en ámbar debajo del nombre.** Son las dos cosas que
un entrenador tiene que saber antes de mandar una serie, y no puede tener que
abrir una ficha para enterarse.

### Un solo grupo abierto
El que toca ahora, con su recuento en ámbar. Los demás plegados con su hora y
«sin empezar». Un entrenador lleva un grupo a la vez.

### Contraste
Ningún texto por debajo de **4,5:1**. Los grises tenues sobre navy van a
`rgba(255,255,255,0.62)` (≈5,4:1). `0.45` medía 4,01:1 y no vale — menos aún en
la pantalla que se usa al sol.

---

## 2 · Ficha del atleta · 39a

A un toque desde la lista.

- **Dos botones grandes** de 56 px: `Ha venido` (verde macizo) / `No ha venido`
- **Asistencia del mes en «7 / 8 · solo faltó el día 2».** Sin porcentajes: a pie
  de pista se necesita el dato, no el análisis. El análisis está en Informes
- **Bloque ámbar si la prueba acaba**: «la prueba acaba el jueves, hay que hablar
  con la familia», con `Se queda` y `Escribir a la familia`
- **Nota del equipo técnico** con su autor y fecha, y aviso explícito de que las
  notas y el contacto de la familia solo los ve el equipo técnico

---

## 3 · En escritorio · 39b

La misma cosa para repasar la semana sentado. Aquí sí es **modo consulta**: crema.

### Rejilla de puntos, cuatro estados
| Punto | Significa |
|---|---|
| Verde macizo | Vino |
| Contorno gris | Faltó |
| Crema relleno | **No contaba** (lesión, o día que no le toca) |
| Contorno discontinuo | **Aún no ha llegado** (periodo de prueba en curso) |

Con leyenda debajo. Columna final con el recuento del mes en mono, en ámbar
cuando baja de la mitad.

### El aviso convierte el dato en acción
Lateral: **«Diego lleva 4 de 8 — ha faltado la mitad del mes sin avisar, conviene
preguntar a la familia antes de que se caiga solo»**, con el botón de escribir.
Para eso sirve mirar la asistencia; una tabla sola no sirve de nada.

Debajo, resumen del grupo (asistencia media, en prueba, lesionados) y enlace al
historial de un atleta, imprimible con membrete.

---

## Reglas que salen de aquí y valen para todo el panel

1. **Tres estados cuando hay tres significados.** Un binario que esconde el
   «pendiente» hace imposible saber si has terminado
2. **El recuento cuenta el trabajo, no el resultado**: «11 marcados de 14», «3
   sin responder», «7 impagados»
3. **Nada de porcentajes en herramientas de campo.** Fracciones y nombres
4. **Todo dato que pida una decisión lleva su acción al lado.** Si el panel
   enseña que Diego falta la mitad del mes y no ofrece escribirle, el dato se
   queda en el panel
