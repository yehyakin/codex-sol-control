#!/usr/bin/env python3
"""Black-box installer tests using an isolated synthetic home directory."""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class InstallerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory(prefix="orchestrate-sol-luna-test.")
        self.test_home = Path(self.tempdir.name)
        self.env = os.environ.copy()
        self.env["ORCHESTRATE_HOME"] = str(self.test_home)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def run_script(self, name: str, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPTS / name), *args],
            cwd=ROOT,
            env=self.env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def seed_existing_install(self) -> tuple[Path, Path, Path, Path]:
        skill = self.test_home / ".agents" / "skills" / "orchestrate-sol-luna"
        sol = self.test_home / ".codex" / "agents" / "sol-planner.toml"
        luna = self.test_home / ".codex" / "agents" / "luna-max-worker.toml"
        unrelated = self.test_home / ".codex" / "agents" / "keep-me.toml"
        skill.mkdir(parents=True)
        sol.parent.mkdir(parents=True)
        (skill / "old.txt").write_text("old skill\n", encoding="utf-8")
        sol.write_text("old sol\n", encoding="utf-8")
        luna.write_text("old luna\n", encoding="utf-8")
        unrelated.write_text("keep\n", encoding="utf-8")
        return skill, sol, luna, unrelated

    def test_install_preserves_unrelated_files_and_records_backup(self) -> None:
        skill, sol, luna, unrelated = self.seed_existing_install()
        unrelated_before = digest(unrelated)

        result = self.run_script("install.sh")

        self.assertEqual(0, result.returncode, result.stdout)
        self.assertTrue((skill / "SKILL.md").is_file())
        self.assertEqual(digest(ROOT / ".codex" / "agents" / "sol-planner.toml"), digest(sol))
        self.assertEqual(digest(ROOT / ".codex" / "agents" / "luna-max-worker.toml"), digest(luna))
        self.assertEqual(unrelated_before, digest(unrelated))
        self.assertIn("Backup path:", result.stdout)
        self.assertNotIn("developer_instructions", result.stdout)
        state = self.test_home / ".codex" / "orchestrate-sol-luna" / "install-state"
        self.assertTrue(state.is_file())

    def test_uninstall_only_removes_owned_targets(self) -> None:
        _, _, _, unrelated = self.seed_existing_install()
        self.assertEqual(0, self.run_script("install.sh").returncode)

        result = self.run_script("uninstall.sh")

        self.assertEqual(0, result.returncode, result.stdout)
        self.assertFalse((self.test_home / ".agents" / "skills" / "orchestrate-sol-luna").exists())
        self.assertFalse((self.test_home / ".codex" / "agents" / "sol-planner.toml").exists())
        self.assertFalse((self.test_home / ".codex" / "agents" / "luna-max-worker.toml").exists())
        self.assertEqual("keep\n", unrelated.read_text(encoding="utf-8"))

    def test_restore_latest_recovers_previous_install(self) -> None:
        skill, sol, luna, unrelated = self.seed_existing_install()
        self.assertEqual(0, self.run_script("install.sh").returncode)

        result = self.run_script("uninstall.sh", "--restore-latest")

        self.assertEqual(0, result.returncode, result.stdout)
        self.assertEqual("old skill\n", (skill / "old.txt").read_text(encoding="utf-8"))
        self.assertEqual("old sol\n", sol.read_text(encoding="utf-8"))
        self.assertEqual("old luna\n", luna.read_text(encoding="utf-8"))
        self.assertEqual("keep\n", unrelated.read_text(encoding="utf-8"))

    def test_install_does_not_modify_config_toml(self) -> None:
        config = self.test_home / ".codex" / "config.toml"
        config.parent.mkdir(parents=True)
        config.write_text("model = \"unchanged\"\n", encoding="utf-8")
        before = digest(config)

        result = self.run_script("install.sh")

        self.assertEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, digest(config))

    def test_install_failure_rolls_back_previous_targets(self) -> None:
        skill, sol, luna, unrelated = self.seed_existing_install()
        config = self.test_home / ".codex" / "config.toml"
        config.write_text("model = \"unchanged\"\n", encoding="utf-8")
        before = {path: digest(path) for path in [skill / "old.txt", sol, luna, unrelated, config]}
        self.env["ORCHESTRATE_FAILPOINT"] = "after-replace"

        result = self.run_script("install.sh")

        self.assertNotEqual(0, result.returncode, result.stdout)
        for path, expected in before.items():
            self.assertTrue(path.is_file(), path)
            self.assertEqual(expected, digest(path), path)
        self.assertFalse((self.test_home / ".codex" / "orchestrate-sol-luna" / "install-state").exists())

    def test_shell_scripts_parse(self) -> None:
        for name in ["install.sh", "validate.sh", "uninstall.sh"]:
            result = subprocess.run(
                ["bash", "-n", str(SCRIPTS / name)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            self.assertEqual(0, result.returncode, f"{name}: {result.stdout}")

    def test_validate_repository(self) -> None:
        result = self.run_script("validate.sh")
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertIn("Validation: PASS", result.stdout)

    def test_install_script_checks_supported_platform(self) -> None:
        text = (SCRIPTS / "install.sh").read_text(encoding="utf-8")
        self.assertIn("uname -s", text)
        self.assertIn("Darwin", text)
        self.assertIn("Linux", text)
        self.assertIn("unsupported platform", text)

    def test_validators_pin_luna_write_ceiling_and_full_protocol(self) -> None:
        shell = (SCRIPTS / "validate.sh").read_text(encoding="utf-8")
        powershell = (SCRIPTS / "install.ps1").read_text(encoding="utf-8")
        self.assertIn('"sandbox_mode": "workspace-write"', shell)
        self.assertIn('sandbox_mode\\s*=\\s*"workspace-write"', powershell)
        for field in [
            "reasoning:", "write_ownership:", "conflict_risks:",
            "integration_owner:", "final_review_required:",
            "Exact verification result:", "evidence_quality:", "remaining_risks:",
        ]:
            self.assertIn(field, shell)


if __name__ == "__main__":
    unittest.main(verbosity=2)
