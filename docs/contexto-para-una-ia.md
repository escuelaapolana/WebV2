# Club Atletismo Apolana · contexto del proyecto

*Documento para pegar en otra IA cuando haga falta que entienda de qué va esto
sin leerse el repositorio entero. Está escrito para que se entienda de una
lectura, no para ser exhaustivo.*

---

## Qué es

Tres cosas dentro de un mismo sitio, con la misma base de datos detrás:

1. **La web pública** del Club Atletismo Apolana (Alicante, fundado en 1988).
   Secciones, horarios, precios, noticias, calendario, formularios de alta.
2. **El portal privado** para atletas, familias y entrenadores: entrenamientos
   del día, apuntar cómo fue, marcas, recibos, documentos.
3. **El panel de administración** del club: personas, cobros, grupos, contenido
   de la web, altas, competiciones.

No es un producto ni una plantilla: es la herramienta de un club concreto, con
420 atletas y siete secciones (atletismo en pista, running, natación, triatlón,
montaña, fuerza y las escuelas de niños).

## Cómo está construido

- **Web estática servida por GitHub Pages.** HTML y CSS a mano, sin framework y
  sin paso de compilación: lo que hay en el repositorio es lo que se publica.
- **JavaScript de navegador, sin librerías** salvo el cliente de Supabase.
  28 archivos en `assets/js/`, cada uno con su responsabilidad.
- **Supabase (PostgreSQL)** como base de datos, autenticación y almacenamiento.
  103 tablas, 310 políticas de seguridad a nivel de fila, 149 migraciones SQL.
- **5 funciones Edge** en Deno para lo que no puede vivir en el navegador:
  enlaces de acceso, avisos, pagos con tarjeta y la integración con Strava.

Tamaño: 31 páginas públicas, 38 pantallas de panel, 20 de portal.

## Las reglas de la casa

Estas no son preferencias de estilo, son decisiones tomadas y sostenidas. Quien
toque el código debería respetarlas:

- **Todo en español**, incluidos los nombres de funciones, variables, tablas y
  columnas. `entrenosDelDia`, `grupo_horarios`, `es_admin()`.
- **Los comentarios explican POR QUÉ, no qué.** Muchos son largos a propósito y
  cuentan qué se probó antes y por qué se descartó. No se borran.
- **Nada de dependencias nuevas** sin una razón muy buena. Ni framework, ni
  librería de gráficos, ni de PDF: hay gráficas en SVG a mano y la impresión se
  hace con `window.print()` y una hoja de estilos.
- **La seguridad vive en la base de datos**, no en la pantalla. Las políticas
  RLS deciden quién ve qué; el navegador solo pinta lo que le llega.
- **Ningún dato personal en el repositorio**, que es público. Las migraciones
  llevan el molde; los datos se ponen desde el panel.
- **Los mensajes de commit son largos y en español**, y cuentan el problema
  antes que la solución.

## Cómo se prueba

- Un servidor local (`python3 -m http.server 8137`) y el navegador.
- Contra la base de datos real, con `bash .secrets/psql.sh` (fuera del
  repositorio).
- Los cambios de permisos se prueban **abriendo una transacción, creando un
  perfil de prueba con ese papel, comprobando qué ve y deshaciendo**. Nunca a
  ojo.

## Cosas que conviene saber antes de proponer nada

- **Se diseñó mirando el móvil.** Casi todo se lee ahí primero.
- **Las fotos son el punto débil**: de 164 imágenes del repositorio, ninguna
  llega a 2400 px y 149 bajan de 1500. En pantallas Retina se estiran y por eso
  el sitio se ve blando. La regla nueva es: mirar cuántos píxeles pide el hueco,
  multiplicar por dos, y no estirar nunca.
- **Hay dos fuentes para el mismo contenido**: los textos y las fotos de las
  páginas salen de las tablas `contenido_secciones` e `imagenes_web`, y lo que
  está escrito en el HTML es solo el respaldo por si la consulta falla.
- **El club es pequeño y lo lleva gente con poco tiempo.** Una función que
  necesite mantenimiento constante no se va a mantener. Lo que se llena solo
  —noticias, horarios, calendario— vale más que lo que hay que escribir a mano.

## Estado

En uso real desde el verano de 2026. La web pública está publicada pero con
`noindex` mientras convive con el sitio antiguo (`atletismoapolana.com`). El
portal y el panel los usan a diario el club y los entrenadores.
