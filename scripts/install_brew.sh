#!/usr/bin/env bash
# Installs Homebrew (Linuxbrew) per-user into $AW_HOMEBREW_DIR (default
# ~/.homebrew) via a plain `git clone` of Homebrew/brew — NOT the official
# curl install.sh, which hardcodes the /home/linuxbrew prefix. This is
# Homebrew's own documented unofficial-but-supported non-default-prefix
# method (Tier 3 support, see
# https://docs.brew.sh/Installation#alternative-installs and
# https://docs.brew.sh/Support-Tiers#tier-3) — brew itself stays per-user
# (owned by whatever installed it), only the resolved `brew` binary is
# symlinked into /usr/local/bin (regular system PATH — needs sudo since the
# container's default user is non-root). Idempotent — safe to re-run
# (on install, and on every reconcile pass after workspace recreation).
set -euo pipefail

BREW_DIR="${AW_HOMEBREW_DIR:-$HOME/.homebrew}"
AW_BIN_DIR="/usr/local/bin"

if ! command -v git >/dev/null 2>&1; then
  echo "install_brew.sh: git not found on this system — install git first (aw-app-git)" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "install_brew.sh: curl not found on this system — unsupported base image" >&2
  exit 1
fi

if [ ! -x "$BREW_DIR/bin/brew" ]; then
  git clone https://github.com/Homebrew/brew "$BREW_DIR"
fi

eval "$("$BREW_DIR/bin/brew" shellenv)"
sudo ln -sf "$BREW_DIR/bin/brew" "$AW_BIN_DIR/brew"

brew update --force --quiet

"$AW_BIN_DIR/brew" --version
