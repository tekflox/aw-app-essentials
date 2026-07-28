#!/usr/bin/env bash
# Installs Go from the official go.dev Linux tarball into a per-user directory
# and symlinks the `go`/`gofmt` binaries into the workspace's persistent bin dir.
# Idempotent — safe to re-run. Version selectable via AW_APP_GO_VERSION
# (default "latest", resolved from https://go.dev/VERSION?m=text).
set -euo pipefail

GO_VERSION="${AW_APP_GO_VERSION:-latest}"
GO_ROOT="${AW_GO_ROOT:-$HOME/.go}"
AW_BIN_DIR="${AW_WORKSPACE_HOME:-$HOME/.aw-workspace}/bin"
mkdir -p "$AW_BIN_DIR"

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "install_go.sh: unsupported arch $(uname -m)" >&2; exit 1 ;;
esac

command -v curl >/dev/null 2>&1 || { echo "install_go.sh: curl not found on this system — unsupported base image" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "install_go.sh: tar not found on this system — unsupported base image" >&2; exit 1; }

if [ "$GO_VERSION" = "latest" ]; then
  GO_VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)"
fi
GO_VERSION="${GO_VERSION#go}"

if ! printf '%s' "$GO_VERSION" | grep -Eq '^[0-9]+[.][0-9]+([.][0-9]+)?$'; then
  echo "install_go.sh: invalid Go version '$GO_VERSION'" >&2
  exit 1
fi

if [ -x "$AW_BIN_DIR/go" ] && "$AW_BIN_DIR/go" version 2>/dev/null | grep -q "go${GO_VERSION} "; then
  echo "go already installed: $("$AW_BIN_DIR/go" version)"
  exit 0
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

TARBALL="go${GO_VERSION}.linux-${ARCH}.tar.gz"
URL="https://go.dev/dl/${TARBALL}"

curl -fsSL -o "$WORKDIR/$TARBALL" "$URL"
rm -rf "$GO_ROOT"
mkdir -p "$(dirname "$GO_ROOT")"
tar -C "$WORKDIR" -xzf "$WORKDIR/$TARBALL"
mv "$WORKDIR/go" "$GO_ROOT"

ln -sf "$GO_ROOT/bin/go" "$AW_BIN_DIR/go"
ln -sf "$GO_ROOT/bin/gofmt" "$AW_BIN_DIR/gofmt"

"$AW_BIN_DIR/go" version
"$AW_BIN_DIR/gofmt" -w /dev/null 2>/dev/null || true
