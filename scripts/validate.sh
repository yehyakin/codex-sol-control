#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
SKILL_ROOT="$ROOT_DIR/.agents/skills/sol-control"
SKILL_FILE="$SKILL_ROOT/SKILL.md"
OPENAI_FILE="$SKILL_ROOT/agents/openai.yaml"
COMPAT_SKILL_ROOT="$ROOT_DIR/.agents/skills/sol-luna"
COMPAT_SKILL_FILE="$COMPAT_SKILL_ROOT/SKILL.md"
COMPAT_OPENAI_FILE="$COMPAT_SKILL_ROOT/agents/openai.yaml"
SOL_FILE="$ROOT_DIR/.codex/agents/sol-controller.toml"
LUNA_FILE="$ROOT_DIR/.codex/agents/luna-max-worker.toml"
TERRA_FILE="$ROOT_DIR/.codex/agents/terra-high-worker.toml"
PS_FILE="$SCRIPT_DIR/install.ps1"
PS_VALIDATE_FILE="$SCRIPT_DIR/validate.ps1"
PS_UNINSTALL_FILE="$SCRIPT_DIR/uninstall.ps1"
WINDOWS_LIFECYCLE_FILE="$ROOT_DIR/tests/windows-lifecycle.ps1"
WINDOWS_WORKFLOW_FILE="$ROOT_DIR/.github/workflows/windows-validation.yml"
TEST_ENTRYPOINT_FILE="$SCRIPT_DIR/test.sh"
AB_BENCHMARK_FILE="$SCRIPT_DIR/benchmark_ab.py"
AB_MANIFEST_FILE="$ROOT_DIR/tests/fixtures/v050-ab-benchmark.json"
POSIX_WORKFLOW_FILE="$ROOT_DIR/.github/workflows/posix-validation.yml"
BUG_TEMPLATE_FILE="$ROOT_DIR/.github/ISSUE_TEMPLATE/bug_report.yml"
FEATURE_TEMPLATE_FILE="$ROOT_DIR/.github/ISSUE_TEMPLATE/feature_request.yml"
ISSUE_CONFIG_FILE="$ROOT_DIR/.github/ISSUE_TEMPLATE/config.yml"

failures=0
fail() {
  printf 'Validation: FAIL: %s\n' "$1"
  failures=1
}

required_files=(
  ".agents/skills/sol-control/SKILL.md"
  ".agents/skills/sol-control/agents/openai.yaml"
  ".agents/skills/sol-control/references/orchestration.md"
  ".agents/skills/sol-luna/SKILL.md"
  ".agents/skills/sol-luna/agents/openai.yaml"
  ".codex/agents/sol-controller.toml"
  ".codex/agents/luna-max-worker.toml"
  ".codex/agents/terra-high-worker.toml"
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
  "docs/assets/readme/hero-zh.svg"
  "docs/assets/readme/hero-en.svg"
  "docs/assets/readme/control-plane-zh.svg"
  "docs/assets/readme/control-plane-en.svg"
  "tests/windows-lifecycle.ps1"
  "tests/test_release_engineering.py"
  "tests/test_v050_benchmark.py"
  "tests/test_v050_evidence_control.py"
  "tests/fixtures/v050-ab-benchmark.json"
  "tests/v050-ab-benchmark.md"
  "tests/v050-live-smoke.md"
  "SOL_CONTROL_V050_IMPLEMENTATION_REPORT.md"
  ".github/workflows/windows-validation.yml"
  ".github/workflows/posix-validation.yml"
  "NOTICE"
  "LICENSE"
)
for relative in "${required_files[@]}"; do
  [[ -f "$ROOT_DIR/$relative" ]] || fail "missing required file: $relative"
done

grep -Fq 'bash scripts/test.sh' "$ROOT_DIR/CONTRIBUTING.md" || fail 'CONTRIBUTING.md is missing the test command'
grep -Fq 'Apache License 2.0' "$ROOT_DIR/CONTRIBUTING.md" || fail 'CONTRIBUTING.md is missing the contribution license'
grep -Fq 'Contributor Covenant' "$ROOT_DIR/CODE_OF_CONDUCT.md" || fail 'CODE_OF_CONDUCT.md is missing its upstream attribution'
grep -Fq '/security/advisories/new' "$ROOT_DIR/SECURITY.md" || fail 'SECURITY.md is missing private vulnerability reporting'
grep -Fq 'Do not open a public issue' "$ROOT_DIR/SECURITY.md" || fail 'SECURITY.md is missing its public disclosure warning'
grep -Fq 'SUPPORT.md' "$ROOT_DIR/README.md" || fail 'README.md is missing the support entry'
grep -Fq 'SUPPORT.md' "$ROOT_DIR/README.en.md" || fail 'README.en.md is missing the support entry'
grep -Fq 'blank_issues_enabled: false' "$ISSUE_CONFIG_FILE" || fail 'issue template config permits blank issues'
grep -Fq 'Security vulnerability' "$ISSUE_CONFIG_FILE" || fail 'issue template config is missing private security routing'
grep -Fq 'Validation and evidence' "$ROOT_DIR/.github/pull_request_template.md" || fail 'pull request template is missing evidence guidance'
[[ -d "$SKILL_ROOT" ]] || fail 'missing canonical v0.4 skill directory'
[[ -d "$COMPAT_SKILL_ROOT" ]] || fail 'missing v0.4 compatibility skill directory'

RUNTIME_FILE=
if [[ -f "$SKILL_ROOT/runtime-notes.md" ]]; then
  RUNTIME_FILE="$SKILL_ROOT/runtime-notes.md"
elif [[ -f "$SKILL_ROOT/references/runtime-notes.md" ]]; then
  RUNTIME_FILE="$SKILL_ROOT/references/runtime-notes.md"
else
  fail 'missing runtime-notes.md in the canonical v0.4 skill'
fi

for command_name in bash git find; do
  command -v "$command_name" >/dev/null 2>&1 || fail "required command is unavailable: $command_name"
done

if [[ -f "$SKILL_FILE" ]]; then
  if ! head -n 1 "$SKILL_FILE" | tr -d '\r' | grep -Fxq -- '---'; then
    fail 'SKILL.md has no YAML frontmatter opener'
  fi
  if ! grep -Eq '^name:[[:space:]]*sol-control[[:space:]]*$' "$SKILL_FILE"; then
    fail 'SKILL.md has the wrong name'
  fi
  if ! grep -Eq '^description:[[:space:]]*Use when([[:space:]]|$)' "$SKILL_FILE"; then
    fail 'SKILL.md has no usable description'
  fi
fi

if [[ -f "$COMPAT_SKILL_FILE" ]]; then
  if ! grep -Eq '^name:[[:space:]]*sol-luna[[:space:]]*$' "$COMPAT_SKILL_FILE"; then
    fail 'compatibility SKILL.md has the wrong name'
  fi
  [[ "$(wc -l < "$COMPAT_SKILL_FILE" | tr -d ' ')" -le 45 ]] || fail 'compatibility SKILL.md is not thin'
  grep -Fq '$sol-control' "$COMPAT_SKILL_FILE" || fail 'compatibility SKILL.md does not redirect to $sol-control'
  grep -Fq 'v0.5.0' "$COMPAT_SKILL_FILE" || fail 'compatibility SKILL.md has no removal milestone'
fi

if [[ -f "$OPENAI_FILE" ]]; then
  for marker in \
    '^interface:[[:space:]]*$' \
    '^[[:space:]]+display_name:[[:space:]]*[^[:space:]].*$' \
    '^[[:space:]]+short_description:[[:space:]]*[^[:space:]].*$' \
    '^[[:space:]]+default_prompt:[[:space:]]*[^[:space:]].*$'; do
    grep -Eq "$marker" "$OPENAI_FILE" || fail "openai.yaml is missing: $marker"
  done
fi

if [[ -f "$OPENAI_FILE" ]]; then
  grep -Fq '$sol-control' "$OPENAI_FILE" || fail 'canonical openai.yaml has the wrong invocation'
  grep -Eq 'allow_implicit_invocation:[[:space:]]*false' "$OPENAI_FILE" || fail 'canonical openai.yaml permits implicit invocation'
fi
if [[ -f "$COMPAT_OPENAI_FILE" ]]; then
  grep -Fq '$sol-luna' "$COMPAT_OPENAI_FILE" || fail 'compatibility openai.yaml has the wrong invocation'
  grep -Fq '$sol-control' "$COMPAT_OPENAI_FILE" || fail 'compatibility openai.yaml does not redirect to $sol-control'
  grep -Eq 'allow_implicit_invocation:[[:space:]]*false' "$COMPAT_OPENAI_FILE" || fail 'compatibility openai.yaml permits implicit invocation'
fi

PYTHON_BIN=
for candidate in \
  "/opt/homebrew/opt/python@3.14/bin/python3.14" \
  "/opt/homebrew/bin/python3.14" \
  "python3.14" \
  "/opt/homebrew/opt/python@3.13/bin/python3.13" \
  "/opt/homebrew/bin/python3.13" \
  "/opt/homebrew/opt/python@3.12/bin/python3.12" \
  "/opt/homebrew/bin/python3.12" \
  "python3.12" \
  "/opt/homebrew/opt/python@3.11/bin/python3.11" \
  "/opt/homebrew/bin/python3.11" \
  "python3.11" \
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
if ! "$PYTHON_BIN" -c 'import pathlib, sys; compile(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"), sys.argv[1], "exec")' "$AB_BENCHMARK_FILE" >/dev/null 2>&1; then
  fail 'benchmark_ab.py syntax validation failed'
fi
if ! "$PYTHON_BIN" "$AB_BENCHMARK_FILE" validate "$AB_MANIFEST_FILE" >/dev/null 2>&1; then
  fail 'v0.5 A/B benchmark manifest validation failed'
fi
if ! "$PYTHON_BIN" - "$ROOT_DIR" "$SKILL_FILE" "$OPENAI_FILE" "$RUNTIME_FILE" "$SOL_FILE" "$LUNA_FILE" "$TERRA_FILE" "$PS_FILE" "$PS_VALIDATE_FILE" "$PS_UNINSTALL_FILE" "$WINDOWS_LIFECYCLE_FILE" "$WINDOWS_WORKFLOW_FILE" "$TEST_ENTRYPOINT_FILE" "$POSIX_WORKFLOW_FILE" "$COMPAT_SKILL_FILE" "$COMPAT_OPENAI_FILE" <<'PY' >/dev/null 2>&1
from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path
from urllib.parse import unquote

root = Path(sys.argv[1]).resolve()
skill_file = Path(sys.argv[2])
openai_file = Path(sys.argv[3])
runtime_file = Path(sys.argv[4]) if sys.argv[4] else None
sol_file = Path(sys.argv[5])
luna_file = Path(sys.argv[6])
terra_file = Path(sys.argv[7])
ps_file = Path(sys.argv[8])
ps_validate_file = Path(sys.argv[9])
ps_uninstall_file = Path(sys.argv[10])
windows_lifecycle_file = Path(sys.argv[11])
windows_workflow_file = Path(sys.argv[12])
test_entrypoint_file = Path(sys.argv[13])
posix_workflow_file = Path(sys.argv[14])
compat_skill_file = Path(sys.argv[15])
compat_openai_file = Path(sys.argv[16])


def fail() -> "NoReturn":
    raise SystemExit(1)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail()


skill_text = read_text(skill_file)
lines = skill_text.splitlines()
if not lines or lines[0] != "---":
    fail()
try:
    closing = lines[1:].index("---") + 1
except ValueError:
    fail()
frontmatter = "\n".join(lines[1:closing])
if not re.search(r"(?m)^name:\s*sol-control\s*$", frontmatter):
    fail()
if not re.search(r"(?m)^description:\s*Use when\b", frontmatter):
    fail()

if runtime_file is None or not runtime_file.is_file():
    fail()
contract_text = skill_text + "\n" + read_text(runtime_file)
contract_patterns = (
    r"(?is)ordinary\s+simple\s+(?:work|tasks?).{0,120}\bdirect\b",
    r"(?is)planning[- ]only.{0,120}zero\s+Luna",
    r"(?m)^\s*goal:\s*",
    r"(?m)^\s*done_when:\s*",
    r"(?m)^\s*tasks:\s*",
    r"(?m)^\s*stages:\s*",
    r"(?m)^\s*Task ID:\s*",
    r"(?m)^\s*Task:\s*",
    r"(?m)^\s*Write scope:\s*",
    r"(?m)^\s*Do not touch:\s*",
    r"(?m)^\s*Expected result:\s*",
    r"(?m)^\s*Verification:\s*",
    r"(?i)Context:\s*.*optional",
    r"(?m)^\s*Status:\s*PASS\s*\|\s*BLOCKED\s*$",
    r"(?m)^\s*Summary:\s*",
    r"(?m)^\s*Changed:\s*",
    r"(?m)^\s*Evidence:\s*",
    r"(?m)^\s*Blocker:\s*",
    r"(?i)PASS\s*\|\s*FIX\s*\|\s*BLOCKED",
    r"(?i)at\s+most\s+one[^\n]*(?:focused\s+)?fix",
)
for pattern in contract_patterns:
    if not re.search(pattern, contract_text):
        fail()

for phrase in (
    "one file",
    "one owner",
    "shared integration",
    "live capacity",
    "batch",
    "exact model",
    "reasoning effort",
    "Fail Closed",
):
    if phrase.lower() not in contract_text.lower():
        fail()

for path, expected in (
    (
        sol_file,
        {
            "name": "sol-controller",
            "model": "gpt-5.6-sol",
            "model_reasoning_effort": "high",
            "sandbox_mode": "read-only",
        },
    ),
    (
        luna_file,
        {
            "name": "luna-max-worker",
            "model": "gpt-5.6-luna",
            "model_reasoning_effort": "max",
            "sandbox_mode": "workspace-write",
        },
    ),
    (
        terra_file,
        {
            "name": "terra-high-worker",
            "model": "gpt-5.6-terra",
            "model_reasoning_effort": "high",
            "sandbox_mode": "workspace-write",
        },
    ),
):
    try:
        with path.open("rb") as handle:
            data = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError):
        fail()
    for key, value in expected.items():
        if data.get(key) != value:
            fail()
    if not isinstance(data.get("developer_instructions"), str) or not data["developer_instructions"].strip():
        fail()

try:
    luna_instructions = tomllib.load(luna_file.open("rb"))["developer_instructions"]
except (OSError, KeyError, tomllib.TOMLDecodeError):
    fail()
if not re.search(r"\bdo not (?:spawn|create).*subagent", luna_instructions, re.IGNORECASE | re.DOTALL):
    fail()
try:
    terra_instructions = tomllib.load(terra_file.open("rb"))["developer_instructions"]
except (OSError, KeyError, tomllib.TOMLDecodeError):
    fail()
if not re.search(r"\bdo not (?:spawn|create).*subagent", terra_instructions, re.IGNORECASE | re.DOTALL):
    fail()

if not openai_file.is_file():
    fail()
openai_text = read_text(openai_file)
for marker in (
    "interface:",
    "display_name:",
    "short_description:",
    "default_prompt:",
):
    if marker not in openai_text:
        fail()
if "$sol-control" not in openai_text or not re.search(r"(?m)^\s*allow_implicit_invocation:\s*false\s*$", openai_text):
    fail()

compat_skill_text = read_text(compat_skill_file)
if len(compat_skill_text.splitlines()) > 45:
    fail()
if not re.search(r"(?m)^name:\s*sol-luna\s*$", compat_skill_text):
    fail()
for marker in ("$sol-luna", "$sol-control", "v0.5.0"):
    if marker not in compat_skill_text:
        fail()
compat_openai_text = read_text(compat_openai_file)
for marker in ("$sol-luna", "$sol-control", "allow_implicit_invocation: false"):
    if marker not in compat_openai_text:
        fail()

for markdown in root.rglob("*.md"):
    if ".git" in markdown.parts or markdown.is_symlink():
        continue
    text = read_text(markdown)
    text = re.sub(
        r"(?ms)^(?P<fence>`{3,}|~{3,})[^\n]*\n.*?^(?P=fence)[ \t]*$",
        "",
        text,
    )
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

credential_patterns = (
    re.compile("AKIA" + r"[0-9A-Z]{16}"),
    re.compile("-" * 5 + r"BEGIN [A-Z0-9 ]+ PRIVATE KEY" + "-" * 5),
    re.compile(r"gh[pousr]_" + r"[A-Za-z0-9_]{20,}"),
    re.compile(r"sk-" + r"[A-Za-z0-9]{20,}"),
    re.compile(r"xox[baprs]-" + r"[A-Za-z0-9-]{20,}"),
    re.compile(
        r"""(?i)(?:api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|password)\s*[:=]\s*['\"][A-Za-z0-9_./+=-]{16,}['\"]"""
    ),
)
for path in root.rglob("*"):
    if not path.is_file() or path.is_symlink() or ".git" in path.parts or "__pycache__" in path.parts:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        continue
    if any(pattern.search(text) for pattern in credential_patterns):
        fail()

for forbidden in ("IPZOR", "Buzz", "DeepSeek", "OpenPencil"):
    for path in skill_file.parent.rglob("*"):
        if path.is_file() and not path.is_symlink():
            try:
                if re.search(re.escape(forbidden), read_text(path), re.IGNORECASE):
                    fail()
            except (OSError, UnicodeDecodeError):
                fail()

ps_text = read_text(ps_file)
for marker in (
    "ORCHESTRATE_HOME",
    "validate.sh",
    "config.toml",
    ".agents/skills/sol-control",
    ".agents/skills/sol-luna",
    "sol-controller.toml",
    "orchestrate-sol-luna",
    "sol-planner.toml",
    "luna-max-worker.toml",
    "terra-high-worker.toml",
    "Move-Item",
    "transaction",
    "rollback",
    "SHA256",
):
    if marker.lower() not in ps_text.lower():
        fail()

for path, markers in (
    (
        ps_validate_file,
        (
            "#requires -Version 5.1",
            "Get-Content",
            "Parser]::ParseFile",
            "Markdown",
            "SVG",
            "PowerShell syntax",
        ),
    ),
    (
        ps_uninstall_file,
        (
            "RestoreLatest",
            "SHA256",
            "install-state",
            "-LiteralPath",
            "config.toml",
        ),
    ),
    (
        windows_lifecycle_file,
        (
            "#requires -Version 5.1",
            "Set-StrictMode",
            "scripts/install.ps1",
            "scripts/validate.ps1",
            "scripts/uninstall.ps1",
            "Invoke-LifecycleScript",
            "Invoke-CheckProcess",
            "Test-CheckModeReadOnly",
            "RestoreLatest",
            "Windows lifecycle contract: PASS",
        ),
    ),
    (
        windows_workflow_file,
        (
            "windows-latest",
            "windows-2022",
            "powershell",
            "pwsh",
            "scripts/install.ps1",
            "scripts/validate.ps1",
            "scripts/uninstall.ps1",
            "tests/windows-lifecycle.ps1",
            "unittest discover",
        ),
    ),
    (
        test_entrypoint_file,
        (
            "#!/usr/bin/env bash",
            "Python 3.11",
            "unittest discover",
        ),
    ),
    (
        posix_workflow_file,
        (
            "macos-latest",
            "ubuntu-latest",
            "3.11",
            "3.13",
            "scripts/test.sh",
            "install.sh --check",
        ),
    ),
):
    text = read_text(path).lower()
    for marker in markers:
        if marker.lower() not in text:
            fail()
PY
  then
    fail 'Python structural, TOML, Markdown, whitespace, or credential validation failed'
  fi
fi

if command -v ruby >/dev/null 2>&1; then
  if ! ruby -r yaml - "$SKILL_FILE" "$OPENAI_FILE" "$COMPAT_SKILL_FILE" "$COMPAT_OPENAI_FILE" "$BUG_TEMPLATE_FILE" "$FEATURE_TEMPLATE_FILE" "$ISSUE_CONFIG_FILE" <<'RUBY' >/dev/null 2>&1
skill_path = ARGV[0]
openai_path = ARGV[1]
compat_skill_path = ARGV[2]
compat_openai_path = ARGV[3]
bug_template_path = ARGV[4]
feature_template_path = ARGV[5]
issue_config_path = ARGV[6]

def load_yaml(text)
  YAML.safe_load(text, permitted_classes: [], permitted_symbols: [], aliases: false)
end

skill_lines = File.readlines(skill_path, encoding: "UTF-8")
raise unless skill_lines.first&.chomp == "---"
closing = skill_lines[1..].index { |line| line.chomp == "---" }
raise if closing.nil?
skill = load_yaml(skill_lines[1, closing].join)
raise unless skill.is_a?(Hash)
raise unless skill["name"] == "sol-control"
raise unless skill["description"].is_a?(String) && skill["description"].start_with?("Use when")

openai = load_yaml(File.read(openai_path, encoding: "UTF-8"))
interface = openai.is_a?(Hash) ? openai["interface"] : nil
raise unless interface.is_a?(Hash)
%w[display_name short_description default_prompt].each do |key|
  raise unless interface[key].is_a?(String) && !interface[key].strip.empty?
end
raise unless interface["default_prompt"].include?("$sol-control")
raise unless openai.dig("policy", "allow_implicit_invocation") == false

compat_lines = File.readlines(compat_skill_path, encoding: "UTF-8")
raise unless compat_lines.length <= 45
raise unless compat_lines.first&.chomp == "---"
compat_closing = compat_lines[1..].index { |line| line.chomp == "---" }
raise if compat_closing.nil?
compat_skill = load_yaml(compat_lines[1, compat_closing].join)
raise unless compat_skill.is_a?(Hash) && compat_skill["name"] == "sol-luna"
compat_text = compat_lines.join
%w[$sol-luna $sol-control v0.5.0].each { |marker| raise unless compat_text.include?(marker) }

compat_openai = load_yaml(File.read(compat_openai_path, encoding: "UTF-8"))
raise unless compat_openai.dig("policy", "allow_implicit_invocation") == false
compat_prompt = compat_openai.dig("interface", "default_prompt")
raise unless compat_prompt.is_a?(String) && compat_prompt.include?("$sol-luna") && compat_prompt.include?("$sol-control")

[bug_template_path, feature_template_path].each do |path|
  form = load_yaml(File.read(path, encoding: "UTF-8"))
  raise unless form.is_a?(Hash)
  raise unless form["name"].is_a?(String) && !form["name"].strip.empty?
  raise unless form["description"].is_a?(String) && !form["description"].strip.empty?
  raise unless form["body"].is_a?(Array) && !form["body"].empty?
end

issue_config = load_yaml(File.read(issue_config_path, encoding: "UTF-8"))
raise unless issue_config.is_a?(Hash)
raise unless issue_config["blank_issues_enabled"] == false
raise unless issue_config["contact_links"].is_a?(Array) && !issue_config["contact_links"].empty?
RUBY
  then
    fail 'YAML parsing or interface validation failed'
  fi
else
  printf 'YAML parser: Ruby not found; structural checks used\n'
fi

for shell_script in "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/validate.sh" "$SCRIPT_DIR/uninstall.sh" "$TEST_ENTRYPOINT_FILE"; do
  if [[ -f "$shell_script" ]] && ! bash -n "$shell_script" >/dev/null 2>&1; then
    fail "Bash syntax validation failed: $(basename "$shell_script")"
  fi
done

if ! (cd "$ROOT_DIR" && git diff --check -- . >/dev/null 2>&1); then
  fail 'git whitespace validation failed'
fi

PWSH_BIN=$(command -v pwsh 2>/dev/null || true)
if [[ -n "$PWSH_BIN" ]]; then
  printf 'PowerShell: pwsh AST parse (install, validate, uninstall, lifecycle)\n'
  if ! PS1_INSTALL_PATH="$PS_FILE" \
    PS1_VALIDATE_PATH="$PS_VALIDATE_FILE" \
    PS1_UNINSTALL_PATH="$PS_UNINSTALL_FILE" \
    PS1_LIFECYCLE_PATH="$WINDOWS_LIFECYCLE_FILE" \
    "$PWSH_BIN" -NoLogo -NoProfile -NonInteractive -Command '
      $paths = @(
        $env:PS1_INSTALL_PATH,
        $env:PS1_VALIDATE_PATH,
        $env:PS1_UNINSTALL_PATH,
        $env:PS1_LIFECYCLE_PATH
      )
      foreach ($path in $paths) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
          $path,
          [ref]$tokens,
          [ref]$errors
        ) | Out-Null
        if ($null -ne $errors -and $errors.Count -gt 0) { exit 1 }
      }
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
