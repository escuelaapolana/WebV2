#!/bin/bash
# ============================================================
# backup.sh · copia de seguridad de la base de Apolana
# ------------------------------------------------------------
# Hace un volcado COMPLETO del esquema `public` (todos los datos del club,
# funciones y RLS), comprimido y con fecha, en ~/Proyectos/Apolana-backups/.
# Luego súbelo a Drive.
#
#   bash herramientas/backup.sh
#
# Usa la misma contraseña que .secrets/psql.sh (.secrets/db_password), que NO
# está en git. NO incluye las cuentas de acceso (auth) ni las fotos (Storage):
# eso es aparte.
# ============================================================
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
SECRET="$(cat "$DIR/.secrets/db_password")"
PW="${SECRET#postgresql://postgres.icaxokjsvhlreuwpyxeb:}"
PW="${PW%%@aws-1-eu-central-1.pooler.supabase.com*}"

DEST="$HOME/Proyectos/Apolana-backups"
mkdir -p "$DEST"
STAMP="$(date +%Y%m%d_%H%M)"
OUT="$DEST/apolana_public_${STAMP}.sql.gz"

PGDUMP="/opt/homebrew/opt/libpq/bin/pg_dump"

echo "Haciendo copia de seguridad de la base… (puede tardar unos segundos)"
PGPASSWORD="$PW" "$PGDUMP" \
  -h aws-1-eu-central-1.pooler.supabase.com -p 5432 \
  -U postgres.icaxokjsvhlreuwpyxeb -d postgres \
  -n public --no-owner | gzip > "$OUT"

TABLAS="$(gzip -dc "$OUT" | grep -c '^CREATE TABLE' || true)"
echo ""
echo "✅ Copia hecha: $OUT"
echo "   $(ls -lh "$OUT" | awk '{print $5}') · $TABLAS tablas"
echo ""
echo "➡️  Súbela a Google Drive para tenerla a salvo."
