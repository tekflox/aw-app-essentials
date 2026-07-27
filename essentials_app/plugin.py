"""
Entrypoint referenced by aw-app.json's runtime.entrypoint
("essentials_app.plugin:EssentialsAppPlugin"). Framework runtime (F1)
isn't built yet — this is ready to plug in once it is; see
_plugin_stub.py for what's substituted in the meantime.
"""

from __future__ import annotations

import logging

from . import installer
from ._plugin_stub import AppContext, Plugin

log = logging.getLogger("aw_apps.essentials")


class EssentialsAppPlugin(Plugin):
    async def activate(self, ctx: AppContext) -> None:
        """
        Installs the essential CLIs (idempotent — also runs on every
        reconcile pass after workspace recreation, per Decision 5's
        reconciler). No login/settings/secrets — pure command install.
        """
        versions = installer.install_all()
        log.info("aw-app-essentials activated: %s", versions)

    async def deactivate(self) -> None:
        installer.uninstall_all()
        log.info("aw-app-essentials deactivated")
