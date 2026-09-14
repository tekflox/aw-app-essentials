#!/usr/bin/env bash
# Activates pnpm via corepack (bundled with Node >=16.9) — the official,
# idempotent way to get pnpm without a separate installer/download.
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
sudo rm -f "$AW_BIN_DIR/pnpm" "$AW_BIN_DIR/pnpx"

# Scoped to pnpm only — bare `corepack enable` writes shims for every
# manager it knows (incl. yarn/yarnpkg) into AW_BIN_DIR, which install_yarn.sh
# owns and this script has no sudo pre-clean for, so that write EACCESes.
#
# --install-directory is required even scoped — see install_yarn.sh: corepack
# picks its shim dir from dirname(process.argv[1]), not the realpath of what
# that resolves to. `corepack` here is `/usr/local/bin/corepack`, a symlink
# install_node.sh points at the real corepack.js to work around a separate
# nvm bug, so argv[1]'s dirname is the root-owned AW_BIN_DIR and `corepack
# enable` (never run under sudo) EACCESes. Force the write into NODE_BIN_DIR
# instead, which the unprivileged user already owns.
corepack enable pnpm --install-directory "$NODE_BIN_DIR"
# `latest`, not `stable`: pnpm's npm dist-tags no longer carry a `stable` tag,
# so corepack fails the whole install with "Usage Error: Tag not found
# (stable)". Yarn still publishes `stable` (see install_yarn.sh) — this is a
# per-package fact, not a corepack-wide one, so don't "unify" the two.
corepack prepare pnpm@latest --activate

sudo ln -sf "$NODE_BIN_DIR/pnpm" "$AW_BIN_DIR/pnpm"
[ -e "$NODE_BIN_DIR/pnpx" ] && sudo ln -sf "$NODE_BIN_DIR/pnpx" "$AW_BIN_DIR/pnpx"

"$AW_BIN_DIR/pnpm" --version
