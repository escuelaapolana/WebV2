# Tesorería, contabilidad y los papeles del club

Guía para el dueño. No hace falta saber nada de informática.

Aquí se explican tres cosas que van juntas:

1. **Quién puede qué** con el dinero del club.
2. **Cómo una misma persona lleva varios papeles** y cambia entre ellos.
3. **Qué falta** para que los avisos salgan también por correo.

---

## 1 · El reparto, en una tabla

| Quién | Qué lleva |
|---|---|
| **Isabel Fuentes** · contable | **Socios y adultos.** Gestiona, gira las remesas y hace las transferencias |
| **Adrián Onandía** · presidente | **Escuela** (y acceso a todo) |
| **Andrés Clavero** · tesorero | **Escuela** (y acceso a todo) |

Y la regla que lo explica todo:

> **Quien decide un importe y quien lo ejecuta no son la misma persona.**
> El panel lo refleja con un aviso entre los dos, no con un permiso que bloquea.

En la práctica:

| Acción | Quién |
|---|---|
| Cambiar una cuota | **Tesorero** (Adrián o Andrés) |
| Aprobar una excepción | **Tesorero** |
| Fijar las tarifas | **Tesorero** |
| Girar la remesa | **Contable** (Isabel) |
| Hacer una transferencia | **Contable** |
| Marcar un recibo cobrado o devuelto | **Contable** |
| Etiquetar a alguien como escuela o socio | Cualquiera de los dos |
| Borrar un recibo | Solo administración |

> ⚠️ **Administrador y tesorero son papeles distintos**, aunque la misma persona
> tenga los dos:
>
> - **Tesorero** → cobros, cuotas, remesas, excepciones
> - **Administrador** → contenido, Liga, fotos, personas, grupos
>
> Se separan a propósito: «evita abrir una pantalla con 32 secciones cuando solo
> vienes a girar una remesa». Cuando entras como tesorero, el menú del panel se
> queda solo con **Dinero**. Para lo demás te pones el de administrador, que es
> un clic.
>
> Con una salvedad, para que nadie se quede fuera: si a alguien **solo** le han
> dado administración, administración le sigue valiendo para el dinero. La
> separación empieza en cuanto tiene los dos papeles.

La **junta** entra al panel pero **no ve el dinero**: ni la bandeja de avisos de
dinero ni el bloque «Dinero» del menú. No es que se le filtre; es que no
aparece.

> ⚠️ **Isabel todavía no tiene cuenta.** El papel de contabilidad está creado y
> **vacío**, esperándola. Hasta que la tenga, Adrián y Andrés siguen haciéndolo
> todo exactamente como hoy: no cambia nada para ellos.

### El día que Isabel tenga cuenta

Cuando se cree su usuario, hay que darle el papel. Es un clic desde el panel, o
esta línea si se hace desde la base:

```sql
select perfil_roles_poner('<el id de Isabel>', array['contabilidad']);
```

A partir de ahí ella entra al panel, ve socios y adultos, gira las remesas… y el
campo de la cuota le sale **de solo lectura**, con un botón para pedir el cambio.

---

## 2 · Una persona, varios papeles

> «Soy tesorero, admin, entrenador y atleta. Soy todo.»

Eso antes no cabía: cada cuenta tenía **un** papel y para probar qué ve un atleta
había que cambiárselo en la base. Ahora cada persona tiene **la lista de papeles
que le han concedido** y elige con cuál está mirando el club.

Andrés tiene los cuatro: **atleta, entrenador, tesorero y administrador**.
Adrián tiene dos: **administrador y tesorero**.

### La franja de arriba

En **todas** las pantallas, panel y portal, hay pegada arriba del todo una franja
de 34 px que dice **`● Estás como atleta`** y trae un botón **`Cambiar`**.

**No se puede cerrar, y es a propósito**: un aviso que se cierra deja de
responder «¿en qué papel estoy?» justo cuando hace falta.

**El color avisa antes de leer:**

| Color de la franja | Papeles |
|---|---|
| **Crema** | atleta, entrenador, familia, junta |
| **Ámbar** | tesorero, administrador, contable, coordinación — los papeles **con permisos sobre otras personas** |

Si solo tienes un papel, la franja no sale: no habría nada que preguntar.

### Cómo se cambia de papel · paso a paso

1. Pulsa **`Cambiar`** en la franja de arriba.
2. Se abre la lista con **tus** papeles. Cada uno dice **lo que tiene
   pendiente** — «14 por pasar lista», «11 cobros por resolver», «12 avisos · 5
   de la Liga» — para que elijas por el trabajo y no por el nombre, y para ver de
   un vistazo lo de los otros papeles sin entrar. El que llevas puesto sale con
   el borde azul y la palabra **Ahora**.
   *Si de alguno no se puede calcular nada, esa fila sale sin recuento. No se
   inventa un número para rellenar.*
3. Pulsa el que quieras. Por ejemplo, **Atleta**.
4. La pantalla se recarga sola y te lleva a la zona de ese papel. **A partir de
   ahí ves exactamente lo que ve un atleta del club**: si intentas entrar al
   panel, te dice que no. No es un fallo: es la prueba.
5. Para volver, el mismo `Cambiar` de la franja.

Debajo de la lista hay **«Al entrar, abrir en»**: puedes dejarlo en *el último
que usé* (lo normal) o fijar uno, y entonces cada vez que entres con tu
contraseña se abrirá en ese.

### El segundo sitio

**Portal › Mi perfil › En qué papel estoy** tiene una fila que abre exactamente
la misma pantalla. Está ahí «para quien lo busque donde se buscan los ajustes».

### Tres cosas que conviene tener claras

- **No es suplantar.** Cambias lo que ves, no quién eres: sigues siendo tú, con
  tu correo y tu contraseña, y **todo se sigue guardando a tu nombre**. Nadie
  puede entrar en la cuenta de otro ni mirar por encima de su hombro.
- **Elegir no concede nada.** En la lista solo salen los papeles que ya te han
  dado. Si alguien intenta ponerse uno que no tiene, la base lo rechaza — se ha
  comprobado a propósito, incluso intentándolo por la vía de atrás.
- **Se recuerda, y se recuerda en el club, no en el navegador.** Si lo cambias en
  el ordenador, el móvil ya está igual. Por eso, si te dejas puesto «Atleta» y al
  día siguiente el panel no te deja entrar, mira la banda de arriba: te está
  diciendo justo eso.

### Repartir papeles

Dar o quitar un papel es **cosa de administración, y solo de administración**. Y
hay un detalle a propósito: **mientras estás actuando como atleta no puedes
repartir papeles**, ni siquiera a ti mismo. Primero vuelves a administración, y
entonces sí. Volver siempre se puede: eso nunca está bloqueado.

---

## 3 · Escuela o socio: se etiqueta, no se adivina

Cada persona lleva **su etiqueta puesta a mano**: escuela o socio. Se pone al dar
de alta la ficha. **No se saca del grupo, ni de la tarifa, ni del año de
nacimiento.**

Es lo que dice **a qué cuenta bancaria va su recibo**: la escuela tiene la suya y
el club (socios y adultos) la otra.

Mientras alguien no tenga etiqueta, el panel dice **«sin etiquetar»**. No se
inventa nada.

### Cómo etiquetar las que ya están

Hoy hay **206 fichas sin etiquetar**. En el inicio del panel sale una fila en la
bandeja:

> **206 fichas sin etiquetar como escuela o socio** · `Etiquetar`

Al pulsar se abre una lista con dos botones por persona, **Escuela** y **Socio**.
Marcas las que quieras y pulsas **Guardar**. Se puede hacer en varias tandas: lo
que ya está guardado no vuelve a salir.

Debajo hay un botón que dice **«Marcar las que se ven según su año»**. Marca de
golpe las que están a la vista usando el año de nacimiento como pista (2009 o
después, escuela). **Marcar no es guardar**: repasas y luego pulsas «Guardar».
La decisión sigue siendo tuya; el año solo ahorra clics.

---

## 4 · Cambiar una cuota

La cuota mensual acordada vive ahora **en la ficha de cada persona**. Antes no
existía: el panel enseñaba el importe del último recibo, que es otra cosa (lo
cobrado, no lo acordado).

### Si eres tesorería (Adrián o Andrés)

1. Abres la ficha del atleta.
2. El campo de la cuota es **editable**.
3. Escribes el importe nuevo y por qué cambia.
4. **Guardas.** A contabilidad le llega un aviso para que lo tenga en cuenta en
   la remesa.

### Si eres contabilidad (Isabel)

1. Abres la ficha del atleta.
2. El campo de la cuota **se ve, pero no se toca**. Debajo hay un botón:
   **«Pedir cambio a tesorería»**.
3. Escribes el importe que debería tener y por qué.
4. A Adrián y a Andrés les llega el aviso.

### Cómo se aprueba

El aviso aparece **en el inicio del panel**, en «Necesita tu atención», con su
acción en la propia fila:

> **Contabilidad pide cambiar la cuota de Nora Cifuentes**
> 40,00 € → 35,00 € · Familia numerosa · `Resolver`

Al pulsar **Resolver** se abre una ventana con lo que hay ahora, lo que piden, el
motivo y un hueco para escribirle una línea a contabilidad. Dos botones:
**Aprobar el cambio** y **Rechazar**.

Si se aprueba, **la cuota cambia de verdad** y le vuelve el aviso a contabilidad.
Si se rechaza, también le vuelve, con tu explicación. El círculo se cierra
siempre.

---

## 5 · «Solo lo mío», en el inicio del panel

El interruptor de la bandeja arranca distinto según quién entra:

| Quién | Cómo arranca | Qué ve |
|---|---|---|
| **Adrián y Andrés** (tesorería) | **Desactivado** | Todo |
| **Isabel** (contabilidad) | **Activado** | Solo dinero, y solo socios y adultos |
| **Junta** | — | El bloque de dinero no aparece |

Lo que no tenga etiqueta se le enseña **a los dos**: más vale que lo mire alguien
de más a que no lo mire nadie.

Cada uno puede cambiarlo cuando quiera, y se le recuerda su elección.

---

## 6 · Por dónde salen los avisos

El club decidió **tres vías**. Dos funcionan y una no.

### ✅ 1 · La bandeja del panel

Funciona. En el inicio, en «Necesita tu atención», y **cada aviso trae su acción
en la propia fila**: no hay que ir a buscarlo a otra pantalla.

### ✅ 2 · El aviso al móvil

Funciona y está encendido en producción. Va por la categoría **«pagos»**, así que
respeta lo que cada uno haya elegido en su ficha. Detalles en
`docs/avisos-al-movil.md`.

Ojo a un detalle: el aviso al móvil se manda **a la persona**, no al papel con el
que esté mirando en ese momento. Si Andrés está probando el club como atleta, el
aviso de tesorería le llega igual.

### ❌ 3 · El correo · **NO EXISTE TODAVÍA**

**El club no manda ni un correo automático.** No hay proveedor de envío ni
función que lo haga. **No se ha montado nada que no funcione**: se ha dejado el
enganche preparado y señalado, y nada más.

Lo que está hecho:

- La tabla de avisos ya tiene las dos casillas donde quedaría el registro:
  `dinero_avisos.correo_en` y `dinero_avisos.correo_error`. Hoy están siempre
  vacías, y así seguirán hasta que se monte.
- En `assets/js/admin-dinero.js` está marcado el sitio exacto, con el comentario
  **«PENDIENTE · CORREO»** y la llamada escrita y comentada.

**Qué haría falta**, por orden, y es un rato de trabajo una sola vez:

1. **Dar de alta un proveedor de envío de correo** (Resend, Postmark, Brevo o
   parecido) y **verificar el dominio del club**. Sin verificar el dominio, los
   correos acaban en spam. Esto no lo puede hacer el programa: hay que entrar en
   el panel del proveedor y en el del dominio.
2. **Guardar su clave como secreto en Supabase**, exactamente igual que se hizo
   con la clave de los avisos al móvil (`docs/avisos-al-movil.md`, paso 2).
3. **Crear la función `correo-enviar`**, con la misma forma que la de los avisos
   al móvil: recibe a quién, el asunto y el texto, y devuelve cuántos salieron.
4. **Descomentar la llamada** que ya está escrita en `admin-dinero.js`.

Hasta que estén los cuatro pasos, el correo **no se anuncia en el panel**. Un
panel que dice «avisado» sin haber avisado a nadie es peor que no tener correo.

---

## 7 · Dónde está cada cosa (por si algún día hay que tocarlo)

| Qué | Dónde |
|---|---|
| Los papeles, los permisos y los avisos de dinero | `migraciones/071_tesoreria.sql` |
| La franja «Estás como …» y el selector | `assets/js/papeles.js` |
| Las ventanas de cuota y de etiquetar | `assets/js/admin-dinero.js` |
| La bandeja del inicio | `admin/index.html` |
| La tarjeta de papeles en el portal | `portal/perfil/index.html` |
| Quién entra al panel | `assets/js/admin-auth.js` |
| Quién entra al portal | `assets/js/portal-auth.js` |
| Los avisos al móvil | `docs/avisos-al-movil.md` |
| El contacto de pagos de cada sección | Panel › tabla `info_pagos` |

### Los nombres técnicos, por si alguien pregunta

- `perfiles.roles` — la lista de papeles concedidos a esa persona.
- `perfiles.rol_activo` — con cuál está actuando ahora. Vacío = el suyo de
  siempre.
- `perfiles.rol` — el papel principal. **No se ha tocado**: todo lo que ya
  funcionaba sigue leyéndolo igual.
- `perfiles.papel_al_entrar` — el papel con el que se abre al entrar. Vacío = el
  último que usé.
- `atletas.tipo_membresia` — la etiqueta: `escuela`, `socio` o vacío.
- `atletas.cuota_mensual` — la cuota acordada.
- `dinero_avisos` — los avisos entre tesorería y contabilidad, en las dos
  direcciones.
