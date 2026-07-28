#!/usr/bin/env bash
# Reverses install_telnet.sh / install_ping.sh / install_curl.sh /
# install_nc.sh / install_perl.sh / install_python.sh / install_vim.sh /
# install_docker.sh.
# Called on app uninstall (journal replay per the ADR's Decision 7 — this
# script IS the revert action for the commands:install journal entries).
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get remove -y --purge telnet iputils-ping curl netcat-openbsd perl python-is-python3 python3 vim docker-ce-cli docker-compose-plugin || true
apt-get autoremove -y || true
apt-get update -qq || true
