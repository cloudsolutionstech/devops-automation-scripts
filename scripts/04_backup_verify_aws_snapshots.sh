#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

ensure_awscli || exit 1

REGION="${REGION:-us-east-1}"
MAX_AGE_HOURS="${MAX_AGE_HOURS:-30}"
TAG_KEY="${TAG_KEY:-Backup}"
TAG_VALUE="${TAG_VALUE:-Daily}"

VOLUME_IDS="$(aws ec2 describe-volumes --region "$REGION" \
  --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
  --query "Volumes[].VolumeId" --output text || true)"

if [[ -z "${VOLUME_IDS// }" ]]; then
  log "No volumes found tagged ${TAG_KEY}=${TAG_VALUE}"
  exit 0
fi

NOW_EPOCH="$(date -u +%s)"
EXIT_CODE=0

for VOL in $VOLUME_IDS; do
  SNAP_TIME="$(aws ec2 describe-snapshots --region "$REGION" \
    --filters "Name=volume-id,Values=$VOL" \
    --owner-ids self \
    --query "Snapshots | sort_by(@,&StartTime)[-1].StartTime" \
    --output text || true)"

  if [[ -z "$SNAP_TIME" || "$SNAP_TIME" == "None" ]]; then
    echo "[FAIL] Volume $VOL has NO snapshots."
    EXIT_CODE=1
    continue
  fi

  SNAP_EPOCH="$(to_epoch_utc "$SNAP_TIME")"
  AGE_HOURS=$(( (NOW_EPOCH - SNAP_EPOCH) / 3600 ))

  if [[ "$AGE_HOURS" -gt "$MAX_AGE_HOURS" ]]; then
    echo "[FAIL] Volume $VOL latest snapshot is $AGE_HOURS hours old (>$MAX_AGE_HOURS). Time=$SNAP_TIME"
    EXIT_CODE=1
  else
    echo "[OK]   Volume $VOL latest snapshot age=$AGE_HOURS hours. Time=$SNAP_TIME"
  fi
done

exit "$EXIT_CODE"
