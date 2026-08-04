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
ALLOWED_EVIDENCE = {"measured", "scenario_model_projection", "unavailable"}
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

    def test_current_relative_weights_and_saving_ranges_are_scenario_model_projections(self) -> None:
        cost = self.load_fixture()["cost"]
        expected = {
            "sol_relative_credit_weight": 1.0,
            "terra_relative_credit_weight": 0.4,
            "luna_relative_credit_weight": 0.04,
            "ordinary_saving_min_percent": 72.2,
            "ordinary_saving_max_percent": 76.2,
            "mixed_saving_min_percent": 50.4,
            "mixed_saving_max_percent": 60.4,
            "complex_direct_saving_min_percent": 33.4,
            "complex_direct_saving_max_percent": 43.4,
            "composite_center_percent": 56,
        }
        for key, value in expected.items():
            self.assertEqual(value, cost[key]["value"])
            self.assertEqual("scenario_model_projection", cost[key]["evidence"])

    def test_current_ranges_do_not_retain_old_complex_direct_claim(self) -> None:
        cost = self.load_fixture()["cost"]
        self.assertNotIn("reliability_gated_complex_saving_percent", cost)
        self.assertNotIn("post_gate_cost_percent", cost)
        self.assertLessEqual(
            cost["complex_direct_saving_max_percent"]["value"],
            43.4,
        )

    def test_report_and_readmes_publish_their_documented_evidence_boundaries(self) -> None:
        self.assertTrue(REPORT.is_file(), REPORT)
        report = REPORT.read_text(encoding="utf-8")
        for signal in (
            "measured",
            "scenario_model_projection",
            "unavailable",
            "72%-76%",
            "50%-60%",
            "33%-43%",
            "56%",
            "Sol = **1**",
            "Terra High = **0.4**",
            "Luna Max",
            "0.04",
        ):
            self.assertIn(signal, report)
        historical_markers = re.compile(
            r"(?i)(?:historical|legacy|prior|previous|not\s+(?:the\s+)?current|"
            r"历史|旧口径|旧基准|非现行|当前公共契约|current\s+public\s+contract)"
        )
        for match in re.finditer(r"(?i)(?:complex|复杂).{0,140}65%", report):
            window = report[max(0, match.start() - 120) : match.end() + 180]
            self.assertRegex(window, historical_markers)
        for match in re.finditer(r"1\s*/\s*25", report):
            window = report[max(0, match.start() - 120) : match.end() + 180]
            self.assertRegex(window, historical_markers)
        for path in README_FILES:
            text = path.read_text(encoding="utf-8")
            for signal in ("72%", "76%", "50%", "60%", "33%", "43%", "0.4", "0.04"):
                self.assertIn(signal, text, path.name)
            self.assertIn("scenario_model_projection", text, path.name)
            self.assertRegex(text, r"(?i)not matched A/B|不是匹配 A/B")
            self.assertNotRegex(text, r"(?i)(?:complex|复杂).{0,160}65%")
            self.assertNotRegex(text, r"1\s*/\s*25")
            self.assertNotIn("sample_validated_projection", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
