# Portales (entrenador / atleta / familia) — plan y permisos

La base ya está: `/portal/` = login de cualquier usuario del club (`assets/js/portal-auth.js`),
detecta el `rol` del `perfil` y te lleva a tu zona. Las zonas leen datos de Supabase.

Roles reales (columna `perfiles.rol`): `admin`, `coordinador`, `entrenador`, `atleta`, `padre`.

Identidad: el usuario entra con su correo → su fila en `perfiles` (por email) → su `id` de perfil.
Los atletas se enlazan con `atletas.perfil_id` (su cuenta) o `atletas.perfil_padre_id` (la familia).
Los entrenadores, con `atletas.entrenador_id` / `grupos.entrenador_id`.

---

## A) SEGURO — ejecutar ya (habilita el login y el rol del portal)
Riesgo bajo: cada usuario solo lee SU propia ficha. Sin esto, `/portal/` no sabe quién eres.

```sql
create or replace function public.mi_perfil_id() returns uuid
language sql security definer stable set search_path = public as $$
  select id from public.perfiles where email = (auth.jwt() ->> 'email') limit 1;
$$;

drop policy if exists "leer mi perfil" on public.perfiles;
create policy "leer mi perfil" on public.perfiles for select to authenticated
using (email = (auth.jwt() ->> 'email'));
```

---

## B) SENSIBLE — REVISAR JUNTOS antes de ejecutar
Esto abre el acceso a datos personales (marcas, sesiones, pagos, asistencia). Hay que
**probar con una cuenta de cada rol** que cada uno ve SOLO lo suyo antes de darlo por bueno.
Es un BORRADOR de diseño, no ejecutar a ciegas.

```sql
-- ATLETA + FAMILIA: sus atletas (los suyos o los de sus hijos)
drop policy if exists "ver mis atletas" on public.atletas;
create policy "ver mis atletas" on public.atletas for select to authenticated
using (perfil_id = public.mi_perfil_id() or perfil_padre_id = public.mi_perfil_id());

-- ENTRENADOR: los atletas que entrena
drop policy if exists "entrenador ve sus atletas" on public.atletas;
create policy "entrenador ve sus atletas" on public.atletas for select to authenticated
using (entrenador_id = public.mi_perfil_id());

-- Datos ligados a "mis" atletas (repetir el patrón por tabla):
--   marcas_atleta, registros_sesion, asistencia, pagos, lesiones_atleta, rm_atleta,
--   inscripciones_eventos, feedback_entrenamientos
-- Ejemplo (marcas del atleta):
drop policy if exists "ver marcas de mis atletas" on public.marcas_atleta;
create policy "ver marcas de mis atletas" on public.marcas_atleta for select to authenticated
using (atleta_id in (
  select id from public.atletas
  where perfil_id = public.mi_perfil_id()
     or perfil_padre_id = public.mi_perfil_id()
     or entrenador_id = public.mi_perfil_id()
));
-- (…y una policy igual, cambiando la tabla, para registros_sesion, asistencia, pagos,
--  lesiones_atleta, rm_atleta, inscripciones_eventos.)

-- ENTRENADOR: escribir sesiones/planificación y pasar lista de sus grupos → policies
-- de insert/update por grupo. (Se define cuando montemos su zona.)
```

---

## Zonas a construir (siguiendo las maquetas App/Admin)
- **Atleta**: hoy, entreno del día por bloques, feedback (ritmos por serie), marcas y gráfica,
  bono de El Cubo, mis pagos.
- **Familia**: ficha de cada hijo, asistencia, pagos, tienda, inscripciones.
- **Entrenador**: sus grupos, planificar sesión, pasar lista, leer feedback, ficha del atleta
  (cambiar de grupo, alta, lesión, mensaje a la familia, baja), carga semanal.
- **Coordinador**: los grupos y técnicos de su sección.

## Orden sugerido
1. Ejecutar el bloque A (login + rol).  2. Construir la zona de **atleta** (solo lectura).
3. Revisar y activar el RLS del bloque B probando con cuentas reales de cada rol.
4. Zona de **familia**, luego **entrenador** (con escritura), luego **coordinador**.
5. Estadísticas.
