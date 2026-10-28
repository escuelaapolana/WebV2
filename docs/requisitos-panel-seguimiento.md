# Panel de seguimiento de atletismo — requisitos pendientes

> **Estado:** pendiente. Visión recibida el 28-oct-2026; **no se construye todavía**.
> Antes hay que revisar qué datos estructurados hacen falta y dividir el panel en fases.
> La fase 1 (protección del histórico) ya está hecha: ver «Base que ya existe».

## Objetivo

Unificar en la app la planificación de atletismo, el feedback y el seguimiento
por atleta, con **Supabase como registro principal** (sustituye al control maestro
en Excel).

## Prioridad inicial

1. **Resumen del grupo.**
2. **Ficha individual** del atleta.
3. **Previsto frente a realizado.**
4. **Volumen por contenido.**

## Principios (obligatorios en todas las fases)

- **Toda conclusión automática enlaza con sus registros de origen**: la sesión
  (y la versión respondida), el registro del atleta, el bienestar del día…
- **Se distingue lo real de lo estimado.** Lo que apunta el atleta o el entrenador
  es real. Lo que se calcula (por ejemplo, volumen = plan × % completado) es una
  estimación y se marca como tal.
- **Se señala la información incompleta**: registros que faltan, datos sin rellenar
  y registros antiguos cuyo plan no está garantizado (`version_garantia`
  `sin_garantia` / `sobrescrita`).
- **Las decisiones y la publicación de entrenamientos siguen pasando por Andrés.**
  El panel (y cualquier asistente) propone o deja borradores; no publica ni decide.

## Base que ya existe (fase 1, migs 458-459, 28-oct-2026)

- `sesiones_versiones`: cada versión de cada sesión, inmutable, con fecha y autor.
- `registros_sesion.sesion_version_id`: la versión que respondió cada atleta (fija).
  `version_garantia` + `version_nota` en los registros anteriores al historial.
- `registros_sesion_versiones`: valores anteriores de cada corrección del feedback.
- Las sesiones con registros se archivan (`archivada_en`); no se borran en cascada.
- Lo demás: `registros_sesion` (estado, % completado, RPE, molestia y zona,
  duración, tiempos por fila, marcas en texto), `bienestar_diario`,
  `lesiones_atleta`, `notas_atleta`, `marcas_atleta`, `test_resultados`,
  `rm_atleta`, `microciclos`.

## Por decidir antes de construir

- Qué datos estructurados faltan (p. ej., perfil deportivo, objetivos, decisiones
  del entrenador; cómo medir el «contenido» de cada fila para el volumen).
- División en fases del panel.

## Propuesta completa

_Pendiente de pegar aquí._ El 28-oct-2026 llegó la introducción y las prioridades,
pero no el texto completo de la propuesta.
