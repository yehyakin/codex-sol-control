#!/usr/bin/env python3
"""Black-box v0.4 installer and rename-migration tests."""

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

LEGACY_SKILL_REL = Path(".agents/skills/orchestrate-sol-luna")
LEGACY_SOL_REL = Path(".codex/agents/sol-planner.toml")
NEW_SKILL_REL = Path(".agents/skills/sol-control")
COMPAT_SKILL_REL = Path(".agents/skills/sol-luna")
NEW_SOL_REL = Path(".codex/agents/sol-controller.toml")
LUNA_REL = Path(".codex/agents/luna-max-worker.toml")
TERRA_REL = Path(".codex/agents/terra-high-worker.toml")
WINDOWS_LIFECYCLE_REL = Path("tests/windows-lifecycle.ps1")
WINDOWS_SCRIPT_RELS = (
    Path("scripts/install.ps1"),
    Path("scripts/validate.ps1"),
    Path("scripts/uninstall.ps1"),
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_digest(directory: Path) -> str:
    """Match the installer's deterministic SHA-256 tree representation."""

    entries: list[str] = []
    for path in sorted(directory.rglob("*"), key=lambda item: item.relative_to(directory).as_posix()):
        relative = path.relative_to(directory).as_posix()
        if path.is_symlink():
            entries.append(f"L\t{relative}\t{os.readlink(path)}\n")
        elif path.is_dir():
            entries.append(f"D\t{relative}\n")
        elif path.is_file():
            entries.append(f"F\t{relative}\t{digest(path)}\n")
        else:
            entries.append(f"O\t{relative}\n")
    return hashlib.sha256("".join(entries).encode("utf-8")).hexdigest()


def snapshot(
    root: Path,
    ignored_prefixes: tuple[str, ...] = (),
) -> dict[str, tuple[str, bytes | str | None]]:
    """Capture every path under an isolated home for exact rollback checks."""

    result: dict[str, tuple[str, bytes | str | None]] = {}
    for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix()):
        relative = path.relative_to(root).as_posix()
        if any(
            relative == prefix or relative.startswith(f"{prefix}/")
            for prefix in ignored_prefixes
        ):
            continue
        if path.is_symlink():
            result[relative] = ("link", os.readlink(path))
        elif path.is_dir():
            result[relative] = ("dir", None)
        elif path.is_file():
            result[relative] = ("file", path.read_bytes())
        else:
            result[relative] = ("other", None)
    return result


class InstallerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory(prefix="sol-luna-v040-test.")
        self.test_home = Path(self.tempdir.name)
        self.env = os.environ.copy()
        self.env["ORCHESTRATE_HOME"] = str(self.test_home)
        self.env.pop("ORCHESTRATE_FAILPOINT", None)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def run_script(self, name: str, *args: str) -> subprocess.CompletedProcess[str]:
        if os.name == "nt":
            self.skipTest(
                "Bash installer execution is POSIX-only; Windows runtime coverage is provided by tests/windows-lifecycle.ps1."
            )
        return subprocess.run(
            ["bash", str(SCRIPTS / name), *args],
            cwd=ROOT,
            env=self.env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def path(self, relative: Path) -> Path:
        return self.test_home / relative

    def v040_targets(self) -> tuple[Path, Path, Path, Path, Path]:
        return (
            self.path(NEW_SKILL_REL),
            self.path(COMPAT_SKILL_REL),
            self.path(NEW_SOL_REL),
            self.path(LUNA_REL),
            self.path(TERRA_REL),
        )

    def assert_v040_targets_installed(self) -> None:
        skill, compat, sol, luna, terra = self.v040_targets()
        self.assertTrue(skill.is_dir(), skill)
        self.assertTrue(compat.is_dir(), compat)
        self.assertTrue(sol.is_file(), sol)
        self.assertTrue(luna.is_file(), luna)
        self.assertTrue(terra.is_file(), terra)

    def seed_legacy_v01_install(self) -> dict[str, Path]:
        """Create a valid, synthetic v0.1 install with a v0.1 checksum state."""

        skill = self.path(LEGACY_SKILL_REL)
        sol = self.path(LEGACY_SOL_REL)
        luna = self.path(LUNA_REL)
        unrelated = self.path(Path(".codex/agents/keep-me.toml"))
        config = self.path(Path(".codex/config.toml"))

        (skill / "agents").mkdir(parents=True)
        (skill / "references").mkdir(parents=True)
        (skill / "SKILL.md").write_text(
            "---\nname: orchestrate-sol-luna\ndescription: legacy\n---\nlegacy skill\n",
            encoding="utf-8",
        )
        (skill / "agents" / "openai.yaml").write_text("legacy: true\n", encoding="utf-8")
        (skill / "references" / "routing-protocol.md").write_text(
            "legacy protocol\n", encoding="utf-8"
        )
        sol.parent.mkdir(parents=True, exist_ok=True)
        sol.write_text('name = "sol-planner"\nmodel = "gpt-5.6-sol"\n', encoding="utf-8")
        luna.write_text(
            'name = "luna-max-worker"\nmodel = "gpt-5.6-luna"\n', encoding="utf-8"
        )
        unrelated.write_text("keep this unrelated file\n", encoding="utf-8")
        config.write_text('model = "user-configured"\nplugins = ["keep"]\n', encoding="utf-8")

        state_root = self.path(Path(".codex/orchestrate-sol-luna"))
        backup = state_root / "backups" / "legacy-seed"
        backup.mkdir(parents=True)
        shutil.copytree(skill, backup / "skill")
        shutil.copy2(sol, backup / "sol-planner.toml")
        shutil.copy2(luna, backup / "luna-max-worker.toml")
        shutil.copy2(config, backup / "config.toml")
        (backup / "manifest").write_text(
            "\n".join(
                [
                    "version=1",
                    "skill_presence=present",
                    f"skill_sha256={tree_digest(skill)}",
                    "sol_presence=present",
                    f"sol_sha256={digest(sol)}",
                    "luna_presence=present",
                    f"luna_sha256={digest(luna)}",
                    "config_presence=present",
                    f"config_sha256={digest(config)}",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        (state_root / "install-state").write_text(
            "\n".join(
                [
                    "version=1",
                    "backup_id=legacy-seed",
                    f"skill_sha256={tree_digest(skill)}",
                    f"sol_sha256={digest(sol)}",
                    f"luna_sha256={digest(luna)}",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        return {
            "skill": skill,
            "sol": sol,
            "luna": luna,
            "unrelated": unrelated,
            "config": config,
            "state": state_root / "install-state",
        }

    def seed_state_only_v01_install(self) -> dict[str, Path]:
        """Leave only a valid v0.1 state and its shared Luna target behind."""

        legacy = self.seed_legacy_v01_install()
        shutil.rmtree(legacy["skill"])
        legacy["sol"].unlink()
        return legacy

    def seed_v030_install(self) -> dict[str, Path]:
        """Create an owned v0.3 Sol Luna install for rename migration."""

        skill = self.path(COMPAT_SKILL_REL)
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(
            "---\nname: sol-luna\ndescription: previous release\n---\nold full skill\n",
            encoding="utf-8",
        )
        sol = self.path(NEW_SOL_REL)
        luna = self.path(LUNA_REL)
        terra = self.path(TERRA_REL)
        sol.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / NEW_SOL_REL, sol)
        shutil.copy2(ROOT / LUNA_REL, luna)
        shutil.copy2(ROOT / TERRA_REL, terra)
        state_root = self.path(Path(".codex/sol-luna"))
        (state_root / "backups" / "v030-seed").mkdir(parents=True)
        state = state_root / "install-state"
        state.write_text(
            "\n".join(
                [
                    "version=2",
                    "backup_id=v030-seed",
                    f"skill_sha256={tree_digest(skill)}",
                    f"sol_sha256={digest(sol)}",
                    f"luna_sha256={digest(luna)}",
                    f"terra_sha256={digest(terra)}",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        return {"skill": skill, "sol": sol, "luna": luna, "terra": terra, "state": state}

    def test_install_creates_v040_targets_and_versioned_state(self) -> None:
        result = self.run_script("install.sh")

        self.assertEqual(0, result.returncode, result.stdout)
        self.assert_v040_targets_installed()
        state = self.path(Path(".codex/sol-control/install-state"))
        self.assertTrue(state.is_file(), state)
        state_text = state.read_text(encoding="utf-8")
        self.assertRegex(state_text, r"(?m)^version=3$")
        for key in ["skill_sha256", "compat_skill_sha256", "sol_sha256", "luna_sha256", "terra_sha256"]:
            self.assertRegex(state_text, rf"(?m)^{key}=[0-9a-f]{{64}}$")

    def test_install_migrates_unmodified_v01_targets_transactionally(self) -> None:
        legacy = self.seed_legacy_v01_install()
        config_before = digest(legacy["config"])
        unrelated_before = digest(legacy["unrelated"])
        old_skill_digest = tree_digest(legacy["skill"])
        old_sol_digest = digest(legacy["sol"])

        result = self.run_script("install.sh")

        self.assertEqual(0, result.returncode, result.stdout)
        self.assert_v040_targets_installed()
        self.assertFalse(legacy["skill"].exists(), legacy["skill"])
        self.assertFalse(legacy["sol"].exists(), legacy["sol"])
        self.assertEqual(config_before, digest(legacy["config"]))
        self.assertEqual(unrelated_before, digest(legacy["unrelated"]))
        self.assertNotEqual(old_skill_digest, tree_digest(self.path(NEW_SKILL_REL)))
        self.assertNotEqual(old_sol_digest, digest(self.path(NEW_SOL_REL)))

    def test_state_only_v01_state_converges_and_restore_latest_recovers_it_exactly(self) -> None:
        legacy = self.seed_state_only_v01_install()
        legacy_state_before = legacy["state"].read_bytes()

        install = self.run_script("install.sh")

        self.assertEqual(0, install.returncode, install.stdout)
        self.assertFalse(legacy["state"].exists(), legacy["state"])
        state = self.path(Path(".codex/sol-control/install-state"))
        backup_id = next(
            line.split("=", 1)[1]
            for line in state.read_text(encoding="utf-8").splitlines()
            if line.startswith("backup_id=")
        )
        backup = self.path(Path(".codex/sol-control/backups") / backup_id)
        backed_up_state = backup / "legacy" / "install-state"
        self.assertEqual(legacy_state_before, backed_up_state.read_bytes())
        manifest = (backup / "manifest").read_text(encoding="utf-8")
        self.assertRegex(manifest, r"(?m)^legacy_state_presence=present$")
        self.assertRegex(manifest, rf"(?m)^legacy_state_sha256={digest(backed_up_state)}$")

        check = self.run_script("install.sh", "--check")
        self.assertEqual(0, check.returncode, check.stdout)

        uninstall = self.run_script("uninstall.sh", "--restore-latest")

        self.assertEqual(0, uninstall.returncode, uninstall.stdout)
        self.assertEqual(legacy_state_before, legacy["state"].read_bytes())

    def test_plain_uninstall_does_not_restore_state_only_v01_state(self) -> None:
        legacy = self.seed_state_only_v01_install()
        self.assertEqual(0, self.run_script("install.sh").returncode)
        self.assertFalse(legacy["state"].exists(), legacy["state"])

        result = self.run_script("uninstall.sh")

        self.assertEqual(0, result.returncode, result.stdout)
        self.assertFalse(legacy["state"].exists(), legacy["state"])

    def test_restore_latest_refuses_to_overwrite_existing_legacy_state(self) -> None:
        legacy = self.seed_state_only_v01_install()
        self.assertEqual(0, self.run_script("install.sh").returncode)
        legacy["state"].parent.mkdir(parents=True, exist_ok=True)
        legacy["state"].write_text("user-owned legacy state\n", encoding="utf-8")
        before = snapshot(self.test_home)

        result = self.run_script("uninstall.sh", "--restore-latest")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_uninstall_accepts_v2_manifest_without_legacy_state_fields(self) -> None:
        self.assertEqual(0, self.run_script("install.sh").returncode)
        state = self.path(Path(".codex/sol-control/install-state"))
        backup_id = next(
            line.split("=", 1)[1]
            for line in state.read_text(encoding="utf-8").splitlines()
            if line.startswith("backup_id=")
        )
        manifest = self.path(Path(".codex/sol-control/backups") / backup_id / "manifest")
        manifest.write_text(
            "\n".join(
                line
                for line in manifest.read_text(encoding="utf-8").splitlines()
                if not line.startswith("legacy_state_")
            )
            + "\n",
            encoding="utf-8",
        )

        result = self.run_script("uninstall.sh")

        self.assertEqual(0, result.returncode, result.stdout)

    def test_uninstall_rejects_partial_legacy_state_manifest_fields(self) -> None:
        legacy = self.seed_state_only_v01_install()
        self.assertEqual(0, self.run_script("install.sh").returncode)
        state = self.path(Path(".codex/sol-control/install-state"))
        backup_id = next(
            line.split("=", 1)[1]
            for line in state.read_text(encoding="utf-8").splitlines()
            if line.startswith("backup_id=")
        )
        manifest = self.path(Path(".codex/sol-control/backups") / backup_id / "manifest")
        manifest.write_text(
            "\n".join(
                "legacy_state_presence=" if line.startswith("legacy_state_presence=")
                else line
                for line in manifest.read_text(encoding="utf-8").splitlines()
                if not line.startswith("legacy_state_sha256=")
            )
            + "\n",
            encoding="utf-8",
        )
        before = snapshot(self.test_home)

        result = self.run_script("uninstall.sh", "--restore-latest")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_uninstall_rejects_empty_legacy_state_manifest_field_pair(self) -> None:
        legacy = self.seed_state_only_v01_install()
        self.assertEqual(0, self.run_script("install.sh").returncode)
        state = self.path(Path(".codex/sol-control/install-state"))
        backup_id = next(
            line.split("=", 1)[1]
            for line in state.read_text(encoding="utf-8").splitlines()
            if line.startswith("backup_id=")
        )
        manifest = self.path(Path(".codex/sol-control/backups") / backup_id / "manifest")
        manifest.write_text(
            "\n".join(
                "legacy_state_presence=" if line.startswith("legacy_state_presence=")
                else "legacy_state_sha256=" if line.startswith("legacy_state_sha256=")
                else line
                for line in manifest.read_text(encoding="utf-8").splitlines()
            )
            + "\n",
            encoding="utf-8",
        )
        before = snapshot(self.test_home)

        result = self.run_script("uninstall.sh", "--restore-latest")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_install_refuses_modified_legacy_targets_without_partial_install(self) -> None:
        legacy = self.seed_legacy_v01_install()
        modified_skill = "user-owned legacy skill change\n"
        modified_sol = 'name = "user-owned-sol"\n'
        (legacy["skill"] / "SKILL.md").write_text(modified_skill, encoding="utf-8")
        legacy["sol"].write_text(modified_sol, encoding="utf-8")
        before = snapshot(self.test_home)

        result = self.run_script("install.sh")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_install_migrates_v030_and_restore_latest_recovers_it_exactly(self) -> None:
        previous = self.seed_v030_install()
        before = snapshot(self.test_home)

        install = self.run_script("install.sh")

        self.assertEqual(0, install.returncode, install.stdout)
        self.assert_v040_targets_installed()
        self.assertFalse(previous["state"].exists())
        self.assertIn("name: sol-control", (self.path(NEW_SKILL_REL) / "SKILL.md").read_text(encoding="utf-8"))
        self.assertLessEqual(
            len((self.path(COMPAT_SKILL_REL) / "SKILL.md").read_text(encoding="utf-8").splitlines()),
            45,
        )
        check = self.run_script("install.sh", "--check")
        self.assertEqual(0, check.returncode, check.stdout)

        restore = self.run_script("uninstall.sh", "--restore-latest")

        self.assertEqual(0, restore.returncode, restore.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_repeat_install_restore_latest_recovers_prior_v040_ownership_state(self) -> None:
        first = self.run_script("install.sh")
        self.assertEqual(0, first.returncode, first.stdout)
        first_snapshot = snapshot(self.test_home)

        second = self.run_script("install.sh")
        self.assertEqual(0, second.returncode, second.stdout)
        restore = self.run_script("uninstall.sh", "--restore-latest")

        self.assertEqual(0, restore.returncode, restore.stdout)
        self.assertEqual(first_snapshot, snapshot(self.test_home))
        check = self.run_script("install.sh", "--check")
        self.assertEqual(0, check.returncode, check.stdout)

    def test_modified_shared_luna_target_aborts_without_partial_install(self) -> None:
        legacy = self.seed_legacy_v01_install()
        legacy["luna"].write_text("user-modified shared Luna target\n", encoding="utf-8")
        before = snapshot(self.test_home)

        result = self.run_script("install.sh")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_install_failure_rolls_back_v01_migration_and_new_targets(self) -> None:
        self.seed_legacy_v01_install()
        before = snapshot(self.test_home)
        self.env["ORCHESTRATE_FAILPOINT"] = "after-replace"

        result = self.run_script("install.sh")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_install_after_state_failure_rolls_back_full_v01_snapshot(self) -> None:
        self.seed_state_only_v01_install()
        before = snapshot(self.test_home)
        self.env["ORCHESTRATE_FAILPOINT"] = "after-state"

        result = self.run_script("install.sh")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_install_does_not_modify_config_toml(self) -> None:
        config = self.path(Path(".codex/config.toml"))
        config.parent.mkdir(parents=True)
        config.write_text(
            "model = \"unchanged\"\n[features]\nsol_luna = false\n",
            encoding="utf-8",
        )
        before = digest(config)

        result = self.run_script("install.sh")

        self.assertEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, digest(config))

    def test_existing_terra_without_any_ownership_state_fails_closed_in_check_and_install(self) -> None:
        terra = self.path(TERRA_REL)
        terra.parent.mkdir(parents=True)
        terra.write_text("name = 'user-owned-terra'\n", encoding="utf-8")
        before = snapshot(self.test_home)

        check = self.run_script("install.sh", "--check")
        self.assertNotEqual(0, check.returncode, check.stdout)
        self.assertRegex(check.stdout, r"(?i)Terra.*ownership state")
        self.assertEqual(before, snapshot(self.test_home))

        install = self.run_script("install.sh")
        self.assertNotEqual(0, install.returncode, install.stdout)
        self.assertRegex(install.stdout, r"(?i)Terra.*ownership state")
        self.assertEqual(before, snapshot(self.test_home))

    def test_existing_terra_with_v3_state_missing_terra_checksum_fails_closed_in_check_and_install(self) -> None:
        self.assertEqual(0, self.run_script("install.sh").returncode)
        state = self.path(Path(".codex/sol-control/install-state"))
        state.write_text(
            "\n".join(line for line in state.read_text(encoding="utf-8").splitlines() if not line.startswith("terra_sha256=")) + "\n",
            encoding="utf-8",
        )
        before = snapshot(self.test_home)

        check = self.run_script("install.sh", "--check")
        self.assertNotEqual(0, check.returncode, check.stdout)
        self.assertEqual(before, snapshot(self.test_home))

        install = self.run_script("install.sh")
        self.assertNotEqual(0, install.returncode, install.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_uninstall_removes_only_v040_owned_targets(self) -> None:
        unrelated = self.path(Path(".codex/agents/keep-me.toml"))
        config = self.path(Path(".codex/config.toml"))
        unrelated.parent.mkdir(parents=True)
        unrelated.write_text("keep\n", encoding="utf-8")
        config.write_text("model = \"keep\"\n", encoding="utf-8")
        unrelated_before = digest(unrelated)
        config_before = digest(config)
        self.assertEqual(0, self.run_script("install.sh").returncode)
        self.assert_v040_targets_installed()

        result = self.run_script("uninstall.sh")

        self.assertEqual(0, result.returncode, result.stdout)
        for target in self.v040_targets():
            self.assertFalse(target.exists(), target)
        self.assertEqual(unrelated_before, digest(unrelated))
        self.assertEqual(config_before, digest(config))

    def test_uninstall_refuses_modified_v040_target(self) -> None:
        self.assertEqual(0, self.run_script("install.sh").returncode)
        self.assert_v040_targets_installed()
        modified = self.path(NEW_SOL_REL)
        modified.write_text("user changed the v0.4 Sol controller\n", encoding="utf-8")
        before = snapshot(self.test_home)

        result = self.run_script("uninstall.sh")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_uninstall_refuses_modified_v040_terra_target(self) -> None:
        self.assertEqual(0, self.run_script("install.sh").returncode)
        self.assert_v040_targets_installed()
        modified = self.path(TERRA_REL)
        modified.write_text("user changed the v0.4 Terra worker\n", encoding="utf-8")
        before = snapshot(self.test_home)

        result = self.run_script("uninstall.sh")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(before, snapshot(self.test_home))

    def test_restore_latest_recovers_unmodified_v01_targets(self) -> None:
        legacy = self.seed_legacy_v01_install()
        old_skill = snapshot(legacy["skill"])
        old_sol = legacy["sol"].read_bytes()
        old_luna = legacy["luna"].read_bytes()
        config_before = digest(legacy["config"])
        unrelated_before = digest(legacy["unrelated"])
        self.assertEqual(0, self.run_script("install.sh").returncode)
        self.assert_v040_targets_installed()

        result = self.run_script("uninstall.sh", "--restore-latest")

        self.assertEqual(0, result.returncode, result.stdout)
        self.assertTrue(legacy["skill"].is_dir())
        self.assertEqual(old_skill, snapshot(legacy["skill"]))
        self.assertEqual(old_sol, legacy["sol"].read_bytes())
        self.assertEqual(old_luna, legacy["luna"].read_bytes())
        self.assertFalse(self.path(NEW_SKILL_REL).exists())
        self.assertFalse(self.path(COMPAT_SKILL_REL).exists())
        self.assertFalse(self.path(NEW_SOL_REL).exists())
        self.assertFalse(self.path(TERRA_REL).exists())
        self.assertEqual(config_before, digest(legacy["config"]))
        self.assertEqual(unrelated_before, digest(legacy["unrelated"]))

    def test_lifecycle_scripts_encode_v040_paths_and_legacy_migration(self) -> None:
        for name in ["install.sh", "install.ps1"]:
            text = (SCRIPTS / name).read_text(encoding="utf-8")
            for fragment in [".agents/skills/sol-control", ".agents/skills/sol-luna", "sol-controller.toml", "terra-high-worker.toml"]:
                self.assertIn(fragment, text, f"{name}: {fragment}")
            for fragment in ["orchestrate-sol-luna", "sol-planner.toml"]:
                self.assertIn(fragment, text, f"{name}: legacy {fragment}")
            self.assertRegex(text, r"(?i)(sha256|checksum)")
            self.assertRegex(text, r"(?i)(transaction|rollback)")

        uninstall = (SCRIPTS / "uninstall.sh").read_text(encoding="utf-8")
        for fragment in [".agents/skills/sol-control", ".agents/skills/sol-luna", "sol-controller.toml", "terra-high-worker.toml", "--restore-latest"]:
            self.assertIn(fragment, uninstall, fragment)

    def test_native_windows_v040_scripts_keep_ps51_safety_and_rollback_markers(self) -> None:
        missing = [str(path) for path in WINDOWS_SCRIPT_RELS if not (ROOT / path).is_file()]
        self.assertEqual([], missing, "missing native Windows v0.4 script(s)")

        install = (ROOT / WINDOWS_SCRIPT_RELS[0]).read_text(encoding="utf-8")
        for marker in (
            "#requires -Version 5.1",
            "Set-StrictMode",
            "-LiteralPath",
            "ReparsePoint",
            "SHA256",
            "ORCHESTRATE_FAILPOINT",
            "after-replace",
            "README.en.md",
            "docs/assets/readme/hero-zh.svg",
            "docs/assets/readme/hero-en.svg",
            "docs/assets/readme/control-plane-zh.svg",
            "docs/assets/readme/control-plane-en.svg",
            "terra-high-worker.toml",
            "function Remove-EmptyDirectory",
        ):
            self.assertIn(marker, install, marker)

        validate = (ROOT / WINDOWS_SCRIPT_RELS[1]).read_text(encoding="utf-8")
        self.assertRegex(validate, r"(?i)Parser\]::ParseFile")
        self.assertIn("#requires -Version 5.1", validate)
        self.assertIn(
            r"[ \t]*\r?$",
            validate,
            "PowerShell Markdown fence matching must accept CRLF closing lines",
        )

        uninstall = (ROOT / WINDOWS_SCRIPT_RELS[2]).read_text(encoding="utf-8")
        for marker in ("RestoreLatest", "SHA256", "install-state", "-LiteralPath", "terra-high-worker.toml"):
            self.assertIn(marker, uninstall, marker)
        for ps_text in (install, validate, uninstall):
            self.assertNotRegex(ps_text, r"\?\?|\?\.", "PowerShell 7-only operator")

    def test_windows_lifecycle_red_test_declares_isolated_safety_cases(self) -> None:
        path = ROOT / WINDOWS_LIFECYCLE_REL
        self.assertTrue(path.is_file(), path)
        text = path.read_text(encoding="utf-8")
        for marker in (
            "Set-StrictMode",
            "ORCHESTRATE_HOME",
            "Get-FileHash",
            "after-replace",
            "RestoreLatest",
            "config.toml",
            "keep-me.toml",
            "terra-high-worker.toml",
            "v0.4",
            "v0.3",
            "v0.1",
            "spaces",
            "finally",
            "$Install",
            "$Validate",
            "$Uninstall",
            "[System.IO.Directory]::CreateDirectory($Path)",
            "[System.IO.Directory]::CreateDirectory($TestRoot)",
            "Test-ModifiedV01MigrationFailsClosed",
            "Test-StateOnlyV01StateConvergence",
            "Test-StateOnlyV01PlainUninstallDoesNotRestore",
            "Test-StateOnlyV01RestoreRefusesExistingState",
            "Test-StateOnlyV01Rollback",
            "Test-LegacyStateManifestMalformedRefusal",
            "legacy_state_presence",
            "legacy_state_sha256",
            "after-state",
            "Terra",
            "Invoke-CheckProcess",
            "Test-CheckModeReadOnly",
            "-Check",
            "Test-FilesystemRootRefusal",
            "Test-ReparsePointRefusal",
            "GetPathRoot",
            "mklink /J",
            "SKIP",
        ):
            self.assertIn(marker, text, marker)
        self.assertNotIn("New-Item -ItemType Directory -LiteralPath", text)

    def test_shell_scripts_parse(self) -> None:
        if os.name == "nt":
            self.skipTest(
                "Bash installer execution is POSIX-only; Windows runtime coverage is provided by tests/windows-lifecycle.ps1."
            )
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
