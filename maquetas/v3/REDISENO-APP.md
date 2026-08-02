# Rediseño de la app · pantallas diarias, rangos y medallas

Maquetas: `App Apolana rediseno.dc.html` (37a-37c) · `App Apolana rangos.dc.html` (38a-38b)
Antes: `FUNDAMENTOS.md`, `KIT.md`, `CARACTER-Y-PANEL.md`

---

## La regla que resuelve el móvil

En 402 px no hay ritmo de bandas a sangre. La decisión equivalente es **modo
trabajo frente a modo consulta**.

### Modo trabajo · navy de arriba abajo
Entreno en curso, calles de natación, toma de tests, pasar lista.

- **Fondo navy completo** (`#22303D`), no solo la cabecera
- **Sin barra de pestañas.** «Salir» arriba a la derecha
- Datos grandes, botones de 52 px
- **Regla para decidir:** si estás de pie y con el móvil en una mano, es modo
  trabajo

### Modo consulta · crema con una sola tarjeta navy
Inicio, calendario, marcas, retos, pagos, más.

- Fondo crema y **una única tarjeta navy**: la que lleva la acción del día
- Esa tarjeta es el ancla que en la web era la banda a sangre
- **Nunca dos bloques navy** en una pantalla de consulta: dejan de anclar

---

## 1 · Las tres de cada día · 37b

### Inicio
1. Aviso de recibo en banda ámbar fina (desaparece si está al día)
2. **Tarjeta navy del entreno de hoy** — nombre a 38 px, y tres datos:
   `6×800` · `4:15` · **`rec 2'`**
3. **Fila del rango** con medalla en ámbar y qué te falta para el próximo reto
4. Dos tarjetas: próxima carrera y última marca
5. Resto de la semana, dos filas

### Entreno en curso · modo trabajo
- Navy completo, sin barra de pestañas, «Salir» arriba
- Cabecera del bloque: `Bloque 2 de 4 · principal` + `6 × 800 · rec 2'` + `3 de 6`
- **Una fila por repetición:** hechas con su tiempo y diferencia, la actual con
  borde azul de 2 px y «apuntar el tiempo», las que faltan en discontinuo
- La nota del entrenador al final
- Botones: `Pausa` y `Siguiente serie`

### Marcas · consulta
- Selector Carreras · Tests · Progresión
- **Tarjeta navy con la mejor marca del año** a 42 px en mono
- Tabla por distancia con diferencia en verde
- **«sin marca» en vez de `—`** cuando no hay dato
- Últimas carreras en filas

---

## 2 · Rangos, retos y perfil · 38a-38b

### Mis retos
- **Tarjeta navy** con la medalla del rango, puntos y barra de progreso en ámbar,
  con las dos cotas escritas (`Plata · 150` → `Oro · 300`)
- **Los retos se ordenan por lo que falta menos**, no por fecha ni por puntos
- El primero con **borde ámbar de 2 px**: «Te falta natación · travesía el día 27».
  Convierte el reto en un plan, y es lo que hace volver
- **Todas las barras de reto en ámbar** — el azul es solo para lo pulsable
- Conseguidos, colapsados en filas con visto verde

### Subir de rango · pantalla completa
Solo al subir de rango: **siete veces en la vida de un atleta**. Un reto normal
es una franja arriba que se puede ignorar; si todo interrumpe, nada importa.

- Medalla a 112 px con anillo ámbar
- **Siempre dice por qué**: «llevas 12 competiciones y 74 entrenos» + el reto
  concreto que lo desbloqueó
- **Sin confeti ni animación.** El navy a toda pantalla ya cambia el registro; el
  confeti convierte un logro deportivo en un juego de móvil, y esto lo ven
  adultos de 50 años igual que niños de 8

### Mi perfil
- **El interruptor dice qué ve el otro**, no «perfil público» a secas: «ven tu
  nombre, tu rango y tus medallas; nunca tus marcas, tus pagos ni tus datos»
- **Enlace para verse como te ven** — la única forma de estar seguro
- **Foto y nombre por separado.** Por defecto: nombre abreviado («Nerea V.») y
  sin foto. Quien quiera enseñarla, la enciende

### Perfil visto por otro socio
Cabecera navy con nombre abreviado, sección, antigüedad y el rango en ámbar.
Medallas en rejilla de cuatro con «+4 · ver todas». Retos cumplidos en filas.

**Ni una marca, ni un tiempo, ni un dato de contacto.** Eso convertiría el perfil
en una clasificación encubierta, que es justo lo que dijimos que no queríamos
hacerle a la Liga.

---

## Decisiones que conviene validar

| Decisión | Por qué |
|---|---|
| **Los menores no tienen perfil visible**, ni con permiso familiar | El interruptor no aparece en cuentas de menores. Sus medallas las ven su familia y su entrenador. Es la conservadora y la que no da problemas |
| Por defecto, nombre abreviado y sin foto | Quien quiera enseñarla, la enciende |
| Ni un tiempo en el perfil ajeno | Sería una clasificación encubierta |
| El entreno en curso sin barra de pestañas | De pie en la pista, la barra se pulsa sin querer |

---

## Pendiente en la app

- **Traducir los rótulos** de calles de natación (`Natacion Apolana.dc.html`) y
  tests (`App Apolana tests.dc.html`): están bien resueltos, solo llevan el
  patrón viejo de etiquetas en mayúsculas. ⚠️ **La monoespaciada de las cifras se
  queda** — son datos que se comparan en columna
- Panel del entrenador con la escala nueva
- Calendario de la app (`Calendario Apolana.dc.html` 24b) — traducir rótulos
- Pagos y bonos (`Pagos Apolana.dc.html`) — traducir rótulos
