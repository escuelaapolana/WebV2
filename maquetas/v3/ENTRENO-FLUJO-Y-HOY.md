# El entreno, de principio a fin · y corrección del navy

Maquetas: `App Apolana entreno flujo.dc.html` (46a-46b) · `App Apolana hoy.dc.html` (45a-45b)
Corrige: `REDISENO-APP.md`

---

## ⚠️ Corrección · el navy a pantalla completa estaba mal

`REDISENO-APP.md` decía «modo trabajo = navy de arriba abajo». **Se retira.** Tres
motivos:

1. **Se lee peor al sol, no mejor.** Lo justifiqué diciendo lo contrario. Navy
   sobre crema da 10,9:1; blanco sobre navy, la mitad. Con luz directa gana el
   texto oscuro sobre fondo claro
2. **El salto es brusco.** Pulsas un botón en crema y aparece una pantalla negra:
   parece que has salido de la app
3. **El modo no lo marca el fondo.** Lo marcan **quitar la barra de pestañas**,
   poner un «Salir» y agrandar los datos

### El patrón correcto: cabecera navy, cuerpo crema
- Franja navy arriba con el contexto (bloque, grupo, hora) y el **«Salir»**
- Cuerpo en crema `#FBF9F4` con tarjetas blancas, como el resto de la app
- **Sin barra de pestañas** — eso es lo que dice «esto es otra cosa»
- Cifras grandes en mono

### Pendiente de aplicar
Tres maquetas anteriores siguen con navy completo y hay que pasarlas a este
patrón: `App Apolana rediseno` 37b (entreno), `Panel Apolana pista` 39a (pasar
lista) y `Natacion Apolana` 25b (calles).

---

## Los tres pasos

### 1 · Al pulsar «Empezar el entreno»
Los cuatro bloques de la sesión, con **el principal abierto y destacado** (borde
azul de 2 px, sombra baja): series, recuperación, ritmo objetivo y la nota del
entrenador en una tira crema. Volumen y duración al final.

Dos botones: **«Apuntar mis tiempos»** (azul) y **«Solo marcar que he entrenado»**
(texto).

### 2 · Apuntando
Cabecera navy: `Bloque 3 de 4 · objetivo 4:15` · `6 × 800` · `3 de 6` · `Salir`.

- **Una fila por repetición.** Hechas con su tiempo en mono a 22 px y la
  diferencia en verde o rojo; la actual con **borde azul y fondo `#F1F7FC`**; las
  que faltan con borde discontinuo y «pendiente»
- **Teclado de 12 teclas** (1-9, `:`, 0, ⌫), el mismo de tests y natación
- Botones: `Saltar` y `Siguiente serie`

### Quién ve el feedback
**Solo atletas de competición y mayores de 13 años.** Un niño de escuela no lo usa:
para él el entreno termina cuando termina, y su asistencia la marca el entrenador
al pasar lista.

- **Menor de 13 o escuela sin competir:** al terminar, solo «Entreno hecho» y vuelta
  a Hoy. Sin RPE, sin nota, sin pantalla de feedback
- **Competición o 13+:** el flujo completo con RPE y nota
- El entrenador puede activarlo por atleta si un chico de 12 ya compite

Esto también decide quién ve «Apuntar mis tiempos»: en escuela, ese botón no
aparece — solo «He entrenado».

### El feedback, para quien lo usa
Cabecera navy con el resumen: media, mejor y volumen.

- **Esfuerzo, RPE del 1 al 10** — rejilla de 5 × 2, teclas de 50 px, la elegida en
  navy. Con las referencias debajo: «1 · muy suave», el valor elegido escrito en
  palabras («7 · duro, pero podía») y «10 · a tope».
  ⚠️ **Sustituye a Fácil / Justo / Duro.** Para los de competición el RPE es el dato
  que sirve, y «justo» no le dice nada al entrenador. Las referencias en los
  extremos permiten que un niño también sepa qué elegir. El mismo RPE se usa en
  natación y en los tests, para poder compararlo
- **Una nota para el entrenador**, opcional
- **Cierre en verde con el reto**: «van 10 días este mes, te faltan 4 para tu reto»
- `Enviar` y **`Dejarlo para luego`**

### 4 · De vuelta en Hoy
La tarjeta pasa a verde: **«Entreno hecho · 3:23 media · Rubén ya lo ha visto»**.
Saber que el entrenador lo ha visto es la mitad del motivo para apuntarlo.

---

## Las cinco reglas del flujo

1. **Apuntar tiempos es opcional.** «Solo marcar que he entrenado» está al lado del
   botón principal. Si obligas a apuntar seis series, la mitad no abre la app en la
   pista
2. **El feedback se puede aplazar.** No se puede saltar sin verlo, pero sí dejarlo
   para luego: queda pendiente en Hoy con un aviso suave. Nadie rellena un
   formulario con el pulso a 160
3. **Siempre hay «Salir»**, en los tres pasos. Sin barra de pestañas y sin salida,
   el atleta queda atrapado en el entreno
4. **Ningún texto por debajo de 4,5:1**, tampoco los índices de serie ni
   «pendiente». `#A79F8E` está retirado del sistema: lo pendiente se distingue por
   el borde discontinuo, no bajando el contraste
5. **La recuperación siempre visible** — `6 × 800 · rec 2'`, en la sesión y en Hoy

---

## Y «Hoy» · `App Apolana hoy.dc.html`

«Inicio» pasa a llamarse **Hoy**, porque es lo único que contiene.

- **Una tarjeta navy y nada más**: el entreno si eres atleta, los hijos si eres
  familia. Todo lo demás en crema
- **«Hoy entrenas» / «Hoy les toca» en ámbar** dentro de la tarjeta: es el ancla
  temporal que faltaba
- **Tres filas de contexto en un solo contenedor** (próxima carrera, última marca,
  rango), no seis tarjetas del mismo peso
- **El aviso de cobro va debajo** de la tarjeta: lo primero al abrir es el entreno,
  no una deuda
- Y una línea con lo que viene, con enlace a la semana

### Las tres barras de cuatro
| Papel | Barra |
|---|---|
| **Atleta** | Hoy · Entrenos · **Marcas** · Más |
| **Familia** | Hoy · Mes · Pagos · Más |
| **Entrenador** | Hoy · Pasar lista · Mi grupo · Más |

- **«Hoy» y «Más» no se mueven nunca.** Solo cambian las dos del medio
- **«Entreno» sale de la barra**: no es un destino, es un modo. Eso libera el sitio
  para bajar a cuatro
- **Marcas se queda** en la del atleta: a los de competición les sirve mucho
- **Quien tiene dos papeles** —entrenador que compite, padre que entrena— los
  cambia desde un selector arriba en «Más». Una cuenta, dos barras

---

## Lo que queda por maquetar

1. La app de la familia completa: Mes, Pagos y Más
2. Panel: Retos, Informes con historial imprimible, fotos de la web, pedidos de
   ropa, tarifas, grupos de entrenamiento, quién entra al panel, importar
3. Pasar a «cabecera navy, cuerpo crema» las tres maquetas que siguen en navy
4. Bajar el ámbar de texto a `#8A5307` en atletas y cobros

## Lo que depende del club
- Veinte fotos con cara y con dorsal, y el recorte vertical del hero para móvil
- Un párrafo por grupo escrito por su entrenador
- ⚠️ Los dos cargadores colgados y los guiones de `/liga/` en producción
