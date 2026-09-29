#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
chequeo_vistas_candado.py — guardia anti-regresión del «candado» de RLS.

Contexto (hallazgo F1): al recrear una vista con `create or replace view`,
Postgres BORRA en silencio la opción `security_invoker`. Si esa vista es un
panel de administración montado sobre una tabla con datos personales
(p. ej. `altas_socio_panel`), pierde el candado y pasa a correr con los permisos
del DUEÑO, saltándose la RLS: cualquier cuenta autenticada del portal podría
leer los datos de todo el mundo.

Este script NO arregla nada: solo VIGILA. Lista las vistas de `public` que DEBEN
llevar `security_invoker=on` (los paneles `*_panel` y las que declaremos con
datos personales) y falla (código de salida != 0) si alguna se ha quedado sin el
candado. Pensado para lanzarlo a mano o desde un hook antes de desplegar
migraciones.

    python3 herramientas/chequeo_vistas_candado.py

OJO: las vistas PÚBLICAS curadas (galería, palmarés, récords, ranking, vacantes
de natación, clasificación de la liga con menores enmascarados, calendario
público…) corren como DUEÑO A PROPÓSITO, para servir a `anon` datos ya
recortados/agregados que la RLS de la tabla base no dejaría leer. Esas NO deben
llevar candado y por eso NO se exigen aquí (ver OWNER_POR_DISENO, solo
documental).
"""

import os
import subprocess
import sys

# Vistas con datos personales que SÍ deben correr como INVOKER (candado puesto),
# ADEMÁS de cualquier vista cuyo nombre acabe en «_panel». Si algún día creas una
# vista sobre datos personales que no se llame *_panel, añádela aquí para que el
# guardia la vigile.
VISTAS_PERSONALES_EXTRA = set()

# Vistas que corren como DUEÑO A PROPÓSITO (público curado / redacción interna).
# Solo están documentadas: NO participan en la comprobación. Sirven para dejar
# claro que su falta de candado no es un fallo.
OWNER_POR_DISENO = {
    "galeria_publica", "natacion_vacantes", "palmares_publico",
    "records_club_publico", "ranking_marcas", "pagos_catalogo",
    "cubo_clases_ocupacion", "sesiones_agenda",
    "liga_clasificacion_general", "liga_clasificacion_por_categoria",
    "liga_clasificacion_por_disciplina", "liga_clasificacion_publica",
    "liga_baremo_publico", "liga_edicion_publica", "contactos_publicos",
    "entrenadores_publicos", "cubo_personas", "cubo_monitores",
    "como_se_paga", "buzon_bandeja", "miembros_juego", "medallas_publicas",
    "logros_publicos", "clasificacion_retos", "mis_companeros",
}

SQL = (
    "select c.relname, "
    "coalesce((select option_value from pg_options_to_table(c.reloptions) "
    "where option_name='security_invoker'),'') as si "
    "from pg_class c join pg_namespace n on n.oid=c.relnamespace "
    "where n.nspname='public' and c.relkind='v' order by c.relname;"
)


def ruta_psql():
    # .secrets/psql.sh vive en la raíz del repo, un nivel por encima de herramientas/
    raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(raiz, ".secrets", "psql.sh")


def leer_vistas():
    ruta = ruta_psql()
    if not os.path.exists(ruta):
        print("ERROR: no encuentro %s (¿lanzas desde el repo?)." % ruta,
              file=sys.stderr)
        sys.exit(2)
    # -tA = sin cabeceras ni adornos; -F '|' = campos separados por barra.
    res = subprocess.run(
        ["bash", ruta, "-tA", "-F", "|", "-c", SQL],
        capture_output=True, text=True,
    )
    if res.returncode != 0:
        print("ERROR ejecutando psql:\n" + (res.stderr or ""), file=sys.stderr)
        sys.exit(2)
    vistas = {}
    for linea in res.stdout.splitlines():
        linea = linea.strip()
        if not linea or "|" not in linea:
            continue
        nombre, si = linea.split("|", 1)
        vistas[nombre.strip()] = si.strip().lower()
    return vistas


def tiene_candado(si):
    # Postgres devuelve la opción como 'on' o 'true' según cómo se puso.
    return si in ("on", "true")


def main():
    vistas = leer_vistas()
    # Conjunto que DEBE llevar candado: los *_panel + las personales declaradas.
    deben = {n for n in vistas if n.endswith("_panel")}
    deben |= (VISTAS_PERSONALES_EXTRA & set(vistas))

    sin_candado = sorted(n for n in deben if not tiene_candado(vistas[n]))
    if sin_candado:
        print("FALLO · vistas que DEBEN correr como INVOKER y NO llevan candado:")
        for n in sin_candado:
            print("  - %s  (security_invoker=%s)"
                  % (n, vistas[n] or "(sin poner)"))
        print("")
        print("Arréglalas con:  alter view public.NOMBRE set (security_invoker = on);")
        return 1

    print("OK · %d vista(s) vigilada(s), todas con security_invoker on."
          % len(deben))
    return 0


if __name__ == "__main__":
    sys.exit(main())
