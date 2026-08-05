# 4 · Avisos y pagos

**Archivo:** `Avisos y pagos Apolana.html`

Dos pantallas de la app, con las decisiones que las ordenan. Todo lo de aquí sigue el
sistema del club: Barlow Condensed y IBM Plex Sans, plano, sin sombras, sin monoespaciada.

---

## A · La pantalla del aviso

### Lo primero: tres niveles

Lo que decide esta pantalla no es la maqueta, es el sistema de niveles. Si «mañana no hay
entreno» y «se suspende la temporada» se ven igual, en dos semanas nadie mira los avisos.

| Nivel | Color de banda | Cuándo se usa |
|---|---|---|
| **Informativo** | `#6E8CA6` sobre `#FBF9F4` | Novedades, crónicas, recordatorios sin fecha límite. La mayoría. |
| **Importante** | `#E08A18` sobre `#FDF6EA` | Cambia tu plan de esta semana: no hay entreno, cambio de sede u hora, cierra un plazo, hay que pagar. **Es el de diario.** |
| **Grave** | `#B3261E` sobre `#FBECEB` | Seguridad y nada más: alerta meteorológica, accidente, suspensión de la actividad. |

**Sobre el `#FBECEB`:** se queda igual, pero solo para «grave». El problema no era el tono,
era que se usaba para todo. Lo que antes iba en rojo ahora va en ámbar.

**El color nunca va solo.** Siempre lleva la palabra —«Importante», «Aviso grave»— porque
una parte de los socios no distingue bien ámbar de rojo.

### El aviso abierto

Estructura, de arriba abajo:

1. Cabecera de navegación: `←` + «Avisos». Alto 54 px, borde inferior `#E4DCCB`.
2. **Banda de cabecera con el color del nivel.** `padding: 22px 20px 20px`, borde inferior
   del color de borde del nivel. Dentro:
   - Chip del nivel: `padding: 5px 11px`, `border-radius: 999px`, fondo del color del
     nivel, texto 12 px 500 con `letter-spacing: 0.04em` en mayúscula. En ámbar el texto va
     en `#141C24`; en rojo, en blanco.
   - Al lado, tipo y grupo: 14 px 400, `#6E6656`.
   - Titular: Barlow Condensed 700, 33px/0.98, uppercase, `#2E4256`.
   - **Fecha y remitente: 14px/1.4, `#6E6656`.**
3. Cuerpo: `padding: 20px`, párrafos en 16px/1.6, `#4A4437`, gap 14 px.
4. Botón de acción si lo hay: alto 50 px, píldora, `#3B85C0`.
5. Meta de envío, separada por `border-top: 1px solid #EFE9DC`: «Enviado a X · N personas».
6. «Anteriores» sobre `#F1EADC`.

**Decisiones y por qué:**

- **No hay tarjeta navy.** El navy es para bloques de una línea; un texto que hay que leer
  entero pide fondo claro.
- **La fecha va arriba**, junto al tipo y el remitente. Es contexto para leer, no un pie de
  página.
- **El aviso grave usa el mismo esqueleto.** Solo cambian el color de la banda y la
  palabra. Si el grave tuviera diseño propio, el ámbar parecería menos importante de lo que
  es.

### El historial

Dos secciones con encabezado: **Sin leer** y **Leídos**. Cada fila:
`padding: 14px 20px`, separadores `1px solid #EFE9DC`, punto de 8 px a la izquierda con
12 px de gap.

| Estado | Punto | Título | Meta | Fondo |
|---|---|---|---|---|
| Sin leer, importante | `#E08A18` | 16 px **600** `#2E4256` | `#6E6656` | `#FDF6EA` |
| Sin leer, informativo | `#6E8CA6` | 16 px **600** `#2E4256` | `#6E6656` | — |
| Leído | sin punto (hueco de 8 px) | 16 px 400 `#4A4437` | `#8C8474` | — |
| Ya pasó | sin punto | 16 px 400 `#8C8474`, **tachado** con `text-decoration-color: #C6BEAE` | `#8C8474`, empieza por «Ya pasó» | — |

**Es el mismo diseño con tres cambios**, no dos tarjetas distintas: punto, peso del título
y fondo si es importante.

**Los que ya no existen no se borran**, se tachan. Borrarlos hace dudar de si lo leíste o
te lo inventaste. Se archivan solos al año, y hay un enlace «Ver los de meses anteriores».

### Lo que hay que resolver fuera del diseño

1. **Quién puede enviar cada nivel.** Si cualquier entrenador puede marcar «grave», el
   nivel se gasta en un mes. Propuesta: informativo e importante, los entrenadores de su
   grupo; grave, solo la junta.
2. **Qué avisos llevan notificación al móvil.** Los informativos no deberían sonar. Si
   suena todo, la gente desactiva las notificaciones y se pierde el canal.
3. **Cuándo caduca un aviso.** Quien lo envía tiene que poner fecha. Sin ese dato, «Ya
   pasó» no se puede calcular y hay que tacharlo a mano.

---

## B · Comprar un bono

Cinco pantallas. La regla que las ordena: **en cada una se ve qué se compra y cuánto
cuesta**, incluida la de error. Nadie llega al banco sin haber visto el total.

### 1 · Elegir

- Estado actual arriba: «Te quedan 2 usos. Caducan el 30 de septiembre.»
- Dos opciones como tarjetas con radio, `border-radius: 14px`, fondo blanco. La
  seleccionada: `border: 2px solid #3B85C0`. La otra: `border: 1px solid #E4DCCB`.
- Cada una lleva **el precio por sesión** debajo del nombre, y la de 20 usos añade
  «ahorras 10 €» en verde `#3F7A4C`. La comparación se hace sola.
- Botón: **«Continuar · 50 €»**. Nunca un «Continuar» a ciegas.
- Letra pequeña: caducidad y dónde se puede usar.

### 2 · Confirmar

Tarjeta blanca con:

| Línea | Estilo |
|---|---|
| Bono de 10 usos | 17 px 500 `#2E4256` · importe 16 px 400 |
| El Cubo · caduca el 3 de agosto de 2027 | 14px/1.4 `#6E6656` |
| Gastos de gestión → **Los paga el club** | etiqueta 15 px 400 `#4A4437` · valor 15 px **500 `#3F7A4C`** |
| **Total** → **50,00 €** | Barlow Condensed 700, 24 px y 30 px, `#2E4256` |

**«Los paga el club» va en verde y sin importe.** Es una buena noticia, no una línea de
factura. El total en Barlow grande, que es la cifra que se mira.

Debajo: quién paga, la nota de Stripe («El club no guarda los datos de tu tarjeta»), botón
**«Pagar 50 €»** y «Cancelar» como texto.

### 3 · La vuelta, pago hecho

Banda navy `#2E4256` con:
- Antetítulo «PAGO HECHO» en `#8FC0E8`, 12 px 500, `letter-spacing: 0.09em`.
- **«Ya tienes 12 usos»** en Barlow Condensed 700, 34px/0.98.
- «Los 10 nuevos y los 2 que te quedaban. Caducan el…»

**No dice «gracias por tu compra»: dice cuántos usos tienes ahora**, sumados a los que
quedaban. Debajo, la acción siguiente real —«Reservar mi próxima sesión»— y «Ver el
recibo». Al final, el historial de pagos sobre `#F1EADC`.

### 4 · El pago falla

- Vuelve a **la misma pantalla de confirmar, con la selección intacta**.
- Arriba, aviso ámbar (`#FDF6EA`, borde izquierdo `#E08A18`, radio 12 px): «El pago no se
  ha completado». Cuerpo: «Tu banco no lo ha autorizado. **No se te ha cobrado nada** y el
  bono sigue sin comprar.»
- Debajo, el resumen otra vez. Botones: «Probar otra vez» y «Escribir a Marta».

**El error es ámbar, no rojo** — misma regla que los avisos. Un pago que falla no es una
emergencia. Y lo primero que se lee es que no se ha cobrado nada, que es el miedo real.

**Si se abandona a medias** (cierra el navegador del banco): exactamente la misma pantalla
con otro texto, «Dejaste el pago sin terminar». Nunca una pantalla en blanco ni volver al
principio.

### 5 · Mientras no haya Stripe

Estado provisional. La pantalla de confirmar con:
- Nota sobre `#F1EADC`: «Todavía no se puede pagar aquí. Estamos terminando de conectar el
  pago con tarjeta. Mientras tanto lo hacemos por transferencia y te cargamos el bono a
  mano.»
- Botón primario: **«Pedir el bono a Marta»** (WhatsApp).
- Botón «Pagar con tarjeta» **visible pero apagado**: borde `#DCD3C0`, texto `#8C8474`.

Se ve pero no funciona, para que se entienda que va a existir. La vía real es la de arriba.
Nada de esconder la pantalla.

---

## Aplicado de las tres respuestas

- **«Running»**, no «Atletismo en ruta». En la portada, el mapa del sitio y el README.
- **Redes: Facebook, TikTok, Instagram y WhatsApp.** Fuera Strava. Son cuatro, así que en
  el pie van en dos filas de dos, no en una fila apretada de cuatro píldoras.
- **Sin monoespaciada.** Los importes van en Barlow Condensed cuando son cifra grande y en
  IBM Plex Sans cuando son línea de lista. Solo vuelve donde los dígitos se comparan en
  columna: parrilla semanal, tarifas y resultados.
