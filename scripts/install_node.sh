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

# On a $NVM_DIR that sits on a virtiofs mount (Apple Virtualization.framework
# virtio-fs, used by podman machines on the `applehv` provider — confirmed
# live on Mac.Home, 2026-09-27), nvm's tar extraction of the node tarball
# reproducibly hard-fails on exactly bin/npm, bin/npx and bin/corepack with
# "Permission denied" — every other entry in the same tar stream (all of
# lib/node_modules/**, every other bin/* file) extracts fine in the same
# pass. Internally, `nvm install` calls `nvm_extract_tarball`, whose
# `command tar ... || return 1` returns cleanly, but ITS caller
# (`nvm_install_binary_extract`) invokes that as an untested bare statement
# — so under this script's own `set -e`, that nonzero return kills
# install_node.sh outright via errexit, before nvm ever reaches its own
# `mkdir -p "$VERSION_PATH" && mv ...` recovery step that would otherwise
# move the (mostly good) extraction into place. Disable errexit around the
# install itself so that recovery step gets to run, and judge success by
# whether a real node binary landed — not by `nvm install`'s own exit code,
# which is unreliable here even when everything this script needs is fine.
set +e
if [ "$NODE_VERSION" = "lts" ]; then
  nvm install --lts >/dev/null
  nvm alias default 'lts/*' >/dev/null
else
  nvm install "$NODE_VERSION" >/dev/null
  nvm alias default "$NODE_VERSION" >/dev/null
fi
nvm use default >/dev/null
NODE_BIN_DIR="$(dirname "$(nvm which default 2>/dev/null)")"
set -e

if [ ! -x "$NODE_BIN_DIR/node" ]; then
  echo "install_node.sh: nvm did not produce a usable node binary for $NODE_VERSION under $NVM_DIR" >&2
  exit 1
fi
NODE_VERSION_DIR="$(dirname "$NODE_BIN_DIR")"

NPM_CLI="$NODE_VERSION_DIR/lib/node_modules/npm/bin/npm-cli.js"
NPX_CLI="$NODE_VERSION_DIR/lib/node_modules/npm/bin/npx-cli.js"
COREPACK_JS="$NODE_VERSION_DIR/lib/node_modules/corepack/dist/corepack.js"

# Removing one of the corrupted bin/{npm,npx,corepack} entries above is not
# reliably one-shot on the same mount: `rm -f` can report success (exit 0,
# no stderr) while the entry is still visibly present on the very next
# access, then clear on a retry with no other change — a readdir/stat cache
# desync, not an rm bug (confirmed live on Mac.Home, 2026-09-27). Retry a
# bounded number of times and fail loudly rather than silently leaving a
# broken entry behind or looping forever.
nvm_bypass_relink() {
  local target="$1" link="$2" attempt
  for attempt in 1 2 3 4 5; do
    rm -f "$link" 2>/dev/null || true
    [ -e "$link" ] || break
    sleep 0.2
  done
  if [ -e "$link" ]; then
    echo "install_node.sh: $link is stuck and could not be removed after 5 attempts" >&2
    exit 1
  fi
  if [ -f "$target" ]; then
    ln -sf "$target" "$link"
  fi
}

# Apply the same npm/npx/corepack bypass used for /usr/local/bin below (real
# JS entrypoints, never nvm's own tar-extracted bin/* copies) INSIDE nvm's
# own version bin dir too, unconditionally — via ln -sf, never tar — so this
# specific extraction failure can never leave $NVM_DIR itself with broken or
# missing npm/npx/corepack, regardless of whether `nvm install` above fully
# succeeded or partially failed on just these 3 files.
nvm_bypass_relink "$NPM_CLI" "$NODE_BIN_DIR/npm"
nvm_bypass_relink "$NPX_CLI" "$NODE_BIN_DIR/npx"
nvm_bypass_relink "$COREPACK_JS" "$NODE_BIN_DIR/corepack"

# nvm's own bin/npm + bin/npx (and bin/corepack) also come out as 0-byte,
# unreadable-even-to-root files on at least one OTHER target host (a Fedora
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
