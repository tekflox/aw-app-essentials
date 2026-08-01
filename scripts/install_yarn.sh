#!/usr/bin/env bash
# Activates yarn via corepack (bundled with Node >=16.9) — the official,
# idempotent way to get yarn without a separate installer/download.
# Requires node already installed (install_node.sh runs first per
# aw-app.json's contributes.system_clis order). Idempotent — safe to re-run.
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
AW_BIN_DIR="/usr/local/bin"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm use default >/dev/null 2>&1 || true
fi

# Resolve node's real nvm-managed bin dir via nvm itself, NOT `command -v
# node` — AW_BIN_DIR (which already holds this app's own `node` symlink,
# placed there by install_node.sh) is on PATH by the time this runs, so
# `command -v node` resolves to THAT symlink and NODE_BIN_DIR below would
# end up equal to AW_BIN_DIR itself — a self-referential yarn symlink that
# points to nothing (confirmed bug, 2026-07-28: `ln -sf "$AW_BIN_DIR/yarn"
# "$AW_BIN_DIR/yarn"` "installs" successfully but the target never exists).
NODE_BIN_DIR="$(dirname "$(nvm which default)")"
export PATH="$NODE_BIN_DIR:$PATH"

if ! command -v corepack >/dev/null 2>&1; then
  echo "install_yarn.sh: corepack not found — install node first (install_node.sh)" >&2
  exit 1
fi

# corepack places its own yarn/yarnpkg shims alongside wherever `corepack`
# itself resolved from (AW_BIN_DIR, since that's what install_node.sh points
# ctx.commands' PATH at) — `corepack enable`'s internal realpath() check on
# an existing stale/dangling entry there throws ENOENT instead of just
# overwriting it (confirmed 2026-07-28, after a broken symlink was left
# behind by the nvm-extraction bug this app's install_node.sh works around).
# Clear the slate first so there's nothing stale for it to trip over.
sudo rm -f "$AW_BIN_DIR/yarn" "$AW_BIN_DIR/yarnpkg"

corepack enable
corepack prepare yarn@stable --activate

sudo ln -sf "$NODE_BIN_DIR/yarn" "$AW_BIN_DIR/yarn"
[ -e "$NODE_BIN_DIR/yarnpkg" ] && sudo ln -sf "$NODE_BIN_DIR/yarnpkg" "$AW_BIN_DIR/yarnpkg"

"$AW_BIN_DIR/yarn" --version
