# Navegación del panel en móvil, avisos y nombres

Maqueta: `Panel movil y avisos.dc.html` (44a navegación · 44b avisos · 44c nombres)
Antes: `MOVIL-LAS-CUATRO-BANDAS.md`, `REDISENO-APP.md`, `KIT.md`

---

## 1 · El panel tiene dos menús en móvil: se queda uno

### La decisión
**La barra lateral no existe por debajo de 900 px.** No se colapsa, no se esconde
en un cajón, no se convierte en acordeón: desaparece. En móvil la única
navegación es la barra de cinco pestañas de abajo.

En escritorio vuelve la lateral y la barra desaparece. **Son la misma navegación
en dos formatos, nunca las dos a la vez.**

### Los botones que cambian de panel no son navegación
`#noticias`, `#avisos`, `#buzon` no navegan: cambian un panel dentro de la misma
página. **Eso no es menú, son pestañas de contenido.**

Salen de la lateral y pasan a ser **chips en la banda de filtros** de su página,
igual que Mes/Semana en el calendario. Efecto secundario bueno: el menú pierde
tres entradas y solo contiene destinos reales.

### La barra de cinco
`Inicio · Pista · Personas · Dinero · Menú`

Las cuatro primeras son las de uso diario. «Menú» es el cajón del resto.

### «Menú», en tres capas
1. **Buscador** arriba
2. **«Las que más usas»** — cuatro atajos calculados con lo que abre esa persona,
   en rejilla de dos. Es lo que evita desplegar bloques: en la práctica cada uno
   usa cinco o seis pantallas de las 32
3. **«Todo, por bloques»** — Personas, Dinero, Actividad, La web, Club, con el
   recuento al lado y plegados

---

## 2 · El buscador sale del menú

**Va en la cabecera navy de todas las páginas del panel**, siempre visible.
Enterrado dentro de «Menú» está a dos toques; en la cabecera está a uno.

Y busca **pantallas y personas a la vez**: con 32 pantallas y 420 atletas es el
camino más corto para todo.

- Filtra mientras se escribe
- Entiende sinónimos: «notificaciones» → Avisos al móvil; «banco» o «impagados» →
  Cobros y recibos
- **Cada resultado muestra su bloque debajo** («Actividad · notificaciones que se
  envían»), que es lo que evita confundir dos pantallas de nombre parecido

---

## 3 · Avisos del socio · `/portal/avisos/`

El permiso de notificaciones **se pide una vez en la vida**. Si dicen que no, no
hay vuelta atrás sin ir a los ajustes del teléfono. Esta pantalla existe para
merecer ese sí antes de pedirlo.

### Las cinco reglas

1. **Nunca al abrir la app por primera vez.** Se pide cuando el socio ya ha visto
   para qué sirve: después de su primer entreno, o al inscribirse en una carrera
2. **Primero elige, después se pide.** Los interruptores van **antes** del botón.
   Quien llega a «Activar los avisos» ya ha decidido qué quiere, así que el
   diálogo del sistema sale cuando ya ha dicho sí de hecho
3. **Cada aviso dice su frecuencia** — «solo si algo sale mal», «como mucho una a
   la semana». Lo que da miedo no es el aviso: es no saber cuántos van a llegar
4. **«Ahora no», no «No, gracias».** Sin culpa y sin letra pequeña. Y no se vuelve
   a preguntar solo: la pantalla se queda disponible en Más
5. **Si está bloqueado en el teléfono:** se explica en una línea dónde se arregla
   (Ajustes → Apolana → Notificaciones), se ofrece la alternativa **por correo**, y
   **los avisos quedan siempre en esta pantalla** aunque no se reciban

### Los cinco tipos y su valor por defecto
| Aviso | Frecuencia | Por defecto |
|---|---|---|
| Cambios en mi entreno | Cancelaciones y cambios de hora | **Activado** |
| Competiciones | Cuando cierra una inscripción | **Activado** |
| Pagos | Solo si algo sale mal | **Activado** |
| Noticias del club | Como mucho una a la semana | Apagado |
| Mis retos | Cuando consigues uno | Apagado |

### La cabecera navy explica el trato
«Te avisamos de lo que no te puedes perder: si se cancela un entreno por lluvia,
si cierra la inscripción de una carrera o si hay un recibo devuelto. Nada más.»

Concreto y con límite. «Recibe notificaciones del club» no dice nada.

---

## 4 · Los nombres que se confunden

| Antes | Ahora | Por qué |
|---|---|---|
| ~~Avisos de portada~~ | **Franja informativa** | Es la franja de la portada. Describe lo que es y no comparte palabra con lo otro |
| Avisos al móvil | **Avisos al móvil** (se queda) | «Notificaciones» es la palabra técnica; «avisos al móvil» lo entiende una madre de 50 años |
| ~~Grupos~~ | **Grupos de entrenamiento** | Se confunde con grupos de usuarios del panel |
| ~~Usuarios~~ | **Quién entra al panel** | Dice qué es sin jerga |
| ~~Adriana~~ | **Adrián Onandía** | Presidente y creador de la escuela |

### La regla para no repetirlo
**Dos pantallas del panel no pueden compartir la primera palabra si hacen cosas
distintas.** Si al leerlas en una lista hay que llegar a la segunda palabra para
distinguirlas, una de las dos está mal nombrada.

### Adrián, dónde sí y dónde no
Aparece en **junta directiva, escuelas y contenido**. En pagos y cobros el
contacto es **Isabel** siempre: el presidente queda fuera del circuito de dinero.

---

## Pendiente

- ⚠️ Los dos cargadores colgados y los guiones de `/liga/` en producción
- Veinte fotos con cara y dorsal + recorte vertical del hero para móvil
- Un párrafo por grupo escrito por su entrenador
- Del panel: Retos, Informes con historial imprimible, fotos de la web, pedidos de
  ropa, tarifas, grupos de entrenamiento, quién entra al panel, importar
