#!/usr/bin/env python3
"""RED contract for the bilingual README Control Orbit SVG assets.

This checkpoint deliberately runs before the four assets are created.  Missing
assets are reported as ordinary, path-specific unittest failures; parsing and
the dependent checks are only attempted once the corresponding file exists.
"""

from __future__ import annotations

import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "hero-zh.svg": ROOT / "docs/assets/readme/hero-zh.svg",
    "hero-en.svg": ROOT / "docs/assets/readme/hero-en.svg",
    "control-plane-zh.svg": ROOT / "docs/assets/readme/control-plane-zh.svg",
    "control-plane-en.svg": ROOT / "docs/assets/readme/control-plane-en.svg",
}

SVG_NAMESPACE = "http://www.w3.org/2000/svg"
SVG_TAG = f"{{{SVG_NAMESPACE}}}"
FORBIDDEN_TAG_RE = re.compile(
    r"(?is)<(?:script|foreignObject|image|animate|set)\b"
)
URL_RE = re.compile(r"https?://[^\s\"'<>]+", re.IGNORECASE)
REMOTE_RESOURCE_RE = re.compile(
    r"(?is)@(?:font-face|import)\b|url\(\s*(?!#|data:)[^)]+\)"
)
FONT_SIZE_RE = re.compile(
    r"(?:^|;)\s*font-size\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*(?:px|pt|em|rem|%)?",
    re.IGNORECASE,
)
NUMERIC_FONT_SIZE_RE = re.compile(
    r"^\s*([0-9]+(?:\.[0-9]+)?)\s*(?:px|pt|em|rem|%)?\s*$",
    re.IGNORECASE,
)
CHINESE_TEXT_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")

TEXT_TAGS = {"text", "tspan"}
NON_RENDERED_TEXT_TAGS = {"title", "desc"}
GEOMETRY_TAGS = {
    "circle",
    "ellipse",
    "g",
    "line",
    "path",
    "polygon",
    "polyline",
    "rect",
}
GEOMETRY_ATTRIBUTES = {
    "d",
    "id",
    "points",
    "transform",
    "x",
    "x1",
    "x2",
    "y",
    "y1",
    "y2",
    "cx",
    "cy",
    "r",
    "rx",
    "ry",
    "width",
    "height",
    "viewBox",
    "data-flow",
    "data-from",
    "data-to",
}
KEY_LABELS = (
    "SOL / LUNA",
    "59%",
    "FILES",
    "DIFF",
    "TEST",
    "PASS",
    "FIX",
    "BLOCKED",
    "DIRECT",
    "SOL-ONLY",
    "SOL → LUNA",
)


def local_name(tag: str) -> str:
    """Return an XML local name for namespaced and unnamespaced tags."""

    return tag.rsplit("}", 1)[-1]


def element_text(element: ET.Element) -> str:
    return " ".join(part.strip() for part in element.itertext() if part.strip())


def direct_text(element: ET.Element) -> str:
    return (element.text or "").strip()


def numeric_font_size(value: str) -> float | None:
    match = NUMERIC_FONT_SIZE_RE.match(value)
    return float(match.group(1)) if match else None


def declared_font_size(element: ET.Element) -> float | None:
    if "font-size" in element.attrib:
        return numeric_font_size(element.attrib["font-size"])
    style_match = FONT_SIZE_RE.search(element.attrib.get("style", ""))
    return float(style_match.group(1)) if style_match else None


def iter_text_nodes(
    element: ET.Element,
    inherited_font_size: float | None = None,
) -> list[tuple[ET.Element, str, float | None]]:
    current_font_size = declared_font_size(element)
    if current_font_size is None:
        current_font_size = inherited_font_size

    nodes: list[tuple[ET.Element, str, float | None]] = []
    if local_name(element.tag) in TEXT_TAGS:
        nodes.append((element, direct_text(element), current_font_size))
    for child in element:
        nodes.extend(iter_text_nodes(child, current_font_size))
    return nodes


def geometry_signature(root: ET.Element) -> tuple[tuple[str, tuple[tuple[str, str], ...]], ...]:
    """Capture shape/path geometry while ignoring localized text fitting."""

    signature: list[tuple[str, tuple[tuple[str, str], ...]]] = []
    for element in root.iter():
        name = local_name(element.tag)
        if name not in GEOMETRY_TAGS:
            continue
        attrs = tuple(
            sorted(
                (key, value)
                for key, value in element.attrib.items()
                if local_name(key) in GEOMETRY_ATTRIBUTES
            )
        )
        signature.append((name, attrs))
    return tuple(signature)


def endpoint_kind(value: str) -> str | None:
    normalized = value.strip().casefold()
    if normalized in {"sol", "sol-controller", "sol controller"}:
        return "sol"
    if re.fullmatch(r"luna(?:-worker-[1-3])?(?: worker)?", normalized):
        return "luna"
    return None


class ControlOrbitAssetContractTests(unittest.TestCase):
    def test_assets_meet_control_orbit_contract(self) -> None:
        parsed: dict[str, ET.Element] = {}

        for name, path in ASSETS.items():
            with self.subTest(asset=name):
                if not path.is_file():
                    self.fail(f"missing SVG asset: {path}")
                try:
                    source = path.read_text(encoding="utf-8")
                    root = ET.fromstring(source)
                except (OSError, ET.ParseError) as error:
                    self.fail(f"invalid SVG asset {path}: {error}")

                parsed[name] = root
                self.assertEqual(
                    f"{SVG_TAG}svg",
                    root.tag,
                    f"{name}: root must use the standard SVG namespace",
                )
                expected_view_box = (
                    "0 0 1200 420" if name.startswith("hero-") else "0 0 1200 520"
                )
                self.assertEqual(expected_view_box, root.attrib.get("viewBox"), name)

                title = root.find(f"{SVG_TAG}title")
                desc = root.find(f"{SVG_TAG}desc")
                self.assertIsNotNone(title, f"{name}: missing title")
                self.assertIsNotNone(desc, f"{name}: missing desc")
                if title is not None:
                    self.assertTrue(element_text(title), f"{name}: title is empty")
                if desc is not None:
                    self.assertTrue(element_text(desc), f"{name}: desc is empty")

                self.assertNotRegex(source, FORBIDDEN_TAG_RE, f"{name}: forbidden SVG tag")
                self.assertNotRegex(
                    source,
                    r"(?is)<(?:script|foreignObject|image|animate|set)\b",
                    f"{name}: forbidden SVG tag",
                )
                self.assertNotRegex(
                    source,
                    REMOTE_RESOURCE_RE,
                    f"{name}: remote font or external resource",
                )
                urls = URL_RE.findall(source)
                self.assertTrue(
                    all(url == SVG_NAMESPACE for url in urls),
                    f"{name}: unexpected external URL(s): {urls}",
                )
                for element in root.iter():
                    event_attributes = [
                        attribute
                        for attribute in element.attrib
                        if local_name(attribute).casefold().startswith("on")
                    ]
                    self.assertFalse(
                        event_attributes,
                        f"{name}: event handler attribute(s): {event_attributes}",
                    )
                    for attribute in ("href", "src"):
                        if attribute in element.attrib:
                            self.assertTrue(
                                element.attrib[attribute].startswith("#"),
                                f"{name}: external {attribute} is forbidden",
                            )

                text = element_text(root)
                if name.endswith("-zh.svg"):
                    self.assertIn("Sol", text, name)
                    self.assertIn("Luna", text, name)
                    self.assertRegex(text, CHINESE_TEXT_RE, f"{name}: missing Chinese copy")
                else:
                    self.assertIn("Sol", text, name)
                    self.assertIn("Luna", text, name)
                    self.assertIn("estimated", text.casefold(), name)
                if name.startswith("hero-"):
                    self.assertIn("59%", text, name)
                    self.assertIn("FILES", text, name)
                    self.assertIn("DIFF", text, name)
                    self.assertIn("TEST", text, name)
                    if name.endswith("-zh.svg"):
                        self.assertIn("估算", text, name)
                else:
                    for token in ("PASS", "FIX", "BLOCKED"):
                        self.assertIn(token, text, f"{name}: missing {token}")

                ids = [element.attrib["id"] for element in root.iter() if "id" in element.attrib]
                self.assertEqual(
                    ids.count("sol-controller"),
                    1,
                    f"{name}: expected exactly one sol-controller",
                )
                worker_ids = sorted(
                    identifier
                    for identifier in ids
                    if re.fullmatch(r"luna-worker-[0-9]+", identifier)
                )
                self.assertEqual(
                    worker_ids,
                    ["luna-worker-1", "luna-worker-2", "luna-worker-3"],
                    f"{name}: expected exactly luna-worker-1..3",
                )

                for element, node_text, font_size in iter_text_nodes(root):
                    if not node_text:
                        continue
                    self.assertIsNotNone(
                        font_size,
                        f"{name}: text has no valid font-size: {node_text!r}",
                    )
                    if font_size is not None:
                        self.assertGreaterEqual(
                            font_size,
                            18,
                            f"{name}: text below 18 units: {node_text!r}",
                        )
                    folded = node_text.casefold()
                    if any(label.casefold() in folded for label in KEY_LABELS):
                        self.assertIsNotNone(font_size, f"{name}: key label has no font-size")
                        if font_size is not None:
                            self.assertGreaterEqual(
                                font_size,
                                20,
                                f"{name}: key label below 20 units: {node_text!r}",
                            )

        if len(parsed) != len(ASSETS):
            # The four missing-file subtests above are the intentional RED
            # signal.  Avoid XML/geometry tracebacks while assets are absent.
            return

        for name, root in parsed.items():
            flow_elements = [
                element
                for element in root.iter()
                if element.attrib.get("data-flow", "").casefold() in {"task", "evidence"}
            ]
            self.assertTrue(flow_elements, f"{name}: missing task/evidence path metadata")
            task_paths = [
                element for element in flow_elements if element.attrib["data-flow"].casefold() == "task"
            ]
            evidence_paths = [
                element
                for element in flow_elements
                if element.attrib["data-flow"].casefold() == "evidence"
            ]
            self.assertTrue(task_paths, f"{name}: missing Sol-to-Luna task path")
            self.assertTrue(evidence_paths, f"{name}: missing Luna-to-Sol evidence path")

            for element in flow_elements:
                flow = element.attrib["data-flow"].casefold()
                source_kind = endpoint_kind(element.attrib.get("data-from", ""))
                target_kind = endpoint_kind(element.attrib.get("data-to", ""))
                self.assertIsNotNone(source_kind, f"{name}: path has invalid data-from")
                self.assertIsNotNone(target_kind, f"{name}: path has invalid data-to")
                if flow == "task":
                    self.assertEqual("sol", source_kind, f"{name}: task path must start at Sol")
                    self.assertEqual("luna", target_kind, f"{name}: task path must end at Luna")
                elif flow == "evidence":
                    self.assertEqual("luna", source_kind, f"{name}: evidence must start at Luna")
                    self.assertEqual("sol", target_kind, f"{name}: evidence must end at Sol")
                self.assertFalse(
                    source_kind == target_kind == "luna",
                    f"{name}: Luna-to-Luna path is forbidden",
                )

        for language in ("zh", "en"):
            hero_geometry = geometry_signature(parsed[f"hero-{language}.svg"])
            plane_geometry = geometry_signature(parsed[f"control-plane-{language}.svg"])
            other_language = "en" if language == "zh" else "zh"
            self.assertEqual(
                hero_geometry,
                geometry_signature(parsed[f"hero-{other_language}.svg"]),
                "hero Chinese/English geometry must match",
            )
            self.assertEqual(
                plane_geometry,
                geometry_signature(parsed[f"control-plane-{other_language}.svg"]),
                "control-plane Chinese/English geometry must match",
            )


if __name__ == "__main__":
    unittest.main()
