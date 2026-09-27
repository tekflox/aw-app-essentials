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
# desync, not an rm bug (confirmed live on Mac.Home, 2026-09-27).
#
# A first cut of this function retried the `rm` but trusted `[ -e "$link" ]`
# to decide cleanup had worked before doing a single, unretried `ln -sf`.
# That's the same desync fooling itself: live re-reproduction on Mac.Home
# (2026-09-27, via `podman exec` into aw-remote-host-workspace) showed
# `stat`/`[ -e ]` on the corrupted path returning ENOENT while `readdir`
# still listed the dirent — so `-e` can report "already gone" while the
# entry is still physically there, the loop exits believing cleanup
# succeeded, and the final `ln -sf` then hits the still-corrupted path and
# fails outright. The same live test found `ln -sf` itself failing
# identically for 15+ continuous seconds before eventually clearing.
#
# Fix: never trust a presence check here. Retry the operation that actually
# has to succeed (`ln -sf`) directly, inside the loop, and judge success by
# ITS OWN exit code — not by whether `-e` thinks the old entry is gone.
# Budget is time, not a guess: ~30s per link (60 attempts x 0.5s), comfortably
# past the 15s+ stuck window observed live. Attempt count/interval are
# overridable via env vars so tests can exercise the retry/give-up paths
# without actually waiting 30s.
nvm_bypass_relink() {
  local target="$1" link="$2" attempt
  local max_attempts="${NVM_BYPASS_RELINK_ATTEMPTS:-60}"
  local retry_sleep="${NVM_BYPASS_RELINK_SLEEP:-0.5}"
  for attempt in $(seq 1 "$max_attempts"); do
    rm -f "$link" 2>/dev/null || true
    if [ ! -f "$target" ]; then
      return 0
    fi
    if ln -sf "$target" "$link" 2>/dev/null; then
      return 0
    fi
    sleep "$retry_sleep"
  done
  echo "install_node.sh: $link is stuck and could not be relinked after $max_attempts attempts" >&2
  exit 1
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
