# Avisos al móvil

Guía para el dueño. No hace falta saber programar. Es **un rato de trabajo, una
sola vez**, y hasta el último paso no le llega nada a nadie.

---

## Qué son y qué resuelven

Hoy el club no tiene forma de avisar de nada. Si mañana no hay entreno por
lluvia, si sale la convocatoria de un cross, si a alguien le vuelve el recibo…
la gente se entera **si entra a mirar**. Y no entra.

Un aviso al móvil es lo mismo que un mensaje de WhatsApp: suena, sale en la
pantalla, se toca y se abre donde toca. La diferencia es que sale de la propia
app del club, va solo a quien le interesa y **no hay que tener el teléfono de
nadie apuntado**.

Ejemplos reales de lo que se podrá mandar:

| Situación | Aviso |
|---|---|
| Llueve y se suspende | **Mañana no hay entreno** · «Por la lluvia se suspende el entreno de mañana martes. El jueves, normal.» |
| Sale una convocatoria | **Ya está la convocatoria del Cross de Alicante** · «Apúntate antes del viernes.» |
| Vuelve un recibo | **Te ha vuelto el recibo de octubre** · «Míralo en la app cuando puedas.» |

**Esto no es un chat.** No se contesta a un aviso. Es corto, se toca y lleva a
la pantalla que corresponde.

---

## Lo que hay que saber antes de nada (las limitaciones de verdad)

Prefiero decirlo aquí arriba y no en letra pequeña:

### 1 · En iPhone y iPad hace falta tener la app instalada

Es una regla de Apple, no del club y no se puede saltar. En Safari a secas
**no llegan avisos por mucho permiso que se dé**. Solo llegan si la persona ha
añadido la web a la pantalla de inicio (el botón de compartir → «Añadir a
pantalla de inicio») y abre la app desde ese icono.

En Android y en el ordenador no hace falta: funciona con el navegador normal,
aunque instalada va mejor.

La app se lo dice a cada uno según el aparato que tenga. Nadie ve un botón que
en su móvil no vaya a funcionar.

### 2 · Si alguien no da permiso, no le llega nada

El móvil pregunta una vez: «¿Apolana quiere enviarte notificaciones?». Quien
diga que no, **no recibirá nada**, y volver atrás obliga a ir a los ajustes del
teléfono a mano. Por eso la app **no pregunta al entrar**: hay que pulsar un
botón que pone «Avisarme». Es a propósito y es lo que más sube el porcentaje de
gente que dice que sí.

### 3 · Llega a los que lo tengan activado, no a todo el club

El primer mes lo tendrá activado poca gente. Va creciendo. En el panel se ve
**a cuántos móviles va a llegar antes de mandar nada**, así que nunca hay
sorpresas.

### 4 · Cada uno elige de qué le avisas

Son cinco interruptores en su ficha:

- Entrenos y cambios de última hora
- Competiciones y convocatorias
- Pagos y recibos
- Noticias del club
- Retos y logros

Vienen **todos encendidos menos las noticias**. Las noticias no son urgentes y
son las que más cansan; quien las quiera, las enciende. Si alguien apaga uno,
no le llegan esos avisos **aunque el aviso vaya a todo el club**. Eso no se
puede saltar desde el panel, y es a propósito: es lo que evita que la gente
acabe apagándolo todo.

### 5 · Un aviso mandado no se puede retirar

Como un mensaje: una vez sale, sale. Por eso el panel enseña **una vista previa
de cómo se verá** y pide confirmación antes de mandarlo.

---

## ¿Y si la persona tiene la app cerrada?

**Le llega igual.** Esa es toda la gracia del asunto.

El aviso no lo entrega la web del club: lo entregan Google (en Android y en
Chrome) y Apple (en iPhone), que son quienes tienen conexión permanente con el
móvil. El móvil despierta un trocito de la app durante un segundo —eso es el
`sw.js`, el «service worker»— solo para pintar el aviso, y se vuelve a dormir.

Traducido a casos:

| Situación de la persona | ¿Le llega? |
|---|---|
| App cerrada, móvil en el bolsillo | **Sí**, suena y sale en la pantalla |
| Móvil apagado o sin cobertura | **Sí, cuando lo encienda**, si no han pasado más de 4 horas |
| App desinstalada | No, y su suscripción se borra sola |
| No dio permiso | No |
| iPhone sin la app instalada | No |

Lo de las cuatro horas es a propósito: un aviso de «hoy no hay entreno» que
llega mañana no vale para nada, y encima molesta.

---

## Qué no ve nadie

Merece la pena saberlo por si alguien pregunta:

- **Ni Google ni Apple leen el texto del aviso.** Va cifrado con una clave que
  solo tiene ese móvil. Para ellos es un churro de bytes que reparten.
- **Ni siquiera un administrador del club puede ver los buzones de los móviles
  de los socios.** La lista de a quién va la calcula la base de datos por
  dentro; desde el panel solo se ve **un número**, nunca los datos.
- El club **no guarda ningún número de teléfono nuevo** por esto.

---

## PASO 1 · Generar las dos claves

Los avisos usan dos claves que van juntas, la **pública** y la **privada**. Se
generan de una vez y no se vuelven a tocar nunca.

La forma más rápida, sin instalar nada, es esta página oficial:

> **https://web-push-codelab.glitch.me/**
> Arriba del todo salen ya generadas una «Public Key» y una «Private Key».
> Pulsa en **Generate Keys** si quieres unas nuevas.

Salen dos churros de letras y números:

- La **pública** empieza por `B` y tiene unas 87 letras.
- La **privada** es más corta, unas 43 letras.

> ⚠️ **La privada es una contraseña.** No se manda por WhatsApp, no se pega en
> un correo y no se escribe en ningún archivo de la web. Solo va al sitio del
> paso 2. Si alguna vez se te escapa, se generan otras dos y se repiten los
> pasos 2 y 3: no se pierde nada, solo hay que volver a ponerlas.
>
> La **pública** no es un secreto: el móvil se la enseña a Google en cada
> suscripción. Esa sí se puede pegar tranquilamente.

Guarda las dos en tu gestor de contraseñas antes de seguir.

---

## PASO 2 · Pegar las claves en Supabase

Aquí es donde vive la privada, y solo aquí.

1. Entra en **supabase.com** con la cuenta del club.
2. Elige el proyecto de Apolana.
3. En el menú de la izquierda: **Edge Functions** → pestaña **Secrets**
   (según la versión puede estar en **Project Settings** → **Edge Functions**
   → **Secrets**).
4. Pulsa **Add new secret** y añade estas tres, una a una:

| Nombre (tal cual, en mayúsculas) | Qué se pega |
|---|---|
| `VAPID_PUBLIC_KEY` | La clave **pública** del paso 1 |
| `VAPID_PRIVATE_KEY` | La clave **privada** del paso 1 |
| `VAPID_SUBJECT` | `mailto:escuelaapolana@gmail.com` |

Y estas dos, opcionales pero recomendables:

| Nombre | Qué se pega |
|---|---|
| `AVISOS_URL_BASE` | La dirección de la web del club, terminada en barra |
| `AVISOS_ORIGENES` | La misma dirección, sin la barra final (para que solo pueda llamar la web del club) |

5. Guarda.

---

## PASO 3 · Desplegar la función que manda los avisos

Es un comando. Se escribe en el Terminal, en la carpeta de la web:

```
supabase functions deploy aviso-enviar --no-verify-jwt
```

Si es la primera vez que usas `supabase` en este ordenador te pedirá entrar
(`supabase login`) y enlazar el proyecto (`supabase link`). Es lo mismo que ya
se hizo para los pagos con tarjeta.

**Este comando hay que volver a lanzarlo cada vez que se toque la función**, y
se ha tocado: ahora también manda los avisos de las peticiones de plaza. Va
junto con la migración `136`; el orden es **primero la migración, después el
despliegue**. Si se hace al revés no se rompe nada, simplemente no sale ningún
aviso hasta que pase la migración.

### Ese `--no-verify-jwt` hay que ponerlo

Antes no hacía falta. Ahora sí, desde que esta misma función manda también los
avisos de las altas y los pedidos.

El motivo: quien avisa de que ha entrado un alta es la web pública, con una
familia rellenando el formulario y **sin ninguna cuenta abierta**. Con ese
filtro puesto, Supabase rechazaría la llamada antes de que llegara a la función
y el aviso no saldría nunca.

**No abre la puerta a nadie.** Ese filtro no era lo que protegía la función: los
avisos que escribe una persona se comprueban dentro, y de forma más estricta
—se pregunta a Supabase si la sesión es de verdad, y a la base si esa persona
puede mandar avisos—. Eso no cambia. Y por el camino nuevo no se acepta ni el
texto del aviso, ni a quién va: solo la palabra que dice qué bandeja ha
recibido algo, y el resto lo decide la base.

Es el mismo caso que `acceso-enlace`, que ya se despliega así por lo mismo
(SETUP-SUPABASE.md): quien pide el enlace para entrar tampoco ha entrado aún.

### Si esto se despliega sin el `--no-verify-jwt`

No se rompe nada y no se pierde ningún alta: siguen llegando y siguen saliendo
en el panel al entrar, en «Necesita tu atención». Lo único que pasa es que no
suena el móvil. Se arregla volviendo a lanzar el comando con el añadido.

---

## PASO 4 · Añadir el trozo al `sw.js`

Este es el único cambio a mano en la web. **El archivo `sw.js` está en la raíz
de la carpeta del proyecto** y lo comparte todo el sitio, así que se añade al
final sin tocar nada de lo que ya hay.

Copia esto **tal cual, al final del archivo**:

```js
/* ============================================================
   AVISOS AL MÓVIL
   ------------------------------------------------------------
   Estos dos trozos son los que hacen que un aviso salga en la
   pantalla aunque la app esté cerrada. El móvil despierta este
   archivo un segundo, pinta el aviso y lo vuelve a dormir.
   Lo manda la función `aviso-enviar` (ver docs/avisos-al-movil.md).
   ============================================================ */

/* 1 · Llega un aviso → se pinta. */
self.addEventListener('push', function (e) {
  var d = {};
  try { d = e.data ? e.data.json() : {}; }
  catch (err) { d = { titulo: 'Club Apolana', cuerpo: e.data ? e.data.text() : '' }; }

  var destino = d.url || (self.registration.scope + 'portal/');

  /* `showNotification` es obligatorio: si llega un aviso y no se
     pinta nada, el navegador acaba retirándole el permiso a la web. */
  e.waitUntil(self.registration.showNotification(d.titulo || 'Club Apolana', {
    body:  d.cuerpo || '',
    icon:  self.registration.scope + 'assets/img/app-icon-192.png',
    badge: self.registration.scope + 'assets/img/app-icon-192.png',
    lang:  'es',
    /* Misma etiqueta = el aviso nuevo sustituye al viejo en vez de
       apilarse. Nadie quiere ocho avisos del club en la pantalla. */
    tag: d.etiqueta || 'apolana',
    renotify: true,
    data: { url: destino }
  }));
});

/* 2 · Se toca el aviso → se abre la app donde toca. */
self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var destino = (e.notification.data && e.notification.data.url) ||
                (self.registration.scope + 'portal/');

  e.waitUntil((async function () {
    /* Si la app ya está abierta, se aprovecha esa ventana: abrir otra
       deja al usuario con dos apps iguales y sin saber cuál es cuál. */
    var abiertas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (var i = 0; i < abiertas.length; i++) {
      var c = abiertas[i];
      if (c.url.indexOf(self.registration.scope) === 0 && 'focus' in c) {
        await c.focus();
        if ('navigate' in c) { try { await c.navigate(destino); } catch (err) { /* da igual */ } }
        return;
      }
    }
    if (self.clients.openWindow) await self.clients.openWindow(destino);
  })());
});
```

Guarda, sube el cambio y listo. Como el `sw.js` va «red primero», el cambio le
llega a la gente la próxima vez que abra la app.

---

## PASO 5 · Encenderlo desde el panel

1. Entra en el panel → **Avisos al móvil** (`/admin/avisos-push/`).
2. Pega la clave **pública** (la del paso 1, la larga) en «Clave pública de los
   avisos» y pon el correo de contacto. **Guardar**.
3. Pulsa **Encender**.

A partir de ese momento:

- En la app aparece el botón **«Avisarme»** para quien pueda usarlo.
- En el panel aparece el formulario para escribir y mandar avisos.

Antes de encenderlo, **nada de esto se ve**. Ni un botón que no funcione.

---

## PASO 6 · La primera prueba

No mandes el primero a todo el club. Hazlo así:

1. En tu propio móvil, abre la app y pulsa **«Avisarme»**. Di que sí.
2. En el panel, elige **A quién → Una persona** y búscate a ti.
3. Escribe algo tonto («Prueba») y mándalo.
4. Bloquea la pantalla del móvil y espera dos segundos.

Si suena, está todo bien. Si no:

| Qué pasa | Qué mirar |
|---|---|
| El panel dice «todavía no está activado» | Falta el paso 2 o el paso 3 |
| El botón «Avisarme» no sale en el móvil | ¿Es un iPhone sin la app instalada? ¿Está encendido en el panel? |
| Dice que se mandó pero no suena | ¿Está el trozo del paso 4 en el `sw.js`? Cierra y abre la app |
| «Le llegará a 0 móviles» | Nadie lo tiene activado todavía, empezando por ti |

---

## Los avisos que salen solos

No todos los avisos los escribe alguien. Hay cuatro que saltan por su cuenta,
sin que nadie toque nada:

| Cuándo salta | Qué dice | A quién |
|---|---|---|
| Entra un alta de la escuela o de socio | «Un alta nueva…» | Administración (y contabilidad, en las de socio) |
| Entra un pedido de ropa | «Un pedido de ropa nuevo» | Administración |
| Alguien pide plaza en una actividad | «Te han pedido plaza» | Quien lleva esa actividad |
| Se contesta a una petición de plaza | «Tienes plaza» / «No ha podido ser» | Quien la pidió **y su familia**, si es menor |

Tres cosas que valen para los cuatro:

- **No llevan ni un dato de nadie.** Ni nombres, ni el de la actividad, ni el
  motivo. Ese texto se queda escrito en la pantalla de bloqueo de un móvil que
  igual está encima de una mesa. El detalle entero está en la app.
- **Uno por bandeja.** Treinta peticiones en una tarde son **un** aviso, no
  treinta. No vuelve a sonar hasta que se conteste lo que hay (o hasta que
  pasen doce horas sin mirarlo).
- **De diez de la noche a ocho de la mañana no suena nada.** Lo que se decida
  de noche espera y sale por la mañana.

Cada uno los puede apagar desde **Avisos al móvil** en la app, y apagar uno no
apaga los demás.

---

## Cómo se le ofrece a la gente

Los avisos no sirven de nada si no los tiene nadie. Por eso, **la primera vez
que alguien entra al portal**, le sale abajo una hoja del club:

> **Que te enteres a tiempo**
> Hola, Marta. Te pedimos que actives los avisos en este móvil. Es la forma de
> enterarte el mismo día:
> · Si se suspende un entrenamiento por la lluvia.
> · Si se cierra la pista por una emergencia.
> · Si pides plaza en un entrenamiento y te contestan.
>
> **[Activar los avisos]**  ·  Ahora no

Los tres ejemplos cambian según lo que haga esa persona en el club: a un
entrenador lo primero que le sale es que alguien está esperando su respuesta.

**Esa hoja NO pide el permiso del móvil.** La ventana del sistema —la de
«¿Apolana quiere enviarte notificaciones?»— solo sale si pulsan **Activar los
avisos**. Es a propósito y es lo importante: la del sistema se pregunta una
vez en la vida, y quien le da a «Bloquear» por reflejo ya no puede volver
atrás desde la web. A la nuestra se le puede decir que no sin perder nada.

Se enseña **una sola vez**. Si dicen que no, o si la cierran sin contestar, no
vuelve a salir. Quien cambie de idea la tiene siempre en **Avisos al móvil**.
Y no se le enseña a quien ya los tiene, a quien los bloqueó en el navegador ni
a quien está en un iPhone sin la app instalada.

---

## Cómo se usa el día a día

En **Panel → Avisos al móvil**:

1. **Título** — lo que se lee gordo. Que se entienda solo: «Mañana no hay
   entreno» dice más que «Información importante».
2. **Texto** — dos líneas. En el móvil no cabe más.
3. **Al tocarlo, lleva a** — la pantalla de la app que corresponda.
4. **De qué es** — entrenos, competiciones, pagos, noticias o retos. Esto
   decide a quién le llega según lo que cada uno haya elegido.
5. **A quién va** — todo el club, un grupo, un papel (atletas, familias,
   entrenadores…) o una persona.
6. Miras **la vista previa** y **a cuántos móviles va a llegar**.
7. **Enviar el aviso**.

Debajo queda el historial: qué se mandó, a quién, cuántos lo recibieron y
cuántos no.

### Tres consejos que valen más que la herramienta

- **Poco y bueno.** Dos o tres avisos por semana como mucho. El club que avisa
  de todo acaba siendo el club que nadie escucha.
- **Al grupo, no a todos.** Que el entreno de velocidad se suspenda no le
  importa a la gente de natación. Mandarlo a todos hace que la próxima vez lo
  apaguen.
- **Escríbelo como se lo dirías a alguien en la pista.** Ni «Estimados socios»
  ni «Se comunica que». «Mañana no hay entreno.»

---

## Preguntas que van a salir

**¿Cuánto cuesta?**
Nada. Ni por mandar ni por recibir. No hay cuota ni límite práctico.

**¿Y si alguien quiere dejar de recibirlos?**
En su ficha de la app, el mismo botón que usó para activarlos. También puede
apagar solo los tipos que no le interesan. Y siempre le queda quitarlo desde
los ajustes del móvil.

**¿Se puede saber quién lo ha leído?**
No, y es mejor así. Se sabe a cuántos móviles se entregó, nada más.

**¿Y si se me escapa un aviso con una falta o mal mandado?**
No se puede retirar. Se manda otro corrigiéndolo. Por eso está la vista previa.

**¿Hay que hacer esto otra vez algún día?**
No. Las claves no caducan. Solo habría que repetir los pasos 1 a 3 si la clave
privada se filtrara.

---

## Dónde está cada cosa (por si algún día hay que tocarlo)

| Qué | Dónde |
|---|---|
| Las tablas, los permisos y las preferencias | `migraciones/054_avisos.sql` |
| Los avisos de las altas y los pedidos, y la regla del ruido | `migraciones/120_que_alguien_se_entere_de_las_altas.sql` |
| Los avisos de las peticiones de plaza | `migraciones/136_que_el_movil_suene_al_pedir_plaza.sql` |
| El botón «Avisarme», la hoja de saludo y las preferencias | `assets/js/avisos.js` |
| Quién enseña la hoja de saludo al entrar | `assets/js/portal-auth.js` |
| Quién lleva los recados que apunta la base | `assets/js/db.js` (`empujarAvisos`) |
| La función que manda los avisos | `supabase/functions/aviso-enviar/index.ts` |
| La pantalla del panel | `admin/avisos-push/index.html` |
| La pantalla de cada uno | `portal/avisos/index.html` |
| Pintar el aviso en el móvil | `sw.js` (el trozo del paso 4) |

**En ninguno de esos archivos hay ni una clave.** La privada vive solo en
Supabase; la pública, en la base de datos, donde la pegas tú desde el panel.
