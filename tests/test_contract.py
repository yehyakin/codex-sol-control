#!/usr/bin/env python3
"""Repository contract tests for the orchestrate-sol-luna skill pack."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError as exc:  # pragma: no cover - exercised on old runners
    raise SystemExit("tests require Python 3.11+ for tomllib") from exc


ROOT = Path(__file__).resolve().parents[1]
SKILL_ROOT = ROOT / ".agents" / "skills" / "orchestrate-sol-luna"


class RepositoryContractTests(unittest.TestCase):
    @staticmethod
    def fenced_block(text: str, heading: str, language: str) -> str:
        section = text.split(heading, 1)[1]
        return section.split(f"```{language}\n", 1)[1].split("```", 1)[0]

    def test_required_files_exist(self) -> None:
        required = [
            SKILL_ROOT / "SKILL.md",
            SKILL_ROOT / "agents" / "openai.yaml",
            SKILL_ROOT / "references" / "routing-protocol.md",
            ROOT / ".codex" / "agents" / "sol-planner.toml",
            ROOT / ".codex" / "agents" / "luna-max-worker.toml",
            ROOT / "scripts" / "install.sh",
            ROOT / "scripts" / "validate.sh",
            ROOT / "scripts" / "uninstall.sh",
            ROOT / "scripts" / "install.ps1",
            ROOT / "README.md",
            ROOT / "NOTICE",
            ROOT / "LICENSE",
        ]
        self.assertEqual([], [str(path.relative_to(ROOT)) for path in required if not path.is_file()])

    def test_skill_frontmatter_and_protocol_contract(self) -> None:
        text = (SKILL_ROOT / "SKILL.md").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\n"))
        frontmatter = text.split("---", 2)[1]
        self.assertRegex(frontmatter, r"(?m)^name:\s*orchestrate-sol-luna\s*$")
        self.assertRegex(frontmatter, r"(?m)^description:\s*Use when\b")
        for phrase in [
            "Level 0",
            "Level 1",
            "Level 2",
            "Level 3",
            "Native Nested",
            "Compatibility",
            "sol-planner",
            "luna-max-worker",
            "Fail Closed",
        ]:
            self.assertIn(phrase, text)

        protocol = (SKILL_ROOT / "references" / "routing-protocol.md").read_text(encoding="utf-8")
        for field in [
            "complexity_level:",
            "execution_mode:",
            "reasoning:",
            "acceptance_criteria:",
            "task_graph:",
            "id:",
            "objective:",
            "agent:",
            "mode:",
            "dependencies:",
            "inputs:",
            "read_scope:",
            "write_scope:",
            "forbidden_scope:",
            "deliverable:",
            "minimum_verification:",
            "can_launch:",
            "held_reason:",
            "stop_conditions:",
            "write_ownership:",
            "conflict_risks:",
            "integration_owner:",
            "final_review_required:",
            "Task ID:",
            "Why it matters:",
            "Inputs and evidence:",
            "Read scope:",
            "Write scope:",
            "Forbidden scope:",
            "Required deliverable:",
            "Minimum verification:",
            "Passing condition:",
            "Required evidence:",
            "Return format:",
            "Status: PASS | BLOCKED",
            "Exact verification result:",
            "Assumptions:",
            "Risks:",
            "verdict: PASS | PASS_WITH_LIMITATIONS | FAIL",
            "required_fixes:",
            "optional_improvements:",
            "evidence_quality:",
            "remaining_risks:",
            "Correction Packet",
        ]:
            self.assertIn(field, protocol)

    def test_agent_models_effort_and_scope(self) -> None:
        expected = {
            "sol-planner.toml": ("sol-planner", "gpt-5.6-sol", "high", "read-only"),
            "luna-max-worker.toml": ("luna-max-worker", "gpt-5.6-luna", "max", "workspace-write"),
        }
        for filename, values in expected.items():
            path = ROOT / ".codex" / "agents" / filename
            with path.open("rb") as handle:
                data = tomllib.load(handle)
            name, model, effort, sandbox = values
            self.assertEqual(name, data["name"])
            self.assertEqual(model, data["model"])
            self.assertEqual(effort, data["model_reasoning_effort"])
            if sandbox is not None:
                self.assertEqual(sandbox, data["sandbox_mode"])
            self.assertIn("developer_instructions", data)
        luna_text = (ROOT / ".codex" / "agents" / "luna-max-worker.toml").read_text(encoding="utf-8")
        self.assertRegex(luna_text, r"(?i)do not (spawn|create).*subagent")
        self.assertRegex(luna_text, r"(?i)parent permission boundary")

    def test_sol_execution_graph_uses_canonical_field_placement(self) -> None:
        protocol = (SKILL_ROOT / "references" / "routing-protocol.md").read_text(encoding="utf-8")
        graph = self.fenced_block(protocol, "## Sol execution graph", "yaml")
        root_fields = [
            "complexity_level", "execution_mode", "reasoning", "acceptance_criteria",
            "task_graph", "write_ownership", "conflict_risks", "integration_owner",
            "final_review_required",
        ]
        for field in root_fields:
            self.assertRegex(graph, rf"(?m)^{field}:", field)
        task_fields = [
            "id", "objective", "agent", "mode", "dependencies", "inputs", "read_scope",
            "write_scope", "forbidden_scope", "deliverable", "minimum_verification",
            "can_launch", "held_reason", "stop_conditions",
        ]
        for field in task_fields:
            self.assertRegex(graph, rf"(?m)^    {field}:", field)
        for field in ["command_or_procedure", "passing_condition", "required_evidence"]:
            self.assertRegex(graph, rf"(?m)^      {field}:", field)

    def test_luna_packet_and_return_use_canonical_fields(self) -> None:
        protocol = (SKILL_ROOT / "references" / "routing-protocol.md").read_text(encoding="utf-8")
        packet = self.fenced_block(protocol, "## Luna task packet", "text")
        for field in [
            "Task ID", "Objective", "Why it matters", "Inputs and evidence", "Read scope",
            "Write scope", "Forbidden scope", "Dependencies", "Constraints",
            "Required deliverable", "Acceptance criteria", "Minimum verification",
            "  Command or procedure", "  Passing condition", "  Required evidence",
            "Stop conditions", "Return format",
        ]:
            self.assertRegex(packet, rf"(?m)^{re.escape(field)}:", field)

        result = self.fenced_block(protocol, "## Luna return contract", "text")
        for field in [
            "Status", "Summary", "Files inspected", "Files changed", "Verification performed",
            "Exact verification result", "Evidence", "Assumptions", "Risks", "Blockers",
        ]:
            self.assertRegex(result, rf"(?m)^{re.escape(field)}:", field)

    def test_sol_final_review_uses_canonical_fields(self) -> None:
        protocol = (SKILL_ROOT / "references" / "routing-protocol.md").read_text(encoding="utf-8")
        review = self.fenced_block(protocol, "## Sol final review", "yaml")
        for field in [
            "verdict", "requirements_coverage", "findings", "required_fixes",
            "optional_improvements", "evidence_quality", "remaining_risks",
        ]:
            self.assertRegex(review, rf"(?m)^{field}:", field)

    def test_forward_fixture_has_required_cases(self) -> None:
        path = ROOT / "tests" / "fixtures" / "forward-cases.json"
        cases = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(13, len(cases))
        self.assertEqual(13, len({case["id"] for case in cases}))
        for case in cases:
            self.assertTrue(case["prompt"])
            self.assertTrue(case["expected_level"])
            self.assertTrue(case["expected_mode"])
            self.assertIsInstance(case["expected_delegation"], int)
            self.assertGreaterEqual(len(case["required_assertions"]), 3)

    def test_skill_has_no_forbidden_project_or_model_terms(self) -> None:
        combined = "\n".join(
            path.read_text(encoding="utf-8")
            for path in SKILL_ROOT.rglob("*")
            if path.is_file()
        )
        forbidden = ["IPZOR", "Buzz", "DeepSeek", "OpenPencil", "gpt-5.6-terra"]
        hits = [term for term in forbidden if re.search(re.escape(term), combined, re.IGNORECASE)]
        self.assertEqual([], hits)


if __name__ == "__main__":
    unittest.main(verbosity=2)
