#!/usr/bin/env bash
# Installs nvm (Node Version Manager) per-user into $NVM_DIR (default
# ~/.nvm) via the official install script — no apt/root required. Idempotent
# — safe to re-run (on install, and on every reconcile pass after workspace
# recreation). The official installer also appends a sourcing snippet to
# ~/.bashrc/~/.zshrc/~/.profile for interactive shells; install_node.sh and
# friends additionally symlink the resolved binaries into the workspace's
# persistent bin dir so they resolve in non-interactive shells too.
set -euo pipefail

NVM_VERSION="v0.40.1"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  echo "nvm already installed: $(nvm --version)"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "install_nvm.sh: curl not found on this system — unsupported base image" >&2
  exit 1
fi

curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
echo "nvm installed: $(nvm --version)"
