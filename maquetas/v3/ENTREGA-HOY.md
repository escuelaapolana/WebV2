# Entrega del día — WebV2 + app

Repo: `escuelaapolana/WebV2` · Diseño: los `.dc.html` de este proyecto

Tres documentos anteriores siguen vigentes: `ARREGLOS.md` (bugs y contenido),
`PAGINAS-NUEVAS.md` (horarios, socio, campus) y `ESPECIFICACION.md` (base).
Esto añade lo de hoy.

---

## 1 · Navegación de la app
**Diseño:** `App Apolana navegacion.dc.html` — 22a Inicio, 22b Más, 22c la barra

Hoy hay tres pantallas llamadas Inicio y ninguna manda. Se sustituyen por una.

**Barra inferior, cinco pestañas:** Inicio · Entreno · Calendario · Marcas · Más.
Iconos de línea de 24 px, sin relleno. El activo se distingue por color
(`#2F6FA8`) y peso, no por píldora de fondo. Objetivos táctiles de 48 px.

**Inicio** — solo hoy y lo pendiente:
- Aviso de recibo pendiente arriba (desaparece si está al día)
- Entreno de hoy como bloque azul dominante, con series, ritmo y volumen
- Dos tarjetas: próxima carrera y última marca
- Resto de la semana, máximo dos entradas

**Más** — tres bloques, nunca lista plana:
- El club: noticias (con contador), horarios, galería y tienda
- Mi cuenta: pagos y recibos, Familia Apolana, bonos de El Cubo, mis grupos
- Ayuda: escribir al club, avisos, cerrar sesión

**Se elimina:** los otros dos Inicio, la pestaña de Noticias (baja a Más) y el
acceso suelto a Ajustes desde la barra.

---

## 2 · Batería de tests
**Diseño:** `App Apolana tests.dc.html` — 23a unidades, 23b móvil, 23c web

Se toman en móvil a pie de pista y se leen en la web.

### Tests y unidades
| Test | Unidad | Precisión | Intentos |
|---|---|---|---|
| 30 m lanzado | segundos (s) | 2 decimales | mejor de 2 |
| 30 m parado | segundos (s) | 2 decimales | mejor de 2 |
| 150 m | segundos (s) | 2 decimales | 1 |
| CMJ | centímetros (cm) | 1 decimal | mejor de 3 |
| SJ | centímetros (cm) | 1 decimal | mejor de 3 |
| Abalakov | centímetros (cm) | 1 decimal | mejor de 3 |
| RSI | índice, sin unidad | 2 decimales | serie de 6 o 10 |

**RSI:** saltos continuos. El formato (6 o 10) se elige al empezar el test y se
guarda con el resultado — un RSI de 6 y uno de 10 no se comparan entre sí.

### Índices calculados, nunca tecleados
- Índice elástico: `(CMJ − SJ) / SJ` en %
- Uso de brazos: `(ABK − CMJ) / CMJ` en %
- Velocidad máxima: `30 / t lanzado` en m/s

### Reglas
- La unidad va **siempre pegada al dato**, en la app y en la web.
- Al teclear se muestra el valor anterior y la diferencia, con color:
  verde mejora, rojo empeora. En tiempos menos es mejor; en saltos, más.
- Estado "no asiste" por atleta, distinto de "sin dato".
- Condiciones de la sesión (sede, temperatura, viento) se guardan una vez por
  batería, no por atleta.
- La comparativa es solo dentro del club y por categoría. No se publican datos
  de otros atletas con nombre.

---

## 3 · Calendario
**Diseño:** `Calendario Apolana.dc.html` — 24a web, 24b app (4 pantallas)

Corrige lo que hay publicado en `/calendario/`.

### Web
- **Dos vistas: Mes y Semana.** Se elimina Día.
- **"Filtrar · 2 activos"** en vez de "Filtrar 0", con los filtros aplicados
  visibles como chips y un "Quitar filtros".
- **Los entrenos se colapsan a recuento** ("3 entrenos") y no ocupan celda con
  color. Solo competiciones, eventos del club, cierres de inscripción y El Cubo
  se pintan. Botón "Mostrar entrenos" para desplegarlos.
- **Suscripción a Google Calendar** por grupo (iCal). Es lo que la gente quiere
  de verdad: suscribirse una vez y no volver a entrar.
- Bloque de próximas competiciones al final, con inscripción.

### App
Selector **Agenda · Semana · Mes**:
- **Agenda** (por defecto): lista continua con separador por día, saltando los
  vacíos. Competiciones con borde rojo; cierres de inscripción en ámbar
  avisando de si estás dentro.
- **Semana**: una fila por día con sus entrenos, navegación por flechas.
- **Mes**: rejilla solo con puntos de color, sin texto, y debajo el detalle del
  día seleccionado. La rejilla es para navegar, no para leer.

Filtros: Todo · Competiciones · Lo mío.

**Ficha de competición:** dorsal, cajón, cuántos van del club, salida, hora de
quedada, cómo se reparten los dorsales, y quién más va (avatares).
Botones: añadir a mi calendario, anular inscripción.

### Regla de fondo
Horarios y calendario **no son lo mismo**. Horarios es lo que se repite cada
semana (`/horarios/`); calendario es lo que pasa una vez. Si se mezclan, las
competiciones se pierden entre veinte entrenos al mes.

---

## Pendiente de decisión

- Colapsar los entrenos por defecto en la web: gana legibilidad, pero si la
  gente entra al calendario a mirar entrenos habría que invertirlo.
- Nombre del entrenador visible en horarios públicos: ahora sí aparece.
- Desglose de Familia Apolana visible siempre o plegado: muestra lo que paga
  cada hijo y el ordenador puede ser compartido.

## Sigue pendiente de antes

- Horarios y precios de deporte adaptado y triatlón municipal (septiembre)
- Precios reales de tienda, por la UI de admin
- Fotos de Miguel Á. Pellín y José Fernández
- Repaso de copy placeholder: citas de entrenadores y descripciones de grupo
- "Hoy en el club": confirmar si carga de verdad en un navegador real
