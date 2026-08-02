# Contraste y tipos de página — Apolana

Maquetas: `Contraste Apolana.dc.html` (34a-34c) · `Tipos de pagina Apolana.dc.html` (35a-35g)
Antes: `FUNDAMENTOS.md`, `KIT.md`, `CARACTER-Y-PANEL.md`, `PORTADA.md`

Lo que había en la portada pasaba en las 28 páginas: **todo flota**. Crema sobre
crema, tarjetas del mismo peso y nada que ancle.

---

# PARTE 1 · La regla del ritmo

Toda página tiene **al menos dos masas oscuras a sangre**: una arriba y una
abajo. Entre ellas, el contenido en crema.

```
navegación (crema, 54-56 px)
BANDA OSCURA          ← cabecera: título + frase + dato duro
contenido (#FBF9F4)
banda #F1EADC         ← filtros, datos duros, sección alterna
contenido (#FBF9F4)
BANDA OSCURA          ← CTA de los 4 días
BANDA OSCURA          ← pie (se tocan, sin crema entre medias)
```

## 1 · Cabecera oscura en todas las interiores
Hoy el título de una interior es texto navy sobre crema y no se distingue de un
título de sección. Pasa a **franja a sangre**: navy si no hay foto, foto con velo
si la hay. Con título, una frase y **el dato que importa** (27 grupos, 34 fotos,
31 participantes).

## 2 · Alternar crema flojo y crema fuerte
Dos secciones seguidas nunca comparten fondo. `#FBF9F4` y `#F1EADC` alternos,
**a sangre y sin radio**: la sección es una banda, no una tarjeta gigante.

## 3 · Cierre oscuro pegado al pie
El CTA de los 4 días en navy a sangre, **tocando** el pie, que también es navy.
Sin crema entre ellas y sin crema debajo.

## 4 · Máximo una tarjeta por sección
Si toda la sección va dentro de una tarjeta blanca redondeada, la tarjeta no
separa nada: quítala. Las tarjetas son para elementos repetidos.

## Seis detalles que quitan blandura · bloque 34c

| Detalle | Regla |
|---|---|
| Bordes de color | **3 px**, no 1. Un filete de 1 px sobre crema no se ve |
| Día y menú activo | Subrayado de **2 px**: `#E4DCCB` normal, navy en hoy/activo |
| Sombras | Se quitan de todo lo que no sea pulsable. **Borde en su lugar** |
| Titular de interior | Barlow Condensed 46 px, interlineado 0.96, **a dos líneas** |
| Cabeceras | **Siempre un dato duro** en cifra grande |
| Bandas | **Nunca radio.** El 14 es solo para tarjetas |

Ejemplo completo aplicado a `/horarios/` en el bloque 34b.

---

# PARTE 2 · Los seis tipos de página

## Tipo 1 · Lanzadera · 35a
**Escuelas · Entrenar · El club · Programas municipales**

Foto a sangre (248 px) con velo diagonal, dato duro en la cabecera, y cuatro
tarjetas con foto, frase y **precio de entrada**. Lo estacional o con nombre
propio, en ámbar.

## Tipo 2 · Grupo o sección · 35b
**La Tribu · Madre Tierra · Pista · Natación · Montaña · Triatlón · El Cubo**

El nombre del grupo **en ámbar a 52 px** es lo único de la cabecera. Debajo, la
**banda de datos duros en crema fuerte**: días, hora, sitio, cuota y el botón de
prueba — es lo que ha venido a buscar quien entra. Después, el texto que convence
(«Cómo es un martes aquí») y la ficha del entrenador.

## Tipo 3 · Clasificación y datos · 35c
**Liga · Récords · Palmarés · Marcas**

**El podio se saca de la tabla**: tres tarjetas, la primera en navy con el número
en ámbar. Sin dorados ni medallas de emoji. La tabla empieza en el puesto 4, solo
con las columnas legibles, y el resto en «clasificación completa».

El `—` es legítimo cuando significa «no ha corrido trail» (gris claro `#C4BCA9`),
nunca cuando significa «falta el dato».

## Tipo 4 · Contenido largo · 35d
**Noticia · Historia · Normativa · Reglamento · Familia Apolana**

El velo va **de abajo arriba** y el titular se apoya en el borde inferior de la
foto: en una noticia el titular pesa más que la imagen.

- Columna de texto **máximo 660 px** — más ancho es ilegible
- Entradilla 18 px, cuerpo 16 px, interlineado 1.6
- Cita con **filete ámbar de 3 px** a la izquierda, 19 px
- Lateral con resultados en datos duros y enlace a la galería de esa carrera

## Tipo 5 · Formulario · 35e
**Inscripción · Hazte socio · Contacto · Acceso**

Cabecera navy **corta** con el paso escrito y tres barras de progreso en ámbar.

- Campo activo con **borde azul de 2 px**
- Lo que se calcula solo (categoría por fecha de nacimiento) en crema y gris
- Chips para elegir, incluida la opción «no lo sé»
- **Lateral con «qué pasa después» en tres pasos** y quién te va a atender: es lo
  que quita el miedo a dar los datos

## Tipo 6 · Galería · 35f
**Galería · Instalaciones · Tienda**

Agrupada **por acontecimiento** con fecha y recuento, no rejilla plana. Las
composiciones **alternan** según cuántas fotos haya: una grande con cuatro
pequeñas, o seis iguales. Al tocar, pantalla completa con flechas y descarga.

---

# PARTE 3 · Lo que sigue mal, y no es de diseño

## 1 · Falta el material que ninguna maqueta puede inventar
Los seis tipos se apoyan en una foto grande a sangre. Hay **siete fotos usables**
en toda la web y una sale tres veces. Hacen falta **veinte fotos nuevas como
mínimo**, con cara y con dorsal. Sin eso, esto se ve igual de plano que antes.

## 2 · Los textos son el 70 % de la identidad y están sin escribir
«Cómo es un martes aquí» está inventado por mí. **Nueve grupos × un párrafo real
de su entrenador.** No lo puede hacer un diseñador ni Claude: media hora con
Rubén y media con Nora. Es la tarea de más valor que queda.

## 3 · Siguen los dos cargadores colgados en producción
Cuarto documento que lo digo: «Hoy en el club» y «Cargando tu panel…», y los
contadores de `/liga/` en cuatro guiones. **Va antes que todo lo de aquí.**

---

## Sobre identidad y sobre que invite a recorrerla

**Identidad no la da una paleta: la dan el vocabulario y las fotos.** «La Tribu»
a 52 px en ámbar sobre una foto de gente sufriendo en la pista *es* identidad. La
misma tarjeta con «Running» y una foto de archivo no lo es, aunque los colores
sean idénticos.

**Se recorre una web cuando cada pantalla deja algo empezado:** el podio que hace
querer ver la tabla, las cuatro fotos que hacen querer ver las 34, «te falta una
disciplina». Eso está montado. Lo que no se puede montar es que haya algo real
detrás de cada enlace.

---

## Orden sugerido

1. Los dos cargadores y los guiones de `/liga/` — antes que todo
2. La regla del ritmo aplicada a las 28 páginas — es mecánico
3. Los seis detalles del bloque 34c — buscar y reemplazar
4. Fotos: veinte nuevas, y quitar las repetidas
5. Textos de grupo con los entrenadores
