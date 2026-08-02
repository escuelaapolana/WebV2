# Las cuatro bandas, traducidas a móvil

Maqueta: `Movil Apolana revision.dc.html` (43a web · 43b panel)
Antes: `PORTADA-MOVIL.md`, `KIT.md`, `PANEL-ATLETAS-Y-COBROS.md`

Resuelve de una vez los cuatro sitios donde una banda de escritorio no cabe en
402 px, para no decidirlo pantalla por pantalla.

---

## WEB

### 1 · Banda de datos duros de un grupo → 2×2 + botón
`Días · Hora · Dónde · Cuota · botón` en una fila no cabe: «Pista Municipal» se
parte en tres líneas.

En móvil: **rejilla de dos por dos** (días, hora / dónde, cuota) y el botón de
prueba **a ancho completo** debajo. Los días se abrevian: «Mar · jue · sáb».

El hero del grupo baja a **300 px** con velo vertical, y el nombre del grupo a
44 px en ámbar.

### 2 · Parrilla de 7 columnas de horarios → acordeón por día
Nunca desplazamiento horizontal en una parrilla.

- **Hoy abierto** con sus entrenos; el resto plegado con su recuento («3 entrenos»)
- Cada día con **subrayado de 2 px**: navy en hoy, `#E4DCCB` en los demás
- Cada entreno con borde izquierdo de 3 px por deporte, hora en `tabular-nums`

### 3 · Cabecera navy de horarios → tres bloques apilados
Título en dos líneas · los dos datos duros en una fila sobre un filete · botón de
suscripción a ancho completo. En escritorio son dos columnas; en móvil, tres
bloques.

### 4 · Los chips se desplazan, no se parten
Fila con desplazamiento horizontal y `white-space: nowrap`.

⚠️ **Es la única excepción a «nunca desplazamiento horizontal»:** en filtros
funciona porque se ve que hay más a la derecha.

---

## PANEL

### 5 · La fila de aviso → tarjeta
En escritorio el aviso es una fila con su acción a la derecha. En móvil pasa a
**tarjeta**: texto arriba, botones abajo a 44 px. **El borde izquierdo de color se
mantiene** — es lo que ordena la bandeja.

Cuando hay dos acciones: la secundaria con borde y ancho automático, la principal
azul y `flex: 1`.

### 6 · Banda navy de cobros → 2×2
`A girar` + `Recibos` arriba; `Devueltos` + `Sin domiciliar` debajo en ámbar. El
botón entero al final. En una fila, «14.280 €» quedaría a 60 px de ancho.

### 7 · Menú lateral → barra inferior
`Inicio · Pista · Personas · Dinero · Menú`, con los mismos iconos del kit. El
resto de secciones, dentro de «Menú» agrupadas por bloques.

### 8 · Las 26 páginas del panel, cuidadas en móvil
**Decisión del club: todo cuidado.** No hay páginas de segunda. Inicio y En la
pista son las que más se usan, pero las 26 tienen que estar resueltas en 402 px.

Se consigue sin trabajo extra por página aplicando estas cuatro conversiones
mecánicas, que ya cubren todo el panel:

| Elemento de escritorio | En móvil |
|---|---|
| Fila con acción a la derecha | Tarjeta: texto arriba, botones abajo a 44 px |
| Banda de 4 cifras | Rejilla 2×2 + botón a ancho completo |
| Tabla de más de 3 columnas | Una ficha por fila (patrón del kit) |
| Menú lateral | Barra inferior de 5 + «Menú» |

**Y dos reglas más para las páginas de edición** (tarifas, grupos, plantillas,
usuarios, textos):

- **El formulario en ventana emergente pasa a pantalla completa** en móvil, con
  «Cancelar» y «Guardar» fijos abajo. Una ventana flotante en 402 px no deja sitio
- **Campos a una columna**, siempre. Nada de dos campos por fila, ni siquiera los
  cortos: en 402 px un campo de la mitad no admite un IBAN ni una fecha con año

Con eso, cualquier página del panel se traduce sin decidir nada nuevo.

---

## La regla general

**Ninguna banda a sangre se traduce sola.** Si una banda de escritorio lleva más
de tres elementos en fila, en móvil hay que decidir explícitamente:

1. ¿Qué se queda dentro de la banda?
2. ¿Qué baja a su propia banda?
3. ¿Qué se abrevia o se cae?

Y el botón, si lo hay, **siempre a ancho completo y al final**.
