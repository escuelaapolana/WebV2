# Auditoría de seguridad · RLS de la base de datos (Supabase)

**Fecha:** 2026-08-01
**Alcance:** Row Level Security de las 49 tablas públicas, funciones `security definer`, vistas, triggers y Storage.
**Método:** ataques reales con `psql`, encarnando a cada rol dentro de una transacción con `ROLLBACK` (`set local role` + `set local request.jwt.claims`). Nada teórico: cada hallazgo lleva el SQL que lo demuestra.

**Recordatorio del modelo de amenaza:** la web es estática y lleva la clave *publishable* en el navegador de todos. Cualquiera puede abrir la consola y lanzar estas mismas consultas. La ÚNICA barrera es la RLS de Postgres. Todo lo que aquí se prueba es exactamente lo que puede hacer un usuario (o un visitante sin cuenta) desde el navegador.

Cuentas usadas para atacar (nunca las de admin):
- Atleta `atleta.prueba@apolana.test` — `ed818f4e-b1aa-4364-8b20-2c27762247ca` (su ficha: `2ac18ce3-…`, sección natación).
- Atleta `atleta2@apolana.test` — `63f45c0c-…`.
- Entrenador `andres.apolana@gmail.com` — `c5c2958a-…` (dirige el grupo *Velocidad · Sub-20*).
- Visitante ANÓNIMO (`set local role anon`, sin claims).
- Víctima ajena de ejemplo: atleta "Candela" `dddddddd-0003-4000-8000-000000000035` (entrenador distinto).

---

## Resumen de gravedad

| Nº | Hallazgo | Tabla/función | Quién lo explota | Gravedad |
|----|----------|---------------|------------------|----------|
| 1 | Vistas sin `security_invoker` saltan la RLS y las lee hasta un anónimo | `sesiones_agenda`, `cubo_clases_ocupacion` | Anónimo / cualquiera | **ALTA** |
| 2 | Cualquier entrenador es "gestor" de todo El Cubo (lee y escribe bonos/reservas/movimientos/clases de todos) | `cubo_es_gestor()` + políticas del Cubo | Entrenador | **ALTA** |
| 3 | El socio fija a voluntad el precio de las líneas de su pedido | `pedido_items` (`precio_unitario`), `pedidos.total` | Atleta/familia (socio) | **MEDIA** |
| 4 | `UPDATE` de `perfiles` sin `WITH CHECK`: solo un trigger evita la escalada | política `escritura_propia` en `perfiles` | Atleta/entrenador | **BAJA** (defensa en profundidad) |
| 5 | La familia/atleta puede leer y REESCRIBIR su entrevista inicial (incluido `notas`) | `entrevista_inicial` | Atleta/familia | **BAJA** |
| 6 | Cualquier autenticado ve todos los documentos de visibilidad `socios` (sin filtro por familia) | `documentos` | Cualquier usuario con cuenta | **BAJA** |
| 7 | La mediateca (bucket `imagenes`) es pública y enumerable | Storage `imagenes` | Anónimo | **BAJA** |
| 8 | Incoherencias de políticas (duplicadas, `eventos`/`productos` con lectura pública que anula la de "logueados") | varias | — | **BAJA** (higiene) |

**Total: 0 críticas · 2 altas · 1 media · 5 bajas.**
Sin críticas: el agujero de escalada a admin que se tapó (`trg_perfiles_protege_rol`) **aguanta** todos los rodeos probados (ver «Lo que SÍ aguanta»).

---

## Detalle de los hallazgos

### 1 (ALTA) · Vistas sin `security_invoker` = RLS saltada, incluso para anónimos

`sesiones_agenda` y `cubo_clases_ocupacion` son propiedad de `postgres`, tienen `SELECT` concedido a `anon` y `authenticated`, y **no** llevan `security_invoker=on` (a diferencia de `bono_saldo`, `cubo_bono_saldo` y `tarifas_vigentes`, que sí lo llevan). Por tanto se ejecutan con los privilegios del dueño y **no aplican la RLS** de las tablas base.

**Demostración (anónimo, sin cuenta):**
```sql
begin; set local role anon;
select (select count(*) from sesiones)               as tabla_rls,     -- 0  (RLS correcta)
       (select count(*) from sesiones_agenda)        as vista_agenda,  -- 330 (¡fuga!)
       (select count(*) from cubo_clases_ocupacion)  as vista_cubo;    -- 55  (¡fuga!)
select sesion_id, fecha, hora, titulo, grupo, seccion, lugar from sesiones_agenda limit 3;
rollback;
```
Un atleta corriente ve por la tabla `sesiones` 55 filas (su grupo), pero por `sesiones_agenda` ve **330** (todos los grupos).

**Qué consigue el atacante:** cualquier visitante de Internet (sin registrarse) obtiene el calendario completo de entrenamientos de todos los grupos —fecha, hora, título, grupo, sección, **lugar** y plazas/ocupación— y la ocupación de todas las clases de El Cubo con el nombre del monitor. La tabla base niega esto al anónimo; la vista lo regala. Es el caso de libro «vista sin `security_invoker`».

*Nota:* no filtra nombres de atletas ni `atletas_ids` (la vista excluye sesiones individuales cerradas), por eso es ALTA y no crítica. Pero es una brecha de RLS limpia y trivial de explotar.

---

### 2 (ALTA) · `cubo_es_gestor()` convierte a CUALQUIER entrenador en gestor de todo El Cubo

```sql
-- cubo_es_gestor() = es_admin() OR rol in ('admin','coordinador','entrenador')
```
Todas las políticas de El Cubo (`cubo_bonos`, `cubo_reservas`, `cubo_movimientos`, `cubo_clases`) usan `cubo_es_gestor()` como `USING`/`WITH CHECK` para el acceso `ALL`. Como devuelve `true` para todo entrenador (no solo para el responsable del Cubo), **cualquiera de la decena de entrenadores del club puede leer y escribir los datos de El Cubo de todos los miembros** (muchos de ellos adultos ajenos a su sección).

**Lectura (entrenador `andres`, que NO tiene nada que ver con El Cubo):**
```sql
begin; set local role authenticated;
set local request.jwt.claims to '{"sub":"c5c2958a-2ba0-4f8f-aaaf-8a796bd22eec","email":"andres.apolana@gmail.com","role":"authenticated"}';
select cubo_es_gestor(),                          -- t
       (select count(*) from cubo_bonos),         -- 71
       (select count(*) from cubo_reservas),      -- 418
       (select count(*) from cubo_movimientos);   -- 470
select atleta_id, count(*) from cubo_movimientos group by atleta_id limit 3;  -- historial de saldo de cualquiera
rollback;
```
**Escritura (mismo entrenador crea una clase pirata):**
```sql
begin; set local role authenticated; set local request.jwt.claims to '{...andres...}';
insert into cubo_clases (id, fecha, hora_inicio, plazas, activa, titulo)
  values ('cccccccc-0000-4000-8000-000000000001', current_date+3, '10:00', 5, true, 'clase pirata'); -- OK
rollback;
```
(El intento de crear una reserva ajena solo se frenó por la lógica de saldo del bono `No te quedan usos…`, no por RLS; con un bono con usos, pasaría.)

**Qué consigue el atacante:** leer el historial de reservas y el saldo de bonos de todos los miembros de El Cubo, crear/editar/desactivar clases, y —vía las políticas `ALL`— regalar o descontar usos y cancelar reservas ajenas. Puede ser una decisión de diseño (que el equipo técnico gestione el Cubo en bloque), pero hoy es un privilegio demasiado amplio: entrenar atletismo no debería dar mando sobre la facturación y las reservas de El Cubo.

---

### 3 (MEDIA) · El socio pone el precio de su propio pedido

`pedido_items` deja crear líneas con `WITH CHECK es_mi_pedido(pedido_id)`, pero **no valida `precio_unitario` contra `productos.precio`**, y `pedidos.total` también lo escribe el cliente. No hay trigger que recalcule importes.

```sql
begin; set local role authenticated;
set local request.jwt.claims to '{"sub":"ed818f4e-…","email":"atleta.prueba@apolana.test","role":"authenticated"}';
insert into pedidos (id, perfil_id, estado, total)
  values ('aaaaaaaa-0000-4000-8000-000000000001','ed818f4e-…','pendiente', 999);
insert into pedido_items (pedido_id, producto_id, cantidad, precio_unitario)
  values ('aaaaaaaa-0000-4000-8000-000000000001', (select id from productos limit 1), 10, 0.01)
  returning pedido_id, cantidad, precio_unitario;   -- 10 uds a 0,01 €
rollback;
```
**Qué consigue el atacante:** encargar productos a un precio inventado (p. ej. 0,01 €). **Atenuante:** el pedido nace en estado `pendiente` y lo procesa un admin (el socio NO puede marcarlo `pagado`, ver «aguanta»). El riesgo real es que la administración cobre confiando en el `total`/`precio_unitario` guardados. Conviene recalcular importes en el servidor a partir de `productos.precio`.

---

### 4 (BAJA · defensa en profundidad) · `UPDATE` de `perfiles` sin `WITH CHECK`

La política `escritura_propia` es `UPDATE … USING (auth.uid()=id)` **sin `WITH CHECK`** (Postgres reutiliza el `USING`, que solo mira el `id`). Es la misma familia del fallo ya corregido. Hoy NO se explota porque el trigger `trg_perfiles_protege_rol` (BEFORE UPDATE) reescribe `id/email/rol/seccion/activo` a sus valores antiguos para quien no sea admin. Se probó el `UPDATE` directo y el rodeo `INSERT … ON CONFLICT DO UPDATE`; **ambos quedan neutralizados por el trigger** (ver «aguanta»).

**Por qué se anota igualmente:** la política, por sí sola, permite cambiar cualquier columna; toda la seguridad recae en el trigger. Si algún día se altera/elimina el trigger, la escalada vuelve. Lo suyo es añadir un `WITH CHECK` que fije `rol`, `seccion`, `activo` y `email` (cinturón + tirantes).

---

### 5 (BAJA) · La familia/atleta lee y reescribe su entrevista inicial

`entrevista_inicial` da al atleta/familia `SELECT`, `INSERT` y `UPDATE` sobre su propia ficha (`atleta_id in mis_atletas()`), incluido el campo libre `notas`.

```sql
begin; set local role authenticated; set local request.jwt.claims to '{...atleta.prueba…}';
insert into entrevista_inicial (atleta_id, motivo, notas)
  values ('2ac18ce3-…','x','texto que la familia puede ver y sobrescribir');  -- OK
rollback;
```
No puede tocar la de otro atleta (probado: `violates row-level security policy`). Probablemente es un formulario de admisión pensado para que lo rellene la familia, así que **es BAJA**. Solo hay que tener claro que `entrevista_inicial.notas` NO sirve para apuntes reservados del staff (para eso está `notas_atleta`, que sí es privada).

---

### 6 (BAJA) · Documentos `socios` visibles para cualquier autenticado

La política `socios leen documentos` es `visibilidad in ('publico','socios')` para todo `authenticated`, sin distinguir familia ni si está al corriente de pago. Cualquier usuario con cuenta ve todos los documentos de socios del club. No se pudo probar con datos reales (en la demo solo hay documentos `publico`), así que se documenta como observación de diseño. Aceptable si esos documentos son de alcance club; problemático si alguna vez se sube ahí algo dirigido a una familia concreta.

---

### 7 (BAJA) · Mediateca pública y enumerable

Solo el bucket `imagenes` es público (`public=t`); contiene la carpeta `biblioteca/` (28 imágenes de contenido/noticias). Los buckets sensibles —`fotos-atletas`, `productos-tienda`, `noticias`, `imagenes-club`— son privados, y el anónimo **no** puede listarlos (probado: 0 filas). Bien.

El único matiz: cualquiera puede **listar y descargar** toda la mediateca pública, incluidas fotos subidas que aún no estén publicadas en ninguna noticia. Si ahí se suben fotos de menores antes de tiempo, quedan accesibles. Riesgo bajo, pero conviene no usar el bucket público como cajón de subidas.

---

### 8 (BAJA · higiene) · Políticas duplicadas e incoherentes

- Muchas tablas tienen dos políticas admin idénticas (`admin gestiona` + `admin gestiona todo`), y `noticias`/`eventos`/`pagos`/`productos`/`pedidos` mezclan la versión basada en `es_admin()` con otra basada en `EXISTS(perfiles p WHERE p.id=auth.uid() AND p.rol='admin')`. Es redundante y confuso (dos formas de identificar al admin: por `email` y por `auth.uid()`).
- `eventos` tiene a la vez `lectura publica (true)` y `Eventos visibles logueados (auth.uid() is not null)`. Como las políticas son permisivas (OR), gana `true`: el anónimo ve los 12 eventos aunque la segunda política sugería que debían ser solo para logueados. Igual en `productos` (`lectura publica true` convive con `Productos visibles logueados`). Revisar cuál es la intención.

No son agujeros, pero conviene limpiarlas para que la RLS sea legible y no se cuele un permiso de más en el futuro.

---

## Lo que SÍ aguanta (ataques probados y bloqueados)

Todo esto se intentó de verdad con `psql` y quedó **bloqueado**:

- **Escalada de rol (el agujero ya tapado):**
  - `update perfiles set rol='admin'` como atleta → el trigger deja `rol=atleta`.
  - `update perfiles set seccion=…, activo=…` → revertido por el trigger.
  - `insert … on conflict (id) do update set rol='admin', seccion=…` → revertido por el trigger.
  - `update perfiles … where rol='admin'` (tocar a otro) → 0 filas (RLS `auth.uid()=id`).
- **Lectura de datos ajenos (confidencialidad):** como atleta, `pagos`, `marcas_atleta`, `atletas` (con `dni`/teléfonos), `perfiles` de terceros → **0 filas** en cada caso (solo ve lo suyo). El anónimo ve 0 en `atletas`, `perfiles`, `pagos`, `sesiones` (tabla base).
- **Entrenador confinado a sus atletas:** `andres` no ve el `dni`/teléfono de atletas ajenos (0 filas), no puede escribir `notas_atleta` de otro, no puede crear `pagos` a otro, y no puede robar un atleta (`update atletas set entrenador_id=self` → 0 filas; el trigger `atletas_cambios_del_entrenador` además restringe las columnas).
- **Integridad económica del socio:** no puede marcar su pedido como `pagado` (`update pedidos set estado='pagado'` → 0 filas; no hay política de UPDATE para socio), ni crear un pedido a nombre de otro perfil (`violates RLS`).
- **Recibos/pagos:** el trigger `pagos_protege` impide borrar/renumerar/alterar recibos ya emitidos y exige la vía `anular_recibo()` para anular.
- **Regalarse saldo:** `insert into bono_movimientos …` y `insert into cubo_movimientos …` como atleta → `violates RLS`.
- **Colarse en entrenamientos:** apuntarse a sesión cerrada → `Ese entrenamiento no está abierto`; a otra sección → `es solo para: …`; apuntar a un atleta ajeno → bloqueado; la ocupación/plazas la vigila el trigger `sesion_inscripciones_control` (con `advisory lock`). El Cubo replica el patrón con `cubo_reservas_control`.
- **Mensajería:** `insert into mensajes_directos` hacia un perfil con el que no se puede hablar → `violates RLS` (`puedo_hablar_con`). Solo deja escribir a su entrenador / administración.
- **Funciones `security definer`:** `estado_cuentas()` devuelve **0 filas** a atleta y a entrenador (filtra por `es_admin()` dentro). `contacto_familia_atleta()` exige `soy_staff_de_atleta`.
- **Storage:** el anónimo no puede listar los buckets privados (`fotos-atletas`, etc.) → 0 filas.
- **Fail-closed:** `recibo_contador` tiene RLS activada y ninguna política → nadie (salvo funciones `definer`) la toca. Correcto.

## Cosas que NO se pudieron probar del todo (honestidad)

- **Hallazgo 6 (documentos `socios`):** en la base de datos de demo solo hay documentos `publico`; el permiso amplio se dedujo de la política, no se ejecutó contra un documento `socios` real.
- **Sesiones completas (plazas=0):** no se pudo crear la sesión de prueba porque hay un `CHECK (plazas > 0)`; la defensa de aforo se validó por la lógica del trigger (`v_apuntados >= plazas`) y por el bloqueo de secciones, no con una sesión de 0 plazas real.
- El análisis es sobre la **RLS y las funciones**; no se auditó la lógica de negocio de cada función `security definer` línea a línea (p. ej. si `anular_recibo`/`emitir_rectificativo` tienen casos límite contables), solo su superficie de permisos.
