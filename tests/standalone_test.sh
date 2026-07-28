#!/usr/bin/env bash
# Standalone test — no framework runtime required. Run this INSIDE the
# aw-workspace container to prove every install script here actually
# installs its tool and that it resolves after. Merged from the former
# aw-app-essentials/aw-app-node/aw-app-terraform/aw-app-brew standalone
# tests — apt-based tools need root, the rest (terraform/node/brew) need
# the non-root workspace user; run as whichever user matches what you're
# checking, or root to cover everything in one pass.
#
# Usage (from inside the container, with this repo copied in):
#   bash tests/standalone_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

export AW_APP_TERRAFORM_VERSION="${AW_APP_TERRAFORM_VERSION:-1.9.8}"
export AW_APP_NODE_VERSION="${AW_APP_NODE_VERSION:-lts}"
AW_BIN_DIR="${AW_WORKSPACE_HOME:-$HOME/.aw-workspace}/bin"

echo "== apt-based tools: telnet/ping/curl/nc/perl/python/vim/docker =="
for s in install_telnet install_ping install_curl install_nc install_perl install_python install_vim install_docker; do
  echo "-- ${s}.sh --"
  bash "scripts/${s}.sh"
done

echo "== Terraform (terraform_version=$AW_APP_TERRAFORM_VERSION) =="
bash scripts/install_terraform.sh

echo "== Node.js toolkit (node_version=$AW_APP_NODE_VERSION): nvm/node/yarn/pnpm =="
bash scripts/install_nvm.sh
bash scripts/install_node.sh
bash scripts/install_yarn.sh
bash scripts/install_pnpm.sh

echo "== Homebrew =="
bash scripts/install_brew.sh

echo "== resolution check (bin dir: $AW_BIN_DIR) =="
export PATH="$AW_BIN_DIR:$PATH"
for bin in telnet ping curl nc perl python python3 vim vi docker terraform node npm npx yarn pnpm brew; do
  which "$bin"
done
# shellcheck disable=SC1090
. "${NVM_DIR:-$HOME/.nvm}/nvm.sh"

echo "== versions =="
curl --version | head -1
perl -v | head -2 | tail -1
python3 --version
python --version
vim --version | head -1
docker --version
docker compose version
terraform version
node --version
npm --version
npx --version
yarn --version
pnpm --version
nvm --version
brew --version

echo "== idempotency re-run (each install script must be safe to run twice) =="
for s in install_telnet install_ping install_curl install_nc install_perl install_python install_vim install_docker \
         install_terraform install_nvm install_node install_yarn install_pnpm install_brew; do
  bash "scripts/${s}.sh"
done

echo "OK: all 16 CLIs installed and resolve"
