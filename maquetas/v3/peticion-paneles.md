# Petición al maquetador · Las pantallas del panel

## El problema, en una frase del club

> «La web está increíble. El panel de entrenador, de atleta y de administrador hay cosas que pulir: hay ventanas con sobreinformación, o que no están bien optimizadas, o se podrían poner más desplegables. Pero también lo entiendo, porque hay mucha información y muchos datos y muchas cosas.»

El diagnóstico es exacto, y conviene decirlo así: **no sobra información, sobra información a la vez.** Un entrenador a pie de pista necesita tres cosas en pantalla; el resto puede estar plegado, no ausente.

**La causa es conocida: la web la maquetaste tú, los paneles no.** Son 55 pantallas, y solo doce tienen maqueta. Las demás se resolvieron sobre la marcha, y por eso se nota el salto: la web respira y el panel te echa encima todo lo que sabe.

## Lo que ya se ha arreglado sin tocar diseño

Para que sepas de qué punto partes, se ha hecho una pasada de ordenar sin rediseñar:

- Las pantallas con desplegables pasan de **4 a 24** de 55.
- Las que usan el juego de estados común (cargando, vacío, error, con datos) pasan de **19 a 32** de 36 en el panel.
- Las que tienen buscador, de **10 a 16**.
- Unos setenta sitios que decían «no hay nada» o «0 €» cuando en realidad había fallado la consulta, ahora lo dicen y dejan reintentar.
- Los botones que no se alcanzaban con el pulgar suben a 44 px, empezando por los que borran cosas.

**Eso es todo lo que se podía hacer sin criterio de diseño.** Lo que queda son diez pantallas que hay que repensar, no ordenar.

## Un dato técnico que te conviene saber

Las 55 pantallas llevan **su propio diseño escrito dentro de cada una**: unas 7.900 líneas repartidas, sin una hoja común. Por eso una pantalla tiene los botones a 44 px y la de al lado a 19. No hay que arreglarlo ahora, pero **es la razón de fondo del desnivel**, y explica por qué las doce que sí tienen maqueta se ven distintas de las demás.

Sí existe ya un juego común de estados de carga y error, y funciona bien. Lo que falta es lo mismo para la forma.

---

## Las diez pantallas

**1 · Entrenador · «Planificar semana» y «Planificar un entreno»**
Es en realidad otra pantalla metida dentro de esta: un formulario de veinte controles con ocho párrafos de explicación siempre abiertos. Hay que decidir si sale a su propia página, y si va por pasos.

**2 · Familia**
El estado de los pagos se dice en **cinco sitios distintos** de la misma pantalla, y la sección «Entreno» son cinco tarjetas seguidas. Hay que decidir dónde vive cada cosa. Y lo más importante: **«Avisar de una falta», que es lo que más hace un padre, está en tercera posición y enterrado.**

**3 · Calendario**
Tres barras de mandos apiladas antes del primer dato. En el móvil, el bono y la próxima competición caen al final del todo.

**4 · Tarifas**
El único botón azul es «Guardar cambios» y **arranca apagado**: lo que más destaca es justo lo que no puedes pulsar. Y lo que sí quieres —«Editar»— es un enlace de 19 px. Los recuadros de precio miden 31 px y rompen la rejilla si se suben.

**5 · Pedidos de ropa**
Arriba cuatro tarjetas que cuentan una cosa («Preparando 8») y justo debajo unas pastillas que cuentan lo mismo filtrado («Preparando 1»), las dos en pantalla a la vez diciendo cosas distintas. Más cuatro mandos apretados en cada fila.

**6 · Usuarios y permisos**
Hay que rehacer la rejilla de ocho cifras y **subir arriba la lista de personas**, que es a lo que va todo el mundo y hoy está a tres pantallas de scroll.

**7 · Plantillas de correo**
Tres columnas a la vez y dos botones azules compitiendo entre sí.

**8 · Documentos (panel)**
Siete columnas con cuatro botones cada una. En el móvil hay que convertirlo en fichas, como se hizo en otras.

**9 · Mapa de contenido**
Enlaces de 18 px, dos pegados por fila, y un medidor que repite exactamente lo que ya dicen las etiquetas de al lado.

**10 · Histórico de la escuela**
Poco: la franja de tablet en vertical y plegar la tabla de trece columnas. Un apunte útil: **en el código hay etiquetas preparadas para una vista de fichas en móvil que nunca llegó a escribirse** — alguien ya pensó cómo debía ser.

## Y una más, del portal: las dos barras de arriba

En el portal hay **dos barras superiores pegadas**: una dice «Estás como atleta · Cambiar» y justo debajo otra oscura con «Ir a la web · Cambiar de perfil · [nombre] · Salir».

El club ya se quejó de esto hace tiempo: *«mi problema en admin es que hay dos menús, uno abajo y otro arriba; no sé dónde están las cosas»*.

**Cambiar de papel y cambiar de perfil son dos cosas distintas** —una persona puede ser a la vez atleta, entrenador, tesorero y administrador, y además tener hijos en el club— y ahora mismo compiten en el mismo sitio. Unificarlas es repensar la navegación, no ordenarla.

## Un patrón que al club le convence, por si sirve de punto de partida

Dentro del propio portal hay unas **tarjetas azules en degradado** para la sesión del día: una línea fina de contexto arriba («Hoy · Velocidad · Sub-20»), el nombre del entreno grande, y abajo dos botones —uno blanco sólido para la acción principal y otro perfilado para la secundaria—.

El club dijo de ellas: *«me encantan estos colores y tarjetas; también se puede usar en atletas para el entrenamiento del día. Se puede usar para muchas cosas.»*

---

*Va aparte la petición sobre los formularios de alta.*
