# Arreglos WebV2 — lista para Claude Code

Repo: `escuelaapolana/WebV2` · Referencia de diseño: `Web Apolana.dc.html` + `ESPECIFICACION.md`

---

## Bloqueantes

### 1. "Hoy en el club" no carga
`index.html` — el widget se queda en *Cargando el día…*.

Es lo primero que ve alguien que entra por la tarde. Comprobar de dónde lee los
datos (admin / JSON estático) y qué falla. Añadir estado de fallback: si no hay
datos, mostrar el horario fijo del día de la semana en lugar del spinner.
Nunca dejar el texto de carga visible más de 2 s.

### 2. Falta el test "Encontramos tu grupo" en portada
Es el gancho principal, va justo debajo del hero, antes de "Para mi hijo o hija".

Cuatro pasos visibles a la vez en la misma pantalla (no uno por pantalla):

1. **Para quién** — mi hijo/a · para mí
2. **Qué deporte** — atletismo ruta · atletismo pista · natación · triatlón · montaña · fuerza (El Cubo)
3. **Qué buscas** — coger el hábito · bajar mi marca · preparar una carrera · solo mantenerme
4. **Cuántos días** — 2 · 3 · 4 o más

El resultado enlaza directo a la sección del grupo que encaja, no a un listado
genérico. Reglas de filtrado en `ESPECIFICACION.md`.

### 3. "Ver galería" apunta al sitio equivocado
Ahora va a `/club/historia/#archivo`. La galería es sección propia en el diseño.
Crear `/galeria/` y apuntar ahí desde portada y desde el menú.

---

## Contenido

### 4. Triatlón ya tiene datos, quitar "Consultar"
En la tabla de grupos y precios:

- Precio: **incluido en la cuota de socio** (120 €/año)
- Días: entrena con los grupos de pista y natación
- Sin entrenador dedicado

Redactarlo sin que parezca una carencia: es una ventaja de precio.

### 5. Falta El Cubo en grupos y precios
Aparece mencionado en la noticia de equipación pero no está en la tabla.
Añadir fila con clases y bonos.

### 6. Montaña sigue en "Consultar"
Confirmar con la junta si hay precio cerrado. Si no lo hay, cambiar "Consultar"
por algo accionable: "Escríbenos" con enlace a contacto.

### 7. Pendientes de septiembre (Ayuntamiento)
No inventar datos. Dejar el bloque con fecha explícita:
"Horarios y precios disponibles en septiembre".

- Deporte adaptado
- Triatlón municipal

### 8. Fotos de Instagram repetidas
El bloque de IG reutiliza `adultos.jpg` y `noticia-xixona-galeria-4.jpg`.
Se nota el relleno. Seis fotos reales de Instagram o reducir a cuatro.

### 9. Fotos de junta directiva
Faltan Miguel Á. Pellín y José Fernández. Placeholder con iniciales sobre
fondo azul, nunca silueta genérica.

### 10. Copy placeholder
Repasar en toda la web: citas de entrenadores y descripciones de grupo.
Ninguna cita inventada debe quedar publicada.

---

## Precios y admin

### 11. Precios reales de tienda
Entrar por la UI de admin cuando esté en marcha. No hardcodear en el HTML.

### 12. Admin como única fuente de verdad
Comprobar que web y app leen de admin y no de datos duplicados en cada repo:
fotos, precios, eventos, grupos, noticias.

### 13. Familia Apolana
Verificar que el cálculo es correcto en la web:

- 2.º miembro del hogar: **−10 %** sobre cuota de entrenamiento
- 3.º y siguientes: **−15 %**
- No acumulable · un solo recibo mensual
- El descuento no aplica a la cuota de socio

---

## Revisión visual

### 14. Densidad de la tabla de grupos
Cinco filas de texto corrido cuesta escanearlas. Que cada grupo sea una tarjeta
con jerarquía: nombre grande, días en mono, precio a la derecha alineado.
El precio es lo que la gente busca y ahora va al final de una línea larga.

### 15. Los tres números del hero
420 / 175 / 38 están puestos pero pasan desapercibidos. Merecen más aire y
tamaño: son la prueba social del club.

### 16. Jerarquía de los dos CTA
"Prueba 4 días gratis" y "Conocer el club" compiten. El primero es el objetivo
de negocio: que sea sólido en azul, el segundo solo texto con flecha.

### 17. Consistencia móvil
Comprobar la tabla de precios y la parrilla de galería en 375 px.
Objetivos táctiles nunca por debajo de 44 px.

---

## No hacer

- No rediseñar lo que ya funciona: jerarquía escuela/adultos, orden de secciones,
  CTA repetido arriba y abajo.
- No cambiar la paleta (crema + azul) ni la tipografía.
- No añadir secciones nuevas sin preguntar.
