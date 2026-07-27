# aw-app-essentials

Second real decoupled app for aw-workspace, per the
[Decoupled Apps Framework ADR](../../docs/knowledge_base/docs/architecture/decoupled-apps-framework.md)
(`aw-app.json` manifest schema v1). Installs a set of essential CLI tools
into the workspace — `telnet`, `ping`, `curl`, `nc`, `perl`, `python` — and
keeps them present across restarts. Same pattern as
[`aw-app-git`](../aw-app-git), but simpler: no login/settings/secrets, pure
command install.

## Status

The framework runtime (Phase 1 — plugin loader, hot routes, `AppContext`)
isn't built yet. This app is **scaffolded and tested standalone**, ready to
plug in once Phase 1 ships (`runtime.entrypoint` in `aw-app.json` already
points at `essentials_app.plugin:EssentialsAppPlugin`). It plugs in for real
around Phase 4 (commands, services, app DB, config/secrets split) — that's
where `commands:install` gets enforced by a real `AppContext`.

## Layout

- `aw-app.json` — the manifest (id `essentials`, tier `inprocess`). No
  `contributes.routes`/`windows`/`nav`/`settings_panels`/`config_schema` —
  this app contributes system CLIs only.
- `schemas/aw-app.schema.json` — local structural validator (copy of
  `aw-app-git`'s — same manifest schema, both apps validate against it).
- `scripts/install_telnet.sh`, `install_ping.sh`, `install_curl.sh`,
  `install_nc.sh`, `install_perl.sh`, `install_python.sh` — idempotent apt
  installers (Debian/Ubuntu — the aw-workspace container's actual base
  image, confirmed via `podman exec aw-remote-host-workspace cat
  /etc/os-release` → Debian 13 trixie, same as `aw-app-git`). Package
  mapping: `telnet`→`telnet`, `ping`→`iputils-ping`, `curl`→`curl`,
  `nc`→`netcat-openbsd`, `perl`→`perl`, `python`→`python3` +
  `python-is-python3` (so both `python3` and `python` resolve).
- `scripts/uninstall.sh` — reverses all six (apt purge + autoremove).
- `essentials_app/plugin.py` — `EssentialsAppPlugin(Plugin)` entrypoint;
  `activate()` installs all six CLIs, `deactivate()` uninstalls.
- `essentials_app/installer.py` — runs the install/uninstall scripts as
  subprocesses; used by both the plugin and the standalone test.
- `essentials_app/_plugin_stub.py` — local stand-in for
  `aw_workspace.apps.Plugin` until Phase 1 exists; delete and import from
  the real module once it does.
- `tests/validate_manifest.py` — validates `aw-app.json` against the
  schema + checks every `system_clis` installer path exists.
- `tests/standalone_test.sh` — installs all six tools for real and checks
  resolution (`which`) + version output; run inside the aw-workspace
  container.

## Testing done

1. **Manifest validation**: `.venv/aw/bin/python tests/validate_manifest.py`
   → `OK: aw-app.json is valid and all system_clis installers exist`.
2. **Real install, standalone, inside the target container**
   (`aw-remote-host-workspace` on macbook-fred, Debian 13 trixie, aarch64):
   ran the exact contents of each `install_*.sh` inside the container as
   root via `podman exec`. All six installed cleanly; `which telnet ping
   curl nc perl python python3` all resolved:
   ```
   /usr/bin/telnet  /usr/bin/ping  /usr/bin/curl  /usr/bin/nc  /usr/bin/perl
   /usr/local/bin/python  /usr/local/bin/python3
   ```
   Versions:
   ```
   curl 8.14.1 (aarch64-unknown-linux-gnu) ...
   This is perl 5, version 40, subversion 1 (v5.40.1) built for aarch64-linux-gnu-thread-multi
   Python 3.12.13   (both python3 and python)
   OpenBSD netcat (Debian patchlevel 1.229-1)
   telnet (GNU inetutils) 2.6
   ping from iputils 20240905
   ```
3. **Idempotency**: re-ran all six `install_*.sh` scripts after install —
   each short-circuits (`"<tool> already installed"`) and exits 0, no
   errors, no redundant apt work.

## NOT done here (explicitly out of scope)

- No install into the production workspace — Frederico installs manually
  after reviewing this.
- No real `AppContext`/`Plugin` runtime — `_plugin_stub.py` is a shim.
- No frontend/settings UI — this app has none by design (pure command
  install, no config to expose).
