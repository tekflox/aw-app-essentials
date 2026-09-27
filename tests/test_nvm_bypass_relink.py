#!/usr/bin/env python3
"""Regression coverage for `nvm_bypass_relink()` in scripts/install_node.sh
— the retry/relink loop that recovers nvm's bin/{npm,npx,corepack} on a
virtiofs mount where extraction reproducibly corrupts exactly those 3
entries (see the comment above the function in install_node.sh for the
live-reproduced root cause, confirmed on Mac.Home 2026-09-27).

Does NOT reproduce virtiofs's actual stat()/readdir desync — that's not
available on a plain CI runner. Instead it extracts the function VERBATIM
from the real script (so this can't drift from what ships) and drives it
against a normal filesystem with a fake `ln` shim placed first on PATH,
which fails on demand — standing in for "the operation that has to
succeed is still stuck" regardless of what any presence check believes.
That's enough to lock in the behaviors QA's two rounds of live
re-reproduction on Mac.Home found missing:

  1. the function must retry the ACTUAL recovery operation (`ln -sf`)
     itself, not bail out early because a presence check thinks cleanup
     already worked (round 1, 2026-09-27);
  2. it must give up loudly (non-zero return, stderr mentions being stuck)
     once its retry budget is exhausted, rather than hang or silently
     limp on with a missing link;
  3. giving up must NOT abort the calling script (`return`, not `exit`) —
     round 2 (2026-09-27) re-reproduced against a FRESH extraction of the
     same cached tarball and found a corrupted entry still unrecoverable
     after 240 attempts / 122+ continuous seconds, disproving the
     assumption that any bounded retry budget always clears the desync.
     Since fixing nvm's own internal bin/{npm,npx,corepack} was never
     load-bearing (install_node.sh's real deliverable, $AW_BIN_DIR/*,
     symlinks straight to the same real JS entrypoints independently of
     this), the fix is architectural, not a bigger number: make the give-up
     path non-fatal and let the caller decide, rather than have the helper
     assume its own success is required.

Mutation check performed by hand while writing this file (not itself
automated): reverting the fix to the pre-fix `[ -e "$link" ]`-then-single-
`ln` shape makes RetryRecoversTest and GivesUpAfterBudgetTest fail — the
old code calls the (failing) `ln` exactly once and aborts under `set -e`
instead of retrying it, so a fake `ln` scripted to fail N times before
succeeding is never given the chance to succeed. Reverting just the
`return 1` back to `exit 1` makes
GivesUpAfterBudgetTest.test_guarded_call_does_not_abort_the_script_under_set_dash_e
fail — `exit` inside a function terminates the whole process regardless of
`|| true` at the call site, which is exactly the regression this locks in.

Run: .venv/aw/bin/python -m pytest tests/test_nvm_bypass_relink.py -q
"""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
INSTALL_NODE_SH = REPO_ROOT / "scripts" / "install_node.sh"

_FUNC_RE = re.compile(r"^nvm_bypass_relink\(\) \{\n.*?^\}\n", re.MULTILINE | re.DOTALL)


def _extract_function() -> str:
    """Pull nvm_bypass_relink()'s exact source out of the real script."""
    text = INSTALL_NODE_SH.read_text()
    match = _FUNC_RE.search(text)
    if not match:
        raise AssertionError(
            f"could not find nvm_bypass_relink() in {INSTALL_NODE_SH} — "
            "did its definition change shape? Update _FUNC_RE."
        )
    return match.group(0)


def _run_bash(body: str, env: dict | None = None, timeout: float = 10.0) -> subprocess.CompletedProcess:
    script = "set -euo pipefail\n" + _extract_function() + "\n" + body
    full_env = {"PATH": "/usr/bin:/bin"}
    if env:
        full_env.update(env)
    return subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        env=full_env,
        timeout=timeout,
    )


class HappyPathTest(unittest.TestCase):
    """No corruption at all — the common case, every real install hits this."""

    def test_creates_a_correct_symlink_on_the_first_try(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "npm-cli.js"
            target.write_text("#!/usr/bin/env node\n")
            link = Path(tmp) / "npm"

            result = _run_bash(f'nvm_bypass_relink "{target}" "{link}"')

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(link.is_symlink())
            self.assertEqual(Path(link.resolve()), target.resolve())

    def test_missing_target_is_a_silent_noop_not_a_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "does-not-exist.js"
            link = Path(tmp) / "npm"

            result = _run_bash(f'nvm_bypass_relink "{target}" "{link}"')

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(link.exists())


class RetryRecoversTest(unittest.TestCase):
    """The defect QA caught live: the function must retry `ln -sf` itself,
    not just the `rm` before it, and must not trust a presence check to
    decide the path is clear."""

    def test_recovers_once_ln_starts_succeeding_after_repeated_failures(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "npm-cli.js"
            target.write_text("#!/usr/bin/env node\n")
            link = Path(tmp) / "npm"

            fake_bin = Path(tmp) / "fakebin"
            fake_bin.mkdir()
            counter_file = Path(tmp) / "ln_calls"
            counter_file.write_text("0")
            # Fails the first 4 calls (simulating the stuck window seen
            # live), then falls through to the real `ln` on the 5th.
            fake_ln = fake_bin / "ln"
            fake_ln.write_text(textwrap.dedent(f"""\
                #!/usr/bin/env bash
                n=$(cat "{counter_file}")
                n=$((n + 1))
                echo "$n" > "{counter_file}"
                if [ "$n" -lt 5 ]; then
                  echo "ln: failed to access: Permission denied" >&2
                  exit 1
                fi
                exec /bin/ln "$@"
                """))
            fake_ln.chmod(0o755)

            result = _run_bash(
                f'nvm_bypass_relink "{target}" "{link}"',
                env={
                    "PATH": f"{fake_bin}:/usr/bin:/bin",
                    "NVM_BYPASS_RELINK_ATTEMPTS": "10",
                    "NVM_BYPASS_RELINK_SLEEP": "0",
                },
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(link.is_symlink())
            self.assertEqual(Path(link.resolve()), target.resolve())
            calls = int(counter_file.read_text())
            self.assertGreaterEqual(
                calls, 5,
                "function gave up (or succeeded by luck) without actually "
                "retrying the ln -sf operation itself",
            )


class GivesUpAfterBudgetTest(unittest.TestCase):
    """A path that's stuck for longer than the retry budget must report the
    failure loudly (nonzero return, stderr mentions being stuck) rather than
    hang forever or silently leave the link missing — but must NOT itself
    abort the calling script, since QA's live re-reproduction of the already
    "fixed" retry loop (2026-09-27, same Mac.Home mount) found a corrupted
    entry that stayed stuck for 240 attempts / 122+ continuous seconds — long
    past any retry budget that's still cheap to pay on every install. No
    budget is large enough to rule that out, so the give-up path returns
    (does not `exit`) and the two call sites in install_node.sh guard it with
    `|| true`."""

    def _stuck_env(self, tmp: Path, attempts: str = "3") -> tuple[Path, Path, Path, dict]:
        target = tmp / "npm-cli.js"
        target.write_text("#!/usr/bin/env node\n")
        link = tmp / "npm"

        fake_bin = tmp / "fakebin"
        fake_bin.mkdir()
        counter_file = tmp / "ln_calls"
        counter_file.write_text("0")
        fake_ln = fake_bin / "ln"
        fake_ln.write_text(textwrap.dedent(f"""\
            #!/usr/bin/env bash
            n=$(cat "{counter_file}")
            n=$((n + 1))
            echo "$n" > "{counter_file}"
            echo "ln: failed to access: Permission denied" >&2
            exit 1
            """))
        fake_ln.chmod(0o755)
        env = {
            "PATH": f"{fake_bin}:/usr/bin:/bin",
            "NVM_BYPASS_RELINK_ATTEMPTS": attempts,
            "NVM_BYPASS_RELINK_SLEEP": "0",
        }
        return target, link, counter_file, env

    def test_reports_nonzero_and_says_so_once_attempts_are_exhausted(self):
        with tempfile.TemporaryDirectory() as tmp:
            target, link, counter_file, env = self._stuck_env(Path(tmp))

            result = _run_bash(f'nvm_bypass_relink "{target}" "{link}"', env=env)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("stuck", result.stderr)
            self.assertFalse(link.exists())
            calls = int(counter_file.read_text())
            self.assertEqual(
                calls, 3,
                "should retry exactly the configured attempt budget, "
                "no more (hang) and no less (giving up early)",
            )

    def test_guarded_call_does_not_abort_the_script_under_set_dash_e(self):
        """The shape install_node.sh actually uses: `nvm_bypass_relink ... ||
        true`. A permanently-stuck link must not stop the script from
        reaching its real deliverable further down."""
        with tempfile.TemporaryDirectory() as tmp:
            target, link, _counter_file, env = self._stuck_env(Path(tmp))

            result = _run_bash(
                f'nvm_bypass_relink "{target}" "{link}" || true\necho REACHED_AFTER_GIVEUP',
                env=env,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("REACHED_AFTER_GIVEUP", result.stdout)
            self.assertFalse(link.exists())


if __name__ == "__main__":
    unittest.main()
