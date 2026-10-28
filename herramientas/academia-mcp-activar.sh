#!/bin/bash
# =====================================================================
# Activa la conexión de PRUEBA de Academia en la app de ChatGPT de este Mac.
#
#   bash herramientas/academia-mcp-activar.sh
#
#   1. Genera una clave nueva. NO se muestra en pantalla ni se guarda en
#      ningún fichero.
#   2. La guarda en el Llavero del Mac (servicio «apolana-academia-mcp»).
#   3. Registra en la base SOLO su huella (sha256), con acceso únicamente al
#      grupo «Academia AC98 · PRUEBA». Revoca la clave anterior de este Mac.
#   4. Añade el servidor «apolana_academia» a Codex (~/.codex/config.toml),
#      que arranca el puente local herramientas/academia-mcp-puente.py.
#   5. Comprueba la conexión.
#
# Después: cerrar y volver a abrir la app de ChatGPT.
# Para desactivarla:  bash herramientas/academia-mcp-activar.sh --quitar
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
CODEX="/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
SERVICIO="apolana-academia-mcp"
NOMBRE="ChatGPT · Mac de Andrés (prueba)"
GRUPO_PRUEBA="9fefd649-2fa2-4036-a4c0-dffe29a7bdee"

[ -x "$CODEX" ] || { echo "✗ No encuentro la app de ChatGPT en /Applications."; exit 1; }
[ -f .secrets/psql.sh ] || { echo "✗ Falta .secrets/psql.sh (acceso a la base)."; exit 1; }

if [ "${1:-}" = "--quitar" ]; then
  bash .secrets/psql.sh -q -c "update api_claves set revocada_en = now() where nombre = '$NOMBRE' and revocada_en is null;"
  /usr/bin/security delete-generic-password -s "$SERVICIO" >/dev/null 2>&1 || true
  "$CODEX" mcp remove apolana_academia >/dev/null 2>&1 || true
  echo "✓ Conexión quitada: clave revocada, borrada del Llavero y servidor quitado de Codex."
  exit 0
fi

# 1-2. Clave nueva → Llavero (sin mostrarla)
CLAVE="apo_ac_$(openssl rand -hex 24)"
HUELLA=$(printf '%s' "$CLAVE" | shasum -a 256 | cut -d' ' -f1)
/usr/bin/security add-generic-password -U -a "$USER" -s "$SERVICIO" \
  -l "Apolana · Academia (ChatGPT, prueba)" -T /usr/bin/security -w "$CLAVE"
unset CLAVE
echo "✓ Clave nueva guardada en el Llavero (servicio $SERVICIO)."

# 3. En la base, solo la huella
bash .secrets/psql.sh -q -v ON_ERROR_STOP=1 <<SQL
begin;
update api_claves set revocada_en = now() where nombre = '$NOMBRE' and revocada_en is null;
insert into api_claves (nombre, hash, grupos, permisos, creada_por)
values ('$NOMBRE', '$HUELLA', array['$GRUPO_PRUEBA']::uuid[],
        '{leer,borradores,revisiones,publicar_prueba}',
        (select id from perfiles where email = 'andres.apolana@gmail.com' limit 1));
commit;
SQL
echo "✓ Registrada en la base (solo el grupo PRUEBA). La clave anterior de este Mac, si había, queda revocada."

# 4. Servidor en Codex (si ya estaba, se sustituye)
"$CODEX" mcp remove apolana_academia >/dev/null 2>&1 || true
"$CODEX" mcp add apolana_academia -- /usr/bin/python3 "$REPO/herramientas/academia-mcp-puente.py" >/dev/null
echo "✓ Servidor «apolana_academia» añadido a Codex."

# 5. Comprobación (lee la clave del Llavero, como hará la app)
RES=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"estado","arguments":{}}}' \
  | /usr/bin/python3 "$REPO/herramientas/academia-mcp-puente.py")
if echo "$RES" | grep -q '"datos_ficticios": true'; then
  echo "✓ Conexión comprobada: responde el grupo «Academia AC98 · PRUEBA»."
  echo
  echo "Ahora cierra la app de ChatGPT del todo (⌘Q) y vuelve a abrirla."
else
  echo "✗ La comprobación no ha ido bien:"; echo "$RES" | head -c 400; echo
  exit 1
fi
