#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

need_cmd curl

TIMEOUT="${TIMEOUT:-5}"
URL="${1:-http://localhost:8080/health}"

CODE="$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$URL" || echo "000")"
if [[ "$CODE" != "200" ]]; then
  echo "[FAIL] $URL returned HTTP $CODE"
  exit 1
fi
echo "[OK]   $URL returned HTTP $CODE"
exit 0