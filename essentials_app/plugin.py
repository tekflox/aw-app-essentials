"""
Entrypoint referenced by aw-app.json's runtime.entrypoint
("essentials_app.plugin:EssentialsAppPlugin").

Plugs into the real F4 framework runtime: activate(ctx) installs each declared
system CLI THROUGH the gated ``ctx.commands`` facade (capability
``commands:install``), so every install is journaled and the framework reverts
them on uninstall by replaying the journal (running scripts/uninstall.sh once).
The install scripts are idempotent, so the reconciler safely re-runs activate on
every boot / workspace recreation.
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
