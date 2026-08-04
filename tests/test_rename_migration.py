#!/usr/bin/env python3
"""v0.4.0 Sol Control rename and compatibility contracts."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CANONICAL_SKILL = ROOT / ".agents" / "skills" / "sol-control"
COMPAT_SKILL = ROOT / ".agents" / "skills" / "sol-luna"
CANONICAL_REPOSITORY = "https://github.com/yehyakin/codex-sol-control"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class RenameMigrationContractTests(unittest.TestCase):
    def test_sol_control_is_the_only_full_skill(self) -> None:
        skill = read(CANONICAL_SKILL / "SKILL.md")
        metadata = read(CANONICAL_SKILL / "agents" / "openai.yaml")

        self.assertRegex(skill, r"(?m)^name:\s*sol-control\s*$")
        self.assertIn("$sol-control", skill)
        self.assertIn("# Sol Control", skill)
        self.assertIn('display_name: "Sol Control"', metadata)
        self.assertIn("$sol-control", metadata)
        self.assertRegex(metadata, r"(?m)^\s*allow_implicit_invocation:\s*false\s*$")

    def test_custom_agent_launches_require_fresh_context(self) -> None:
        surfaces = (
            CANONICAL_SKILL / "SKILL.md",
            CANONICAL_SKILL / "references" / "orchestration.md",
            CANONICAL_SKILL / "references" / "runtime-notes.md",
        )
        for surface in surfaces:
            text = read(surface)
            self.assertIn('fork_turns="none"', text, surface)
            self.assertRegex(text, r"(?is)full-history.{0,120}(?:invalid|never|fail)")

    def test_sol_luna_is_a_thin_one_release_compatibility_alias(self) -> None:
        alias = read(COMPAT_SKILL / "SKILL.md")
        metadata = read(COMPAT_SKILL / "agents" / "openai.yaml")

        self.assertLessEqual(len(alias.splitlines()), 45)
        self.assertRegex(alias, r"(?m)^name:\s*sol-luna\s*$")
        self.assertIn("$sol-luna", alias)
        self.assertIn("$sol-control", alias)
        self.assertRegex(alias, r"(?i)compatib|兼容")
        self.assertIn("v0.5.0", alias)
        self.assertRegex(metadata, r"(?m)^\s*allow_implicit_invocation:\s*false\s*$")

    def test_public_readmes_publish_the_new_identity_and_version(self) -> None:
        for relative in ("README.md", "README.en.md"):
            text = read(ROOT / relative)
            self.assertIn(CANONICAL_REPOSITORY, text, relative)
            self.assertIn("v0.4.0", text, relative)
            self.assertIn("$sol-control", text, relative)
            self.assertNotIn("https://github.com/yehyakin/codex-sol-luna", text, relative)

    def test_installers_use_sol_control_state_and_migrate_both_old_states(self) -> None:
        for relative in (
            "scripts/install.sh",
            "scripts/uninstall.sh",
            "scripts/install.ps1",
            "scripts/uninstall.ps1",
        ):
            text = read(ROOT / relative)
            self.assertIn(".agents/skills/sol-control", text, relative)
            self.assertIn(".agents/skills/sol-luna", text, relative)
            self.assertRegex(text, r"[.\\/]codex[.\\/]sol-control|(?:stateRoot|state_root).{0,80}sol-control")
            self.assertIn("sol-luna", text, relative)
            self.assertIn("orchestrate-sol-luna", text, relative)


if __name__ == "__main__":
    unittest.main(verbosity=2)
