#!/usr/bin/env python3
"""
Versiona los ficheros de la app (assets/js/*.js y assets/css/*.css) con
?v=<huella de su contenido> en TODAS las páginas y en los JS que cargan otros.

Por qué: Cloudflare guarda una copia de los .js/.css durante horas. Si el nombre
no cambia, sigue sirviendo la versión vieja aunque esté subida la nueva (pasó el
15-oct-2026 con la barra lateral y el buscador). Con ?v=huella, cada versión es
una dirección distinta: en cuanto cambia el fichero, cambia la dirección y
Cloudflare (y la caché del móvil) piden la nueva. Si el fichero NO cambia, la
huella tampoco, y la copia guardada sigue valiendo (la web va igual de rápida).

Uso:
    python3 herramientas/versionar.py            # versiona y dice qué ficheros tocó
    python3 herramientas/versionar.py --comprobar  # solo dice si falta algo (no escribe)

Lo llama el gancho de git `herramientas/hooks/pre-commit` en cada commit.
"""
import hashlib, os, re, sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALTAR = {'.git', '.claude', 'node_modules', '.secrets'}


def assets():
    out = {}
    for sub, ext in (('assets/js', '.js'), ('assets/css', '.css')):
        d = os.path.join(RAIZ, sub)
        if not os.path.isdir(d):
            continue
        for f in os.listdir(d):
            if f.endswith(ext):
                out[f] = os.path.join(d, f)
    return out


def huella(ruta):
    with open(ruta, 'rb') as fh:
        datos = fh.read()
    # Lo que este mismo script escribe (?v=…) no cuenta para la huella propia:
    # así un JS que carga a otro no cambia de huella en bucle.
    datos = re.sub(rb'\?v=[0-9a-f]{8}', b'', datos)
    return hashlib.sha1(datos).hexdigest()[:8]


def paginas():
    for base, dirs, files in os.walk(RAIZ):
        dirs[:] = [d for d in dirs if d not in SALTAR and '_maqueta' not in d]
        for f in files:
            if f.endswith('.html'):
                yield os.path.join(base, f)


def versiona_texto(texto, huellas, en_js):
    nombres = '|'.join(re.escape(n) for n in sorted(huellas, key=len, reverse=True))
    if en_js:
        # Literales de JS: 'assets/js/mundos.js', 'contactos-web.js'… (comilla simple)
        patron = re.compile(r"'((?:[^'\s]*?assets/(?:js|css)/)?(" + nombres + r"))(?:\?v=[0-9a-f]{8})?'")
        return patron.sub(lambda m: "'" + m.group(1) + '?v=' + huellas[m.group(2)] + "'", texto)
    # HTML: src="…assets/js/x.js" / href="…assets/css/x.css" (con o sin ?v= / ?n=)
    patron = re.compile(r'((?:src|href)=(["\']))([^"\']*?assets/(?:js|css)/(' + nombres + r'))(\?[^"\']*)?\2')
    def rep(m):
        q = m.group(5) or ''
        q = re.sub(r'(^\?|&)v=[0-9a-f]{8}', '', q).lstrip('?&')
        return m.group(1) + m.group(3) + '?v=' + huellas[m.group(4)] + ('&' + q if q else '') + m.group(2)
    return patron.sub(rep, texto)


def git(*args):
    import subprocess
    return subprocess.run(['git', *args], cwd=RAIZ, capture_output=True, text=True).stdout


def main():
    comprobar = '--comprobar' in sys.argv
    gancho = '--gancho' in sys.argv
    # En el gancho: los ficheros con cambios SIN preparar de antes no se añaden
    # (no queremos colar en el commit trabajo a medias de otra cosa).
    a_medias = set(git('diff', '--name-only').split()) if gancho else set()
    rutas = assets()
    tocados = set()
    # Primero los JS (los que cargan a otros cambian; se repite hasta que no cambie nada)
    for _ in range(6):
        huellas = {n: huella(r) for n, r in rutas.items()}
        cambio = False
        for n, r in rutas.items():
            if not n.endswith('.js'):
                continue
            t = open(r, encoding='utf-8').read()
            nt = versiona_texto(t, {k: v for k, v in huellas.items() if k != n}, True)
            if nt != t:
                cambio = True
                tocados.add(r)
                if not comprobar:
                    open(r, 'w', encoding='utf-8').write(nt)
        if not cambio or comprobar:
            break
    huellas = {n: huella(r) for n, r in rutas.items()}
    for p in paginas():
        t = open(p, encoding='utf-8').read()
        nt = versiona_texto(t, huellas, False)
        if nt != t:
            tocados.add(p)
            if not comprobar:
                open(p, 'w', encoding='utf-8').write(nt)
    for p in sorted(tocados):
        rel = os.path.relpath(p, RAIZ)
        if gancho:
            if rel in a_medias:
                print('versionar: ' + rel + ' tiene cambios sin preparar; su ?v= se sube en el próximo commit', file=sys.stderr)
            else:
                git('add', '--', rel)
        else:
            print(rel)
    if comprobar and tocados:
        sys.exit(1)


if __name__ == '__main__':
    main()
