#!/usr/bin/env bash
# Installs nc (netcat-openbsd) into the workspace via apt. Idempotent —
# safe to re-run (on install, and on every reconcile pass after workspace
# recreation).
set -euo pipefail

if command -v nc >/dev/null 2>&1; then
  echo "nc already installed: $(command -v nc)"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install_nc.sh: no apt-get on this system — unsupported base image" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends netcat-openbsd

command -v nc
