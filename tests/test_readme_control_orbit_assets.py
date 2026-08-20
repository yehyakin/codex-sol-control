#!/usr/bin/env python3
"""Contracts for the bilingual Codex PROVE README SVG assets."""

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
XLINK_NAMESPACE = "http://www.w3.org/1999/xlink"
SVG_TAG = f"{{{SVG_NAMESPACE}}}"
FORBIDDEN_TAG_RE = re.compile(
    r"(?is)<(?:script|foreignObject|image|animate|set)\b"
)
URL_RE = re.compile(r"https?://[^\s\"'<>]+", re.IGNORECASE)
PROTOCOL_RELATIVE_RE = re.compile(r"(?<!:)//[A-Za-z0-9._~:/?#@!$&'()*+,;=%-]+")
URL_FUNCTION_RE = re.compile(r"url\(\s*([^)]*?)\s*\)", re.IGNORECASE)
NAMESPACE_DECLARATION_RE = re.compile(
    r"\bxmlns(?::[A-Za-z_][\w.-]*)?\s*=\s*(['\"])(.*?)\1",
    re.IGNORECASE | re.DOTALL,
)
REMOTE_FONT_RE = re.compile(r"(?is)@(?:font-face|import)\b")
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
    "CODEX PROVE",
    "72%",
    "FILES",
    "DIFF",
    "TEST",
    "PASS",
    "FIX",
    "BLOCKED",
    "DIRECT",
    "CONTROLLER-ONLY",
    "CONTROLLER → EFFICIENT",
    "CONTROLLER → COMPLEX",
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


def resource_safety_errors(source: str, root: ET.Element) -> list[str]:
    """Return violations of the local-only SVG resource policy.

    The SVG namespace (and the standard XLink declaration needed to parse an
    ``xlink:href`` attribute) are XML plumbing, not external resources.  Every
    actual resource reference must be a local ``#fragment``.
    """

    errors: list[str] = []
    namespace_values = {
        value.strip() for _, value in NAMESPACE_DECLARATION_RE.findall(source)
    }
    allowed_namespaces = {SVG_NAMESPACE, XLINK_NAMESPACE}
    errors.extend(
        f"unexpected namespace URI: {value}"
        for value in sorted(namespace_values - allowed_namespaces)
    )

    source_without_namespace_declarations = NAMESPACE_DECLARATION_RE.sub("", source)
    errors.extend(
        f"unexpected external URL: {url}"
        for url in URL_RE.findall(source_without_namespace_declarations)
        if url not in allowed_namespaces
    )
    errors.extend(
        f"protocol-relative resource: {match.group(0)}"
        for match in PROTOCOL_RELATIVE_RE.finditer(source_without_namespace_declarations)
    )
    if REMOTE_FONT_RE.search(source_without_namespace_declarations):
        errors.append("remote font or CSS import declaration")

    for match in URL_FUNCTION_RE.finditer(source_without_namespace_declarations):
        value = match.group(1).strip().strip("\"'").strip()
        if not value.startswith("#"):
            errors.append(f"non-local url() resource: {value}")

    for element in root.iter():
        for attribute, value in element.attrib.items():
            attribute_name = local_name(attribute).casefold()
            if attribute_name in {"href", "src", "srcset"}:
                normalized = value.strip()
                if not normalized.startswith("#"):
                    errors.append(
                        f"non-local {attribute_name} resource: {normalized}"
                    )
    return errors


EXPECTED_WORKERS = (
    "efficient-worker-1",
    "efficient-worker-2",
    "efficient-worker-3",
)


def worker_path_errors(root: ET.Element) -> list[str]:
    """Validate three independent controller/worker task/evidence round trips."""

    errors: list[str] = []
    flow_elements = [
        element
        for element in root.iter()
        if element.attrib.get("data-flow", "").casefold() in {"task", "evidence"}
    ]
    tasks = [
        element
        for element in flow_elements
        if element.attrib.get("data-flow", "").casefold() == "task"
    ]
    evidence = [
        element
        for element in flow_elements
        if element.attrib.get("data-flow", "").casefold() == "evidence"
    ]
    if not tasks:
        errors.append("missing task paths")
    if not evidence:
        errors.append("missing evidence paths")

    task_targets: list[str] = []
    for element in tasks:
        source = element.attrib.get("data-from", "").strip()
        target = element.attrib.get("data-to", "").strip()
        if source != "prove-controller":
            errors.append(f"task path must start at prove-controller: {source!r}")
        if target not in EXPECTED_WORKERS:
            errors.append(f"task path has invalid efficient owner: {target!r}")
        task_targets.append(target)

    evidence_sources: list[str] = []
    for element in evidence:
        source = element.attrib.get("data-from", "").strip()
        target = element.attrib.get("data-to", "").strip()
        if source not in EXPECTED_WORKERS:
            errors.append(f"evidence path has invalid efficient owner: {source!r}")
        if target != "prove-controller":
            errors.append(f"evidence path must return to prove-controller: {target!r}")
        evidence_sources.append(source)

    expected_workers = set(EXPECTED_WORKERS)
    if set(task_targets) != expected_workers:
        errors.append(
            "task path data-to must exactly cover efficient-worker-1..3: "
            f"{sorted(set(task_targets))!r}"
        )
    if len(task_targets) != len(EXPECTED_WORKERS):
        errors.append("task paths must contain exactly one path per efficient worker")
    if set(evidence_sources) != expected_workers:
        errors.append(
            "evidence path data-from must exactly cover efficient-worker-1..3: "
            f"{sorted(set(evidence_sources))!r}"
        )
    if len(evidence_sources) != len(EXPECTED_WORKERS):
        errors.append("evidence paths must contain exactly one path per efficient worker")
    return errors


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
                self.assertEqual(
                    [],
                    resource_safety_errors(source, root),
                    f"{name}: resource safety violation",
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

                text = element_text(root)
                if name.endswith("-zh.svg"):
                    self.assertIn("PROVE", text, name)
                    self.assertIn("Controller", text, name)
                    self.assertRegex(text, CHINESE_TEXT_RE, f"{name}: missing Chinese copy")
                elif name == "hero-en.svg":
                    self.assertIn("PROVE", text, name)
                    self.assertIn("controller", text.casefold(), name)
                    self.assertRegex(
                        text,
                        r"(?i)(?:estimated|budget|projection|sample[- ]validated)",
                        name,
                    )
                else:
                    self.assertIn("PROVE", text, name)
                    self.assertIn("CONTROLLER", text, name)
                if name.startswith("hero-"):
                    self.assertIn("72%", text, name)
                    self.assertIn("FILES", text, name)
                    self.assertIn("DIFF", text, name)
                    self.assertIn("TEST", text, name)
                    if name.endswith("-zh.svg"):
                        self.assertRegex(text, r"(?:估算|预算|比例|路由开销)", name)
                else:
                    for token in ("PASS", "FIX", "BLOCKED"):
                        self.assertIn(token, text, f"{name}: missing {token}")
                    for token in (
                        "DIRECT",
                        "CONTROLLER-ONLY",
                        "CONTROLLER → EFFICIENT",
                        "CONTROLLER → COMPLEX",
                    ):
                        self.assertIn(token, text, f"{name}: missing route {token}")
                    if name.endswith("-zh.svg"):
                        self.assertIn("同一文件只能有一个 Owner", text, name)
                        self.assertIn("重叠范围不得并发", text, name)
                    else:
                        folded_text = text.casefold()
                        self.assertIn("one file, one owner", folded_text, name)
                        self.assertIn(
                            "overlapping scopes never run concurrently",
                            folded_text,
                            name,
                        )

                ids = [element.attrib["id"] for element in root.iter() if "id" in element.attrib]
                self.assertEqual(
                    ids.count("prove-controller"),
                    1,
                    f"{name}: expected exactly one prove-controller",
                )
                worker_ids = sorted(
                    identifier
                    for identifier in ids
                    if re.fullmatch(r"efficient-worker-[0-9]+", identifier)
                )
                self.assertEqual(
                    worker_ids,
                    ["efficient-worker-1", "efficient-worker-2", "efficient-worker-3"],
                    f"{name}: expected exactly efficient-worker-1..3",
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
            self.assertEqual([], worker_path_errors(root), f"{name}: worker path violation")

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

    def test_resource_safety_helper_fixtures(self) -> None:
        local_source = f"""
        <svg xmlns="{SVG_NAMESPACE}">
          <defs><linearGradient id="local" /></defs>
          <use href="#local" />
          <rect style="fill:url(#local)" />
        </svg>
        """
        local_root = ET.fromstring(local_source)
        self.assertEqual([], resource_safety_errors(local_source, local_root))

        rejected_sources = {
            "data": f'<svg xmlns="{SVG_NAMESPACE}"><use href="data:image/svg+xml;base64,AA==" /></svg>',
            "http": f'<svg xmlns="{SVG_NAMESPACE}"><use href="https://cdn.example/asset.svg" /></svg>',
            "protocol-relative": f'<svg xmlns="{SVG_NAMESPACE}"><use href="//cdn.example/asset.svg" /></svg>',
            "relative": f'<svg xmlns="{SVG_NAMESPACE}"><use href="../asset.svg" /></svg>',
            "xlink": (
                f'<svg xmlns="{SVG_NAMESPACE}" xmlns:xlink="{XLINK_NAMESPACE}">'
                '<use xlink:href="https://cdn.example/asset.svg" /></svg>'
            ),
            "remote-font": (
                f'<svg xmlns="{SVG_NAMESPACE}"><style>@font-face {{'
                "font-family: Remote; src: url(https://cdn.example/font.woff2) }}"
                "</style></svg>"
            ),
        }
        for label, source in rejected_sources.items():
            with self.subTest(resource=label):
                root = ET.fromstring(source)
                self.assertTrue(resource_safety_errors(source, root), label)

    def test_worker_path_helper_requires_every_round_trip(self) -> None:
        def fixture(task_workers: tuple[str, ...], evidence_workers: tuple[str, ...]) -> ET.Element:
            root = ET.Element(f"{SVG_TAG}svg")
            for index, worker in enumerate(task_workers):
                path = ET.SubElement(root, f"{SVG_TAG}path", id=f"task-{index}")
                path.set("data-flow", "task")
                path.set("data-from", "prove-controller")
                path.set("data-to", worker)
            for index, worker in enumerate(evidence_workers):
                path = ET.SubElement(root, f"{SVG_TAG}path", id=f"evidence-{index}")
                path.set("data-flow", "evidence")
                path.set("data-from", worker)
                path.set("data-to", "prove-controller")
            return root

        complete = fixture(EXPECTED_WORKERS, EXPECTED_WORKERS)
        self.assertEqual([], worker_path_errors(complete))

        missing_task = fixture(EXPECTED_WORKERS[:2], EXPECTED_WORKERS)
        self.assertTrue(worker_path_errors(missing_task))

        missing_evidence = fixture(EXPECTED_WORKERS, EXPECTED_WORKERS[:2])
        self.assertTrue(worker_path_errors(missing_evidence))

        generalized_worker = fixture(("efficient", "efficient-worker-2", "efficient-worker-3"), EXPECTED_WORKERS)
        self.assertTrue(worker_path_errors(generalized_worker))


if __name__ == "__main__":
    unittest.main()
