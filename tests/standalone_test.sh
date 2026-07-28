#!/usr/bin/env bash
# Standalone test — no framework runtime required. Run this INSIDE the
# aw-workspace container (as root) to prove the install scripts actually
# install telnet/ping/curl/nc/perl/python/vim/docker and that each resolves
# after.
#
# Usage (from inside the container, with this repo copied in):
#   bash tests/standalone_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

for s in install_telnet install_ping install_curl install_nc install_perl install_python install_vim install_docker; do
  echo "== ${s}.sh =="
  bash "scripts/${s}.sh"
done

echo "== resolution check (which) =="
for bin in telnet ping curl nc perl python python3 vim vi docker; do
  which "$bin"
done

echo "== versions =="
curl --version | head -1
perl -v | head -2 | tail -1
python3 --version
python --version
vim --version | head -1
docker --version
docker compose version

echo "OK: telnet, ping, curl, nc, perl, python, vim/vi, docker/docker-compose all installed and resolve"
