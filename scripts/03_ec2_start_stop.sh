#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

need_cmd awk
ensure_awscli || exit 1

ACTION="${1:-}"
REGION="${REGION:-us-east-1}"
TAG_KEY="${TAG_KEY:-Schedule}"
TAG_VALUE="${TAG_VALUE:-OfficeHours}"

[[ "$ACTION" == "start" || "$ACTION" == "stop" ]] || die "Usage: $0 start|stop"

INSTANCE_IDS="$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" "Name=instance-state-name,Values=running,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text || true)"

if [[ -z "${INSTANCE_IDS// }" ]]; then
  log "No instances found for tag ${TAG_KEY}=${TAG_VALUE} in $REGION"
  exit 0
fi

log "Action=$ACTION Region=$REGION Instances: $INSTANCE_IDS"

if [[ "$ACTION" == "stop" ]]; then
  aws ec2 stop-instances --region "$REGION" --instance-ids $INSTANCE_IDS >/dev/null
else
  aws ec2 start-instances --region "$REGION" --instance-ids $INSTANCE_IDS >/dev/null
fi

log "Done."
