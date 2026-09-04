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
    ("academia/index.html",                       "academia/",                      "0.6",  True),
    ("running/index.html",                        "running/",                       "0.8",  True),
    ("natacion/index.html",                       "natacion/",                      "0.8",  True),
    ("montana/index.html",                        "montana/",                       "0.7",  True),
    ("triatlon/index.html",                       "triatlon/",                      "0.7",  True),
    ("cubo/index.html",                           "cubo/",                          "0.7",  True),
    ("inscripcion/index.html",                    "inscripcion/",                   "0.9",  True),
    ("prueba/index.html",                         "prueba/",                        "0.8",  True),
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
    "academia/":                    "assets/img/competicion-andres.jpg",
    "prueba/":                      "assets/img/hero.jpg",
}
FOTO_POR_DEFECTO = "assets/img/hero.jpg"

# Palabras clave por pagina. El dueño las ha pedido explicitamente. Google casi
# no las usa ya, pero no molestan y dejan por escrito de que va cada pagina.
# Todas cuelgan del nucleo: club/escuela de atletismo en Alicante.
KEYWORDS_COMUNES = "Club Atletismo Apolana, atletismo Alicante, club de atletismo Alicante"
KEYWORDS = {
    "":                             "club de atletismo Alicante, atletismo Alicante, running Alicante, natación Alicante, triatlón Alicante, escuela de atletismo Alicante, entrenamiento de atletismo, club deportivo Alicante",
    "escuelas/":                    "escuela de atletismo Alicante, escuela de natación Alicante, escuela deportiva Alicante, atletismo para niños Alicante, campus deportivo Alicante, escuelas municipales Alicante",
    "escuela/":                     "escuela de atletismo Alicante, atletismo para niños Alicante, atletismo infantil Alicante, iniciación al atletismo, escuela deportiva Alicante, atletismo 3 a 17 años",
    "escuela-natacion/":            "escuela de natación Alicante, natación para niños Alicante, aprender a nadar Alicante, natación infantil, clases de natación Alicante",
    "escuela-municipal-atletismo/": "escuela municipal de atletismo Alicante, escuelas deportivas municipales Alicante, atletismo para niños Alicante, deporte escolar Alicante",
    "campus/":                      "campus deportivo Alicante, campus de verano Alicante, campamento deportivo niños Alicante, multideporte verano, atletismo verano niños",
    "entrenar/":                    "entrenamiento de atletismo Alicante, running Alicante, natación Alicante, triatlón Alicante, montaña Alicante, atletismo adultos Alicante, club deportivo Alicante",
    "competicion/":                 "atletismo en pista Alicante, atletismo de competición Alicante, velocidad, vallas, medio fondo, fondo, saltos, lanzamientos, atletismo federado Alicante",
    "academia/":                    "academia de velocidad Alicante, alto rendimiento atletismo, velocistas Alicante, entrenamiento de velocidad, Academia AC98, atletismo de competición Alicante",
    "running/":                     "running Alicante, grupos de running Alicante, correr en Alicante, entrenamiento de carrera, trail Alicante, preparación carreras populares",
    "natacion/":                    "natación Alicante, natación adultos Alicante, nadar en Alicante, clases de natación adultos, entrenamiento de natación",
    "montana/":                     "senderismo Alicante, trail Alicante, montaña Alicante, rutas de montaña Alicante, trail running Alicante, FEMECV",
    "triatlon/":                    "triatlón Alicante, club de triatlón Alicante, natación ciclismo carrera, entrenamiento de triatlón",
    "cubo/":                        "sala de fuerza Alicante, entrenamiento de fuerza Alicante, gimnasio atletismo Alicante, core y prevención, bonos de fuerza",
    "inscripcion/":                 "inscripción club atletismo Alicante, apuntarse a atletismo Alicante, alta socio Apolana, matrícula escuela de atletismo",
    "prueba/":                      "clase de prueba atletismo Alicante, probar atletismo gratis, entrenar de prueba, prueba gratis running Alicante, probar natación Alicante",
    "encuentra-tu-grupo/":          "encuentra tu grupo, grupos de entrenamiento Alicante, running natación pista montaña, elegir grupo atletismo Alicante",
    "horarios/":                    "horarios de entrenamiento Alicante, horarios club de atletismo, horario escuela de atletismo Alicante",
    "calendario/":                  "calendario de competiciones Alicante, eventos atletismo Alicante, pruebas populares Alicante, calendario del club",
    "instalaciones/":               "Estadio Joaquín Villar Alicante, pista de atletismo Alicante, instalaciones deportivas Alicante, piscina Monte Tossal, piscina Vía Parque",
    "contacto/":                    "contacto club de atletismo Alicante, teléfono Apolana, dónde entrena Apolana, Estadio Joaquín Villar",
    "familias/":                    "descuento familia deporte, cuota familiar club, deporte en familia Alicante, Familia Apolana",
    "socio/":                       "hacerse socio club de atletismo Alicante, cuota de socio Apolana, área de socio, alta de socio Alicante",
    "club/":                        "club de atletismo Alicante, Club Atletismo Apolana, club deportivo Alicante, historia junta normativa palmarés",
    "club/historia/":               "historia Club Atletismo Apolana, club de atletismo Alicante 1988, atletismo Alicante historia",
    "club/normativa/":              "normativa club de atletismo, estatutos Apolana, protección al menor deporte, documentos del club",
    "club/palmares/":               "palmarés Club Atletismo Apolana, podios atletismo Alicante, resultados del club",
    "club/ranking/":                "ranking club de atletismo Alicante, mejores marcas Apolana, ranking por prueba",
    "club/records/":                "récords Club Atletismo Apolana, mejores marcas del club, récords de atletismo Alicante",
    "liga/":                        "Liga Apolana, competición interna club, ranking participación atletismo",
    "noticias/":                    "noticias Club Atletismo Apolana, resultados atletismo Alicante, crónicas competición, actualidad del club",
    "noticias/articulo/":           "noticias Club Atletismo Apolana, atletismo Alicante, resultados del club",
    "galeria/":                     "galería fotos Club Atletismo Apolana, atletismo Alicante fotos, El Cubo, escuela campus",
    "tienda/":                      "tienda club de atletismo Alicante, equipación Apolana, ropa de atletismo club",
    "app/":                         "app Club Atletismo Apolana, portal del atleta, instalar app del club",
    "legal/":                       "aviso legal Apolana, privacidad, condiciones de uso, cookies, Club Atletismo Apolana",
    "legal/aviso-legal/":           "aviso legal Club Atletismo Apolana, titular de la web, NIF G-03845500",
    "legal/privacidad/":            "política de privacidad Apolana, protección de datos club de atletismo, datos de menores",
    "legal/condiciones/":           "condiciones de uso portal Apolana, términos del club, condiciones app",
    "legal/cookies/":               "política de cookies Apolana, web sin cookies, privacidad del navegador",
}

# Descripcion mas corta para la tarjeta al compartir (Open Graph), cuando la
# descripcion normal es larga. Si una pagina no esta aqui, la tarjeta usa la
# misma <meta name="description"> de la pagina.
OG_DESC = {
    "prueba/":   "Pídenos tus 4 días de prueba gratis: te asignamos grupo, entrenas cuatro días y decides. Sin papeleos ni compromiso.",
    "academia/": "La academia de alto rendimiento del Club Apolana. Se entra por selección y por marcas. Máximo 12 atletas.",
}

# Paginas a las que NO se les pone la etiqueta canonica ESTATICA porque su
# direccion real lleva parametro (?id=...) y la fija el propio JavaScript.
SIN_CANONICAL = {"noticias/articulo/"}

# Paginas que apuntan su canonica a OTRA direccion (son un alias). Ejemplo:
# /horarios/ es la misma tabla que la vista de horarios del calendario, asi que
# se le dice a Google que la buena es esa. El valor es la ruta relativa destino;
# el dominio lo pone seo.py, asi que el dia del cambio tambien se reescribe.
CANONICAL_ESPECIAL = {
    "horarios/": "calendario/?vista=horarios",
}

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
    og_desc = OG_DESC.get(ruta_publica, descripcion)
    keywords = KEYWORDS.get(ruta_publica, KEYWORDS_COMUNES)
    og_type = "article" if ruta_publica.startswith("noticias/articulo") else "website"
    partes = [INICIO]
    if not indexable:
        partes.append(
            "<!-- MIENTRAS LA WEB ESTA EN PRUEBAS: le decimos a Google que no la\n"
            "     mire, para que no compita con atletismoapolana.com. EL DIA DEL\n"
            "     CAMBIO DE DOMINIO HAY QUE QUITAR ESTA LINEA (la quita sola el\n"
            "     comando de arriba con --indexable). -->"
        )
        partes.append('<meta name="robots" content="noindex, follow">')
    else:
        partes.append('<meta name="robots" content="index, follow">')
    partes.append('<meta name="keywords" content="%s">' % html.escape(keywords, quote=True))
    if canonical and ruta_publica not in SIN_CANONICAL:
        destino = base + CANONICAL_ESPECIAL[ruta_publica] if ruta_publica in CANONICAL_ESPECIAL else url
        partes.append('<link rel="canonical" href="%s">' % html.escape(destino, quote=True))
    partes += [
        '<meta property="og:type" content="%s">' % og_type,
        '<meta property="og:site_name" content="%s">' % SITIO,
        '<meta property="og:locale" content="es_ES">',
        '<meta property="og:title" content="%s">' % html.escape(titulo, quote=True),
        '<meta property="og:description" content="%s">' % html.escape(og_desc, quote=True),
        '<meta property="og:url" content="%s">' % html.escape(url, quote=True),
        '<meta property="og:image" content="%s">' % html.escape(foto_url, quote=True),
        '<meta name="twitter:card" content="summary_large_image">',
        '<meta name="twitter:title" content="%s">' % html.escape(titulo, quote=True),
        '<meta name="twitter:description" content="%s">' % html.escape(og_desc, quote=True),
        '<meta name="twitter:image" content="%s">' % html.escape(foto_url, quote=True),
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

    return ficha


def _nombre_pagina(archivo, ruta_publica):
    """El nombre corto de una pagina para la miga de pan: la primera parte del
    <title> (antes del «·»). La portada es «Inicio»."""
    if ruta_publica == "":
        return "Inicio"
    p = os.path.join(RAIZ, archivo)
    if os.path.exists(p):
        t = sacar(r"<title[^>]*>(.*?)</title>", leer(p))
        if t:
            return html.unescape(t.split("·")[0].strip())
    return ruta_publica.strip("/").split("/")[-1].capitalize()


def breadcrumb(base, ruta_publica):
    """Miga de pan (BreadcrumbList): Inicio › … › esta pagina. Ayuda a que
    Google entienda la jerarquia y la muestre bajo el resultado."""
    if ruta_publica == "":
        return None
    segmentos = ruta_publica.strip("/").split("/")
    items = []
    acumulado = ""
    # El primer eslabon siempre es la portada.
    items.append(("Inicio", base))
    for seg in segmentos:
        acumulado += seg + "/"
        nombre = _nombre_pagina(acumulado + "index.html", acumulado)
        items.append((nombre, base + acumulado))
    return {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": i + 1, "name": nombre, "item": url}
            for i, (nombre, url) in enumerate(items)
        ],
    }


# Preguntas frecuentes del area de socio (estan escritas en socio/index.html;
# aqui van en el idioma de los buscadores para que salgan como FAQ en Google).
FAQ_SOCIO = [
    ("¿El alta de socio sirve para cualquier sección?",
     "Sí. Al hacerte socio o socia puedes entrenar en cualquier sección del club: atletismo en pista, running, natación, montaña o triatlón. El alta es una sola, para todo."),
    ("¿Cuándo y cuánto se paga la cuota de socio?",
     "Una vez al año. El primer año son 125 € y, a partir del segundo, 110 € cada año. El entrenamiento se paga aparte, cada mes, según el grupo en el que entrenes."),
    ("¿Cuándo puedo empezar a entrenar?",
     "En cuanto el club confirma tu alta. Y antes de decidirte puedes probar cuatro entrenamientos gratis, sin ser socio todavía."),
    ("¿Dónde se entrena?",
     "El sitio oficial es el Estadio Joaquín Villar de Alicante, con pista, gimnasio, vestuarios y material, en horario de mañana y de tarde. La natación es en la piscina de la Vía Parque y en el Monte Tossal cuando está habilitada."),
    ("¿Puedo entrenar por mi cuenta o tiene que ser con entrenador?",
     "Como quieras. Puedes entrenar por tu cuenta (solo con la cuota de socio), pedir un plan de entrenamiento o entrenar con un entrenador presencial. Los planes y el entrenamiento presencial llevan su cuota mensual, según el grupo y tu nivel."),
    ("¿Hay diferentes niveles y grupos?",
     "Sí. Hay grupos de atletas federados que compiten de forma regular y grupos que participan sobre todo en pruebas populares. En pista, además, está la Academia AC98, el grupo de alto rendimiento al que se entra por selección."),
    ("¿Tengo que federarme?",
     "En montaña y triatlón, sí. En atletismo y natación es opcional, aunque lo recomendamos: competir federado tiene ventajas que merecen la pena."),
    ("¿Qué cuesta la licencia federativa y cuándo se paga?",
     "Depende del tipo de licencia y la modalidad, aproximadamente entre 50 € y 160 €. Las renovaciones se cargan a lo largo de diciembre; en triatlón, el propio atleta la renueva en la web de la federación."),
]


def faqpage(ruta_publica):
    if ruta_publica != "socio/":
        return None
    return {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "mainEntity": [
            {"@type": "Question", "name": q,
             "acceptedAnswer": {"@type": "Answer", "text": a}}
            for q, a in FAQ_SOCIO
        ],
    }


def sellar_datos(base):
    """Pone en cada pagina su ficha de datos (schema.org): la del club en la
    portada, la miga de pan en las demas y las preguntas frecuentes en el area
    de socio. La plantilla de noticia se salta: su ficha la pone el JavaScript
    con los datos reales de cada noticia."""
    import json
    ficha = datos_estructurados(base)
    tocados = 0
    for archivo, ruta_publica, _prio, _sm in PAGINAS:
        if ruta_publica in SIN_CANONICAL:
            continue  # la plantilla de noticia se sella sola por JavaScript
        p = os.path.join(RAIZ, archivo)
        if not os.path.exists(p):
            continue
        fichas = []
        if ruta_publica == "":
            fichas.append(ficha)
        else:
            b = breadcrumb(base, ruta_publica)
            if b:
                fichas.append(b)
        f = faqpage(ruta_publica)
        if f:
            fichas.append(f)
        if not fichas:
            continue
        cuerpo = "\n".join(
            '<script type="application/ld+json">\n' +
            json.dumps(d, ensure_ascii=False, indent=2) +
            "\n</script>"
            for d in fichas
        )
        texto = INICIO_LD + "\n" + cuerpo + "\n" + FIN_LD
        s = leer(p)
        if INICIO_LD in s:
            s = re.sub(re.escape(INICIO_LD) + r".*?" + re.escape(FIN_LD), lambda _: texto, s, flags=re.S)
        else:
            m = re.search(re.escape(FIN), s)
            if not m:
                print("  aviso: no encuentro donde poner la ficha en", archivo)
                continue
            s = s[: m.end()] + "\n" + texto + s[m.end():]
        escribir(p, s)
        tocados += 1
    print("  %d fichas de datos (schema.org) selladas" % tocados)


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
    sellar_datos(base)
    sitemap(base)
    robots(base)
    print("Listo.")


if __name__ == "__main__":
    main()
