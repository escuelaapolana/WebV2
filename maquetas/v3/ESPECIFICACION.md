# Club Atletismo Apolana · especificación de implementación

Documento de trabajo para implementar el diseño con Claude Code. Las maquetas están en
tres archivos que se abren en el navegador:

- `Web Apolana.dc.html` — web pública
- `App Apolana movil.dc.html` — app móvil
- `Admin Apolana.dc.html` — panel de administración

Cada maqueta lleva la URL en la barra del navegador y un id visible (`13a`, `18b`…) para
poder referirse a ella. Repo actual: `escuelaapolana/apolana-club` (GitHub Pages).
Backend: Supabase (ya en uso).

---

## 1. Principio rector

**Un dato se escribe una vez.** La cuota de pista vive en una sola tabla y la leen: la
página de pista, la tabla de precios de la home, «encuentra tu grupo», el alta de socio,
el formulario de inscripción y el recibo. Si cambia 40 → 42, cambia en los seis sitios.
El mapa completo de qué es editable y quién lo edita está en la maqueta `18a`.

---

## 2. Roles y accesos

| Rol | Entra a | Ve |
|---|---|---|
| Visitante (sin cuenta) | web y app | noticias, calendario, secciones, escuelas, campus, precios, inscripción |
| Atleta | app + portal web | su entreno, feedback, marcas, clases y bono, sus pagos |
| Familia | app + portal web | ficha de sus hijos, asistencia, pagos, tienda, inscripciones |
| Entrenador | app + portal web | sus grupos: planificar, pasar lista, leer feedback, cambiar de grupo, dar de baja |
| Coordinador | portal web | todos los grupos de su sección y sus técnicos |
| Administración | admin | cobros, contenido web, estadísticas, usuarios, familias |

Reglas:

- La cuenta se **crea sola al terminar la inscripción**, con su rol, y se envía un correo
  para fijar contraseña (caduca en 72 h). A mano solo se crean técnicos y junta.
- Menores de 14: **no tienen cuenta propia**, la cuenta es de la familia. A partir de 14
  el atleta tiene la suya; la familia sigue viendo pagos y asistencia, no su feedback.
- Un mismo correo puede tener **varios roles** y cambiar de panel sin cerrar sesión.

Maquetas: `19a` (matriz de roles), `19b` (acceso, alta y selector de perfil).

---

## 3. Rutas de la web pública

| Ruta | Maqueta | Notas |
|---|---|---|
| `/` | `3b` | hero, selector de perfil, formas de entrenar, precios, mosaico, Instagram, noticias |
| `/club` | `7a` | hub corto |
| `/club/historia` | `7b` | cronología |
| `/club/normativa` | `7c` | documentos descargables |
| `/club/palmares` | `7d` | |
| `/club/records` | `7e` | tabla de récords del club |
| `/competicion` | `13a` | atletismo en pista · 4 grupos |
| `/running` | `4b` | Madre Tierra y La Tribu |
| `/natacion` | `13b` | bonos de 4, 8 y 12 clases |
| `/triatlon` | `14a` | sin entrenador: solo cuota de socio |
| `/montana` | `14b` | licencia FEMECV, salidas |
| `/cubo` | `12d` | 4 modalidades de uso |
| `/instalaciones` | `14c` | 4 sedes |
| `/escuela` | `9a` | escuela de atletismo |
| `/escuela-natacion` | `9b` | escuela de natación |
| `/escuela-municipal-atletismo` | `9c` | programa del Ayuntamiento |
| `/campus` | `16a` | cartel, tarifas 5×8, horario semanal |
| `/calendario` | `4c` | mismos datos que la app |
| `/noticias`, `/noticias/:slug` | `6a`, `6b` | |
| `/socio` | `12b` | alta de socio y coste total |
| `/familias` | `19c` | Familia Apolana y calculadora |
| `/inscripcion` | `12c` | 3 pasos + pasarela |
| `/contacto` | `6d` | |
| `/tienda` | `6e` | solo socios; 13 productos |

Mapa de enlaces y estados: `12a`.

---

## 4. Modelo de datos (Supabase)

Tablas mínimas, nombres orientativos:

- `personas` — nombre, apellidos, fecha_nac, dni, email, teléfono, `familia_id`, roles[]
- `familias` — domicilio, cuenta de cobro (IBAN + mandato), miembros
- `secciones` — pista, running, natación, triatlón, montaña, cubo, escuelas
- `grupos` — sección, nombre, tramo de edad, plazas, sede, `tarifa_id`, responsable,
  `admite_inscripciones` (bool)
- `turnos` — grupo, días[], hora_inicio, hora_fin
- `tarifas` — concepto, precio_socio, precio_no_socio, periodicidad (mensual /
  trimestral / temporada / única), vigencia_desde
- `inscripciones` — persona, grupo, temporada, estado (prueba / activa / baja), origen
  («¿cómo nos conociste?»)
- `asistencias` — turno, fecha, persona, estado (presente / falta / avisó), quién la pasó
- `sesiones` — grupo, fecha, bloques (calentamiento / principal / vuelta a la calma)
- `feedback` — sesión, persona, sensaciones, RPE, **ritmos por serie**, comentario
- `marcas` — persona, prueba, valor, fecha, tipo (entrenamiento / competición), lugar
- `eventos` — competiciones, salidas de montaña, quedadas; con cierre de inscripción
- `inscripciones_evento` — evento, persona, estado, importe
- `clases` — El Cubo: fecha, hora, entrenador, plazas
- `reservas_clase` — clase, persona, estado; descuenta uso de bono
- `bonos` — persona, usos totales, usos restantes, caducidad
- `recibos` — persona o familia, concepto, importe, cuenta (escuela / club), estado
  (listo / cobrado / devuelto), mandato
- `contenido` — bloques editables de la web (textos, cabeceras, FAQ, normativa)
- `imagenes` — biblioteca: archivo, etiquetas[], recortes por formato
- `huecos` — hueco de la web → imagen asignada + formato
- `avisos` — aviso de portada con nivel (informativo / importante / urgente) y caducidad
- `plantillas` — emails y notificaciones automáticas

**Dos cuentas bancarias distintas**: escuela y club. Los recibos se giran en remesas
separadas (maqueta `11c`).

---

## 5. Reglas de negocio

### Cuotas

- Socio del club: **120 €/año** por adulto. No lleva descuento nunca.
- Pista: 40 €/mes (3 días) o 55 €/mes (5 días) para socios, **pago trimestral**;
  70 €/mes para no socios, y la entrada al estadio va por su cuenta.
- Al grupo **Velocidad A se accede por decisión del club**, no se elige al inscribirse.
- Running: Madre Tierra 40 €/mes, La Tribu 60 €/mes.
- Natación adultos: bonos de 4 / 8 / 12 clases al mes → 35 / 45 / 55 € socios y
  50 / 60 / 70 € no socios. Sin ser socio se puede empezar pagando +15 €/mes, y ese
  suplemento se descuenta del alta hasta tres meses.
- Montaña: incluida en la cuota de socio, con licencia FEMECV aparte.
- Triatlón: **la sección no tiene entrenador**, así que no hay mensualidad; se entrena
  con los grupos de natación y de pista.
- El Cubo: padres 40 €/mes, o 30 €/mes si su hijo está en la escuela; socios en franjas
  de mañana; alumnos de la escuela incluido; alquiler a grupos a consultar.
- Escuela de atletismo: dos pagos de temporada, no mensualidad.
- Campus: matriz de 5 filas (semanas) × 8 combinaciones, de 99 € a 1.125 €. Comedor
  42 €/semana por persona; matinera 12 €/semana **por familia**. Pago por transferencia
  en tres modalidades (100 % en 10 días · 50 %+50 % antes del 15 de mayo · tres o cuatro
  cuotas si pasa de 350 €, con 150 € de reserva).

### Familia Apolana

- 2.º adulto de la familia: −10 % en su cuota de entrenamiento. 3.º y siguientes: −15 %.
- Hermanos en la escuela: −20 % el segundo, −40 % el tercero.
- Padre o madre con hijo en la escuela: 30 €/mes en El Cubo y precio de socio en natación.
- **No se acumulan**: se aplica el más favorable.
- Solo afectan al entrenamiento, nunca a la cuota de socio ni a la ficha federativa.
- Si un miembro se da de baja, el descuento se mantiene **hasta final de temporada**.
- Unidad familiar = mismo domicilio y misma cuenta de cobro.
- **Ajuste excepcional**: la junta puede fijar una cuota distinta caso por caso; queda
  registrado con importe, motivo y quién lo aprobó.
- Un solo recibo familiar al mes, con desglose por persona.

### Bonos de El Cubo

- El uso se descuenta **al empezar la clase**, no al reservar.
- Cancelar con más de 3 horas devuelve el uso.
- Lista de espera cuando la clase está completa.

### Periodo de prueba

- Cuatro entrenamientos gratis. El atleta aparece en la lista del entrenador marcado
  como «de prueba · día N de 4».
- Al acabar, el entrenador confirma el alta desde su ficha.

### Avisos automáticos

Se envían solos: inscripción completada (con credenciales), recibo cobrado, recibo
devuelto (con enlace de pago), entrenamiento suspendido, recordatorio de competición
48 h antes, cierre de inscripción 5 días antes, fin del periodo de prueba, tres faltas
sin avisar, ropa lista para recoger. Plantillas editables en `20a`.

Alertas al admin cuando: cae la renovación de un grupo, sube el impagado, un atleta lleva
tres faltas seguidas, un grupo baja del 60 % de asistencia.

---

## 6. App móvil

Pantallas ya diseñadas: acceso y modo público, selector de perfil y notificaciones, hoy,
entreno del día por bloques con confirmación de asistencia, **feedback con ritmos por
serie**, calendario mensual y agenda del día, marcas y gráfica de progresión con filtro
entrenamiento/competición, clases abiertas de El Cubo con apuntarse y desapuntarse, bono
de usos con historial, y panel del entrenador (pasar lista + ficha del atleta con cambio
de grupo, alta, lesión, mensaje a la familia y baja).

La app y la web **leen lo mismo**: noticias, calendario, precios y horarios salen de las
mismas tablas.

---

## 7. Estadísticas

Cuadro de mando en `15b`, `17a` y `17b`:

- Socios, % chicas/chicos, altas nuevas, renovaciones, atletas por categoría, hermanos,
  familias que también usan El Cubo.
- Ingresos por mes de escuela y club, impagado en € y en %, ingreso medio por atleta.
- Asistencia media por grupo (sale de la lista del entrenador).
- Origen de las altas (desplegable «¿cómo nos conociste?» en la inscripción) y embudo de
  la prueba: reservan → vienen → terminan → se quedan.
- Retención por cohorte: de cada 100 que entran, cuántos siguen al año, a los dos, a los tres.
- Carga por entrenador: atletas, grupos, horas semanales, feedback sin contestar.
- Informe de una página para la asamblea, generado con un botón.

---

## 8. Contenido editable desde admin

Todo lo que aparece en la web se edita en el panel: tarifas, grupos y horarios,
responsables, junta, campus (incluido **el cartel de la edición**), noticias, eventos,
aviso de portada, tienda, historia, normativa, palmarés, récords, FAQ, instalaciones,
textos legales, plantillas de email, reglas del test «encuentra tu grupo» y umbrales de
alertas.

Imágenes: **biblioteca común** (`10a`) con etiquetas, buscador, filtro de «sin usar» y
recorte por formato; cada hueco de la web elige de la biblioteca (`10b`). Instagram se
lee del feed de @apolana.alicante, no se sube a mano.

---

## 9. Pendiente de datos reales

- Precios de la tienda (los cambia el club desde admin).
- Programas municipales de triatlón y deporte adaptado: edades, sedes, días, horarios y
  precio. **Los adjudica el Ayuntamiento y se conocen en septiembre.**
- Fotos: Miguel Á. Pellín, Enrique Gallego y José Fernández (junta), y las cuatro del
  campus (pádel, talleres, piscina, excursión).
- Repaso de textos por parte del club: hay copy de trabajo, sobre todo frases entre
  comillas atribuidas a entrenadores.
