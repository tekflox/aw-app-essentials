#!/usr/bin/env bash
# Installs telnet into the workspace via apt. Idempotent — safe to re-run
# (on install, and on every reconcile pass after workspace recreation).
set -euo pipefail

if command -v telnet >/dev/null 2>&1; then
  echo "telnet already installed: $(telnet -V 2>&1 || true)"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install_telnet.sh: no apt-get on this system — unsupported base image" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends telnet

command -v telnet
