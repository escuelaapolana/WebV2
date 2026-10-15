#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Salud diaria · lista de funciones (RPC) que llama el FRONT
==========================================================

La comprobación de cada mañana (`salud_comprobar()`, migración 391) mira que
las funciones que llama la web/app tengan permiso de ejecución para quien las
llama (el fallo de `_dia_corto`: con sesión real salía «permission denied» y
nadie se enteraba). Para eso necesita saber QUÉ funciones llama el front, y eso
vive en la tabla `salud_rpc_front`.

Este programa recorre el repo, saca los nombres de las RPC que se llaman
(`.rpc('x'`, `F.llamar('x'`, `rpc/x`) y dice en qué zona aparecen:

  · publica  → páginas de la web pública (fuera de admin/ y portal/): las puede
               abrir alguien SIN sesión → se exige permiso para `anon`
               (solo si hoy ya lo tiene: ver --sql).
  · app      → admin/, portal/ y assets/js → se exige permiso para `authenticated`.

Uso:
    python3 herramientas/salud_rpc_front.py            # lista legible
    python3 herramientas/salud_rpc_front.py --sql      # SQL para refrescar la tabla

El SQL que imprime NO borra filas: añade las nuevas (on conflict do nothing).
Se pega en psql (o en una migración) cuando aparezcan funciones nuevas.
"""
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NO_MIRAR = {"supabase", "migraciones", "herramientas", "node_modules", ".git",
            "maquetas", "docs", ".secrets", ".claude"}
PATRONES = [
    re.compile(r"""\.rpc\(\s*['"]([A-Za-z_][A-Za-z_0-9]*)['"]"""),
    re.compile(r"""\bllamar\(\s*['"]([a-z_][a-z_0-9]*)['"]"""),
    re.compile(r"""rpc/([a-z_][a-z_0-9]*)"""),
]


def zona_de(ruta_rel: str) -> str:
    primera = ruta_rel.split(os.sep, 1)[0]
    if primera in ("admin", "portal", "assets"):
        return "app"
    return "publica"


def recorrer():
    vistas = {}  # nombre -> set(zonas)
    for base, dirs, ficheros in os.walk(RAIZ):
        rel_base = os.path.relpath(base, RAIZ)
        partes = [] if rel_base == "." else rel_base.split(os.sep)
        if any(p in NO_MIRAR or p.startswith("_maqueta") or "maqueta" in p for p in partes):
            dirs[:] = []
            continue
        for f in ficheros:
            if not (f.endswith(".html") or f.endswith(".js")):
                continue
            ruta = os.path.join(base, f)
            rel = os.path.relpath(ruta, RAIZ)
            try:
                texto = open(ruta, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            for pat in PATRONES:
                for m in pat.finditer(texto):
                    vistas.setdefault(m.group(1), set()).add(zona_de(rel))
    return vistas


def main():
    vistas = recorrer()
    if "--sql" in sys.argv:
        filas = []
        for nombre in sorted(vistas):
            publica = "publica" in vistas[nombre]
            filas.append(f"  ('{nombre}', {'true' if publica else 'false'})")
        print("-- Generado con herramientas/salud_rpc_front.py --sql")
        print("-- en_publica = aparece en una página que se abre sin sesión.")
        print("insert into public.salud_rpc_front (nombre, en_publica) values")
        print(",\n".join(filas))
        print("on conflict (nombre) do update set en_publica = excluded.en_publica;")
    else:
        for nombre in sorted(vistas):
            print(f"{nombre:45s} {', '.join(sorted(vistas[nombre]))}")
        print(f"\n{len(vistas)} funciones", file=sys.stderr)


if __name__ == "__main__":
    main()
