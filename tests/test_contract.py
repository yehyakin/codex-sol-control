#!/usr/bin/env python3
"""Public repository and Skill contracts for Codex PROVE v1.0."""

from __future__ import annotations

import re
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / ".agents" / "skills" / "codex-prove"
COMPAT = ROOT / ".agents" / "skills" / "sol-control"
CONTROLLER = ROOT / ".codex" / "agents" / "prove-controller.toml"
COMPLEX = ROOT / ".codex" / "agents" / "prove-complex-worker.toml"
EFFICIENT = ROOT / ".codex" / "agents" / "prove-efficient-worker.toml"
REPO_URL = "https://github.com/yehyakin/codex-prove"


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


class RepositoryStructureTests(unittest.TestCase):
    def test_canonical_skill_structure_exists(self) -> None:
        for path in (
            SKILL / "SKILL.md",
            SKILL / "agents" / "openai.yaml",
            SKILL / "references" / "orchestration.md",
            SKILL / "references" / "runtime-notes.md",
        ):
            self.assertTrue(path.is_file(), path)

    def test_compatibility_entry_is_small_and_has_no_second_protocol(self) -> None:
        self.assertTrue((COMPAT / "SKILL.md").is_file())
        self.assertTrue((COMPAT / "agents" / "openai.yaml").is_file())
        self.assertFalse((COMPAT / "references").exists())
        self.assertLess(len(read(COMPAT / "SKILL.md").splitlines()), 30)

    def test_only_model_neutral_agent_source_names_exist(self) -> None:
        names = sorted(path.name for path in (ROOT / ".codex" / "agents").glob("*.toml"))
        self.assertEqual(
            ["prove-complex-worker.toml", "prove-controller.toml", "prove-efficient-worker.toml"],
            names,
        )

    def test_public_docs_use_new_repository_url(self) -> None:
        for path in (ROOT / "README.md", ROOT / "README.en.md", ROOT / "SECURITY.md"):
            text = read(path)
            self.assertIn(REPO_URL, text, path.name)
            self.assertNotIn("github.com/yehyakin/codex-sol-control", text, path.name)

    def test_required_release_files_exist(self) -> None:
        for relative in (
            "CODEX_PROVE_V1_IMPLEMENTATION_REPORT.md",
            "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "SECURITY.md", "SUPPORT.md",
            "scripts/install.sh", "scripts/uninstall.sh", "scripts/validate.sh",
            "scripts/install.ps1", "scripts/uninstall.ps1", "scripts/validate.ps1",
        ):
            self.assertTrue((ROOT / relative).is_file(), relative)


class InvocationAndLanguageTests(unittest.TestCase):
    def test_canonical_frontmatter_is_explicit_only(self) -> None:
        text = read(SKILL / "SKILL.md")
        frontmatter = text.split("---", 2)[1]
        self.assertRegex(frontmatter, r"(?m)^name:\s*codex-prove\s*$")
        self.assertRegex(frontmatter, r"(?m)^description:\s*Use only when\b")
        self.assertIn("$codex-prove", frontmatter)

    def test_canonical_interface_disables_implicit_invocation(self) -> None:
        text = read(SKILL / "agents" / "openai.yaml")
        self.assertIn('display_name: "Codex PROVE"', text)
        self.assertIn("$codex-prove", text)
        self.assertRegex(text, r"(?m)^\s*allow_implicit_invocation:\s*false\s*$")

    def test_legacy_alias_redirects_without_implicit_invocation(self) -> None:
        text = read(COMPAT / "SKILL.md") + read(COMPAT / "agents" / "openai.yaml")
        self.assertIn("$sol-control", text)
        self.assertIn("$codex-prove", text)
        self.assertIn("deprecated", text)
        self.assertRegex(text, r"(?m)^\s*allow_implicit_invocation:\s*false\s*$")

    def test_runtime_defaults_to_chinese(self) -> None:
        self.assertIn("默认使用中文", read(SKILL / "SKILL.md"))
        for path in (CONTROLLER, COMPLEX, EFFICIENT):
            with path.open("rb") as handle:
                instructions = tomllib.load(handle)["developer_instructions"]
            self.assertIn("默认使用中文", instructions, path.name)
            self.assertIn("其他语言", instructions, path.name)

    def test_readme_default_is_chinese_with_english_peer(self) -> None:
        self.assertIn("运行时默认使用简体中文", read(ROOT / "README.md"))
        self.assertIn("Runtime output defaults to Simplified Chinese", read(ROOT / "README.en.md"))


class PlanningAndPacketTests(unittest.TestCase):
    def test_plan_has_requirements_tasks_stages_and_integration_owner(self) -> None:
        text = contract()
        for field in ("goal", "done_when", "tasks", "stages", "integration_owner"):
            self.assertRegex(text, rf"(?m)^\s*{field}:\s*", field)

    def test_task_graph_has_dependency_and_launch_fields(self) -> None:
        text = contract()
        for field in ("agent_profile", "dependencies", "read_scope", "write_scope", "can_launch", "held_reason"):
            self.assertRegex(text, rf"(?m)^\s*{field}:\s*", field)

    def test_task_packet_is_complete_and_context_is_optional(self) -> None:
        text = contract()
        for field in (
            "Task ID", "Task", "Requirement IDs", "Read scope", "Write scope",
            "Do not touch", "Dependencies", "Expected result", "Verification",
            "Required evidence", "Stop conditions",
        ):
            self.assertRegex(text, rf"(?m)^\s*{re.escape(field)}:\s*", field)
        self.assertRegex(text, r"(?i)Context:\s*.*optional")

    def test_worker_result_is_structured_and_falsifiable(self) -> None:
        text = contract()
        for field in (
            "Status", "Summary", "Inspected", "Changed", "Requirement coverage",
            "Verification", "Evidence", "Assumptions", "Risks", "Failure class", "Blocker",
        ):
            self.assertRegex(text, rf"(?m)^\s*{re.escape(field)}:\s*", field)
        self.assertRegex(text, r"(?m)^\s*Status:\s*PASS\s*\|\s*BLOCKED\s*$")

    def test_requirement_ids_map_to_evidence(self) -> None:
        text = contract()
        self.assertRegex(text, r"(?is)done_when.{0,400}id:\s*REQ-1.{0,200}criterion:.{0,200}evidence:")
        self.assertRegex(text, r"(?is)tasks:.{0,500}requirements:\s*\[REQ-1\]")


class SchedulingAndOwnershipTests(unittest.TestCase):
    def test_one_file_has_one_owner(self) -> None:
        text = contract().lower()
        self.assertIn("one owner for the entire run", text)
        self.assertIn("shared interface", text)
        self.assertIn("preserve unrelated user changes", text)

    def test_disjoint_ready_tasks_parallelize_and_dependencies_wait(self) -> None:
        text = contract().lower()
        self.assertIn("dependencies are satisfied", text)
        self.assertIn("write scopes are disjoint", text)
        self.assertIn("run sequentially", text)

    def test_parallelism_uses_live_capacity_not_a_fixed_maximum(self) -> None:
        text = contract().lower()
        self.assertIn("live capacity", text)
        self.assertIn("one to three workers", text)
        self.assertIn("not a hard cap", text)

    def test_zero_write_escalation_preserves_ownership(self) -> None:
        text = contract().lower()
        self.assertIn("before any owned write", text)
        self.assertIn("unchanged task and scope", text)
        self.assertIn("never transfer", text)


class EvidenceAndReviewTests(unittest.TestCase):
    def test_final_candidate_changes_invalidate_evidence(self) -> None:
        text = contract().lower()
        self.assertIn("evidence must bind to the final candidate", text)
        self.assertIn("candidate changes", text)
        self.assertIn("stale", text)

    def test_transport_completed_is_not_pass(self) -> None:
        text = contract().lower()
        self.assertIn("completed", text)
        self.assertIn("delivery lifecycle completion only", text)
        self.assertIn("result-only follow-up", text)

    def test_controller_reviews_artifacts_before_summaries(self) -> None:
        text = contract().lower()
        start = text.index("review artifact-first")
        summary = text.index("worker summaries", start)
        diff = text.index("complete diff", start)
        self.assertLess(diff, summary)

    def test_controller_verifies_the_verifier(self) -> None:
        text = contract().lower()
        self.assertIn("verifies the verifier", text)
        self.assertIn("wrong-module", text)
        self.assertIn("existence-only", text)
        self.assertIn("evidence_quality", text)

    def test_final_verdict_is_closed(self) -> None:
        text = contract()
        self.assertIn("verdict: PASS | FIX | BLOCKED", text)
        self.assertIn("residual_suggestions", text)
        self.assertIn("evidence_quality", text)

    def test_selective_challenge_is_bounded_and_read_only(self) -> None:
        text = contract().lower()
        self.assertIn("zero challenge calls", text)
        self.assertIn("at most one bounded read-only challenge", text)
        self.assertIn("write_scope: []", text)
        self.assertIn("cannot become a second reviewer", text)

    def test_correction_is_single_owner_and_same_scope(self) -> None:
        text = contract().lower()
        self.assertIn("at most one focused correction packet", text)
        self.assertRegex(text, r"same[- ]scope")
        self.assertIn("never relaunch an identical packet", text)


class ContinuityAndSafetyTests(unittest.TestCase):
    def test_authorized_plan_is_not_a_stop_point(self) -> None:
        text = contract().lower()
        self.assertIn("a plan is not a stop point", text)
        self.assertRegex(text, r"status (?:inquiry|question)\s+does not pause")
        self.assertIn("urgency does not lower", text)

    def test_resume_packet_prevents_duplicate_dispatch(self) -> None:
        text = contract().lower()
        for field in ("run_id", "completed", "in_flight", "ownership", "candidate_identity", "attempts", "next_action"):
            self.assertIn(field, text)
        self.assertIn("do not redispatch completed tasks", text)
        self.assertIn("do not reset attempts", text)

    def test_capability_does_not_widen_authorization(self) -> None:
        text = contract().lower()
        self.assertIn("capability separate from authorization", text)
        self.assertRegex(text, r"broader technical access\s+does not\s+widen")
        self.assertRegex(text, r"host-owned\s+before/after changed-path")

    def test_skill_contains_no_business_project_terms(self) -> None:
        text = contract() + read(COMPAT / "SKILL.md")
        for forbidden in ("IPZOR", "Buzz", "DeepSeek", "OpenPencil"):
            self.assertNotRegex(text, re.compile(forbidden, re.I))


if __name__ == "__main__":
    unittest.main(verbosity=2)
