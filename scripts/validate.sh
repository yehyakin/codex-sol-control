#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
SKILL_DIR="$ROOT_DIR/.agents/skills/orchestrate-sol-luna"
SKILL_FILE="$SKILL_DIR/SKILL.md"
OPENAI_FILE="$SKILL_DIR/agents/openai.yaml"
PROTOCOL_FILE="$SKILL_DIR/references/routing-protocol.md"
SOL_FILE="$ROOT_DIR/.codex/agents/sol-planner.toml"
LUNA_FILE="$ROOT_DIR/.codex/agents/luna-max-worker.toml"
PS_FILE="$SCRIPT_DIR/install.ps1"

failures=0
fail() {
  printf 'Validation: FAIL: %s\n' "$1"
  failures=1
}

required_files=(
  ".agents/skills/orchestrate-sol-luna/SKILL.md"
  ".agents/skills/orchestrate-sol-luna/agents/openai.yaml"
  ".agents/skills/orchestrate-sol-luna/references/routing-protocol.md"
  ".codex/agents/sol-planner.toml"
  ".codex/agents/luna-max-worker.toml"
  "scripts/install.sh"
  "scripts/validate.sh"
  "scripts/uninstall.sh"
  "scripts/install.ps1"
  "README.md"
  "NOTICE"
  "LICENSE"
)
for relative in "${required_files[@]}"; do
  [[ -f "$ROOT_DIR/$relative" ]] || fail "missing required file: $relative"
done
[[ -d "$SKILL_DIR" ]] || fail 'missing skill directory'

for command_name in bash git find; do
  command -v "$command_name" >/dev/null 2>&1 || fail "required command is unavailable: $command_name"
done

if [[ -f "$SKILL_FILE" ]]; then
  if ! head -n 1 "$SKILL_FILE" | grep -Fxq -- '---'; then
    fail 'SKILL.md has no YAML frontmatter opener'
  fi
  if ! grep -Eq '^name:[[:space:]]*orchestrate-sol-luna[[:space:]]*$' "$SKILL_FILE"; then
    fail 'SKILL.md has the wrong name'
  fi
  if ! grep -Eq '^description:[[:space:]]*Use when([[:space:]]|$)' "$SKILL_FILE"; then
    fail 'SKILL.md has no usable description'
  fi
fi

if [[ -f "$PROTOCOL_FILE" ]]; then
  for phrase in \
    'Level 0' 'Level 1' 'Level 2' 'Level 3' \
    'Native Nested' 'Compatibility' 'Fail Closed' \
    'complexity_level:' 'execution_mode:' 'reasoning:' 'acceptance_criteria:' \
    'task_graph:' 'objective:' 'agent:' 'mode:' 'dependencies:' 'inputs:' \
    'read_scope:' 'write_scope:' 'forbidden_scope:' 'deliverable:' \
    'minimum_verification:' 'command_or_procedure:' 'passing_condition:' 'required_evidence:' \
    'can_launch:' 'held_reason:' 'stop_conditions:' \
    'write_ownership:' 'conflict_risks:' 'integration_owner:' 'final_review_required:' \
    'Luna Task Packet' 'Status: PASS | BLOCKED' 'Exact verification result:' \
    'Correction Packet' 'verdict: PASS | PASS_WITH_LIMITATIONS | FAIL' \
    'required_fixes:' 'optional_improvements:' 'evidence_quality:' 'remaining_risks:'; do
    grep -Fq -- "$phrase" "$PROTOCOL_FILE" || fail "protocol is missing required structure: $phrase"
  done
fi

PYTHON_BIN=
for candidate in \
  "/opt/homebrew/opt/python@3.13/bin/python3.13" \
  "/opt/homebrew/bin/python3.13" \
  "python3" \
  "python"; do
  if [[ "$candidate" == */* ]]; then
    candidate_path="$candidate"
  else
    candidate_path=$(command -v "$candidate" 2>/dev/null || true)
  fi
  if [[ -n "$candidate_path" ]] && "$candidate_path" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' >/dev/null 2>&1; then
    PYTHON_BIN="$candidate_path"
    break
  fi
done
if [[ -z "$PYTHON_BIN" ]]; then
  fail 'Python 3.11 or newer is required for TOML validation'
else
  if ! "$PYTHON_BIN" - "$ROOT_DIR" "$SKILL_FILE" "$OPENAI_FILE" "$PROTOCOL_FILE" "$SOL_FILE" "$LUNA_FILE" "$PS_FILE" <<'PY' >/dev/null 2>&1
from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path
from urllib.parse import unquote

root = Path(sys.argv[1]).resolve()
skill_file = Path(sys.argv[2])
openai_file = Path(sys.argv[3])
protocol_file = Path(sys.argv[4])
sol_file = Path(sys.argv[5])
luna_file = Path(sys.argv[6])
ps_file = Path(sys.argv[7])

def fail() -> "NoReturn":
    raise SystemExit(1)

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail()

skill_text = read_text(skill_file)
if not skill_text.startswith("---\n"):
    fail()
frontmatter_end = skill_text.find("\n---", 4)
if frontmatter_end < 0:
    fail()
frontmatter = skill_text[4:frontmatter_end]
if not re.search(r"(?m)^name:\s*orchestrate-sol-luna\s*$", frontmatter):
    fail()
if not re.search(r"(?m)^description:\s*Use when\b", frontmatter):
    fail()

openai_text = read_text(openai_file)
for key in ("interface:", "display_name:", "short_description:", "default_prompt:"):
    if key not in openai_text:
        fail()

protocol_text = read_text(protocol_file)
for phrase in (
    "complexity_level:",
    "execution_mode:",
    "reasoning:",
    "acceptance_criteria:",
    "task_graph:",
    "objective:",
    "agent:",
    "mode:",
    "dependencies:",
    "inputs:",
    "read_scope:",
    "write_scope:",
    "forbidden_scope:",
    "deliverable:",
    "minimum_verification:",
    "command_or_procedure:",
    "passing_condition:",
    "required_evidence:",
    "can_launch:",
    "held_reason:",
    "stop_conditions:",
    "write_ownership:",
    "conflict_risks:",
    "integration_owner:",
    "final_review_required:",
    "Luna Task Packet",
    "Exact verification result:",
    "Correction Packet",
    "required_fixes:",
    "optional_improvements:",
    "evidence_quality:",
    "remaining_risks:",
):
    if phrase not in protocol_text:
        fail()

expected = {
    sol_file: {
        "name": "sol-planner",
        "model": "gpt-5.6-sol",
        "model_reasoning_effort": "high",
        "sandbox_mode": "read-only",
    },
    luna_file: {
        "name": "luna-max-worker",
        "model": "gpt-5.6-luna",
        "model_reasoning_effort": "max",
        "sandbox_mode": "workspace-write",
    },
}
for path, values in expected.items():
    try:
        with path.open("rb") as handle:
            data = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError):
        fail()
    for key, value in values.items():
        if data.get(key) != value:
            fail()
    if not isinstance(data.get("developer_instructions"), str) or not data["developer_instructions"].strip():
        fail()

luna_instructions = expected[luna_file] and tomllib.load(luna_file.open("rb"))["developer_instructions"]
if not re.search(r"\bdo not (?:spawn|create).*subagent", luna_instructions, re.IGNORECASE | re.DOTALL):
    fail()

for markdown in root.rglob("*.md"):
    if ".git" in markdown.parts or markdown.is_symlink():
        continue
    text = read_text(markdown)
    for match in re.finditer(r"\]\(\s*(<[^>]+>|[^)\s]+)", text):
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
            fail()
        if not candidate.exists():
            fail()

for path in root.rglob("*"):
    if not path.is_file() or path.is_symlink() or ".git" in path.parts or "__pycache__" in path.parts:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        continue
    for line in text.splitlines():
        if line.endswith((" ", "\t")):
            fail()
    if text and not text.endswith("\n"):
        fail()

for path in root.rglob("*"):
    if not path.is_file() or path.is_symlink() or ".git" in path.parts or "__pycache__" in path.parts:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        continue
    credential_patterns = (
        ("aws-access-key", re.compile("AKIA" + r"[0-9A-Z]{16}")),
        ("private-key", re.compile("-" * 5 + r"BEGIN [A-Z0-9 ]+ PRIVATE KEY" + "-" * 5)),
        ("github-token", re.compile(r"gh[pousr]_" + r"[A-Za-z0-9_]{20,}")),
        ("openai-token", re.compile(r"sk-" + r"[A-Za-z0-9]{20,}")),
        ("slack-token", re.compile(r"xox[baprs]-" + r"[A-Za-z0-9-]{20,}")),
        (
            "generic-secret",
            re.compile(
                r"""(?i)(?:api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|password)\s*[:=]\s*['"][A-Za-z0-9_./+=-]{16,}['"]"""
            ),
        ),
    )
    for _, pattern in credential_patterns:
        if pattern.search(text):
            fail()
            break

for forbidden in ("IPZOR", "Buzz", "DeepSeek", "OpenPencil", "gpt-5.6-terra"):
    for path in skill_file.parent.rglob("*"):
        if path.is_file() and not path.is_symlink():
            try:
                if re.search(re.escape(forbidden), path.read_text(encoding="utf-8"), re.IGNORECASE):
                    fail()
            except (OSError, UnicodeDecodeError):
                fail()

ps_text = read_text(ps_file)
for marker in (
    "ORCHESTRATE_HOME",
    "validate.sh",
    "config.toml",
    "sol-planner.toml",
    "luna-max-worker.toml",
    "Backup path:",
    "Move-Item",
    "rollback",
):
    if marker not in ps_text:
        fail()
PY
  then
    fail 'Python structural, TOML, Markdown, whitespace, or credential validation failed'
  fi
fi

if command -v ruby >/dev/null 2>&1; then
  if ! ruby -r yaml - "$SKILL_FILE" "$OPENAI_FILE" <<'RUBY' >/dev/null 2>&1
skill_path = ARGV[0]
openai_path = ARGV[1]

def load_yaml(text)
  YAML.safe_load(text, permitted_classes: [], permitted_symbols: [], aliases: false)
end

skill_lines = File.readlines(skill_path, encoding: "UTF-8")
raise unless skill_lines.first&.chomp == "---"
closing = skill_lines[1..].index { |line| line.chomp == "---" }
raise if closing.nil?
skill = load_yaml(skill_lines[1, closing].join)
raise unless skill.is_a?(Hash)
raise unless skill["name"] == "orchestrate-sol-luna"
raise unless skill["description"].is_a?(String) && skill["description"].start_with?("Use when")

openai = load_yaml(File.read(openai_path, encoding: "UTF-8"))
interface = openai.is_a?(Hash) ? openai["interface"] : nil
raise unless interface.is_a?(Hash)
%w[display_name short_description default_prompt].each do |key|
  raise unless interface[key].is_a?(String) && !interface[key].strip.empty?
end
RUBY
  then
    fail 'YAML parsing or interface validation failed'
  fi
else
  printf 'YAML parser: Ruby not found; structural checks used\n'
fi

for shell_script in "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/validate.sh" "$SCRIPT_DIR/uninstall.sh"; do
  if [[ -f "$shell_script" ]] && ! bash -n "$shell_script" >/dev/null 2>&1; then
    fail "Bash syntax validation failed: $(basename "$shell_script")"
  fi
done

if ! (cd "$ROOT_DIR" && git diff --check -- . >/dev/null 2>&1); then
  fail 'git whitespace validation failed'
fi

PWSH_BIN=$(command -v pwsh 2>/dev/null || true)
if [[ -n "$PWSH_BIN" ]]; then
  printf 'PowerShell: pwsh AST parse\n'
  if ! PS1_VALIDATE_PATH="$PS_FILE" "$PWSH_BIN" -NoLogo -NoProfile -NonInteractive -Command '
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
      $env:PS1_VALIDATE_PATH,
      [ref]$tokens,
      [ref]$errors
    ) | Out-Null
    if ($errors.Count -gt 0) { exit 1 }
  ' >/dev/null 2>&1; then
    fail 'PowerShell AST parsing failed'
  fi
else
  printf 'PowerShell: pwsh not found; deterministic structural checks used\n'
fi

if (( failures != 0 )); then
  printf 'Validation: FAIL\n'
  exit 1
fi
printf 'Validation: PASS\n'
