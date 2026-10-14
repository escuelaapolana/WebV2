#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Redirecciones del cambio de dominio
===================================

Convierte el mapa de `herramientas/redirecciones.txt` en algo que un servidor
entienda. Hay dos formas, y NO valen lo mismo:

  1) --redirects  (LA BUENA)
     Genera el archivo `_redirects`, que es lo que leen Netlify y Cloudflare
     Pages. Hace redirecciones «301», que es la manera correcta y la unica
     que traslada a la web nueva el posicionamiento que tiene la vieja.
     Requiere mover el alojamiento de GitHub Pages a Netlify o a Cloudflare
     Pages (los dos son gratis y despliegan desde este mismo repositorio).

  2) --paginas  (EL APAÑO)
     Si el club decide quedarse en GitHub Pages, genera una carpeta con una
     pagina puente por cada direccion vieja. GitHub Pages NO SABE hacer
     redirecciones de verdad: lo maximo que se puede hacer es una pagina que
     salta sola. Funciona para las personas y Google acaba entendiendolo,
     pero es mas lento, mas feo y traslada peor la reputacion. Ademas no
     admite las reglas con * (las de blog y las de /es/), asi que esas se
     pierden.

  3) --404  (LO QUE FUNCIONA HOY EN GITHUB PAGES)
     Rellena el mapa en JavaScript de `404.html`. GitHub Pages sirve esa
     pagina para cualquier ruta que no existe, y el script salta a la nueva.
     Admite las reglas con * (como prefijos). Hay que regenerarlo cada vez
     que se toque redirecciones.txt.

Uso:
    python3 herramientas/redirecciones.py --redirects --404
    python3 herramientas/redirecciones.py --paginas
"""

import argparse
import json
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPA = os.path.join(RAIZ, "herramientas", "redirecciones.txt")


def leer_mapa():
    pares = []
    with open(MAPA, encoding="utf-8") as f:
        for n, linea in enumerate(f, 1):
            linea = linea.strip()
            if not linea or linea.startswith("#"):
                continue
            if "->" not in linea:
                print("  aviso: linea %d sin flecha, la salto" % n)
                continue
            viejo, nuevo = [x.strip() for x in linea.split("->", 1)]
            pares.append((viejo, nuevo))
    return pares


def generar_redirects(pares):
    """Formato de Netlify / Cloudflare Pages."""
    lineas = [
        "# Redirecciones de la web vieja a la nueva.",
        "# No se escribe a mano: lo genera herramientas/redirecciones.py a partir",
        "# de herramientas/redirecciones.txt. El 301 es lo que le dice a Google",
        "# «esta pagina se ha mudado para siempre, llevate su reputacion alli».",
        "",
    ]
    for viejo, nuevo in pares:
        if viejo.endswith("/*"):
            destino = nuevo.replace("/*", "/:splat") if nuevo.endswith("/*") else nuevo
            lineas.append("%-52s %-32s 301" % (viejo, destino))
        else:
            lineas.append("%-52s %-32s 301" % (viejo, nuevo))
    lineas.append("")
    destino = os.path.join(RAIZ, "_redirects")
    with open(destino, "w", encoding="utf-8") as f:
        f.write("\n".join(lineas))
    print("  _redirects con %d reglas" % len(pares))
    print("  (GitHub Pages lo ignora; lo leen Netlify y Cloudflare Pages)")


PUENTE = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<!-- Pagina puente: esta direccion es de la web vieja y ahora vive en otro
     sitio. Se salta sola. La genera herramientas/redirecciones.py -->
<meta http-equiv="refresh" content="0; url=%(destino)s">
<link rel="canonical" href="%(destino)s">
<title>Esta pagina se ha mudado</title>
</head>
<body>
<p>Esta pagina se ha mudado. Si no saltas solo,
   <a href="%(destino)s">entra aqui</a>.</p>
</body>
</html>
"""


def generar_paginas(pares):
    hechas = 0
    saltadas = []
    for viejo, nuevo in pares:
        if "*" in viejo:
            saltadas.append(viejo)
            continue
        ruta = viejo.strip("/")
        if not ruta:
            continue
        carpeta = os.path.join(RAIZ, ruta)
        os.makedirs(carpeta, exist_ok=True)
        with open(os.path.join(carpeta, "index.html"), "w", encoding="utf-8") as f:
            f.write(PUENTE % {"destino": nuevo})
        hechas += 1
    print("  %d paginas puente creadas" % hechas)
    if saltadas:
        print("  %d reglas con * NO se pueden hacer asi:" % len(saltadas))
        for s in saltadas:
            print("     ", s)


MARCA_INI = "/* MAPA-REDIRECCIONES · lo genera herramientas/redirecciones.py --404 · no editar a mano */"
MARCA_FIN = "/* /MAPA-REDIRECCIONES */"


def destino_puente(ruta):
    """Si `ruta` es una pagina puente (carpeta con location.replace), su destino."""
    p = os.path.join(RAIZ, ruta.strip("/"), "index.html")
    if not ruta.strip("/") or not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        m = re.search(r'location\.replace\("([^"]+)"\)', f.read())
    return m.group(1) if m else None


def generar_404(pares):
    """GitHub Pages ignora `_redirects`: sirve 404.html para toda ruta que no
    existe. Volcamos el mismo mapa en un objeto JS dentro de 404.html (claves en
    minusculas, sin barra final) para que las direcciones viejas salten igual.
    Si el destino es a su vez una pagina puente, se apunta al destino final."""
    mapa, prefijos, avisos = {}, [], []
    for viejo, nuevo in pares:
        # /es/* lo resuelve 404.html quitando el prefijo de idioma
        if viejo.startswith("/es/"):
            continue
        final, saltos = nuevo, 0
        while saltos < 5:
            d = destino_puente(final)
            if not d or d == final:
                break
            final, saltos = d, saltos + 1
        if not os.path.exists(os.path.join(RAIZ, final.strip("/"), "index.html")):
            avisos.append("%s -> %s (destino sin index.html)" % (viejo, final))
        if viejo.endswith("/*"):
            prefijos.append((viejo[:-1].lower(), final))
            continue
        clave = viejo.rstrip("/").lower()
        if clave in mapa and mapa[clave] != final:
            avisos.append("%s repetida con destinos distintos (%s / %s)" % (clave, mapa[clave], final))
        mapa.setdefault(clave, final)
    js = [MARCA_INI, "    var mapa = {"]
    js += ["      %s: %s," % (json.dumps(k), json.dumps(v)) for k, v in sorted(mapa.items())]
    js[-1] = js[-1].rstrip(",")
    js += ["    };", "    var prefijos = ["]
    js += ["      [%s, %s]," % (json.dumps(k), json.dumps(v)) for k, v in prefijos]
    if prefijos:
        js[-1] = js[-1].rstrip(",")
    js += ["    ];", "    " + MARCA_FIN]
    bloque = "\n".join(js)
    ruta = os.path.join(RAIZ, "404.html")
    with open(ruta, encoding="utf-8") as f:
        s = f.read()
    if MARCA_INI not in s or MARCA_FIN not in s:
        print("  ERROR: 404.html no tiene las marcas del mapa")
        return
    s = re.sub(re.escape(MARCA_INI) + r".*?" + re.escape(MARCA_FIN), lambda _: bloque, s, flags=re.S)
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(s)
    print("  404.html con %d rutas y %d prefijos" % (len(mapa), len(prefijos)))
    for a in avisos:
        print("  aviso:", a)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--redirects", action="store_true")
    ap.add_argument("--paginas", action="store_true")
    ap.add_argument("--404", dest="js404", action="store_true")
    args = ap.parse_args()
    pares = leer_mapa()
    print("Mapa leido: %d mudanzas" % len(pares))
    if not args.redirects and not args.paginas and not args.js404:
        print("Nada que hacer. Pasa --redirects (lo bueno) o --paginas (el apaño).")
        return
    if args.redirects:
        generar_redirects(pares)
    if args.paginas:
        generar_paginas(pares)
    if args.js404:
        generar_404(pares)


if __name__ == "__main__":
    main()
