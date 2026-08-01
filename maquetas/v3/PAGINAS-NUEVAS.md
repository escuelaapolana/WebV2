# Páginas nuevas — WebV2

Repo: `escuelaapolana/WebV2` · Referencia de diseño: `Web Apolana.dc.html` · Datos: admin

Tres cambios de estructura. Ninguno inventa datos: todo sale de lo que ya
existe en admin. Leer antes `ARREGLOS.md` — los bloqueantes van primero.

---

## Sistema visual (aplica a las tres)

Ya está definido en la web actual. No inventar nada nuevo.

```
Crema fondo      #FBF9F4        Crema bloque     #F1EADC
Blanco tarjeta   #FFFFFF        Borde tarjeta    #EFE9DC
Borde crema      #E4DCCB        Borde chip       #E0D8C8
Azul oscuro      #2E4256        Azul medio       #2F6FA8
Azul acción      #3B85C0        Azul hover       #1E4E78
Texto cuerpo     #5E5849        Texto suave      #6B6558
Texto tenue      #7A7365        Meta             #A79F8E
```

- **Titulares:** Barlow Condensed 700, mayúsculas, `line-height: 0.98`
- **Cuerpo:** IBM Plex Sans, 16 px, `line-height: 1.55`, `text-wrap: pretty`
- **Meta y datos:** JetBrains Mono, 11 px, `letter-spacing: 0.18em`, mayúsculas
- **Cifras y precios:** JetBrains Mono en `#2F6FA8`
- **Tarjetas:** `border-radius: 18px`, `box-shadow: 0 26px 50px -32px rgba(46,66,86,0.35)`
- **Chips:** `border-radius: 999px`, borde `#E0D8C8`, 8 px 14 px

Móvil: comprobar a 375 px. Objetivos táctiles nunca por debajo de 44 px.

---

# 1 · Rehacer el área de socio

**Ruta:** `/socio/` (sustituye la actual) · **Requiere login**

## Problema

Ahora es un listado de historial y pagos: una pantalla de gestoría. Tenemos
datos suficientes en admin para que sea el panel personal del socio.

## Qué muestra

Misma información que ahora, más lo que ya está en admin, pero ordenada por
lo que el socio quiere saber al entrar.

### Cabecera
Nombre, foto si la hay, número de socio en mono, antigüedad ("socio desde 2019").
Fondo crema `#F1EADC`, sin foto de portada.

### Fila de estado — cuatro tarjetas blancas
1. **Cuota** — al día / pendiente. Si hay recibo pendiente, esta tarjeta pasa a
   azul `#2F6FA8` con texto blanco y enlaza a pagos. Si está al día, discreta.
2. **Próxima carrera** — nombre, fecha, dorsal si lo hay. Del calendario de admin.
   Si no hay ninguna inscrita: enlace a calendario.
3. **Mis grupos** — los grupos a los que pertenece, con días en mono.
4. **Marcas del trimestre** — número de marcas nuevas registradas. Enlaza a marcas.

### Bloque "Este mes"
Los próximos entrenos y eventos del socio en lista vertical, máximo seis.
Fecha en mono a la izquierda, evento a la derecha. Es la parte que hace que
el socio vuelva a entrar.

### Familia Apolana
Solo si el socio tiene familiares vinculados. Tarjeta con los miembros del
hogar, el descuento aplicado a cada uno y el total del recibo mensual.

- 2.º miembro: **−10 %** sobre cuota de entrenamiento
- 3.º y siguientes: **−15 %**
- No acumulable · un solo recibo · no aplica a la cuota de socio

### Historial y pagos
Lo que hay ahora, pero **debajo** y plegado por defecto. Es consulta, no lo
primero que se mira. Recibos descargables en PDF.

### Accesos
Fila de enlaces al final: datos personales, cambiar contraseña, dar de baja
un grupo, contacto.

## No hacer
- No duplicar aquí el entreno del día ni el feedback: eso vive en la app.
- No poner gráficas de progresión. La web enseña el número, la app la gráfica.

---

# 2 · Página nueva: El día en el club

**Ruta:** `/horarios/` · **Pública, sin login** · **Entra en el menú principal**

## Por qué

El widget de portada solo enseña hoy. La pregunta más repetida de cualquier
club es "¿a qué hora entrena mi hijo?" y ahora mismo obliga a llamar. Los
datos ya están en admin: es la página más barata de construir y la más útil.

## Qué muestra

### Cabecera
Titular corto. Selector de semana (anterior / actual / siguiente) y un filtro
de chips: todos · escuela · adultos · natación · pista · montaña · El Cubo.
El filtro es lo importante — una familia solo quiere ver su grupo.

### Parrilla semanal
Rejilla de siete columnas (L a D) en escritorio. Cada entreno es una tarjeta
compacta:

- Hora de inicio y fin en mono
- Nombre del grupo en Barlow Condensed
- Instalación (pista, Monte Tossal, El Cubo, sierra)
- Entrenador

Color del borde izquierdo por deporte, sutil, para poder escanear la semana
de un vistazo. Nada de fondos saturados.

**Hoy** va destacado: columna con fondo crema `#F1EADC` y la etiqueta del día
en azul.

### Móvil
La rejilla de siete columnas no funciona a 375 px. En móvil: acordeón por día,
con hoy abierto por defecto y el resto plegados.

### Bloque de instalaciones
Al final, las sedes con dirección y enlace a mapa: pista, piscina del Monte
Tossal, El Cubo, punto de quedada de montaña.

### Cierre
CTA de los 4 días gratis, igual que en portada.

## Datos
Todo desde admin, módulo de grupos. Si un entreno se cancela o cambia de hora
en admin, esta página lo refleja sin tocar código.

Estados vacíos: si un día no tiene entrenos, no dejar la columna en blanco —
poner "Sin entrenos" en texto tenue.

---

# 3 · Campus deja de ser página de menú

**Ruta actual:** `/campus/` · **Nueva ubicación:** sección dentro de `/escuela/`

## Por qué

Es estacional. Nueve meses al año ocupa un sitio en el menú principal sin
tener nada que contar, y el menú de la escuela es donde lo buscan los padres.

## Qué hacer

1. Mover el contenido de campus a una sección dentro de `/escuela/`, con ancla
   propia `#campus` para poder enlazarla desde noticias y redes.
2. Quitar Campus del menú principal.
3. Mantener `/campus/` como redirección a `/escuela/#campus` — habrá enlaces
   antiguos circulando.
4. **Visibilidad por temporada, controlada desde admin:** un interruptor
   `campus_activo` decide si la sección aparece. Fuera de temporada la sección
   no se renderiza.
5. Cuando el campus está activo, sí gana presencia: banner en portada y
   destacado arriba en `/escuela/`. Es un mes al año — que se note.

## No hacer
- No borrar el contenido. Solo cambia de sitio y de visibilidad.

---

## Orden sugerido

1. **El día en el club** — la más útil, la más barata, datos ya en admin.
2. **Campus** — cambio pequeño, libera sitio en el menú.
3. **Área de socio** — la más grande, requiere login y datos personales.
