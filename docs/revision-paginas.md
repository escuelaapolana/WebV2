# Revisión de páginas · auditoría visual y de consola

Fecha: 1 de agosto de 2026 · Revisión **solo de lectura** (no se ha tocado ningún archivo del sitio).

**Cómo se ha probado:** servidor estático en `http://localhost:8765`, navegador real a 1280×900 y a 390×844,
lectura de la consola en cada página, comprobación de todos los `href` internos contra el disco y contra el
servidor, y barrido de desbordamiento horizontal en móvil de las 44 páginas.

**Buena noticia de partida:** **no hay ni un solo error de JavaScript ni un recurso 404 en ninguna de las 44
páginas revisadas.** Tampoco hay texto en inglés en la interfaz, ni "lorem ipsum", ni una sola mención a IA,
Claude, Anthropic o asistentes. Lo que falla es otra cosa: hay pantallas que **parecen** funcionar y no
funcionan, porque se quedaron en maqueta.

**Lo que NO se ha podido probar (falta la contraseña):** todo el contenido *detrás* del login. De las 30
páginas de `/portal/*` y `/admin/*` solo se ha podido verificar que **cargan, sin errores de consola, y que
enseñan correctamente la pantalla de acceso**. No se ha visto ni una tabla, ni un listado, ni un formulario de
esas zonas. Es la mitad grande del proyecto y sigue sin revisar.

---

## Tabla de resultados

### ROTO

| Página | Estado | Qué falla exactamente |
|---|---|---|
| `/acceso/` | **Roto** | El formulario de entrar **no entra**: `<form class="acceso-form" onsubmit="return false;">`. En el propio archivo está el comentario `<!-- SIN BACKEND: se maqueta visualmente, no autentica ni envía nada -->` y `<!-- pendiente de conectar (Supabase) -->`. Un socio que llegue aquí escribe su correo, pulsa "Entrar" y no pasa nada. Se llega desde `/club/normativa/` ("Hay documentos disponibles solo para socios. **Entra en tu zona** para verlos"). El login que sí funciona es `/portal/`. |
| `/acceso/` | **Roto** | Enlace roto: "He olvidado la contraseña" → `../acceso/recuperar/` → **404**. Esa carpeta no existe. |
| `/tienda/` | **Roto** | La tienda no compra nada. Los 12 botones "Añadir" (`class="anadir"`) **no tienen ningún manejador de clic** en toda la página. El panel "Tu pedido" es HTML fijo: siempre muestra "Camiseta de competición · Talla M · 1 ud. · 22€ · Total 22€", aunque no hayas tocado nada. "Confirmar pedido" es un `<button type="button">` sin código detrás. El catálogo de productos sí se carga bien desde Supabase. |
| `/calendario/` | **Roto** | Es una maqueta con datos inventados, teniendo 60+ sesiones reales en la base de datos: (1) la rejilla del mes está escrita a mano en el HTML (líneas 179-208), con agosto fijo y el día **29 marcado como "hoy"**; (2) el panel lateral "**Martes 29 · 4 ACTIVIDADES**" es HTML fijo (líneas 213-235); (3) "Próxima competición: Cross de Alicante · 16 de agosto · Inscribirme 12€" es HTML fijo (líneas 237-243); (4) los seis filtros (Todo / Escuela / Running / Pista / Natación / Competiciones) son `<span>` sin JavaScript: se pulsan y no hacen nada. Lo único real es la lista "Próximos eventos". |
| `/calendario/` | **Roto** | **Desbordamiento horizontal en móvil**: a 390px el contenido mide 455px. El culpable es `.cal-tabla` (436px de ancho dentro de un hueco de 386px): la rejilla de 7 columnas no se adapta. Es la única página del sitio con este problema. |
| `/familias/` | **Roto** | La calculadora "Calculad lo vuestro" es una maqueta: los desplegables son `<div class="calc-select">` (no `<select>`), las cifras son fijas (36,5 € / 36,0 € / 30,0 € → recibo de 138,5 €) y "+ Añadir a alguien más de casa" es un `<span>` sin código. El botón principal de la página ("Calcular lo nuestro") lleva justo ahí. El comentario del archivo lo reconoce: "*No existe una tabla de precios base por opción, así que la calculadora se reproduce visualmente con los datos de la maqueta*" — pero ahora **sí existe** `migraciones/022_tarifas.sql`. |
| `/portal/` | **Roto** | Enlace mal construido. `portal/index.html:59` hace `'<a href="' + base + 'documentos/">Documentos del club</a>'` con `base = "../"`, así que apunta a **`/documentos/`**, que es la carpeta de PDFs y **no tiene `index.html`**. En local parece funcionar (Python genera un índice automático), pero **en GitHub Pages dará 404**. Debería ser `/portal/documentos/` o `/club/normativa/`. Los mismos enlaces en `/portal/atleta/`, `/portal/familia/` y `/portal/coordinador/` sí están bien (`../documentos/`). |
| `/` (portada) | **Roto** | La banda "**HOY EN EL CLUB**" es HTML fijo (líneas 179-195): pone "*Hoy · martes 29*" y cuatro sesiones inventadas (Escuela Benjamín 17:30, Madre Tierra 19:00, La Tribu 19:30, Natación adultos 20:30). Hoy es sábado 1 de agosto y hay 60+ sesiones publicadas en la base de datos. Es lo primero que ve cualquier visitante y siempre estará mal. |

### AVISO

| Página | Estado | Qué falla exactamente |
|---|---|---|
| `/club/historia/` | Aviso | El bloque "Archivo fotográfico" enseña al público la **nota interna de la maqueta**: "`SE SUBE DESDE ADMIN · MÁX. 12`", seguida de **12 recuadros rayados vacíos** (`<div class="hueco">`). Además la página **no consulta la base de datos** en ningún momento, así que esos huecos no se llenarán nunca por mucho que se suban fotos desde el panel. |
| `/contacto/` | Aviso | Donde debería ir el mapa hay un recuadro rayado de 220px con el texto de maqueta "`mapa · tres instalaciones`" (`contacto/index.html:167`). No hay mapa ni enlace a uno. |
| `/noticias/`, `/noticias/articulo/`, `/` | Aviso | La etiqueta de categoría se pinta haciendo `.toUpperCase()` del valor crudo de la base de datos, así que sale "**COMPETICION**" sin tilde. Ocurre en tres sitios: `noticias/index.html:151`, `noticias/articulo/index.html:70` e `index.html:397`. Los filtros de la propia página sí ponen "Competición" bien, así que se ve la incoherencia al lado. Hace falta traducir la clave a etiqueta (competicion → Competición, resultado → Resultados…). |
| `/club/palmares/` | Aviso | Los seis filtros (Todo / Pista / Cross y ruta / Montaña / Natación / Nacional) son `<span>` decorativos: no hay ni un `addEventListener` en la página. Se pulsan y no filtran. |
| `/club/records/` | Aviso | Igual: las cuatro pestañas de categoría (Absoluta / Sub-20 / Sub-18 / Máster) son `<span class="chip">` sin código. Siempre se ve la tabla absoluta. |
| `/escuela-municipal-atletismo/` | Aviso | El texto bueno de la página lo machaca lo que hay guardado en `contenido_secciones`, y lo que hay guardado está mal escrito: el rótulo sale "**NINOS Y JOVENES**" (sin eñe ni tildes) y la entradilla se queda en "*Programa con Deportes Alicante.*", cuando el HTML original tenía un texto completo. Es dato, no código, pero se ve en la web pública. Además el subtítulo pone "Curso 2025-26" mientras el resto del sitio va por 2026-27. |
| `/` y `/noticias/` | Aviso | La noticia destacada de la portada es "**PRUEBA 1 — *jeje prueba prueba***" (30 jul, categoría Club). Es una noticia de pruebas marcada como publicada. Ocupa el bloque grande de la portada. |
| `/campus/` | Aviso | Cabecera "MATRÍCULA ABIERTA" y "**DEL 29 DE JUNIO AL 31 DE JULIO**": la fecha ya pasó (hoy es 1 de agosto). El campus XII aparece como abierto cuando ya ha terminado. |
| `/404.html` | Aviso | Usa `window.APOLANA_BASE="./"` y enlaces relativos (`href="./"`, `href="calendario/"`). En GitHub Pages la página 404 se sirve **conservando la URL que el visitante pidió**, así que desde `/club/loquesea/` los dos botones ("Volver a la portada", "Ver el calendario") apuntarán a sitios que no existen. Deben ser rutas absolutas. |
| `/familias/`, `/tienda/` | Aviso | **Huérfanas**: ninguna página pública ni el menú ni el pie enlazan a `/familias/` (solo se llega desde dentro del portal de familia) ni a `/tienda/` (solo desde el portal). Están hechas y nadie las va a encontrar. |
| `/admin/estadisticas/` | Aviso | Existe y carga bien, pero el panel `/admin/` **no la enlaza**: tiene enlaces a las otras 17 secciones y a ésta no. Es inaccesible salvo escribiendo la URL. |
| `/acceso/` | Aviso | Duplicado funcional de `/portal/`. El botón "Entrar" de la cabecera de toda la web lleva a `/portal/` (que sí funciona y sí tiene recuperación de contraseña real vía `resetPasswordForEmail`). `/acceso/` solo se enlaza desde `/club/normativa/`. Sobra una de las dos. |
| `/` (portada) | Aviso | "Ver galería →" apunta a `/club/`, que **no tiene galería**. La galería de verdad está en `/club/historia/`… y está vacía (ver arriba). |
| Todo el repo | Aviso | En GitHub Pages se publica **todo lo que hay en el repositorio**. Ahora mismo son públicos: `/maquetas/` (las maquetas internas de diseño, incluidas `diseno-completo.html` y `originales-design/*.dc.html`), `/ESPECIFICACION.md`, `/SETUP-SUPABASE.md` y **`/migraciones/` (37 ficheros `.sql` con el esquema completo de la base de datos, las políticas de seguridad RLS y los datos de demostración, con 28 direcciones de correo dentro)**. No hay claves secretas ahí (la clave `publishable` es pública por diseño y está bien), pero enseñar el esquema y las reglas de seguridad no aporta nada y facilita el trabajo a quien quiera buscarles las cosquillas. Tampoco hay `robots.txt` ni `sitemap.xml`. |
| `/`, `/socio/`, `/instalaciones/`, `/tienda/` | Aviso | Anglicismo suelto: "**container**" ("Container de entrenamiento funcional", "Acceso a pista, gimnasio y container", "Se recoge en el container de la pista"). Si es la palabra que usa el club, vale; si no, en español sería "contenedor". |
| `/portal/tienda/`, `/recibo/`, `/admin/noticias/` | Aviso | **No existen** (404). No las enlaza nadie, así que no rompen nada; la gestión de noticias vive dentro de `/admin/` y la tienda del portal reutiliza la pública `/tienda/`. Se listaban como páginas a revisar, pero no están hechas. |

### OK

Cargan bien, sin errores de consola, sin desbordamiento en móvil, con el estilo del club (crema/navy/azul,
tipografías correctas) y con datos reales de la base de datos donde toca:

| Página | Estado | Nota |
|---|---|---|
| `/club/` | OK | Cifras, cuatro tarjetas y junta directiva completa. |
| `/club/normativa/` | OK | Tres documentos con sus PDF; el aviso de "solo socios" está oculto hasta que haga falta. |
| `/club/palmares/` | OK | Carga los podios de la base de datos correctamente (salvo los filtros, ver arriba). |
| `/club/records/` | OK | 12 récords, masculino y femenino (salvo las pestañas, ver arriba). |
| `/competicion/` | OK | Grupos, cuotas y responsable. |
| `/running/` | OK | |
| `/natacion/` | OK | |
| `/triatlon/` | OK | Avisa correctamente de que la sección no tiene entrenador. |
| `/montana/` | OK | |
| `/cubo/` | OK | Las 5 clases de la semana salen de la base de datos, con plazas libres y "COMPLETA". |
| `/escuela/` | OK | |
| `/escuela-natacion/` | OK | |
| `/instalaciones/` | OK | Cuatro sedes. |
| `/noticias/` | OK | 5 noticias de la base de datos y **los filtros por categoría sí funcionan** aquí. |
| `/noticias/articulo/` | OK | Abre por `?id=`; sin `id` avisa con elegancia ("No hemos podido cargar la noticia") en vez de romperse. |
| `/socio/` | OK | |
| `/inscripcion/` | OK | El formulario **sí guarda** en `solicitudes_inscripcion`. (No se ha enviado ninguna solicitud de prueba.) |
| `/contacto/` | OK | Teléfonos y formulario correctos (salvo el hueco del mapa). |
| `/portal/` y las 9 de `/portal/*` | OK (parcial) | Las 10 cargan sin un solo error y todas enseñan bien la pantalla "Club Apolana · Entra con tu cuenta". **No se ha podido ver nada de dentro.** |
| `/admin/` y las 17 de `/admin/*` | OK (parcial) | Las 18 cargan sin un solo error y todas enseñan bien "Panel Apolana · Acceso solo para administración". **No se ha podido ver nada de dentro.** |

---

## Qué arreglar primero

1. **`/acceso/`: decidir y actuar.** Es un formulario que no autentica, enlazado desde `/club/normativa/`. O se conecta a Supabase como `/portal/`, o se borra y se redirige a `/portal/`. Lo segundo es más rápido y evita mantener dos logins. De paso desaparece el 404 de `/acceso/recuperar/`.
2. **`/portal/` → "Documentos del club" apunta a `/documentos/`.** Una línea (`portal/index.html:59`). Ahora mismo funciona en local y **romperá al publicar**, que es la peor clase de fallo.
3. **`/calendario/`.** Es la página más visitada después de la portada y hoy es una maqueta entera con "martes 29" congelado. Conectar la rejilla y el panel del día a las sesiones reales, y hacer que los filtros filtren. Aprovechar para arreglar el desbordamiento en móvil (`.cal-tabla`).
4. **La banda "Hoy en el club" de la portada.** Mismo problema, mismo origen de datos que el punto 3: se arreglan juntos.
5. **`/tienda/`.** O se le pone carrito de verdad (ya hay `migraciones/029_tienda.sql` y `/admin/pedidos/`), o se cambia por un "pídelo por WhatsApp". Tal como está, un socio cree que ha comprado y no ha comprado nada.
6. **Limpiar los restos de maqueta visibles al público:** la nota "SE SUBE DESDE ADMIN · MÁX. 12" y los 12 huecos vacíos de `/club/historia/`, y el recuadro "mapa · tres instalaciones" de `/contacto/`.
7. **Borrar la noticia de pruebas "Prueba 1 / jeje prueba prueba"** o despublicarla: está en el bloque grande de la portada.
8. **Los acentos de las categorías** (`COMPETICION` → `Competición`) en los tres sitios donde se hace `.toUpperCase()`, y arreglar el contenido guardado de `escuela-municipal-atletismo` ("NINOS Y JOVENES").
9. **Filtros decorativos de `/club/palmares/` y `/club/records/`:** o se conectan, o se quitan. Un botón que no hace nada es peor que no tenerlo.
10. **Sacar de la publicación lo que no es la web:** `/maquetas/`, `/migraciones/`, `ESPECIFICACION.md` y `SETUP-SUPABASE.md`. Y arreglar los enlaces relativos del `404.html`.
11. **Enlazar las páginas huérfanas** (`/familias/` y `/tienda/` desde el menú o el pie; `/admin/estadisticas/` desde el panel) y corregir "Ver galería →" de la portada.
12. **Actualizar `/campus/`** (matrícula que ya cerró el 31 de julio) y el "Curso 2025-26" de la escuela municipal.
13. **Pendiente y grande: revisar las 28 pantallas de dentro del portal y del panel.** Cargan limpias, pero nadie ha visto todavía si sus tablas, formularios y filtros funcionan con los datos reales. Hace falta una cuenta de prueba de cada rol (atleta, familia, entrenador, coordinador, administración) para poder auditarlas.
