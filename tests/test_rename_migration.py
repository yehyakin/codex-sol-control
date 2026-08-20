#!/usr/bin/env python3
"""Codex PROVE v1.0 identity and compatibility-migration contracts."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CANONICAL = ROOT / ".agents" / "skills" / "codex-prove"
COMPAT = ROOT / ".agents" / "skills" / "sol-control"
REPOSITORY = "https://github.com/yehyakin/codex-prove"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class RenameMigrationContractTests(unittest.TestCase):
    def test_codex_prove_is_the_only_full_skill(self) -> None:
        skill = read(CANONICAL / "SKILL.md")
        metadata = read(CANONICAL / "agents" / "openai.yaml")
        alias = read(COMPAT / "SKILL.md")

        self.assertIn("name: codex-prove", skill)
        self.assertIn("# Codex PROVE", skill)
        self.assertIn("Planning, Routing, Ownership, Verification, Evidence", skill)
        self.assertIn('display_name: "Codex PROVE"', metadata)
        self.assertIn("$codex-prove", metadata)
        self.assertIn("allow_implicit_invocation: false", metadata)
        self.assertLess(len(alias.splitlines()), 30)
        self.assertIn("$codex-prove", alias)
        self.assertNotIn("## Plan", alias)

    def test_role_names_are_model_neutral(self) -> None:
        for name in (
            "prove-controller.toml",
            "prove-complex-worker.toml",
            "prove-efficient-worker.toml",
        ):
            self.assertTrue((ROOT / ".codex" / "agents" / name).is_file(), name)
        active_names = {path.name for path in (ROOT / ".codex" / "agents").glob("*.toml")}
        self.assertNotIn("sol-controller.toml", active_names)
        self.assertNotIn("terra-high-worker.toml", active_names)
        self.assertNotIn("luna-max-worker.toml", active_names)

    def test_public_readmes_publish_new_identity_and_compatibility_window(self) -> None:
        for relative in ("README.md", "README.en.md"):
            text = read(ROOT / relative)
            self.assertIn(REPOSITORY, text, relative)
            self.assertIn("v1.0.0", text, relative)
            self.assertIn("CODEX_PROVE_V1_IMPLEMENTATION_REPORT.md", text, relative)
            self.assertIn("$codex-prove", text, relative)
            self.assertIn("$sol-control", text, relative)
            self.assertNotIn("https://github.com/yehyakin/codex-sol-control", text, relative)

    def test_installers_use_v1_state_and_preserve_old_state_migration(self) -> None:
        for relative in (
            "scripts/install.sh",
            "scripts/uninstall.sh",
            "scripts/install.ps1",
            "scripts/uninstall.ps1",
        ):
            text = read(ROOT / relative)
            self.assertIn("codex-prove", text, relative)
            self.assertIn("sol-control", text, relative)
            self.assertIn("sol-luna", text, relative)
            self.assertIn("orchestrate-sol-luna", text, relative)
            self.assertIn("prove-controller", text, relative)

    def test_custom_agent_launch_contract_requires_fresh_context(self) -> None:
        surfaces = (
            CANONICAL / "SKILL.md",
            CANONICAL / "references" / "orchestration.md",
            CANONICAL / "references" / "runtime-notes.md",
        )
        for surface in surfaces:
            text = read(surface)
            self.assertIn('fork_turns="none"', text, surface)
            self.assertIn("identity", text.lower(), surface)
            self.assertIn("handshake", text.lower(), surface)
            self.assertIn("BLOCKED", text, surface)


if __name__ == "__main__":
    unittest.main(verbosity=2)
