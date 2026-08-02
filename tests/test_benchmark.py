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
ALLOWED_EVIDENCE = {"measured", "estimated", "unavailable"}
EXPECTED_CATEGORIES = {"codebase", "documentation", "infrastructure"}
PRIVATE_PATH_RE = re.compile(r"(?:/Users/|[A-Za-z]:[\\/]Users[\\/])")


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
        if REPORT.is_file():
            texts.append(REPORT.read_text(encoding="utf-8"))
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

    def test_measured_cost_requires_exact_usage_evidence(self) -> None:
        cost = self.load_fixture()["cost"]
        measured = cost["measured_workflow_saving_percent"]
        exact_usage = cost["exact_per_model_usage_available"]
        if measured["evidence"] == "measured":
            self.assertIs(exact_usage["value"], True)
            self.assertEqual("measured", exact_usage["evidence"])
        else:
            self.assertIsNone(measured["value"])

    def test_report_and_readmes_publish_the_same_evidence_boundary(self) -> None:
        self.assertTrue(REPORT.is_file(), REPORT)
        report = REPORT.read_text(encoding="utf-8")
        for signal in ("measured", "estimated", "unavailable", "59%"):
            self.assertIn(signal, report)
        for path in README_FILES:
            text = path.read_text(encoding="utf-8")
            self.assertIn("59%", text, path.name)
            self.assertRegex(text, r"(?i)measured|实测")
            self.assertRegex(text, r"(?i)estimated|估算")
            self.assertRegex(text, r"(?i)unavailable|不可得")


if __name__ == "__main__":
    unittest.main(verbosity=2)
