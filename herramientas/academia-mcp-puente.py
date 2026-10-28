#!/usr/bin/env python3
"""Puente local MCP (stdio ↔ HTTPS) para la conexión de PRUEBA de Academia.

Lo arranca Codex (la app de ChatGPT para Mac) como servidor MCP «stdio»:
lee cada mensaje JSON-RPC por la entrada estándar, lo manda a la función
academia-mcp de Supabase con la clave en la cabecera y devuelve la respuesta
por la salida estándar.

La clave NO está en ningún fichero: se lee del Llavero del Mac (servicio
«apolana-academia-mcp», la deja ahí herramientas/academia-mcp-activar.sh).
Solo para pruebas técnicas se puede pasar en la variable APOLANA_ACADEMIA_TOKEN.

Sin dependencias: funciona con el Python del sistema (/usr/bin/python3).
"""
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

URL = os.environ.get(
    "APOLANA_ACADEMIA_URL",
    "https://icaxokjsvhlreuwpyxeb.supabase.co/functions/v1/academia-mcp",
)
SERVICIO_LLAVERO = "apolana-academia-mcp"


def leer_clave():
    t = os.environ.get("APOLANA_ACADEMIA_TOKEN", "").strip()
    if t:
        return t
    try:
        r = subprocess.run(
            ["/usr/bin/security", "find-generic-password", "-s", SERVICIO_LLAVERO, "-w"],
            capture_output=True, text=True, timeout=20,
        )
    except Exception:
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


def escribir(msg):
    sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def error(id_, texto, code=-32000):
    return {"jsonrpc": "2.0", "id": id_, "error": {"code": code, "message": texto}}


def main():
    clave = leer_clave()
    for linea in sys.stdin:
        linea = linea.strip()
        if not linea:
            continue
        try:
            msg = json.loads(linea)
        except ValueError:
            continue
        lote = isinstance(msg, list)
        ids = [m.get("id") for m in (msg if lote else [msg]) if isinstance(m, dict) and m.get("id") is not None]
        if not clave:
            for i in ids:
                escribir(error(i, "Falta la clave de Academia en el Llavero (servicio apolana-academia-mcp). "
                                  "Ejecuta herramientas/academia-mcp-activar.sh.", -32001))
            continue
        peticion = urllib.request.Request(
            URL,
            data=json.dumps(msg).encode("utf-8"),
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream",
                "Authorization": "Bearer " + clave,
            },
        )
        try:
            with urllib.request.urlopen(peticion, timeout=90) as r:
                cuerpo = r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            try:
                cuerpo = e.read().decode("utf-8")
            except Exception:
                cuerpo = ""
            if not ids:
                continue
            try:
                resp = json.loads(cuerpo)
                texto = resp.get("error", {}).get("message") or ("HTTP %s" % e.code)
            except Exception:
                texto = "HTTP %s" % e.code
            for i in ids:
                escribir(error(i, texto, -32001 if e.code == 401 else -32000))
            continue
        except Exception as e:  # red caída, tiempo agotado…
            for i in ids:
                escribir(error(i, "No se pudo conectar con el club: %s" % e))
            continue
        if not ids or not cuerpo.strip():
            continue   # notificaciones: no llevan respuesta
        try:
            escribir(json.loads(cuerpo))
        except ValueError:
            for i in ids:
                escribir(error(i, "Respuesta no válida del servidor."))


if __name__ == "__main__":
    main()
