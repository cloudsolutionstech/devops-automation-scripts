#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="devops-automation-scripts"
INSTALL_DIR="${INSTALL_DIR:-/opt/${REPO_NAME}}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
LOG_DIR="${LOG_DIR:-/var/log/devops-automation}"
USE_SYSTEMD="${USE_SYSTEMD:-true}"

say() { echo -e "\n==> $*"; }
die() { echo -e "\n[ERROR] $*" >&2; exit 1; }

need_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root: sudo $0"
}

detect_pkg_mgr() {
  if command -v apt-get >/dev/null 2>&1; then echo apt; return; fi
  if command -v dnf >/dev/null 2>&1; then echo dnf; return; fi
  if command -v yum >/dev/null 2>&1; then echo yum; return; fi
  echo none
}

install_deps() {
  local pm
  pm="$(detect_pkg_mgr)"
  [[ "$pm" == "none" ]] && die "No supported package manager found."

  say "Installing dependencies via $pm"
  case "$pm" in
    apt)
      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get install -y rsync curl wget git unzip jq ca-certificates openssl
      apt-get install -y mailutils || true
      ;;
    dnf)
      dnf install -y rsync curl wget git unzip jq ca-certificates openssl
      dnf install -y mailx || true
      ;;
    yum)
      yum install -y rsync curl wget git unzip jq ca-certificates openssl
      yum install -y mailx || true
      ;;
  esac

  if ! command -v aws >/dev/null 2>&1; then
    say "Installing AWS CLI v2"
    TMPD=$(mktemp -d)
    curl --fail -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMPD/awscliv2.zip"
    unzip -q "$TMPD/awscliv2.zip" -d "$TMPD"
    "$TMPD/aws/install" >/dev/null
    rm -rf "$TMPD"
  fi
}

deploy_files() {
  say "Deploying repository to $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  rsync -a --exclude ".git" ./ "$INSTALL_DIR/"

  say "Creating log dir $LOG_DIR"
  mkdir -p "$LOG_DIR"
  chmod 755 "$LOG_DIR"

  say "Linking scripts into $BIN_DIR"
  mkdir -p "$BIN_DIR"
  chmod +x "$INSTALL_DIR"/scripts/*.sh
  chmod +x "$INSTALL_DIR"/lib/common.sh

  for f in "$INSTALL_DIR"/scripts/*.sh; do
    ln -sf "$f" "$BIN_DIR/$(basename "$f" .sh)"
  done

  say "Installed. Try: 12_daily_system_health_summary"
}

setup_cron() {
  say "Setting up cron examples at /etc/cron.d/devops-automation"
  cat > /etc/cron.d/devops-automation <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

*/15 * * * * root THRESHOLD=75 EMAIL_TO=you@example.com /usr/local/bin/01_disk_usage_alert > /var/log/devops-automation/disk_alert.log 2>&1
10 2 * * * root LOG_DIR=/var/log DAYS_OLD=14 DRY_RUN=false /usr/local/bin/02_log_cleanup > /var/log/devops-automation/log_cleanup.log 2>&1
0 8 * * * root /usr/local/bin/12_daily_system_health_summary > /var/log/devops-automation/daily_health.txt 2>&1
EOF
  chmod 644 /etc/cron.d/devops-automation
}

setup_systemd_timer() {
  # Works on Ubuntu/CentOS/Amazon Linux (systemd-based)
  if ! command -v systemctl >/dev/null 2>&1; then
    say "systemd not found. Falling back to cron."
    setup_cron
    return
  fi

  say "Setting up systemd timer (daily health)"
  cat > /etc/systemd/system/devops-daily-health.service <<'EOF'
[Unit]
Description=DevOps Automation - Daily Health Summary

[Service]
Type=oneshot
ExecStart=/usr/local/bin/12_daily_system_health_summary
StandardOutput=append:/var/log/devops-automation/daily_health.txt
StandardError=append:/var/log/devops-automation/daily_health.txt
EOF

  cat > /etc/systemd/system/devops-daily-health.timer <<'EOF'
[Unit]
Description=Run Daily Health Summary at 8am

[Timer]
OnCalendar=*-*-* 08:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now devops-daily-health.timer
}

main() {
  need_root
  install_deps
  deploy_files

  if [[ "$USE_SYSTEMD" == "true" ]]; then
    setup_systemd_timer
  else
    setup_cron
  fi

  say "Done."
}

main "$@"
