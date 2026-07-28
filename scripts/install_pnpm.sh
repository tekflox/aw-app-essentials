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

# Resolve node's real nvm-managed bin dir via nvm itself, NOT `command -v
# node` — see install_yarn.sh for why (AW_BIN_DIR, which already has this
# app's own `node` symlink, is on PATH by the time this runs, so `command -v
# node` can resolve to that symlink instead of the real nvm bin dir).
NODE_BIN_DIR="$(dirname "$(nvm which default)")"
export PATH="$NODE_BIN_DIR:$PATH"

if ! command -v corepack >/dev/null 2>&1; then
  echo "install_pnpm.sh: corepack not found — install node first (install_node.sh)" >&2
  exit 1
fi

# See install_yarn.sh — corepack's own realpath() check on a stale/dangling
# shim throws ENOENT instead of overwriting it.
rm -f "$AW_BIN_DIR/pnpm" "$AW_BIN_DIR/pnpx"

corepack enable
corepack prepare pnpm@stable --activate

ln -sf "$NODE_BIN_DIR/pnpm" "$AW_BIN_DIR/pnpm"
[ -e "$NODE_BIN_DIR/pnpx" ] && ln -sf "$NODE_BIN_DIR/pnpx" "$AW_BIN_DIR/pnpx"

"$AW_BIN_DIR/pnpm" --version
