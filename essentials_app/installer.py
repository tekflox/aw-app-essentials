"""
Install/uninstall logic for every CLI this app installs: core networking/
utilities (telnet, ping, curl, nc, perl, python, vim, docker), Terraform, the
Node.js dev toolkit (nvm, node, npm, npx, yarn, pnpm), and Homebrew.
Invoked directly by tests/test_installer.py (subprocess mocked) and
tests/standalone_test.sh (real, out-of-framework). EssentialsAppPlugin's
activate() goes through ctx.commands.install_system_cli() instead (the
gated/journaled framework path) — this module is the plain, framework-free
version of the same install logic.

Merged from the former aw-app-essentials/aw-app-node/aw-app-terraform/
aw-app-brew repos — same per-CLI function shape each of those already used,
just all in one file now.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = APP_ROOT / "scripts"


class InstallError(RuntimeError):
    pass


def _run_script(script: str, *, env_overrides: dict[str, str] | None = None) -> str:
    path = SCRIPTS_DIR / script
    env = dict(os.environ)
    if env_overrides:
        env.update(env_overrides)
    result = subprocess.run(
        ["bash", str(path)],
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    if result.returncode != 0:
        raise InstallError(
            f"{script} failed (exit {result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout.strip()


# ---- core networking/utilities ---------------------------------------------

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


def install_vim() -> str:
    return _run_script("install_vim.sh")


def install_docker() -> str:
    return _run_script("install_docker.sh")


# ---- Terraform --------------------------------------------------------------

def install_terraform(terraform_version: str = "1.9.8") -> str:
    return _run_script("install_terraform.sh", env_overrides={"AW_APP_TERRAFORM_VERSION": terraform_version})


# ---- Node.js dev toolkit ----------------------------------------------------

def install_nvm() -> str:
    return _run_script("install_nvm.sh")


def install_node(node_version: str = "lts") -> str:
    return _run_script("install_node.sh", env_overrides={"AW_APP_NODE_VERSION": node_version})


def install_npm(node_version: str = "lts") -> str:
    return _run_script("install_node.sh", env_overrides={"AW_APP_NODE_VERSION": node_version})


def install_npx(node_version: str = "lts") -> str:
    return _run_script("install_node.sh", env_overrides={"AW_APP_NODE_VERSION": node_version})


def install_yarn() -> str:
    return _run_script("install_yarn.sh")


def install_pnpm() -> str:
    return _run_script("install_pnpm.sh")


# ---- Homebrew (Linuxbrew) ----------------------------------------------------

def install_brew() -> str:
    return _run_script("install_brew.sh")


# ---- aggregate ---------------------------------------------------------------

def install_all(terraform_version: str = "1.9.8", node_version: str = "lts") -> dict[str, str]:
    return {
        "telnet": install_telnet(),
        "ping": install_ping(),
        "curl": install_curl(),
        "nc": install_nc(),
        "perl": install_perl(),
        "python": install_python(),
        "vim": install_vim(),
        "docker": install_docker(),
        "terraform": install_terraform(terraform_version),
        "nvm": install_nvm(),
        "node": install_node(node_version),
        "npm": install_npm(node_version),
        "npx": install_npx(node_version),
        "yarn": install_yarn(),
        "pnpm": install_pnpm(),
        "brew": install_brew(),
    }


def uninstall_all() -> None:
    _run_script("uninstall.sh")
