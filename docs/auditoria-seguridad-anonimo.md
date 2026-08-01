# Auditoría de seguridad · ángulo del visitante anónimo

**Objetivo:** comprobar qué puede VER y HACER un desconocido sin cuenta, atacando la web
tal cual lo haría una persona real desde el navegador (API REST de Supabase con la clave
pública) y desde GitHub Pages. Complementa a la auditoría de escalada de privilegios por psql.

- **Web atacada:** https://escuelaapolana.github.io/WebV2/
- **Proyecto Supabase:** `icaxokjsvhlreuwpyxeb.supabase.co`
- **Clave usada:** la *publishable* que va en `assets/js/db.js` (pública por diseño).
- **Fecha:** 2026-08-01
- **Método:** `curl` con la clave pública (idéntico a lo que haría cualquiera desde la consola
  del navegador sin cuenta), contrastado con `psql` de administrador solo para *confirmar*
  qué hay realmente detrás (si una tabla devuelve vacío es porque RLS la protege, no porque
  esté vacía).

## Veredicto rápido

**Ninguna fuga crítica.** El muro de verdad —las reglas RLS— aguanta: **todas** las tablas
con datos personales (atletas, pagos, salud, mensajes, solicitudes, notas…) devuelven `[]`
a un anónimo aunque por dentro tengan cientos de filas reales. No hay ninguna clave secreta
en el frontend. Lo que se encontró son **fugas de reconocimiento y riesgos latentes de
configuración**, no datos personales expuestos hoy. Aun así conviene cerrarlos antes de
meter datos de menores.

---

## Hallazgos por gravedad

| # | Gravedad | Hallazgo | Qué se filtra / se puede hacer | Quién lo sufre |
|---|----------|----------|--------------------------------|----------------|
| 1 | **Media** | Todo `/migraciones/*.sql` y `/docs/*.md` se sirven en GitHub Pages | Esquema completo de la BD, **toda la lógica RLS**, nombres de funciones internas (`es_admin()`, `mis_atletas()`, `mi_perfil_id()`), datos demo (nombres + fechas de nacimiento) y documentos internos de diseño. `docs/formularios-reales.md` detalla qué datos sensibles se piensan pedir (DNI, SIP de menores, IBAN) | El club (mapa de ataque servido en bandeja) |
| 2 | **Media** | Bucket de Storage `fotos-atletas` es **público** (`public=t`) | Hoy está **vacío**, pero en cuanto se suban fotos de atletas (menores) serán legibles por cualquiera vía URL directa `/storage/v1/object/public/fotos-atletas/…`, saltándose RLS. Además hay buckets duplicados con distinta capitalización, todos públicos | Menores (fotos), a futuro |
| 3 | **Baja** | `mensajes` y `solicitudes_inscripcion` aceptan INSERT anónimo con `with_check = true` y sin límite ni captcha | Un anónimo puede **inundar** esas tablas con basura o cargas grandes (spam a administración, consumo de BD). *Lado bueno:* NO puede leer lo que otros enviaron | Administración del club |
| 4 | **Baja** | PII de maqueta en documentos publicados | `docs/maquetas-app.md` contiene nombres y teléfonos (625 47 38 30, 636 06 17 00); plantillas de email publican el correo/teléfono de administración. Son sobre todo datos de contacto del club, pero algún teléfono podría ser de personal real | Personal del club |
| 5 | **Baja/Info** | `palmares` es público y muestra **nombres completos** de atletas premiados, incluidas categorías Sub-18 | Inherente a una página de palmarés (honor), pero incluye posibles menores por nombre y apellidos | Atletas nombrados |
| 6 | **Info** | Bucket `imagenes` (galería/biblioteca) es público | Las fotos de entrenamientos (`imagenes/biblioteca/…`, muchas de atletas) son descargables por URL directa si se conoce el nombre. NO se pueden listar. Es la galería de la web, así que es esperable, pero son imágenes de menores accesibles sin cuenta | Atletas fotografiados |

---

## Detalle y comandos que lo demuestran

### Hallazgo 1 — Esquema y RLS servidos en la web pública
```
curl -s -o /dev/null -w "%{http_code}" https://escuelaapolana.github.io/WebV2/migraciones/037_usuarios.sql   # 200
curl -s -o /dev/null -w "%{http_code}" https://escuelaapolana.github.io/WebV2/migraciones/033_plantillas_email.sql  # 200
curl -s -o /dev/null -w "%{http_code}" https://escuelaapolana.github.io/WebV2/docs/maquetas-admin.md          # 200
curl -s -o /dev/null -w "%{http_code}" https://escuelaapolana.github.io/WebV2/docs/formularios-reales.md      # 200
```
Cualquiera puede descargar los 40+ ficheros SQL (estructura de tablas, políticas RLS, triggers,
funciones) y los documentos de diseño interno. No es una clave, pero le da a un atacante el
plano completo del edificio. **No debería publicarse:** son artefactos de desarrollo.
Recomendación: excluir `migraciones/` y `docs/` del sitio publicado (o mover el despliegue a
una carpeta `/public` o `/dist` que solo contenga lo que la web necesita).

*Nota buena:* GitHub Pages NO lista directorios (`/migraciones/` → 404) y NO sirve dotfiles,
por eso `/.secrets/` da 404 (ver «Lo que SÍ aguanta»).

### Hallazgo 2 — Bucket público de fotos de atletas
```
psql> select id, public from storage.buckets;
  → fotos-atletas | t      (público, hoy vacío)
  → imagenes       | t
  → imagenes-club  | t  ... y duplicados 'Fotos-atletas', 'Imagenes-club' también públicos
```
La política `Lectura publica imagenes` da SELECT a `{public}` para
`['imagenes-club','productos-tienda','fotos-atletas']`, y al ser buckets públicos el endpoint
`/object/public/…` sirve el fichero **sin autenticación y saltándose RLS**. Un fallo típico es
proteger la fila de la tabla pero dejar el archivo accesible por su URL: aquí la tabla
`documentos` está protegida (RLS), pero el patrón de bucket público es el mismo riesgo si se
usa para archivos sensibles. Hoy no hay daño (bucket vacío), pero en cuanto se suban fotos de
menores serán públicas. Recomendación: `fotos-atletas` debe ser **privado** y servirse con
URLs firmadas de caducidad corta; eliminar los buckets duplicados mal capitalizados.

### Hallazgo 3 — Escritura anónima en formularios (esperada, pero sin freno)
```
# Insert anónimo aceptado (formulario de contacto, comportamiento deseado):
curl -s -X POST ".../rest/v1/mensajes" -H "apikey: <pub>" -H "Authorization: Bearer <pub>" \
     -H "Content-Type: application/json" -H "Prefer: return=minimal" \
     -d '{"nombre":"...","medio":"...","asunto":"...","mensaje":"..."}'   # → 201
```
Es correcto que un formulario público inserte. El problema es que `with_check` es `true` (sin
validación) y no hay rate-limit ni captcha → vector de spam/flooding. Se comprobó además que el
anónimo **no puede leer de vuelta** lo insertado (ver «Lo que SÍ aguanta»). *Las filas de prueba
creadas durante la auditoría se borraron con psql; no queda rastro.*

---

## Lo que SÍ aguanta (bien hecho)

- **RLS activado en el 100 % de las tablas** (`relrowsecurity = true` en las 48 tablas públicas).
  Ninguna tabla tiene RLS desactivado.
- **Cero fuga de datos personales a un anónimo.** Todas devuelven `[]` por `curl` con la clave
  pública, a pesar de contener datos reales confirmados por psql:
  - `atletas` (206 filas) → `[]`
  - `pagos` (666) → `[]`
  - `marcas_atleta` (289) → `[]`
  - `registros_sesion` (1184) → `[]`
  - `perfiles` (15) → `[]`
  - `solicitudes_inscripcion` (5, con datos de contacto) → `[]`
  - `mensajes` (4) → `[]`
  - `cubo_bonos` (71), `cubo_reservas` (418), `cubo_movimientos` (470), `competicion_atleta` (80),
    `bono_movimientos` (25) → todas `[]`
  - `lesiones_atleta`, `mensajes_directos`, `notas_atleta`, `notas_familia`, `entrevista_inicial`,
    `ausencias`, `pedidos`, `sesiones`, `asistencia` → `[]`
- **Datos que SÍ deben ser públicos, y lo son correctamente:** noticias publicadas, productos,
  tarifas, grupos, eventos, competiciones, avisos, palmarés, contenido de páginas, histórico de
  escuela, catálogo de pruebas, documentos con visibilidad `publico`. Es lo esperado en una web
  de club.
- **Escritura anónima bloqueada donde debe estarlo:**
  ```
  POST .../rest/v1/atletas  → 401  "new row violates row-level security policy for table atletas"
  ```
- **El anónimo NO puede leer de vuelta lo que inserta.** Un INSERT con `Prefer: return=representation`
  en `mensajes` falla con `42501` (necesita SELECT, que no tiene), y `GET mensajes?nombre=eq.…`
  devuelve `[]`. Formulario de una sola dirección: entra, no sale.
- **Storage cerrado a escritura y a listado anónimos:**
  ```
  POST .../storage/v1/object/imagenes/hack.txt          → 400 (denegado)
  POST .../storage/v1/object/list/imagenes {"prefix":""} → []   (no se puede enumerar)
  POST .../storage/v1/object/list/fotos-atletas          → []
  ```
- **Sin claves secretas en el frontend.** `grep -rn "service_role|secret|eyJ|sb_secret" assets/`
  no encuentra nada: solo está la clave *publishable*, que es pública por diseño. Ninguna
  `service_role` ni cadena de conexión en el código servido.
- **`/.secrets/` no accesible** (`curl … /.secrets/db_password` → **404**), `/.git/config` → 404,
  `.DS_Store` → 404, sin listado de directorios. GitHub Pages no sirve carpetas ocultas.
- **`recibo_contador`** no tiene grant para `anon` → `401 permission denied` (bien).

> **Nota de higiene (fuera del ámbito del anónimo):** el fichero local `.secrets/db_password`
> contiene la cadena de conexión de administrador a Postgres. NO se sirve en la web (404
> confirmado) y NO se transcribe aquí, pero conviene tenerlo siempre en `.gitignore` y, si
> alguna vez llegó a un commit, **rotar esa contraseña** en Supabase por precaución.

---

## Recomendaciones priorizadas

1. **(Media)** Dejar de publicar `migraciones/` y `docs/` en GitHub Pages (desplegar solo lo que
   la web necesita).
2. **(Media)** Poner `fotos-atletas` como bucket **privado** con URLs firmadas antes de subir
   ninguna foto de menores; borrar los buckets duplicados mal capitalizados.
3. **(Baja)** Añadir captcha / rate-limit / longitud máxima a los formularios que insertan en
   `mensajes` y `solicitudes_inscripcion`.
4. **(Baja)** Revisar teléfonos/nombres reales en `docs/maquetas-app.md` (se irá con el punto 1).
