# Mundo «Academia AC98» — PROPUESTA (sin construir)

> 28-oct-2026 · Requisitos: [requisitos-panel-seguimiento.md](requisitos-panel-seguimiento.md).
> Modelo de datos: [modelo-datos-seguimiento.md](modelo-datos-seguimiento.md).
> Maqueta (local, datos inventados): `portal/_maqueta-academia/`.

## Navegación

```
Panel ─ tira de mundos ─ … · Atletismo pista · [Academia AC98] · Escuela atletismo …
                              │
                              ├─ Hoy            (entrada del mundo)
                              ├─ Planificación  (tabla atletas × días; detalle al tocar)
                              ├─ Atletas        (lista → ficha individual con pestañas)
                              ├─ Feedback       (plan respondido + realizado, filtros)
                              ├─ Carga y contenidos   ← fase 2 (tras acordar el modelo)
                              ├─ Tests y marcas
                              └─ Competiciones
Detalle de una casilla/sesión = panel lateral (no otra pantalla).
```

## Qué se reutiliza (existe hoy)

| Necesidad | Ya existe |
|---|---|
| Mundos, barra lateral y móvil | `assets/js/mundos.js` (añadir el mundo y su mapa de pantallas) |
| Sesiones, versiones, archivadas, feedback, correcciones | `sesiones`, `sesiones_versiones`, `registros_sesion`, `registros_sesion_versiones` (fase 1) |
| Planificar, duplicar semana, plantillas, pasar lista | `portal/entrenador` (formulario «Planificar», «Semana», «Calendario», copiar semana, plantillas) |
| Feedback por día del entrenador | `portal/entrenador` sección Feedback (FBX) y descarga |
| Ficha del atleta (resumen, notas, RM) | `portal/entrenador` «Mi grupo» → ficha (`pintarFicha`), `notas_atleta`, `rm_atleta` |
| Ver la semana como la ve el atleta | `portal/atleta` en modo «Viendo la semana de…» (solo lectura) |
| Lesiones y disponibilidad | `portal/lesiones` + `lesiones_atleta` |
| Carga y bienestar | `portal/carga` + `bienestar_diario` |
| Tests | `portal/tests`, `admin/tests`, `test_resultados`, `test_baterias` |
| Marcas y récords | `marcas_atleta`, `admin/records` |
| Competiciones e inscripciones | `admin/competiciones`, `admin/confirmaciones`, `competiciones`, `competicion_atleta` |

## Qué falta y qué cambios de datos requiere

| Falta | Cambio |
|---|---|
| Entrada «Academia AC98» y acceso | Nuevo mundo en `mundos.js` + `mis_mundos()`: admin y **entrenadores autorizados de Academia**. Hoy los permisos de entreno van por `grupos.entrenador_id` (un solo entrenador). Para autorizar a más, haría falta una tabla `grupo_entrenadores` y ajustar 3 funciones de permiso, **solo para Academia**: es un cambio delicado que va aparte y con tu visto bueno. |
| Distinguir entrenamiento / descanso / ausencia / sin planificar | Hoy «Descanso», «No asiste» o «NO ENTRENA» son sesiones con título, unas veces como `carga` y otras como `descanso` (hay hasta un fartlek marcado «descanso»). Propuesta: `sesiones.clase_dia` (`entreno` · `descanso`) y las ausencias en `ausencias` (ya existe, sin uso). Rellenar lo antiguo con reglas y dejar lo dudoso **pendiente de revisar**. |
| Mañana / tarde | Hoy solo por la hora (12 de 535 sesiones la tienen). Propuesta: `sesiones.momento` (`unica` · `manana` · `tarde`), como ya tiene `registros_sesion`. |
| Nombre del atleta en cada tarjeta | Solo es de pantalla: `atletas_ids` ya dice de quién es (la «solo para 1» actual se cambia por el nombre). |
| Comparar versiones | Pantalla nueva sobre `sesiones_versiones` (los datos ya están). |
| «Pendiente de revisar» en feedback | `registros_sesion.revisado_en` / `revisado_por` (nuevo). |
| Observaciones, decisiones y objetivos | Ampliar `notas_atleta` (clase, motivo, vigencia, evidencias) y tabla `atleta_objetivos` (modelo §6). |
| Competiciones objetivo por atleta | Ampliar `competicion_atleta` (pruebas previstas, objetivo, prioridad) — sin uso hoy. |
| Condiciones de tests y marcas | `condiciones` en `test_resultados` y `marcas_atleta` (modelo §5). |
| Carga y contenidos | Tablas del modelo (`plan_filas_estructura`, `entreno_contenidos`) — fase 2. |

## Propuesta visual (maqueta)

- **Hoy:** cuatro cifras, «Quién entrena hoy» (una fila por atleta: sesión, feedback
  de ayer y aviso con su motivo), «Pendiente de revisar» y «No entrenan hoy».
- **Semana:** tabla atletas × días; cada casilla con su estado (publicada,
  borrador, descanso, ausencia, sin planificar), mañana/tarde separadas, marcas de
  feedback (✓ · falta · molestia) y «v2» si cambió tras publicar; fila de resumen
  que **no cuenta descansos ni ausencias como entrenos**. Al tocar: panel con el plan
  respondido, el actual, el feedback y las acciones (comparar, ficha, editar).
- **Ficha:** cabecera con el perfil; **«Ahora»** (situación temporal) separado del
  perfil estable; pestañas (Resumen · Planificación y feedback · Bienestar · Tests
  y marcas · Competiciones); objetivos, decisiones vigentes con motivo y vigencia;
  feedback con el plan respondido; tests con condiciones y objetivo aparte.

## Fases

1. **Definiciones** (ahora): modelo de datos, conexión con ChatGPT, accesos.
2. **Entrada y datos base:** mundo «Academia AC98» con acceso solo de admin y del
   entrenador de Academia; `clase_dia`, `momento`, ausencias y `revisado_*`, con
   relleno de lo antiguo (sin inventar).
3. **Semana clara** (tabla, estados, mañana/tarde, panel de detalle, comparar
   versiones, publicar) + **Hoy**.
4. **Ficha individual** + objetivos y decisiones + **Feedback integrado**.
5. **Conexión con ChatGPT** (servicio del club + la conexión elegida), primero
   con datos ficticios.
6. **Carga y contenidos**, tendencias y resúmenes, sobre el modelo acordado.
