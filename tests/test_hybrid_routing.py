#!/usr/bin/env python3
"""RED contracts for the Sol/Luna Max/Terra High routing tier.

These tests intentionally describe the next routing contract without importing
an implementation that does not exist yet.  They inspect the public Skill,
agent definitions, lifecycle sources, forward fixtures, and bilingual README
as users and lifecycle scripts observe them.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError as exc:  # pragma: no cover - old runner guard
    raise SystemExit("tests require Python 3.11+ for tomllib") from exc


ROOT = Path(__file__).resolve().parents[1]
SKILL_ROOT = ROOT / ".agents" / "skills" / "sol-control"
TERRA_AGENT = ROOT / ".codex" / "agents" / "terra-high-worker.toml"
FORWARD_CASES = ROOT / "tests" / "fixtures" / "forward-cases.json"
README_FILES = (ROOT / "README.md", ROOT / "README.en.md")
CONTRACT_DOCS = (
    SKILL_ROOT / "SKILL.md",
    SKILL_ROOT / "references" / "orchestration.md",
    SKILL_ROOT / "references" / "runtime-notes.md",
    ROOT / ".codex" / "agents" / "sol-controller.toml",
    ROOT / "README.md",
    ROOT / "README.en.md",
    ROOT / "SOL_CONTROL_IMPLEMENTATION_REPORT.md",
    ROOT / "tests" / "forward-tests.md",
)
POSIX_SCRIPTS = (
    ROOT / "scripts" / "install.sh",
    ROOT / "scripts" / "validate.sh",
    ROOT / "scripts" / "uninstall.sh",
)
POWERSHELL_SCRIPTS = (
    ROOT / "scripts" / "install.ps1",
    ROOT / "scripts" / "validate.ps1",
    ROOT / "scripts" / "uninstall.ps1",
    ROOT / "tests" / "windows-lifecycle.ps1",
)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def compact(text: str) -> str:
    """Normalize soft wrapping while retaining a bounded context window."""

    return re.sub(r"\s+", " ", text)


def require_pattern(test: unittest.TestCase, text: str, pattern: str, message: str) -> None:
    if not re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL):
        test.fail(message)


class TerraAgentContractTests(unittest.TestCase):
    def test_terra_worker_identity_and_parent_scoped_write_contract(self) -> None:
        self.assertTrue(TERRA_AGENT.is_file(), TERRA_AGENT)
        with TERRA_AGENT.open("rb") as handle:
            data = tomllib.load(handle)

        self.assertEqual("terra-high-worker", data.get("name"))
        self.assertEqual("gpt-5.6-terra", data.get("model"))
        self.assertEqual("high", data.get("model_reasoning_effort"))
        self.assertEqual("workspace-write", data.get("sandbox_mode"))

        instructions = data.get("developer_instructions")
        self.assertIsInstance(instructions, str)
        normalized = compact(instructions)
        self.assertRegex(
            normalized,
            r"(?i)(?:parent\s+permission\s+boundary|parent.{0,20}(?:permission|权限).{0,20}(?:boundary|边界))",
        )
        self.assertRegex(
            normalized,
            r"(?i)(?:exact|precise|精确).{0,30}(?:assigned\s+)?write[_ -]?scope",
        )
        self.assertRegex(
            normalized,
            r"(?is)(?:do not|must not).{0,100}(?:spawn|create).{0,100}subagents?",
        )
        self.assertRegex(
            normalized,
            r"(?i)(?:only|modify only).{0,120}(?:assigned|exact).{0,80}(?:files?|write scope)",
        )

    def test_skill_keeps_sol_as_only_controller_and_assigns_tiers_by_risk(self) -> None:
        skill_files = [path for path in SKILL_ROOT.rglob("*") if path.is_file()]
        self.assertTrue(skill_files, SKILL_ROOT)
        text = compact("\n".join(read_text(path) for path in skill_files))

        require_pattern(
            self,
            text,
            r"Sol.{0,220}(?:single\s+controller|only\s+controller|唯一主控)",
            "Skill must identify Sol as the only controller",
        )
        require_pattern(
            self,
            text,
            r"Sol.{0,420}(?:final\s+(?:review|approval)|终审|最终审核)",
            "Skill must identify Sol as final reviewer",
        )

        luna_markers = (
            r"(?i)Luna(?:\s+Max)?.{0,260}(?:clear|low[- ]?ambiguity|低歧义|明确)",
            r"(?i)Luna(?:\s+Max)?.{0,260}(?:falsifiable|可证伪|independently\s+verif)",
            r"(?i)Luna(?:\s+Max)?.{0,260}(?:small\s+context|小上下文|bounded\s+context)",
        )
        for marker in luna_markers:
            require_pattern(self, text, marker, f"Skill is missing Luna routing boundary: {marker}")

        terra_markers = (
            r"(?i)Terra(?:\s+High)?.{0,320}(?:cross[- ]module|跨模块)",
            r"(?i)Terra(?:\s+High)?.{0,320}(?:long[- ]?context|长上下文)",
            r"(?i)Terra(?:\s+High)?.{0,320}(?:ambiguous\s+debugging|模糊调试)",
            r"(?i)Terra(?:\s+High)?.{0,320}(?:shared\s+interface|共享接口)",
            r"(?i)Terra(?:\s+High)?.{0,320}(?:high[- ]risk\s+implementation|高风险实现)",
        )
        for marker in terra_markers:
            require_pattern(self, text, marker, f"Skill is missing Terra routing boundary: {marker}")

        require_pattern(
            self,
            text,
            r"(?:one\s+file|同一文件).{0,180}(?:one\s+owner|唯一 owner)",
            "Skill must enforce one file, one owner",
        )
        require_pattern(
            self,
            text,
            r"(?:Luna(?:\s+Max)?|Luna).{0,260}(?:first|首次|第一次).{0,120}(?:failure|失败).{0,260}"
            r"(?:Terra(?:\s+High)?|Terra|升级).{0,260}(?:infinite|unbounded|无限).{0,100}(?:retry|重试)",
            "Skill must escalate a misclassified Luna task to Terra without unbounded Luna retries",
        )

    def test_unprovable_model_identity_fails_closed_before_execution(self) -> None:
        skill_files = [path for path in SKILL_ROOT.rglob("*") if path.is_file()]
        text = compact("\n".join(read_text(path) for path in skill_files))
        self.assertRegex(text, r"(?i)Fail\s+Closed|失败关闭")
        self.assertRegex(
            text,
            r"(?is)(?:exact\s+model|model\s+identity|模型(?:身份|选择)).{0,240}"
            r"(?:cannot|unable|unprovable|无法|不可证明).{0,240}(?:blocked|fail\s+closed|关闭)",
        )
        self.assertRegex(
            text,
            r"(?is)identity(?:-only)?\s+handshake.{0,360}(?:no|without).{0,120}"
            r"(?:task execution|planning).{0,120}(?:write|writing)",
        )


class LifecycleContractTests(unittest.TestCase):
    def test_all_posix_and_powershell_surfaces_name_terra_and_its_checksum(self) -> None:
        for path in POSIX_SCRIPTS + POWERSHELL_SCRIPTS:
            text = read_text(path)
            self.assertTrue(text, path)
            require_pattern(self, text, r"terra[-_]high[-_]worker\.toml", f"{path.name}: missing Terra worker path")

        for path in (POSIX_SCRIPTS[0], POSIX_SCRIPTS[2], POWERSHELL_SCRIPTS[0], POWERSHELL_SCRIPTS[2]):
            text = read_text(path)
            require_pattern(self, text, r"terra[_-](?:sha256|checksum)|terra.{0,100}sha256", f"{path.name}: missing Terra checksum")
            text = read_text(path)
            require_pattern(self, text, r"backup|备份", f"{path.name}: missing backup path")
            require_pattern(self, text, r"install-state|RestoreLatest|restore", f"{path.name}: missing lifecycle state/restore")
        for path in (POSIX_SCRIPTS[1], POWERSHELL_SCRIPTS[1]):
            text = read_text(path)
            require_pattern(self, text, r"terra[-_]high[-_]worker\.toml", f"{path.name}: missing Terra worker path")
            require_pattern(self, text, r"gpt-5\.6-terra", f"{path.name}: missing Terra model")
            require_pattern(self, text, r"model_reasoning_effort|reasoning", f"{path.name}: missing reasoning validation")

    def test_windows_lifecycle_checks_terra_without_touching_user_config_or_agents(self) -> None:
        text = read_text(ROOT / "tests" / "windows-lifecycle.ps1")
        for marker in ("config.toml", "keep-me.toml", "SHA256", "RestoreLatest"):
            self.assertIn(marker, text, marker)
        require_pattern(self, text, r"terra[-_]high[-_]worker\.toml", "Windows lifecycle is missing Terra worker path")
        require_pattern(self, text, r"terra.{0,240}(?:backup|checksum|restore|uninstall)", "Windows lifecycle lacks Terra backup/checksum/restore coverage")
        require_pattern(self, text, r"(?:config\.toml|keep-me\.toml).{0,220}(?:preserv|unchanged|不变)", "Windows lifecycle lacks user-file preservation assertion")

    def test_posix_install_uninstall_round_trip_owns_terra_only(self) -> None:
        if os.name == "nt":
            self.skipTest("POSIX lifecycle test requires bash")

        with tempfile.TemporaryDirectory(prefix="sol-luna-terra-lifecycle.") as raw_home:
            home = Path(raw_home)
            config = home / ".codex" / "config.toml"
            unrelated = home / ".codex" / "agents" / "keep-me.toml"
            config.parent.mkdir(parents=True)
            unrelated.parent.mkdir(parents=True)
            config.write_text("model = 'user-owned'\n", encoding="utf-8")
            unrelated.write_text("name = 'unrelated-agent'\n", encoding="utf-8")
            before_config = config.read_bytes()
            before_unrelated = unrelated.read_bytes()

            env = os.environ.copy()
            env["ORCHESTRATE_HOME"] = str(home)
            env.pop("ORCHESTRATE_FAILPOINT", None)

            install = subprocess.run(
                ["bash", str(ROOT / "scripts" / "install.sh")],
                cwd=ROOT,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            self.assertEqual(0, install.returncode, install.stdout)

            terra = home / ".codex" / "agents" / "terra-high-worker.toml"
            state = home / ".codex" / "sol-control" / "install-state"
            self.assertTrue(terra.is_file(), "install must install Terra High")
            self.assertTrue(state.is_file(), state)
            state_text = state.read_text(encoding="utf-8")
            self.assertRegex(state_text, r"(?m)^terra_sha256=[0-9a-f]{64}$")
            backup_root = home / ".codex" / "sol-control" / "backups"
            manifests = sorted(backup_root.glob("*/manifest"))
            self.assertTrue(manifests, "install must retain a versioned backup manifest")
            manifest_text = manifests[-1].read_text(encoding="utf-8")
            self.assertRegex(manifest_text, r"(?i)terra.{0,100}(?:presence|sha256|checksum)")

            uninstall = subprocess.run(
                ["bash", str(ROOT / "scripts" / "uninstall.sh")],
                cwd=ROOT,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            self.assertEqual(0, uninstall.returncode, uninstall.stdout)
            self.assertFalse(terra.exists(), "uninstall must remove only the owned Terra target")
            self.assertEqual(before_config, config.read_bytes())
            self.assertEqual(before_unrelated, unrelated.read_bytes())

    def test_posix_existing_unowned_terra_fails_closed_without_user_file_changes(self) -> None:
        if os.name == "nt":
            self.skipTest("POSIX lifecycle test requires bash")

        with tempfile.TemporaryDirectory(prefix="sol-luna-terra-restore.") as raw_home:
            home = Path(raw_home)
            terra = home / ".codex" / "agents" / "terra-high-worker.toml"
            config = home / ".codex" / "config.toml"
            unrelated = home / ".codex" / "agents" / "keep-me.toml"
            terra.parent.mkdir(parents=True)
            terra.write_text("name = 'user-owned-terra'\n", encoding="utf-8")
            config.write_text("feature = 'keep'\n", encoding="utf-8")
            unrelated.write_text("name = 'unrelated-agent'\n", encoding="utf-8")
            original_terra = terra.read_bytes()
            original_config = config.read_bytes()
            original_unrelated = unrelated.read_bytes()

            env = os.environ.copy()
            env["ORCHESTRATE_HOME"] = str(home)
            env.pop("ORCHESTRATE_FAILPOINT", None)
            before = {
                str(path.relative_to(home)): path.read_bytes()
                for path in home.rglob("*")
                if path.is_file()
            }
            install = subprocess.run(
                ["bash", str(ROOT / "scripts" / "install.sh")],
                cwd=ROOT,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            self.assertNotEqual(0, install.returncode, install.stdout)
            after = {
                str(path.relative_to(home)): path.read_bytes()
                for path in home.rglob("*")
                if path.is_file()
            }
            self.assertEqual(before, after)
            self.assertEqual(original_terra, terra.read_bytes())
            self.assertEqual(original_config, config.read_bytes())
            self.assertEqual(original_unrelated, unrelated.read_bytes())


class ForwardCaseContractTests(unittest.TestCase):
    def load_cases(self) -> list[dict]:
        self.assertTrue(FORWARD_CASES.is_file(), FORWARD_CASES)
        data = json.loads(FORWARD_CASES.read_text(encoding="utf-8"))
        self.assertIsInstance(data, list)
        return data

    def test_forward_cases_cover_tiered_routes_and_safe_escalation(self) -> None:
        cases = self.load_cases()
        by_id = {case["id"]: case for case in cases}
        required = {
            "luna-low-ambiguity-small-context",
            "terra-cross-module-long-context",
            "model-identity-unavailable-fail-closed",
            "luna-classification-error-escalates-terra",
            "single-file-unique-owner",
        }
        self.assertTrue(required.issubset(by_id), sorted(required - set(by_id)))

        self.assertEqual("sol_then_luna", by_id["luna-low-ambiguity-small-context"]["expected"]["route"])
        self.assertEqual("sol_then_terra", by_id["terra-cross-module-long-context"]["expected"]["route"])
        self.assertEqual("blocked", by_id["model-identity-unavailable-fail-closed"]["expected"]["route"])
        self.assertEqual(
            "sol_then_terra",
            by_id["luna-classification-error-escalates-terra"]["expected"]["route"],
        )
        self.assertEqual("sol_then_terra", by_id["single-file-unique-owner"]["expected"]["route"])

        assertion_text = " ".join(
            assertion
            for case in by_id.values()
            for assertion in case.get("required_assertions", [])
        )
        self.assertRegex(assertion_text, r"(?i)low[- ]ambiguity|低歧义")
        self.assertRegex(assertion_text, r"(?i)cross[- ]module|跨模块")
        self.assertRegex(assertion_text, r"(?i)long[- ]?context|长上下文")
        self.assertRegex(assertion_text, r"(?i)fail[- ]?closed|失败关闭")
        self.assertRegex(assertion_text, r"(?i)model\s+(?:identity|selection)|模型(?:身份|选择)")
        self.assertRegex(assertion_text, r"(?i)classif(?:ication|y).{0,100}(?:Terra|terra|升级)")
        self.assertRegex(assertion_text, r"(?i)(?:not|no).{0,100}(?:infinite|unbounded).{0,100}Luna")
        self.assertRegex(assertion_text, r"(?i)one\s+owner|唯一 owner")

    def test_escalation_fixture_separates_zero_write_allow_from_written_file_forbid(self) -> None:
        cases = self.load_cases()
        by_id = {case["id"]: case for case in cases}
        required = {
            "luna-first-failure-before-write-escalates-terra",
            "luna-first-failure-after-write-keeps-luna-owner",
        }
        missing = required - set(by_id)
        if missing:
            self.fail(f"fixture is missing ownership-transfer scenarios: {sorted(missing)}")
        allow = by_id["luna-first-failure-before-write-escalates-terra"]
        forbid = by_id["luna-first-failure-after-write-keeps-luna-owner"]

        self.assertEqual("sol_then_terra", allow["expected"]["route"])
        self.assertEqual("required", allow["expected"]["terra"])
        self.assertEqual(0, allow["luna_state"]["owned_files_written_before_failure"])
        self.assertTrue(allow["luna_state"]["failed_before_owned_write"])
        self.assertEqual("same_task_same_scope_once", allow["expected"]["upgrade"])

        self.assertEqual("sol_then_luna", forbid["expected"]["route"])
        self.assertEqual("blocked", forbid["expected"]["terra"])
        self.assertEqual("luna_retains_scope", forbid["expected"]["ownership"])
        self.assertEqual(1, forbid["luna_state"]["owned_files_written_before_failure"])
        self.assertFalse(forbid["luna_state"]["failed_before_owned_write"])
        self.assertEqual("focused_fix_or_blocked", forbid["expected"]["correction"])

        assertion_text = " ".join(
            assertion
            for case in (allow, forbid)
            for assertion in case["required_assertions"]
        )
        self.assertRegex(assertion_text, r"(?i)(?:zero|no|without).{0,100}(?:owned )?file")
        self.assertRegex(assertion_text, r"(?i)Luna.{0,120}(?:retains?|keeps?).{0,120}ownership")
        self.assertRegex(assertion_text, r"(?i)Terra.{0,120}(?:blocked|not eligible|禁止)")


class OwnershipTransferContractTests(unittest.TestCase):
    def test_every_public_contract_surface_uses_luna_zero_write_gate(self) -> None:
        for path in CONTRACT_DOCS:
            text = compact(read_text(path))
            self.assertTrue(text, path)
            self.assertRegex(
                text,
                r"(?i)Luna.{0,220}(?:first|首次|第一次).{0,120}(?:failure|失败).{0,240}(?:"
                r"(?:before|without|prior to|在.{0,20}之前).{0,160}"
                r"(?:write|written|wrote|写入).{0,120}(?:owned file|owned-file|owned_file|文件)"
                r"|(?:write|written|wrote|写入).{0,120}(?:owned file|owned-file|owned_file|文件).{0,160}"
                r"(?:before|without|prior to|之前))",
                f"{path}: missing Luna-before-write escalation gate",
            )
            self.assertRegex(
                text,
                r"(?i)(?:Luna|露娜).{0,180}(?:writes?|wrote|written|写入).{0,180}"
                r"(?:owned file|owned-file|owned_file|文件).{0,240}"
                r"(?:retains?|keeps?|remains?|保留|继续持有).{0,180}"
                r"(?:ownership|owner|所有权|owner)",
                f"{path}: missing post-write ownership retention",
            )
            self.assertRegex(
                text,
                r"(?i)(?:Terra|泰拉).{0,220}(?:(?:not|never|不是|并非).{0,180}"
                r"(?:the )?(?:gate|threshold|门槛|条件).{0,220}(?:write|written|写入|owned)"
                r"|(?:write|written|写入|owned).{0,180}(?:not|never|不是|并非).{0,180}"
                r"(?:the )?(?:gate|threshold|门槛|条件))",
                f"{path}: must reject Terra-write state as the gate",
            )

    def test_contract_does_not_use_terra_write_state_as_escalation_gate(self) -> None:
        combined = compact("\n".join(read_text(path) for path in CONTRACT_DOCS))
        self.assertNotRegex(
            combined,
            r"(?i)Terra.{0,100}(?:may|can|only).{0,80}(?:receive|take|accept).{0,100}"
            r"(?:escalat|upgrade|handoff|转交).{0,180}(?:not|has not|未|没有).{0,100}"
            r"(?:written|write|写入).{0,100}(?:owned file|owned-file|owned_file|文件)",
        )


class ReadmeCostContractTests(unittest.TestCase):
    @staticmethod
    def nearby(text: str, label: str, radius: int = 360) -> str:
        normalized = compact(text)
        match = re.search(label, normalized, flags=re.IGNORECASE)
        if not match:
            return ""
        return normalized[max(0, match.start() - radius) : match.end() + radius]

    @staticmethod
    def nearby_windows(text: str, label: str, radius: int = 360) -> list[str]:
        normalized = compact(text)
        return [
            normalized[max(0, match.start() - radius) : match.end() + radius]
            for match in re.finditer(label, normalized, flags=re.IGNORECASE)
        ]

    def test_bilingual_readmes_publish_current_relative_tier_quotas(self) -> None:
        for path in README_FILES:
            text = read_text(path)
            self.assertTrue(text, path)
            for label, value in (
                (r"(?:Sol|索尔)", r"1(?:\.0+)?"),
                (r"(?:Terra(?:\s+High)?|Terra 高)", r"0\.4(?:0+)?"),
                (r"(?:Luna(?:\s+Max)?|Luna 高)", r"0\.04(?:0+)?"),
            ):
                windows = self.nearby_windows(text, label)
                self.assertTrue(windows, f"{path.name}: missing relative quota label {label}")
                quota_pattern = rf"(?<![\d.]){value}(?![\d.])\s*(?:x|×|倍|relative|相对)?"
                self.assertTrue(
                    any(re.search(quota_pattern, window, flags=re.IGNORECASE) for window in windows),
                    f"{path.name}: wrong relative quota for {label}",
                )

    def test_bilingual_readmes_publish_current_savings_ranges_not_old_direct_claims(self) -> None:
        required_ranges = (
            (r"(?:ordinary|typical|普通)", r"72\s*%.*76\s*%"),
            (r"(?:mixed|hybrid|混合)", r"50\s*%.*60\s*%"),
            (r"(?:complex|复杂)", r"33\s*%.*43\s*%"),
        )
        unsafe_legacy_markers = re.compile(
            r"(?i)(?:historical|legacy|prior|previous|not\s+current|"
            r"condition(?:ed|al|-based)|reliability[- ]gated|"
            r"历史|旧口径|旧基准|非现行|条件(?:下|性)|可靠性门槛)"
        )

        for path in README_FILES:
            text = read_text(path)
            normalized = compact(text)
            for label, value_pattern in required_ranges:
                windows = self.nearby_windows(normalized, label)
                self.assertTrue(windows, f"{path.name}: missing range label {label}")
                self.assertTrue(
                    any(re.search(value_pattern, window, flags=re.IGNORECASE) for window in windows),
                    f"{path.name}: missing current range for {label}",
                )

            for match in re.finditer(r"65\s*%", normalized):
                window = normalized[max(0, match.start() - 240) : match.end() + 240]
                if re.search(r"(?i)complex|复杂", window):
                    self.assertRegex(
                        window,
                        unsafe_legacy_markers,
                        f"{path.name}: complex 65% must not be an unqualified current direct saving",
                    )
            for match in re.finditer(r"1\s*/\s*25", normalized):
                window = normalized[max(0, match.start() - 220) : match.end() + 220]
                self.assertRegex(
                    window,
                    unsafe_legacy_markers,
                    f"{path.name}: Luna=Sol 1/25 must be historical/non-current if retained",
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
