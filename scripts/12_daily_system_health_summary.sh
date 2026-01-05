#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

HOST="$(hostname -f 2>/dev/null || hostname)"
DATE_NOW="$(date)"
UPTIME="$(uptime -p 2>/dev/null || uptime)"
LOAD="$(cat /proc/loadavg 2>/dev/null | awk '{print $1,$2,$3}' || echo "N/A")"

if command -v free >/dev/null 2>&1; then
  MEM="$(free -h | awk '/Mem:/ {print $3 "/" $2}')"
else
  MEM="N/A"
fi

DISK="$(df -hP / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"

echo "===== Daily System Health Summary ====="
echo "Host:   $HOST"
echo "Date:   $DATE_NOW"
echo "Uptime: $UPTIME"
echo "Load:   $LOAD"
echo "Memory: $MEM"
echo "Disk(/): $DISK"
echo
echo "Top CPU processes:"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6
echo
echo "Top Memory processes:"
ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -n 6
echo "======================================="