#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Exporta el feedback de los atletas de Academia AC98 a dos CSV con la MISMA
forma que el control maestro (hojas BIENESTAR y SESIONES), listos para pegar.

    python3 herramientas/export_feedback.py [--out CARPETA] [--desde AAAA-MM-DD]

- Lee de la base real usando .secrets/psql.sh (no expone credenciales).
- Casa cada atleta por su `atleta_id` (uuid) con su código AP-00N y su nombre
  EXACTO del maestro: así da igual que en la app se llame «Rafael Gil de
  Bernabe Valero» y en el maestro «Rafa Gil de Bernabé».
- Excluye a Irene (AP-009, se planifica a mano) y a cualquiera que no esté en
  el maestro (p. ej. Andrés, que es el entrenador).
- UTF-8, fechas AAAA-MM-DD, desplegables ya traducidos a su etiqueta.

OJO con `sesion_id` (columna C de SESIONES): el maestro usa su propio código de
plan («S2-COM-L»…) que la app no conoce. Aquí va «fecha · título» de la sesión
de la app, que es matcheable; si quieres su código exacto, se sustituye a mano.
"""
import csv, os, subprocess, sys, argparse

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PSQL = os.path.join(REPO, '.secrets', 'psql.sh')
GRUPO_ACADEMIA = 'c288b979-cd00-4abb-96da-30fa997ef297'

# atleta_id (uuid de la app) -> (AP-00N, nombre EXACTO del maestro, columna B)
# Irene se deja fuera a propósito (se planifica a mano). Pablo Rodríguez (AP-008)
# está en el maestro pero no en el grupo de la app, así que no aparece aquí.
ATLETAS = {
    '3e0355ca-c758-40f4-8959-795980e95ba9': ('AP-001', 'Mateo Brián'),
    '1cf6a6ff-091f-42d1-822b-2a12b0d93b28': ('AP-002', 'Giovanna Lanz'),
    'd98fde93-b3af-442e-8ed7-381a0b1ba909': ('AP-003', 'Ander Pastor'),
    '0762c205-7fed-43ee-a213-1be4f1caa6d9': ('AP-004', 'Juan Asensi'),
    '7eab9e45-435f-4ef7-a189-8368c773b427': ('AP-005', 'Adrián Berenguer'),
    'c2559895-be13-4eb5-b48a-48cc3bc83359': ('AP-006', 'Rafa Gil de Bernabé'),
    '0106f9c3-8e83-4719-afec-90cc1f37010a': ('AP-007', 'Gabriel García del Dionisio'),
    # '8a77922d-...': Irene Ferriz Mejías (AP-009) -> EXCLUIDA a propósito
    # '308afb35-...': Andrés Clavero -> entrenador, no está en el maestro
}

# Traducción de los desplegables (código en BD -> etiqueta del maestro)
LOCALIZACION = {'ninguna': 'Ninguna', 'isquio': 'Isquio', 'soleo_gemelo': 'Sóleo/gemelo',
                'rodilla': 'Rodilla', 'lumbar': 'Lumbar', 'cadera': 'Cadera',
                'tobillo': 'Tobillo', 'aductor': 'Aductor', 'pie': 'Pie', 'otra': 'Otra'}
SUPERFICIE = {'pista': 'Pista', 'hierba': 'Hierba', 'asfalto': 'Asfalto', 'tierra': 'Tierra',
              'gimnasio': 'Gimnasio', 'mixta': 'Mixta', 'otra': 'Otra'}
# estado -> columna S del maestro: Hecha y A medias -> «Sí»; No hecha -> «No»
ESTADO_SI_NO = {'completo': 'Sí', 'a_medias': 'Sí', 'no_hecho': 'No'}


def psql_csv(query):
    """Ejecuta una consulta y devuelve filas como lista de dicts (cabecera CSV)."""
    out = subprocess.run(['bash', PSQL, '-v', 'ON_ERROR_STOP=1', '--csv', '-c', query],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.stderr.write(out.stderr)
        raise SystemExit('Error consultando la base (ver arriba).')
    return list(csv.DictReader(out.stdout.splitlines()))


def limpia(v):
    return '' if v is None else str(v).strip()


def exporta_sesiones(desde):
    filtro_fecha = "AND COALESCE(s.fecha, r.created_at::date) >= '%s'" % desde if desde else ''
    q = """
    SELECT r.atleta_id::text AS aid,
           COALESCE(s.fecha, r.created_at::date)::text AS fecha,
           COALESCE(s.titulo, '') AS titulo, COALESCE(s.deporte, '') AS deporte,
           r.duracion_min, r.rpe, r.completado_pct, r.superficie,
           r.molestia_sesion, r.notas_atleta, r.estado
    FROM registros_sesion r
    JOIN atletas a ON a.id = r.atleta_id
    LEFT JOIN sesiones s ON s.id = r.sesion_id
    WHERE a.grupo_id = '%s' %s
    ORDER BY fecha, a.nombre, a.apellidos;
    """ % (GRUPO_ACADEMIA, filtro_fecha)
    rows, saltados = [], []
    for r in psql_csv(q):
        m = ATLETAS.get(r['aid'])
        if not m:
            saltados.append(r['aid'])
            continue
        ap, nombre = m
        titulo = limpia(r['titulo']) or (limpia(r['deporte']).capitalize() or 'Sesión')
        sesion_id = '%s · %s' % (r['fecha'], titulo)
        sup = SUPERFICIE.get(limpia(r['superficie']).lower(), limpia(r['superficie']))
        est = ESTADO_SI_NO.get(limpia(r['estado']).lower(), '')
        # Orden posicional del maestro (A..S). Vacío = columna que no alimenta la app
        # o que es fórmula (I = sRPE = G×H). La cabecera nombra cada columna.
        rows.append([
            r['fecha'], nombre, sesion_id, '', '', '',           # A fecha B atleta C sesion_id D E F
            limpia(r['duracion_min']), limpia(r['rpe']), '',      # G duracion H rpe I sRPE(fórmula)
            limpia(r['completado_pct']), '', '', '', '',          # J completado_pct K L M N
            sup, '',                                              # O superficie P
            limpia(r['molestia_sesion']), limpia(r['notas_atleta']), est,  # Q molestia R notas S estado
        ])
    cab = ['fecha', 'atleta', 'sesion_id', '', '', '', 'duracion_min', 'rpe',
           'sRPE (fórmula)', 'completado_pct', '', '', '', '', 'superficie', '',
           'molestia_sesion', 'notas', 'estado']
    return cab, rows, saltados


def exporta_bienestar(desde):
    filtro_fecha = "AND b.fecha >= '%s'" % desde if desde else ''
    q = """
    SELECT b.atleta_id::text AS aid, b.fecha::text AS fecha, b.horas_sueno,
           b.sueno_calidad, b.fatiga, b.dolor_muscular, b.estres, b.motivacion,
           b.molestia, b.molestia_localizacion, b.nota
    FROM bienestar_diario b
    JOIN atletas a ON a.id = b.atleta_id
    WHERE a.grupo_id = '%s' %s
    ORDER BY b.fecha, a.nombre, a.apellidos;
    """ % (GRUPO_ACADEMIA, filtro_fecha)
    rows, saltados = [], []
    for r in psql_csv(q):
        m = ATLETAS.get(r['aid'])
        if not m:
            saltados.append(r['aid'])
            continue
        ap, nombre = m
        loc = LOCALIZACION.get(limpia(r['molestia_localizacion']).lower(), limpia(r['molestia_localizacion']))
        rows.append([
            r['fecha'], nombre, limpia(r['horas_sueno']), limpia(r['sueno_calidad']),  # A B C D
            limpia(r['fatiga']), limpia(r['dolor_muscular']), limpia(r['estres']),      # E F G
            limpia(r['motivacion']), '',                                               # H I índice(fórmula)
            limpia(r['molestia']), loc, limpia(r['nota']),                             # J K L
        ])
    cab = ['fecha', 'atleta', 'sueno_h', 'sueno_calidad', 'fatiga', 'dolor_muscular',
           'estres', 'motivacion', 'índice (fórmula)', 'molestia', 'molestia_localizacion',
           'comentario']
    return cab, rows, saltados


def escribe(path, cab, rows):
    with open(path, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(cab)
        w.writerows(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(REPO, 'herramientas', 'export'))
    ap.add_argument('--desde', default=None, help='Solo fechas >= AAAA-MM-DD')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)

    cab_s, filas_s, salt_s = exporta_sesiones(a.desde)
    cab_b, filas_b, salt_b = exporta_bienestar(a.desde)
    p_s = os.path.join(a.out, 'maestro_SESIONES.csv')
    p_b = os.path.join(a.out, 'maestro_BIENESTAR.csv')
    escribe(p_s, cab_s, filas_s)
    escribe(p_b, cab_b, filas_b)

    print('SESIONES  -> %s  (%d filas)' % (p_s, len(filas_s)))
    print('BIENESTAR -> %s  (%d filas)' % (p_b, len(filas_b)))
    saltados = set(salt_s) | set(salt_b)
    if saltados:
        print('\nAtletas fuera del maestro (no exportados): %d uuid distintos' % len(saltados))
        print('  (Irene AP-009 y el entrenador van fuera a propósito)')


if __name__ == '__main__':
    main()
