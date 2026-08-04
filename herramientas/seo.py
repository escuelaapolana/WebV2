#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SEO · sella las etiquetas que dependen de la DIRECCION de la web
================================================================

Hay tres cosas en el SEO de esta web que solo se pueden escribir si sabemos
en que direccion vive la web: la etiqueta canonica (cual es la direccion
buena de cada pagina), la tarjeta que se ve al compartir por WhatsApp
(Open Graph, que necesita direcciones absolutas para la foto) y el
sitemap.xml (la lista de paginas que se le entrega a Google).

Hoy la web vive en  https://escuelaapolana.github.io/WebV2/
y el dia que se cambie el dominio vivira en  https://atletismoapolana.com/

Ese dia NO hay que tocar 30 archivos a mano. Se ejecuta esto:

    python3 herramientas/seo.py --base https://atletismoapolana.com/

y el programa reescribe el bloque de etiquetas de todas las paginas y vuelve
a generar el sitemap.xml con las direcciones nuevas.

Sin --base usa la direccion de hoy (la de GitHub Pages).

EL DIA DEL CAMBIO DE DOMINIO, EL COMANDO ES EXACTAMENTE ESTE:

    python3 herramientas/seo.py --base https://atletismoapolana.com/ \
                                --canonical --indexable

Opciones:
    --base URL       direccion raiz de la web (con la barra final)
    --canonical      ademas, escribe la etiqueta <link rel="canonical">
                     (cual es la direccion buena de cada pagina). Solo tiene
                     sentido cuando la web ya vive de verdad en esa direccion.
    --indexable      QUITA el «noindex». Mientras la web esta en la direccion
                     de pruebas de GitHub le decimos a Google que no la mire,
                     para que no compita con atletismoapolana.com. El dia del
                     cambio hay que pasar esta opcion; si se olvida, Google no
                     indexara la web nueva.

El programa NO toca el texto visible de ninguna pagina: solo escribe dentro
de un bloque marcado en la cabecera <head>, entre los comentarios
<!-- APOLANA-SEO --> y <!-- /APOLANA-SEO -->. Si el bloque ya existe, lo
sustituye; si no, lo pone justo despues de la <meta name="description">.
"""

import argparse
import html
import os
import re
import sys
from datetime import date

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BASE_HOY = "https://escuelaapolana.github.io/WebV2/"

SITIO = "Club Atletismo Apolana"

# Paginas publicas: las que queremos que Google vea y que se compartan bien.
# El orden manda en el sitemap. La prioridad es una pista, no una orden.
PAGINAS = [
    # (ruta del archivo,                          ruta publica,                     prioridad, en_sitemap)
    ("index.html",                                "",                               "1.0",  True),
    ("escuelas/index.html",                       "escuelas/",                      "0.9",  True),
    ("escuela/index.html",                        "escuela/",                       "0.9",  True),
    ("escuela-natacion/index.html",               "escuela-natacion/",              "0.8",  True),
    ("escuela-municipal-atletismo/index.html",    "escuela-municipal-atletismo/",   "0.7",  True),
    ("campus/index.html",                         "campus/",                        "0.7",  True),
    ("entrenar/index.html",                       "entrenar/",                      "0.9",  True),
    ("competicion/index.html",                    "competicion/",                   "0.8",  True),
    ("running/index.html",                        "running/",                       "0.8",  True),
    ("natacion/index.html",                       "natacion/",                      "0.8",  True),
    ("montana/index.html",                        "montana/",                       "0.7",  True),
    ("triatlon/index.html",                       "triatlon/",                      "0.7",  True),
    ("cubo/index.html",                           "cubo/",                          "0.7",  True),
    ("inscripcion/index.html",                    "inscripcion/",                   "0.9",  True),
    ("encuentra-tu-grupo/index.html",             "encuentra-tu-grupo/",            "0.8",  True),
    ("horarios/index.html",                       "horarios/",                      "0.8",  True),
    ("calendario/index.html",                     "calendario/",                    "0.7",  True),
    ("instalaciones/index.html",                  "instalaciones/",                 "0.8",  True),
    ("contacto/index.html",                       "contacto/",                      "0.8",  True),
    ("familias/index.html",                       "familias/",                      "0.7",  True),
    ("socio/index.html",                          "socio/",                         "0.7",  True),
    ("club/index.html",                           "club/",                          "0.8",  True),
    ("club/historia/index.html",                  "club/historia/",                 "0.6",  True),
    ("club/normativa/index.html",                 "club/normativa/",                "0.5",  True),
    ("club/palmares/index.html",                  "club/palmares/",                 "0.6",  True),
    ("club/ranking/index.html",                   "club/ranking/",                  "0.5",  True),
    ("club/records/index.html",                   "club/records/",                  "0.6",  True),
    ("liga/index.html",                           "liga/",                          "0.5",  True),
    ("noticias/index.html",                       "noticias/",                      "0.7",  True),
    ("galeria/index.html",                        "galeria/",                       "0.5",  True),
    ("tienda/index.html",                         "tienda/",                        "0.5",  True),
    ("app/index.html",                            "app/",                           "0.4",  True),
    ("legal/index.html",                          "legal/",                         "0.3",  True),
    ("legal/aviso-legal/index.html",              "legal/aviso-legal/",             "0.3",  True),
    ("legal/privacidad/index.html",               "legal/privacidad/",              "0.4",  True),
    ("legal/condiciones/index.html",              "legal/condiciones/",             "0.3",  True),
    ("legal/cookies/index.html",                  "legal/cookies/",                 "0.2",  True),
    # Plantilla de noticia: se comparte por WhatsApp, pero no va al sitemap
    # porque no es una pagina, es el molde de todas (?id=...).
    ("noticias/articulo/index.html",              "noticias/articulo/",             "0.3",  False),
]

# Foto que se ve al compartir cada pagina. Si no esta aqui, se usa la de la
# portada. Son fotos que ya existen en la web; no se ha creado ninguna.
FOTOS = {
    "":                             "assets/img/hero.jpg",
    "escuelas/":                    "assets/img/escuela.jpg",
    "escuela/":                     "assets/img/escuela-hero.jpg",
    "escuela-natacion/":            "assets/img/escuela-natacion-hero.jpg",
    "escuela-municipal-atletismo/": "assets/img/escuela-municipal-hero.jpg",
    "campus/":                      "assets/img/campus-hero.jpg",
    "entrenar/":                    "assets/img/adultos.jpg",
    "competicion/":                 "assets/img/competicion-hero.jpg",
    "running/":                     "assets/img/running-hero.jpg",
    "natacion/":                    "assets/img/natacion-hero.jpg",
    "montana/":                     "assets/img/montana-hero.jpg",
    "triatlon/":                    "assets/img/triatlon-hero.jpg",
    "cubo/":                        "assets/img/cubo-hero.jpg",
    "instalaciones/":               "assets/img/instalaciones-estadio.jpg",
    "familias/":                    "assets/img/familias-hero.jpg",
    "socio/":                       "assets/img/acceso-portada.jpg",
    "noticias/":                    "assets/img/noticia.jpg",
    "noticias/articulo/":           "assets/img/noticia.jpg",
    "galeria/":                     "assets/img/galeria-1.jpg",
}
FOTO_POR_DEFECTO = "assets/img/hero.jpg"

INICIO = "<!-- APOLANA-SEO · lo genera herramientas/seo.py · no editar a mano -->"
FIN = "<!-- /APOLANA-SEO -->"


def leer(ruta):
    with open(ruta, encoding="utf-8") as f:
        return f.read()


def escribir(ruta, texto):
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(texto)


def sacar(patron, texto):
    m = re.search(patron, texto, re.I | re.S)
    return m.group(1).strip() if m else None


def bloque(base, ruta_publica, titulo, descripcion, foto, canonical, indexable):
    url = base + ruta_publica
    foto_url = base + foto
    partes = [INICIO]
    if not indexable:
        partes.append(
            "<!-- MIENTRAS LA WEB ESTA EN PRUEBAS: le decimos a Google que no la\n"
            "     mire, para que no compita con atletismoapolana.com. EL DIA DEL\n"
            "     CAMBIO DE DOMINIO HAY QUE QUITAR ESTA LINEA (la quita sola el\n"
            "     comando de arriba con --indexable). -->"
        )
        partes.append('<meta name="robots" content="noindex, follow">')
    if canonical:
        partes.append('<link rel="canonical" href="%s">' % html.escape(url, quote=True))
    partes += [
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="%s">' % SITIO,
        '<meta property="og:locale" content="es_ES">',
        '<meta property="og:title" content="%s">' % titulo,
        '<meta property="og:description" content="%s">' % descripcion,
        '<meta property="og:url" content="%s">' % html.escape(url, quote=True),
        '<meta property="og:image" content="%s">' % html.escape(foto_url, quote=True),
        '<meta name="twitter:card" content="summary_large_image">',
        FIN,
    ]
    return "\n".join(partes)


def sellar(base, canonical, indexable):
    tocados = 0
    for archivo, ruta_publica, _prio, _sm in PAGINAS:
        p = os.path.join(RAIZ, archivo)
        if not os.path.exists(p):
            print("  aviso: no existe", archivo)
            continue
        s = leer(p)

        titulo = sacar(r"<title[^>]*>(.*?)</title>", s) or SITIO
        desc = sacar(r'<meta[^>]+name="description"[^>]+content="(.*?)"', s) or ""
        foto = FOTOS.get(ruta_publica, FOTO_POR_DEFECTO)

        nuevo = bloque(base, ruta_publica, titulo, desc, foto, canonical, indexable)

        if INICIO in s:
            s = re.sub(re.escape(INICIO) + r".*?" + re.escape(FIN), lambda _: nuevo, s, flags=re.S)
        else:
            # Detras de la description; si no la hay, detras del <title>.
            m = re.search(r'<meta[^>]+name="description"[^>]*>', s, re.I)
            if not m:
                m = re.search(r"</title>", s, re.I)
            if not m:
                print("  aviso: sin sitio donde poner el bloque en", archivo)
                continue
            s = s[: m.end()] + "\n" + nuevo + s[m.end():]

        escribir(p, s)
        tocados += 1
    print("  %d paginas selladas" % tocados)


INICIO_LD = "<!-- APOLANA-SEO-DATOS · lo genera herramientas/seo.py · no editar a mano -->"
FIN_LD = "<!-- /APOLANA-SEO-DATOS -->"


def datos_estructurados(base):
    """La ficha del club en el idioma que entienden los buscadores (schema.org).

    Es lo que le dice a Google, en claro: esto es un CLUB DEPORTIVO, esta en
    ALICANTE, existe desde 1988, hace estos deportes, entrena en estos sitios
    y se le localiza aqui. Es lo que mas ayuda a salir en «club de atletismo
    en Alicante» y en el mapa.

    Todo lo que va aqui esta ya escrito en la propia web (pie de pagina y
    pagina de instalaciones). No se ha inventado ni una direccion postal:
    la web no da ninguna, asi que solo se declara la ciudad.
    """
    ficha = {
        "@context": "https://schema.org",
        "@type": "SportsClub",
        "name": "Club Atletismo Apolana",
        "alternateName": ["Apolana", "C.A. Apolana", "Club de Atletismo Apolana"],
        "url": base,
        "logo": base + "assets/img/logo.png",
        "image": base + "assets/img/hero.jpg",
        "description": (
            "Club de atletismo de Alicante desde 1988. Escuela de atletismo y de "
            "natación para niños y niñas desde los 3 años, y secciones de adultos "
            "de pista, running, natación, triatlón y montaña."
        ),
        "foundingDate": "1988",
        "sport": ["Atletismo", "Running", "Natación", "Triatlón", "Senderismo y trail"],
        "email": "administracion@atletismoapolana.com",
        "telephone": "+34636061700",
        # La direccion sale de la propia web (pagina de contacto): la del
        # estadio donde entrena casi todo el club. No se ha inventado nada;
        # el codigo postal no se pone porque la web no lo dice.
        "address": {
            "@type": "PostalAddress",
            "streetAddress": "Av. de Elche, 3",
            "addressLocality": "Alicante",
            "addressRegion": "Alicante",
            "addressCountry": "ES",
        },
        "areaServed": {"@type": "City", "name": "Alicante"},
        "sameAs": [
            "https://instagram.com/apolana.alicante",
            "https://www.facebook.com/atletismo.apolana.alicante",
            "https://www.tiktok.com/@escuela.apolana",
        ],
        "location": [
            {
                "@type": "Place",
                "name": "Estadio de Atletismo Joaquín Villar",
                "description": "Pista de tartán, foso de saltos y jaula de lanzamientos. "
                               "Casa de la escuela de atletismo, de la sección de pista y del grupo de running.",
                "address": {"@type": "PostalAddress", "streetAddress": "Av. de Elche, 3",
                            "addressLocality": "Alicante", "addressCountry": "ES"},
            },
            {
                "@type": "Place",
                "name": "El Cubo",
                "description": "Gimnasio del club junto a la pista: fuerza, core y prevención.",
                "address": {"@type": "PostalAddress", "addressLocality": "Alicante", "addressCountry": "ES"},
            },
            {
                "@type": "Place",
                "name": "Piscina Monte Tossal",
                "description": "Piscina municipal donde entrena la escuela de natación y los adultos.",
                "address": {"@type": "PostalAddress", "streetAddress": "C/ Foguerer José Romeu Zarandieta",
                            "addressLocality": "Alicante", "addressCountry": "ES"},
            },
            {
                "@type": "Place",
                "name": "Piscina Vía Parque",
                "description": "Sede de invierno de la escuela de natación y del sector de natación del triatlón.",
                "address": {"@type": "PostalAddress", "addressLocality": "Alicante", "addressCountry": "ES"},
            },
        ],
    }

    import json
    texto = INICIO_LD + '\n<script type="application/ld+json">\n' + \
        json.dumps(ficha, ensure_ascii=False, indent=2) + "\n</script>\n" + FIN_LD

    p = os.path.join(RAIZ, "index.html")
    s = leer(p)
    if INICIO_LD in s:
        s = re.sub(re.escape(INICIO_LD) + r".*?" + re.escape(FIN_LD), lambda _: texto, s, flags=re.S)
    else:
        m = re.search(re.escape(FIN), s)
        if not m:
            print("  aviso: no encuentro donde poner la ficha del club")
            return
        s = s[: m.end()] + "\n" + texto + s[m.end():]
    escribir(p, s)
    print("  ficha del club (schema.org) en la portada")


def sitemap(base):
    hoy = date.today().isoformat()
    filas = []
    for _archivo, ruta_publica, prio, en_sitemap in PAGINAS:
        if not en_sitemap:
            continue
        filas.append(
            "  <url>\n"
            "    <loc>%s%s</loc>\n"
            "    <lastmod>%s</lastmod>\n"
            "    <priority>%s</priority>\n"
            "  </url>" % (html.escape(base, quote=True), html.escape(ruta_publica, quote=True), hoy, prio)
        )
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!-- Lista de las paginas publicas de la web, para Google.\n'
        '     No se escribe a mano: la genera herramientas/seo.py -->\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "\n".join(filas)
        + "\n</urlset>\n"
    )
    escribir(os.path.join(RAIZ, "sitemap.xml"), xml)
    print("  sitemap.xml con %d paginas" % len(filas))


def robots(base):
    txt = (
        "# Que puede mirar Google y que no.\n"
        "#\n"
        "# OJO: mientras la web viva en escuelaapolana.github.io/WebV2/ este\n"
        "# archivo NO lo lee nadie, porque los buscadores solo miran el robots.txt\n"
        "# que esta en la RAIZ del dominio y aqui la web cuelga de /WebV2/.\n"
        "# Empieza a funcionar el dia que la web viva en atletismoapolana.com.\n"
        "# Hasta entonces, lo que protege al panel y al portal es la etiqueta\n"
        "# <meta name=\"robots\" content=\"noindex\"> que llevan sus paginas.\n"
        "\n"
        "User-agent: *\n"
        "Allow: /\n"
        "\n"
        "# Zonas privadas: no son para Google.\n"
        "Disallow: /admin/\n"
        "Disallow: /portal/\n"
        "Disallow: /acceso/\n"
        "Disallow: /piezas/\n"
        "Disallow: /documentos/fuente/\n"
        "\n"
        "Sitemap: %ssitemap.xml\n" % base
    )
    escribir(os.path.join(RAIZ, "robots.txt"), txt)
    print("  robots.txt")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=BASE_HOY)
    ap.add_argument("--canonical", action="store_true")
    ap.add_argument("--indexable", action="store_true")
    args = ap.parse_args()
    base = args.base if args.base.endswith("/") else args.base + "/"
    print("Direccion base:", base)
    print("Google puede indexar:", "SI" if args.indexable else "NO (web en pruebas)")
    sellar(base, args.canonical, args.indexable)
    datos_estructurados(base)
    sitemap(base)
    robots(base)
    print("Listo.")


if __name__ == "__main__":
    main()
