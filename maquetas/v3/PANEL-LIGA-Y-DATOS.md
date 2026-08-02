# Panel · validar la Liga y estadísticas

Maqueta: `Panel Apolana liga y datos.dc.html` (41a validar · 41b estadísticas · 41c reglas)
Antes: `PANEL-ATLETAS-Y-COBROS.md`, `EN-LA-PISTA.md`, `KIT.md`

---

## 1 · Validar pruebas de la Liga · 41a

Sigue el patrón: **lo que pide algo, primero**, con su acción en la fila.

### La clave: la comprobación viene hecha
Cada prueba llega con tres cosas ya verificadas, para que validar sea un clic y
no una investigación:

1. **Si aparece con el nombre del club** en la clasificación oficial (visto verde
   explícito: «Aparece como Club Atletismo Apolana»)
2. **Qué puntos le tocan** según la tabla
3. **Si la distancia cae entre dos tramos** — por reglamento puntúa por la menor

### Tres estados, con el motivo escrito

| Borde | Caso | Acciones |
|---|---|---|
| Verde `#3F7A4C` | Todo correcto | `Validar` · `Rechazar` |
| Ámbar `#B96F09`, fondo `#FDF3E3` | Necesita ajuste de reglamento: «8,4 km puntúa como **5 km**, no como 10» | `Validar` · `Cambiar` |
| Rojo `#B0563A`, fondo `#FBEAE5` | No puntúa: «aparece como **independiente**, no como Club Atletismo Apolana» | `Validar igual` · `Rechazar y avisar` |

Los puntos van a la derecha en mono, y **en el caso ámbar se muestra el valor
corregido** («+8 · como 5 km»), no el que pidió el socio.

### Validar en bloque
Botón en la cabecera: **«Validar las 4 correctas»**. Con tres días de plazo y 184
pruebas en la temporada, revisar una a una no es viable. Solo entran las verdes.

### El plazo, visible
Banda en crema fuerte: «hasta el día 5 de septiembre para pruebas de agosto ·
**quedan 3 días**». El reglamento tiene plazo y el panel tiene que recordarlo.

### Pruebas incompletas
Al final, en una línea: «Y una más de Diego Pastor, pendiente de que mande el
enlace» + `Pedírselo`. No ocupa tarjeta porque no se puede validar.

---

## 2 · Estadísticas · 41b

Lo que hay funciona pero es soso. El cambio de fondo: **cada gráfica lleva por
titular la conclusión, no el nombre del eje.**

| Antes | Ahora |
|---|---|
| «Atletas por temporada» | **«El club crece por la escuela»** |
| «Altas por mes» | **«Septiembre es el mes clave»** |
| «Atletas por categoría» | **«Se van a los 13»** |
| «Ocupación de El Cubo» | **«El Cubo llena por la mañana»** |
| «Ingresos por mes» | **«Los ingresos siguen a las altas»** |

Y debajo de cada una, **una frase que dice qué hacer**:
- «La escuela ha doblado en cuatro años; los adultos están planos.»
- «El 41 % de las altas del año entran en septiembre. Es cuando hay que tener la
  web lista.»
- «De infantil a cadete se pierde casi la mitad. Es donde hay que hacer algo.»
- «Los turnos de tarde van a medias. O se juntan o se promocionan.»

---

## 3 · Reglas para gráficas · 41c

1. **El titular es la conclusión.** Si no sabes qué titular poner, esa gráfica no
   hace falta — y ese es el mejor filtro para decidir qué medir
2. **Una frase debajo con qué hacer.** Verde si es buena noticia, ámbar si hay que
   actuar, gris si es solo contexto
3. **Barras planas, dos tonos.** Sin degradados, sin sombras, sin esquinas
   redondeadas. Navy el dato que importa, azul claro `#C0D9EC` el contexto, ámbar
   `#C98F5A` solo donde hay un problema. Nunca una escala de seis colores
4. **Fracciones antes que porcentajes.** «11 de 12 plazas» dice más que «92 % de
   ocupación». El porcentaje solo cuando *es* la noticia
5. **La cifra siempre al lado de la barra**, en mono y alineada a la derecha. Nada
   de pasar el ratón por encima para saber cuánto mide algo
6. **Sin datos, sin gráfica.** Las primeras temporadas habrá gráficas de dos
   barras: en ese caso, la cifra sola y una línea — «hacen falta tres temporadas
   para que esto diga algo»

---

## Nota de contraste

En este documento el ámbar de **texto** ya va en `#8A5307` (cumple 4,5:1), no en
`#B96F09`. Aplicar el mismo cambio en atletas («4 / 8») y cobros («438 €») según
la deuda anotada en `PANEL-ATLETAS-Y-COBROS.md`.

`#B96F09` se queda solo para **bordes y puntos de estado**, donde no es texto.

---

## Pendiente del panel

- Retos: crear y ver quién cumple, con permisos de menores
- Informes e historial de un atleta, imprimible con membrete
- Fotos de la web (los 80 huecos) y biblioteca de fotos
- Pedidos de ropa · tarifas · grupos · usuarios · importar
- Colaboradores · plantillas de email · récords · palmarés
