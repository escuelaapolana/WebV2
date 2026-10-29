#!/usr/bin/env python3
"""
Copia estática de las condiciones de Training Camps dentro de
training-camps/terms/index.html (entre las marcas CONDICIONES-ESTATICO).

Por qué: la página carga el texto bueno de la base (camp_condiciones, editable
en el panel) con JavaScript. Quien la lee sin JavaScript (buscadores, otras IA)
veía solo «Loading…». Esta copia es el respaldo: con JavaScript se sustituye
al momento por la versión de la base.

Uso (después de guardar o publicar unas condiciones nuevas en el panel):
    python3 herramientas/camp_condiciones_web.py
Lee la base con .secrets/psql.sh (no hay claves en el repo).
"""
import html, json, os, re, subprocess

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGINA = os.path.join(RAIZ, 'training-camps', 'terms', 'index.html')


def datos():
    sal = subprocess.run(['bash', os.path.join(RAIZ, '.secrets', 'psql.sh'), '-Atc', 'select camp_condiciones_publicas()'],
                         capture_output=True, text=True, check=True).stdout.strip()
    return json.loads(sal)


def num(v, es):
    v = float(v)
    s = ('%d' % v) if v == int(v) else ('%.2f' % v).rstrip('0').rstrip('.')
    return s.replace('.', ',') if es else s


def md(texto):
    out, lista = [], []
    def cierra():
        if lista:
            out.append('<ul>' + ''.join(lista) + '</ul>')
            lista.clear()
    for l in texto.split('\n'):
        s = l.strip()
        if not s:
            cierra(); continue
        if s.startswith('## '):
            cierra(); out.append('<h2>' + html.escape(s[3:].strip()) + '</h2>'); continue
        if s.startswith('- '):
            lista.append('<li>' + html.escape(s[2:].strip()) + '</li>'); continue
        cierra(); out.append('<p>' + html.escape(s) + '</p>')
    cierra()
    return '\n'.join(out)


def bloque(c, lang):
    es = lang == 'es'
    v = c['senal_valor']
    senal = (num(v, es) + ' %') if c['senal_tipo'] == 'porcentaje' else ((num(v, es) + ' €') if es else ('€' + num(v, es)))
    texto = c['texto_es' if es else 'texto_en']
    for k, val in {'senal': senal, 'senal_dias': c['senal_dias_pago'], 'saldo_dias': c['saldo_dias_antes'], 'validez_dias': c['validez_dias']}.items():
        texto = texto.replace('{' + k + '}', str(val))
    nota = ('Versión %s%s. Copia de referencia: con JavaScript activado se muestra siempre la versión vigente.'
            if es else 'Version %s%s. Reference copy: with JavaScript enabled the current version is always shown.')
    borr = (' (borrador)' if es else ' (draft)') if c.get('borrador') else ''
    return '<div class="tt-est" lang="%s"><p class="tt-meta"><span>%s</span></p>\n%s\n</div>' % (lang, html.escape(nota % (c['version'], borr)), md(texto))


def main():
    c = datos()
    nuevo = '<!-- CONDICIONES-ESTATICO · lo genera herramientas/camp_condiciones_web.py · no editar a mano -->\n' + \
            bloque(c, 'en') + '\n' + bloque(c, 'es') + '\n<!-- /CONDICIONES-ESTATICO -->'
    t = open(PAGINA, encoding='utf-8').read()
    t2, n = re.subn(r'<!-- CONDICIONES-ESTATICO.*?<!-- /CONDICIONES-ESTATICO -->', lambda m: nuevo, t, flags=re.S)
    if not n:
        raise SystemExit('No encuentro las marcas CONDICIONES-ESTATICO en ' + PAGINA)
    if t2 != t:
        open(PAGINA, 'w', encoding='utf-8').write(t2)
        print('Actualizada la copia estática (versión %s).' % c['version'])
    else:
        print('Sin cambios (versión %s).' % c['version'])


if __name__ == '__main__':
    main()
