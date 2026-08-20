#!/usr/bin/env python3
"""Validate, schedule, and summarize matched Codex PROVE A/B runs.

This tool never launches a model. It freezes the experiment shape and rejects
incomplete or incomparable result cells before computing descriptive metrics.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


EXPECTED_METRICS = {
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
}
ARM_IDS = ("baseline", "candidate")


class ContractError(ValueError):
    """Raised when benchmark evidence is incomplete or incomparable."""


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractError(f"cannot read JSON {path}: {exc}") from exc


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def sha256(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def validate_manifest(data: Any) -> dict[str, Any]:
    require(isinstance(data, dict), "manifest must be an object")
    require(data.get("schema_version") == 1, "unsupported manifest schema")
    require(data.get("evidence_class") == "protocol_only", "manifest must be protocol_only")
    require(data.get("counterbalanced_order") is True, "counterbalanced_order must be true")
    require(data.get("fresh_isolated_checkout") is True, "fresh checkout isolation is required")
    require(data.get("hidden_grader_after_run") is True, "hidden post-run graders are required")

    repetitions = data.get("repetitions")
    require(isinstance(repetitions, int) and repetitions >= 3, "repetitions must be >= 3")

    arms = data.get("arms")
    require(isinstance(arms, list), "arms must be a list")
    arm_ids = [arm.get("id") for arm in arms if isinstance(arm, dict)]
    require(tuple(arm_ids) == ARM_IDS, "arms must be baseline then candidate")

    cases = data.get("cases")
    require(isinstance(cases, list) and len(cases) >= 6, "at least six cases are required")
    case_ids = [case.get("id") for case in cases if isinstance(case, dict)]
    require(len(case_ids) == len(cases), "every case must be an object with an id")
    require(all(isinstance(case_id, str) and case_id for case_id in case_ids), "case ids must be non-empty")
    require(len(set(case_ids)) == len(case_ids), "case ids must be unique")
    require(
        all(isinstance(case.get("forward_case_id"), str) and case["forward_case_id"] for case in cases),
        "every case must reference a forward_case_id",
    )

    metrics = data.get("metrics")
    require(isinstance(metrics, list), "metrics must be a list")
    require(set(metrics) == EXPECTED_METRICS, "manifest metrics do not match the required set")
    require("results" not in data and "winner" not in data, "protocol manifest cannot contain results or a winner")
    return data


def make_schedule(manifest: dict[str, Any]) -> dict[str, Any]:
    cells: list[dict[str, Any]] = []
    for repetition in range(1, manifest["repetitions"] + 1):
        for case_index, case in enumerate(manifest["cases"]):
            arm_order = list(ARM_IDS)
            if (case_index + repetition) % 2:
                arm_order.reverse()
            for order, arm in enumerate(arm_order, start=1):
                cells.append(
                    {
                        "case_id": case["id"],
                        "arm": arm,
                        "repetition": repetition,
                        "order": order,
                    }
                )
    return {
        "schema_version": 1,
        "evidence_class": "protocol_schedule",
        "manifest_sha256": sha256(manifest),
        "cells": cells,
    }


def validate_metric_value(name: str, value: Any) -> None:
    if name in {"held_out_pass", "integrity_pass", "false_pass"}:
        require(isinstance(value, bool), f"{name} must be boolean")
    elif name in {"input_tokens", "output_tokens", "subagent_count", "retry_count"}:
        require(isinstance(value, int) and not isinstance(value, bool) and value >= 0, f"{name} must be a non-negative integer")
    elif name == "elapsed_seconds":
        require(isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0, "elapsed_seconds must be non-negative")
    elif name == "cost_value":
        require(value is None or (isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0), "cost_value must be non-negative or null")
    elif name == "cost_unit":
        require(value is None or (isinstance(value, str) and value.strip()), "cost_unit must be a non-empty string or null")


def validate_results(
    manifest: dict[str, Any], schedule: dict[str, Any], data: Any
) -> list[dict[str, Any]]:
    require(isinstance(data, dict), "results must be an object")
    require(data.get("schema_version") == 1, "unsupported results schema")
    require(data.get("evidence_class") == "measured_ab_cells", "results must be measured_ab_cells")
    require(data.get("manifest_sha256") == schedule["manifest_sha256"], "results use a different manifest")
    rows = data.get("cells")
    require(isinstance(rows, list), "results cells must be a list")

    scheduled = {
        (cell["case_id"], cell["arm"], cell["repetition"])
        for cell in schedule["cells"]
    }
    observed: set[tuple[str, str, int]] = set()
    for row in rows:
        require(isinstance(row, dict), "each result cell must be an object")
        key = (row.get("case_id"), row.get("arm"), row.get("repetition"))
        require(key in scheduled, f"unexpected result cell: {key}")
        require(key not in observed, f"duplicate result cell: {key}")
        observed.add(key)
        for proof in ("base_commit", "prompt_sha256", "grader_sha256", "candidate_identity"):
            require(isinstance(row.get(proof), str) and row[proof].strip(), f"{proof} is required for {key}")
        for metric in manifest["metrics"]:
            require(metric in row, f"missing {metric} for {key}")
            validate_metric_value(metric, row[metric])
        require(
            (row["cost_value"] is None) == (row["cost_unit"] is None),
            f"cost_value and cost_unit must both be set or both null for {key}",
        )

    missing = scheduled - observed
    require(not missing, f"missing {len(missing)} scheduled result cells")
    return rows


def rate(rows: list[dict[str, Any]], field: str) -> float:
    return round(sum(1 for row in rows if row[field]) / len(rows), 6)


def summarize(manifest: dict[str, Any], rows: list[dict[str, Any]]) -> dict[str, Any]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[row["arm"]].append(row)

    arms: dict[str, Any] = {}
    for arm in ARM_IDS:
        arm_rows = grouped[arm]
        units = {row["cost_unit"] for row in arm_rows if row["cost_unit"] is not None}
        require(len(units) <= 1, f"mixed cost units for {arm}: {sorted(units)}")
        unit = next(iter(units), None)
        arms[arm] = {
            "runs": len(arm_rows),
            "held_out_pass_rate": rate(arm_rows, "held_out_pass"),
            "integrity_pass_rate": rate(arm_rows, "integrity_pass"),
            "false_pass_rate": rate(arm_rows, "false_pass"),
            "input_tokens_total": sum(row["input_tokens"] for row in arm_rows),
            "output_tokens_total": sum(row["output_tokens"] for row in arm_rows),
            "elapsed_seconds_total": round(sum(row["elapsed_seconds"] for row in arm_rows), 6),
            "elapsed_seconds_median": round(statistics.median(row["elapsed_seconds"] for row in arm_rows), 6),
            "cost_value_total": (
                round(sum(row["cost_value"] for row in arm_rows), 6) if unit is not None else None
            ),
            "cost_unit": unit,
            "subagent_count_total": sum(row["subagent_count"] for row in arm_rows),
            "retry_count_total": sum(row["retry_count"] for row in arm_rows),
        }

    return {
        "schema_version": 1,
        "evidence_class": "measured_ab_summary",
        "manifest_sha256": sha256(manifest),
        "arms": arms,
        "winner": None,
        "note": "Descriptive metrics only; apply the declared acceptance thresholds separately.",
    }


def write_json(value: Any, output: Path | None) -> None:
    rendered = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if output is None:
        sys.stdout.write(rendered)
    else:
        output.write_text(rendered, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("validate", "schedule"):
        child = sub.add_parser(command)
        child.add_argument("manifest", type=Path)
        child.add_argument("--output", type=Path)
    summary = sub.add_parser("summarize")
    summary.add_argument("manifest", type=Path)
    summary.add_argument("results", type=Path)
    summary.add_argument("--output", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifest = validate_manifest(load_json(args.manifest))
        if args.command == "validate":
            write_json(
                {
                    "status": "PASS",
                    "manifest_sha256": sha256(manifest),
                    "scheduled_cells": len(make_schedule(manifest)["cells"]),
                },
                args.output,
            )
        elif args.command == "schedule":
            write_json(make_schedule(manifest), args.output)
        else:
            schedule = make_schedule(manifest)
            rows = validate_results(manifest, schedule, load_json(args.results))
            write_json(summarize(manifest, rows), args.output)
    except ContractError as exc:
        print(f"benchmark_ab.py: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
