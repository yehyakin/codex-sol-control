#!/usr/bin/env python3
"""Contract tests for the ``sol-control`` package."""

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
SKILL_ROOT = ROOT / ".agents" / "skills" / "sol-control"
SOL_AGENT = ROOT / ".codex" / "agents" / "sol-controller.toml"
LUNA_AGENT = ROOT / ".codex" / "agents" / "luna-max-worker.toml"
TERRA_AGENT = ROOT / ".codex" / "agents" / "terra-high-worker.toml"
RUNTIME_NOTE_CANDIDATES = (
    SKILL_ROOT / "runtime-notes.md",
    SKILL_ROOT / "references" / "runtime-notes.md",
)
V030_REQUIRED_FILES = (
    "README.en.md",
    "docs/assets/readme/hero-zh.svg",
    "docs/assets/readme/hero-en.svg",
    "docs/assets/readme/control-plane-zh.svg",
    "docs/assets/readme/control-plane-en.svg",
    "scripts/validate.ps1",
    "scripts/uninstall.ps1",
    "tests/windows-lifecycle.ps1",
    ".github/workflows/windows-validation.yml",
)
CANONICAL_REPOSITORY_URL = "https://github.com/yehyakin/codex-sol-control"
OLD_REPOSITORY_URLS = (
    "https://github.com/yehyakin/codex-sol-luna",
    "https://github.com/yehyakin/codex-sol-luna-orchestrator",
)


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
            TERRA_AGENT,
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
        for relative in ("README.md", "README.en.md"):
            path = ROOT / relative
            self.assertTrue(path.is_file(), relative)
            text = path.read_text(encoding="utf-8")
            self.assertIn(CANONICAL_REPOSITORY_URL, text, relative)
            for old_url in OLD_REPOSITORY_URLS:
                self.assertNotIn(old_url, text, relative)

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
            "README.en.md",
            "docs/assets/readme/hero-zh.svg",
            "docs/assets/readme/hero-en.svg",
            "docs/assets/readme/control-plane-zh.svg",
            "docs/assets/readme/control-plane-en.svg",
            "scripts/validate.ps1",
            "scripts/uninstall.ps1",
            "terra-high-worker.toml",
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
            "terra-high-worker.toml",
        ):
            self.assertIn(marker, validate, marker)

        uninstall = required["uninstall"].read_text(encoding="utf-8")
        for marker in (
            "RestoreLatest",
            "SHA256",
            "install-state",
            "-LiteralPath",
            "config.toml",
            "terra-high-worker.toml",
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
        self.assertRegex(frontmatter, r"(?m)^name:\s*sol-control\s*$")
        self.assertRegex(frontmatter, r"(?m)^description:\s*Use when\b")
        self.assertIn("$sol-control", text)
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

        with TERRA_AGENT.open("rb") as handle:
            terra_instructions = tomllib.load(handle)["developer_instructions"]
        self.assertIn("默认使用中文", terra_instructions, TERRA_AGENT.name)
        self.assertRegex(terra_instructions, r"用户.*明确.*其他语言", TERRA_AGENT.name)

        openai_text = read_if_present(SKILL_ROOT / "agents" / "openai.yaml")
        self.assertIn('default_prompt: "使用 $sol-control', openai_text)

        chinese_readme = read_if_present(ROOT / "README.md")
        english_readme = read_if_present(ROOT / "README.en.md")
        self.assertRegex(chinese_readme, r"运行时默认使用简体中文|默认简体中文")
        self.assertRegex(
            english_readme,
            r"Runtime output defaults to Simplified Chinese|(?:canonical|default).{0,80}Simplified Chinese",
        )

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

    def test_v040_evidence_binds_final_candidate_and_invalidates_stale_evidence(self) -> None:
        text = self.contract_text()
        self.assertIn(
            "Evidence must bind to the final candidate identity",
            text,
        )
        self.assertRegex(
            text,
            r"(?i)commit\+diff identity|exact changed-file snapshot",
        )
        self.assertRegex(
            text,
            r"(?is)candidate changes? after verification.{0,160}(?:stale|invalid).{0,160}rerun",
        )
        self.assertNotRegex(text, r"(?m)^\s*Candidate:\s*")

    def test_v040_transport_completion_cannot_substitute_task_pass(self) -> None:
        text = self.contract_text()
        self.assertIn(
            "transport/spawn `completed` only proves delivery lifecycle completion",
            text,
        )
        self.assertRegex(
            text,
            r"(?i)cannot substitute for (?:a )?structured Luna `?PASS`?",
        )
        self.assertRegex(
            text,
            r"(?i)Verification/Evidence/changed-path proof",
        )
        self.assertRegex(text, r"(?i)Sol review")

    def test_v040_correction_packets_require_allowed_failure_class_and_delta(self) -> None:
        text = self.contract_text()
        allowed = "runtime | timeout | model_identity | permission | dependency | scope | verification | evidence_quality | conflict | none"
        self.assertIn(allowed, text)
        self.assertIn("Failure class:", text)
        self.assertIn("Correction Packet", text)
        self.assertRegex(text, r"(?is)Correction Packet.{0,220}Delta")
        self.assertRegex(
            text,
            r"(?i)same (?:task )?packet.{0,100}no new evidence.{0,100}BLOCKED",
        )

    def test_v040_resume_packet_is_long_task_only_and_has_minimal_fields(self) -> None:
        text = self.contract_text()
        self.assertIn("Resume packet", text)
        for field in ("goal", "completed", "in_flight", "artifact_location", "next_action"):
            self.assertRegex(text, rf"(?is)Resume packet.{{0,300}}\b{re.escape(field)}\b")
        self.assertRegex(text, r"(?i)Resume packet.{0,180}(?:long|compression|interruption)")
        self.assertIn("Short and Direct tasks never generate a resume packet", text)

    def test_v041_authorized_execution_plan_is_not_a_stop_point(self) -> None:
        text = self.contract_text()
        self.assertRegex(
            text,
            r"(?is)authorized execution.{0,220}(?:plan|planning).{0,180}(?:not|never).{0,100}stop",
        )
        self.assertRegex(
            text,
            r"(?is)(?:stop|pause).{0,180}(?:new permission|irreversible|real blocker)",
        )
        self.assertRegex(
            text,
            r"(?is)(?:new permission|irreversible choice|real blocker).{0,180}(?:only|unless)",
        )

    def test_v041_status_questions_do_not_pause_authorized_work(self) -> None:
        text = self.contract_text()
        self.assertRegex(
            text,
            r"(?is)(?:ordinary|normal|routine) status (?:question|inquiry).{0,180}(?:continue|resume|does not pause|not pause)",
        )
        self.assertRegex(
            text,
            r"(?is)(?:status (?:question|inquiry)).{0,180}(?:no new permission|not a blocker)",
        )

    def test_v041_planning_timebox_must_converge(self) -> None:
        text = self.contract_text()
        self.assertRegex(
            text,
            r"(?is)planning.{0,120}(?:timebox|time box).{0,220}(?:plan|determination|evidence gap)",
        )
        self.assertRegex(
            text,
            r"(?is)(?:plan|determination|evidence gap).{0,120}(?:within|inside|before).{0,120}(?:timebox|time box)",
        )

    def test_v041_later_stage_blocker_still_delivers_earlier_evidence(self) -> None:
        text = self.contract_text()
        self.assertRegex(
            text,
            r"(?is)(?:later|subsequent|downstream) stage.{0,220}(?:blocked|blocker).{0,220}(?:earlier|prior|completed) stage.{0,180}(?:deliver|return|ship).{0,180}(?:evidence|artifact)",
        )
        self.assertRegex(
            text,
            r"(?is)(?:partial|front-loaded) delivery.{0,180}(?:evidence-complete|complete evidence)",
        )

    def test_v041_completed_without_structured_result_allows_one_result_only_follow_up(self) -> None:
        text = self.contract_text()
        self.assertRegex(
            text,
            r"(?is)completed.{0,160}(?:without|no).{0,100}structured.{0,100}result.{0,220}(?:one|single).{0,80}(?:same|original) worker.{0,140}(?:result-only|result only) follow[- ]up",
        )
        self.assertRegex(
            text,
            r"(?is)(?:result-only|result only) follow[- ]up.{0,180}(?:no new write|no re[- ]execut|not authorize).{0,100}(?:write|execution)",
        )
        self.assertRegex(
            text,
            r"(?is)(?:still|otherwise).{0,120}(?:no|without).{0,100}(?:structured|bound final candidate).{0,150}BLOCKED",
        )

    def test_v041_urgency_cannot_lower_evidence_threshold(self) -> None:
        text = self.contract_text()
        self.assertRegex(
            text,
            r"(?is)(?:urgent|urgency|hurry|do not stop|don't stop|催促).{0,220}(?:cannot|does not|must not).{0,160}(?:lower|relax|reduce).{0,120}(?:evidence|verification).{0,100}(?:threshold|bar)",
        )
        self.assertRegex(
            text,
            r"(?is)(?:evidence|verification).{0,100}(?:threshold|bar).{0,160}(?:unchanged|remains|still applies)",
        )

    def test_v041_explicit_user_steering_stops_old_plan_and_replans(self) -> None:
        text = self.contract_text()
        self.assertRegex(
            text,
            r"(?is)explicit user (?:cancellation|replacement|redirection).{0,180}(?:stop|stops).{0,100}(?:old|current).{0,100}(?:plan|task)",
        )
        self.assertRegex(
            text,
            r"(?is)(?:substantive|material) user steering.{0,160}(?:not|never).{0,100}ordinary status (?:question|inquiry)",
        )
        self.assertRegex(
            text,
            r"(?is)(?:requires|must).{0,100}re-?plan.{0,180}(?:new|updated).{0,100}(?:request|goal)",
        )

    def test_v041_runtime_surface_matrix_is_release_time_only(self) -> None:
        path = ROOT / "docs" / "release" / "runtime-surface-matrix.md"
        self.assertTrue(path.is_file(), path)
        text = path.read_text(encoding="utf-8")
        for surface in ("Desktop", "CLI", "codex exec"):
            self.assertIn(surface, text, surface)
        for signal in (
            "Agent selection",
            "exact model",
            "reasoning",
            "nested dispatch",
            "result retrieval",
            "candidate binding",
        ):
            self.assertIn(signal, text, signal)
        for status in ("VERIFIED", "FAILED", "UNVERIFIED"):
            self.assertIn(status, text, status)
        self.assertRegex(text, r"(?i)release[- ]time|release documentation|per-task")
        self.assertIn("| Desktop | Agent selection | VERIFIED |", text)
        self.assertIn("| Desktop | exact model | VERIFIED |", text)
        self.assertIn("| Desktop | reasoning | VERIFIED |", text)
        self.assertIn("| Desktop | nested dispatch | VERIFIED |", text)
        self.assertRegex(
            text,
            r"(?is)Desktop\s*\|\s*nested dispatch\s*\|\s*VERIFIED.{0,320}"
            r"`sol-controller`.{0,180}`terra-high-worker`.{0,180}`luna-max-worker`",
        )
        self.assertRegex(
            text,
            r"(?is)does not ask the child to self-report.{0,180}Host/tool role mapping.{0,180}launch record",
        )

    def test_runtime_notes_preserve_host_safety_checkpoints_and_environment_hygiene(self) -> None:
        text = self.contract_text()
        for marker in (
            "First-artifact checkpoint",
            "smallest observable first artifact",
            "Host's stated execution timebox",
            "Before dispatching a Sol `FIX`",
            "permissions, and side effects",
            "Verification environment hygiene",
            "committed lockfile",
            "different package manager",
            "unexpectedly changes the worktree or dependency layout",
            "stop, attribute the new paths and timestamps",
        ):
            self.assertIn(marker, text, marker)

    def test_runtime_matrix_verified_rows_have_checkable_evidence(self) -> None:
        path = ROOT / "docs" / "release" / "runtime-surface-matrix.md"
        text = path.read_text(encoding="utf-8")
        verified_rows = [line for line in text.splitlines() if "| VERIFIED |" in line]
        for row in verified_rows:
            self.assertRegex(row, r"`[^`]+`")

    def test_failure_class_none_means_no_failure(self) -> None:
        contract_paths = (
            SKILL_ROOT / "SKILL.md",
            SKILL_ROOT / "references" / "orchestration.md",
            SKILL_ROOT / "references" / "runtime-notes.md",
            SOL_AGENT,
            LUNA_AGENT,
            TERRA_AGENT,
        )
        for path in contract_paths:
            text = read_if_present(path)
            with self.subTest(path=path.relative_to(ROOT) if path.is_relative_to(ROOT) else path):
                self.assertRegex(
                    text,
                    r"(?is)`?none`?.{0,120}(?:no failure|failure is absent|without a failure)",
                )

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
            TERRA_AGENT: ("terra-high-worker", "gpt-5.6-terra", "high", "workspace-write"),
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
        self.assertRegex(
            luna_text,
            r"(?i)(?:parent permission boundary|capability is not authorization)",
        )
        terra_text = read_if_present(TERRA_AGENT)
        self.assertRegex(terra_text, r"(?i)do not (spawn|create).*subagent")
        self.assertRegex(
            terra_text,
            r"(?i)(?:parent permission boundary|capability is not authorization)",
        )
        self.assertRegex(self.contract_text(), r"(?i)Fail Closed")

    def test_forward_fixture_covers_v020_routes_and_v040_reliability_cases(self) -> None:
        path = ROOT / "tests" / "fixtures" / "forward-cases.json"
        cases = json.loads(path.read_text(encoding="utf-8"))
        expected_ids = {
            "ordinary-simple-direct",
            "explicit-sol-control",
            "planning-only-sol",
            "single-file-execution",
            "live-capacity-batching",
            "shared-integration-owner",
            "incomplete-luna-packet",
            "exact-selection-unavailable",
            "focused-sol-fix",
            "dirty-worktree-preserved",
            "stale-evidence-after-candidate-change",
            "transport-completed-not-pass",
            "identical-retry-no-delta",
            "long-task-resume",
            "authorized-plan-not-stop",
            "status-inquiry-keeps-running",
            "planning-timebox-converges",
            "partial-stage-delivery-on-blocker",
            "completed-no-result-one-recovery",
            "completed-no-result-recovery-blocked",
            "urgency-does-not-lower-evidence",
            "explicit-user-steering-replans",
            "luna-low-ambiguity-small-context",
            "terra-cross-module-long-context",
            "model-identity-unavailable-fail-closed",
            "broader-runtime-capability-keeps-narrow-authorization",
            "irreversible-work-requires-enforced-boundary",
            "luna-classification-error-escalates-terra",
            "luna-first-failure-before-write-escalates-terra",
            "luna-first-failure-after-write-keeps-luna-owner",
            "single-file-unique-owner",
            "v050-requirement-evidence-gap",
            "v050-worker-pass-is-untrusted",
            "v050-wrong-scope-verifier",
            "v050-high-risk-selective-challenge",
            "v050-standard-task-no-challenge",
            "v050-resume-no-duplicate-dispatch",
            "v050-timeout-after-write-keeps-owner",
            "v050-residual-suggestions-do-not-change-pass",
        }
        self.assertEqual(expected_ids, {case["id"] for case in cases})
        self.assertEqual(len(expected_ids), len(cases))

        allowed_routes = {"direct", "sol", "sol_then_luna", "sol_then_terra", "blocked"}
        allowed_presence = {"none", "optional", "required", "blocked"}
        allowed_reviews = {"not_applicable", "PASS", "FIX", "BLOCKED"}
        allowed_capacity = {"not_applicable", "live"}
        allowed_resume = {"not_applicable", "forbidden", "required"}
        allowed_challenge = {"none", "required", "blocked"}

        for case in cases:
            self.assertTrue(case["prompt"])
            expected = case["expected"]
            self.assertIn(expected["route"], allowed_routes)
            self.assertIn(expected["sol"], allowed_presence)
            self.assertIn(expected["luna"], allowed_presence)
            if "terra" in expected:
                self.assertIn(expected["terra"], allowed_presence)
            self.assertIn(expected["review"], allowed_reviews)
            self.assertIn(expected["capacity"], allowed_capacity)
            if "resume" in expected:
                self.assertIn(expected["resume"], allowed_resume)
            if "challenge" in expected:
                self.assertIn(expected["challenge"], allowed_challenge)
            self.assertGreaterEqual(len(case["required_assertions"]), 3)

        by_id = {case["id"]: case for case in cases}
        self.assertEqual("forbidden", by_id["ordinary-simple-direct"]["expected"].get("resume"))
        self.assertEqual("required", by_id["long-task-resume"]["expected"].get("resume"))

        ownership_ids = {
            "luna-first-failure-before-write-escalates-terra",
            "luna-first-failure-after-write-keeps-luna-owner",
        }
        missing = ownership_ids - set(by_id)
        if missing:
            self.fail(f"fixture is missing ownership-transfer scenarios: {sorted(missing)}")
        allow = by_id["luna-first-failure-before-write-escalates-terra"]
        forbid = by_id["luna-first-failure-after-write-keeps-luna-owner"]
        self.assertEqual(0, allow["luna_state"]["owned_files_written_before_failure"])
        self.assertTrue(allow["luna_state"]["failed_before_owned_write"])
        self.assertEqual("same_task_same_scope_once", allow["expected"]["upgrade"])
        self.assertEqual(1, forbid["luna_state"]["owned_files_written_before_failure"])
        self.assertFalse(forbid["luna_state"]["failed_before_owned_write"])
        self.assertEqual("blocked", forbid["expected"]["terra"])
        self.assertEqual("luna_retains_scope", forbid["expected"]["ownership"])
        self.assertEqual("focused_fix_or_blocked", forbid["expected"]["correction"])

    def test_public_skill_has_no_unrelated_brand_or_model_contamination(self) -> None:
        combined = "\n".join(
            path.read_text(encoding="utf-8")
            for path in SKILL_ROOT.rglob("*")
            if path.is_file()
        ) if SKILL_ROOT.is_dir() else ""
        forbidden = ["IPZOR", "Buzz", "DeepSeek", "OpenPencil"]
        hits = [term for term in forbidden if re.search(re.escape(term), combined, re.IGNORECASE)]
        self.assertEqual([], hits)


if __name__ == "__main__":
    unittest.main(verbosity=2)
