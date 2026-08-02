#!/usr/bin/env python3
"""Contract tests for the v0.2.0 and v0.3.0 ``sol-luna`` package."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError as exc:  # pragma: no cover - old runner guard
    raise SystemExit("tests require Python 3.11+ for tomllib") from exc


ROOT = Path(__file__).resolve().parents[1]
SKILL_ROOT = ROOT / ".agents" / "skills" / "sol-luna"
SOL_AGENT = ROOT / ".codex" / "agents" / "sol-controller.toml"
LUNA_AGENT = ROOT / ".codex" / "agents" / "luna-max-worker.toml"
RUNTIME_NOTE_CANDIDATES = (
    SKILL_ROOT / "runtime-notes.md",
    SKILL_ROOT / "references" / "runtime-notes.md",
)
V030_REQUIRED_FILES = (
    "README.zh-CN.md",
    "docs/assets/sol-luna-hero.svg",
    "docs/assets/sol-luna-architecture.svg",
    "scripts/validate.ps1",
    "scripts/uninstall.ps1",
    "tests/windows-lifecycle.ps1",
    ".github/workflows/windows-validation.yml",
)
CANONICAL_REPOSITORY_URL = "https://github.com/yehyakin/codex-sol-luna"
OLD_REPOSITORY_URL = "https://github.com/yehyakin/codex-sol-luna-orchestrator"


def read_if_present(path: Path) -> str:
    """Return empty text for a not-yet-created v0.2 target."""

    return path.read_text(encoding="utf-8") if path.is_file() else ""


class RepositoryContractTests(unittest.TestCase):
    def runtime_note_path(self) -> Path | None:
        return next((path for path in RUNTIME_NOTE_CANDIDATES if path.is_file()), None)

    def contract_text(self) -> str:
        runtime_path = self.runtime_note_path()
        return "\n".join(
            [
                read_if_present(SKILL_ROOT / "SKILL.md"),
                read_if_present(runtime_path) if runtime_path else "",
            ]
        )

    def test_required_v020_files_exist(self) -> None:
        required = [
            SKILL_ROOT / "SKILL.md",
            SKILL_ROOT / "agents" / "openai.yaml",
            SOL_AGENT,
            LUNA_AGENT,
        ]
        self.assertTrue(
            any(path.is_file() for path in RUNTIME_NOTE_CANDIDATES),
            "v0.2 must keep runtime mechanics in runtime-notes.md",
        )
        self.assertEqual(
            [],
            [str(path.relative_to(ROOT)) for path in required if not path.is_file()],
        )

    def test_required_v030_files_exist(self) -> None:
        missing = [relative for relative in V030_REQUIRED_FILES if not (ROOT / relative).is_file()]
        self.assertEqual([], missing, "missing v0.3 contract artifact(s)")

    def test_repository_rename_uses_the_canonical_v030_url(self) -> None:
        for relative in ("README.md", "README.zh-CN.md"):
            path = ROOT / relative
            self.assertTrue(path.is_file(), relative)
            text = path.read_text(encoding="utf-8")
            self.assertIn(CANONICAL_REPOSITORY_URL, text, relative)
            self.assertNotIn(OLD_REPOSITORY_URL, text, relative)

    def test_windows_sources_declare_the_v030_native_lifecycle_contract(self) -> None:
        required = {
            "install": ROOT / "scripts" / "install.ps1",
            "validate": ROOT / "scripts" / "validate.ps1",
            "uninstall": ROOT / "scripts" / "uninstall.ps1",
            "lifecycle_test": ROOT / "tests" / "windows-lifecycle.ps1",
        }
        missing = [name for name, path in required.items() if not path.is_file()]
        self.assertEqual([], missing, "missing Windows v0.3 file(s)")

        install = required["install"].read_text(encoding="utf-8")
        for marker in (
            "#requires -Version 5.1",
            "Set-StrictMode",
            "-LiteralPath",
            "ReparsePoint",
            "SHA256",
            "ORCHESTRATE_FAILPOINT",
            "after-replace",
            "orchestrate-sol-luna",
            "README.zh-CN.md",
            "docs/assets/sol-luna-hero.svg",
            "docs/assets/sol-luna-architecture.svg",
            "scripts/validate.ps1",
            "scripts/uninstall.ps1",
        ):
            self.assertIn(marker, install, marker)

        validate = required["validate"].read_text(encoding="utf-8")
        for marker in (
            "#requires -Version 5.1",
            "Get-Content",
            "Parser]::ParseFile",
            "Markdown",
            "SVG",
            "PowerShell syntax",
        ):
            self.assertIn(marker, validate, marker)

        uninstall = required["uninstall"].read_text(encoding="utf-8")
        for marker in (
            "RestoreLatest",
            "SHA256",
            "install-state",
            "-LiteralPath",
            "config.toml",
        ):
            self.assertIn(marker, uninstall, marker)

    def test_windows_workflow_covers_both_supported_powershell_editions(self) -> None:
        path = ROOT / ".github" / "workflows" / "windows-validation.yml"
        self.assertTrue(path.is_file(), path)
        text = path.read_text(encoding="utf-8")
        for marker in (
            "windows-latest",
            "windows-2022",
            "powershell",
            "pwsh",
            "tests/windows-lifecycle.ps1",
            "unittest discover",
        ):
            self.assertIn(marker, text, marker)

    def test_public_skill_is_named_and_explicitly_invoked(self) -> None:
        text = read_if_present(SKILL_ROOT / "SKILL.md")
        self.assertTrue(text.startswith("---\n"), "SKILL.md must have frontmatter")
        frontmatter = text.split("---", 2)[1] if "---" in text else ""
        self.assertRegex(frontmatter, r"(?m)^name:\s*sol-luna\s*$")
        self.assertRegex(frontmatter, r"(?m)^description:\s*Use when\b")
        self.assertIn("$sol-luna", text)
        self.assertRegex(text, r"(?i)ordinary\s+simple\s+(work|tasks?).{0,120}\bdirect\b")
        self.assertRegex(text, r"(?i)planning[- ]only.{0,120}zero\s+Luna")

    def test_runtime_defaults_to_chinese_unless_the_user_overrides_it(self) -> None:
        skill_text = read_if_present(SKILL_ROOT / "SKILL.md")
        self.assertIn("默认使用中文", skill_text)
        self.assertIn("用户明确要求", skill_text)
        self.assertIn("其他语言", skill_text)

        for path in (SOL_AGENT, LUNA_AGENT):
            with path.open("rb") as handle:
                instructions = tomllib.load(handle)["developer_instructions"]
            self.assertIn("默认使用中文", instructions, path.name)
            self.assertRegex(instructions, r"用户.*明确.*其他语言", path.name)

        openai_text = read_if_present(SKILL_ROOT / "agents" / "openai.yaml")
        self.assertIn('default_prompt: "使用 $sol-luna', openai_text)

        english_readme = read_if_present(ROOT / "README.md")
        chinese_readme = read_if_present(ROOT / "README.zh-CN.md")
        self.assertIn("Runtime output defaults to Simplified Chinese", english_readme)
        self.assertIn("运行时默认使用简体中文", chinese_readme)

    def test_sol_plan_has_only_the_v020_canonical_fields(self) -> None:
        text = self.contract_text()
        for field in ["goal", "done_when", "tasks", "stages"]:
            self.assertRegex(text, rf"(?m)^\s*{field}:\s*", field)

    def test_luna_task_packet_uses_the_simplified_fields(self) -> None:
        text = self.contract_text()
        for field in [
            "Task ID",
            "Task",
            "Write scope",
            "Do not touch",
            "Expected result",
            "Verification",
        ]:
            self.assertRegex(text, rf"(?m)^\s*{re.escape(field)}:\s*", field)
        self.assertRegex(text, r"(?i)Context:\s*.*optional")

    def test_luna_result_and_sol_review_contracts_are_falsifiable(self) -> None:
        text = self.contract_text()
        for field in ["Task ID", "Status", "Summary", "Changed", "Verification", "Evidence", "Blocker"]:
            self.assertRegex(text, rf"(?m)^\s*{re.escape(field)}:\s*", field)
        self.assertRegex(text, r"(?m)^\s*Status:\s*PASS\s*\|\s*BLOCKED\s*$")
        self.assertRegex(text, r"(?i)PASS\s*\|\s*FIX\s*\|\s*BLOCKED")
        self.assertRegex(text, r"(?i)at\s+most\s+one[^\n]*(focused\s+)?fix")

    def test_routing_safety_keeps_runtime_mechanics_internal(self) -> None:
        skill_text = read_if_present(SKILL_ROOT / "SKILL.md")
        runtime_path = self.runtime_note_path()
        runtime_text = read_if_present(runtime_path) if runtime_path else ""
        self.assertTrue(runtime_text, "runtime-notes.md must contain the internal runtime rules")

        combined = f"{skill_text}\n{runtime_text}"
        for phrase in [
            "one file",
            "one owner",
            "shared integration",
            "live capacity",
            "batch",
            "exact model",
            "reasoning effort",
            "Fail Closed",
        ]:
            self.assertRegex(combined, rf"(?i){re.escape(phrase)}", phrase)

    def test_agent_models_effort_permissions_and_no_subagents(self) -> None:
        expected = {
            SOL_AGENT: ("sol-controller", "gpt-5.6-sol", "high", "read-only"),
            LUNA_AGENT: ("luna-max-worker", "gpt-5.6-luna", "max", "workspace-write"),
        }
        for path, values in expected.items():
            self.assertTrue(path.is_file(), path)
            with path.open("rb") as handle:
                data = tomllib.load(handle)
            name, model, effort, sandbox = values
            self.assertEqual(name, data["name"])
            self.assertEqual(model, data["model"])
            self.assertEqual(effort, data["model_reasoning_effort"])
            self.assertEqual(sandbox, data["sandbox_mode"])
            self.assertIn("developer_instructions", data)

        luna_text = read_if_present(LUNA_AGENT)
        self.assertRegex(luna_text, r"(?i)do not (spawn|create).*subagent")
        self.assertRegex(luna_text, r"(?i)parent permission boundary")
        self.assertRegex(self.contract_text(), r"(?i)Fail Closed")

    def test_forward_fixture_covers_only_v020_routes(self) -> None:
        path = ROOT / "tests" / "fixtures" / "forward-cases.json"
        cases = json.loads(path.read_text(encoding="utf-8"))
        expected_ids = {
            "ordinary-simple-direct",
            "explicit-sol-luna",
            "planning-only-sol",
            "single-file-execution",
            "live-capacity-batching",
            "shared-integration-owner",
            "incomplete-luna-packet",
            "exact-selection-unavailable",
            "focused-sol-fix",
            "dirty-worktree-preserved",
        }
        self.assertEqual(expected_ids, {case["id"] for case in cases})
        self.assertEqual(len(expected_ids), len(cases))

        allowed_routes = {"direct", "sol", "sol_then_luna", "blocked"}
        allowed_presence = {"none", "optional", "required", "blocked"}
        allowed_reviews = {"not_applicable", "PASS", "FIX", "BLOCKED"}
        allowed_capacity = {"not_applicable", "live"}

        for case in cases:
            self.assertTrue(case["prompt"])
            expected = case["expected"]
            self.assertIn(expected["route"], allowed_routes)
            self.assertIn(expected["sol"], allowed_presence)
            self.assertIn(expected["luna"], allowed_presence)
            self.assertIn(expected["review"], allowed_reviews)
            self.assertIn(expected["capacity"], allowed_capacity)
            self.assertGreaterEqual(len(case["required_assertions"]), 3)

    def test_public_skill_has_no_unrelated_brand_or_model_contamination(self) -> None:
        combined = "\n".join(
            path.read_text(encoding="utf-8")
            for path in SKILL_ROOT.rglob("*")
            if path.is_file()
        ) if SKILL_ROOT.is_dir() else ""
        forbidden = ["IPZOR", "Buzz", "DeepSeek", "OpenPencil", "gpt-5.6-terra"]
        hits = [term for term in forbidden if re.search(re.escape(term), combined, re.IGNORECASE)]
        self.assertEqual([], hits)


if __name__ == "__main__":
    unittest.main(verbosity=2)
