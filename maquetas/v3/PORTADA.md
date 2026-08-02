# Portada — rehacer la primera pantalla

Maqueta: `Portada Apolana.dc.html` (33a diagnóstico · 33b la portada · 33c los cambios)
Antes: `FUNDAMENTOS.md`, `KIT.md`, `CARACTER-Y-PANEL.md`

---

## El diagnóstico

La portada actual se lee plana, y no es por el contenido: **todo flota**. Cinco
cajas blancas redondeadas del mismo peso sobre el mismo crema, sin una sola masa
oscura que ancle la página. Cuatro problemas concretos:

1. **La foto está encarcelada.** Metida en una caja redondeada con margen por
   los cuatro lados. Una foto de tres atletas saliendo a tope pierde toda su
   fuerza rodeada de aire: parece una ilustración de catálogo.
2. **Media pantalla está vacía.** La tarjeta blanca ocupa la izquierda y a la
   derecha no hay nada hasta que aparecen los tres números flotando en mitad de
   la nada.
3. **Todo pesa lo mismo.** Sin masa oscura, el ojo no sabe dónde parar.
4. **El informativo de arriba manda demasiado.** Una franja azul a todo el ancho
   sobre las clases de agosto, por encima del logotipo.

---

## Los cinco cambios

### 1 · Foto a sangre
Sin margen y **sin esquinas redondeadas**, de borde a borde del navegador.
Alto 430 px. Es el cambio que más se nota: en cuanto rodeas la foto de crema, se
convierte en catálogo.

### 2 · El texto va encima, se elimina la tarjeta blanca
Tapaba a los atletas y dejaba el hueco de la derecha. Velo en diagonal:

```css
background: linear-gradient(96deg,
  rgba(22,31,40,0.90) 0%,
  rgba(22,31,40,0.74) 40%,
  rgba(22,31,40,0.18) 100%);
```

Oscuro donde está el texto, casi limpio a la derecha. **El titular sube a 62 px**
porque ya no compite con una caja.

### 3 · Los números, dentro de la foto
420 · 175 · 38 al pie, sobre una línea fina `rgba(255,255,255,0.2)`. Ahí son la
firma del club, no tres cifras en un hueco. Cifras en mono, rótulos en Plex Sans.

### 4 · Una banda navy que ancla
**«Hoy en el club» deja de ser una caja y pasa a ser una franja navy `#2E4256` a
todo el ancho**, pegada bajo la foto. Da el ritmo que faltaba —oscuro, oscuro,
claro— y convierte el dato más vivo de la web en lo segundo que se ve.

Dentro: título + fecha a la izquierda, separador vertical, dos o tres sesiones
con la hora en `#8FC0E8` (Plex Sans, `tabular-nums` — no mono, son pocas), y
«Ver la semana →» a la derecha.

⚠️ Esta banda es la que hoy está colgada en *«Cargando el día…»*. Al rehacerla,
resolver también el cargador y su estado vacío.

### 5 · El informativo baja
La franja azul superior desaparece. El aviso de agosto va al pie de la foto, en
la misma línea que los números: discreto pero visible. Un informativo no puede
ser lo primero de la portada.

---

## Debajo del pliegue: dos públicos, dos tratamientos

**Para mi hijo o hija** — foto de escuela con degradado y tres chips encima
(Atletismo · Natación · Adaptado). A los padres les convence ver niños
entrenando.

**Para mí** — lista de grupos con nombre, frase y precio. A un adulto le
convence ver el precio y los días.

```
MADRE TIERRA   Empezar a correr sin morir en el intento    40 €
LA TRIBU       Series, tiradas largas y marcas             60 €
EL CUBO        Fuerza y funcional, por bonos             6,20 €
→ Ver los 9 grupos y sus horarios
```

Nombres propios en ámbar `#8A5307`, precios en mono. Así las dos columnas dejan
de ser dos tarjetas iguales.

⚠️ **Las frases son inventadas.** Hay que pedírselas a los entrenadores antes de
publicarlas.

---

## Barra de navegación

Siete entradas + «Pregúntanos» (WhatsApp, verde, solo texto e icono) + «Entrar».
Logotipo compacto con el escudo a 30 px y «Alicante · 1988» debajo en 11 px.

`Entrenar · Escuelas · Horarios · Calendario · Liga · Noticias · Club`

«Liga» en ámbar, porque es nombre propio del club y no una categoría.

---

## Lo que no cambia

El orden de secciones, la jerarquía escuela/adultos, el CTA repetido arriba y
abajo, la paleta y las tipografías. Esto es estructura y peso visual, no un
rediseño.
