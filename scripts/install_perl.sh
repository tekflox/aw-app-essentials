#!/usr/bin/env bash
# Installs perl into the workspace via apt. Idempotent — safe to re-run
# (on install, and on every reconcile pass after workspace recreation).
set -euo pipefail

if command -v perl >/dev/null 2>&1; then
  echo "perl already installed: $(perl -v | head -2 | tail -1)"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install_perl.sh: no apt-get on this system — unsupported base image" >&2
  exit 1
fi

# The container's default user (ubuntu) is non-root — apt-get needs root, so
# re-exec ourselves under sudo. -E keeps $HOME etc. pointed at ubuntu's, not
# root's.
if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends perl

perl -v | head -2 | tail -1
