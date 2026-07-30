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
