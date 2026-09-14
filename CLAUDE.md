# CLAUDE.md — Club Atletismo Apolana

Orientación estable del proyecto (se carga en cada sesión). Los hechos que
cambian con el tiempo van en la memoria (`memory/MEMORY.md` + `memory/*.md`),
no aquí.

## Qué es
Web pública + portal/app del **Club Atletismo Apolana** (Alicante). Sitio
**estático servido por GitHub Pages** (repo `escuelaapolana/WebV2`) con
**backend en Supabase**. Andrés (itakadyr@gmail.com) es admin/entrenador.

## Cómo se despliega
- **La web se publica con `git push` a `main`** (GitHub Pages). No hay build.
- **Hoy la web vive en `escuelaapolana.github.io/WebV2/` y está en `noindex` A PROPÓSITO** hasta migrar de dominio (a `atletismoapolana.com`). El SEO/noindex lo maneja `herramientas/seo.py` (un comando el día del cambio). Ver memoria de migración de dominio.
- **Edge Functions de Supabase**: `supabase functions deploy <n> --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb` (CLI ya autenticado; el aviso de Docker es inofensivo). NO se despliegan con git.

## Base de datos (Supabase)
- Project ref: `icaxokjsvhlreuwpyxeb`.
- **`bash .secrets/psql.sh` = psql a la base REAL de producción (superusuario).** Con eso se leen/escriben datos y se aplican migraciones (`migraciones/NNN_*.sql`). Cuidado: es producción. Insertar/actualizar sí; **borrar sesiones con feedback NO** (cascade).
- Clave pública del front (REST/functions sin sesión): `sb_publishable_ABwJ5L9azzN30mqKg6igxA_zq6pB3MH`. **Nunca** poner claves secretas (sk_*, service_role) en el repo — van solo en secretos de Supabase, las mete Andrés.
- RLS activada en las tablas sensibles; hay funciones de permiso (`es_admin()`, `es_staff()`, `mis_atletas()`, `veo_bateria()`…).

## Estructura
- `admin/` — panel de gestión (usa `APOLANA_ADMIN.listo(sb)`).
- `portal/` — vistas del portal por papel (atleta, entrenador, tests…) (usa `APOLANA_PORTAL.listo(sb, perfil)`; `APOLANA_UI`/`APX` existen aquí, NO en admin).
- Carpetas de la web pública (club, escuela, cubo, tienda, legal, contacto…).
- `assets/js/` — JS compartido (`papeles.js`, `descansos.js`, `db.js`…).
- `migraciones/` — SQL numerado. `herramientas/` — scripts Python (seo.py, export…).
- Carpetas `portal/_maqueta*` y `*_maqueta*` son **maquetas locales, NO commitear**.

## Cómo trabajar aquí
- **App en uso real** — tocar con cuidado; cambios aditivos y aislados mejor que reescrituras.
- **No hay node/deno.** Comprobar sintaxis JS con `osascript -l JavaScript` + `new Function(script)` (parse-only). Python3 sí está.
- Truco de caché para ver cambios en el navegador: `?n=` en la URL.
- Los **documentos legales** (`legal/*`) son **borradores pendientes de asesoría** — no darlos por validados.
- Commits: mensajes en español, estilo «Área · qué se hizo». Push solo cuando Andrés lo pida (o cuando algo tiene que estar live para que funcione, avisándole).

## Idioma
Todo (UI, commits, respuestas) en **español**.
