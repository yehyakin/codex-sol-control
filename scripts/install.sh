#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)

check_mode=0
if (( $# > 1 )); then
  printf 'Usage: install.sh [--check]\n' >&2
  exit 1
fi
if (( $# == 1 )); then
  case "$1" in
    --check)
      check_mode=1
      ;;
    *)
      printf 'Usage: install.sh [--check]\n' >&2
      exit 1
      ;;
  esac
fi

die() {
  printf 'install.sh: %s\n' "$1" >&2
  exit 1
}

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

valid_hash() {
  [[ "$1" =~ ^[0-9a-f]{64}$ ]]
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

state_value_file() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, length(wanted) + 2); found = 1 } END { if (!found) exit 1 }' "$file"
}

assert_plain_tree() {
  local path="$1"
  local link
  [[ ! -L "$path" ]] || die 'symbolic links are not allowed in an owned path'
  if [[ -d "$path" ]]; then
    link=$(find "$path" -type l -print -quit)
    [[ -z "$link" ]] || die 'symbolic links are not allowed in an owned tree'
  fi
}

assert_existing_path_chain() {
  local path="$1"
  local cursor="$path"
  local parent
  while ! path_exists "$cursor"; do
    [[ "$cursor" == / ]] && break
    parent=${cursor%/*}
    [[ -n "$parent" ]] || parent=/
    [[ "$parent" != "$cursor" ]] || break
    cursor="$parent"
  done
  if path_exists "$cursor"; then
    [[ ! -L "$cursor" ]] || die 'an install path contains a symbolic link'
    [[ -d "$cursor" ]] || die 'an install path ancestor is not a directory'
  fi
}

assert_target() {
  local path="$1"
  local kind="$2"
  if ! path_exists "$path"; then
    return 0
  fi
  [[ ! -L "$path" ]] || die 'symbolic links are not allowed in an install target'
  if [[ "$kind" == directory ]]; then
    [[ -d "$path" ]] || die 'an existing directory target has the wrong type'
  else
    [[ -f "$path" ]] || die 'an existing file target has the wrong type'
  fi
  assert_plain_tree "$path"
}

created_dirs=()
ensure_dir() {
  local directory="$1"
  local parent
  if path_exists "$directory"; then
    [[ ! -L "$directory" && -d "$directory" ]] || die 'an install parent is unsafe'
    return 0
  fi
  parent=${directory%/*}
  [[ "$parent" != "$directory" && -n "$parent" ]] || die 'cannot create an install directory'
  ensure_dir "$parent"
  mkdir "$directory" || die 'cannot create an install directory'
  created_dirs+=("$directory")
}

cleanup_created_dirs() {
  local index
  for ((index=${#created_dirs[@]} - 1; index >= 0; index--)); do
    rmdir "${created_dirs[index]}" 2>/dev/null || true
  done
}

copy_exact() {
  local source="$1"
  local destination="$2"
  if [[ -d "$source" ]]; then
    cp -a "$source" "$destination"
  else
    cp -p "$source" "$destination"
  fi
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

for command_name in bash find awk sort mktemp date cp mv rm mkdir rmdir; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is unavailable: $command_name"
done
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  die 'a SHA-256 utility is unavailable'
fi

skill_source="$REPO_ROOT/.agents/skills/sol-luna"
sol_source="$REPO_ROOT/.codex/agents/sol-controller.toml"
luna_source="$REPO_ROOT/.codex/agents/luna-max-worker.toml"

[[ -d "$skill_source" && ! -L "$skill_source" ]] || die 'source skill directory is missing'
[[ -f "$sol_source" && ! -L "$sol_source" ]] || die 'source Sol controller is missing'
[[ -f "$luna_source" && ! -L "$luna_source" ]] || die 'source Luna agent is missing'
assert_plain_tree "$skill_source"
assert_plain_tree "$sol_source"
assert_plain_tree "$luna_source"

if (( check_mode )); then
  bash "$SCRIPT_DIR/validate.sh" || die 'source validation failed'
else
  validation_log=$(mktemp "${TMPDIR:-/tmp}/sol-luna-validation.XXXXXX") || die 'cannot create a validation temporary file'
  if ! bash "$SCRIPT_DIR/validate.sh" >"$validation_log" 2>&1; then
    rm -f "$validation_log"
    die 'source validation failed'
  fi
  rm -f "$validation_log"
fi

raw_home=${ORCHESTRATE_HOME:-${HOME:-}}
[[ -n "$raw_home" ]] || die 'ORCHESTRATE_HOME or HOME is required'
[[ "$raw_home" == /* ]] || die 'ORCHESTRATE_HOME must be an absolute path'
[[ "$raw_home" != / ]] || die 'refusing the filesystem root as ORCHESTRATE_HOME'
[[ ! -L "$raw_home" ]] || die 'ORCHESTRATE_HOME must not be a symbolic link'
raw_home=${raw_home%/}
[[ -n "$raw_home" ]] || die 'refusing the filesystem root as ORCHESTRATE_HOME'
if (( check_mode )); then
  assert_existing_path_chain "$raw_home"
  if path_exists "$raw_home"; then
    [[ -d "$raw_home" ]] || die 'ORCHESTRATE_HOME must be a directory'
    base_dir=$(CDPATH= cd -- "$raw_home" && pwd -P) || die 'cannot resolve ORCHESTRATE_HOME'
  else
    base_dir="$raw_home"
  fi
else
  ensure_dir "$raw_home"
  base_dir=$(CDPATH= cd -- "$raw_home" && pwd -P) || die 'cannot resolve ORCHESTRATE_HOME'
fi
[[ "$base_dir" != / ]] || die 'refusing the filesystem root as ORCHESTRATE_HOME'

new_skill_target="$base_dir/.agents/skills/sol-luna"
new_sol_target="$base_dir/.codex/agents/sol-controller.toml"
luna_target="$base_dir/.codex/agents/luna-max-worker.toml"
legacy_skill_target="$base_dir/.agents/skills/orchestrate-sol-luna"
legacy_sol_target="$base_dir/.codex/agents/sol-planner.toml"
codex_dir="$base_dir/.codex"
agents_dir="$codex_dir/agents"
config_target="$codex_dir/config.toml"
state_root="$codex_dir/sol-luna"
state_file="$state_root/install-state"
backup_root="$state_root/backups"
legacy_state_root="$codex_dir/orchestrate-sol-luna"
legacy_state_file="$legacy_state_root/install-state"

for directory in \
  "$base_dir/.agents" \
  "$base_dir/.agents/skills" \
  "$codex_dir" \
  "$agents_dir" \
  "$state_root" \
  "$backup_root" \
  "$legacy_state_root"; do
  if path_exists "$directory"; then
    [[ ! -L "$directory" && -d "$directory" ]] || die 'an install parent is unsafe'
  fi
done

if (( check_mode )); then
  for directory in \
    "$base_dir/.agents" \
    "$base_dir/.agents/skills" \
    "$codex_dir" \
    "$agents_dir" \
    "$state_root" \
    "$backup_root" \
    "$legacy_state_root"; do
    assert_existing_path_chain "$directory"
  done
fi

assert_target "$new_skill_target" directory
assert_target "$new_sol_target" file
assert_target "$luna_target" file
assert_target "$legacy_skill_target" directory
assert_target "$legacy_sol_target" file
if path_exists "$config_target"; then
  assert_target "$config_target" file
fi
if path_exists "$state_file"; then
  assert_target "$state_file" file
fi
if path_exists "$legacy_state_file"; then
  assert_target "$legacy_state_file" file
fi

v2_state_present=0
v2_skill_sha256=
v2_sol_sha256=
v2_luna_sha256=
if path_exists "$state_file"; then
  [[ "$(state_value_file "$state_file" version)" == 2 ]] || die 'existing v0.2 state has an unsupported version'
  v2_backup_id=$(state_value_file "$state_file" backup_id) || die 'existing v0.2 state is incomplete'
  [[ "$v2_backup_id" =~ ^[A-Za-z0-9._-]+$ ]] || die 'existing v0.2 state has an unsafe backup identifier'
  v2_skill_sha256=$(state_value_file "$state_file" skill_sha256) || die 'existing v0.2 state is incomplete'
  v2_sol_sha256=$(state_value_file "$state_file" sol_sha256) || die 'existing v0.2 state is incomplete'
  v2_luna_sha256=$(state_value_file "$state_file" luna_sha256) || die 'existing v0.2 state is incomplete'
  valid_hash "$v2_skill_sha256" || die 'existing v0.2 state has an invalid skill checksum'
  valid_hash "$v2_sol_sha256" || die 'existing v0.2 state has an invalid Sol checksum'
  valid_hash "$v2_luna_sha256" || die 'existing v0.2 state has an invalid Luna checksum'
  [[ -d "$new_skill_target" && ! -L "$new_skill_target" ]] || die 'existing v0.2 skill is missing or unsafe'
  [[ -f "$new_sol_target" && ! -L "$new_sol_target" ]] || die 'existing v0.2 Sol controller is missing or unsafe'
  [[ -f "$luna_target" && ! -L "$luna_target" ]] || die 'existing v0.2 Luna agent is missing or unsafe'
  [[ "$(sha256_tree "$new_skill_target")" == "$v2_skill_sha256" ]] || die 'existing v0.2 skill was modified'
  [[ "$(sha256_file "$new_sol_target")" == "$v2_sol_sha256" ]] || die 'existing v0.2 Sol controller was modified'
  [[ "$(sha256_file "$luna_target")" == "$v2_luna_sha256" ]] || die 'existing v0.2 Luna agent was modified'
  v2_state_present=1
else
  if path_exists "$new_skill_target" || path_exists "$new_sol_target"; then
    die 'existing v0.2 target has no ownership state'
  fi
fi

legacy_state_present=0
legacy_skill_sha256=
legacy_sol_sha256=
legacy_luna_sha256=
if path_exists "$legacy_state_file"; then
  [[ "$(state_value_file "$legacy_state_file" version)" == 1 ]] || die 'existing v0.1 state has an unsupported version'
  legacy_state_present=1
  legacy_skill_sha256=$(state_value_file "$legacy_state_file" skill_sha256) || die 'existing v0.1 state is incomplete'
  legacy_sol_sha256=$(state_value_file "$legacy_state_file" sol_sha256) || die 'existing v0.1 state is incomplete'
  legacy_luna_sha256=$(state_value_file "$legacy_state_file" luna_sha256) || die 'existing v0.1 state is incomplete'
  valid_hash "$legacy_skill_sha256" || die 'existing v0.1 state has an invalid skill checksum'
  valid_hash "$legacy_sol_sha256" || die 'existing v0.1 state has an invalid Sol checksum'
  valid_hash "$legacy_luna_sha256" || die 'existing v0.1 state has an invalid Luna checksum'
fi

legacy_skill_remove=0
legacy_sol_remove=0
if (( legacy_state_present )); then
  if path_exists "$legacy_skill_target" && [[ "$(sha256_tree "$legacy_skill_target")" == "$legacy_skill_sha256" ]]; then
    legacy_skill_remove=1
  fi
  if path_exists "$legacy_sol_target" && [[ "$(sha256_file "$legacy_sol_target")" == "$legacy_sol_sha256" ]]; then
    legacy_sol_remove=1
  fi
fi

if (( ! v2_state_present )) && path_exists "$luna_target"; then
  if (( legacy_state_present )); then
    [[ "$(sha256_file "$luna_target")" == "$legacy_luna_sha256" ]] || die 'shared Luna was modified; refusing migration'
  else
    die 'existing shared Luna has no ownership state'
  fi
fi

if (( check_mode )); then
  source_skill_sha256=$(sha256_tree "$skill_source") || die 'cannot hash the source skill'
  source_sol_sha256=$(sha256_file "$sol_source") || die 'cannot hash the source Sol controller'
  source_luna_sha256=$(sha256_file "$luna_source") || die 'cannot hash the source Luna agent'
  if (( v2_state_present )) &&
    [[ "$v2_skill_sha256" == "$source_skill_sha256" ]] &&
    [[ "$v2_sol_sha256" == "$source_sol_sha256" ]] &&
    [[ "$v2_luna_sha256" == "$source_luna_sha256" ]] &&
    ! path_exists "$legacy_skill_target" &&
    ! path_exists "$legacy_sol_target" &&
    ! path_exists "$legacy_state_file"; then
    printf 'Check: installation is consistent; no changes required\n'
    exit 0
  fi
  printf 'Check: installation is safe and requires install/update\n'
  exit 2
fi

ensure_dir "$base_dir/.agents/skills"
ensure_dir "$agents_dir"
ensure_dir "$state_root"
ensure_dir "$backup_root"

backup_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
backup_dir="$backup_root/$backup_id"
while path_exists "$backup_dir"; do
  backup_id="$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"
  backup_dir="$backup_root/$backup_id"
done
mkdir "$backup_dir"

transaction_dir=
state_tmp=
skill_old=0
skill_new=0
sol_old=0
sol_new=0
luna_old=0
luna_new=0
legacy_skill_old=0
legacy_sol_old=0
state_old=0
state_new=0

rollback_install() {
  local status="$1"
  trap - EXIT INT TERM
  set +e

  [[ -z "${state_tmp:-}" ]] || rm -f "$state_tmp"
  if (( state_new )); then
    rm -f "$state_file"
  fi
  if (( state_old )) && path_exists "$transaction_dir/old-state"; then
    mv "$transaction_dir/old-state" "$state_file"
  fi

  if (( luna_new )); then rm -rf "$luna_target"; fi
  if (( luna_old )) && path_exists "$transaction_dir/old-luna"; then mv "$transaction_dir/old-luna" "$luna_target"; fi
  if (( sol_new )); then rm -rf "$new_sol_target"; fi
  if (( sol_old )) && path_exists "$transaction_dir/old-v020-sol"; then mv "$transaction_dir/old-v020-sol" "$new_sol_target"; fi
  if (( skill_new )); then rm -rf "$new_skill_target"; fi
  if (( skill_old )) && path_exists "$transaction_dir/old-v020-skill"; then mv "$transaction_dir/old-v020-skill" "$new_skill_target"; fi

  if (( legacy_sol_old )) && path_exists "$transaction_dir/old-legacy-sol"; then mv "$transaction_dir/old-legacy-sol" "$legacy_sol_target"; fi
  if (( legacy_skill_old )) && path_exists "$transaction_dir/old-legacy-skill"; then mv "$transaction_dir/old-legacy-skill" "$legacy_skill_target"; fi

  if [[ -n "${transaction_dir:-}" ]]; then rm -rf "$transaction_dir"; fi
  if [[ -n "${backup_dir:-}" ]]; then rm -rf "$backup_dir"; fi
  cleanup_created_dirs
  exit "$status"
}
trap 'rollback_install "$?"' EXIT INT TERM

backup_skill_presence=absent
backup_skill_sha256=
mkdir "$backup_dir/legacy"
if path_exists "$legacy_skill_target"; then
  backup_skill_presence=present
  backup_skill_sha256=$(sha256_tree "$legacy_skill_target") || die 'cannot hash the legacy skill'
  copy_exact "$legacy_skill_target" "$backup_dir/legacy/skill"
fi

backup_sol_presence=absent
backup_sol_sha256=
if path_exists "$legacy_sol_target"; then
  backup_sol_presence=present
  backup_sol_sha256=$(sha256_file "$legacy_sol_target") || die 'cannot hash the legacy Sol agent'
  copy_exact "$legacy_sol_target" "$backup_dir/legacy/sol-planner.toml"
fi

backup_luna_presence=absent
backup_luna_sha256=
if path_exists "$luna_target"; then
  backup_luna_presence=present
  backup_luna_sha256=$(sha256_file "$luna_target") || die 'cannot hash the existing shared Luna agent'
  copy_exact "$luna_target" "$backup_dir/legacy/luna-max-worker.toml"
fi

backup_new_skill_presence=absent
backup_new_skill_sha256=
mkdir "$backup_dir/v020"
if path_exists "$new_skill_target"; then
  backup_new_skill_presence=present
  backup_new_skill_sha256=$(sha256_tree "$new_skill_target") || die 'cannot hash the existing v0.2 skill'
  copy_exact "$new_skill_target" "$backup_dir/v020/skill"
fi

backup_new_sol_presence=absent
backup_new_sol_sha256=
if path_exists "$new_sol_target"; then
  backup_new_sol_presence=present
  backup_new_sol_sha256=$(sha256_file "$new_sol_target") || die 'cannot hash the existing v0.2 Sol controller'
  copy_exact "$new_sol_target" "$backup_dir/v020/sol-controller.toml"
fi

backup_new_luna_presence="$backup_luna_presence"
backup_new_luna_sha256="$backup_luna_sha256"
if [[ "$backup_luna_presence" == present ]]; then
  copy_exact "$luna_target" "$backup_dir/v020/luna-max-worker.toml"
fi

config_presence=absent
config_sha256=
if path_exists "$config_target"; then
  config_presence=present
  config_sha256=$(sha256_file "$config_target") || die 'cannot hash config.toml'
fi

manifest_tmp="$backup_dir/.manifest.tmp"
{
  printf 'version=2\n'
  printf 'legacy_skill_presence=%s\n' "$backup_skill_presence"
  printf 'legacy_skill_sha256=%s\n' "$backup_skill_sha256"
  printf 'legacy_sol_presence=%s\n' "$backup_sol_presence"
  printf 'legacy_sol_sha256=%s\n' "$backup_sol_sha256"
  printf 'legacy_luna_presence=%s\n' "$backup_luna_presence"
  printf 'legacy_luna_sha256=%s\n' "$backup_luna_sha256"
  printf 'v020_skill_presence=%s\n' "$backup_new_skill_presence"
  printf 'v020_skill_sha256=%s\n' "$backup_new_skill_sha256"
  printf 'v020_sol_presence=%s\n' "$backup_new_sol_presence"
  printf 'v020_sol_sha256=%s\n' "$backup_new_sol_sha256"
  printf 'v020_luna_presence=%s\n' "$backup_new_luna_presence"
  printf 'v020_luna_sha256=%s\n' "$backup_new_luna_sha256"
  printf 'config_presence=%s\n' "$config_presence"
  printf 'config_sha256=%s\n' "$config_sha256"
} >"$manifest_tmp"
mv "$manifest_tmp" "$backup_dir/manifest"

transaction_dir=$(mktemp -d "$state_root/.transaction.XXXXXX") || die 'cannot create the staged transaction directory'
mkdir "$transaction_dir/stage"
copy_exact "$skill_source" "$transaction_dir/stage/v020-skill"
copy_exact "$sol_source" "$transaction_dir/stage/v020-sol-controller.toml"
copy_exact "$luna_source" "$transaction_dir/stage/v020-luna-max-worker.toml"

if path_exists "$state_file"; then
  mv "$state_file" "$transaction_dir/old-state"
  state_old=1
fi

if path_exists "$new_skill_target"; then
  mv "$new_skill_target" "$transaction_dir/old-v020-skill"
  skill_old=1
fi
mv "$transaction_dir/stage/v020-skill" "$new_skill_target"
skill_new=1

if (( legacy_skill_remove )); then
  mv "$legacy_skill_target" "$transaction_dir/old-legacy-skill"
  legacy_skill_old=1
fi

if path_exists "$new_sol_target"; then
  mv "$new_sol_target" "$transaction_dir/old-v020-sol"
  sol_old=1
fi
mv "$transaction_dir/stage/v020-sol-controller.toml" "$new_sol_target"
sol_new=1

if (( legacy_sol_remove )); then
  mv "$legacy_sol_target" "$transaction_dir/old-legacy-sol"
  legacy_sol_old=1
fi

if path_exists "$luna_target"; then
  mv "$luna_target" "$transaction_dir/old-luna"
  luna_old=1
fi
mv "$transaction_dir/stage/v020-luna-max-worker.toml" "$luna_target"
luna_new=1

if [[ -n "${ORCHESTRATE_HOME:-}" && "${ORCHESTRATE_FAILPOINT:-}" == after-replace ]]; then
  die 'injected failure after replacement'
fi

new_skill_sha256=$(sha256_tree "$new_skill_target") || die 'cannot hash the installed v0.2 skill'
new_sol_sha256=$(sha256_file "$new_sol_target") || die 'cannot hash the installed v0.2 Sol controller'
new_luna_sha256=$(sha256_file "$luna_target") || die 'cannot hash the installed v0.2 Luna checksum'
valid_hash "$new_skill_sha256" || die 'invalid installed v0.2 skill checksum'
valid_hash "$new_sol_sha256" || die 'invalid installed v0.2 Sol checksum'
valid_hash "$new_luna_sha256" || die 'invalid installed v0.2 Luna checksum'

state_tmp=$(mktemp "$state_root/.install-state.XXXXXX") || die 'cannot create v0.2 install state'
{
  printf 'version=2\n'
  printf 'backup_id=%s\n' "$backup_id"
  printf 'skill_sha256=%s\n' "$new_skill_sha256"
  printf 'sol_sha256=%s\n' "$new_sol_sha256"
  printf 'luna_sha256=%s\n' "$new_luna_sha256"
} >"$state_tmp"
mv "$state_tmp" "$state_file"
state_tmp=
state_new=1

if [[ "${ORCHESTRATE_FAILPOINT:-}" == after-state ]]; then
  die 'injected failure after state'
fi

rm -rf "$transaction_dir" || die 'cannot finalize the staged transaction'
transaction_dir=
trap - EXIT INT TERM

printf 'Install path: %s\n' "$new_skill_target"
printf 'Install path: %s\n' "$new_sol_target"
printf 'Install path: %s\n' "$luna_target"
printf 'Backup path: %s\n' "$backup_dir"
