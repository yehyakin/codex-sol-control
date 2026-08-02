#!/usr/bin/env python3
"""RED contract tests for the v0.3.0 bilingual documentation surface."""

from __future__ import annotations

import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
CHINESE_README = ROOT / "README.md"
ENGLISH_README = ROOT / "README.en.md"
README_FILES = (CHINESE_README, ENGLISH_README)
SVG_FILES = (
    ROOT / "docs" / "assets" / "sol-luna-hero.svg",
    ROOT / "docs" / "assets" / "sol-luna-architecture.svg",
)
CANONICAL_REPOSITORY_URL = "https://github.com/yehyakin/codex-sol-luna"
OLD_REPOSITORY_URL = "https://github.com/yehyakin/codex-sol-luna-orchestrator"

MARKDOWN_LINK_RE = re.compile(
    r"!?\[[^\]]*\]\((?:<(?P<bracketed>[^>]+)>|(?P<plain>[^\s)]+))"
)
MARKDOWN_IMAGE_RE = re.compile(
    r"!\[(?P<alt>[^\]]+)\]\((?:<(?P<bracketed>[^>]+)>|(?P<plain>[^\s)]+))"
)
HEADING_RE = re.compile(r"(?im)^#{1,6}\s+(?P<title>.+?)\s*$")

SECTION_HEADING_PATTERNS = (
    ("headline_cost", re.compile(r"(?i)estimated\s+cost\s+saving|成本约节省")),
    ("architecture", re.compile(r"(?i)architecture|架构")),
    (
        "use",
        re.compile(
            r"(?i)when\s+to\s+use|when\s+not\s+to\s+use|use\s*/?\s*not|use\s+cases|"
            r"使用场景|何时使用|不使用"
        ),
    ),
    ("platform", re.compile(r"(?i)platform|quickstart|平台|快速开始|快速入门")),
    (
        "reliability",
        re.compile(r"(?i)reliab|identity|ownership|evidence|correction|可靠|身份|所有权|证据|修正"),
    ),
    ("benchmark", re.compile(r"(?i)real[- ]project\s+benchmark|真实项目基准")),
    ("cost_details", re.compile(r"(?i)cost\s+model|pricing\s+snapshot|成本模型|价格快照")),
    (
        "repository",
        re.compile(
            r"(?i)repository\s+(?:layout|structure)|testing|limitations?|prior\s+art|license|"
            r"仓库(?:布局|结构)|测试|限制|先例|许可证|许可"
        ),
    ),
)

API_RATES = {
    "GPT-5.6 Sol": ("$5.00", "$0.50", "$6.25", "$30.00"),
    "GPT-5.6 Luna": ("$0.20", "$0.02", "$0.25", "$1.20"),
}
CHATGPT_RATES = {
    "GPT-5.6 Sol": ("125", "12.5", "750"),
    "GPT-5.6 Luna": ("5", "0.5", "30"),
}
SCENARIOS = (
    (("Conservative", "保守"), ("50%", "125%", "10%", "38%")),
    (("Typical", "典型"), ("70%", "115%", "8%", "59%")),
    (("Execution-heavy", "执行密集型", "执行偏重"), ("85%", "110%", "7%", "74%")),
)


class ReadmeContractTests(unittest.TestCase):
    def readme_documents(self) -> dict[Path, str]:
        missing = [str(path.relative_to(ROOT)) for path in README_FILES if not path.is_file()]
        self.assertEqual([], missing, "missing bilingual README file(s)")
        return {path: path.read_text(encoding="utf-8") for path in README_FILES}

    def require_svg_files(self) -> None:
        missing = [str(path.relative_to(ROOT)) for path in SVG_FILES if not path.is_file()]
        self.assertEqual([], missing, "missing repository-owned SVG asset(s)")

    def test_both_complete_readmes_exist_and_start_with_language_switches(self) -> None:
        documents = self.readme_documents()
        chinese_head = "\n".join(documents[CHINESE_README].splitlines()[:24])
        english_head = "\n".join(documents[ENGLISH_README].splitlines()[:24])

        self.assertRegex(chinese_head, r"\[简体中文\]\(README\.md\)")
        self.assertRegex(chinese_head, r"\[English\]\(README\.en\.md\)")
        self.assertRegex(english_head, r"\[简体中文\]\(README\.md\)")
        self.assertRegex(english_head, r"\[English\]\(README\.en\.md\)")

    def test_chinese_readme_is_cost_first(self) -> None:
        text = CHINESE_README.read_text(encoding="utf-8")
        first_screen = "\n".join(text.splitlines()[:48])
        self.assertIn("成本约节省 59%", first_screen)
        self.assertRegex(first_screen, r"保守.{0,20}38%")
        self.assertRegex(first_screen, r"执行密集.{0,20}74%")
        self.assertRegex(first_screen, r"估算|不是.{0,20}保证")
        self.assertLess(text.index("成本约节省 59%"), text.index("## 架构"))

    def test_readmes_use_the_canonical_repository_name(self) -> None:
        documents = self.readme_documents()
        for path, text in documents.items():
            self.assertIn(CANONICAL_REPOSITORY_URL, text, path.name)
            self.assertNotIn(OLD_REPOSITORY_URL, text, path.name)
            self.assertIn("codex-sol-luna", text, path.name)

    def test_readmes_have_local_accessible_hero_and_architecture_images(self) -> None:
        documents = self.readme_documents()
        expected_targets = {
            "docs/assets/sol-luna-hero.svg",
            "docs/assets/sol-luna-architecture.svg",
        }
        for path, text in documents.items():
            image_targets = set()
            for match in MARKDOWN_IMAGE_RE.finditer(text):
                target = match.group("bracketed") or match.group("plain")
                parsed = urlsplit(target)
                self.assertFalse(
                    parsed.scheme or parsed.netloc,
                    f"{path.name}: README image must be repository-local: {target}",
                )
                image_targets.add(target.split("#", 1)[0])
                self.assertTrue(match.group("alt").strip(), f"{path.name}: empty image alt text")
            self.assertTrue(expected_targets.issubset(image_targets), path.name)

    def test_all_relative_markdown_links_resolve_inside_the_repository(self) -> None:
        documents = self.readme_documents()
        root = ROOT.resolve()
        for path, text in documents.items():
            links = list(MARKDOWN_LINK_RE.finditer(text))
            self.assertTrue(links, f"{path.name}: no Markdown links found")
            for match in links:
                raw_target = match.group("bracketed") or match.group("plain")
                parsed = urlsplit(raw_target)
                if parsed.scheme or parsed.netloc or raw_target.startswith("#"):
                    continue
                relative_target = unquote(parsed.path)
                if not relative_target:
                    continue
                target = (path.parent / relative_target).resolve()
                try:
                    target.relative_to(root)
                except ValueError:
                    self.fail(f"{path.name}: relative link escapes repository: {raw_target}")
                self.assertTrue(target.is_file(), f"{path.name}: broken relative link: {raw_target}")

    def test_svg_assets_are_well_formed_local_and_accessible(self) -> None:
        self.require_svg_files()
        for path in SVG_FILES:
            try:
                root = ET.parse(path).getroot()
            except (ET.ParseError, OSError) as exc:
                self.fail(f"{path.relative_to(ROOT)} is not parseable SVG: {exc}")
            self.assertEqual("svg", root.tag.rsplit("}", 1)[-1], path.name)
            self.assertIn("viewBox", root.attrib, path.name)
            title = root.find(".//{http://www.w3.org/2000/svg}title")
            if title is None:
                title = root.find(".//title")
            description = root.find(".//{http://www.w3.org/2000/svg}desc")
            if description is None:
                description = root.find(".//desc")
            self.assertIsNotNone(title, f"{path.name}: missing SVG title")
            self.assertIsNotNone(description, f"{path.name}: missing SVG description")
            self.assertTrue((title.text or "").strip(), f"{path.name}: empty SVG title")
            self.assertTrue((description.text or "").strip(), f"{path.name}: empty SVG description")

            source = path.read_text(encoding="utf-8")
            self.assertNotRegex(source, r"(?is)<script\b|(?:href|src)=['\"]https?://")
            self.assertNotRegex(source, r"(?i)@import|url\(['\"]?https?://")

    def test_readme_section_order_matches_in_both_languages(self) -> None:
        documents = self.readme_documents()
        for path, text in documents.items():
            headings = [(match.start(), match.group("title")) for match in HEADING_RE.finditer(text)]
            self.assertTrue(headings, f"{path.name}: no section headings found")
            previous = -1
            for key, pattern in SECTION_HEADING_PATTERNS:
                positions = [position for position, title in headings if pattern.search(title)]
                self.assertTrue(positions, f"{path.name}: missing {key} section")
                self.assertGreater(positions[0], previous, f"{path.name}: {key} section is out of order")
                previous = positions[0]

    def test_readmes_cover_layout_testing_limitations_prior_art_and_license(self) -> None:
        documents = self.readme_documents()
        required_topics = (
            r"(?i)repository\s+(?:layout|structure)|仓库(?:布局|结构)",
            r"(?i)testing|测试",
            r"(?i)limitations?|限制",
            r"(?i)prior\s+art|先例",
            r"(?i)license|许可证|许可",
        )
        for path, text in documents.items():
            for topic in required_topics:
                self.assertRegex(text, topic, f"{path.name}: missing final documentation topic {topic}")

    def test_readmes_explain_the_two_role_runtime_and_platform_quickstarts(self) -> None:
        documents = self.readme_documents()
        signals = (
            "$sol-luna",
            "sol-controller",
            "luna-max-worker",
            "bash scripts/validate.sh",
            "bash scripts/install.sh",
            "bash scripts/uninstall.sh",
            "scripts/install.ps1",
            "scripts/validate.ps1",
            "scripts/uninstall.ps1",
            "-RestoreLatest",
            "ORCHESTRATE_HOME",
            "PowerShell 5.1",
            "PowerShell 7",
            "Windows 11",
            "Windows Server 2022",
            "macOS",
            "Linux",
        )
        for path, text in documents.items():
            for signal in signals:
                self.assertIn(signal, text, f"{path.name}: missing platform/runtime signal {signal}")
            self.assertRegex(text, r"(?i)Sol.{0,120}(?:controls|controller|控制)")
            self.assertRegex(text, r"(?i)Luna(?: Max)?[\s\S]{0,120}(?:executes|worker|执行)")

    def test_readmes_publish_exact_api_and_chatgpt_rate_rows(self) -> None:
        documents = self.readme_documents()
        for path, text in documents.items():
            lines = text.splitlines()
            for model, values in API_RATES.items():
                model_rows = [line for line in lines if model in line]
                self.assertTrue(model_rows, f"{path.name}: missing API row for {model}")
                self.assertTrue(
                    any(all(value in line for value in values) for line in model_rows),
                    f"{path.name}: wrong API rate row for {model}",
                )
            for model, values in CHATGPT_RATES.items():
                model_rows = [line for line in lines if model in line]
                self.assertTrue(model_rows, f"{path.name}: missing ChatGPT row for {model}")
                self.assertTrue(
                    any(all(value in line for value in values) for line in model_rows),
                    f"{path.name}: wrong ChatGPT rate row for {model}",
                )

    def test_readmes_publish_the_exact_cost_formula_assumptions_and_estimates(self) -> None:
        documents = self.readme_documents()
        formula = "savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead"
        for path, text in documents.items():
            self.assertIn("https://developers.openai.com/api/docs/pricing", text, path.name)
            self.assertIn("https://learn.chatgpt.com/docs/pricing", text, path.name)
            self.assertIn("2026-08-02", text, path.name)
            self.assertIn(formula, text, path.name)
            for assumption in ("delegated_share", "luna_duplication", "sol_overhead"):
                self.assertIn(assumption, text, f"{path.name}: missing assumption {assumption}")
            self.assertIn("1/25", text, path.name)
            self.assertIn("96%", text, path.name)

            lines = text.splitlines()
            for labels, values in SCENARIOS:
                scenario_rows = [line for line in lines if any(label in line for label in labels)]
                self.assertTrue(scenario_rows, f"{path.name}: missing scenario {labels[0]}")
                self.assertTrue(
                    any(all(value in line for value in values) for line in scenario_rows),
                    f"{path.name}: incomplete {labels[0]} scenario",
                )

            self.assertRegex(text, r"(?i)(?:Direct|直接)[^\n]{0,100}0%")

    def test_readmes_state_disclaimers_and_api_subscription_distinction(self) -> None:
        documents = self.readme_documents()
        for path, text in documents.items():
            self.assertRegex(
                text,
                r"(?i)(?:not\s+(?:a\s+)?(?:benchmark|guarantee)|no\s+(?:benchmark|guarantee)|"
                r"不(?:是|作)?(?:基准|保证)|非(?:基准|保证))",
                path.name,
            )
            self.assertRegex(text, r"(?i)API")
            self.assertRegex(text, r"(?i)subscription|订阅")
            self.assertRegex(text, r"(?i)(?:dollar|monetary|capacity|credits|美元|金额|容量|额度)")
            self.assertRegex(text, r"(?i)(?:retry|retries|erase|reverse|重试|抵消|反转)")
            self.assertRegex(text, r"(?is)API.{0,180}(?:dollar|monetary|美元|金额|金钱)")
            self.assertRegex(text, r"(?is)(?:subscription|订阅).{0,180}(?:capacity|credits|容量|额度)")

    def test_bilingual_core_signals_have_parity(self) -> None:
        documents = self.readme_documents()
        parity_signals = (
            "$sol-luna",
            "sol-controller",
            "luna-max-worker",
            "gpt-5.6-sol",
            "gpt-5.6-luna",
            "savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead",
            "https://developers.openai.com/api/docs/pricing",
            "https://learn.chatgpt.com/docs/pricing",
            "1/25",
            "96%",
            "38%",
            "59%",
            "74%",
            "0%",
            "config.toml",
            "RestoreLatest",
        )
        for signal in parity_signals:
            for path, text in documents.items():
                self.assertIn(signal, text, f"{path.name}: parity signal missing: {signal}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
