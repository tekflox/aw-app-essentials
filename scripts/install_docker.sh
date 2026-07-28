#!/usr/bin/env bash
# Installs the Docker CLI + Compose plugin (docker / docker compose) via
# apt, adding Docker's official repo if it isn't already configured.
# Idempotent — safe to re-run (on install, and on every reconcile pass
# after workspace recreation). Does NOT install/start a Docker daemon —
# this only gives you the client tools; they talk to whatever daemon is
# reachable (host-mounted /var/run/docker.sock, DOCKER_HOST, etc.).
set -euo pipefail

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  echo "docker + docker compose already installed: $(docker --version), $(docker compose version --short 2>/dev/null || docker compose version | head -1)"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install_docker.sh: no apt-get on this system — unsupported base image" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

KEYRING=/usr/share/keyrings/docker-archive-keyring.gpg
LIST=/etc/apt/sources.list.d/docker.list

if [ ! -f "$KEYRING" ] || [ ! -f "$LIST" ]; then
  apt-get update -qq
  apt-get install -y --no-install-recommends ca-certificates curl gnupg
  install -m 0755 -d /usr/share/keyrings
  . /etc/os-release
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | gpg --dearmor -o "$KEYRING"
  chmod a+r "$KEYRING"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=${KEYRING}] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
    > "$LIST"
fi

apt-get update -qq
apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin

docker --version
docker compose version
