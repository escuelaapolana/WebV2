# Correcciones · pie de página y buzón

Maquetas: `Contraste Apolana.dc.html` (34b, pie correcto) · `Panel Apolana.dc.html` (32c, buzón)

Dos cosas mal implementadas, con la misma raíz: **algo que debía ser una banda o
una lista se ha montado como tarjeta o como tabla.**

---

## 1 · El pie de página está montado al revés

Ahora el navy es **una tarjeta redondeada flotando dentro del crema**, con el
logotipo y los enlaces fuera de ella y media zona vacía a la derecha. Es
exactamente el problema de «todo flota», y en el pie se nota el doble.

**El pie ES la banda.** Todo va dentro del navy, a sangre, sin radio.

```
┌──────────────────────────────────────────────────────────┐
│ #2E4256 · a sangre, de borde a borde, sin esquinas       │
│                                                          │
│ CLUB APOLANA        Club          Contacto      Síguenos │
│ Atletismo, running… Inicio        625 47 38 30  Instagram│
│                     Hazte socio   636 06 17 00  TikTok   │
│                     Calendario    administra…   Facebook │
│                     Noticias                    WhatsApp │
│                     Tienda                               │
│ ──────────────────────────────────────────────────────── │
│ Con la colaboración de   [logo][logo][logo][logo]        │
└──────────────────────────────────────────────────────────┘
```

### Reglas
- **Fondo `#2E4256` a sangre**, `border-radius: 0`. Nada de tarjeta interior
- **Cuatro columnas en una sola rejilla**: identidad · Club · Contacto · Síguenos.
  Ahora hay dos bloques desalineados y una columna vacía
- **La identidad va dentro del navy**, en la primera columna: escudo, nombre en
  Barlow Condensed y la frase de una línea
- **Colaboradores en una fila final**, separada por
  `border-top: 1px solid rgba(255,255,255,0.14)`, logos a 26 px y monocromo
- **Sin fondo `rgba(255,255,255,0.12)` en los iconos** de redes: sobre navy ya
  contrastan. Solo icono + cuenta, alineados
- Texto: `rgba(255,255,255,0.85)` en enlaces, `rgba(255,255,255,0.55)` en rótulos
- **Se pega al CTA navy** que va justo encima, sin crema entre medias, y **sin
  crema debajo**: el pie es lo último de la página

Pie correcto montado en `Contraste Apolana.dc.html`, bloque 34b.

---

## 2 · El buzón no puede ser una tabla

### Qué pasa ahora
La columna «Mensaje» se sale de la tarjeta y se corta a media palabra. La fecha
se parte en dos líneas y el asunto en tres. Una fila ocupa 200 px de alto para
enseñar un tercio del contenido.

### Por qué
Las tablas sirven para datos de longitud parecida: fechas, importes, nombres. Un
texto escrito a mano puede tener 20 o 400 caracteres, y **no hay ancho de columna
que valga para los dos**.

### La regla
**Si una columna contiene texto libre, no es una tabla: es una bandeja.**
Afecta al buzón, a las notas de lesión y a las propuestas de publicación.

### Cómo se monta · bloque 32c

**Sin responder → tarjeta abierta**, borde izquierdo ámbar de 3 px:
- **El asunto es el titular**: Barlow Condensed 21 px mayúsculas
- Fecha **en relativo** a la derecha («31 jul · hace 2 días») — lo que importa es
  cuánto llevas sin contestar
- Nombre y contacto en una línea
- **El mensaje completo**, 15 px, interlineado 1.55. Sin recortar
- Fila de acciones separada por borde: `Responder` (azul) · la plantilla que toca
  según el asunto · `Pasar a la junta` · `Marcar respondido`

**Respondido → fila colapsada de 48 px**: asunto, quién escribió, quién contestó
en verde, fecha y chevron.

**La bandeja se ordena por trabajo pendiente, no por fecha.** Los que necesitan
algo, arriba y abiertos.

### El recuento
`3 sin responder` en ámbar junto al título, y el mismo número en el menú lateral.
Nunca «Buzón (12)» contando los ya resueltos.

---

## Lo mismo, aplicado al resto del panel

Estas dos correcciones son casos de dos reglas del kit que conviene repasar en
las 26 páginas:

1. **Las bandas no llevan radio** y ocupan todo el ancho. Si un bloque oscuro
   tiene esquinas redondeadas y margen, deja de anclar y flota.
2. **Texto libre nunca en columna.** Buzón, lesiones, propuestas de publicación,
   notas de comportamiento y observaciones de test: todas son bandejas o fichas.
