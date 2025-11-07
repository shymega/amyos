#!/usr/bin/bash
set -euo pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Starting system cleanup"

# Remove autostart files
rm /etc/skel/.config/autostart/steam.desktop

# Clean package manager cache
dnf5 clean all

# Commit and lint container
ostree container commit
bootc container lint

log "Cleanup completed"
