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
    ROOT / "docs" / "assets" / "readme" / "hero-zh.svg",
    ROOT / "docs" / "assets" / "readme" / "hero-en.svg",
    ROOT / "docs" / "assets" / "readme" / "control-plane-zh.svg",
    ROOT / "docs" / "assets" / "readme" / "control-plane-en.svg",
)
EXPECTED_IMAGE_TARGETS_BY_README = {
    CHINESE_README: (
        "docs/assets/readme/hero-zh.svg",
        "docs/assets/readme/control-plane-zh.svg",
    ),
    ENGLISH_README: (
        "docs/assets/readme/hero-en.svg",
        "docs/assets/readme/control-plane-en.svg",
    ),
}
CANONICAL_REPOSITORY_URL = "https://github.com/yehyakin/codex-sol-luna"
OLD_REPOSITORY_URL = "https://github.com/yehyakin/codex-sol-luna-orchestrator"

MARKDOWN_LINK_RE = re.compile(
    r"!?\[[^\]]*\]\((?:<(?P<bracketed>[^>]+)>|(?P<plain>[^\s)]+))"
)
MARKDOWN_IMAGE_RE = re.compile(
    r"!\[(?P<alt>[^\]]*)\]\((?:<(?P<bracketed>[^>]+)>|(?P<plain>[^\s)]+))"
)
HEADING_RE = re.compile(r"(?im)^#{1,6}\s+(?P<title>.+?)\s*$")
H2_HEADING_RE = re.compile(r"(?im)^## (?P<title>.+?)\s*$")
FENCE_OPEN_RE = re.compile(r"^[ \t]{0,3}(?P<fence>`{3,}|~{3,})")
HTML_COMMENT_RE = re.compile(r"(?s)<!--.*?-->")
ACK_HEADING_RE = re.compile(r"(?im)^\*\*致谢 / Thanks\*\*\s*$")

SECTION_HEADING_MAP = {
    "60 秒开始": "quickstart",
    "60-second quickstart": "quickstart",
    "单一主控，一座执行工坊": "architecture",
    "one controller, one execution workshop": "architecture",
    "选择路径": "routing",
    "choose the route": "routing",
    "工作流": "workflow",
    "workflow": "workflow",
    "可靠性来自边界": "reliability",
    "reliability comes from boundaries": "reliability",
    "真实项目路由样本": "benchmark",
    "real-project routing samples": "benchmark",
    "成本测算与测试口径": "cost_details",
    "成本模型与证据边界": "cost_details",
    "cost projection and test method": "cost_details",
    "cost model and evidence boundary": "cost_details",
    "平台与生命周期": "platform",
    "platforms and lifecycle": "platform",
    "platform and lifecycle": "platform",
    "仓库与开发验证": "repository",
    "repository and development": "repository",
    "限制": "limitations",
    "limitations": "limitations",
    "先例与许可证": "prior_art",
    "prior art and license": "prior_art",
}
EXPECTED_SECTION_KEYS = (
    "quickstart",
    "architecture",
    "routing",
    "workflow",
    "reliability",
    "cost_details",
    "platform",
    "benchmark",
    "repository",
    "limitations",
    "prior_art",
)

CONTROL_ORBIT_PALETTE = (
    "#0B1020",
    "#F7F3E8",
    "#65D6C4",
    "#8FA7FF",
    "#FF6B3D",
)

ENGLISH_DISCLAIMER_RE = re.compile(r"\bnot(?:\s+a)?\s+guarantee\b", re.IGNORECASE)
CHINESE_DISCLAIMER_RE = re.compile(
    r"(?:不构成保证|非保证|不是\s*保证|不是[^。！？；;\n]{1,40}?的\s*保证)"
)

API_RATES = {
    "GPT-5.6 Sol": ("$5.00", "$0.50", "$30.00"),
    "GPT-5.6 Terra": ("$2.00", "$0.20", "$12.00"),
    "GPT-5.6 Luna": ("$0.20", "$0.02", "$1.20"),
}
CHATGPT_RATES = {
    "GPT-5.6 Sol": ("125", "12.5", "750"),
    "GPT-5.6 Terra": ("50", "5", "300"),
    "GPT-5.6 Luna": ("5", "0.5", "30"),
}


class ReadmeContractTests(unittest.TestCase):
    @staticmethod
    def normalize_soft_line(text: str) -> str:
        """Fold soft line wraps inside one already-isolated Markdown block."""

        return re.sub(r"[ \t]*\n[ \t]*", " ", text).strip()

    @staticmethod
    def rendered_markdown(text: str) -> str:
        """Remove fenced code and HTML comments while preserving line boundaries."""

        lines = text.splitlines(keepends=True)
        rendered: list[str] = []
        fence_char: str | None = None
        fence_length = 0
        for line in lines:
            if fence_char is not None:
                closing = re.match(
                    rf"^[ \t]{{0,3}}{re.escape(fence_char)}{{{fence_length},}}[ \t]*(?:\r?\n)?$",
                    line,
                )
                rendered.append("\n" if line.endswith("\n") else "")
                if closing:
                    fence_char = None
                    fence_length = 0
                continue

            opening = FENCE_OPEN_RE.match(line)
            if opening:
                fence = opening.group("fence")
                fence_char = fence[0]
                fence_length = len(fence)
                rendered.append("\n" if line.endswith("\n") else "")
                continue
            rendered.append(line)

        without_fences = "".join(rendered)

        def blank_comment(match: re.Match[str]) -> str:
            newlines = "\n" * match.group(0).count("\n")
            return newlines or " "

        return HTML_COMMENT_RE.sub(blank_comment, without_fences)

    @classmethod
    def normalize_heading_title(cls, title: str) -> str:
        title = re.sub(r"\s+#+\s*$", "", title)
        title = re.sub(r"[`*_~]", "", title)
        return cls.normalize_soft_line(title).casefold()

    @classmethod
    def heading_key(cls, title: str) -> str | None:
        return SECTION_HEADING_MAP.get(cls.normalize_heading_title(title))

    @classmethod
    def heading_sequence(cls, text: str) -> list[str]:
        rendered = cls.rendered_markdown(text)
        return [
            key
            for match in H2_HEADING_RE.finditer(rendered)
            if (key := cls.heading_key(match.group("title"))) is not None
        ]

    @staticmethod
    def table_cells(line: str) -> tuple[str, ...]:
        row = line.strip()
        if row.startswith("|"):
            row = row[1:]
        if row.endswith("|"):
            row = row[:-1]
        return tuple(
            re.sub(r"[ \t]+", " ", cell.strip())
            for cell in row.split("|")
            if cell.strip()
        )

    @classmethod
    def markdown_blocks(cls, text: str) -> list[tuple[str, str, tuple[str, ...]]]:
        """Return rendered paragraphs/headings and tables without cross-block folding."""

        rendered = cls.rendered_markdown(text)
        blocks: list[tuple[str, str, tuple[str, ...]]] = []
        paragraph_lines: list[str] = []
        table_lines: list[str] = []

        def flush_paragraph() -> None:
            if paragraph_lines:
                block = cls.normalize_soft_line("\n".join(paragraph_lines))
                blocks.append(("paragraph", block, (block,)))
                paragraph_lines.clear()

        def flush_table() -> None:
            if table_lines:
                rows = [cls.normalize_soft_line(line) for line in table_lines]
                cells = tuple(cell for line in table_lines for cell in cls.table_cells(line))
                blocks.append(("table", " ".join(rows), cells))
                table_lines.clear()

        for line in rendered.splitlines():
            stripped = line.strip()
            is_table_row = stripped.startswith("|") and stripped.endswith("|")
            if is_table_row:
                flush_paragraph()
                table_lines.append(line)
                continue
            flush_table()
            if not stripped:
                flush_paragraph()
                continue
            if re.match(r"^#{1,6}\s+", stripped):
                flush_paragraph()
                heading = cls.normalize_soft_line(stripped)
                blocks.append(("heading", heading, (heading,)))
                continue
            paragraph_lines.append(line)

        flush_table()
        flush_paragraph()
        return blocks

    @classmethod
    def semantic_units(cls, text: str) -> list[str]:
        units: list[str] = []
        for kind, block, cells in cls.markdown_blocks(text):
            units.extend(cells if kind == "table" else (block,))
        return units

    @classmethod
    def block_units(cls, blocks: list[tuple[str, str, tuple[str, ...]]]) -> list[str]:
        units: list[str] = []
        for kind, block, cells in blocks:
            units.extend(cells if kind == "table" else (block,))
        return units

    @staticmethod
    def block_contains_tokens(
        blocks: list[tuple[str, str, tuple[str, ...]]],
        tokens: tuple[str, ...],
    ) -> bool:
        folded_tokens = tuple(token.casefold() for token in tokens)
        return any(
            all(token in block.casefold() for token in folded_tokens)
            for _, block, _ in blocks
        )

    @classmethod
    def has_direct_zero_in_blocks(cls, blocks: list[tuple[str, str, tuple[str, ...]]]) -> bool:
        return any(
            re.search(r"(?i)\bDirect\b|直接", unit) and "0%" in unit
            for unit in cls.block_units(blocks)
        )

    @classmethod
    def has_direct_zero_pair(cls, text: str) -> bool:
        return cls.has_direct_zero_in_blocks(cls.markdown_blocks(text))

    @classmethod
    def has_valid_disclaimer(cls, text: str, language: str | None = None) -> bool:
        if language == "english":
            return bool(ENGLISH_DISCLAIMER_RE.search(text))
        if language == "chinese":
            return bool(CHINESE_DISCLAIMER_RE.search(text))
        return bool(ENGLISH_DISCLAIMER_RE.search(text) or CHINESE_DISCLAIMER_RE.search(text))

    @classmethod
    def has_valid_disclaimer_in_blocks(
        cls,
        blocks: list[tuple[str, str, tuple[str, ...]]],
        language: str | None = None,
    ) -> bool:
        return any(cls.has_valid_disclaimer(unit, language) for unit in cls.block_units(blocks))

    def first_screen_blocks(self, text: str, readme_name: str) -> list[tuple[str, str, tuple[str, ...]]]:
        rendered = self.rendered_markdown(text)
        quickstart = next(
            (
                match
                for match in HEADING_RE.finditer(rendered)
                if re.match(r"^##(?!#)\s+", match.group(0))
                and self.heading_key(match.group("title")) == "quickstart"
            ),
            None,
        )
        self.assertIsNotNone(
            quickstart,
            f"{readme_name}: missing rendered ## 60-second quickstart / ## 60 秒开始 boundary",
        )
        return self.markdown_blocks(rendered[: quickstart.start()])

    def trailing_acknowledgement(self, text: str, readme_name: str) -> str:
        rendered = self.rendered_markdown(text).rstrip()
        matches = list(ACK_HEADING_RE.finditer(rendered))
        self.assertTrue(matches, f"{readme_name}: missing final acknowledgement heading")
        acknowledgement = rendered[matches[-1].start() :]
        return re.sub(r"\s+", " ", acknowledgement).strip()

    def test_trailing_acknowledgement_normalizes_heading_gap_without_hiding_trailing_content(self) -> None:
        sentence = "感谢 [LINUX DO 论坛](https://linux.do/) 社区的关注、反馈与支持"
        fixture = f"**致谢 / Thanks**\n\n{sentence}"
        expected = f"**致谢 / Thanks** {sentence}"
        self.assertEqual(expected, self.trailing_acknowledgement(fixture, "fixture README"))

        with_trailing_content = f"{fixture}\n\n尾随内容"
        normalized = self.trailing_acknowledgement(with_trailing_content, "fixture README")
        self.assertIn("尾随内容", normalized)
        self.assertFalse(
            normalized.endswith(sentence),
            "trailing content must remain visible so final-block validation can reject it",
        )

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

    def test_cost_claims_are_scenario_model_projections_not_sample_validated_costs(self) -> None:
        chinese = CHINESE_README.read_text(encoding="utf-8")
        english = ENGLISH_README.read_text(encoding="utf-8")

        for text, path in ((chinese, CHINESE_README), (english, ENGLISH_README)):
            for signal in ("72%", "76%", "50%", "60%", "33%", "43%", "56%", "0.4", "0.04"):
                self.assertIn(signal, text, f"{path.name}: missing cost signal {signal}")
            self.assertIn("scenario_model_projection", text, path.name)
            self.assertNotIn("sample_validated_projection", text, path.name)

        self.assertRegex(chinese, r"(?:场景|模型).{0,30}(?:投影|预算)")
        self.assertRegex(english, r"(?i)scenario.{0,30}model.{0,30}projection")

    def test_rendered_markdown_helpers_ignore_fenced_code_and_html_comments(self) -> None:
        fixture = """
```markdown
## Choose the route
![fenced](docs/assets/fenced.svg)
```
<!--
## Workflow
![commented](docs/assets/commented.svg)
-->
## 60-second quickstart
![visible](docs/assets/visible.svg)
"""
        self.assertEqual(
            ["quickstart"],
            self.heading_sequence(fixture),
            "section fixture: fenced/commented headings must not enter rendered section keys",
        )
        self.assertEqual(
            [("visible", "docs/assets/visible.svg")],
            self.image_sequence(fixture),
            "docs/assets/visible.svg: only the rendered image may enter the asset sequence",
        )

    def test_section_heading_map_assigns_one_key_to_each_overlapping_title(self) -> None:
        fixture = """
## Reliability comes from boundaries
## Cost projection and test method
## Real-project routing samples
"""
        self.assertEqual(
            ["reliability", "cost_details", "benchmark"],
            self.heading_sequence(fixture),
            "section fixture: overlapping heading vocabulary must produce one key per heading",
        )
        self.assertEqual(
            "benchmark",
            self.heading_key("Real-project routing samples"),
            "benchmark section must win over the routing word in its title",
        )
        self.assertEqual(
            "cost_details",
            self.heading_key("Cost projection and test method"),
            "cost_details section must win over the boundary word in its title",
        )
        self.assertEqual(
            ["routing"],
            self.heading_sequence("# Choose the route\n### Choose the route\n## Choose the route"),
            "section fixture: only a rendered ## heading may contribute a section key",
        )

    def test_disclaimer_helper_rejects_a_contrary_guarantee_clause(self) -> None:
        self.assertTrue(self.has_valid_disclaimer("This is not a guarantee."))
        self.assertTrue(self.has_valid_disclaimer("这不是每个任务的保证。"))
        self.assertTrue(self.has_valid_disclaimer("这是非保证说明。"))
        self.assertFalse(
            self.has_valid_disclaimer("这不是模型，而是保证。"),
            "README disclaimer fixture must reject a contrast clause ending in 而是保证",
        )
        self.assertFalse(
            self.has_valid_disclaimer("这不是模型，却是保证。"),
            "README disclaimer fixture must reject a contrast clause ending in 却是保证",
        )
        self.assertFalse(
            self.has_valid_disclaimer("这不是成本估算，只是保证。"),
            "README disclaimer fixture must reject a contrast clause ending in 只是保证",
        )
        self.assertFalse(
            self.has_valid_disclaimer("This is not a model, but a guarantee."),
            "README disclaimer fixture must not treat an unrelated contrast as a guarantee disclaimer",
        )

    def test_direct_and_zero_percent_must_share_one_semantic_block(self) -> None:
        self.assertTrue(self.has_direct_zero_pair("Direct tasks route here with 0% savings."))
        self.assertTrue(self.has_direct_zero_pair("Direct tasks route here\nwith 0% savings."))
        self.assertFalse(
            self.has_direct_zero_pair("Direct tasks route here.\n\nThe separate route saves 0%."),
            "README first-screen fixture must reject a cross-paragraph Direct/0% pairing",
        )
        self.assertFalse(
            self.has_direct_zero_pair(
                "| Direct tasks | ordinary route |\n| --- | --- |\n| no delegation | 0% savings |"
            ),
            "README first-screen fixture must reject a cross-cell Direct/0% pairing",
        )

    def test_chinese_readme_is_cost_first_and_conditioned(self) -> None:
        text = CHINESE_README.read_text(encoding="utf-8")
        blocks = self.first_screen_blocks(text, CHINESE_README.name)
        block_texts = [block for _, block, _ in blocks]
        self.assertTrue(
            self.block_contains_tokens(blocks, ("普通", "72%", "76%")),
            f"{CHINESE_README.name}: missing ordinary 72%-76% range in first-screen semantic block",
        )
        self.assertTrue(
            self.block_contains_tokens(blocks, ("混合", "50%", "60%")),
            f"{CHINESE_README.name}: missing mixed 50%-60% range in first-screen semantic block",
        )
        self.assertTrue(
            self.block_contains_tokens(blocks, ("复杂", "33%", "43%")),
            f"{CHINESE_README.name}: missing complex-direct 33%-43% range in first-screen section/table",
        )
        self.assertTrue(
            self.block_contains_tokens(blocks, ("综合", "56%")),
            f"{CHINESE_README.name}: missing composite 56% range in first-screen section/table",
        )
        self.assertTrue(
            any("不是固定结果或保证" in block for block in block_texts)
            or self.has_valid_disclaimer_in_blocks(blocks, "chinese"),
            f"{CHINESE_README.name}: missing current-range disclaimer in first screen",
        )
        self.assertTrue(
            self.has_direct_zero_in_blocks(blocks),
            f"{CHINESE_README.name}: Direct and 0% must share a first-screen paragraph/table cell",
        )

    def test_english_readme_matches_the_conditioned_cost_first_screen(self) -> None:
        text = ENGLISH_README.read_text(encoding="utf-8")
        blocks = self.first_screen_blocks(text, ENGLISH_README.name)
        block_texts = [block for _, block, _ in blocks]
        self.assertTrue(
            self.block_contains_tokens(blocks, ("typical", "72%", "76%"))
            or self.block_contains_tokens(blocks, ("ordinary", "72%", "76%")),
            f"{ENGLISH_README.name}: missing ordinary 72%-76% range in first-screen semantic block",
        )
        self.assertTrue(
            self.block_contains_tokens(blocks, ("mixed", "50%", "60%"))
            or self.block_contains_tokens(blocks, ("hybrid", "50%", "60%")),
            f"{ENGLISH_README.name}: missing mixed 50%-60% range in first-screen semantic block",
        )
        self.assertTrue(
            self.block_contains_tokens(blocks, ("complex", "33%", "43%")),
            f"{ENGLISH_README.name}: missing complex-direct 33%-43% range in first-screen section/table",
        )
        self.assertTrue(
            self.block_contains_tokens(blocks, ("composite", "56%"))
            or self.block_contains_tokens(blocks, ("combined", "56%")),
            f"{ENGLISH_README.name}: missing composite 56% range in first-screen section/table",
        )
        self.assertTrue(
            self.has_valid_disclaimer_in_blocks(blocks, "english"),
            f"{ENGLISH_README.name}: missing valid English not-guarantee disclaimer",
        )
        self.assertTrue(
            self.has_direct_zero_in_blocks(blocks),
            f"{ENGLISH_README.name}: Direct and 0% must share a first-screen paragraph/table cell",
        )

    def test_readmes_use_the_canonical_repository_name(self) -> None:
        documents = self.readme_documents()
        for path, text in documents.items():
            self.assertIn(CANONICAL_REPOSITORY_URL, text, path.name)
            self.assertNotIn(OLD_REPOSITORY_URL, text, path.name)
            self.assertIn("codex-sol-luna", text, path.name)

    def image_sequence(self, text: str, readme_name: str = "fixture README") -> list[tuple[str, str]]:
        images: list[tuple[str, str]] = []
        for match in MARKDOWN_IMAGE_RE.finditer(self.rendered_markdown(text)):
            target = match.group("bracketed") or match.group("plain")
            parsed = urlsplit(target)
            self.assertFalse(
                parsed.scheme or parsed.netloc,
                f"{readme_name}: image asset must be repository-local: {target}",
            )
            images.append((match.group("alt").strip(), target.split("#", 1)[0]))
        return images

    def test_readmes_use_the_localized_images_in_the_same_order(self) -> None:
        documents = self.readme_documents()
        sequences = {path: self.image_sequence(text, path.name) for path, text in documents.items()}
        for path, sequence in sequences.items():
            self.assertEqual(
                list(EXPECTED_IMAGE_TARGETS_BY_README[path]),
                [target for _, target in sequence],
                f"{path.name}: rendered image asset sequence must match {list(EXPECTED_IMAGE_TARGETS_BY_README[path])}",
            )
        for path, sequence in sequences.items():
            for alt, target in sequence:
                self.assertTrue(alt, f"{target}: {path.name} image alt text must be non-empty")

        english_targets = EXPECTED_IMAGE_TARGETS_BY_README[ENGLISH_README]
        for index, ((chinese_alt, chinese_target), (english_alt, english_target)) in enumerate(
            zip(sequences[CHINESE_README], sequences[ENGLISH_README])
        ):
            self.assertEqual(
                english_targets[index],
                english_target,
                f"image index {index}: English asset must pair with the localized Chinese asset",
            )
            self.assertNotEqual(
                chinese_alt,
                english_alt,
                f"{chinese_target}: corresponding Chinese and English alt text must be localized",
            )

    def test_all_relative_markdown_links_resolve_inside_the_repository(self) -> None:
        documents = self.readme_documents()
        root = ROOT.resolve()
        for path, text in documents.items():
            links = list(MARKDOWN_LINK_RE.finditer(self.rendered_markdown(text)))
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
            self.assertNotRegex(source, r"(?is)<image\b|data:image|<foreignObject\b")
            self.assertNotRegex(source, r"(?is)<linearGradient\b|<radialGradient\b")
            self.assertNotRegex(source, r"(?i)oil-visual|border collie|边牧|圆框眼镜")
            for color in CONTROL_ORBIT_PALETTE:
                self.assertIn(color, source, path.name)

    def test_readme_section_order_matches_in_both_languages(self) -> None:
        documents = self.readme_documents()
        matched_sections: dict[Path, list[str]] = {}
        for path, text in documents.items():
            rendered = self.rendered_markdown(text)
            self.assertTrue(
                list(HEADING_RE.finditer(rendered)),
                f"{path.name}: no rendered section headings found",
            )
            section_keys = self.heading_sequence(rendered)
            self.assertEqual(
                list(EXPECTED_SECTION_KEYS),
                section_keys,
                f"{path.name}: rendered heading key sequence must match the expected sections",
            )
            matched_sections[path] = section_keys
        self.assertEqual(
            matched_sections[CHINESE_README],
            matched_sections[ENGLISH_README],
            "bilingual README sections must follow the same stable order",
        )

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
            "terra-high-worker",
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
            self.assertRegex(
                text,
                r"(?i)Terra(?: High)?[\s\S]{0,180}(?:executes|worker|跨模块|cross[- ]module|high[- ]risk|高风险)",
            )

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

    def test_readmes_publish_current_cost_ranges_and_relative_credit_weights(self) -> None:
        documents = self.readme_documents()
        for path, text in documents.items():
            self.assertIn("https://developers.openai.com/api/docs/models/compare", text, path.name)
            self.assertIn(
                "https://help.openai.com/en/articles/20001106-codex-rate-card",
                text,
                path.name,
            )
            self.assertIn("2026-08-03", text, path.name)
            blocks = self.markdown_blocks(text)
            for labels, value in (
                (("Sol", "索尔"), "1"),
                (("Terra", "Terra 高"), "0.4"),
                (("Luna", "Luna 高"), "0.04"),
            ):
                self.assertTrue(
                    any(
                        any(label.casefold() in block.casefold() for label in labels)
                        and re.search(rf"(?<![\d.]){re.escape(value)}(?![\d.])", block)
                        for _, block, _ in blocks
                    ),
                    f"{path.name}: missing relative credit weight {labels[0]}={value}",
                )
            for labels, values in (
                (("ordinary", "typical", "普通"), ("72%", "76%")),
                (("mixed", "hybrid", "混合"), ("50%", "60%")),
                (("complex", "复杂"), ("33%", "43%")),
                (("composite", "combined", "综合"), ("56%",)),
            ):
                self.assertTrue(
                    any(
                        any(label.casefold() in block.casefold() for label in labels)
                        and all(value in block for value in values)
                        for _, block, _ in blocks
                    ),
                    f"{path.name}: missing current cost range for {labels[0]}",
                )

            self.assertTrue(
                self.has_direct_zero_pair(text),
                f"{path.name}: Direct and 0% must share one paragraph or table cell",
            )

    def test_readmes_do_not_publish_old_complex_direct_claim_as_current(self) -> None:
        documents = self.readme_documents()
        historical_markers = re.compile(
            r"(?i)(?:historical|legacy|prior|previous|not\s+current|"
            r"condition(?:ed|al|-based)|reliability[- ]gated|"
            r"历史|旧口径|旧基准|非现行|条件(?:下|性)|可靠性门槛)"
        )
        for path, text in documents.items():
            for unit in self.semantic_units(text):
                if re.search(r"(?i)(?:complex|复杂).{0,180}65%", unit):
                    self.assertRegex(
                        unit,
                        historical_markers,
                        f"{path.name}: complex 65% must be explicitly historical/non-current",
                    )
            self.assertNotRegex(
                text,
                r"41%\s*\*\s*85%\s*=\s*34\.85%",
                f"{path.name}: old reliability-gated derivation must not remain current",
            )

    def test_readmes_preserve_linux_do_attribution(self) -> None:
        chinese = CHINESE_README.read_text(encoding="utf-8")
        english = ENGLISH_README.read_text(encoding="utf-8")
        chinese_tail = self.trailing_acknowledgement(chinese, CHINESE_README.name)
        english_tail = self.trailing_acknowledgement(english, ENGLISH_README.name)
        self.assertTrue(
            chinese_tail.endswith(
                "**致谢 / Thanks** 感谢 [LINUX DO 论坛](https://linux.do/) 社区的关注、反馈与支持"
            ),
            "Chinese acknowledgement must be the final block without a full stop",
        )
        self.assertTrue(
            english_tail.endswith(
                "**致谢 / Thanks** Thank you to the [LINUX DO forum](https://linux.do/) community for its attention, feedback, and support."
            ),
            "English acknowledgement must be the final block",
        )

    def test_readmes_link_the_release_runtime_surface_matrix(self) -> None:
        documents = self.readme_documents()
        for path, text in documents.items():
            self.assertIn("docs/release/runtime-surface-matrix.md", text, path.name)

    def test_readmes_state_disclaimers_and_api_subscription_distinction(self) -> None:
        documents = self.readme_documents()
        for path, text in documents.items():
            self.assertRegex(
                text,
                r"(?i)(?:not\s+(?:a\s+)?(?:benchmark|guarantee)|no\s+(?:benchmark|guarantee)|"
                r"不(?:是|作)?(?:基准|保证)|非(?:基准|保证))",
                path.name,
            )
            self.assertTrue(
                any(
                    self.has_valid_disclaimer(
                        unit,
                        "chinese" if path == CHINESE_README else "english",
                    )
                    for unit in self.semantic_units(text)
                ),
                f"{path.name}: disclaimer must explicitly state not (a) guarantee or its Chinese equivalent",
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
            "terra-high-worker",
            "gpt-5.6-sol",
            "gpt-5.6-luna",
            "gpt-5.6-terra",
            "https://developers.openai.com/api/docs/models/compare",
            "https://help.openai.com/en/articles/20001106-codex-rate-card",
            "72%",
            "76%",
            "50%",
            "60%",
            "33%",
            "43%",
            "56%",
            "0.4",
            "0.04",
            "0%",
            "config.toml",
            "RestoreLatest",
            "v0.3.0",
            "106/106",
            "Compatibility",
            "Native Nested",
            "6895f06",
            "ORCHESTRATE_SOL_LUNA_V2_IMPLEMENTATION_REPORT.md",
            "actions/runs/30858707335",
            "actions/runs/30858707364",
        )
        for signal in parity_signals:
            for path, text in documents.items():
                self.assertIn(signal, text, f"{path.name}: parity signal missing: {signal}")

        release_status_specs = {
            CHINESE_README: {
                "title": "v0.3.0 发布状态",
                "control_orbit": "docs/assets/readme/control-plane-zh.svg",
                "compatibility": r"Compatibility\s+已验证",
                "unproven": r"Native Nested.*全新 CLI child model/effort 身份.*物理 Windows 11 尚未证明",
                "local_row_label": "本地仓库",
                "hosted_row_label": "托管 CI",
                "local_row_signals": (
                    "Skill Creator **PASS**",
                    "**106/106** tests PASS",
                ),
                "hosted_row_signals": (
                    "POSIX **PASS**",
                    "Windows Server 2022",
                    "windows-latest",
                    "Windows PowerShell 5.1",
                    "PowerShell 7 **PASS**",
                ),
            },
            ENGLISH_README: {
                "title": "v0.3.0 release status",
                "control_orbit": "docs/assets/readme/control-plane-en.svg",
                "compatibility": r"Compatibility\s+verified",
                "unproven": r"Native Nested, fresh-CLI child model/effort identity, and physical Windows 11 remain unproven",
                "local_row_label": "Local repository",
                "hosted_row_label": "Hosted CI",
                "local_row_signals": (
                    "Skill Creator **PASS**",
                    "**106/106** tests PASS",
                ),
                "hosted_row_signals": (
                    "POSIX **PASS**",
                    "Windows Server 2022",
                    "windows-latest",
                    "Windows PowerShell 5.1",
                    "PowerShell 7 **PASS**",
                ),
            },
        }
        for path, text in documents.items():
            spec = release_status_specs[path]
            rendered = self.rendered_markdown(text)
            release_heading_matches = list(
                re.finditer(rf"(?m)^## {re.escape(spec['title'])}\s*$", rendered)
            )
            self.assertEqual(
                len(release_heading_matches),
                1,
                f"{path.name}: release status must have exactly one H2 heading",
            )
            release_heading = release_heading_matches[0]
            self.assertEqual(
                release_heading.group(0).split(maxsplit=1)[0],
                "##",
                f"{path.name}: release status heading must be H2",
            )

            control_orbit_matches = list(
                re.finditer(
                    rf"(?m)^!\[[^\n]*\]\({re.escape(spec['control_orbit'])}\)\s*$",
                    rendered,
                )
            )
            self.assertEqual(
                len(control_orbit_matches),
                1,
                f"{path.name}: Control Orbit image must have exactly one target",
            )
            control_orbit = control_orbit_matches[0]
            self.assertLess(
                release_heading.end(),
                control_orbit.start(),
                f"{path.name}: release status must precede Control Orbit",
            )
            release_block = rendered[release_heading.start() : control_orbit.start()]
            for signal in (
                "v0.3.0",
                "106/106",
                "6895f06",
                "(ORCHESTRATE_SOL_LUNA_V2_IMPLEMENTATION_REPORT.md)",
                "https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707335",
                "https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707364",
            ):
                self.assertIn(
                    signal,
                    release_block,
                    f"{path.name}: release status block missing {signal}",
                )
            self.assertRegex(
                release_block,
                spec["compatibility"],
                f"{path.name}: release status must positively verify Compatibility",
            )
            self.assertRegex(
                release_block,
                spec["unproven"],
                f"{path.name}: release status must mark unsupported surfaces unproven",
            )

            def gfm_row_cells(line: str) -> tuple[str, ...] | None:
                stripped = line.strip()
                if not stripped or "|" not in stripped:
                    return None
                cells = self.table_cells(stripped)
                return cells if len(cells) >= 2 else None

            table_blocks: list[list[tuple[str, ...]]] = []
            lines = release_block.splitlines()
            line_index = 0
            while line_index + 1 < len(lines):
                header_cells = gfm_row_cells(lines[line_index])
                delimiter_cells = gfm_row_cells(lines[line_index + 1])
                if (
                    header_cells is None
                    or delimiter_cells is None
                    or len(header_cells) != len(delimiter_cells)
                    or not all(
                        re.fullmatch(r":?-+:?", cell.replace(" ", ""))
                        for cell in delimiter_cells
                    )
                ):
                    line_index += 1
                    continue

                data_rows: list[tuple[str, ...]] = []
                line_index += 2
                while line_index < len(lines):
                    data_cells = gfm_row_cells(lines[line_index])
                    if data_cells is None or len(data_cells) != len(header_cells):
                        break
                    data_rows.append(data_cells)
                    line_index += 1
                table_blocks.append(data_rows)

            status_table_rows: list[dict[str, str]] = []
            target_labels = (spec["local_row_label"], spec["hosted_row_label"])
            for data_rows in table_blocks:
                rows: dict[str, str] = {}
                for cells in data_rows:
                    row_label = cells[0]
                    if row_label in target_labels:
                        self.assertNotIn(
                            row_label,
                            rows,
                            f"{path.name}: release status row must be unique: {row_label}",
                        )
                        rows[row_label] = cells[1]
                if rows:
                    status_table_rows.append(rows)

            self.assertEqual(
                len(status_table_rows),
                1,
                f"{path.name}: local and hosted release rows must share one GFM table",
            )
            status_rows = status_table_rows[0]

            for row_key in ("local", "hosted"):
                row_label = spec[f"{row_key}_row_label"]
                self.assertIn(
                    row_label,
                    status_rows,
                    f"{path.name}: release status missing {row_key} evidence row",
                )
                row = status_rows[row_label]
                for signal in spec[f"{row_key}_row_signals"]:
                    self.assertIn(
                        signal,
                        row,
                        f"{path.name}: {row_key} release status row missing {signal}",
                    )


if __name__ == "__main__":
    unittest.main(verbosity=2)
