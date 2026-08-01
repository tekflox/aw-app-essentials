#!/usr/bin/env bash
# Installs Node.js via nvm (per-user, non-root) and symlinks node/npm/npx
# into /usr/local/bin (regular system PATH — needs sudo since the
# container's default user is non-root) so they resolve without sourcing
# nvm.sh in every shell. Idempotent — safe to re-run (on install, and on
# every reconcile pass after workspace recreation). Version selectable via
# the AW_APP_NODE_VERSION env var (default "lts"), set by node_app/plugin.py
# from the app's config_schema.node_version.
#
# Shared by the "node", "npm", and "npx" contributes.system_clis entries —
# npm/npx are bundled with node itself, so there's nothing extra to install
# for them; re-running this script for each entry is a cheap no-op once
# node is already the requested version.
set -euo pipefail

NODE_VERSION="${AW_APP_NODE_VERSION:-lts}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
AW_BIN_DIR="/usr/local/bin"

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
NODE_VERSION_DIR="$(dirname "$NODE_BIN_DIR")"

# nvm's own bin/npm + bin/npx (and bin/corepack) come out as 0-byte,
# unreadable-even-to-root files on at least one target host (a Fedora
# CoreOS / rootless-podman ARM64 VM, confirmed 2026-07-28) — every single
# time nvm (re)installs this node version, despite the downloaded tarball's
# checksum matching the official release (the corruption is in nvm's own
# extraction, not the download; a plain `tar xzf` of the SAME cached
# tarball produces perfectly good files). Worse: the broken inodes can't be
# overwritten OR removed afterward (`rm`/`cp -f` both fail "Permission
# denied", even as root — looks like host-filesystem-level corruption on
# those specific paths, not a permissions problem `chmod` can fix).
#
# Bypass bin/npm|npx entirely instead of fighting it: npm ships its real
# entrypoints as plain, `#!/usr/bin/env node`-shebanged JS files under
# lib/node_modules/npm/bin/{npm-cli.js,npx-cli.js} (and corepack's under
# lib/node_modules/corepack/dist/corepack.js) — a completely different,
# unaffected part of the tree. Symlinking AW_BIN_DIR straight to those
# (skipping bin/npm|npx as a middleman) works whether or not nvm's own
# copies are broken, so just always do it this way.
NPM_CLI="$NODE_VERSION_DIR/lib/node_modules/npm/bin/npm-cli.js"
NPX_CLI="$NODE_VERSION_DIR/lib/node_modules/npm/bin/npx-cli.js"
COREPACK_JS="$NODE_VERSION_DIR/lib/node_modules/corepack/dist/corepack.js"

sudo ln -sf "$NODE_BIN_DIR/node" "$AW_BIN_DIR/node"
if [ -f "$NPM_CLI" ]; then
  sudo ln -sf "$NPM_CLI" "$AW_BIN_DIR/npm"
else
  sudo ln -sf "$NODE_BIN_DIR/npm" "$AW_BIN_DIR/npm"
fi
if [ -f "$NPX_CLI" ]; then
  sudo ln -sf "$NPX_CLI" "$AW_BIN_DIR/npx"
else
  sudo ln -sf "$NODE_BIN_DIR/npx" "$AW_BIN_DIR/npx"
fi
if [ -f "$COREPACK_JS" ]; then
  sudo ln -sf "$COREPACK_JS" "$AW_BIN_DIR/corepack"
fi

"$AW_BIN_DIR/node" --version
"$AW_BIN_DIR/npm" --version
"$AW_BIN_DIR/npx" --version
