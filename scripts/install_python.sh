#!/usr/bin/env bash
# Installs python3 + the `python` shim (python-is-python3) into the
# workspace via apt, so both `python3` and `python` resolve. Idempotent —
# safe to re-run (on install, and on every reconcile pass after workspace
# recreation).
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install_python.sh: no apt-get on this system — unsupported base image" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if ! command -v python3 >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y --no-install-recommends python3
fi

if ! command -v python >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y --no-install-recommends python-is-python3 || \
    ln -sf "$(command -v python3)" /usr/local/bin/python
fi

python3 --version
python --version
