#!/usr/bin/env python3
"""Release-engineering contracts for check-only installs and CI entry points."""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
WORKFLOWS = ROOT / ".github" / "workflows"


def snapshot_tree(root: Path) -> dict[str, tuple[str, bytes | str | None]]:
    """Capture an isolated home without following symlinks."""

    result: dict[str, tuple[str, bytes | str | None]] = {}
    if not root.exists():
        return result
    for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix()):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            result[relative] = ("link", os.readlink(path))
        elif path.is_dir():
            result[relative] = ("dir", None)
        elif path.is_file():
            result[relative] = ("file", path.read_bytes())
        else:
            result[relative] = ("other", None)
    return result


class ReleaseEngineeringTests(unittest.TestCase):
    def run_posix(self, script: str, home: Path, *args: str) -> subprocess.CompletedProcess[str]:
        if os.name == "nt":
            self.skipTest(
                "POSIX installer execution is covered by macOS/Linux; Windows runtime coverage is provided by tests/windows-lifecycle.ps1."
            )
        env = os.environ.copy()
        env["ORCHESTRATE_HOME"] = str(home)
        return subprocess.run(
            ["bash", str(SCRIPTS / script), *args],
            cwd=ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def test_posix_execution_skips_windows_before_starting_bash(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sol-luna-check.") as temporary:
            home = Path(temporary) / "home"
            with (
                mock.patch.object(os, "name", "nt"),
                mock.patch("subprocess.run") as run,
                self.assertRaises(unittest.SkipTest),
            ):
                self.run_posix("install.sh", home, "--check")
            run.assert_not_called()

    def test_install_check_fresh_home_returns_zero_without_writes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sol-luna-check.") as temporary:
            parent = Path(temporary)
            home = parent / "not-created" / "nested home"
            before = snapshot_tree(parent)

            result = self.run_posix("install.sh", home, "--check")

            self.assertEqual(0, result.returncode, result.stdout)
            self.assertIn("check", result.stdout.lower())
            self.assertFalse(home.exists(), "check mode created the home/install directory")
            self.assertEqual(before, snapshot_tree(parent))

    def test_install_check_current_install_returns_zero_without_writes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sol-luna-check.") as temporary:
            home = Path(temporary) / "home"
            install = self.run_posix("install.sh", home)
            self.assertEqual(0, install.returncode, install.stdout)
            before = snapshot_tree(home)

            result = self.run_posix("install.sh", home, "--check")

            self.assertEqual(0, result.returncode, result.stdout)
            self.assertIn("install check: ok", result.stdout.lower())
            self.assertEqual(before, snapshot_tree(home))

    def test_install_check_unsafe_target_returns_one_without_writes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sol-luna-check.") as temporary:
            home = Path(temporary) / "home"
            (home / ".agents").parent.mkdir(parents=True)
            (home / ".agents").write_text("user file\n", encoding="utf-8")
            before = snapshot_tree(home)

            result = self.run_posix("install.sh", home, "--check")

            self.assertEqual(1, result.returncode, result.stdout)
            self.assertIn("unsafe", result.stdout.lower())
            self.assertEqual(before, snapshot_tree(home))

    def test_test_entrypoint_and_validation_scripts_cover_new_contract_files(self) -> None:
        test_entrypoint = SCRIPTS / "test.sh"
        self.assertTrue(test_entrypoint.is_file())
        test_text = test_entrypoint.read_text(encoding="utf-8")
        self.assertRegex(test_text, r"unittest\s+discover")
        self.assertRegex(test_text, r"3\.11")

        validate_sh = (SCRIPTS / "validate.sh").read_text(encoding="utf-8")
        validate_ps1 = (SCRIPTS / "validate.ps1").read_text(encoding="utf-8")
        for text in (validate_sh, validate_ps1):
            self.assertIn("scripts/test.sh", text)
            self.assertIn("posix-validation.yml", text)
            self.assertIn("windows-validation.yml", text)
            for community_file in (
                "CONTRIBUTING.md",
                "CODE_OF_CONDUCT.md",
                "SECURITY.md",
                "SUPPORT.md",
                "bug_report.yml",
                "feature_request.yml",
                "pull_request_template.md",
            ):
                self.assertIn(community_file, text)

    def test_python_entrypoints_cover_named_311_through_314_candidates(self) -> None:
        for relative in (Path("scripts/test.sh"), Path("scripts/validate.sh")):
            text = (ROOT / relative).read_text(encoding="utf-8")
            positions = [text.index(f"python3.{minor}") for minor in (14, 13, 12, 11)]
            self.assertEqual(sorted(positions), positions, relative)
            self.assertGreater(text.index("python3", positions[-1] + 1), positions[-1], relative)
            self.assertIn("python", text, relative)
            if relative.name == "test.sh":
                for minor in (14, 13, 12, 11):
                    self.assertIn(f"python@3.{minor}", text, relative)

    def test_posix_workflow_checks_each_shell_file_individually(self) -> None:
        workflow = (WORKFLOWS / "posix-validation.yml").read_text(encoding="utf-8")
        self.assertIn("for script in scripts/*.sh; do", workflow)
        self.assertIn('bash -n "$script"', workflow)
        self.assertNotIn("bash -n scripts/*.sh\n", workflow)

    def test_workflows_pin_actions_and_cover_release_matrix(self) -> None:
        expected = {
            "actions/checkout": "11d5960a326750d5838078e36cf38b85af677262",
            "actions/setup-python": "a26af69be951a213d495a4c3e4e4022e16d87065",
        }
        workflow_text = "\n".join(
            path.read_text(encoding="utf-8")
            for path in sorted(WORKFLOWS.glob("*.yml"))
        )
        for action, sha in expected.items():
            self.assertIsNotNone(
                re.search(
                    rf"uses:\s+{re.escape(action)}@{sha}(?:\s+#.*)?$",
                    workflow_text,
                    flags=re.MULTILINE,
                )
            )
        self.assertIn("macos-latest", workflow_text)
        self.assertIn("ubuntu-latest", workflow_text)
        self.assertIn('"3.11"', workflow_text)
        self.assertIn('"3.13"', workflow_text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
