#!/usr/bin/env bash
# Installs Node.js via nvm (per-user, non-root) and symlinks node/npm/npx
# into the workspace's persistent bin dir (same tree the F4 command-shim
# facade uses — always on PATH) so they resolve without sourcing nvm.sh in
# every shell. Idempotent — safe to re-run (on install, and on every
# reconcile pass after workspace recreation). Version selectable via the
# AW_APP_NODE_VERSION env var (default "lts"), set by node_app/plugin.py
# from the app's config_schema.node_version.
#
# Shared by the "node", "npm", and "npx" contributes.system_clis entries —
# npm/npx are bundled with node itself, so there's nothing extra to install
# for them; re-running this script for each entry is a cheap no-op once
# node is already the requested version.
set -euo pipefail

NODE_VERSION="${AW_APP_NODE_VERSION:-lts}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
AW_BIN_DIR="${AW_WORKSPACE_HOME:-$HOME/.aw-workspace}/bin"
mkdir -p "$AW_BIN_DIR"

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "install_node.sh: nvm not found at $NVM_DIR — run install_nvm.sh first" >&2
  exit 1
fi
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

if [ "$NODE_VERSION" = "lts" ]; then
  nvm install --lts >/dev/null
  nvm alias default 'lts/*' >/dev/null
else
  nvm install "$NODE_VERSION" >/dev/null
  nvm alias default "$NODE_VERSION" >/dev/null
fi
nvm use default >/dev/null

NODE_BIN_DIR="$(dirname "$(nvm which default)")"
ln -sf "$NODE_BIN_DIR/node" "$AW_BIN_DIR/node"
ln -sf "$NODE_BIN_DIR/npm" "$AW_BIN_DIR/npm"
ln -sf "$NODE_BIN_DIR/npx" "$AW_BIN_DIR/npx"

"$AW_BIN_DIR/node" --version
"$AW_BIN_DIR/npm" --version
"$AW_BIN_DIR/npx" --version
