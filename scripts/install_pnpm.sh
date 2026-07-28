#!/usr/bin/env bash
# Activates pnpm via corepack (bundled with Node >=16.9) — the official,
# idempotent way to get pnpm without a separate installer/download.
# Requires node already installed (install_node.sh runs first per
# aw-app.json's contributes.system_clis order). Idempotent — safe to re-run.
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
AW_BIN_DIR="${AW_WORKSPACE_HOME:-$HOME/.aw-workspace}/bin"
mkdir -p "$AW_BIN_DIR"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm use default >/dev/null 2>&1 || true
fi

if ! command -v corepack >/dev/null 2>&1; then
  echo "install_pnpm.sh: corepack not found — install node first (install_node.sh)" >&2
  exit 1
fi

corepack enable
corepack prepare pnpm@stable --activate

NODE_BIN_DIR="$(dirname "$(command -v node)")"
ln -sf "$NODE_BIN_DIR/pnpm" "$AW_BIN_DIR/pnpm"
[ -e "$NODE_BIN_DIR/pnpx" ] && ln -sf "$NODE_BIN_DIR/pnpx" "$AW_BIN_DIR/pnpx"

"$AW_BIN_DIR/pnpm" --version
