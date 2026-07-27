"""
Install/uninstall logic for the essential system CLIs (telnet, ping, curl,
nc, perl, python). Invoked by EssentialsAppPlugin.activate()/deactivate()
through the framework, and directly by tests/standalone_test.sh for
out-of-framework testing.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = APP_ROOT / "scripts"


class InstallError(RuntimeError):
    pass


def _run_script(script: str) -> str:
    path = SCRIPTS_DIR / script
    result = subprocess.run(
        ["bash", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise InstallError(
            f"{script} failed (exit {result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout.strip()


def install_telnet() -> str:
    return _run_script("install_telnet.sh")


def install_ping() -> str:
    return _run_script("install_ping.sh")


def install_curl() -> str:
    return _run_script("install_curl.sh")


def install_nc() -> str:
    return _run_script("install_nc.sh")


def install_perl() -> str:
    return _run_script("install_perl.sh")


def install_python() -> str:
    return _run_script("install_python.sh")


def install_all() -> dict[str, str]:
    return {
        "telnet": install_telnet(),
        "ping": install_ping(),
        "curl": install_curl(),
        "nc": install_nc(),
        "perl": install_perl(),
        "python": install_python(),
    }


def uninstall_all() -> None:
    _run_script("uninstall.sh")
