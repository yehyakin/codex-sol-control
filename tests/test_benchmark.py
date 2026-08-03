#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests" / "fixtures" / "real-project-benchmark.json"
REPORT = ROOT / "tests" / "real-project-benchmark.md"
README_FILES = (ROOT / "README.md", ROOT / "README.en.md")
BENCHMARK_DOCUMENTS = README_FILES + (
    REPORT,
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "2026-08-02-chinese-cost-first-real-project-benchmark-design.md",
    ROOT
    / "docs"
    / "superpowers"
    / "plans"
    / "2026-08-02-chinese-cost-first-real-project-benchmark.md",
)
ALLOWED_EVIDENCE = {"measured", "sample_validated_projection", "unavailable"}
EXPECTED_CATEGORIES = {"codebase", "documentation", "infrastructure"}
PRIVATE_PATH_RE = re.compile(
    r"(?:/Users/[A-Za-z0-9._-]+/|"
    r"[A-Za-z]:[\\/]Users[\\/][A-Za-z0-9._-]+[\\/])"
)


class RealProjectBenchmarkTests(unittest.TestCase):
    def load_fixture(self) -> dict:
        self.assertTrue(FIXTURE.is_file(), FIXTURE)
        return json.loads(FIXTURE.read_text(encoding="utf-8"))

    def test_fixture_has_three_anonymous_categories(self) -> None:
        data = self.load_fixture()
        categories = data["categories"]
        self.assertEqual(EXPECTED_CATEGORIES, {item["id"] for item in categories})
        self.assertTrue(all(item["sample_count"] >= 1 for item in categories))

    def test_every_metric_declares_a_valid_evidence_class(self) -> None:
        data = self.load_fixture()
        metrics = list(data["cost"].values())
        for category in data["categories"]:
            metrics.extend(category["metrics"].values())
        for metric in metrics:
            self.assertIn(metric["evidence"], ALLOWED_EVIDENCE)
            if metric["evidence"] == "unavailable":
                self.assertIsNone(metric["value"])

    def test_public_artifacts_contain_no_private_paths_or_source_identity_fields(self) -> None:
        data = self.load_fixture()
        texts = [json.dumps(data, ensure_ascii=False)]
        for path in BENCHMARK_DOCUMENTS:
            self.assertTrue(path.is_file(), path)
            texts.append(path.read_text(encoding="utf-8"))
        combined = "\n".join(texts)
        self.assertNotRegex(combined, PRIVATE_PATH_RE)
        forbidden_keys = {
            "project_name",
            "project_path",
            "repository_url",
            "thread_id",
            "prompt",
        }
        serialized_keys: set[str] = set()

        def collect_keys(value: object) -> None:
            if isinstance(value, dict):
                serialized_keys.update(value)
                for child in value.values():
                    collect_keys(child)
            elif isinstance(value, list):
                for child in value:
                    collect_keys(child)

        collect_keys(data)
        self.assertTrue(forbidden_keys.isdisjoint(serialized_keys))

    def test_projection_prices_are_complete_and_sample_validated(self) -> None:
        cost = self.load_fixture()["cost"]
        expected = {
            "typical_workflow_saving_percent": 59,
            "reliability_gated_complex_saving_percent": 65,
            "all_sol_reference_dollars": 8.00,
            "routed_reference_dollars": 3.30,
            "all_sol_reference_credits": 200,
            "routed_reference_credits": 82.4,
        }
        for key, value in expected.items():
            self.assertEqual(value, cost[key]["value"])
            self.assertEqual("sample_validated_projection", cost[key]["evidence"])

    def test_reliability_gated_cost_claim_is_sample_validated(self) -> None:
        cost = self.load_fixture()["cost"]
        reliability = cost["reliability_gated_complex_saving_percent"]
        self.assertEqual(65, reliability["value"])
        self.assertEqual("sample_validated_projection", reliability["evidence"])
        self.assertEqual(41, cost["remaining_cost_after_typical_saving_percent"]["value"])
        self.assertEqual(15, cost["avoided_invalid_rework_percent"]["value"])
        self.assertEqual(34.85, cost["post_gate_cost_percent"]["value"])
        self.assertEqual(
            "sample_validated_projection",
            cost["post_gate_cost_percent"]["evidence"],
        )

    def test_report_and_readmes_publish_the_same_evidence_boundary(self) -> None:
        self.assertTrue(REPORT.is_file(), REPORT)
        report = REPORT.read_text(encoding="utf-8")
        for signal in (
            "measured",
            "sample_validated_projection",
            "unavailable",
            "59%",
            "65%",
            "34.85%",
            "$8.00",
            "$3.30",
            "200",
            "82.4",
        ):
            self.assertIn(signal, report)
        self.assertNotRegex(report, r"(?i)not measured|非实测")
        for path in README_FILES:
            text = path.read_text(encoding="utf-8")
            for signal in ("59%", "65%", "34.85%", "$8.00", "$3.30", "200", "82.4"):
                self.assertIn(signal, text, path.name)
            self.assertRegex(text, r"(?i)measured|实测")
            self.assertRegex(text, r"(?i)sample.validated|样本验证")
            self.assertRegex(text, r"(?i)unavailable|不可得")
            self.assertNotRegex(text, r"(?i)not measured|非实测")


if __name__ == "__main__":
    unittest.main(verbosity=2)
