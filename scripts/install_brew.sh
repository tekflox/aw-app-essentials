#!/usr/bin/env bash
# Installs Homebrew (Linuxbrew) per-user into $AW_HOMEBREW_DIR (default
# ~/.homebrew) via a plain `git clone` of Homebrew/brew — NOT the official
# curl install.sh, which requires sudo/root and hardcodes /home/linuxbrew.
# The aw-workspace container runs Linux, non-root, no sudo, so the official
# installer does not work here. This is Homebrew's own documented
# unofficial-but-supported non-default-prefix method (Tier 3 support,
# see https://docs.brew.sh/Installation#alternative-installs and
# https://docs.brew.sh/Support-Tiers#tier-3). Idempotent — safe to re-run
# (on install, and on every reconcile pass after workspace recreation).
set -euo pipefail

BREW_DIR="${AW_HOMEBREW_DIR:-$HOME/.homebrew}"
AW_BIN_DIR="${AW_WORKSPACE_HOME:-$HOME/.aw-workspace}/bin"
mkdir -p "$AW_BIN_DIR"

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
ln -sf "$BREW_DIR/bin/brew" "$AW_BIN_DIR/brew"

brew update --force --quiet

"$AW_BIN_DIR/brew" --version
