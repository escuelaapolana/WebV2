# Decisiones cerradas y retos personales

Maquetas afectadas: `App Apolana rangos.dc.html` (38a-38d) · `Pagos Apolana.dc.html`
Antes: `REDISENO-APP.md`, `CARACTER-Y-PANEL.md`

---

## PARTE 1 · Cinco decisiones cerradas

| Decisión | Cerrada así |
|---|---|
| **Retos y Liga** | **Separados.** Los retos son personales, para ver tu propia mejora. Nada público |
| **Comisión de Stripe** | **La paga el club.** El socio ve el precio limpio |
| **Contacto de pagos** | **Todo a Isabel**, la contable. El presidente queda fuera del circuito de dinero |
| **Perfil de menores** | Cuando se encienda: **13 años cumplidos y permiso familiar** revocable |
| **Precio de Montaña** | **No hay, porque no hay entrenador.** Se explica, no se pone «Consultar» |

### Lo que hay que cambiar en la web
**Montaña**, igual que triatlón: en vez de «Consultar», la razón escrita. Algo como
«sin cuota: el grupo sale los fines de semana sin entrenador asignado». «Consultar»
parece un descuido; la razón escrita es honesta y evita la llamada.

### Comisión — cómo queda en pantalla
El desglose se mantiene, pero la segunda línea dice **«Gastos de gestión · los
paga el club»** en verde `#3F7A4C`, y el total es el precio limpio (62,00 €). Es
mejor argumento así: se ve que el club no cobra extra por pagar con tarjeta.

### Retos privados — qué implica
- **El perfil consultable por otros socios se construye pero queda apagado** tras
  un interruptor, igual que la clasificación de la Liga
- El interruptor sigue visible en el perfil, **desactivado**, con una línea: «el
  perfil entre socios llegará más adelante». Así el socio sabe que existe y nadie
  lo enciende por error
- Con esto desaparece la contradicción que había: rangos públicos eran una
  clasificación aunque no hubiera tabla, y solapaban con la Liga
- Nunca foto en cuentas de menores: solo nombre abreviado

### Adrián Onandía Bieco
Presidente y creador de la escuela. Aparece en junta directiva, escuelas y
contenido. **No en cobros.** Donde los documentos anteriores decían «Adriana»
(venía del brief de pagos), poner Isabel si es de dinero y Adrián si es de escuela.

---

## PARTE 2 · Retos que se pone el socio

`/portal/retos/` · **«Mis retos» es UNA sola pantalla**, con dos secciones.

### Estructura de la pantalla
1. **Tarjeta navy con el rango** y barra de progreso en ámbar, con las dos cotas
   escritas (`Plata · 150` → `Oro · 300`)
2. **Del club** — dan puntos, en ámbar, con su icono. Ordenados por lo que falta
   menos, el primero con borde ámbar de 2 px
3. **Míos** — en navy, sin icono y sin puntos, con botón de editar
4. **Conseguidos** — colapsados en filas con visto verde

### Crear un reto · tres toques
1. **Qué contar** — días de entreno · kilómetros · metros a nado · competiciones ·
   desnivel
2. **Cuántos** — campo numérico
3. **Hasta cuándo** — este mes · este trimestre · la temporada

### Las cinco reglas
1. **Los tuyos en navy, los del club en ámbar.** Sin icono y sin puntos los tuyos;
   con icono y «+40» los del club. Se distinguen sin rótulos largos
2. **Sin puntos, a propósito.** Si un reto propio diera puntos, cualquiera se
   pondría «entrenar 1 día» y subiría de rango
3. **Se cuentan solos** con las asistencias, las marcas y los metros que ya están
   en el sistema. **Nada de apuntar a mano:** un reto que hay que ir marcando se
   abandona en dos semanas
4. **El objetivo se propone con el historial** — «el mes pasado hiciste 11, tu
   mejor mes 15». Sin eso la gente pone un número al azar y falla
5. **Máximo tres a la vez**, y se pueden editar o borrar sin dar explicaciones. Un
   reto personal que no se puede quitar deja de ser un reto y pasa a ser un
   reproche

### Qué NO hace
- No da puntos ni sube de rango
- No sale en ningún sitio del club
- No lo ve el entrenador
- No se comparte

---

## Sigue pendiente

- ¿Unifican Liga y Retos? Pendiente del responsable de la Liga. **No bloquea:** con
  los retos personales se puede implementar ya
- Veinte fotos nuevas con cara y con dorsal, y el recorte vertical del hero
- Un párrafo real por grupo, escrito por su entrenador
- ⚠️ Los dos cargadores colgados y los guiones de `/liga/` en producción
- Del panel: Retos en admin, Informes con historial imprimible, fotos de la web,
  pedidos de ropa, tarifas, grupos, usuarios, importar, plantillas, récords
