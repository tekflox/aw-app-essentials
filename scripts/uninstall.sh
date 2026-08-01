#!/usr/bin/env bash
# Reverses every install_*.sh in this repo — apt-installed networking/utils
# (telnet/ping/curl/nc/perl/python/vim/docker), Terraform, the Node.js
# toolkit (nvm/node/npm/npx/yarn/pnpm), Go, and Homebrew. Called on app uninstall
# (journal replay per the ADR's Decision 7 — this script IS the revert action
# for every commands:install journal entry from this app).
set -euo pipefail

# apt-get and removing symlinks from /usr/local/bin both need root — the
# container's default user (ubuntu) is non-root, so re-exec ourselves under
# sudo. -E keeps $HOME etc. pointed at ubuntu's, not root's.
if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get remove -y --purge telnet iputils-ping curl netcat-openbsd perl python-is-python3 python3 vim docker-ce-cli docker-compose-plugin || true
apt-get autoremove -y || true
apt-get update -qq || true

AW_BIN_DIR="/usr/local/bin"

# Terraform
rm -f "$AW_BIN_DIR/terraform"

# Go
rm -f "$AW_BIN_DIR"/{go,gofmt}
rm -rf "${AW_GO_ROOT:-$HOME/.go}"

# Node.js toolkit (nvm/node/npm/npx/yarn/pnpm)
rm -f "$AW_BIN_DIR"/{node,npm,npx,yarn,yarnpkg,pnpm,pnpx}
rm -rf "${NVM_DIR:-$HOME/.nvm}"
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  [ -f "$rc" ] && sed -i '/NVM_DIR/d' "$rc" || true
done

# Homebrew (Linuxbrew)
rm -f "$AW_BIN_DIR/brew"
rm -rf "${AW_HOMEBREW_DIR:-$HOME/.homebrew}"
