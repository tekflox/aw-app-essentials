"""
Entrypoint referenced by aw-app.json's runtime.entrypoint
("essentials_app.plugin:EssentialsAppPlugin").

Plugs into the real F4 framework runtime: activate(ctx) installs each declared
system CLI THROUGH the gated ``ctx.commands`` facade (capability
``commands:install``), so every install is journaled and the framework reverts
them on uninstall by replaying the journal (running scripts/uninstall.sh once).
The install scripts are idempotent, so the reconciler safely re-runs activate on
every boot / workspace recreation.

Consolidates the former aw-app-essentials/aw-app-node/aw-app-terraform/
aw-app-brew apps into one — same activate loop, just a longer system_clis
list. The config knobs (terraform_version, node_version, go_version) are passed to
their respective install scripts via env vars, same pattern the standalone
apps used (the framework doesn't pass args to installer scripts, only the
app's own package_dir/cwd).
"""

from __future__ import annotations

import json
import logging
import os

log = logging.getLogger("aw_apps.essentials")


class EssentialsAppPlugin:
    async def activate(self, ctx) -> None:
        with open(os.path.join(ctx.package_dir, "aw-app.json"), encoding="utf-8") as f:
            manifest = json.load(f)

        config = getattr(ctx, "config", {}) or {}
        os.environ["AW_APP_TERRAFORM_VERSION"] = str(config.get("terraform_version") or "1.9.8")
        os.environ["AW_APP_NODE_VERSION"] = str(config.get("node_version") or "lts")
        os.environ["AW_APP_GO_VERSION"] = str(config.get("go_version") or "latest")

        clis = manifest.get("contributes", {}).get("system_clis", [])
        installed = []
        for cli in clis:
            ctx.commands.install_system_cli(
                cli["name"], cli["installer"], uninstall="scripts/uninstall.sh"
            )
            installed.append(cli["name"])
        log.info("aw-app-essentials activated: installed %s", installed)

    async def deactivate(self) -> None:
        # Revert is driven by the framework's journal reverse-replay (it runs
        # scripts/uninstall.sh once on uninstall) — nothing to undo here.
        log.info("aw-app-essentials deactivated")
