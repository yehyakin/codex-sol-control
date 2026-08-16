#!/usr/bin/env python3
"""Deterministic tests for the matched A/B evidence harness."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "benchmark_ab.py"
MANIFEST = ROOT / "tests" / "fixtures" / "v050-ab-benchmark.json"


def load_module():
    spec = importlib.util.spec_from_file_location("benchmark_ab", SCRIPT)
    if spec is None or spec.loader is None:  # pragma: no cover - import guard
        raise RuntimeError("cannot load benchmark_ab.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BenchmarkABTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_module()
        cls.manifest = cls.module.validate_manifest(json.loads(MANIFEST.read_text(encoding="utf-8")))
        cls.schedule = cls.module.make_schedule(cls.manifest)

    def make_results(self) -> dict:
        cells = []
        for cell in self.schedule["cells"]:
            cells.append(
                {
                    "case_id": cell["case_id"],
                    "arm": cell["arm"],
                    "repetition": cell["repetition"],
                    "base_commit": "a" * 40,
                    "prompt_sha256": "b" * 64,
                    "grader_sha256": "c" * 64,
                    "candidate_identity": "d" * 64,
                    "held_out_pass": cell["arm"] == "candidate",
                    "integrity_pass": True,
                    "false_pass": cell["arm"] == "baseline",
                    "input_tokens": 100 if cell["arm"] == "baseline" else 80,
                    "output_tokens": 20,
                    "elapsed_seconds": 10.0 if cell["arm"] == "baseline" else 9.0,
                    "cost_value": 1.0 if cell["arm"] == "baseline" else 0.8,
                    "cost_unit": "credits",
                    "subagent_count": 1,
                    "retry_count": 0,
                }
            )
        return {
            "schema_version": 1,
            "evidence_class": "measured_ab_cells",
            "manifest_sha256": self.schedule["manifest_sha256"],
            "cells": cells,
        }

    def test_schedule_is_complete_unique_and_counterbalanced(self) -> None:
        cells = self.schedule["cells"]
        expected = len(self.manifest["cases"]) * len(self.manifest["arms"]) * self.manifest["repetitions"]
        self.assertEqual(expected, len(cells))
        keys = {(cell["case_id"], cell["arm"], cell["repetition"]) for cell in cells}
        self.assertEqual(expected, len(keys))

        first_arm_by_case_and_rep = {
            (cell["case_id"], cell["repetition"]): cell["arm"]
            for cell in cells
            if cell["order"] == 1
        }
        for case in self.manifest["cases"]:
            observed = {
                first_arm_by_case_and_rep[(case["id"], repetition)]
                for repetition in range(1, self.manifest["repetitions"] + 1)
            }
            self.assertEqual({"baseline", "candidate"}, observed)

    def test_summary_reports_both_arms_without_declaring_a_winner(self) -> None:
        rows = self.module.validate_results(self.manifest, self.schedule, self.make_results())
        summary = self.module.summarize(self.manifest, rows)
        self.assertIsNone(summary["winner"])
        self.assertEqual(0.0, summary["arms"]["baseline"]["held_out_pass_rate"])
        self.assertEqual(1.0, summary["arms"]["candidate"]["held_out_pass_rate"])
        self.assertEqual(1.0, summary["arms"]["baseline"]["false_pass_rate"])
        self.assertEqual(0.0, summary["arms"]["candidate"]["false_pass_rate"])
        self.assertLess(
            summary["arms"]["candidate"]["input_tokens_total"],
            summary["arms"]["baseline"]["input_tokens_total"],
        )

    def test_incomplete_cells_fail_closed(self) -> None:
        results = self.make_results()
        results["cells"].pop()
        with self.assertRaisesRegex(self.module.ContractError, "missing 1 scheduled result cells"):
            self.module.validate_results(self.manifest, self.schedule, results)

    def test_cli_validate_emits_frozen_manifest_hash(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sol-control-ab.") as raw:
            output = Path(raw) / "validation.json"
            run = subprocess.run(
                [str(SCRIPT), "validate", str(MANIFEST), "--output", str(output)],
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            self.assertEqual(0, run.returncode, run.stdout)
            data = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual("PASS", data["status"])
            self.assertEqual(self.schedule["manifest_sha256"], data["manifest_sha256"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
