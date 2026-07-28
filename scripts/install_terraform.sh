#!/usr/bin/env bash
# Installs Terraform (single Go binary) from the official HashiCorp release
# zip, non-root, into the workspace's persistent bin dir (same tree the F4
# command-shim facade uses — always on PATH). Idempotent — safe to re-run
# (on install, and on every reconcile pass after workspace recreation).
# Version selectable via the AW_APP_TERRAFORM_VERSION env var (default
# "1.9.8", or "latest" to resolve the newest stable release from
# releases.hashicorp.com/terraform/index.json), set by terraform_app/plugin.py
# from the app's config_schema.terraform_version.
#
# Note: Terraform's license moved to BSL with 1.6+, but the official binary
# download is still free and unrestricted — this installs upstream Terraform,
# not OpenTofu.
set -euo pipefail

TF_VERSION="${AW_APP_TERRAFORM_VERSION:-1.9.8}"
AW_BIN_DIR="${AW_WORKSPACE_HOME:-$HOME/.aw-workspace}/bin"
mkdir -p "$AW_BIN_DIR"

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "install_terraform.sh: unsupported arch $(uname -m)" >&2; exit 1 ;;
esac

command -v curl >/dev/null 2>&1 || { echo "install_terraform.sh: curl not found on this system — unsupported base image" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "install_terraform.sh: unzip not found on this system — unsupported base image" >&2; exit 1; }

if [ "$TF_VERSION" = "latest" ]; then
  TF_VERSION="$(curl -fsSL https://releases.hashicorp.com/terraform/index.json \
    | grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' \
    | tr -d '"' \
    | sort -V | tail -1)"
  if [ -z "$TF_VERSION" ]; then
    echo "install_terraform.sh: could not resolve latest terraform version from the releases index" >&2
    exit 1
  fi
fi

if [ -x "$AW_BIN_DIR/terraform" ] && "$AW_BIN_DIR/terraform" version 2>/dev/null | head -1 | grep -q "v${TF_VERSION}\$"; then
  echo "terraform already installed: $("$AW_BIN_DIR/terraform" version | head -1)"
  exit 0
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

ZIP_NAME="terraform_${TF_VERSION}_linux_${ARCH}.zip"
URL="https://releases.hashicorp.com/terraform/${TF_VERSION}/${ZIP_NAME}"

curl -fsSL -o "$WORKDIR/$ZIP_NAME" "$URL"
unzip -oq "$WORKDIR/$ZIP_NAME" -d "$WORKDIR"

cp "$WORKDIR/terraform" "$AW_BIN_DIR/terraform"
chmod 0755 "$AW_BIN_DIR/terraform"

"$AW_BIN_DIR/terraform" version
