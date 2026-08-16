#!/usr/bin/env python3
"""Evidence-first controller contracts for the v0.5 Sol Control candidate."""

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
CONTRACT_PATHS = (
    SKILL_ROOT / "SKILL.md",
    SKILL_ROOT / "references" / "orchestration.md",
    SKILL_ROOT / "references" / "runtime-notes.md",
)
AGENT_PATHS = (
    ROOT / ".codex" / "agents" / "sol-controller.toml",
    ROOT / ".codex" / "agents" / "luna-max-worker.toml",
    ROOT / ".codex" / "agents" / "terra-high-worker.toml",
)
FORWARD_CASES = ROOT / "tests" / "fixtures" / "forward-cases.json"
AB_MANIFEST = ROOT / "tests" / "fixtures" / "v050-ab-benchmark.json"
AB_SCRIPT = ROOT / "scripts" / "benchmark_ab.py"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def contract_text() -> str:
    return "\n".join(read(path) for path in CONTRACT_PATHS)


class EvidenceGraphContractTests(unittest.TestCase):
    def test_sol_plan_maps_stable_requirements_to_tasks_and_evidence(self) -> None:
        text = contract_text()
        for marker in ("Requirement IDs", "REQ-", "criterion", "required evidence"):
            self.assertIn(marker, text)
        self.assertRegex(
            text,
            r"(?is)done_when.{0,500}\bid:\s*REQ-.{0,220}\bcriterion:.{0,220}\bevidence:",
        )
        self.assertRegex(
            text,
            r"(?is)tasks:.{0,700}requirements:.{0,220}REQ-",
        )

    def test_worker_packet_and_result_preserve_requirement_coverage(self) -> None:
        text = contract_text()
        self.assertRegex(text, r"(?m)^\s*Requirement IDs:\s*")
        self.assertRegex(text, r"(?m)^\s*Required evidence:\s*")
        self.assertRegex(text, r"(?m)^\s*Requirement coverage:\s*")
        self.assertRegex(
            text,
            r"(?is)Verification:.{0,220}(?:passing condition|Pass:).{0,220}(?:evidence|required evidence)",
        )

    def test_sol_final_review_contains_a_requirement_evidence_matrix(self) -> None:
        text = contract_text()
        self.assertIn("requirements_coverage", text)
        for marker in ("requirement", "status", "evidence"):
            self.assertRegex(
                text,
                rf"(?is)requirements_coverage.{{0,520}}\b{marker}\b",
            )
        self.assertRegex(
            text,
            r"(?is)PASS.{0,240}(?:every|all).{0,160}(?:requirement|REQ-).{0,160}(?:satisfied|evidenced)",
        )


class ReviewIntegrityContractTests(unittest.TestCase):
    def test_sol_uses_artifact_first_review_before_worker_summary(self) -> None:
        text = contract_text()
        self.assertRegex(text, r"(?i)artifact[- ]first")
        self.assertRegex(
            text,
            r"(?is)artifact[- ]first.{0,800}(?:original request|done_when).{0,240}"
            r"(?:changed paths|actual files|complete diff).{0,300}verification.{0,320}"
            r"(?:worker summary|worker self[- ]assessment|worker result)",
        )
        self.assertRegex(
            text,
            r"(?is)worker.{0,100}PASS.{0,140}(?:claim|untrusted|not evidence)",
        )

    def test_verification_quality_is_checked_not_just_exit_status(self) -> None:
        text = contract_text()
        self.assertRegex(text, r"(?i)verify the verifier|verification quality")
        for marker in (
            "correct final candidate",
            "intended requirement",
            "wrong scope",
            "existence-only",
        ):
            self.assertIn(marker, text)
        self.assertRegex(
            text,
            r"(?is)(?:wrong scope|tautological|existence-only).{0,240}(?:FIX|BLOCKED)",
        )

    def test_final_verdict_is_closed_and_residual_suggestions_are_separate(self) -> None:
        text = contract_text()
        self.assertRegex(text, r"(?i)closed (?:verdict|gate)|closed vocabulary")
        self.assertRegex(text, r"PASS\s*\|\s*FIX\s*\|\s*BLOCKED")
        self.assertRegex(
            text,
            r"(?is)(?:suggestions|optional improvements|residual work).{0,220}"
            r"(?:separate|not part of|do not change).{0,160}(?:verdict|PASS)",
        )


class SelectiveChallengeContractTests(unittest.TestCase):
    def test_challenge_lane_is_selective_read_only_and_non_authoritative(self) -> None:
        text = contract_text()
        self.assertRegex(text, r"(?i)selective (?:challenge|challenge lane)")
        self.assertRegex(
            text,
            r"(?is)(?:ordinary|standard|low-risk).{0,220}(?:zero|no).{0,120}challenge",
        )
        for trigger in (
            "high-consequence",
            "cross-module",
            "shared interface",
            "weak or conflicting evidence",
        ):
            self.assertIn(trigger, text)
        self.assertRegex(
            text,
            r"(?is)challenge.{0,300}(?:read-only|write_scope:\s*\[\]).{0,260}findings",
        )
        self.assertRegex(
            text,
            r"(?is)challenge.{0,280}(?:cannot|does not|must not).{0,180}"
            r"(?:approve|final verdict|final review)",
        )
        self.assertRegex(
            text,
            r"(?is)(?:at most|maximum of) one.{0,100}(?:challenge|challenger)",
        )

    def test_sol_remains_the_only_controller_and_final_reviewer(self) -> None:
        text = contract_text()
        self.assertRegex(text, r"(?i)Sol is the (?:single|only) controller")
        self.assertRegex(text, r"(?i)Sol.{0,180}(?:only|sole).{0,120}final reviewer")
        self.assertNotRegex(text, r"(?i)(?:second|another|fresh) Sol.{0,80}reviewer")


class RecoveryAndFailureContractTests(unittest.TestCase):
    def test_runtime_capability_does_not_silently_widen_authorization(self) -> None:
        text = contract_text()
        self.assertRegex(text, r"(?i)capability is not authorization")
        self.assertRegex(
            text,
            r"(?is)broader technical (?:access|capability).{0,260}"
            r"(?:does not|doesn't|never).{0,140}(?:widen|enlarge).{0,140}"
            r"(?:authorization|write_scope|scope)",
        )
        self.assertRegex(
            text,
            r"(?is)broader technical (?:access|capability).{0,420}"
            r"(?:baseline/final|before/after).{0,160}changed-path",
        )

    def test_irreversible_external_work_still_fails_closed_without_boundary(self) -> None:
        text = contract_text()
        self.assertRegex(
            text,
            r"(?is)(?:destructive|irreversible).{0,160}(?:production|external).{0,220}"
            r"(?:enforceable|enforced).{0,180}(?:boundary|approval)",
        )
        self.assertRegex(text, r"(?i)Fail Closed")

    def test_worker_identity_handshake_is_a_task_packet_exception(self) -> None:
        for path in AGENT_PATHS[1:]:
            with path.open("rb") as handle:
                worker = tomllib.load(handle)["developer_instructions"]
            self.assertRegex(worker, r"(?i)identity-only first-turn handshake")
            self.assertRegex(worker, r"(?i)(?:sole|only) exception")
            self.assertRegex(
                worker,
                r"(?is)handshake.{0,260}(?:do not|must not).{0,160}"
                r"(?:reject|BLOCKED).{0,180}(?:missing task fields|task-packet)",
            )

    def test_failure_taxonomy_distinguishes_timeout_and_evidence_quality(self) -> None:
        text = contract_text()
        allowed = (
            "runtime | timeout | model_identity | permission | dependency | scope | "
            "verification | evidence_quality | conflict | none"
        )
        self.assertIn(allowed, text)
        self.assertRegex(
            text,
            r"(?is)(?:silence|timeout).{0,220}(?:not|never).{0,160}(?:model capability|capability failure)",
        )

    def test_resume_packet_prevents_duplicate_work_and_retry_reset(self) -> None:
        text = contract_text()
        for field in (
            "run_id",
            "ownership",
            "requirement_coverage",
            "candidate_identity",
            "attempts",
        ):
            self.assertRegex(text, rf"(?is)Resume packet.{{0,700}}\b{field}\b")
        self.assertRegex(
            text,
            r"(?is)resume.{0,320}(?:must not|never).{0,120}(?:redispatch|relaunch|duplicate).{0,120}completed",
        )
        self.assertRegex(
            text,
            r"(?is)(?:attempt|retry).{0,160}(?:must not|does not|never).{0,120}reset",
        )
        self.assertRegex(
            text,
            r"(?is)candidate_identity.{0,220}(?:mismatch|changed).{0,200}(?:BLOCKED|re-plan|replan)",
        )

    def test_agent_instructions_carry_the_evidence_first_contract(self) -> None:
        with AGENT_PATHS[0].open("rb") as handle:
            sol = tomllib.load(handle)["developer_instructions"]
        for marker in (
            "Requirement IDs",
            "artifact-first",
            "verify the verifier",
            "selective challenge",
            "requirements_coverage",
        ):
            self.assertIn(marker, sol)

        for path in AGENT_PATHS[1:]:
            with path.open("rb") as handle:
                worker = tomllib.load(handle)["developer_instructions"]
            self.assertIn("Requirement IDs", worker, path.name)
            self.assertIn("Required evidence", worker, path.name)
            self.assertIn("Requirement coverage", worker, path.name)


class ForwardAndBenchmarkContractTests(unittest.TestCase):
    def test_powershell_uninstall_commits_before_backup_cleanup(self) -> None:
        script = read(ROOT / "scripts" / "uninstall.ps1")
        failpoint = script.index('"before-transaction-cleanup"')
        transaction_cleanup = script.index("Remove-Exact $transactionDir", failpoint)
        transaction_clear = script.index('$transactionDir = ""', transaction_cleanup)
        backup_cleanup = script.index("Remove-Exact $backupDir", transaction_clear)
        self.assertLess(failpoint, transaction_cleanup)
        self.assertLess(transaction_cleanup, transaction_clear)
        self.assertLess(transaction_clear, backup_cleanup)

        lifecycle = read(ROOT / "tests" / "windows-lifecycle.ps1")
        self.assertIn("Test-UninstallTransactionCleanupFailpoint", lifecycle)
        self.assertIn('"before-transaction-cleanup"', lifecycle)
        self.assertRegex(
            lifecycle,
            r"(?is)Test-UninstallTransactionCleanupFailpoint.{0,1200}"
            r"(?:backup|recovery).{0,400}(?:unchanged|changed|removed)",
        )

    def test_forward_fixture_covers_v050_evidence_failures(self) -> None:
        cases = json.loads(read(FORWARD_CASES))
        by_id = {case["id"]: case for case in cases}
        required = {
            "v050-requirement-evidence-gap",
            "v050-worker-pass-is-untrusted",
            "v050-wrong-scope-verifier",
            "v050-high-risk-selective-challenge",
            "v050-standard-task-no-challenge",
            "v050-resume-no-duplicate-dispatch",
            "v050-timeout-after-write-keeps-owner",
            "v050-residual-suggestions-do-not-change-pass",
        }
        self.assertTrue(required.issubset(by_id), sorted(required - set(by_id)))
        self.assertEqual(
            "required",
            by_id["v050-high-risk-selective-challenge"]["expected"]["challenge"],
        )
        self.assertEqual(
            "none",
            by_id["v050-standard-task-no-challenge"]["expected"]["challenge"],
        )

    def test_ab_benchmark_manifest_is_reproducible_and_claim_free(self) -> None:
        self.assertTrue(AB_MANIFEST.is_file(), AB_MANIFEST)
        self.assertTrue(AB_SCRIPT.is_file(), AB_SCRIPT)
        data = json.loads(read(AB_MANIFEST))
        self.assertEqual(1, data["schema_version"])
        self.assertEqual("protocol_only", data["evidence_class"])
        self.assertEqual({"baseline", "candidate"}, {arm["id"] for arm in data["arms"]})
        self.assertGreaterEqual(data["repetitions"], 3)
        self.assertTrue(data["counterbalanced_order"])
        self.assertTrue(data["fresh_isolated_checkout"])
        self.assertTrue(data["hidden_grader_after_run"])
        self.assertGreaterEqual(len(data["cases"]), 6)
        self.assertEqual(
            {
                "held_out_pass",
                "integrity_pass",
                "false_pass",
                "input_tokens",
                "output_tokens",
                "elapsed_seconds",
                "cost_value",
                "cost_unit",
                "subagent_count",
                "retry_count",
            },
            set(data["metrics"]),
        )
        self.assertNotIn("results", data)
        self.assertNotIn("winner", data)

    def test_both_validators_cover_the_ab_protocol_files(self) -> None:
        for path in (ROOT / "scripts" / "validate.sh", ROOT / "scripts" / "validate.ps1"):
            text = read(path)
            for marker in (
                "scripts/benchmark_ab.py",
                "tests/fixtures/v050-ab-benchmark.json",
                "tests/test_v050_benchmark.py",
                "tests/test_v050_evidence_control.py",
                "tests/v050-live-smoke.md",
                "SOL_CONTROL_V050_IMPLEMENTATION_REPORT.md",
            ):
                self.assertIn(marker, text, f"{path.name}: {marker}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
