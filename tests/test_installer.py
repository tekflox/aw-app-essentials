#!/usr/bin/env python3
"""Unit tests for essentials_app/installer.py with subprocess mocked out —
no real network/download/apt involved, so this is safe to run in CI on a
plain GitHub-hosted runner. Covers every CLI this app installs (merged from
the former aw-app-essentials/aw-app-node/aw-app-terraform/aw-app-brew repos):
core networking/utilities, Terraform, the Node.js toolkit, and Homebrew.

For each, asserts the install function invokes bash on the EXACT expected
script path under SCRIPTS_DIR (i.e. installed from the correct path within
the repo) and, for the two version-configurable ones, that the right env
var is set to the right value.

Run: .venv/aw/bin/python -m pytest tests/test_installer.py -q
(or plain unittest: .venv/aw/bin/python -m unittest tests/test_installer.py)
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from essentials_app import installer  # noqa: E402


def _ok(stdout: str = ""):
    return MagicMock(returncode=0, stdout=stdout, stderr="")


def _script_path(call_args) -> str:
    """The script path bash was invoked with — last element of argv."""
    args, _kwargs = call_args
    return args[0][-1]


class SimpleCliInstallersTest(unittest.TestCase):
    """The 8 no-config-knob CLIs — each just runs its own script."""

    CASES = [
        (installer.install_telnet, "install_telnet.sh"),
        (installer.install_ping, "install_ping.sh"),
        (installer.install_curl, "install_curl.sh"),
        (installer.install_nc, "install_nc.sh"),
        (installer.install_perl, "install_perl.sh"),
        (installer.install_python, "install_python.sh"),
        (installer.install_vim, "install_vim.sh"),
        (installer.install_docker, "install_docker.sh"),
        (installer.install_nvm, "install_nvm.sh"),
        (installer.install_yarn, "install_yarn.sh"),
        (installer.install_pnpm, "install_pnpm.sh"),
        (installer.install_brew, "install_brew.sh"),
    ]

    @patch("essentials_app.installer.subprocess.run")
    def test_each_installer_runs_its_own_script_at_the_correct_path(self, mock_run):
        for fn, script_name in self.CASES:
            with self.subTest(script=script_name):
                mock_run.return_value = _ok(f"installed {script_name}")
                fn()
                self.assertEqual(
                    _script_path(mock_run.call_args),
                    str(installer.SCRIPTS_DIR / script_name),
                )

    @patch("essentials_app.installer.subprocess.run")
    def test_failure_raises_install_error(self, mock_run):
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="boom")
        with self.assertRaises(installer.InstallError):
            installer.install_telnet()


class TerraformInstallerTest(unittest.TestCase):
    @patch("essentials_app.installer.subprocess.run")
    def test_install_terraform_runs_script_with_version_env(self, mock_run):
        mock_run.return_value = _ok("Terraform v1.9.8")

        out = installer.install_terraform("1.9.8")

        self.assertEqual(out, "Terraform v1.9.8")
        self.assertEqual(
            _script_path(mock_run.call_args),
            str(installer.SCRIPTS_DIR / "install_terraform.sh"),
        )
        self.assertEqual(mock_run.call_args.kwargs["env"]["AW_APP_TERRAFORM_VERSION"], "1.9.8")

    @patch("essentials_app.installer.subprocess.run")
    def test_install_terraform_defaults_version(self, mock_run):
        mock_run.return_value = _ok()
        installer.install_terraform()
        self.assertEqual(mock_run.call_args.kwargs["env"]["AW_APP_TERRAFORM_VERSION"], "1.9.8")


class NodeToolkitInstallerTest(unittest.TestCase):
    @patch("essentials_app.installer.subprocess.run")
    def test_install_node_runs_install_node_script_with_version_env(self, mock_run):
        mock_run.return_value = _ok("v22.0.0")

        out = installer.install_node("22")

        self.assertEqual(out, "v22.0.0")
        self.assertEqual(
            _script_path(mock_run.call_args),
            str(installer.SCRIPTS_DIR / "install_node.sh"),
        )
        self.assertEqual(mock_run.call_args.kwargs["env"]["AW_APP_NODE_VERSION"], "22")

    @patch("essentials_app.installer.subprocess.run")
    def test_install_npm_and_npx_also_run_install_node_script(self, mock_run):
        # npm/npx come bundled with node — same underlying script.
        mock_run.return_value = _ok()
        installer.install_npm("lts")
        self.assertEqual(_script_path(mock_run.call_args), str(installer.SCRIPTS_DIR / "install_node.sh"))
        installer.install_npx("lts")
        self.assertEqual(_script_path(mock_run.call_args), str(installer.SCRIPTS_DIR / "install_node.sh"))


class AggregateInstallTest(unittest.TestCase):
    @patch("essentials_app.installer.subprocess.run")
    def test_install_all_covers_every_declared_cli(self, mock_run):
        mock_run.return_value = _ok("ok")
        result = installer.install_all()
        self.assertEqual(
            set(result.keys()),
            {"telnet", "ping", "curl", "nc", "perl", "python", "vim", "docker",
             "terraform", "nvm", "node", "npm", "npx", "yarn", "pnpm", "brew"},
        )

    @patch("essentials_app.installer.subprocess.run")
    def test_uninstall_all_runs_the_merged_uninstall_script(self, mock_run):
        mock_run.return_value = _ok()
        installer.uninstall_all()
        self.assertEqual(
            _script_path(mock_run.call_args),
            str(installer.SCRIPTS_DIR / "uninstall.sh"),
        )


if __name__ == "__main__":
    unittest.main()
