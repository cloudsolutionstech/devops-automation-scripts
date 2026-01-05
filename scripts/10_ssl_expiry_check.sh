#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

need_cmd openssl
need_cmd date

DOMAIN="${1:-example.com}"
PORT="${PORT:-443}"
WARN_DAYS="${WARN_DAYS:-30}"

ENDDATE="$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:$PORT" 2>/dev/null \
  | openssl x509 -noout -enddate | cut -d= -f2 || true)"

[[ -z "$ENDDATE" ]] && die "Could not read certificate end date for $DOMAIN:$PORT"

END_EPOCH="$(date -d "$ENDDATE" +%s)"
NOW_EPOCH="$(date +%s)"
DAYS_LEFT=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))

if [[ "$DAYS_LEFT" -le "$WARN_DAYS" ]]; then
  echo "[WARN] $DOMAIN cert expires in $DAYS_LEFT days ($ENDDATE)"
  exit 1
fi

echo "[OK] $DOMAIN cert expires in $DAYS_LEFT days ($ENDDATE)"
exit 0