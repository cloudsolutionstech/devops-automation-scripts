#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

ensure_awscli || exit 1

echo "username,key_id,status,create_date,last_used_date,last_used_service,last_used_region"

USERS="$(aws iam list-users --query "Users[].UserName" --output text || true)"
[[ -z "${USERS// }" ]] && exit 0

for U in $USERS; do
  KEYS="$(aws iam list-access-keys --user-name "$U" \
    --query "AccessKeyMetadata[].{id:AccessKeyId,status:Status,create:CreateDate}" --output text || true)"

  if [[ -z "${KEYS// }" ]]; then
    echo "$U,,NO_KEYS,,,"
    continue
  fi

  while read -r KEY_ID STATUS CREATE_DATE; do
    [[ -z "${KEY_ID:-}" ]] && continue

    # Try jq first (clean), fallback to grep if jq missing
    if command -v jq >/dev/null 2>&1; then
      LAST_USED_JSON="$(aws iam get-access-key-last-used --access-key-id "$KEY_ID")"
      LAST_USED_DATE="$(echo "$LAST_USED_JSON" | jq -r '.AccessKeyLastUsed.LastUsedDate // "N/A"')"
      LAST_USED_SERVICE="$(echo "$LAST_USED_JSON" | jq -r '.AccessKeyLastUsed.ServiceName // "N/A"')"
      LAST_USED_REGION="$(echo "$LAST_USED_JSON" | jq -r '.AccessKeyLastUsed.Region // "N/A"')"
    else
      LAST_USED_JSON="$(aws iam get-access-key-last-used --access-key-id "$KEY_ID" --output json)"
      LAST_USED_DATE="$(echo "$LAST_USED_JSON" | grep -oP '"LastUsedDate"\s*:\s*"\K[^"]+' || true)"
      LAST_USED_SERVICE="$(echo "$LAST_USED_JSON" | grep -oP '"ServiceName"\s*:\s*"\K[^"]+' || true)"
      LAST_USED_REGION="$(echo "$LAST_USED_JSON" | grep -oP '"Region"\s*:\s*"\K[^"]+' || true)"
      LAST_USED_DATE="${LAST_USED_DATE:-N/A}"
      LAST_USED_SERVICE="${LAST_USED_SERVICE:-N/A}"
      LAST_USED_REGION="${LAST_USED_REGION:-N/A}"
    fi

    echo "$U,$KEY_ID,$STATUS,$CREATE_DATE,$LAST_USED_DATE,$LAST_USED_SERVICE,$LAST_USED_REGION"
  done <<< "$KEYS"
done
