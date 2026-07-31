# Configuración de Supabase — pasos manuales

Aquí está TODO el SQL que hay que ejecutar en **Supabase → SQL Editor** para que las
funciones nuevas de la web funcionen. Marca con ✅ lo que ya hayas hecho.

> Cómo ejecutarlo: Supabase → menú izquierdo **SQL Editor** → **New query** → pegar → **Run**.

---

## ✅ 1. Seguridad y administrador (YA HECHO)
Ya ejecutado: función `es_admin()`, políticas de administrador y tu perfil como `admin`.

---

## 2. Almacén de imágenes (para SUBIR FOTOS en el panel)
Sin esto, al subir una foto en el panel dará error.

```sql
insert into storage.buckets (id, name, public) values ('imagenes','imagenes', true)
on conflict (id) do nothing;

drop policy if exists "admin sube imagenes" on storage.objects;
create policy "admin sube imagenes" on storage.objects for all to authenticated
using (bucket_id = 'imagenes' and public.es_admin())
with check (bucket_id = 'imagenes' and public.es_admin());
```

---

## 3. Formulario de CONTACTO (tabla de mensajes)
Para que el formulario de `/contacto/` guarde los mensajes.

```sql
create table if not exists public.mensajes (
  id uuid primary key default gen_random_uuid(),
  nombre text,
  medio text,
  asunto text,
  mensaje text,
  atendido boolean default false,
  created_at timestamptz default now()
);

alter table public.mensajes enable row level security;

-- Cualquiera puede ENVIAR un mensaje (formulario público)
drop policy if exists "enviar mensaje" on public.mensajes;
create policy "enviar mensaje" on public.mensajes for insert to anon, authenticated with check (true);

-- Solo administración puede LEER / gestionar los mensajes
drop policy if exists "admin lee mensajes" on public.mensajes;
create policy "admin lee mensajes" on public.mensajes for select using (public.es_admin());
drop policy if exists "admin gestiona mensajes" on public.mensajes;
create policy "admin gestiona mensajes" on public.mensajes for all to authenticated
using (public.es_admin()) with check (public.es_admin());
```

---

## 4. Formulario de PREINSCRIPCIÓN (tabla de solicitudes)
Para que el formulario "Déjanos tus datos" de `/inscripcion/` guarde las solicitudes.

```sql
create table if not exists public.solicitudes_inscripcion (
  id uuid primary key default gen_random_uuid(),
  nombre text,
  medio text,
  interes text,
  origen text,
  comentario text,
  atendida boolean default false,
  created_at timestamptz default now()
);

alter table public.solicitudes_inscripcion enable row level security;

drop policy if exists "enviar solicitud" on public.solicitudes_inscripcion;
create policy "enviar solicitud" on public.solicitudes_inscripcion for insert to anon, authenticated with check (true);

drop policy if exists "admin lee solicitudes" on public.solicitudes_inscripcion;
create policy "admin lee solicitudes" on public.solicitudes_inscripcion for select using (public.es_admin());
drop policy if exists "admin gestiona solicitudes" on public.solicitudes_inscripcion;
create policy "admin gestiona solicitudes" on public.solicitudes_inscripcion for all to authenticated
using (public.es_admin()) with check (public.es_admin());
```

---

Cuando ejecutes 2, 3 y 4, funcionarán: subir fotos, el formulario de contacto y el de
preinscripción (y los verás en el panel, en la sección "Buzón").

---

## 5. Precargar "Textos de las páginas" (secciones de entrenamiento)
Opcional pero recomendado: mete el contenido actual de cada sección en la tabla
`contenido_secciones`, para poder editarlo desde el panel (Panel → "Textos de las páginas")
y verlo cambiar en la web. Solo inserta las que no existan ya.

```sql
insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$competicion$$, $$Federado y popular · temporada 2026-27$$, $$Atletismo en pista$$, $$El corazón del club: velocidad, vallas, medio fondo, fondo, saltos y lanzamientos, cada disciplina con su técnica y su forma de sufrir. Hay quien viene a bajar su 400 y quien busca el Campeonato de España; en los dos casos hay planificación individual detrás.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$competicion$$);

insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$running$$, $$Adultos · asfalto, cross y trail$$, $$Running$$, $$Dos grupos según el momento en el que estés: uno para coger el hábito y disfrutar del kilómetro, otro para buscar marca. En los dos hay entrenador en pista y plan escrito cada semana.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$running$$);

insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$natacion$$, $$Adultos · todos los niveles$$, $$Natación$$, $$Grupos por nivel y sesiones dirigidas en el Tossal y Vía Parque: técnica de los cuatro estilos, series de fondo, velocidad y preparación de competición. En verano, piscina de 50 metros y aguas abiertas los sábados.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$natacion$$);

insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$triatlon$$, $$Natación · ciclismo · carrera$$, $$Triatlón$$, $$Dominar tres disciplinas y saber encadenarlas: nadar, montar y correr gestionando el esfuerzo para que las piernas respondan al bajar de la bici. La sección nació en 2011 con cinco socios y hoy pasa de cincuenta.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$triatlon$$);

insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$montana$$, $$Senderismo y trail · todas las edades$$, $$Montaña$$, $$Rutas por la Serra de la Marina, el Maigmó, el Puig Campana y las sierras que rodean Alicante. No hay ritmo obligatorio ni competición: hay rutas para todos los niveles, desde paseos familiares hasta travesías exigentes.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$montana$$);

insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$cubo$$, $$Entrenamiento funcional$$, $$El Cubo$$, $$El gimnasio del club, junto a la pista: fuerza, core y prevención en grupos de doce. Nadadores, corredores y triatletas comparten sala y cada uno lleva su progresión.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$cubo$$);
```

### 5b. Precargar escuelas, campus e instalaciones
```sql
insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$escuela$$, $$Escuela · temporada 2026-27$$, $$Escuela de atletismo$$, $$Iniciación y desarrollo del atletismo de los 3 a los 17 años. Correr, saltar y lanzar en forma de juego en las categorías pequeñas, y especialización cuando toca.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$escuela$$);

insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$escuela-natacion$$, $$Escuela · 6 a 15 años$$, $$Escuela de natación$$, $$Aprendizaje y perfeccionamiento en las piscinas del Tossal y Vía Parque, con grupos reducidos y la opción de competir en federado si al niño le apetece.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$escuela-natacion$$);

insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$escuela-municipal$$, $$Programa de Deportes Alicante$$, $$Atletismo municipal$$, $$Escuela deportiva municipal que gestiona el club dentro del programa del Ayuntamiento de Alicante. La inscripción y el precio los fija Deportes Alicante; los entrenadores y la metodología son los mismos de la escuela del club.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$escuela-municipal$$);

insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$campus$$, $$Del 29 de junio al 31 de julio · 3 a 16 años$$, $$XII Campus de verano$$, $$Atletismo, multideporte, pádel, natación, juegos de agua, gymkanas, talleres y una excursión cada semana. Todo con enfoque lúdico: el objetivo es que hagan deporte pasándolo bien.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$campus$$);

insert into public.contenido_secciones (seccion, dirigido_a, titulo, descripcion)
select $$instalaciones$$, $$Dónde entrenamos$$, $$Instalaciones$$, $$Cuatro sedes repartidas por la ciudad. Todas son municipales salvo El Cubo, que es del club y está dentro del estadio.$$
where not exists (select 1 from public.contenido_secciones where seccion=$$instalaciones$$);
```

---

## §6 · Perfil automático al crear una cuenta (necesario para portales)

Cada usuario de Supabase (Authentication) necesita una fila en `perfiles` con **el mismo id**.
Este automatismo la crea sola en cuanto se crea la cuenta, y rellena las cuentas ya existentes.
Pegar en Supabase → SQL Editor y ejecutar una vez.

```sql
-- Función que crea el perfil de una cuenta nueva
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer set search_path = public
as $fn$
begin
  insert into public.perfiles (id, email, rol, activo)
  values (new.id, new.email, 'atleta', true)
  on conflict (id) do nothing;
  return new;
end;
$fn$;

-- Disparador: al crear una cuenta, crear su perfil
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

-- Rellenar cuentas que ya existían sin perfil (p. ej. la de prueba)
insert into public.perfiles (id, email, rol, activo)
select u.id, u.email, 'atleta', true
from auth.users u
left join public.perfiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;
```
