# 10 · La página del atleta, y los estados que faltaban

**Archivo visual:** `Pagina del atleta Apolana.html`. **1a** día con entreno · **1b** día de
descanso con competición cerca · **1c** los cuatro estados que faltaban en las entregas 7, 8 y 9.

---

## La página del atleta

Es la pantalla que más se abre de toda la app, y hasta ahora no tenía maqueta.

**Responde una sola pregunta: qué me toca hoy.** El progreso, las marcas y el historial se
miran de vez en cuando; no compiten con eso.

### Aquí sí van las tarjetas azules en degradado, y solo una

Esta es la pantalla para la que existen. **«Lo que toca hoy» en la tarjeta azul, arriba, y nada
más en azul en toda la pantalla.** Todo lo demás baja a lista. Si hay dos tarjetas azules,
ninguna es la importante.

### Orden de la pantalla

1. **Saludo** — «Hola, Andrés». Una línea, Barlow Condensed 30 px.
2. **La tarjeta azul de hoy** — antetítulo con día y hora, nombre del entreno grande, el plan y
   la sede, y dos botones: **«Apuntar el entreno»** en blanco sólido y **«No voy»** perfilado.
3. **«Esta semana»** — tres líneas, no siete tarjetas. Lo hecho con chip verde, hoy resaltado en
   `#EAF2F9`, lo que viene en texto normal. Los rangos se muestran tal cual («35-45 min»).
4. **La próxima competición** — franja sobre `#F1EADC` de una línea, con la fecha límite de
   inscripción.
5. **Lista de secciones** — Mis marcas · Mi historial · Mi bono de El Cubo (con los usos
   restantes) · Pagos y recibos. Filas de 44 px separadas por línea, con chevron.

### Las tres reglas de esta pantalla

**«No voy» va en la tarjeta, no escondido.** Avisar de una falta es lo segundo que más se hace,
y si cuesta encontrarlo la gente no avisa — que es justo lo que el entrenador necesita saber.

**La competición desplaza al entreno en la tarjeta azul** cuando falta menos de una semana. Es
lo único que gana a «lo que toca hoy». La tarjeta cambia el botón a «Voy a competir» y añade la
hora de quedada. Sigue habiendo **una sola** tarjeta azul.

**El día de descanso se dice, y se dice por qué.** «Hoy descansas · toca descanso antes del
cross». Un hueco sin explicación se lee como que falta el dato. Va en tarjeta de borde
discontinuo, no en azul.

**«Sin apuntar» en ámbar es el único recordatorio**, y vive en la lista de la semana, no como
aviso empujado. Al club le interesa que se apunte; no hasta el punto de dar la lata.

---

## Los cuatro estados que faltaban · 1c

Aplican a las entregas 7 (apuntar entreno), 8 (repartir) y 9 (planificador). Hasta ahora solo
estaba dibujado el caso bueno.

### 1 · Sin plan puesto todavía

Borde discontinuo, «Aún no hay entreno», y **quién lo tiene que poner**: «Nacho todavía no ha
puesto el de hoy. Te avisamos en cuanto lo publique.»

**No es un error y no debe parecerlo.** Es el caso más frecuente a primera hora de la mañana, y
nombrar al entrenador evita la llamada.

### 2 · Falló la consulta

Caja `#FDECEA` con borde `#F6D7D4`: «No hemos podido cargar tu entreno · puede ser la conexión»
y **botón Reintentar** de 44 px.

**Nunca «no hay entreno» cuando lo que ha fallado es la consulta.** Es el mismo bug que ya se
arregló en setenta sitios del panel; la regla vale igual aquí.

### 3 · Se cortó a mitad de un reparto

El caso serio de la entrega 8. Caja ámbar: **«28 de 40 movimientos guardados»**, «los 12 que
faltan siguen aquí y se guardan al recuperar la conexión», y «Reintentar los 12».

**Un reparto de cuarenta niños no puede fallar en bloque.** Cada movimiento se guarda por su
cuenta; si se corta, se dice cuántos van y los pendientes esperan en la pantalla. Nunca «ha
fallado, vuelve a empezar» — eso es lo que hace que se acabe repartiendo en papel.

### 4 · Turno sin niveles cargados

«Sin grupos en este turno» y **el botón que lleva a crearlos**.

**Todo estado vacío lleva su salida.** Si no hay grupos, el botón va a la pantalla que los crea;
no se deja al tesorero buscándola en el menú.

---

## Pendiente del club

- **El texto de la quedada** para competiciones: «quedamos a las 8:45 en el club» sale de un
  campo del panel, no escrito a mano por maqueta.
- **Cuándo se considera «competición cerca»** para que desplace al entreno. Propuesta: siete
  días.
