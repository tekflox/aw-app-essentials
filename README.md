# aw-app-essentials

Second real decoupled app for aw-workspace, per the
[Decoupled Apps Framework ADR](../../docs/knowledge_base/docs/architecture/decoupled-apps-framework.md)
(`aw-app.json` manifest schema v1). Installs a set of essential CLI tools
into the workspace — `telnet`, `ping`, `curl`, `nc`, `perl`, `python`, `vim`,
`docker` (CLI + Compose plugin) — and keeps them present across restarts. Same pattern as
[`aw-app-git`](../aw-app-git), but simpler: no login/settings/secrets, pure
command install.

## Status

**Plugged into the real framework (F4).** `EssentialsAppPlugin.activate(ctx)`
installs all seven CLIs THROUGH the gated `ctx.commands.install_system_cli(...)`
facade (capability `commands:install`) — each install is journaled and the
framework reverts them on uninstall by running `scripts/uninstall.sh`. No raw
shell in the plugin path anymore.

## Layout

- `aw-app.json` — the manifest (id `essentials`, tier `inprocess`). No
  `contributes.routes`/`windows`/`nav`/`settings_panels`/`config_schema` —
  this app contributes system CLIs only.
- `schemas/aw-app.schema.json` — local structural validator (copy of
  `aw-app-git`'s — same manifest schema, both apps validate against it).
- `scripts/install_telnet.sh`, `install_ping.sh`, `install_curl.sh`,
  `install_nc.sh`, `install_perl.sh`, `install_python.sh`, `install_vim.sh`,
  `install_docker.sh`
  — idempotent apt installers (Debian/Ubuntu — the aw-workspace container's
  actual base image, confirmed via `podman exec aw-remote-host-workspace cat
  /etc/os-release` → Debian 13 trixie, same as `aw-app-git`). Package
  mapping: `telnet`→`telnet`, `ping`→`iputils-ping`, `curl`→`curl`,
  `nc`→`netcat-openbsd`, `perl`→`perl`, `python`→`python3` +
  `python-is-python3` (so both `python3` and `python` resolve), `vim`→`vim`
  (Debian's `vim` package provides both `vim` and `vi`), `docker`→
  `docker-ce-cli` + `docker-compose-plugin` (adds Docker's official apt repo
  first if not already configured; installs client tooling only — talks to
  whatever daemon is reachable, e.g. a host-mounted `/var/run/docker.sock`,
  does not install/start a daemon itself).
- `scripts/uninstall.sh` — reverses all eight (apt purge + autoremove).
- `essentials_app/plugin.py` — `EssentialsAppPlugin` entrypoint;
  `activate(ctx)` installs all eight CLIs via `ctx.commands`. Revert is driven
  by the framework's journal reverse-replay (runs `scripts/uninstall.sh`).
- `essentials_app/installer.py` — runs the install/uninstall scripts as
  subprocesses; used by the standalone test (the framework path runs the
  scripts through `ctx.commands` directly).
- `tests/validate_manifest.py` — validates `aw-app.json` against the
  schema + checks every `system_clis` installer path exists.
- `tests/standalone_test.sh` — installs all eight tools for real and checks
  resolution (`which`) + version output; run inside the aw-workspace
  container.

## Testing done

1. **Manifest validation**: `.venv/aw/bin/python tests/validate_manifest.py`
   → `OK: aw-app.json is valid and all system_clis installers exist`.
2. **Real install, standalone, inside the target container**
   (`aw-remote-host-workspace` on macbook-fred, Debian 13 trixie, aarch64):
   ran the exact contents of each `install_*.sh` inside the container as
   root via `podman exec`. All seven installed cleanly; `which telnet ping
   curl nc perl python python3 vim vi` all resolved:
   ```
   /usr/bin/telnet  /usr/bin/ping  /usr/bin/curl  /usr/bin/nc  /usr/bin/perl
   /usr/local/bin/python  /usr/local/bin/python3  /usr/bin/vim  /usr/bin/vi
   ```
   Versions:
   ```
   curl 8.14.1 (aarch64-unknown-linux-gnu) ...
   This is perl 5, version 40, subversion 1 (v5.40.1) built for aarch64-linux-gnu-thread-multi
   Python 3.12.13   (both python3 and python)
   OpenBSD netcat (Debian patchlevel 1.229-1)
   telnet (GNU inetutils) 2.6
   ping from iputils 20240905
   VIM - Vi IMproved 9.1 (2024 Jan 02, compiled May 23 2025 00:48:59)
   ```
   `vim` package wires `vi` via `update-alternatives` automatically — no
   separate symlink step needed (unlike `python`'s manual fallback).
3. **Idempotency**: re-ran all seven `install_*.sh` scripts after install —
   each short-circuits (`"<tool> already installed"`) and exits 0, no
   errors, no redundant apt work.
4. **`install_docker.sh` (2026-07-28)**: added after the first six were
   verified above; not yet run end-to-end inside a target container (no
   root apt access from the sandbox to test the repo-add + install path).
   Confirmed by inspection that `aw-sandbox` itself already has `docker-ce-cli`
   installed and a mounted `/var/run/docker.sock`, but no
   `docker-compose-plugin` and no candidate for it until Docker's own apt
   repo (`/etc/apt/sources.list.d/docker.list`) is present — exactly the gap
   this script closes. Needs a real run (as root, in a fresh target
   container) before calling it verified like the other seven.

   **BYOD/podman gotcha**: the actual target for this app — the
   `aw-workspace` container on machines like macbook-fred — has no Docker
   daemon at all. `bootstrap/workspace/install.sh` (in `aw-remote-host`)
   mounts the **host's rootless podman socket** at `/run/podman.sock`
   instead (`AW_CONTAINER_SOCKET`, used by `src/apps/containers.py`'s Tier-2
   supervisor) — podman speaks the Docker API, but the `docker` CLI only
   looks at `/var/run/docker.sock` by default. The script now symlinks
   `/var/run/docker.sock -> /run/podman.sock` when the podman socket exists
   and no real docker socket is present, both before and after the apt
   install (the mount may not exist yet on a container's very first boot).
   With that in place `docker ps` / `docker compose up` talk straight to
   podman with **zero extra config** — not yet verified live on
   macbook-fred, only by reading the mount + socket-compat code paths.

## NOT done here (explicitly out of scope)

- No install into the production workspace — Frederico installs manually
  after reviewing this.
- No frontend/settings UI — this app has none by design (pure command
  install, no config to expose).
