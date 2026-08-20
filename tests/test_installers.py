#!/usr/bin/env python3
"""Transactional installer lifecycle tests for Codex PROVE v1.0."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
SKILL = Path(".agents/skills/codex-prove")
ALIAS = Path(".agents/skills/sol-control")
CONTROLLER = Path(".codex/agents/prove-controller.toml")
COMPLEX = Path(".codex/agents/prove-complex-worker.toml")
EFFICIENT = Path(".codex/agents/prove-efficient-worker.toml")
STATE = Path(".codex/codex-prove/install-state")
CURRENT_TARGETS = (SKILL, ALIAS, CONTROLLER, COMPLEX, EFFICIENT)


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_hash(root: Path) -> str:
    rows: list[str] = []
    for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix()):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            rows.append(f"L\t{relative}\t{os.readlink(path)}\n")
        elif path.is_dir():
            rows.append(f"D\t{relative}\n")
        elif path.is_file():
            rows.append(f"F\t{relative}\t{file_hash(path)}\n")
        else:
            rows.append(f"O\t{relative}\n")
    return hashlib.sha256("".join(rows).encode()).hexdigest()


def snapshot(root: Path) -> dict[str, tuple[str, bytes | str | None]]:
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
    return result


class PosixInstallerTests(unittest.TestCase):
    def setUp(self) -> None:
        if os.name == "nt":
            self.skipTest("POSIX lifecycle runs on macOS/Linux; Windows uses windows-lifecycle.ps1")
        self.temporary = tempfile.TemporaryDirectory(prefix="codex-prove-v1.")
        self.home = Path(self.temporary.name) / "home"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def path(self, relative: Path) -> Path:
        return self.home / relative

    def run_script(self, script: str, *args: str, failpoint: str | None = None) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["ORCHESTRATE_HOME"] = str(self.home)
        if failpoint:
            env["ORCHESTRATE_FAILPOINT"] = failpoint
        return subprocess.run(
            ["bash", str(SCRIPTS / script), *args],
            cwd=ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def assert_current(self) -> None:
        for relative in CURRENT_TARGETS:
            self.assertTrue(self.path(relative).exists(), relative)
        state = self.path(STATE).read_text(encoding="utf-8")
        self.assertIn("version=5", state)
        self.assertIn("skill_sha256=", state)
        self.assertIn("compat_skill_sha256=", state)
        self.assertIn("controller_sha256=", state)

    def install(self) -> subprocess.CompletedProcess[str]:
        result = self.run_script("install.sh")
        self.assertEqual(0, result.returncode, result.stdout)
        self.assert_current()
        return result

    def make_v050_install(self) -> dict[str, bytes]:
        old_skill = self.home / ".agents/skills/sol-control"
        old_agents = self.home / ".codex/agents"
        old_skill.mkdir(parents=True)
        old_agents.mkdir(parents=True)
        (old_skill / "SKILL.md").write_text(
            "---\nname: sol-control\ndescription: managed v0.5 fixture\n---\nold\n",
            encoding="utf-8",
        )
        files = {
            "sol-controller.toml": b'name = "sol-controller"\nmodel = "gpt-5.6-sol"\n',
            "terra-high-worker.toml": b'name = "terra-high-worker"\nmodel = "gpt-5.6-terra"\n',
            "luna-max-worker.toml": b'name = "luna-max-worker"\nmodel = "gpt-5.6-luna"\n',
        }
        for name, content in files.items():
            (old_agents / name).write_bytes(content)
        old_state = self.home / ".codex/sol-control/install-state"
        old_state.parent.mkdir(parents=True)
        old_state.write_text(
            "\n".join(
                (
                    "version=4",
                    "backup_id=v050-fixture",
                    f"skill_sha256={tree_hash(old_skill)}",
                    f"sol_sha256={file_hash(old_agents / 'sol-controller.toml')}",
                    f"terra_sha256={file_hash(old_agents / 'terra-high-worker.toml')}",
                    f"luna_sha256={file_hash(old_agents / 'luna-max-worker.toml')}",
                    "",
                )
            ),
            encoding="utf-8",
        )
        return {str(path.relative_to(self.home)): path.read_bytes() for path in old_agents.glob("*.toml")}

    def test_install_creates_v1_targets_and_state(self) -> None:
        result = self.install()
        self.assertIn(str(self.path(SKILL)), result.stdout)
        self.assertIn("Backup path:", result.stdout)
        self.assertIn("name: codex-prove", (self.path(SKILL) / "SKILL.md").read_text())
        self.assertIn("$codex-prove", (self.path(ALIAS) / "SKILL.md").read_text())

    def test_check_mode_is_read_only_for_fresh_and_current_home(self) -> None:
        before = snapshot(Path(self.temporary.name))
        check = self.run_script("install.sh", "--check")
        self.assertEqual(0, check.returncode, check.stdout)
        self.assertEqual(before, snapshot(Path(self.temporary.name)))

        self.install()
        before = snapshot(self.home)
        check = self.run_script("install.sh", "--check")
        self.assertEqual(0, check.returncode, check.stdout)
        self.assertEqual(before, snapshot(self.home))

    def test_unowned_collision_and_modified_install_fail_closed(self) -> None:
        collision = self.path(SKILL)
        collision.mkdir(parents=True)
        (collision / "user.txt").write_text("keep", encoding="utf-8")
        before = snapshot(self.home)
        result = self.run_script("install.sh")
        self.assertEqual(1, result.returncode, result.stdout)
        self.assertIn("no matching ownership state", result.stdout)
        self.assertEqual(before, snapshot(self.home))

        for path in sorted(collision.rglob("*"), reverse=True):
            path.unlink()
        collision.rmdir()
        self.install()
        (self.path(SKILL) / "SKILL.md").write_text("user modification\n", encoding="utf-8")
        before = snapshot(self.home)
        result = self.run_script("install.sh")
        self.assertEqual(1, result.returncode, result.stdout)
        self.assertIn("modified", result.stdout)
        self.assertEqual(before, snapshot(self.home))

    def test_failpoint_rolls_back_current_install(self) -> None:
        self.install()
        before = {str(relative): snapshot(self.path(relative)) for relative in CURRENT_TARGETS}
        before_state = self.path(STATE).read_bytes()
        backup_root = self.home / ".codex/codex-prove/backups"
        before_backups = {path.name for path in backup_root.iterdir()}
        result = self.run_script("install.sh", failpoint="after-replace")
        self.assertEqual(1, result.returncode, result.stdout)
        self.assertEqual(before, {str(relative): snapshot(self.path(relative)) for relative in CURRENT_TARGETS})
        self.assertEqual(before_state, self.path(STATE).read_bytes())
        after_backups = {path.name for path in backup_root.iterdir()}
        self.assertEqual(1, len(after_backups - before_backups))

    def test_uninstall_removes_only_owned_v1_targets(self) -> None:
        unrelated = self.home / ".codex/agents/user-agent.toml"
        unrelated.parent.mkdir(parents=True)
        unrelated.write_text("user", encoding="utf-8")
        self.install()
        result = self.run_script("uninstall.sh")
        self.assertEqual(0, result.returncode, result.stdout)
        for relative in CURRENT_TARGETS:
            self.assertFalse(self.path(relative).exists(), relative)
        self.assertFalse(self.path(STATE).exists())
        self.assertEqual("user", unrelated.read_text())

    def test_v050_upgrade_and_restore_latest_round_trip(self) -> None:
        old_agent_bytes = self.make_v050_install()
        self.install()
        self.assertFalse((self.home / ".codex/sol-control/install-state").exists())
        self.assertFalse((self.home / ".codex/agents/sol-controller.toml").exists())
        result = self.run_script("uninstall.sh", "--restore-latest")
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertFalse(self.path(SKILL).exists())
        self.assertTrue((self.home / ".agents/skills/sol-control/SKILL.md").is_file())
        self.assertTrue((self.home / ".codex/sol-control/install-state").is_file())
        for relative, expected in old_agent_bytes.items():
            self.assertEqual(expected, (self.home / relative).read_bytes())


class ScriptSurfaceTests(unittest.TestCase):
    def test_native_windows_scripts_keep_ps51_safety_and_rollback_markers(self) -> None:
        install = (SCRIPTS / "install.ps1").read_text(encoding="utf-8")
        uninstall = (SCRIPTS / "uninstall.ps1").read_text(encoding="utf-8")
        validate = (SCRIPTS / "validate.ps1").read_text(encoding="utf-8")
        lifecycle = (ROOT / "tests/windows-lifecycle.ps1").read_text(encoding="utf-8")
        for marker in (
            "codex-prove",
            "prove-controller.toml",
            "prove-complex-worker.toml",
            "prove-efficient-worker.toml",
            "install-state",
            "SHA256",
            "-LiteralPath",
        ):
            self.assertIn(marker, install)
            self.assertIn(marker, uninstall + validate + lifecycle)
        self.assertIn("#requires -Version 5.1", install)
        self.assertIn("ORCHESTRATE_FAILPOINT", install)
        self.assertIn("RestoreLatest", uninstall)
        self.assertIn("v050", lifecycle)


if __name__ == "__main__":
    unittest.main(verbosity=2)
