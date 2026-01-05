#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

NEW_USER="${NEW_USER:-devops}"
SSH_PUBKEY="${SSH_PUBKEY:-}"  # optional
INSTALL_AWSCLI="${INSTALL_AWSCLI:-false}"

if ! is_root; then
  die "Run as root: sudo $0"
fi

OS_ID="$(detect_os_id)"
PM="$(detect_pkg_mgr)"

log "Bootstrap starting (os=$OS_ID pm=$PM)"

# Base packages that exist across Ubuntu/CentOS/Amazon Linux repos
install_packages curl wget git unzip jq ca-certificates openssl

# Optional: install AWS CLI v2
if [[ "$INSTALL_AWSCLI" == "true" ]] && ! command -v aws >/dev/null 2>&1; then
  log "Installing AWS CLI v2"
  TMPD="$(mktemp -d)"
  curl --fail -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMPD/awscliv2.zip"
  unzip -q "$TMPD/awscliv2.zip" -d "$TMPD"
  "$TMPD/aws/install" >/dev/null
  rm -rf "$TMPD"
fi

# Create user
if id "$NEW_USER" >/dev/null 2>&1; then
  log "User exists: $NEW_USER"
else
  useradd -m -s /bin/bash "$NEW_USER"
  log "Created user: $NEW_USER"
fi

# Sudoers
if [[ ! -f "/etc/sudoers.d/$NEW_USER" ]]; then
  echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$NEW_USER"
  chmod 440 "/etc/sudoers.d/$NEW_USER"
  log "Added sudoers: /etc/sudoers.d/$NEW_USER"
fi

# SSH key (optional)
if [[ -n "$SSH_PUBKEY" ]]; then
  mkdir -p "/home/$NEW_USER/.ssh"
  echo "$SSH_PUBKEY" > "/home/$NEW_USER/.ssh/authorized_keys"
  chmod 700 "/home/$NEW_USER/.ssh"
  chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
  chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
  log "Installed SSH key for $NEW_USER"
fi

log "Bootstrap complete."
exit 0