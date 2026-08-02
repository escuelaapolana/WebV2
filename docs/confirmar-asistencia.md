# Confirmar asistencia · «¿vas?»

Lo que hasta ahora se preguntaba por WhatsApp —«¿quién va el sábado a Elche?»—
pasa a estar en la app, contado y ordenado. Este documento cuenta qué hace,
cómo se usa y, al final, dónde hay que enganchar el módulo en cada pantalla.

---

## 1 · Qué resuelve

Hoy el club no sabe cuánta gente va a una carrera, a un desplazamiento o a un
entreno especial hasta que aparece. Se pregunta por el grupo de WhatsApp, se
contesta a medias y a la hora de contar plazas de autobús no hay nada fiable.

A partir de ahora, a cualquier actividad que ya esté en el calendario se le
puede colgar una pregunta:

> **¿Vas al desplazamiento a Elche?**
> `Voy` · `No voy` · `Aún no lo sé`

Y el club ve en una pantalla **quién va, quién no y quién falta por contestar**,
con el recuento hecho.

Además, sin coste ninguno:

- **Plazas limitadas.** Pones «20 plazas» (el autobús, tres coches) y cuando se
  llenan, quien diga «voy» entra en **lista de espera**. Si alguien se cae, el
  primero de la cola **sube solo**, sin que nadie tenga que acordarse.
- **Nota corta.** Al contestar se puede escribir una línea: «voy con mi coche,
  llevo 3 sitios», «llego media hora tarde».

---

## 2 · La regla de los menores

**La confirmación de un menor la hace su familia, no él.**

- Si el atleta es **mayor de edad**, contesta él desde su cuenta.
- Si es **menor** y tiene su cuenta de familia enlazada, **solo la familia**
  puede contestar. Aunque el menor entre con su cuenta, los botones le salen
  apagados con el aviso «esto lo contesta tu familia».
- Si es **menor y no tiene familia enlazada**, no puede contestar nadie de casa:
  lo apunta el club desde el panel. Esa pantalla te avisa en ámbar de cuántos
  están en esa situación, para que enlaces la familia en «Atletas».

Esto no es solo un aviso de la pantalla: lo impide la propia base de datos. Un
menor no puede confirmar por sí mismo ni aunque alguien lo intente por otro
camino.

Sin fecha de nacimiento en la ficha no se puede saber si es menor: en ese caso
se le trata como mayor. Otra razón para tener las fichas completas.

---

## 3 · Cómo se usa, paso a paso

### En el panel · «Confirmar asistencia» (`/admin/confirmaciones/`)

1. **Pedir confirmación.** El botón azul de arriba. Eliges:
   - **La actividad** del calendario. Solo salen las que aún no preguntan nada.
     Si falta alguna, créala antes en «Calendario y eventos» o en
     «Competiciones».
   - **La pregunta** («¿Vas al desplazamiento a Elche?»). Si la dejas vacía se
     pregunta «¿Vas?».
   - **El recado**: hora de quedada, dónde se sale, qué hay que llevar.
   - **Hasta cuándo se puede contestar.** Pasada esa hora, la gente ya no puede;
     tú sí sigues pudiendo apuntar respuestas.
   - **Plazas.** Vacío = sin límite. Con número = autobús o coches, con lista de
     espera automática.
   - **A quién se le pregunta:** a todo el club, solo a unos grupos, o solo a
     quien ya está apuntado a esa actividad.
2. **Ver quién va.** En cada fila. Salen las cifras arriba (van · no van · aún
   no lo saben · sin contestar · plazas libres · lista de espera) y debajo la
   lista completa, con filtros: *Van*, *No van*, *Sin contestar*, *Lista de
   espera*.
3. **Apuntar una respuesta a mano.** Última columna de cada fila. Sirve para la
   madre que te lo dice por WhatsApp o para el menor sin familia enlazada. Pasa
   por el mismo sitio que la app: reparte plaza o lista de espera igual.
4. **Sacar la lista.** «Descargar la lista» (un archivo que abre el Excel) o
   «Copiar la lista» (texto para pegar en el WhatsApp del club, agrupado en
   VAN / EN LISTA DE ESPERA / NO VAN / SIN CONTESTAR). Lo que se exporta es lo
   que estés viendo: si tienes puesto el filtro «Van», se exporta solo esa
   parte.
5. **Dejar de preguntar sin borrar.** En «Editar», quita la marca de «Está
   pidiéndose». Las respuestas se quedan guardadas.
6. **Quitar.** Borra la pregunta y sus respuestas. La actividad del calendario
   no se toca. Si se borra la actividad, su confirmación se va con ella.

### En la app · lo que ve la familia o el atleta

Un bloque con la pregunta, el recado, hasta cuándo hay tiempo, cuántas plazas
quedan y tres botones. **Dos toques:** abrir la actividad y pulsar «Voy». Si hay
varios hijos, sale un bloque por hijo, con su nombre.

Si las plazas están llenas, al pulsar «Voy» se avisa de que ha entrado en la
lista de espera.

⚠️ **Un aviso honesto:** la plaza se le da sola en cuanto alguien se cae, pero
**hoy no le llega ningún mensaje al móvil** diciéndoselo: lo ve al volver a
entrar. Por eso el texto dice «vuelve a mirar aquí» y no «te avisamos». El día
que estén los avisos al móvil, este es el primer sitio donde merece la pena
engancharlos.

---

## 4 · Qué falta por hacer (dos cosas, y las dos son de enganchar)

Esta entrega trae la base de datos, el módulo y la pantalla del panel. Como
había compañeros trabajando en casi todas las pantallas, **no se ha tocado
ninguna página existente**. Quedan dos cosas:

### 4.1 · Poner «Confirmar asistencia» en el menú del panel

En `assets/js/admin-tabbar.js`, dentro de la función `bloques()`, en el grupo
**«Actividad»** (donde están Competiciones, Liga, El Cubo…), añadir una línea:

```js
{ txt: 'Confirmar asistencia', url: r + 'confirmaciones/' },
```

Hasta que se haga, la pantalla existe y funciona, pero solo se llega escribiendo
la dirección `/admin/confirmaciones/`.

### 4.2 · Enganchar el módulo en las pantallas del portal

Está explicado en el punto 6, sitio por sitio.

---

## 5 · El módulo, en una línea

Todo lo de la app vive en **`assets/js/confirmaciones.js`**. Se carga así, en
cualquier página que lo necesite (después de `db.js` y del acceso de la zona):

```html
<script src="../assets/js/confirmaciones.js" defer></script>
```

Y se pinta con **una sola llamada**:

```js
APOLANA_CONF.bloque(document.getElementById('donde-va'), { evento_id: '…' });
```

- Si esa actividad **no** pide confirmación, no pinta nada y devuelve `null`:
  la pantalla se queda exactamente igual que estaba. No hace falta preguntar
  antes.
- El módulo se busca solo por quién puede contestar (el propio atleta si es
  mayor, y los hijos), pinta el bloque, guarda, mueve la lista de espera y
  enseña el aviso navy de siempre.
- Trae su propio estilo (13 px en rótulos, radios 14/10/999, zonas de 44 px,
  esqueleto al cargar y error en ámbar) y no hay que añadir CSS en la página.

También está lo demás por si una pantalla quiere pintar lo suyo:

| Llamada | Para qué |
|---|---|
| `APOLANA_CONF.peticion({evento_id})` | la petición de una actividad, o `null` |
| `APOLANA_CONF.peticiones({eventos:[…]})` | varias de golpe, para una lista |
| `APOLANA_CONF.resumen(id)` | recuentos y plazas (cifras, sin nombres) |
| `APOLANA_CONF.lista(id)` | quién va, con nombres · **solo para el club** |
| `APOLANA_CONF.responder(id, atleta, 'voy', nota)` | contestar |
| `APOLANA_CONF.misAtletas()` | por quién puedo contestar |
| `APOLANA_CONF.frase(resumen)` | «12 van · 3 no van · 5 sin contestar» |
| `APOLANA_CONF.csv(filas)` | texto para exportar |

---

## 6 · Dónde se engancha, pantalla por pantalla

En las cinco, primero hay que añadir el `<script>` del punto 5 en la cabecera de
la página (fíjate en el número de `../` según la carpeta).

### 6.1 · Calendario (`portal/calendario/index.html`) — **el sitio principal**

Es donde la gente abre la actividad, así que es donde tiene que estar la
pregunta.

1. En la función `contenidoActividad(a, f)`, justo **antes** de la línea que
   abre el pie (`h += '<div class="modal-pie">';`), añadir el hueco:

   ```js
   h += '<div id="cf-modal"></div>';
   ```

2. En la función `abrirActividad(a)`, después de `abrirModal('modal-act');`,
   añadir:

   ```js
   APOLANA_CONF.bloque('cf-modal', a.compId
     ? { competicion_id: a.compId }
     : { evento_id: a.id });
   ```

   (`a.compId` existe cuando la actividad viene de una competición; si no, `a.id`
   es el identificador del evento del calendario.)

### 6.2 · Inicio del atleta y de la familia (`portal/atleta/index.html`)

Para que el «¿vas?» de lo que viene salga sin buscarlo, en la pantalla de
Inicio. Esa pantalla ya se guarda la próxima competición en la variable
`PROXCOMP` para la tarjeta «Próxima carrera»: se aprovecha esa misma.

1. Un detalle: hoy esa consulta pide `'nombre,sede,fecha_inicio'`. Hay que
   añadirle el identificador → `'id,nombre,sede,fecha_inicio'`.
2. En la función que pinta `#sec-hoy` (busca `var sec=$('sec-hoy')`), al final
   del `html` que se le mete, añadir `'<div id="cf-hoy"></div>'`, y después de
   escribirlo:

   ```js
   if (window.APOLANA_CONF && PROXCOMP) {
     APOLANA_CONF.bloque('cf-hoy', { competicion_id: PROXCOMP.id });
   }
   ```

### 6.3 · Competiciones (`portal/competiciones/index.html`)

Cada competición se pinta como una tarjeta con `id="comp-<identificador>"`.
Dentro de esa tarjeta, al final del `html`, añadir el hueco:

```js
'<div id="cf-' + esc(c.id) + '"></div>'
```

y, cuando la lista ya está pintada, una vuelta por todas (la lista vive en la
variable `COMPS`):

```js
COMPS.forEach(function (c) {
  APOLANA_CONF.bloque('cf-' + c.id, { competicion_id: c.id });
});
```

Aquí se ve claro para qué sirven las dos cosas a la vez: **apuntarse** a una
competición es decir «quiero competir» y se hace en la web de la organización;
**confirmar** es «cuenta conmigo ese día», y es lo que necesita el club para el
autobús.

### 6.4 · Familia (`portal/familia/index.html`)

Esta es la única de las cinco que necesita un poco más, porque la pantalla de la
familia hoy no carga ni competiciones ni eventos: solo entrenos. Dos pasos:

1. En `inicioHTML(hijo, dat)`, al final del texto que devuelve, añadir el hueco
   `'<div id="cf-familia"></div>'`.
2. En `pintar()`, después de la línea `wrap.innerHTML = …`, pedir las preguntas
   que estén abiertas y pintar la primera:

   ```js
   if (window.APOLANA_CONF && SEC === 'inicio') {
     APOLANA_CONF.peticiones({}).then(function (mapa) {
       var abiertas = Object.keys(mapa).map(function (k) { return mapa[k]; })
         .filter(function (p) { return p.abierta && (!p.fecha_limite || new Date(p.fecha_limite) > new Date()); });
       if (abiertas.length) APOLANA_CONF.bloque('cf-familia', { peticion: abiertas[0] });
     });
   }
   ```

El módulo pinta un bloque por hijo con su nombre, así que la madre contesta por
los dos sin cambiar de pantalla.

Si prefieres no tocar esta pantalla, no pasa nada: desde el calendario ya se
puede contestar, y es donde la gente lo va a buscar.

### 6.5 · Entrenador (`portal/entrenador/index.html`)

Aquí no se contesta: se mira. En la función `pintarApuntados()` (la tarjeta
«Quién se ha apuntado»), añadir el recuento de la próxima actividad:

```js
APOLANA_CONF.peticion({ competicion_id: idDeLaCompeticion }).then(function (p) {
  if (!p) return;
  APOLANA_CONF.resumen(p.id).then(function (r) {
    cont.innerHTML += '<p class="vacio">' + APOLANA_CONF.frase(r) + '</p>';
  });
});
```

Y si quiere la lista con nombres, `APOLANA_CONF.lista(id)` le devuelve **solo a
los atletas de sus grupos**. Eso lo decide la base de datos, no la pantalla.

---

## 7 · Quién ve qué (el candado)

| Quién | Qué puede |
|---|---|
| Visitante sin cuenta | **nada**, ni leer |
| Atleta mayor de edad | ve y cambia **su** respuesta |
| Familia | ve y cambia las de **sus hijos** |
| Entrenador y coordinación | ven las de **sus atletas y grupos**, y pueden apuntar respuestas |
| Administración | todo, y es la única que crea o cambia las preguntas |

Se ha comprobado de verdad, entrando en la base de datos como cada uno de ellos:
el visitante sin cuenta recibe «permiso denegado»; un atleta no ve las
respuestas de los demás ni puede quitarse la lista de espera a mano; un
entrenador de natación no ve la lista de un desplazamiento de atletismo; y un
menor no puede confirmar por sí mismo.

---

## 8 · Detalles que conviene saber

- **Una pregunta por actividad.** No se pueden colgar dos «¿vas?» del mismo
  evento.
- **Cambiar de opinión, siempre.** Mientras haya plazo, se puede pasar de «voy»
  a «no voy» y al revés. Al soltar una plaza, sube el primero de la cola en ese
  mismo momento.
- **Fuera de plazo** solo apunta el club. Es a propósito: así el plazo significa
  algo, pero una llamada de última hora sigue pudiendo entrar.
- **Quien no contesta cuenta.** El recuento siempre dice «28 de 35 han
  contestado», nunca solo los que van.
- **Nada se pierde al borrar la pregunta**, salvo las respuestas de esa
  pregunta: la actividad del calendario, las inscripciones y la asistencia de
  los entrenos son cosas distintas y no se tocan.
- **Esto no es pasar lista.** «Confirmar» es antes («¿vendrás?»); «asistencia»
  es el día del entreno, y sigue donde estaba.

---

## 9 · Dónde está cada cosa

| Archivo | Qué es |
|---|---|
| `migraciones/056_confirmaciones.sql` | las dos tablas, los candados y las funciones. Ya aplicada |
| `assets/js/confirmaciones.js` | el módulo: la lógica y el bloque de la app |
| `admin/confirmaciones/index.html` | la pantalla del panel |
| `docs/confirmar-asistencia.md` | esto |
