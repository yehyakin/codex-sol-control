#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
SKILL_ROOT="$ROOT_DIR/.agents/skills/codex-prove"
SKILL_FILE="$SKILL_ROOT/SKILL.md"
OPENAI_FILE="$SKILL_ROOT/agents/openai.yaml"
CONTRACT_FILE="$SKILL_ROOT/references/orchestration.md"
RUNTIME_FILE="$SKILL_ROOT/references/runtime-notes.md"
COMPAT_ROOT="$ROOT_DIR/.agents/skills/sol-control"
COMPAT_SKILL_FILE="$COMPAT_ROOT/SKILL.md"
COMPAT_OPENAI_FILE="$COMPAT_ROOT/agents/openai.yaml"
CONTROLLER_FILE="$ROOT_DIR/.codex/agents/prove-controller.toml"
COMPLEX_FILE="$ROOT_DIR/.codex/agents/prove-complex-worker.toml"
EFFICIENT_FILE="$ROOT_DIR/.codex/agents/prove-efficient-worker.toml"
WINDOWS_LIFECYCLE_FILE="$ROOT_DIR/tests/windows-lifecycle.ps1"
WINDOWS_WORKFLOW_FILE="$ROOT_DIR/.github/workflows/windows-validation.yml"
POSIX_WORKFLOW_FILE="$ROOT_DIR/.github/workflows/posix-validation.yml"

failures=0
fail() {
  printf 'Validation: FAIL: %s\n' "$1"
  failures=1
}

required_files=(
  ".agents/skills/codex-prove/SKILL.md"
  ".agents/skills/codex-prove/agents/openai.yaml"
  ".agents/skills/codex-prove/references/orchestration.md"
  ".agents/skills/codex-prove/references/runtime-notes.md"
  ".agents/skills/sol-control/SKILL.md"
  ".agents/skills/sol-control/agents/openai.yaml"
  ".codex/agents/prove-controller.toml"
  ".codex/agents/prove-complex-worker.toml"
  ".codex/agents/prove-efficient-worker.toml"
  "scripts/install.sh"
  "scripts/validate.sh"
  "scripts/test.sh"
  "scripts/benchmark_ab.py"
  "scripts/uninstall.sh"
  "scripts/install.ps1"
  "scripts/validate.ps1"
  "scripts/uninstall.ps1"
  "README.md"
  "README.en.md"
  "CONTRIBUTING.md"
  "CODE_OF_CONDUCT.md"
  "SECURITY.md"
  "SUPPORT.md"
  ".github/ISSUE_TEMPLATE/bug_report.yml"
  ".github/ISSUE_TEMPLATE/feature_request.yml"
  ".github/ISSUE_TEMPLATE/config.yml"
  ".github/pull_request_template.md"
  ".github/workflows/posix-validation.yml"
  ".github/workflows/windows-validation.yml"
  "docs/assets/readme/hero-zh.svg"
  "docs/assets/readme/hero-en.svg"
  "docs/assets/readme/control-plane-zh.svg"
  "docs/assets/readme/control-plane-en.svg"
  "docs/release/runtime-surface-matrix.md"
  "tests/windows-lifecycle.ps1"
  "tests/fixtures/forward-cases.json"
  "tests/fixtures/v100-ab-benchmark.json"
  "tests/v100-ab-benchmark.md"
  "tests/v100-live-smoke.md"
  "tests/test_v100_benchmark.py"
  "tests/test_v100_evidence_control.py"
  "CODEX_PROVE_V1_IMPLEMENTATION_REPORT.md"
  "NOTICE"
  "LICENSE"
)
for relative in "${required_files[@]}"; do
  [[ -f "$ROOT_DIR/$relative" ]] || fail "missing required file: $relative"
done

for removed in \
  ".agents/skills/sol-luna" \
  ".agents/skills/orchestrate-sol-luna" \
  ".codex/agents/sol-controller.toml" \
  ".codex/agents/terra-high-worker.toml" \
  ".codex/agents/luna-max-worker.toml" \
  ".codex/agents/sol-planner.toml"; do
  [[ ! -e "$ROOT_DIR/$removed" && ! -L "$ROOT_DIR/$removed" ]] || fail "legacy runtime source still exists: $removed"
done

PYTHON_BIN=
for candidate in python3.14 python3.13 python3.12 python3.11 python3 python; do
  candidate_path=$(command -v "$candidate" 2>/dev/null || true)
  if [[ -n "$candidate_path" ]] && "$candidate_path" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' >/dev/null 2>&1; then
    PYTHON_BIN="$candidate_path"
    break
  fi
done
if [[ -z "$PYTHON_BIN" ]]; then
  fail 'Python 3.11 or newer is required'
else
  if ! "$PYTHON_BIN" - "$ROOT_DIR" <<'PY' >/dev/null 2>&1
from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path
from urllib.parse import unquote

root = Path(sys.argv[1]).resolve()


def stop() -> "NoReturn":
    raise SystemExit(1)


def text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        stop()


def frontmatter(path: Path) -> dict[str, str]:
    lines = text(path).splitlines()
    if not lines or lines[0] != "---":
        stop()
    try:
        close = lines[1:].index("---") + 1
    except ValueError:
        stop()
    values: dict[str, str] = {}
    for line in lines[1:close]:
        if not line.strip():
            continue
        match = re.fullmatch(r"([a-z_]+):\s*(.+)", line)
        if not match:
            stop()
        values[match.group(1)] = match.group(2).strip().strip('"')
    if set(values) != {"name", "description"}:
        stop()
    return values


canonical = root / ".agents/skills/codex-prove"
skill_path = canonical / "SKILL.md"
skill_meta = frontmatter(skill_path)
if skill_meta["name"] != "codex-prove" or "$codex-prove" not in skill_meta["description"]:
    stop()
if not skill_meta["description"].startswith("Use only when"):
    stop()

compat = root / ".agents/skills/sol-control"
compat_meta = frontmatter(compat / "SKILL.md")
if compat_meta["name"] != "sol-control" or "$sol-control" not in compat_meta["description"]:
    stop()

skill_text = text(skill_path)
contract_text = text(canonical / "references/orchestration.md")
runtime_text = text(canonical / "references/runtime-notes.md")
combined = "\n".join((skill_text, contract_text, runtime_text))
for marker in (
    "Planning", "Routing", "Ownership", "Verification", "Evidence",
    "ordinary small work stays", "explicit", "Requirement ID", "write_scope",
    "one owner", "live capacity", "Native Nested", "Compatibility",
    "fork_turns=\"none\"", "Fail Closed", "PASS | FIX | BLOCKED",
    "verify the verifier", "result-only", "resume packet",
    "prove-controller", "prove-complex-worker", "prove-efficient-worker",
):
    if marker.lower() not in combined.lower():
        stop()

openai_text = text(canonical / "agents/openai.yaml")
if "$codex-prove" not in openai_text or not re.search(r"(?m)^\s*allow_implicit_invocation:\s*false\s*$", openai_text):
    stop()
compat_text = text(compat / "SKILL.md") + "\n" + text(compat / "agents/openai.yaml")
if "$sol-control" not in compat_text or "$codex-prove" not in compat_text:
    stop()
if not re.search(r"(?m)^\s*allow_implicit_invocation:\s*false\s*$", compat_text):
    stop()

expected_agents = {
    "prove-controller.toml": {
        "name": "prove-controller", "model": "gpt-5.6-sol",
        "model_reasoning_effort": "high", "sandbox_mode": "read-only",
    },
    "prove-complex-worker.toml": {
        "name": "prove-complex-worker", "model": "gpt-5.6-terra",
        "model_reasoning_effort": "high", "sandbox_mode": "workspace-write",
    },
    "prove-efficient-worker.toml": {
        "name": "prove-efficient-worker", "model": "gpt-5.6-luna",
        "model_reasoning_effort": "max", "sandbox_mode": "workspace-write",
    },
}
for filename, expected in expected_agents.items():
    path = root / ".codex/agents" / filename
    try:
        data = tomllib.loads(text(path))
    except tomllib.TOMLDecodeError:
        stop()
    for key, value in expected.items():
        if data.get(key) != value:
            stop()
    instructions = data.get("developer_instructions")
    if not isinstance(instructions, str) or not instructions.strip():
        stop()
    if filename != "prove-controller.toml" and not re.search(r"do not .*?(?:spawn|create).*?subagent", instructions, re.I | re.S):
        stop()

for forbidden in ("IPZOR", "Buzz", "DeepSeek", "OpenPencil"):
    for path in (canonical, compat):
        for candidate in path.rglob("*"):
            if candidate.is_file() and re.search(forbidden, text(candidate), re.I):
                stop()

for markdown in root.rglob("*.md"):
    if ".git" in markdown.parts or markdown.is_symlink():
        continue
    source = re.sub(
        r"(?ms)^(?P<fence>`{3,}|~{3,})[^\n]*\n.*?^(?P=fence)[ \t]*$",
        "",
        text(markdown),
    )
    for match in re.finditer(r"\]\(\s*(<[^>]+>|[^)\s]+)", source):
        target = match.group(1)
        if target.startswith("<") and target.endswith(">"):
            target = target[1:-1]
        if target.startswith(("#", "http://", "https://", "mailto:")):
            continue
        target = unquote(target.split("#", 1)[0].split("?", 1)[0])
        if not target:
            continue
        candidate = (markdown.parent / target).resolve()
        try:
            candidate.relative_to(root)
        except ValueError:
            stop()
        if not candidate.exists():
            stop()

credential_patterns = (
    re.compile("AKIA" + r"[0-9A-Z]{16}"),
    re.compile("-" * 5 + r"BEGIN [A-Z0-9 ]+ PRIVATE KEY" + "-" * 5),
    re.compile(r"gh[pousr]_[A-Za-z0-9_]{20,}"),
    re.compile(r"sk-[A-Za-z0-9]{20,}"),
    re.compile(r"xox[baprs]-[A-Za-z0-9-]{20,}"),
    re.compile(r"(?i)(?:api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|password)\s*[:=]\s*['\"][A-Za-z0-9_./+=-]{16,}['\"]"),
)
for path in root.rglob("*"):
    if not path.is_file() or path.is_symlink() or ".git" in path.parts or "__pycache__" in path.parts:
        continue
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        continue
    if source and not source.endswith("\n"):
        stop()
    if any(line.endswith((" ", "\t")) for line in source.splitlines()):
        stop()
    if any(pattern.search(source) for pattern in credential_patterns):
        stop()

active_public_files = (
    root / "README.md", root / "README.en.md", root / "SECURITY.md",
    root / "CONTRIBUTING.md", root / "SUPPORT.md",
    root / ".github/ISSUE_TEMPLATE/config.yml",
)
for path in active_public_files:
    source = text(path)
    if "github.com/yehyakin/codex-sol-control" in source:
        stop()

for script_name in ("install.ps1", "validate.ps1", "uninstall.ps1"):
    source = text(root / "scripts" / script_name).lower()
    for marker in ("codex-prove", "prove-controller.toml", "prove-complex-worker.toml", "prove-efficient-worker.toml"):
        if marker not in source:
            stop()

workflow = text(root / ".github/workflows/windows-validation.yml").lower()
for marker in ("windows-latest", "windows-2022", "powershell", "pwsh", "windows-lifecycle.ps1", "unittest discover"):
    if marker not in workflow:
        stop()
PY
  then
    fail 'Python structural, TOML, Markdown, whitespace, or credential validation failed'
  fi
fi

if command -v ruby >/dev/null 2>&1; then
  if ! ruby -r yaml - "$SKILL_FILE" "$OPENAI_FILE" "$COMPAT_SKILL_FILE" "$COMPAT_OPENAI_FILE" <<'RUBY' >/dev/null 2>&1
paths = ARGV

def load_yaml(text)
  YAML.safe_load(text, permitted_classes: [], permitted_symbols: [], aliases: false)
end

def frontmatter(path)
  lines = File.readlines(path, encoding: "UTF-8")
  raise unless lines.first&.chomp == "---"
  closing = lines[1..].index { |line| line.chomp == "---" }
  raise if closing.nil?
  load_yaml(lines[1, closing].join)
end

canonical = frontmatter(paths[0])
raise unless canonical == {"name" => "codex-prove", "description" => canonical["description"]}
raise unless canonical["description"].include?("$codex-prove")

openai = load_yaml(File.read(paths[1], encoding: "UTF-8"))
raise unless openai.dig("interface", "default_prompt").include?("$codex-prove")
raise unless openai.dig("policy", "allow_implicit_invocation") == false

compat = frontmatter(paths[2])
raise unless compat["name"] == "sol-control" && compat["description"].include?("$sol-control")
compat_openai = load_yaml(File.read(paths[3], encoding: "UTF-8"))
raise unless compat_openai.dig("policy", "allow_implicit_invocation") == false
RUBY
  then
    fail 'YAML parsing or Skill interface validation failed'
  fi
else
  printf 'YAML parser: Ruby unavailable; deterministic structural checks used\n'
fi

for shell_script in "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/validate.sh" "$SCRIPT_DIR/uninstall.sh" "$SCRIPT_DIR/test.sh"; do
  bash -n "$shell_script" >/dev/null 2>&1 || fail "Bash syntax validation failed: $(basename "$shell_script")"
done

if ! (cd "$ROOT_DIR" && git diff --check -- . >/dev/null 2>&1); then
  fail 'git whitespace validation failed'
fi

PWSH_BIN=$(command -v pwsh 2>/dev/null || true)
if [[ -n "$PWSH_BIN" ]]; then
  if ! PS1_INSTALL_PATH="$SCRIPT_DIR/install.ps1" \
    PS1_VALIDATE_PATH="$SCRIPT_DIR/validate.ps1" \
    PS1_UNINSTALL_PATH="$SCRIPT_DIR/uninstall.ps1" \
    PS1_LIFECYCLE_PATH="$WINDOWS_LIFECYCLE_FILE" \
    "$PWSH_BIN" -NoLogo -NoProfile -NonInteractive -Command '
      foreach ($path in @($env:PS1_INSTALL_PATH, $env:PS1_VALIDATE_PATH, $env:PS1_UNINSTALL_PATH, $env:PS1_LIFECYCLE_PATH)) {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count -gt 0) { exit 1 }
      }
    ' >/dev/null 2>&1; then
    fail 'PowerShell AST parsing failed'
  fi
else
  printf 'PowerShell: pwsh unavailable; deterministic structural checks used\n'
fi

if (( failures != 0 )); then
  printf 'Validation: FAIL\n'
  exit 1
fi
printf 'Validation: PASS\n'
