# Ocho decisiones y el interruptor de papel

Maqueta: `App Apolana papeles.dc.html` (47a)
Corrige: `KIT.md`, `PANEL-MOVIL-Y-AVISOS.md`, `Retos Apolana.dc.html`, `PORTADA-MOVIL.md`

---

## 1 · ⚠️ El azul de los botones se oscurece · CAMBIO GLOBAL

`#3B85C0` con texto blanco mide **3,96:1** — por debajo del 4,5:1 que fija
`FUNDAMENTOS.md`. Y es el botón principal de las 40 pantallas.

**Decisión: se oscurece el azul, no se toca el texto.**

| Uso | Antes | Ahora |
|---|---|---|
| Botón principal, fondo | `#3B85C0` | **`#2F6FA8`** (5,1:1 con blanco) |
| Enlaces y texto azul | `#2F6FA8` | `#2F6FA8` (sin cambio) |
| Bordes de foco, filetes, barras de gráfica | — | `#3B85C0` **sin texto encima** |

No cambio el tratamiento del texto porque un botón principal con texto oscuro
deja de leerse como botón. Buscar y reemplazar en web, app y panel.

---

## 2 · Avisos: dos cosas que no se pueden hacer

- **«Abrir los ajustes» se elimina del diseño.** Ninguna web puede abrir los
  ajustes del móvil. Era un error mío. Se queda solo la línea escrita
  «Ajustes → Apolana → Notificaciones», que ya estaba en la regla 5
- **El interruptor de correo se aparca.** No monto una infraestructura de envío
  para guardar una preferencia. En su lugar, texto. Cuando haga falta correo para
  los avisos de tesorería, se monta y entonces vuelve el interruptor

---

## 3 · Retos bloqueados: fuera

Dibujé un estado «bloqueado hasta conseguir otro reto» y en la base **un reto no
tiene requisitos previos**. Me inventé un mecanismo que no existe.

Se elimina de `Retos Apolana.dc.html` 29b. Los retos se ordenan por lo que falta
menos y ya está — que es lo que de verdad hace volver.

---

## 4 · Cortes de rango: manda la base

**60 / 550 / 900 / 1400**, no 50 / 500 / 800 / 1200. Ajustar las maquetas 29a y
38a. Los números redondos se leen mejor, pero no merece una migración de datos por
estética.

---

## 5 · Foto de móvil: un hueco extra, solo en la portada

El hero de móvil necesita un recorte vertical con el tercio inferior limpio.

**Segundo hueco de foto solo en `home.hero.movil`.** En las demás cabeceras,
recorte CSS: no merece 28 huecos extra que alguien tiene que rellenar uno a uno.
Si más adelante se ve que alguna cabecera concreta queda mal, se le añade el suyo.

---

## 6 · El Cubo en ámbar, en todos los sitios

Es nombre propio del club, igual que La Tribu y Madre Tierra: va en `#8A5307`
sobre crema. **Se cambia en todos los sitios**, móvil y escritorio — la regla no
puede aplicarse a medias o deja de ser regla.

---

## 7 · Récords y Palmarés con podio

Faltaba, y dejaba tres clasificaciones con podio (Liga, general, categoría) y dos
sin él. **Mismo patrón del tipo 3:** tres tarjetas fuera de la tabla, la primera en
navy con el número en ámbar, y la tabla empezando en el puesto 4.

---

## 8 · Un solo Buzón

**Se queda `/admin/buzon/`.** Fuera el panel duplicado del inicio.

En Inicio queda **solo el aviso con recuento** («3 sin responder» + `Ver`), como
cualquier otro aviso de la bandeja.

**Las solicitudes de inscripción pasan a bandeja**, no tabla: su columna «Interés»
es texto libre, y por la regla de `CORRECCIONES-PIE-Y-BUZON.md` eso nunca va en
columna. Van dentro de `/admin/buzon/` como segunda pestaña de contenido
(`Mensajes · Solicitudes`), no como pantalla aparte.

---

## 9 · Interruptor de papel · maqueta 47a

Andrés es **atleta, entrenador, tesorero y administrador**.

### Franja permanente
Pegada arriba en todas las pantallas, **no se puede cerrar**: un aviso que se
cierra deja de responder «¿en qué papel estoy?» justo cuando hace falta.

`● Estás como atleta` + botón `Cambiar`, altura 34 px.

### El color de la franja identifica el papel
- **Crema `#F1EADC`** — atleta y entrenador
- **Ámbar `#FDF3E3`** — tesorero y administrador, los papeles **con permisos sobre
  otras personas**

El color avisa antes de leer.

### El selector
Cuatro filas, cada una con **lo que tiene pendiente**: «14 por pasar lista», «11
cobros por resolver», «12 avisos · 5 de la Liga». Así se elige por el trabajo y no
por el nombre, y se ve lo de los otros papeles sin entrar.

Debajo: «Al entrar, abrir en» → el último que usé · o uno fijo.

### Administrador y tesorero son papeles distintos
Aunque la persona tenga los dos:
- **Tesorero** — cobros, cuotas, remesas, excepciones
- **Administrador** — contenido, Liga, fotos, personas, grupos

Separarlos evita abrir una pantalla con 32 secciones cuando solo vienes a girar
una remesa.

### No es suplantar
Cambias lo que ves, no quién eres: **todo se guarda a tu nombre**. Dos sitios para
cambiar: la franja (uso diario) y una fila en Mi perfil.

---

## Pendiente

**De diseño:**
1. Cabecera navy + cuerpo crema en las tres maquetas que siguen en navy completo
2. Deslizador de RPE 1-10 en natación y tests
3. Cierre de entreno para escuela, sin feedback (menores de 13 y no competidores)
4. App de la familia: Mes, Pagos y Más
5. Panel: Retos, Informes con historial imprimible, Fotos de la web, Pedidos de
   ropa, Tarifas, Grupos de entrenamiento, Quién entra al panel, Importar,
   Plantillas de email
6. Ámbar de texto a `#8A5307` en atletas y cobros

**Del club:** un párrafo por grupo escrito por su entrenador. Es lo único que
queda de verdad bloqueado — las fotos ya están.
