#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

JOB_NAME="${1:?job name required}"
shift

LOG_DIR="${LOG_DIR:-/var/log/devops-automation}"
mkdir -p "$LOG_DIR"

TS="$(date +'%Y-%m-%d_%H-%M-%S')"
LOG_FILE="$LOG_DIR/${JOB_NAME}_${TS}.log"

{
  echo "[$(date)] Running job: $JOB_NAME"
  echo "Command: $*"
  "$@"
  echo "[$(date)] SUCCESS: $JOB_NAME"
} >"$LOG_FILE" 2>&1 || {
  echo "[$(date)] FAILED: $JOB_NAME" >>"$LOG_FILE"
  echo "Job failed. See log: $LOG_FILE"
  exit 1
}
