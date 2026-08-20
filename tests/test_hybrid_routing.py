#!/usr/bin/env python3
"""Model-neutral routing and role-profile contracts for Codex PROVE."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / ".agents" / "skills" / "codex-prove"
FORWARD_CASES = ROOT / "tests" / "fixtures" / "forward-cases.json"
CONTROLLER = ROOT / ".codex" / "agents" / "prove-controller.toml"
COMPLEX = ROOT / ".codex" / "agents" / "prove-complex-worker.toml"
EFFICIENT = ROOT / ".codex" / "agents" / "prove-efficient-worker.toml"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def contract() -> str:
    return "\n".join(
        read(path)
        for path in (
            SKILL / "SKILL.md",
            SKILL / "references" / "orchestration.md",
            SKILL / "references" / "runtime-notes.md",
        )
    )


class AgentProfileTests(unittest.TestCase):
    def test_controller_profile_is_model_neutral_and_read_only(self) -> None:
        with CONTROLLER.open("rb") as handle:
            data = tomllib.load(handle)
        self.assertEqual("prove-controller", data["name"])
        self.assertEqual("gpt-5.6-sol", data["model"])
        self.assertEqual("high", data["model_reasoning_effort"])
        self.assertEqual("read-only", data["sandbox_mode"])
        self.assertIn("replaceable capability profile", data["developer_instructions"])

    def test_complex_profile_uses_current_terra_default(self) -> None:
        with COMPLEX.open("rb") as handle:
            data = tomllib.load(handle)
        self.assertEqual("prove-complex-worker", data["name"])
        self.assertEqual("gpt-5.6-terra", data["model"])
        self.assertEqual("high", data["model_reasoning_effort"])
        self.assertEqual("workspace-write", data["sandbox_mode"])

    def test_efficient_profile_uses_current_luna_default(self) -> None:
        with EFFICIENT.open("rb") as handle:
            data = tomllib.load(handle)
        self.assertEqual("prove-efficient-worker", data["name"])
        self.assertEqual("gpt-5.6-luna", data["model"])
        self.assertEqual("max", data["model_reasoning_effort"])
        self.assertEqual("workspace-write", data["sandbox_mode"])

    def test_workers_are_leaf_agents(self) -> None:
        for path in (COMPLEX, EFFICIENT):
            with path.open("rb") as handle:
                instructions = tomllib.load(handle)["developer_instructions"].lower()
            self.assertIn("do not", instructions)
            self.assertIn("subagent", instructions)
            self.assertTrue("spawn" in instructions or "create" in instructions)


class RoutingContractTests(unittest.TestCase):
    def test_controller_is_sole_decision_and_review_owner(self) -> None:
        text = contract().lower()
        self.assertRegex(text, r"(?:only|one) controller")
        self.assertIn("sole final reviewer", text)
        self.assertIn("operationally read-only", text)

    def test_profiles_are_selected_by_capability(self) -> None:
        text = contract().lower()
        for marker in ("low-ambiguity", "falsifiable", "small-context", "high-throughput"):
            self.assertIn(marker, text)
        for marker in ("cross-module", "long-context", "ambiguous debugging", "shared-interface", "high-consequence"):
            self.assertIn(marker, text)

    def test_native_nested_and_compatibility_share_the_protocol(self) -> None:
        text = read(SKILL / "references" / "runtime-notes.md")
        self.assertIn("Native Nested", text)
        self.assertIn("Compatibility", text)
        self.assertIn("same requirement graph", text)
        self.assertIn("max_depth >= 2", text)

    def test_model_identity_failure_is_fail_closed(self) -> None:
        text = contract()
        self.assertIn("Fail Closed", text)
        self.assertIn("authoritative Host/tool", text)
        self.assertIn('fork_turns="none"', text)
        self.assertIn("configuration", text.lower())

    def test_model_replacement_does_not_require_a_rename(self) -> None:
        runtime = read(SKILL / "references" / "runtime-notes.md")
        self.assertIn("keep the brand, invocation, role names", runtime)
        self.assertIn(".codex/agents/prove-*.toml", runtime)
        self.assertIn("Do not rename Codex PROVE", runtime)


class ForwardRoutingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = json.loads(read(FORWARD_CASES))
        cls.by_id = {case["id"]: case for case in cls.cases}

    def test_forward_cases_cover_direct_controller_and_both_workers(self) -> None:
        routes = {case["expected"]["route"] for case in self.cases}
        self.assertEqual(
            {"direct", "controller", "controller_then_efficient", "controller_then_complex", "blocked"},
            routes,
        )

    def test_forward_cases_cover_zero_write_escalation(self) -> None:
        allow = self.by_id["efficient-first-failure-before-write-escalates-complex"]
        forbid = self.by_id["efficient-first-failure-after-write-keeps-efficient-owner"]
        self.assertEqual("controller_then_complex", allow["expected"]["route"])
        self.assertEqual("controller_then_efficient", forbid["expected"]["route"])
        self.assertIn("before", " ".join(allow["required_assertions"]).lower())
        self.assertIn("owner", " ".join(forbid["required_assertions"]).lower())

    def test_forward_cases_cover_one_file_one_owner(self) -> None:
        case = self.by_id["single-file-unique-owner"]
        assertions = " ".join(case["required_assertions"]).lower()
        self.assertIn("owner", assertions)
        self.assertTrue("one" in assertions or "唯一" in assertions)


class PosixRoleLifecycleTests(unittest.TestCase):
    def test_install_and_uninstall_preserve_unrelated_files(self) -> None:
        if os.name == "nt":
            self.skipTest("covered by tests/windows-lifecycle.ps1")
        with tempfile.TemporaryDirectory(prefix="codex-prove-routing-") as raw:
            home = Path(raw)
            config = home / ".codex" / "config.toml"
            other = home / ".codex" / "agents" / "other-agent.toml"
            other.parent.mkdir(parents=True)
            config.write_text("# user config\n", encoding="utf-8")
            other.write_text('name = "other-agent"\n', encoding="utf-8")
            before = (config.read_bytes(), other.read_bytes())
            env = {**os.environ, "ORCHESTRATE_HOME": str(home)}
            install = subprocess.run(
                ["bash", "scripts/install.sh"], cwd=ROOT, env=env,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
            )
            self.assertEqual(0, install.returncode, install.stdout)
            self.assertTrue((home / ".codex/agents/prove-complex-worker.toml").is_file())
            uninstall = subprocess.run(
                ["bash", "scripts/uninstall.sh"], cwd=ROOT, env=env,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
            )
            self.assertEqual(0, uninstall.returncode, uninstall.stdout)
            self.assertEqual(before, (config.read_bytes(), other.read_bytes()))


if __name__ == "__main__":
    unittest.main(verbosity=2)
