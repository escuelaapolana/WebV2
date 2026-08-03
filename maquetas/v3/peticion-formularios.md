# Petición al maquetador · Los formularios de alta

## Lo primero: esto no hay que inventarlo

El club **ya tiene funcionando** dos formularios en Google Forms —**inscripción nueva** y **renovación** de la escuela— con todo lo que se pregunta y cómo se pregunta. Lo que hace falta no es decidir qué datos se piden, sino **diseñarlos bien y traerlos a la web**.

Faltan además dos que hoy **no existen en ninguna parte**: el de **hacerse socio** y el de **domiciliación bancaria (SEPA)**.

Lo único que hay hoy en la web, en `/inscripcion/`, es un «déjanos tus datos y te llamamos». Todo lo demás vive en Google Forms, en papel o en WhatsApp.

## El contexto

- Club de atletismo de Alicante, unos **200 atletas**. Hay adultos, pero la mayoría son niños: quien rellena esto casi siempre es un padre o una madre, **con el móvil**.
- **La web ya está hecha y funciona**: ocho páginas de sección con plantilla común, dos páginas que reparten (`/entrenar/` y `/escuelas/`), portal del socio y panel de gestión. Los formularios tienen que parecer de la misma casa.
- **Los datos salen de la base y se editan desde el panel.** Precios, horarios, grupos y contactos ya funcionan así.
- Dentro del portal hay un patrón que al club le convence y sirve de vocabulario: **tarjetas azules en degradado**, línea fina de contexto arriba, título grande, y abajo un botón blanco sólido para la acción principal y otro perfilado para la secundaria.

---

## 1 · Inscripción a la escuela (nueva)

Hoy son **siete pantallas** en Google Forms:

**1 · El alumno** — correo · nombre y dos apellidos · sexo · DNI (*«si no tiene, ponga un 0»*) · **SIP / tarjeta sanitaria** · fecha de nacimiento (*«muy importante para que no haya errores en la distribución de los grupos»*) · **turno** · ¿se apunta también un hermano?

Los cuatro turnos, tal cual:
- Lunes y miércoles 17:30–18:30 *(nacidos entre 2023 y 2015)*
- Martes y jueves 17:30–18:30 *(nacidos entre 2023 y 2015)*
- Lunes y miércoles 18:30–20:00 y viernes 17:30–19:00 *(nacidos entre 2014 y 2008)*
- Martes y jueves 18:30–20:00 y viernes 17:30–19:00 *(nacidos entre 2014 y 2008)*

**2 · El padre, madre o tutor** — nombre y dos apellidos · DNI · dirección · código postal · localidad · móvil (*«se añadirá al grupo informativo de WhatsApp»*) · cómo se enteró de la escuela.

**3 · Equipación** — foto de la camiseta de la temporada, talla de camiseta y talla de sudadera.

**4 · Protección de datos** — texto legal del RGPD y tres autorizaciones por separado: tratamiento de datos, envío de información de otras actividades, y **toma de fotografías y vídeo**.

**5 · Condiciones** — declara que la inscripción es por temporada completa y que **no hay devoluciones**; acepta cuotas y condiciones; y elige **pagar la cuota en uno o en dos pagos**.

**6 · Cuenta bancaria** — el IBAN completo.

**7 · Observaciones** — texto libre.

## 2 · Renovación (quien ya estaba)

Cuatro pantallas: los datos del alumno otra vez, **solo la talla de camiseta**, las condiciones con el pago en uno o dos plazos, y observaciones.

**No vuelve a pedir**: los datos del padre o tutor, el SIP, las autorizaciones de protección de datos ni el IBAN.

**Y aquí está el problema más claro de los dos formularios:** una familia que renueva por tercer año **vuelve a escribir el nombre, los apellidos, el sexo, el DNI y la fecha de nacimiento de su hijo**, datos que el club ya tiene desde el primer día. Renovar debería ser **confirmar lo que ya hay y decir qué cambia** —el turno, la talla, cómo se paga—, no rellenar una ficha desde cero.

## 3 · Alta de socio

Existe en Google Forms y **es el más largo de todos**. Hoy pide, en una sola pantalla:

Nombre y dos apellidos · sexo · DNI/NIE/NIF · **nacionalidad** · **ciudad, provincia y país de nacimiento** · fecha de nacimiento · domicilio, localidad, código postal y provincia · móvil (*«se añadirá al grupo de WhatsApp informativo»*) · correo · en qué sección se da de alta (atletismo y ruta, montaña y trail, triatlón, natación) · tallas de camiseta, pantalón y calcetín · **peso** · **estatura** · **foto tipo carné** · **DNI escaneado por delante** · **DNI escaneado por detrás** · **IBAN**.

Y además, según la propia web del club, para completar el alta hay que: rellenar este formulario, rellenar el SEPA, **hacer un ingreso de 125 €** en la cuenta del club con el concepto «alta socio + nombre y apellidos», y **enviar el justificante por correo**.

**Aquí hay tres cosas que resolver, y son de fondo:**

- **Es una pantalla larguísima y sin pasos.** Todo de golpe, incluidas tres subidas de archivo. En el móvil eso es mucha gente que lo deja a medias.
- **Se piden datos muy sensibles**: el DNI escaneado por las dos caras, una foto de la cara, el peso y la estatura. Peso y estatura suenan a ficha federativa, y el DNI a trámite de federación — pero conviene **preguntarse cuáles hacen falta de verdad para ser socio** y cuáles solo si además te federas. Cada uno de esos datos hay que custodiarlo.
- **El circuito acaba fuera de la web**: transferencia manual y justificante por correo. Ahí se pierde gente y se pierde el rastro de quién ha pagado.

**Y lo que más confunde:** hoy «hacerse socio» y «apuntarse a un grupo» son dos cosas distintas y la gente las mezcla. Un adulto que quiere correr tiene que ser socio **y** elegir grupo; un padre que apunta a su hijo a la escuela **no** se hace socio por ello. Hay que dejarlo claro sin dar una clase de organigrama.

Dos condiciones del alta que hoy están escritas en la página y conviene que se vean donde toca: la **obligación de federarse** en montaña y triatlón (aconsejable en el resto), y la **obligación de coger cinco décimos de lotería de Navidad** o pagar 15 € como donación, que se cobra por recibo del 1 al 15 de diciembre.

## 4 · Domiciliación bancaria · SEPA

Existe en Google Forms, y **está incompleto de una forma que importa.**

Hoy pide solo: nombre del titular, dirección del titular, tipo de pago (recurrente) y la aceptación del texto legal.

**No pide el IBAN, ni la fecha, ni la firma, ni el lugar de firma.** Una orden de domiciliación sin esos cuatro campos no es una orden de domiciliación: es una declaración de intenciones. Si mañana un socio reclama un cobro, ese documento no sostiene nada. El IBAN se recoge, sí, pero **en el otro formulario**, separado del mandato que debería contenerlo.

*(El CIF correcto del club es **G-03845500**. En el formulario de SEPA actual aparece como `G0384500`, al que le falta un dígito, y va en un documento con valor legal. En la web está bien en todas partes.)*

**Hay que rehacerlo partiendo del formato oficial de orden SEPA**, con todos sus campos obligatorios y los datos del club como acreedor.

**Y es el punto más delicado de todo el encargo.** El formulario de la escuela pide el IBAN acompañado de este párrafo, escrito por el club:

> «No tengáis "miedo" de poner los datos bancarios, porque en ningún caso se hará un cobro sin el consentimiento previo y la firma de la autorización SEPA. Si finalmente el alumno/a no se apunta, borramos todos vuestros datos.»

Ese párrafo existe porque **ahí la gente se pone nerviosa y algunos abandonan**. Es el momento de más desconfianza de toda la web, y muchos lo rellenan desde el móvil.

**Tres decisiones que hay que tomar:**
- **Cómo se firma**: en pantalla, descargando para imprimir, o las dos. Tiene consecuencias legales.
- **Titular y atleta no son la misma persona**, casi nunca. Paga el padre, entrena el hijo, y a veces un mismo titular paga por tres hermanos en un solo recibo. Eso hay que verlo claro **antes** de firmar.
- **Cuándo se pide.** Hoy el IBAN va dentro de la inscripción, antes de saber si el niño se queda. Puede que tenga más sentido después del periodo de prueba.

---

## Lo que atraviesa los cuatro

- **Móvil primero.** La mayoría entra por el móvil, algunos a pie de pista y con prisa.
- **Los hermanos.** Los dos formularios preguntan si hay hermano, pero **no lo resuelven**: hay que rellenar todo otra vez desde cero. Muchas familias apuntan a dos o tres a la vez. Es de lo que más agradece un padre.
- **Son datos de menores**: nombres, fechas de nacimiento, DNI, tarjeta sanitaria, teléfonos, autorizaciones. Cuanto menos se pida, mejor: cada campo de más es un dato que hay que custodiar.
- **Se dejan a medias.** Alguien empieza, le llaman, y vuelve. Hay que decidir si se guarda el avance y cómo se retoma.
- **Qué pasa al terminar, y esto lo pide el club expresamente:** que al enviar **llegue un correo de confirmación con las respuestas** y con la certeza de que se ha enviado bien. Ese correo es además su comprobante: qué ha pedido, en qué turno, con qué talla y con qué forma de pago. Hay que diseñar **qué dice y qué aspecto tiene**, porque para muchas familias va a ser el único papel que les quede del trámite. Y decidir también **cómo se entera el club**.

  El club **ya manda uno** y sirve de punto de partida. Dice, en resumen: gracias por la preinscripción · el día que empiezan las pruebas y los entrenamientos, y en qué estadio · **qué hay que traer** (ropa deportiva, calzado deportivo y una botella de agua con su nombre, para los más pequeños) · **por dónde se entra**, con enlace al mapa · los horarios de los dos grupos por año de nacimiento · dónde consultar precios y condiciones · y la firma del coordinador con su teléfono.

  **Y ahí está el fallo que hay que resolver.** Para saber en qué grupo ha caído su hijo, la familia recibe unos enlaces a listas, con este aviso: *«No se actualiza automáticamente, por lo que recomendamos revisar el enlace el día anterior a su primer entrenamiento»*. Es decir: alguien del club mantiene esas listas a mano, y la familia tiene que acordarse de volver a mirar. **Eso debería ser una línea en el portal**: «tu hijo está en el grupo verde 2, lunes y miércoles», siempre al día. Ahorra trabajo al club y quita llamadas.
- **La escuela municipal.** Es un programa del ayuntamiento que empieza en octubre; la familia paga al ayuntamiento y **el niño entrena en los grupos normales del club**, con los mismos compañeros, viniendo dos días. No es una escuela aparte: es otra forma de entrar. Si el formulario deja elegir esa vía, tiene que quedar claro que acaba en el mismo sitio.

## Cómo se reparten los grupos, para que el formulario tenga sentido

Primera hora, de 3 a unos 11 años, en **nueve grupos de color**: rojo 1, 2 y 3 · azul 1, 2 y 3 · verde 1, 2 y 3. Rojo 1 los más pequeños, verde 3 los mayores.

**El color lo da el año de nacimiento** —como en todo el atletismo— y **el número lo da el turno** que elige la familia. Así que el grupo debería salir solo al poner la fecha de nacimiento y el turno, y el club poder cambiarlo después a mano.

**Y ojo con esto, que hoy es un fallo:** la edad **obliga** a una franja horaria. Un niño nacido en 2023 tiene que ir a la de 17:30–18:30; no puede elegir la de 18:30–20:00. Lo único que elige la familia es **el día**: lunes y miércoles, o martes y jueves.

El formulario actual **enseña los cuatro turnos a todo el mundo**, así que se puede marcar el que no corresponde sin que nada lo impida; alguien lo detecta después y hay que llamar a la familia. **Al poner la fecha de nacimiento deberían quedar solo las dos opciones posibles.**

De esos mismos niños sale además un grupo de competición a primera hora (Sub-14 de primer año, Sub-12 y Sub-10).

## Qué necesitamos de ti

El diseño de las pantallas: los pasos, qué se pregunta en cada uno y en qué orden, cómo se ven los errores, y qué ve la persona al terminar.

Y en particular estas cuatro:
1. **Cómo se firma el SEPA** y cuándo se pide el IBAN.
2. **Cómo se resuelve lo de los hermanos.**
3. **Cómo es renovar** sin volver a escribirlo todo.
4. **Qué autorizaciones van dentro del formulario y cuáles siguen siendo PDF** — el club ya tiene tres documentos que las familias firman (imagen y datos, normas, premios) y no hay que pedir lo mismo dos veces.

---

*Va aparte la petición sobre la página del grupo de competición, y las diez pantallas del panel que se hicieron sin maqueta.*
