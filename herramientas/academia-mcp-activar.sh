#!/bin/bash
# =====================================================================
# Activa (o renueva) la conexión de Academia AC98 en la app de ChatGPT de este Mac.
#
#   bash herramientas/academia-mcp-activar.sh
#
#   1. Genera una clave nueva. NO se muestra en pantalla ni se guarda en
#      ningún fichero.
#   2. La guarda en el Llavero del Mac (servicio «apolana-academia-mcp»).
#   3. Registra en la base SOLO su huella (sha256), con acceso únicamente a
#      Academia AC98 (leer, borradores, revisiones; publicar solo con código).
#      Revoca TODAS las claves activas de esta conexión («ChatGPT · Mac de Andrés…»).
#   4. Añade el servidor «apolana_academia» a Codex (~/.codex/config.toml),
#      que arranca el puente local herramientas/academia-mcp-puente.py.
#   5. Comprueba la conexión.
#
# Después: cerrar y volver a abrir la app de ChatGPT.
# Para desactivarla:  bash herramientas/academia-mcp-activar.sh --quitar
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(pwd -P)"   # ruta real (no el acceso del Escritorio, que sincroniza iCloud)
CODEX="/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
SERVICIO="apolana-academia-mcp"
NOMBRE="ChatGPT · Mac de Andrés"
# Al renovar o quitar se revocan TODAS las claves activas de esta conexión: las
# que se llaman «ChatGPT · Mac de Andrés…» (la viva y las viejas «… (prueba)»).
# Antes solo buscaba el nombre con «(prueba)» y la viva seguía valiendo (auditoría 1-nov).
REVOCAR_SQL="update api_claves set revocada_en = now() where nombre like 'ChatGPT · Mac de Andrés%' and revocada_en is null;"
# El grupo de PRUEBA se borró el 1-nov-2026. La clave entra en Academia AC98 real por
# academia_api_habilitados (mig 499): al renovarla se le vuelve a dar ese permiso.
GRUPO_ACADEMIA="c288b979-cd00-4abb-96da-30fa997ef297"

[ -x "$CODEX" ] || { echo "✗ No encuentro la app de ChatGPT en /Applications."; exit 1; }
[ -f .secrets/psql.sh ] || { echo "✗ Falta .secrets/psql.sh (acceso a la base)."; exit 1; }

if [ "${1:-}" = "--quitar" ]; then
  bash .secrets/psql.sh -q -v ON_ERROR_STOP=1 -c "$REVOCAR_SQL"
  /usr/bin/security delete-generic-password -s "$SERVICIO" >/dev/null 2>&1 || true
  "$CODEX" mcp remove apolana_academia >/dev/null 2>&1 || true
  echo "✓ Conexión quitada: clave revocada, borrada del Llavero y servidor quitado de Codex."
  exit 0
fi

# 1-2. Clave nueva → Llavero (sin mostrarla)
CLAVE="apo_ac_$(openssl rand -hex 24)"
HUELLA=$(printf '%s' "$CLAVE" | shasum -a 256 | cut -d' ' -f1)
/usr/bin/security add-generic-password -U -a "$USER" -s "$SERVICIO" \
  -l "Apolana · Academia (ChatGPT)" -T /usr/bin/security -w "$CLAVE"
unset CLAVE
echo "✓ Clave nueva guardada en el Llavero (servicio $SERVICIO)."

# 3. En la base, solo la huella
bash .secrets/psql.sh -q -v ON_ERROR_STOP=1 <<SQL
begin;
$REVOCAR_SQL
insert into api_claves (nombre, hash, grupos, permisos, creada_por)
values ('$NOMBRE', '$HUELLA', '{}'::uuid[],
        '{leer,borradores,revisiones}',
        (select id from perfiles where email = 'andres.apolana@gmail.com' limit 1));
-- Academia AC98 real: leer, borradores y revisiones; publicar solo con su código (mig 499).
insert into academia_api_habilitados (clave_id, grupo_id, permisos, habilitado_por, motivo)
select k.id, '$GRUPO_ACADEMIA', '{leer,borradores,revisiones,publicar}', k.creada_por,
       'Renovación de la clave: mismo permiso que el 29-oct-2026 (planificación de Academia AC98; publicar solo con autorización expresa de Andrés)'
  from api_claves k where k.nombre = '$NOMBRE' and k.hash = '$HUELLA';
commit;
SQL
echo "✓ Registrada en la base (Academia AC98: leer, borradores, revisiones y publicar con código). Las claves anteriores de esta conexión quedan revocadas."

# 4. Servidor en Codex (si ya estaba, se sustituye)
"$CODEX" mcp remove apolana_academia >/dev/null 2>&1 || true
"$CODEX" mcp add apolana_academia -- /usr/bin/python3 "$REPO/herramientas/academia-mcp-puente.py" >/dev/null
echo "✓ Servidor «apolana_academia» añadido a Codex."

# 5. Comprobación (lee la clave del Llavero, como hará la app)
RES=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"estado","arguments":{}}}' \
  | /usr/bin/python3 "$REPO/herramientas/academia-mcp-puente.py")
if echo "$RES" | grep -q 'Academia AC98'; then
  echo "✓ Conexión comprobada: responde el grupo «Academia AC98»."
  echo
  echo "Ahora cierra la app de ChatGPT del todo (⌘Q) y vuelve a abrirla."
else
  echo "✗ La comprobación no ha ido bien:"; echo "$RES" | head -c 400; echo
  exit 1
fi
