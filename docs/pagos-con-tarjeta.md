# Pagar con tarjeta en la web del club

Guía para el dueño. No hace falta saber programar. Son cuatro ratos de trabajo,
y hasta el último paso **no se cobra ni un euro de verdad**.

---

## Lo primero: qué se cobra con tarjeta y qué no

| | Cómo se paga |
|---|---|
| **Bonos de El Cubo** | Tarjeta ✅ |
| **Licencias federativas** | Tarjeta ✅ |
| **Ropa y equipación** | Tarjeta ✅ |
| **Las cuotas** (escuela, club, secciones) | **Domiciliación bancaria, igual que siempre** ❌ |

Las cuotas se quedan en el banco a propósito: son muchas personas, todos los meses,
y el recibo domiciliado sale mucho más barato que la tarjeta.

**Lo que gana el club:** cuando alguien paga un bono de El Cubo, **los usos se le
añaden al momento**. No hay que mirar el banco, ni apuntarlos a mano, ni que la
persona espere dos días para poder reservar clase.

---

## Cuánto cuesta

Stripe cobra una comisión por cada pago. Con tarjeta europea normal ronda el
**1,5 % + 0,25 €**.

| Se cobra | Comisión aproximada | Le entra al club |
|---|---|---|
| Bono de 55 € | ~1,08 € | ~53,92 € |
| Bono de 95 € | ~1,68 € | ~93,32 € |
| Licencia de 42 € | ~0,88 € | ~41,12 € |

No hay cuota mensual ni alta: si no se cobra nada, no se paga nada.

En el panel hay un interruptor, **«Sumar la comisión de la tarjeta al importe»**:

- **Sin marcar** (recomendado): el club asume la comisión. Del bono de 55 € entran 53,92 €.
- **Marcado**: al bono de 55 € se le suman ~1,08 € y al club le entran los 55 € limpios.

Se puede cambiar de idea cuando se quiera, sin tocar nada más.

---

## PASO 1 · Abrir la cuenta de Stripe

1. Entra en **stripe.com** y crea una cuenta a nombre del club.
2. Te pedirá los datos de la entidad: CIF, dirección, la cuenta bancaria donde
   quieres recibir el dinero y el DNI de quien firma. Es lo normal, es una
   pasarela de pagos.
3. Mientras verifican los datos ya puedes trabajar: Stripe da desde el minuto uno
   un **modo de prueba** con tarjetas de mentira.

> ⚠️ **Nadie del club, ni yo, ni ningún programa, va a meter esos datos por ti.**
> El alta la haces tú, en la web de Stripe, con tus credenciales. Es tu cuenta y
> tu dinero.

---

## PASO 2 · Copiar las dos claves

Stripe da dos claves. Son como las llaves de la caja: **quien las tenga puede
mover dinero**. Por eso no van escritas en la web (que es pública) sino guardadas
en Supabase.

### Clave A · la clave secreta

1. En Stripe, arriba a la derecha, asegúrate de que el interruptor
   **«Modo de prueba» / «Test mode» está ENCENDIDO**.
2. Ve a **Desarrolladores → Claves de API**.
3. Copia la que pone **«Clave secreta»**. Empieza por `sk_test_` mientras estés
   en pruebas y por `sk_live_` cuando pases a real.

### Clave B · la del aviso (webhook)

Esta es la que le sirve al club para saber que un aviso de «ya han pagado» viene
de Stripe de verdad y no de alguien haciéndose pasar por él. Se saca en el paso 5.

> 🚫 **Estas claves no se pegan en un correo, ni en WhatsApp, ni en un chat, ni en
> un archivo de la web.** Solo en el sitio del paso 3. Si alguna se escapa, se
> anula desde Stripe (botón «Roll key») y se genera otra: no pasa nada grave si se
> hace rápido.

---

## PASO 3 · Pegar las claves en Supabase

1. Entra en **supabase.com**, en el proyecto del club.
2. Menú de la izquierda: **Edge Functions → Secrets** (en algunas versiones,
   **Project Settings → Edge Functions → Secrets**).
3. Pulsa **«Add new secret»** y añade estas dos, una a una:

   | Nombre (cópialo tal cual) | Qué se pega |
   |---|---|
   | `STRIPE_SECRET_KEY` | la clave secreta del paso 2 (`sk_test_…`) |
   | `STRIPE_WEBHOOK_SECRET` | la del paso 5 (`whsec_…`) — de momento déjala en blanco |

4. Guarda.

Las otras dos claves que hacen falta (`SUPABASE_URL` y
`SUPABASE_SERVICE_ROLE_KEY`) **las pone Supabase sola**. No hay que tocarlas.

---

## PASO 4 · Subir las dos funciones

Esto es lo único que se hace desde el ordenador con una ventana de comandos.
Es copiar y pegar dos líneas.

```bash
supabase functions deploy pago-crear
supabase functions deploy pago-webhook --no-verify-jwt
```

Detalle importante de la segunda: `--no-verify-jwt` está puesto a propósito.
Esa dirección la llama **Stripe**, no una persona con sesión iniciada, así que no
puede exigir que alguien haya entrado en su cuenta. Su seguridad es otra: la
**firma** del paso 5, que es lo que hace que solo Stripe pueda avisar.

Cuando termine, apunta la dirección que sale de la segunda función. Tiene esta
pinta:

```
https://icaxokjsvhlreuwpyxeb.supabase.co/functions/v1/pago-webhook
```

---

## PASO 5 · Decirle a Stripe dónde avisar

1. En Stripe (con el **modo de prueba encendido**): **Desarrolladores → Webhooks →
   «Añadir endpoint»**.
2. En la dirección, pega la del paso 4.
3. En «eventos a escuchar», marca estos:
   - `checkout.session.completed` ← el importante
   - `checkout.session.expired`
   - `checkout.session.async_payment_succeeded`
   - `checkout.session.async_payment_failed`
   - `charge.refunded`
4. Guarda. Stripe enseñará entonces una clave que empieza por **`whsec_`**.
5. Cópiala y pégala en Supabase en el secreto `STRIPE_WEBHOOK_SECRET` (paso 3).

Con esto ya está montado el circuito completo: alguien paga → Stripe avisa →
la web comprueba la firma → se dan los usos del bono.

---

## PASO 6 · Encenderlo en el panel

1. Entra en el panel: **Panel → Pagos con tarjeta**.
2. Deja el modo en **«Pruebas»**.
3. Pulsa **«Encender»**.
4. Revisa la lista **«Qué se puede pagar»**. Vienen ya los dos bonos de El Cubo
   (10 usos · 55 € y 20 usos · 95 €). Si los precios han cambiado, se corrigen
   ahí. Las licencias y la ropa se añaden con el botón «Añadir».

---

## PASO 7 · Probar sin gastar dinero

Con el modo de prueba, Stripe acepta unas tarjetas inventadas:

| Para probar | Número | Caducidad | CVC |
|---|---|---|---|
| Que el pago **sale bien** | `4242 4242 4242 4242` | cualquiera futura | cualquiera |
| Que el pago **se rechaza** | `4000 0000 0000 0002` | cualquiera futura | cualquiera |

Haz una compra de prueba de un bono. Después comprueba tres cosas:

1. En **Panel → Pagos con tarjeta**, el pago aparece como **«Pagado»** y con la
   etiqueta verde **«usos añadidos»**.
2. En **Panel → El Cubo**, ese atleta tiene los usos nuevos.
3. En Stripe, en **Webhooks**, el aviso sale en verde (200). Si sale en rojo,
   casi siempre es que la clave `whsec_` no es la buena: vuelve al paso 5.

---

## PASO 8 · Pasar a real

Cuando Stripe haya verificado la cuenta y las pruebas vayan bien:

1. En Stripe, **apaga el modo de prueba**.
2. Ve otra vez a **Claves de API** y copia la clave secreta **de verdad**
   (`sk_live_…`).
3. Repite el **paso 5** con el modo de prueba apagado: hay que crear **otro
   webhook** para el modo real, y da **otra** clave `whsec_`.
4. En Supabase, cambia los dos secretos por los nuevos (paso 3).
5. Vuelve a subir las funciones (paso 4) para que cojan las claves nuevas.
6. En el panel, cambia el modo a **«Real»**.
7. Haz **una compra de verdad de un bono, con tu propia tarjeta**, y luego
   devuélvetela desde Stripe. Es la única forma de quedarse tranquilo.

---

## Preguntas que van a salir

**¿Y si alguien paga y no le salen los usos?**
En el panel, ese pago sale con una etiqueta roja: **«usos SIN añadir · revisar»**.
Es raro (pasaría solo si el pago se hizo sin decir de qué atleta era). Se arregla
dando el bono a mano desde **Panel → El Cubo**.

**Stripe manda el mismo aviso dos veces. ¿Se dan los usos dos veces?**
No. Está cerrado por tres sitios distintos, y probado. Un pago puede generar
**un solo bono**, aunque Stripe avise diez veces.

**¿Alguien puede comprarse un bono por un céntimo trasteando la web?**
No. El precio nunca lo dice el navegador: la web solo manda *qué* se quiere
pagar, y el importe lo pone el servidor leyéndolo de la base de datos.

**¿Los números de tarjeta pasan por la web del club?**
No, nunca. Se teclean en la página de Stripe. El club no ve ni guarda ninguno,
que es justo lo que evita muchos problemas legales.

**¿Se puede devolver un pago?**
Sí, desde Stripe (botón «Refund»). En el panel del club el pago pasará solo a
«Devuelto». **Los usos del bono no se quitan solos** a propósito: puede que ya se
hayan gastado, así que esa decisión la toma el club a mano.

**¿Y si quiero apagarlo todo un tiempo?**
Panel → Pagos con tarjeta → **Apagar**. Al momento dejan de salir los botones de
pagar en toda la web. Los pagos ya cobrados no se tocan.

**¿Dónde veo el dinero?**
En Stripe. Lo va enviando a la cuenta del club cada pocos días, en un solo
ingreso que agrupa varios pagos.

---

## Recordatorio de seguridad

- Las claves **solo** viven en los secretos de Supabase.
- En el repositorio de la web **no hay ni puede haber ninguna clave**: es público.
- Nadie del club necesita las claves para el día a día. Solo para configurarlas
  una vez, y para renovarlas si alguna se escapa.
- Si sospechas que una clave se ha filtrado: Stripe → Claves de API → **«Roll
  key»**, y repite los pasos 3 y 4. Tarda cinco minutos.

---

## Para quien tenga que tocarlo por dentro

| Pieza | Dónde está |
|---|---|
| Tablas, reglas y candados | `migraciones/053_pagos_tarjeta.sql` |
| Crear la sesión de pago | `supabase/functions/pago-crear/index.ts` |
| Recibir el aviso de Stripe | `supabase/functions/pago-webhook/index.ts` |
| Módulo para las pantallas | `assets/js/pago-tarjeta.js` |
| Pantalla del panel | `admin/pagos-online/index.html` |

Variables de entorno que usan las funciones:

| Nombre | Quién la pone |
|---|---|
| `STRIPE_SECRET_KEY` | el club (paso 3) |
| `STRIPE_WEBHOOK_SECRET` | el club (paso 5) |
| `SUPABASE_URL` | Supabase, sola |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase, sola |
| `SUPABASE_ANON_KEY` | Supabase, sola |
| `PAGOS_URL_BASE`, `PAGOS_URL_OK`, `PAGOS_URL_KO` | opcionales: a dónde vuelve la persona al terminar |

Enganchar un botón de pagar en cualquier pantalla:

```html
<script src="../../assets/js/pago-tarjeta.js" defer></script>
```

```js
// Si está apagado, el botón se esconde solo. Nada de botones muertos.
APOLANA_PAGO.prepararBoton(document.getElementById('btn-bono'), {
  tipo: 'bono-cubo-10',
  atleta_id: idDelAtleta
});
```
