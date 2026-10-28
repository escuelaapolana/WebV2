# Historial de sesiones y feedback (fase 1) · límites de los datos antiguos

> Desde el **28-oct-2026** (migraciones 458-461). Ámbito: entrenos de atletismo
> (Academia AC98 y demás grupos que usan `sesiones` / `registros_sesion`).

## Qué se guarda desde el 28-oct-2026

| Qué | Dónde | Garantía |
|---|---|---|
| Cada versión de cada sesión (alta, cambio, archivo, borrado) con fecha y autor | `sesiones_versiones` | inmutable |
| La versión que el atleta tenía en pantalla al responder | `registros_sesion.sesion_version_id` + `version_vista` | `exacta` |
| Los valores ANTERIORES de cada corrección del feedback | `registros_sesion_versiones` | inmutable |
| Sesiones con registros que se «borran» | `sesiones.archivada_en` (no se borran) | — |

`version_garantia` de cada registro:

| Valor | Qué significa | ¿Plan exacto? |
|---|---|---|
| `exacta` | La app dijo qué versión veía el atleta y es esa. | **Sí** |
| `vigente_al_enviar` | La app no lo dijo (pantalla vieja en caché u otro camino): se enlaza con la versión vigente al enviar. | **No asegurado** |
| `sin_garantia` | Registro anterior al historial: enlazado al estado de la sesión el 28-oct. | **No** |
| `sobrescrita` | Anterior al historial y con pruebas de que la sesión cambió después. | **No: el plan respondido se perdió** |

## Límites de los registros antiguos (31-ago → 27-oct-2026, 206 registros)

1. **No hay versiones anteriores al 28-oct.** Las 545 sesiones que existían tienen
   una única versión «inicial» = como estaban ese día.
2. **201 registros `sin_garantia`**: pudo ser el plan que vio el atleta, pero no se
   puede asegurar (la sesión se editaba encima y `updated_at` no siempre se
   actualizaba).
3. **5 registros `sobrescrita`**: la sesión se cambió después del registro, o sus
   tiempos apuntan a filas que ya no existen. El plan respondido no se conserva.
4. **48 registros corregidos antes del historial**: solo queda el contador
   `corregido_veces`; los valores anteriores no se guardaron.
5. **24 registros con claves de tiempos antiguas** (por bloque: `cc`, `mov`, `tec`…)
   que no casan con una fila concreta del plan.
6. Cada registro lleva su explicación en `version_nota`, y la base lo documenta en
   los comentarios de las columnas (mig 461).

## Reglas para cualquier análisis (panel, informes, asistente)

- **Previsto frente a realizado** solo con registros `exacta`. Los demás se
  muestran, pero marcados («plan no garantizado») y fuera de los cálculos de
  cumplimiento del plan.
- Lo **realizado** declarado por el atleta (RPE, molestias, tiempos, notas) sigue
  siendo un dato real aunque el plan no esté garantizado: se puede usar para
  RPE, molestias y tendencias, citando el registro de origen.
- **Nunca reconstruir** versiones o valores que no se guardaron. Si falta, se dice
  que falta.
- Ausencia de registro **no** significa que se hiciera lo previsto.

## Copias de seguridad previas a la mig 458

- En la base: schema `respaldo` (`sesiones_20261028`, `registros_sesion_20261028`),
  sin acceso por la API. **No se borra hasta que Andrés lo autorice.**
- Fuera (Mac de Andrés, `.secrets/backups/2026-10-28_antes_mig458/`, fuera de git):
  `sesiones.jsonl`, `registros_sesion.jsonl` (idénticos byte a byte al respaldo de
  la base), `respaldo_20261028.dump` (formato de `pg_restore`), funciones tocadas y
  la clave ajena original. Contienen datos personales: no se comparten.
- Comprobado el 28-oct-2026: la copia externa se lee entera y se reconstruye en un
  entorno aislado (545 sesiones, 206 registros, sin huérfanos).
