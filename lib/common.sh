#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\n[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
warn() { echo -e "\n[WARN] $*" >&2; }
die() { echo -e "\n[ERROR] $*" >&2; exit 1; }

need_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || die "Missing required command: $c"
}

is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

detect_os_id() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

detect_pkg_mgr() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  else
    echo "none"
  fi
}

install_packages() {
  local pkgs=("$@")
  local pm
  pm="$(detect_pkg_mgr)"

  [[ "$pm" == "none" ]] && die "No supported package manager found (apt/dnf/yum)."

  if ! is_root; then
    die "Run as root to install packages (sudo)."
  fi

  case "$pm" in
    apt)
      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
      ;;
    dnf)
      dnf install -y "${pkgs[@]}"
      ;;
    yum)
      yum install -y "${pkgs[@]}"
      ;;
  esac
}

ensure_awscli() {
  if command -v aws >/dev/null 2>&1; then
    return 0
  fi
  warn "AWS CLI not found. Install AWS CLI v2 or run from an instance with AWS CLI."
  return 1
}

send_email_best_effort() {
  local subject="$1"
  local body="$2"
  local to="$3"

  if command -v mail >/dev/null 2>&1; then
    echo "$body" | mail -s "$subject" "$to"
    return 0
  fi

  if command -v mailx >/dev/null 2>&1; then
    echo "$body" | mailx -s "$subject" "$to"
    return 0
  fi

  warn "mail/mailx not installed. Printing alert instead:"
  echo "SUBJECT: $subject"
  echo "$body"
  return 1
}

to_epoch_utc() {
  # Linux distros (Ubuntu/CentOS/Amazon Linux) have GNU date -> supports -d
  # Usage: to_epoch_utc "2026-01-05T12:30:00Z"  OR any AWS ISO time string
  date -u -d "$1" +%s
}
from_epoch_utc() {
  # Convert epoch to UTC ISO 8601 format
  date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ
}