# Petición al maquetador · El planificador del entrenador

Dos encargos sobre la misma pantalla, `portal/entrenador/`. El primero es una
revisión de algo ya entregado; el segundo, una pantalla que nunca se diseñó.

---

## 1 · Planificar semana · **lo más importante**

**Esta es la pantalla que más se va a usar de todo el proyecto.** Un entrenador
entra aquí cada semana, en temporada, para montar lo que harán sus grupos.

La entregaste en la **entrega 9, sección 0a**, y está aplicada. Pero al usarla
de verdad, el tesorero dice que **sigue resultando tosca**, y él es entrenador
además de tesorero.

**No te pedimos que la rehagas a ciegas.** Te pedimos que la mires con el
resultado delante, porque puede que el problema no esté en el diseño sino en
cómo se aplicó — o puede que sobre el papel funcionara y en la mano no.

Lo que hay ahora, para que sepas qué mirar:

- Rejilla de días: tres columnas en escritorio, una en móvil.
- Cabecera con la línea de cifras y la acción principal.
- Una sola fila de mandos: `← 27 jul – 2 ago →`, el grupo, y «Copiar de otra semana».
- Cada día es una tarjeta: cabecera crema, título, chips, resumen, y un pie con
  el estado y «Abrir».
- El día vacío se ve vacío: borde discontinuo, «Sin entreno puesto»,
  «Planificar este día».
- Banda ámbar: «El borrador del miércoles no lo ve la familia hasta que lo
  publiques».

**Cosas del club que condicionan esta pantalla y conviene tener delante:**

- **Se reutiliza muchísimo.** Dicho por él: *«a lo mejor yo quiero hacer un
  lunes cuatro por cien y el lunes siguiente cinco por cien»*. Partir de lo del
  lunes pasado y cambiar un número es el gesto más frecuente, no la excepción.
- **Un entrenamiento tiene dos ejes independientes**: el **deporte**
  (atletismo, natación, fuerza, El Cubo — hasta dos el mismo día) y el **papel
  del día** (ajuste, carga, impacto, recuperación, activación, tapering,
  competición, descanso, rehabilitador). Son dos cosas distintas y las dos
  importan.
- **Un entrenador lleva varios grupos** y salta entre ellos constantemente.
- **Se usa desde el móvil**, muchas veces de pie en la pista.

---

## 2 · El calendario del entrenador · **no existe ninguna maqueta**

Se construyó sin diseño, porque no había. Lo que hay ahora es una interpretación
de algo que dijo el tesorero sobre el calendario de la web —*«se ve en grande, y
si pincho en un día se me abre ese día»*— aplicado aquí a ojo.

Hay dos detalles que quien lo construyó **se tuvo que inventar** y lo dejó
dicho:

- **La leyenda de los puntos del mes** (publicado · borrador · competición).
- Cómo se distingue un día con entreno de uno sin él.

**Qué tiene que resolver:** que el entrenador vea de un vistazo qué hay por
delante en sus grupos —entrenamientos publicados, borradores sin publicar,
competiciones— y pueda abrir un día.

**Ojo con un detalle del club**: el verde y el ámbar ya significan cosas
concretas en esta app («bien» y «ojo»), así que los puntos del calendario no
deberían competir con eso.

---

## Lo que vale para las dos

- **Móvil primero.** Todo lo que se pulsa, **44 px**.
- Las piezas comunes ya entregadas y los colores y tarjetas de la entrega 9,
  que gustaron mucho: *«me encantan estos colores y tarjetas»*.
- **Sin aire de aplicación de empresa.** Esto lo usa gente que entrena a niños
  por las tardes, no una oficina.
