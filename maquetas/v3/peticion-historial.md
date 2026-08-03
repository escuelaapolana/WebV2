# Petición al maquetador · El historial de entrenamientos

## Lo que pide el club

Palabras del entrenador:

> «Yo quiero, como entrenador, hablar con el atleta: mira lo que hicimos hace un mes, hicimos esto y ahora estamos haciendo esto. **Y que él mismo pueda verlo.**»
> «La idea es que él vea su progresión.»

No es una pantalla de consulta: es **la herramienta que hace que un chaval entienda por qué está haciendo lo que hace**. Y eso es lo que hace que siga viniendo en marzo.

## Lo que ya está hecho, para que no lo diseñes de cero

**El historial existe y es completo.** El atleta tiene en su sección de Entrenamiento unas flechas de semana que van hacia atrás **indefinidamente**, con los tiempos que apuntó y sus sensaciones ya rellenos. Se han añadido saltos de mes y una marca en la tira de días para ver de un vistazo qué días apuntó algo.

**Lo que falta no son los datos: es la puerta.** Hoy, para ver «hace un mes» hay que pulsar cuatro veces, y no hay ninguna vista de conjunto.

**Y ya está en tu menú.** En `docs/maquetas-app.md` (línea 552), el menú del atleta que diseñaste es: *Sesión de hoy · Mi semana · **Historial** · Mis marcas · Competiciones · Datos personales*. **No hay que inventarlo: hay que dibujarlo.**

## Lo nuevo que se puede enseñar

Cada entrenamiento tiene ahora **dos etiquetas separadas**, que antes iban revueltas en una:

**Deporte** — Atletismo · Natación · Fuerza · El Cubo. Puede haber **dos** el mismo día (el caso real: pesas y luego series como transferencia).

**Papel del día** — Ajuste · Carga · Impacto · Recuperación · Activación · Tapering · Competición · Descanso · Rehabilitador.

Esos nombres **no son inventados**: son los que el entrenador ya usa en su planificación anual.

Y de ahí sale lo que de verdad quiere el club: que un chaval vea **cuántos días de cada deporte lleva** y **cuánta carga frente a cuánta recuperación**. Ahí está la progresión, no solo en las marcas.

## Lo que hay que resolver

**1 · La pantalla de Historial del atleta.**
- La lista larga hacia atrás, **agrupada por mes**.
- Una línea por entrenamiento: qué día, qué deporte, qué papel del día.
- **La marca de «lo apunté / no lo apunté»**, que es lo que convierte la lista en un espejo de su constancia.
- Qué pasa al tocar uno. *(Importante: no hace falta inventar una vista de «entrenamiento antiguo». El atleta ya tiene la pantalla donde se abre el de hoy —bloques, sus tiempos, sus sensaciones—. Se trata de dejar llegar a ella.)*
- **Y el resumen**: cuántos días de cada deporte, cuánta carga frente a cuánta recuperación. En qué periodo, y cómo se lee sin ser un gráfico de laboratorio.

**⚠️ Un límite que hay que respetar:** la barra de abajo tiene **cinco pestañas y no cabe una sexta**. Así que el Historial va dentro de «Entrenamiento», en «Más», o donde tú decidas — pero no como pestaña nueva.

**2 · El historial del entrenador — y probablemente no es una pantalla.**

Si la maqueta nueva de «Planificar semana» ya lleva navegador `← 8-14 sep →`, **el historial del entrenador es ese mismo navegador andando hacia atrás hasta donde haya datos**.

Lo que habría que resolver ahí:
- Que una **semana pasada** se vea igual que una futura, pero con **el feedback de los atletas al lado**: qué pusiste y cómo les fue.
- **«Duplicar en otra semana»** en cada día. *(El botón «Duplicar» de un entrenamiento suelto ya existe.)*
- Y si eso funciona, **sobra el paso 3 actual** con sus dos desplegables: duplicar pasa a ser «estoy en la semana del 8, la copio a la del 15».

## Contexto que conviene tener

- **Las familias ya no ven el contenido del entrenamiento ni el feedback**, por decisión del club. Esta pantalla es del atleta y del entrenador.
- El club quiere además **entrenamientos por porcentaje** —«3×400 al 85 %», y cada atleta ve sus segundos, calculados desde su mejor marca de los últimos doce meses—. Eso está por montar, pero si el historial va a enseñar entrenamientos, **conviene que quepa un número calculado por atleta** en la misma línea.

---

*Van aparte los formularios de alta y las diez pantallas del panel.*
