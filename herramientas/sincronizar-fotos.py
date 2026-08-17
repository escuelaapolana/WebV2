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


def main():
    solo_ver = '--ver' in sys.argv

    biblioteca = {f['clave']: (f.get('url') or '').strip()
                  for f in pedir('imagenes_web', 'clave,url')}
    cabeceras = {f['seccion']: (f.get('imagen_url') or '').strip()
                 for f in pedir('contenido_secciones', 'seccion,imagen_url')}

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
            src = re.search(r'src="([^"]*)"', etiqueta)
            if not src or src.group(1) == nueva:
                return etiqueta
            cambios.append((archivo, clave.group(1), src.group(1), nueva))
            return etiqueta[:src.start(1)] + nueva + etiqueta[src.end(1):]

        texto = re.sub(r'<img[^>]*>', igualar, texto)

        # --- 2 · la foto grande de la cabecera de sección ---
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
                nueva = relativa(url, archivo)
                src = re.search(r'src="([^"]*)"', etiqueta)
                if not src or src.group(1) == nueva:
                    return etiqueta
                cambios.append((archivo, 'cabecera:' + ficha, src.group(1), nueva))
                return etiqueta[:src.start(1)] + nueva + etiqueta[src.end(1):]
            texto = re.sub(r'<img id="cs-hero-img"[^>]*>|<img[^>]*class="pag-hero-foto"[^>]*>',
                           cabecera, texto)

        if texto != original and not solo_ver:
            with open(archivo, 'w', encoding='utf-8') as f:
                f.write(texto)

    if not cambios:
        print('Las fotos del HTML ya son las de la biblioteca. Nada que igualar.')
        return 0

    print('%d foto(s) %s:' % (len(cambios), 'por igualar' if solo_ver else 'igualadas'))
    for archivo, clave, antes, ahora in cambios:
        print('  · %-38s %-26s %s → %s' % (archivo, clave, antes, ahora))
    return 0


if __name__ == '__main__':
    sys.exit(main())
