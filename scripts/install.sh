#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)

die() {
  printf 'install.sh: %s\n' "$1" >&2
  exit 1
}

command -v uname >/dev/null 2>&1 || die 'uname is required for platform detection'
platform=$(uname -s)
case "$platform" in
  Darwin|Linux)
    ;;
  *)
    die "unsupported platform: $platform"
    ;;
esac

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 1
  fi
}

sha256_text_stream() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    return 1
  fi
}

sha256_tree() {
  local directory="$1"
  local item relative
  (
    CDPATH= cd -- "$directory"
    while IFS= read -r item; do
      relative=${item#./}
      if [[ -L "$item" ]]; then
        printf 'L\t%s\t%s\n' "$relative" "$(readlink "$item")"
      elif [[ -d "$item" ]]; then
        printf 'D\t%s\n' "$relative"
      elif [[ -f "$item" ]]; then
        printf 'F\t%s\t%s\n' "$relative" "$(sha256_file "$item")"
      else
        printf 'O\t%s\n' "$relative"
      fi
    done < <(find . -mindepth 1 -print | LC_ALL=C sort)
  ) | sha256_text_stream
}

state_value() {
  local key="$1"
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, length(wanted) + 2); found = 1 } END { if (!found) exit 1 }' "$state_file"
}

validate_installed_state() {
  [[ -f "$state_file" && ! -L "$state_file" ]] || return 1

  local recorded_backup recorded_skill recorded_sol recorded_luna
  recorded_backup=$(state_value backup_id) || return 1
  [[ "$recorded_backup" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [[ -d "$state_root/backups/$recorded_backup" && ! -L "$state_root/backups/$recorded_backup" ]] || return 1

  recorded_skill=$(state_value skill_sha256) || return 1
  recorded_sol=$(state_value sol_sha256) || return 1
  recorded_luna=$(state_value luna_sha256) || return 1
  [[ "$recorded_skill" =~ ^[0-9a-f]{64}$ ]] || return 1
  [[ "$recorded_sol" =~ ^[0-9a-f]{64}$ ]] || return 1
  [[ "$recorded_luna" =~ ^[0-9a-f]{64}$ ]] || return 1

  [[ -d "$skill_target" && ! -L "$skill_target" ]] || return 1
  [[ -f "$sol_target" && ! -L "$sol_target" ]] || return 1
  [[ -f "$luna_target" && ! -L "$luna_target" ]] || return 1
  [[ "$(sha256_tree "$skill_target")" == "$recorded_skill" ]] || return 1
  [[ "$(sha256_file "$sol_target")" == "$recorded_sol" ]] || return 1
  [[ "$(sha256_file "$luna_target")" == "$recorded_luna" ]] || return 1
}

raw_home=${ORCHESTRATE_HOME:-${HOME:-}}
[[ -n "$raw_home" ]] || die 'ORCHESTRATE_HOME or HOME is required'
[[ "$raw_home" == /* ]] || die 'ORCHESTRATE_HOME must be an absolute path'
[[ "$raw_home" != / ]] || die 'refusing the filesystem root as ORCHESTRATE_HOME'

if [[ -L "$raw_home" ]]; then
  die 'ORCHESTRATE_HOME must not be a symbolic link'
fi
if [[ ! -e "$raw_home" ]]; then
  mkdir -p "$raw_home" || die 'cannot create ORCHESTRATE_HOME'
fi
[[ -d "$raw_home" ]] || die 'ORCHESTRATE_HOME must be a directory'
base_dir=$(CDPATH= cd -- "$raw_home" && pwd -P) || die 'cannot resolve ORCHESTRATE_HOME'
[[ "$base_dir" != / ]] || die 'refusing the filesystem root as ORCHESTRATE_HOME'

skill_source="$REPO_ROOT/.agents/skills/orchestrate-sol-luna"
sol_source="$REPO_ROOT/.codex/agents/sol-planner.toml"
luna_source="$REPO_ROOT/.codex/agents/luna-max-worker.toml"

skill_target="$base_dir/.agents/skills/orchestrate-sol-luna"
codex_dir="$base_dir/.codex"
agents_dir="$codex_dir/agents"
sol_target="$agents_dir/sol-planner.toml"
luna_target="$agents_dir/luna-max-worker.toml"
state_root="$codex_dir/orchestrate-sol-luna"
state_file="$state_root/install-state"

for directory in "$base_dir/.agents" "$base_dir/.agents/skills" "$codex_dir" "$agents_dir" "$state_root" "$state_root/backups"; do
  if [[ -L "$directory" ]]; then
    die 'refusing a symbolic-link directory in the install path'
  fi
  if [[ -e "$directory" && ! -d "$directory" ]]; then
    die 'an install parent is not a directory'
  fi
done
mkdir -p "$base_dir/.agents/skills" "$agents_dir" "$state_root/backups"

[[ -d "$skill_source" && ! -L "$skill_source" ]] || die 'source skill directory is missing'
[[ -f "$sol_source" && ! -L "$sol_source" ]] || die 'source Sol agent is missing'
[[ -f "$luna_source" && ! -L "$luna_source" ]] || die 'source Luna agent is missing'

for command_name in bash find awk sort; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is unavailable: $command_name"
done
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  die 'a SHA-256 utility is unavailable'
fi

validation_log=$(mktemp "${TMPDIR:-/tmp}/orchestrate-sol-luna-validation.XXXXXX") || die 'cannot create a validation temporary file'
validation_cleanup() {
  if [[ -n "${validation_log:-}" ]]; then
    rm -f "$validation_log" || true
  fi
}
trap validation_cleanup EXIT
if ! bash "$SCRIPT_DIR/validate.sh" >"$validation_log" 2>&1; then
  die 'source validation failed'
fi
validation_cleanup
trap - EXIT

if path_exists "$state_file"; then
  [[ ! -L "$state_file" ]] || die 'install state is a symbolic link'
  validate_installed_state || die 'existing installed copies do not match install state'
fi

if path_exists "$skill_target"; then
  [[ -d "$skill_target" && ! -L "$skill_target" ]] || die 'existing skill target has an unsafe type'
fi
for target in "$sol_target" "$luna_target"; do
  if path_exists "$target"; then
    [[ -f "$target" && ! -L "$target" ]] || die 'existing agent target has an unsafe type'
  fi
done
config_target="$codex_dir/config.toml"
if path_exists "$config_target"; then
  [[ -f "$config_target" && ! -L "$config_target" ]] || die 'existing config.toml has an unsafe type'
fi

backup_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
backup_dir="$state_root/backups/$backup_id"
while path_exists "$backup_dir"; do
  backup_id="$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"
  backup_dir="$state_root/backups/$backup_id"
done
mkdir "$backup_dir"

skill_presence=absent
skill_sha256=
if path_exists "$skill_target"; then
  skill_presence=present
  skill_sha256=$(sha256_tree "$skill_target") || die 'cannot hash the existing skill'
  cp -a "$skill_target" "$backup_dir/skill"
fi

sol_presence=absent
sol_sha256=
if path_exists "$sol_target"; then
  sol_presence=present
  sol_sha256=$(sha256_file "$sol_target") || die 'cannot hash the existing Sol agent'
  cp -p "$sol_target" "$backup_dir/sol-planner.toml"
fi

luna_presence=absent
luna_sha256=
if path_exists "$luna_target"; then
  luna_presence=present
  luna_sha256=$(sha256_file "$luna_target") || die 'cannot hash the existing Luna agent'
  cp -p "$luna_target" "$backup_dir/luna-max-worker.toml"
fi

config_presence=absent
config_sha256=
if path_exists "$config_target"; then
  config_presence=present
  config_sha256=$(sha256_file "$config_target") || die 'cannot hash config.toml'
  cp -p "$config_target" "$backup_dir/config.toml"
fi

manifest_tmp="$backup_dir/.manifest.tmp"
{
  printf 'version=1\n'
  printf 'skill_presence=%s\n' "$skill_presence"
  printf 'skill_sha256=%s\n' "$skill_sha256"
  printf 'sol_presence=%s\n' "$sol_presence"
  printf 'sol_sha256=%s\n' "$sol_sha256"
  printf 'luna_presence=%s\n' "$luna_presence"
  printf 'luna_sha256=%s\n' "$luna_sha256"
  printf 'config_presence=%s\n' "$config_presence"
  printf 'config_sha256=%s\n' "$config_sha256"
} >"$manifest_tmp"
mv "$manifest_tmp" "$backup_dir/manifest"

transaction_dir=$(mktemp -d "$state_root/.transaction.XXXXXX") || die 'cannot create the staged transaction directory'
mkdir "$transaction_dir/stage"
cp -a "$skill_source" "$transaction_dir/stage/skill"
cp -p "$sol_source" "$transaction_dir/stage/sol-planner.toml"
cp -p "$luna_source" "$transaction_dir/stage/luna-max-worker.toml"

skill_had=0
skill_new=0
sol_had=0
sol_new=0
luna_had=0
luna_new=0
state_had=0
state_new=0
rollback_active=1

rollback_install() {
  local status="$1"
  trap - EXIT INT TERM
  set +e

  if (( state_new )); then
    rm -f "$state_file"
  fi
  if (( state_had )) && path_exists "$transaction_dir/old-state"; then
    mv "$transaction_dir/old-state" "$state_file"
  fi

  if (( luna_new )); then rm -rf "$luna_target"; fi
  if (( luna_had )) && path_exists "$transaction_dir/old-luna"; then mv "$transaction_dir/old-luna" "$luna_target"; fi
  if (( sol_new )); then rm -rf "$sol_target"; fi
  if (( sol_had )) && path_exists "$transaction_dir/old-sol"; then mv "$transaction_dir/old-sol" "$sol_target"; fi
  if (( skill_new )); then rm -rf "$skill_target"; fi
  if (( skill_had )) && path_exists "$transaction_dir/old-skill"; then mv "$transaction_dir/old-skill" "$skill_target"; fi

  rm -rf "$transaction_dir"
  exit "$status"
}
trap 'rollback_install "$?"' EXIT INT TERM

if path_exists "$state_file"; then
  mv "$state_file" "$transaction_dir/old-state"
  state_had=1
fi
if path_exists "$skill_target"; then
  mv "$skill_target" "$transaction_dir/old-skill"
  skill_had=1
fi
mv "$transaction_dir/stage/skill" "$skill_target"
skill_new=1

if path_exists "$sol_target"; then
  mv "$sol_target" "$transaction_dir/old-sol"
  sol_had=1
fi
mv "$transaction_dir/stage/sol-planner.toml" "$sol_target"
sol_new=1

if path_exists "$luna_target"; then
  mv "$luna_target" "$transaction_dir/old-luna"
  luna_had=1
fi
mv "$transaction_dir/stage/luna-max-worker.toml" "$luna_target"
luna_new=1

# Test-only fault injection is active only with an explicit isolated install root.
if [[ -n "${ORCHESTRATE_HOME:-}" && "${ORCHESTRATE_FAILPOINT:-}" == after-replace ]]; then
  die 'injected failure after replacement'
fi

new_skill_sha256=$(sha256_tree "$skill_target") || die 'cannot hash the installed skill'
new_sol_sha256=$(sha256_file "$sol_target") || die 'cannot hash the installed Sol agent'
new_luna_sha256=$(sha256_file "$luna_target") || die 'cannot hash the installed Luna agent'
[[ "$new_skill_sha256" =~ ^[0-9a-f]{64}$ ]] || die 'invalid installed skill checksum'
[[ "$new_sol_sha256" =~ ^[0-9a-f]{64}$ ]] || die 'invalid installed Sol checksum'
[[ "$new_luna_sha256" =~ ^[0-9a-f]{64}$ ]] || die 'invalid installed Luna checksum'

state_tmp=$(mktemp "$state_root/.install-state.XXXXXX") || die 'cannot create install state'
{
  printf 'version=1\n'
  printf 'backup_id=%s\n' "$backup_id"
  printf 'skill_sha256=%s\n' "$new_skill_sha256"
  printf 'sol_sha256=%s\n' "$new_sol_sha256"
  printf 'luna_sha256=%s\n' "$new_luna_sha256"
} >"$state_tmp"
mv "$state_tmp" "$state_file"
state_new=1

rm -rf "$transaction_dir" || die 'cannot finalize the staged transaction'
rollback_active=0
trap - EXIT INT TERM

printf 'Install path: %s\n' "$skill_target"
printf 'Install path: %s\n' "$sol_target"
printf 'Install path: %s\n' "$luna_target"
printf 'Backup path: %s\n' "$backup_dir"
