# Arreglos WebV2 — orden de trabajo (del dueño)

Referencia de diseño: `Web Apolana.dc.html` + `ESPECIFICACION.md`.
Regla general del proyecto: cada cambio se aplica a TODO, cómodo y bonito. Ver memoria `feedback-consistencia-y-comodidad`.

## Bloqueantes
1. **"Hoy en el club" no carga** (`index.html`): se queda en "Cargando el día…". Ver de dónde lee; fallback: si no hay datos, mostrar el horario fijo del día de la semana. Nunca dejar el spinner > 2 s.
2. **Falta el test "Encontramos tu grupo"** en portada (bajo el hero, antes de "Para mi hijo o hija"). 4 pasos visibles a la vez: (1) para quién: hijo/a · para mí; (2) deporte: atletismo ruta · pista · natación · triatlón · montaña · fuerza (El Cubo); (3) qué buscas: hábito · bajar marca · preparar carrera · mantenerme; (4) días: 2 · 3 · 4+. Resultado enlaza DIRECTO a la sección del grupo que encaja. Reglas en ESPECIFICACION.md.
3. **"Ver galería" mal apuntada**: ahora va a `/club/historia/#archivo`. Crear `/galeria/` y apuntar ahí desde portada y menú.

## Contenido
4. **Triatlón**: quitar "Consultar". Precio: incluido en cuota de socio (120 €/año); entrena con grupos de pista y natación; sin entrenador dedicado. Redactar como ventaja, no carencia.
5. **Falta El Cubo** en la tabla de grupos y precios. Añadir fila con clases y bonos.
6. **Montaña** sigue en "Consultar": confirmar con junta; si no hay precio, poner "Escríbenos" → contacto.
7. **Pendientes de septiembre (Ayuntamiento)**: no inventar. Bloque con fecha: "Horarios y precios disponibles en septiembre". Deporte adaptado, Triatlón municipal.
8. **Fotos IG repetidas** (adultos.jpg, noticia-xixona-galeria-4.jpg): 6 fotos reales o reducir a 4.
9. **Fotos junta**: faltan Miguel Á. Pellín y José Fernández. Placeholder con iniciales sobre azul (nunca silueta genérica).
10. **Copy placeholder**: repasar toda la web; ninguna cita de entrenador inventada publicada.

## Precios y admin
11. **Precios reales de tienda**: por la UI de admin, no hardcodear en HTML.
12. **Admin = única fuente de verdad**: web y app leen de admin, no de datos duplicados (fotos, precios, eventos, grupos, noticias).
13. **Familia Apolana** (verificar cálculo en web): 2.º miembro −10 %, 3.º y siguientes −15 %, sobre cuota de ENTRENAMIENTO (no la de socio); no acumulable; un recibo mensual.

## Revisión visual
14. **Tabla de grupos → tarjetas**: nombre grande, días en estilo secundario, precio a la derecha alineado (es lo que buscan).
15. **Tres números del hero** (420/175/38): más aire y tamaño (prueba social).
16. **Jerarquía de los 2 CTA**: "Prueba 4 días gratis" sólido en azul (objetivo); "Conocer el club" solo texto con flecha.
17. **Consistencia móvil** (375 px): tabla de precios y galería; objetivos táctiles ≥ 44 px.

## No hacer
- No rediseñar lo que funciona (jerarquía escuela/adultos, orden de secciones, CTA repetido arriba/abajo).
- No cambiar la paleta (crema + azul). Tipografía: mantener fuentes de marca; el único cambio acordado en vivo es quitar el aire monoespaciado de las etiquetas.
- No añadir secciones nuevas sin preguntar.
