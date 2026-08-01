#!/usr/bin/env bash
# Installs the Docker CLI + Compose plugin (docker / docker compose) via
# apt, adding Docker's official repo if it isn't already configured.
# Idempotent — safe to re-run (on install, and on every reconcile pass
# after workspace recreation). Does NOT install/start a Docker daemon —
# this only gives you the client tools; they talk to whatever daemon is
# reachable.
#
# BYOD/podman note: aw-remote-host's workspace bootstrap (bootstrap/workspace/
# install.sh) mounts the HOST's rootless podman socket into this container at
# /run/podman.sock, not /var/run/docker.sock — podman speaks the Docker API,
# but the docker CLI only looks at /var/run/docker.sock by default. If that's
# the only socket present, symlink it into place so `docker`/`docker compose`
# work with zero extra config (see the wiring block below).
set -euo pipefail

# The container's default user (ubuntu) is non-root — the podman-socket
# symlink below and apt-get both need root, so re-exec ourselves under
# sudo. -E keeps $HOME etc. pointed at ubuntu's, not root's.
if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

_wire_podman_socket() {
  local docker_sock=/var/run/docker.sock
  local podman_sock=/run/podman.sock
  if [ -S "$podman_sock" ] && [ ! -S "$docker_sock" ]; then
    ln -sf "$podman_sock" "$docker_sock"
    echo "install_docker.sh: no docker daemon socket found — symlinked $docker_sock -> $podman_sock (rootless podman, Docker-API compatible)"
  fi
}

_wire_podman_socket

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

# The socket may not have been mounted yet on first-ever activate() (container
# creation order) — re-check now that packages are in place.
_wire_podman_socket

docker --version
if [ -S /var/run/docker.sock ] || [ -n "${DOCKER_HOST:-}" ]; then
  docker compose version
else
  echo "install_docker.sh: no docker/podman socket reachable yet — compose version check skipped, docker compose is installed and will work once one is mounted"
fi
