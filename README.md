# aw-app-essentials

Decoupled app for aw-workspace, per the
[Decoupled Apps Framework ADR](../../docs/knowledge_base/docs/architecture/decoupled-apps-framework.md)
(`aw-app.json` manifest schema v1). Installs a broad set of workspace CLI
tooling and keeps it present across restarts — no login/settings/secrets
beyond version knobs. Same pattern as [`aw-app-git`](../aw-app-git), but
simpler: pure command install, nothing to configure or authenticate.

**2026-07-28: consolidated.** This repo used to be four separate apps —
`aw-app-essentials` (telnet/ping/curl/nc/perl/python/vim/docker),
`aw-app-node` (nvm/node/npm/npx/yarn/pnpm), `aw-app-terraform` (terraform),
and `aw-app-brew` (Homebrew) — all the exact same shape (a Tier-1 plugin
whose `activate()` loops over `contributes.system_clis` and installs each
through `ctx.commands`), so they're now one app with a longer CLI list. The
other three repos are deleted; their functionality lives here unchanged.

## What it installs

- **Core networking/utilities**: `telnet`, `ping`, `curl`, `nc`, `perl`,
  `python`, `vim`, `docker` (CLI + Compose plugin) — apt installs (Debian/
  Ubuntu, the aw-workspace container's actual base image).
- **Terraform**: single Go binary, version pinned via the `terraform_version`
  config knob (default `1.9.8`, or `"latest"`).
- **Go**: official Linux tarball into a per-user directory, version selected
  via the `go_version` config knob (default `"latest"`).
- **Node.js dev toolkit**: `nvm`, `node`, `npm`, `npx`, `yarn`, `pnpm` —
  version selected via the `node_version` config knob (default `lts`).
- **Homebrew** (Linuxbrew, non-root git-clone method — the official
  installer requires sudo/root, unavailable in this container).

## Layout

- `aw-app.json` — the manifest (id `essentials`, tier `inprocess`), 18
  `contributes.system_clis` entries + `config_schema` (`terraform_version`,
  `node_version`, `go_version`). No `routes`/`windows`/`nav`/`settings_panels` — this app
  contributes CLIs only.
- `schemas/aw-app.schema.json` — local structural validator (same manifest
  schema every `aw-app-*` repo validates against).
- `scripts/install_*.sh` — one idempotent installer per CLI/toolchain.
- `scripts/uninstall.sh` — reverses all 18 (apt purge/autoremove + binary/
  dir removal for terraform/go/node/nvm/yarn/pnpm/brew).
- `essentials_app/plugin.py` — `EssentialsAppPlugin` entrypoint;
  `activate(ctx)` sets the two version env vars then installs every CLI via
  `ctx.commands`. Revert is driven by the framework's journal reverse-replay
  (runs `scripts/uninstall.sh` once).
- `essentials_app/installer.py` — the same install logic as a plain
  subprocess-calling module (no framework `ctx` needed) — used by
  `tests/test_installer.py` and `tests/standalone_test.sh`.
- `tests/test_installer.py` — unit tests (subprocess mocked, no real
  installs) verifying every install function invokes the correct script
  **path** under `SCRIPTS_DIR`, and that the two version knobs land in the
  right env var. Runs in CI on every push (see below).
- `tests/validate_manifest.py` — validates `aw-app.json` against the
  schema + checks every `system_clis` installer path exists on disk.
- `tests/standalone_test.sh` — installs all 16 tools for real and checks
  resolution (`which`) + version output; run inside the aw-workspace
  container (not part of CI — needs apt/root + real network).

## CI/CD

`tests/validate_manifest.py` and `tests/test_installer.py` both run in
`tekflox/aw-marketplace`'s shared `app-release.yml` reusable workflow on
every push to `master` — a failure stops the release **before** any version
bump, tag, or marketplace catalog sync happens.

## NOT done here (explicitly out of scope)

- No install into the production workspace by this repo's own CI — install/
  update happens from the AW Marketplace panel, after review.
- No frontend/settings UI — this app has none by design (pure command
  install, no config to expose beyond the two version fields).
