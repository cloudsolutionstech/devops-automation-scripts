#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

ensure_awscli || exit 1

MAX_DAYS="${MAX_DAYS:-90}"
NOW_EPOCH="$(date -u +%s)"

echo "Report: Access keys older than $MAX_DAYS days"
echo "username,key_id,age_days,status,create_date"

USERS="$(aws iam list-users --query "Users[].UserName" --output text || true)"
[[ -z "${USERS// }" ]] && exit 0

for U in $USERS; do
  aws iam list-access-keys --user-name "$U" \
    --query "AccessKeyMetadata[].{id:AccessKeyId,status:Status,create:CreateDate}" --output text |
  while read -r KEY_ID STATUS CREATE_DATE; do
    [[ -z "${KEY_ID:-}" ]] && continue
    CREATE_EPOCH="$(to_epoch_utc "$CREATE_DATE")"
    AGE_DAYS=$(( (NOW_EPOCH - CREATE_EPOCH) / 86400 ))

    if [[ "$AGE_DAYS" -ge "$MAX_DAYS" ]]; then
      echo "$U,$KEY_ID,$AGE_DAYS,$STATUS,$CREATE_DATE"
    fi
  done
done
