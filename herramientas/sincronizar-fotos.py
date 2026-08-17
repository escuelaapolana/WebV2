#!/usr/bin/env python3
# ============================================================
# IGUALAR LAS FOTOS DEL HTML CON LAS DE LA BIBLIOTECA
# ------------------------------------------------------------
# EL PROBLEMA QUE RESUELVE
#
# Cada foto que el club puede cambiar tiene DOS orígenes:
#
#   1. La que trae escrita el HTML. El navegador la pinta en cuanto lee
#      la página, antes de preguntarle nada a nadie. Es el respaldo: si
#      la base no contesta, la web no se queda con un hueco gris.
#   2. La que el club eligió en la biblioteca (tabla `imagenes_web`) o
#      como cabecera de una sección (`contenido_secciones.imagen_url`).
#      Ésa llega unas décimas más tarde, cuando responde la base.
#
# Si las dos son la misma foto, no se nota nada. Si son distintas, se ve
# el cambio: entras y la foto se cambia sola delante de ti. Andrés lo
# dijo tal cual: «no me gusta eso de que entres a una página y esté
# cambiando fotos».
#
# La primera vez que se midió, NINGUNA de las 16 coincidía. Se igualaron
# a mano, pero eso no aguanta: en cuanto el club cambia una foto desde el
# panel, el HTML se queda con la anterior y el cambio vuelve. Y no le
# pasa solo al que la cambió: le pasa a TODO el que entre, siempre, hasta
# que alguien vuelva a igualarlas.
#
# Este script las iguala. Lo lanza una tarea de GitHub cada noche, así
# que como mucho hay unas horas de desajuste después de tocar una foto,
# y nadie tiene que acordarse de nada.
#
# LO QUE HACE, EXACTAMENTE
#   Lee dos tablas (solo lectura), recorre los .html del repositorio y
#   cambia el `src` de las fotos marcadas. No toca ninguna otra cosa: ni
#   el texto, ni el `alt`, ni las fotos sin marcar.
#
# LA CLAVE QUE USA
#   La «publishable» de Supabase, la misma que viaja en el navegador de
#   cualquiera que abra la web. Es pública por diseño. AQUÍ NO SE PONE
#   NUNCA UNA CLAVE SECRETA: este repositorio es público.
#
# A MANO
#   python3 herramientas/sincronizar-fotos.py           (cambia los archivos)
#   python3 herramientas/sincronizar-fotos.py --ver     (solo dice qué haría)
#   python3 herramientas/sincronizar-fotos.py --ver --comprobar
#                                        (falla si hay algo descuadrado; para
#                                         usarlo como control antes de subir)
# ============================================================

import json
import os
import re
import sys
import urllib.request

BASE_DATOS = os.environ.get('SUPABASE_URL', 'https://icaxokjsvhlreuwpyxeb.supabase.co')
CLAVE = os.environ.get('SUPABASE_KEY', 'sb_publishable_ABwJ5L9azzN30mqKg6igxA_zq6pB3MH')

# Dirección pública de la web. Muchas fotos de la biblioteca son archivos
# de este mismo repositorio y se guardan con su URL completa; al escribirlas
# en el HTML se convierten en ruta relativa, que es más corta, funciona sin
# conexión y sigue valiendo el día que cambie el dominio.
SITIO = 'https://escuelaapolana.github.io/WebV2/'

# Carpetas que no son la web publicada.
FUERA = ('maquetas/', 'admin/', 'portal/', '.claude/', 'node_modules/', 'docs/')

# Fichas de `contenido_secciones` cuya página no se llama igual que ellas.
# Las tres municipales comparten una sola página; la portada está en la raíz.
PAGINA_DE = {
    'home': 'index.html',
    'escuela-municipal': 'escuela-municipal-atletismo/index.html',
    'mun-atletismo': None,      # comparten página con la de arriba: no tienen
    'mun-triatlon': None,       # cabecera propia que igualar
    'deporte-adaptado': None,
}


def pedir(tabla, campos):
    url = '%s/rest/v1/%s?select=%s' % (BASE_DATOS, tabla, campos)
    pet = urllib.request.Request(url, headers={
        'apikey': CLAVE,
        'Authorization': 'Bearer ' + CLAVE,
        'Accept': 'application/json',
    })
    with urllib.request.urlopen(pet, timeout=30) as r:
        return json.loads(r.read().decode('utf-8'))


def encuadre_estilo(fila, es_imagen=True):
    """El recorte que el club eligió en el panel, escrito para el HTML.

    ⚠️ ESTO NO ES UN ADORNO, ARREGLA UN SALTO QUE SE VE. La foto podía ser
    ya la buena y aun así la página daba un respingo al abrirse: el
    encuadre —«mira al 6,6% de la altura, no al centro»— lo ponía el
    JavaScript cuando contestaba la base, así que la foto se pintaba con
    el encuadre del CSS y medio segundo después se recolocaba. Andrés:
    «las fotos siguen cambiando al entrar; no las fotos, sino que se
    mueven, se reajustan a lo alto». Escrito aquí, nace ya colocada.
    """
    partes = []
    pos = (fila.get('encuadre') or fila.get('imagen_encuadre') or '').strip()
    zoom = fila.get('zoom') if fila.get('zoom') is not None else fila.get('imagen_zoom')
    try:
        zoom = float(zoom) if zoom is not None else 1.0
    except (TypeError, ValueError):
        zoom = 1.0
    if pos:
        partes.append(('object-position' if es_imagen else 'background-position') + ':' + pos)
        if es_imagen:
            partes.append('transform-origin:' + pos)
    if zoom > 1 and es_imagen:
        partes.append('transform:scale(%s)' % zoom)
    return ';'.join(partes)


def con_estilo(etiqueta, estilo):
    """Mete el encuadre en el `style` de una etiqueta, MEZCLANDO.

    ⚠️ Mezclar y no sustituir. La primera versión escribía el atributo
    entero, y eso habría borrado sin avisar cualquier estilo que ya
    hubiera escrito a mano en esa etiqueta —un alto, un margen—. Un
    script que corre solo cada noche NO puede permitirse borrar cosas
    que no ha escrito él: aquí solo se tocan las propiedades del
    encuadre y el resto se deja donde estaba, en su orden.
    """
    if not estilo:
        return etiqueta
    nuevas = dict(d.split(':', 1) for d in estilo.split(';') if ':' in d)
    m = re.search(r'style="([^"]*)"', etiqueta)
    if not m:
        return re.sub(r'^<(\w+)', r'<\1 style="%s"' % estilo, etiqueta, count=1)

    salida, puestas = [], set()
    for trozo in m.group(1).split(';'):
        if ':' not in trozo:
            if trozo.strip():
                salida.append(trozo.strip())
            continue
        prop, valor = trozo.split(':', 1)
        clave = prop.strip()
        if clave in nuevas:
            salida.append(clave + ':' + nuevas[clave])
            puestas.add(clave)
        else:
            salida.append(clave + ':' + valor.strip())
    for clave, valor in nuevas.items():
        if clave not in puestas:
            salida.append(clave + ':' + valor)

    final = ';'.join(salida)
    if final == m.group(1).strip().rstrip(';'):
        return etiqueta
    return etiqueta[:m.start(1)] + final + etiqueta[m.end(1):]


def relativa(url, archivo):
    """La URL tal y como debe quedar escrita en ESE archivo."""
    if url.startswith(SITIO):
        return '../' * archivo.count('/') + url[len(SITIO):]
    return url


def archivos_html():
    for raiz, dirs, nombres in os.walk('.'):
        dirs[:] = [d for d in dirs if not d.startswith('.') or d == '.github']
        for n in nombres:
            if not n.endswith('.html'):
                continue
            ruta = os.path.relpath(os.path.join(raiz, n), '.')
            if ruta.startswith(FUERA) or '/.' in '/' + ruta:
                continue
            yield ruta


def sin_cubrir(archivos):
    """Fotos que NADIE iguala, o marcadas dos veces.

    ⚠️ ESTO EXISTE PORQUE EL ARREGLO SE QUEDÓ CORTO DOS VECES SEGUIDAS.
    Primero se igualaron los huecos con `data-img` y las cabeceras de
    sección, y /entrenar/ siguió cambiando las fotos al abrirse: sus
    tarjetas no llevan `data-img`, dicen de qué sección son con `data-sec`,
    y nadie las miraba. Al añadirlas, las de /escuelas/ —que llevan LAS DOS
    marcas— se quedaron con dos ayudantes escribiendo el mismo `src`, o sea
    el parpadeo otra vez y peor.

    Andrés: «revisa y que no vuelva a pasar». Un arreglo no se sostiene
    solo; una comprobación que corre cada noche, sí. Esto lista lo que
    ninguna vía cubre y lo que dos vías se disputan, para que la siguiente
    forma de pintar una foto se note el primer día y no cuando alguien la
    vea moverse.
    """
    huerfanas, dobles = [], []
    for archivo in archivos:
        with open(archivo, encoding='utf-8') as f:
            texto = f.read()
        # dentro de una tarjeta de lanzadera
        for bloque in re.findall(r'<a[^>]*data-sec="[^"]+"[^>]*>.*?</a>', texto, flags=re.S):
            sec = re.search(r'data-sec="([^"]+)"', bloque).group(1)
            for etiqueta in re.findall(r'<img[^>]*>', bloque):
                if 'data-img=' in etiqueta:
                    dobles.append((archivo, sec, re.search(r'data-img="([^"]+)"', etiqueta).group(1)))
        # Fotos de tarjeta que no cubre NINGUNA vía: ni son hueco de
        # biblioteca, ni están dentro de una tarjeta con `data-sec`, ni son la
        # cabecera de una sección. Ésas nadie las mantiene al día.
        dentro_de_tarjeta = set()
        for bloque in re.findall(r'<a[^>]*data-sec="[^"]+"[^>]*>.*?</a>', texto, flags=re.S):
            dentro_de_tarjeta.update(re.findall(r'<img[^>]*>', bloque))
        for etiqueta in re.findall(r'<img[^>]*>', texto):
            if ('data-img=' in etiqueta or 'cs-hero-img' in etiqueta
                    or 'pag-hero-foto' in etiqueta or etiqueta in dentro_de_tarjeta):
                continue
            if 'lanz-foto' in etiqueta:
                huerfanas.append((archivo, etiqueta[:90]))
    return huerfanas, dobles


def main():
    solo_ver = '--ver' in sys.argv
    comprobar = '--comprobar' in sys.argv

    filas_bib = pedir('imagenes_web', 'clave,url,encuadre,zoom')
    biblioteca = {f['clave']: (f.get('url') or '').strip() for f in filas_bib}
    biblioteca_completa = {f['clave']: f for f in filas_bib}

    filas_cab = pedir('contenido_secciones', 'seccion,imagen_url,imagen_encuadre,imagen_zoom')
    cabeceras = {f['seccion']: (f.get('imagen_url') or '').strip() for f in filas_cab}
    cab_completa = {f['seccion']: f for f in filas_cab}

    cambios = []

    # --- 1 · los huecos marcados con data-img ---
    for archivo in archivos_html():
        with open(archivo, encoding='utf-8') as f:
            texto = original = f.read()

        def igualar(m):
            etiqueta = m.group(0)
            clave = re.search(r'data-img="([^"]+)"', etiqueta)
            if not clave:
                return etiqueta
            url = biblioteca.get(clave.group(1), '')
            if not url:
                # Sin foto elegida no se toca: manda la del HTML, que para
                # eso está. Vaciar el hueco sería peor que dejarlo viejo.
                return etiqueta
            nueva = relativa(url, archivo)
            fila = biblioteca_completa.get(clave.group(1), {})
            src = re.search(r'src="([^"]*)"', etiqueta)
            antes = etiqueta
            if src and src.group(1) != nueva:
                cambios.append((archivo, clave.group(1), src.group(1), nueva))
                etiqueta = etiqueta[:src.start(1)] + nueva + etiqueta[src.end(1):]
            estilo = encuadre_estilo(fila, etiqueta.lower().startswith('<img'))
            etiqueta = con_estilo(etiqueta, estilo)
            if etiqueta != antes and (not src or src.group(1) == nueva):
                cambios.append((archivo, clave.group(1) + ' (encuadre)', '—', estilo))
            return etiqueta

        texto = re.sub(r'<img[^>]*>', igualar, texto)

        # --- 2 · las tarjetas de las lanzaderas (/entrenar/, /escuelas/) ---
        # No llevan `data-img`: dicen de qué sección son con `data-sec`, y su
        # foto sale de la ficha de esa sección. Se quedaron fuera del primer
        # arreglo y por eso /entrenar/ seguía cambiando las fotos al abrirse.
        def tarjeta(m):
            bloque = m.group(0)
            sec = re.search(r'data-sec="([^"]+)"', bloque).group(1)
            u = cabeceras.get(sec, '')
            if not u:
                return bloque
            def dentro(mi):
                etiqueta, antes = mi.group(0), mi.group(0)
                # ⚠️ Si la foto ya es un hueco de biblioteca (`data-img`), manda
                # ésa y aquí no se toca. Las tarjetas de /escuelas/ llevan las
                # DOS marcas, y escribir la de la sección encima dejaba a dos
                # ayudantes peleándose por la misma <img> al cargar la página:
                # el parpadeo volvía, y peor, porque cambiaba de foto de verdad.
                if 'data-img=' in etiqueta:
                    return etiqueta
                nueva = relativa(u, archivo)
                s = re.search(r'src="([^"]*)"', etiqueta)
                if s and s.group(1) != nueva:
                    cambios.append((archivo, 'tarjeta:' + sec, s.group(1), nueva))
                    etiqueta = etiqueta[:s.start(1)] + nueva + etiqueta[s.end(1):]
                estilo = encuadre_estilo(cab_completa.get(sec, {}))
                etiqueta = con_estilo(etiqueta, estilo)
                if etiqueta != antes and (not s or s.group(1) == nueva):
                    cambios.append((archivo, 'tarjeta:' + sec + ' (encuadre)', '—', estilo))
                return etiqueta
            return re.sub(r'<img[^>]*>', dentro, bloque, count=1)

        texto = re.sub(r'<a[^>]*data-sec="[^"]+"[^>]*>.*?</a>', tarjeta, texto, flags=re.S)

        # --- 3 · la foto grande de la cabecera de sección ---
        slug = archivo.split('/')[0] if '/' in archivo else 'home'
        ficha = next((s for s, p in PAGINA_DE.items() if p == archivo), None)
        if ficha is None and archivo.endswith('/index.html'):
            ficha = slug if slug in cabeceras else None
        if ficha is None and archivo == 'index.html':
            ficha = 'home'
        url = cabeceras.get(ficha, '') if ficha else ''
        if url:
            def cabecera(m):
                etiqueta = m.group(0)
                antes = etiqueta
                nueva = relativa(url, archivo)
                src = re.search(r'src="([^"]*)"', etiqueta)
                if src and src.group(1) != nueva:
                    cambios.append((archivo, 'cabecera:' + ficha, src.group(1), nueva))
                    etiqueta = etiqueta[:src.start(1)] + nueva + etiqueta[src.end(1):]
                estilo = encuadre_estilo(cab_completa.get(ficha, {}))
                etiqueta = con_estilo(etiqueta, estilo)
                if etiqueta != antes and (not src or src.group(1) == nueva):
                    cambios.append((archivo, 'cabecera:' + ficha + ' (encuadre)', '—', estilo))
                return etiqueta
            texto = re.sub(r'<img id="cs-hero-img"[^>]*>|<img[^>]*class="pag-hero-foto"[^>]*>',
                           cabecera, texto)

        if texto != original and not solo_ver:
            with open(archivo, 'w', encoding='utf-8') as f:
                f.write(texto)

    huerfanas, dobles = sin_cubrir(list(archivos_html()))
    # Las dobles NO son un error: se sabe quién manda (la biblioteca) y las
    # dos vías lo respetan. Se dicen para que nadie se sorprenda al ver que
    # cambiar la foto de la sección no cambia la de la tarjeta.
    for archivo, sec, clave in dobles:
        print('·  %s · la tarjeta de «%s» usa la foto de biblioteca "%s", '
              'no la de la ficha de la sección.' % (archivo, sec, clave))
    for archivo, etiqueta in huerfanas:
        print('⚠️  %s · foto de tarjeta que nadie iguala: %s' % (archivo, etiqueta))

    if not cambios:
        print('Las fotos del HTML ya son las de la biblioteca. Nada que igualar.')
        return 1 if (comprobar and huerfanas) else 0

    print('%d foto(s) %s:' % (len(cambios), 'por igualar' if solo_ver else 'igualadas'))
    for archivo, clave, antes, ahora in cambios:
        print('  · %-38s %-26s %s → %s' % (archivo, clave, antes, ahora))
    # `--comprobar` es para usarlo como control: falla si algo NO cuadraba.
    return 1 if comprobar else 0


if __name__ == '__main__':
    sys.exit(main())
