# Revisión por dentro del panel y del portal

Recorrido pantalla a pantalla del **panel de administración** (`/admin/`) y del **portal**
(`/portal/`), entrando con una cuenta de administración contra la base de datos real.
De cada pantalla se ha mirado: errores de consola, si carga con datos de verdad, cómo se ve a
tamaño de ordenador y de móvil (390 px), y si se parece a lo que piden las maquetas
(`docs/maquetas-admin.md` y `docs/maquetas-app.md`).

**Resumen**: ninguna pantalla da error de consola y ninguna se queda en blanco por una consulta
rota, salvo un contador de estadísticas que estaba mal. Lo que más se ha arreglado son
identificadores de la base de datos que se enseñaban en crudo al usuario (`natacion`, `cubo`,
`entrenamiento_especial`), plurales del tipo «0 grupo(s)» y tres fallos de verdad: el contador
de atletas activos, el orden inestable de los recibos y una tabla que se salía de la pantalla en
el móvil.

Fecha del recorrido: 1 de agosto de 2026.

---

## Panel de administración

| Pantalla | Estado | Qué falla | Qué hice |
| --- | --- | --- | --- |
| `/admin/` · Inicio | OK | Los contadores y las alertas salen con datos reales. Falta la columna derecha de la maqueta (accesos rápidos, aviso activo en portada) y la tabla de «últimos inscritos»: queda mucho hueco vacío a la derecha | Nada (es una decisión de diseño, ver más abajo) |
| `/admin/` · Noticias | OK | — | — |
| `/admin/` · Avisos de portada | OK | — | — |
| `/admin/` · Tienda | OK | — | — |
| `/admin/` · Buzón | Aviso | Las dos tablas apretaban tanto la columna del mensaje que el texto salía a una palabra por línea, en una columna larguísima | Le he dado un ancho fijo a fecha, nombre, contacto y asunto, y el resto del ancho al mensaje; la tabla se desliza a lo ancho si hace falta |
| `/admin/atletas/` | Aviso | 179 fichas en una sola lista, sin buscador ni filtros, y sin ver a qué grupo pertenece cada una. Además el enlace «← Volver al panel» salía dos veces (uno en la barra y otro en la página) | Añadido buscador por nombre o correo, filtro por estado, filtro por grupo, contador de resultados y columna «Grupo». Quitado el enlace duplicado |
| `/admin/grupos/` | Aviso | La columna «Sección» enseñaba el identificador interno: `natacion`, `cubo`, `escuela-natacion`, `competicion`, `montana` | Ahora se lee «Natación», «El Cubo», «Escuela de natación»… y el campo del formulario ofrece la lista de secciones válidas para no escribirlas a mano |
| `/admin/usuarios/` | OK | — | Solo mirar: otra persona está trabajando en esta pantalla |
| `/admin/cobros/` | **Roto** | (1) La pastilla decía «Pendientes 48» mientras el contador de arriba decía «Pendiente 0,00 € · 0 recibos por vencer». (2) Al marcar un recibo, la lista se recolocaba entera y perdías el sitio. (3) La cabecera mezclaba el total del club con lo filtrado. (4) **Un recibo ya emitido con número la base de datos no deja tocarlo**, pero los botones «Pendiente», «Impagado», «Editar» y «Borrar» seguían activos y al pulsarlos salía un `alert()` con el error técnico que además dejaba el navegador bloqueado | (1) La pastilla ahora se llama «Por vencer» y cuenta lo mismo que el contador. (2) El listado se pide con un orden estable (vencimiento, alta y id), así ya no baila. (3) La cabecera siempre habla del total. (4) Los recibos emitidos muestran su número, se bloquean sus botones con la explicación («ya está emitido: habría que anularlo y emitir un rectificativo») y los errores salen en un aviso dentro de la página, nunca en una ventana que bloquea |
| `/admin/tarifas/` | OK | Muy fiel a la maqueta. El nombre del grupo se partía en tres líneas («Natación · bono 4 clases») teniendo hueco de sobra al lado | Ensanchada la columna del grupo |
| `/admin/pedidos/` | OK | La pantalla está bien, pero no hay ningún pedido en la base, así que sale todo a cero | Nada. Es que no hay datos todavía |
| `/admin/eventos/` | Aviso | La columna «Tipo» enseñaba `competicion` y `entrenamiento_especial` en crudo | Ahora se lee «Competición» y «Entrenamiento especial», y el campo sugiere los tipos que ya se usan |
| `/admin/competiciones/` | Aviso | Textos con plural de formulario: «5 atleta(s)», «5 prueba(s) · 0 confirmada(s)», «inscripción(es)» | Reescritos en singular o plural según el número |
| `/admin/cubo/` | OK | Carga las 55 clases con monitor, plazas y lista de espera | — |
| `/admin/pruebas/` | OK | Catálogo completo con filtros por ámbito y disciplina | — |
| `/admin/paginas/` | Aviso | La página «Campus» aparecía como `campus` (sin nombre bonito), igual que «Escuela municipal» | Añadidos los dos nombres que faltaban |
| `/admin/contenido/` | Aviso | La columna «Sección» enseñaba el identificador en crudo, al revés que en «Páginas» y en «Mapa de contenido» | Ahora sale el nombre de la página y debajo, pequeño, el identificador |
| `/admin/biblioteca/` | OK | La versión que hay publicada es la antigua; la del repositorio ya lleva etiquetas, buscador y favoritas | Nada (lo está tocando otra persona) |
| `/admin/documentos/` | OK | La columna «Tamaño» sale siempre vacía porque los documentos no guardan el peso del fichero | Nada (hace falta decidir si se rellena o se quita) |
| `/admin/mapa/` | OK | Muy bien resuelto y muy pegado a la maqueta | — |
| `/admin/plantillas/` | Aviso | Funciona bien. En los textos el club se llama «Club Atletismo Apol-Ana» y en el resto de la web «Club Atletismo Apolana» | Nada: hay que decidir cuál es el nombre bueno (ver abajo) |
| `/admin/records/` | OK | No hay ningún récord dado de alta, sale el estado vacío | — |
| `/admin/palmares/` | Aviso | En el palmarés real hay erratas: «Setgio Redondo del Rio» (por Sergio Redondo del Río) y «800ml» (por 800 m lisos). Eso sale en la web pública | Nada: son datos escritos por el club, no los toco sin permiso |
| `/admin/historico/` | OK | Las 13 temporadas reales, con comparativa y gráficos. Bien | — |
| `/admin/importar/` | Aviso | El enlace «← Volver al panel» sale dos veces, igual que pasaba en Atletas | Solo mirar: otra persona está trabajando en esta pantalla |
| `/admin/estadisticas/` | **Roto** | «Atletas activos: **0**» con 175 atletas activos en la base: la consulta buscaba el estado `activa` y en la ficha se guarda `activo`. Los importes de cobros buscaban estados que no existen (`cobrado`, `devuelto`, `listo`) y se dejaban fuera los impagados. Arriba había una nota de desarrollo («requiere permisos de lectura de administración sobre esas tablas») | Corregidos los estados, añadido el contador de lesionados, la cifra de «pendiente de cobro» ahora suma pendientes e impagados, y la nota se ha reescrito en cristiano |

## Portal

| Pantalla | Estado | Qué falla | Qué hice |
| --- | --- | --- | --- |
| `/portal/` | OK | Entrada por rol correcta | — |
| `/portal/atleta/` | Aviso | La primera tarjeta se pegaba al titular y le cortaba la coma de «Hola, Revisor» | Separada la cabecera de la primera tarjeta |
| `/portal/entrenador/` | Aviso | «Hola, Revisor · 0 grupo(s)» | Ahora dice «sin grupos a tu cargo», «1 grupo» o «N grupos» |
| `/portal/familia/` | OK | Con cuenta de administración sale el aviso de «no hay ningún hijo enlazado», que es lo correcto | — |
| `/portal/coordinador/` | **Roto** | En el móvil la tabla de grupos se salía de la pantalla (480 px de tabla en 390 px de móvil) y no había forma de leerla. Además la sección «cubo» salía en crudo | Las dos tablas van dentro de una caja que se desliza a lo ancho, y añadidos los nombres de sección que faltaban |
| `/portal/calendario/` | Aviso | Había dos pastillas de filtro que se llamaban casi igual («Cubo» y «El Cubo») y una sin acentuar («Escuela-natacion») | Añadidos los nombres que faltaban y quitada la pastilla de sección «cubo», que ya tenía la suya propia |
| `/portal/competiciones/` | OK | — | — |
| `/portal/cubo/` | Aviso | En la ficha de la clase ponía «10 PLAZAS» arriba y «2 de 12 plazas» abajo: parecían contradecirse. Y al entrar salía «No hay clases abiertas en estos días» sin decir que sí las hay la semana siguiente | Arriba ahora pone «10 LIBRES»; el mensaje de vacío remite a la pestaña «Siguiente» |
| `/portal/documentos/` | OK | Los tres documentos activos salen agrupados por categoría | — |
| `/portal/calles/` | Aviso | El desplegable de grupo ponía «Fondistas · competicion» | Ahora pone «Fondistas · Competición» |
| `/portal/carga/` | Aviso | Mismo problema en el desplegable de grupo | Igual que en Calles |
| `/portal/lesiones/` | Aviso | Dice «206 disponibles · 0 tocados · 0 de baja · ahora mismo están todos disponibles», pero el inicio del panel avisa de «9 atletas marcados como lesionados». Son dos sitios distintos que no se hablan | Nada: hay que decidir cómo se juntan (ver abajo) |
| `/portal/mensajes/` | OK | No hay ninguna conversación en la base todavía; el estado vacío está bien escrito | — |

---

## Móvil (390 px)

Se han medido las 35 pantallas a 390 px de ancho. **Solo una se salía**: `/portal/coordinador/`,
ya arreglada. El resto no tiene desbordamiento horizontal.

## Textos y acabado

- No hay ni una mención a inteligencia artificial, ni a asistentes, ni textos en inglés, ni
  restos de relleno tipo «lorem ipsum» en ninguna pantalla del panel ni del portal.
- Se han quitado todos los plurales de formulario del tipo «0 grupo(s)» que se encontraron.

---

## Lo que hay que decidir (no lo he tocado)

1. **Inicio del panel a medio hacer.** Están los cuatro contadores y las alertas, pero falta toda
   la columna derecha de la maqueta (accesos rápidos, aviso activo en portada) y la tabla de
   «últimos inscritos». Por eso la pantalla se ve vacía por la derecha.
2. **Lesiones: dos verdades a la vez.** El estado «lesionado» de la ficha del atleta (9 personas)
   y la tabla de lesiones del portal (0 registros) van cada uno por su lado. Hay que decidir cuál
   manda, o hacer que la pantalla de lesiones cuente también a los que tienen la ficha marcada.
3. **Recibos emitidos.** La base de datos, bien hecha, no deja cambiar ni borrar un recibo que ya
   tiene número; solo anularlo con un motivo y emitir un rectificativo. He bloqueado los botones y
   lo he explicado, pero **el panel todavía no tiene la pantalla para anular**: hoy eso solo se
   puede hacer desde la base de datos.
4. **Nombre del club en los correos.** Las plantillas dicen «Club Atletismo Apol-Ana» y toda la web
   dice «Club Atletismo Apolana». Hay que unificarlo con el nombre bueno.
5. **Erratas del palmarés.** «Setgio Redondo del Rio» debería ser «Sergio Redondo del Río», y
   «800ml», «800 m lisos». Sale en la web pública, pero son datos del club y no los cambio sin que
   lo diga el dueño.
6. **Enlace «Volver al panel» duplicado en `/admin/importar/`** (lo está tocando otra persona).
7. **Ventanas de aviso que bloquean el navegador.** Quedan 33 avisos de error hechos con `alert()`
   repartidos por el panel. No es grave para una persona, pero conviene ir cambiándolos por avisos
   dentro de la página, como se ha hecho ya en Cobros.
8. **Cobros carga los 700 recibos de golpe**, sin paginar. Va lento al marcar uno y volver a pintar.
9. **Columna «Tamaño» de Documentos** siempre vacía: o se guarda el peso del fichero al subirlo, o
   se quita la columna.
10. **Grupos**, comparado con la maqueta, aún no tiene turnos con días, plazas, sede, tarifa
    aplicada, responsable ni el interruptor de «admite inscripciones».
