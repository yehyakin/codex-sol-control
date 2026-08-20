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
  [[ "$1" == --check ]] || { printf 'Usage: install.sh [--check]\n' >&2; exit 1; }
  check_mode=1
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
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

sha256_stream() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    sha256sum | awk '{print $1}'
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
  ) | sha256_stream
}

hash_path() {
  if [[ "$2" == directory ]]; then
    sha256_tree "$1"
  else
    sha256_file "$1"
  fi
}

state_value() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, length(wanted) + 2); found = 1 } END { if (!found) exit 1 }' "$file"
}

state_optional() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, length(wanted) + 2); found = 1 } END { if (!found) exit 0 }' "$file"
}

assert_plain() {
  local target="$1"
  local kind="$2"
  local link
  [[ ! -L "$target" ]] || die 'symbolic links are not allowed in managed paths'
  if [[ "$kind" == directory ]]; then
    [[ -d "$target" ]] || die 'a managed directory has the wrong type'
    link=$(find "$target" -type l -print -quit)
    [[ -z "$link" ]] || die 'symbolic links are not allowed in a managed tree'
  else
    [[ -f "$target" ]] || die 'a managed file has the wrong type'
  fi
}

copy_exact() {
  if [[ -d "$1" ]]; then
    cp -a "$1" "$2"
  else
    cp -p "$1" "$2"
  fi
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
  [[ -n "$parent" && "$parent" != "$directory" ]] || die 'cannot create an install directory'
  ensure_dir "$parent"
  mkdir "$directory"
  created_dirs+=("$directory")
}

cleanup_dirs() {
  local index
  for (( index=${#created_dirs[@]} - 1; index >= 0; index-- )); do
    rmdir "${created_dirs[index]}" 2>/dev/null || true
  done
}

command -v uname >/dev/null 2>&1 || die 'uname is required'
case "$(uname -s)" in
  Darwin|Linux) ;;
  *) die 'this installer supports macOS and Linux; use install.ps1 on Windows' ;;
esac
for command_name in bash find awk sort mktemp date cp mv mkdir rmdir rm; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is unavailable: $command_name"
done
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  die 'a SHA-256 utility is unavailable'
fi

canonical_skill_source="$REPO_ROOT/.agents/skills/codex-prove"
compat_skill_source="$REPO_ROOT/.agents/skills/sol-control"
controller_source="$REPO_ROOT/.codex/agents/prove-controller.toml"
complex_source="$REPO_ROOT/.codex/agents/prove-complex-worker.toml"
efficient_source="$REPO_ROOT/.codex/agents/prove-efficient-worker.toml"

for source_dir in "$canonical_skill_source" "$compat_skill_source"; do
  [[ -d "$source_dir" && ! -L "$source_dir" ]] || die 'a source skill directory is missing or unsafe'
  assert_plain "$source_dir" directory
done
for source_file in "$controller_source" "$complex_source" "$efficient_source"; do
  [[ -f "$source_file" && ! -L "$source_file" ]] || die 'a source agent file is missing or unsafe'
  assert_plain "$source_file" file
done

if (( check_mode )); then
  bash "$SCRIPT_DIR/validate.sh" || die 'source validation failed'
else
  validation_log=$(mktemp "${TMPDIR:-/tmp}/codex-prove-validation.XXXXXX") || die 'cannot create a validation log'
  if ! bash "$SCRIPT_DIR/validate.sh" >"$validation_log" 2>&1; then
    rm -f "$validation_log"
    die 'source validation failed'
  fi
  rm -f "$validation_log"
fi

raw_home=${ORCHESTRATE_HOME:-${HOME:-}}
[[ -n "$raw_home" && "$raw_home" == /* && "$raw_home" != / ]] || die 'ORCHESTRATE_HOME must be a non-root absolute path'
[[ ! -L "$raw_home" ]] || die 'ORCHESTRATE_HOME must not be a symbolic link'
raw_home=${raw_home%/}

if path_exists "$raw_home"; then
  [[ -d "$raw_home" ]] || die 'ORCHESTRATE_HOME must be a directory'
  base_dir=$(CDPATH= cd -- "$raw_home" && pwd -P) || die 'cannot resolve ORCHESTRATE_HOME'
elif (( check_mode )); then
  base_dir="$raw_home"
else
  ensure_dir "$raw_home"
  base_dir=$(CDPATH= cd -- "$raw_home" && pwd -P) || die 'cannot resolve ORCHESTRATE_HOME'
fi
[[ "$base_dir" != / ]] || die 'refusing the filesystem root'

for parent in \
  "$base_dir/.agents" \
  "$base_dir/.agents/skills" \
  "$base_dir/.codex" \
  "$base_dir/.codex/agents" \
  "$base_dir/.codex/codex-prove"; do
  if path_exists "$parent"; then
    [[ ! -L "$parent" && -d "$parent" ]] || die 'an install parent is unsafe'
  fi
done

known_relatives=(
  ".agents/skills/codex-prove"
  ".agents/skills/sol-control"
  ".agents/skills/sol-luna"
  ".agents/skills/orchestrate-sol-luna"
  ".codex/agents/prove-controller.toml"
  ".codex/agents/prove-complex-worker.toml"
  ".codex/agents/prove-efficient-worker.toml"
  ".codex/agents/sol-controller.toml"
  ".codex/agents/terra-high-worker.toml"
  ".codex/agents/luna-max-worker.toml"
  ".codex/agents/sol-planner.toml"
  ".codex/codex-prove/install-state"
  ".codex/sol-control/install-state"
  ".codex/sol-luna/install-state"
  ".codex/orchestrate-sol-luna/install-state"
)
known_kinds=(
  directory directory directory directory
  file file file file file file file
  file file file file
)
owned=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)

for (( index=0; index<${#known_relatives[@]}; index++ )); do
  target="$base_dir/${known_relatives[index]}"
  if path_exists "$target"; then
    assert_plain "$target" "${known_kinds[index]}"
  fi
done

state_indexes=(11 12 13 14)
state_count=0
active_state_index=-1
for index in "${state_indexes[@]}"; do
  if path_exists "$base_dir/${known_relatives[index]}"; then
    state_count=$((state_count + 1))
    active_state_index=$index
  fi
done
(( state_count <= 1 )) || die 'multiple managed install states exist; restore or remove one before migration'

verify_owned() {
  local index="$1"
  local expected_hash="$2"
  local target="$base_dir/${known_relatives[index]}"
  valid_hash "$expected_hash" || die 'an install state contains an invalid checksum'
  path_exists "$target" || die 'a state-owned target is missing'
  [[ "$(hash_path "$target" "${known_kinds[index]}")" == "$expected_hash" ]] || die 'a state-owned target was modified; refusing to overwrite it'
  owned[index]=1
}

if (( active_state_index >= 0 )); then
  active_state="$base_dir/${known_relatives[active_state_index]}"
  state_version=$(state_value "$active_state" version) || die 'install state is incomplete'
  case "$active_state_index:$state_version" in
    11:5)
      verify_owned 0 "$(state_value "$active_state" skill_sha256)"
      verify_owned 1 "$(state_value "$active_state" compat_skill_sha256)"
      verify_owned 4 "$(state_value "$active_state" controller_sha256)"
      verify_owned 5 "$(state_value "$active_state" complex_worker_sha256)"
      verify_owned 6 "$(state_value "$active_state" efficient_worker_sha256)"
      owned[11]=1
      ;;
    12:3|12:4)
      verify_owned 1 "$(state_value "$active_state" skill_sha256)"
      verify_owned 7 "$(state_value "$active_state" sol_sha256)"
      verify_owned 9 "$(state_value "$active_state" luna_sha256)"
      terra_hash=$(state_optional "$active_state" terra_sha256)
      if [[ -n "$terra_hash" ]]; then verify_owned 8 "$terra_hash"; fi
      if [[ "$state_version" == 3 ]]; then
        verify_owned 2 "$(state_value "$active_state" compat_skill_sha256)"
      fi
      owned[12]=1
      ;;
    13:2)
      verify_owned 2 "$(state_value "$active_state" skill_sha256)"
      verify_owned 7 "$(state_value "$active_state" sol_sha256)"
      verify_owned 9 "$(state_value "$active_state" luna_sha256)"
      terra_hash=$(state_optional "$active_state" terra_sha256)
      if [[ -n "$terra_hash" ]]; then verify_owned 8 "$terra_hash"; fi
      owned[13]=1
      ;;
    14:1)
      verify_owned 3 "$(state_value "$active_state" skill_sha256)"
      verify_owned 10 "$(state_value "$active_state" sol_sha256)"
      verify_owned 9 "$(state_value "$active_state" luna_sha256)"
      owned[14]=1
      ;;
    *) die 'the existing managed install state has an unsupported version or location' ;;
  esac
fi

for (( index=0; index<${#known_relatives[@]}; index++ )); do
  target="$base_dir/${known_relatives[index]}"
  if path_exists "$target" && (( owned[index] == 0 )); then
    die "an existing target has no matching ownership state: ${known_relatives[index]}"
  fi
done

if (( check_mode )); then
  printf 'Install check: OK\n'
  printf 'Install path: %s\n' "$base_dir/.agents/skills/codex-prove"
  exit 0
fi

codex_dir="$base_dir/.codex"
agents_dir="$codex_dir/agents"
skills_dir="$base_dir/.agents/skills"
state_root="$codex_dir/codex-prove"
backup_root="$state_root/backups"
ensure_dir "$skills_dir"
ensure_dir "$agents_dir"
ensure_dir "$state_root"
ensure_dir "$backup_root"

backup_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
backup_dir="$backup_root/$backup_id"
if path_exists "$backup_dir"; then
  backup_id="$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"
  backup_dir="$backup_root/$backup_id"
fi
mkdir "$backup_dir" "$backup_dir/entries"

manifest_tmp="$backup_dir/.manifest.tmp"
printf 'version=5\nentry_count=%s\n' "${#known_relatives[@]}" >"$manifest_tmp"
for (( index=0; index<${#known_relatives[@]}; index++ )); do
  number=$((index + 1))
  relative=${known_relatives[index]}
  kind=${known_kinds[index]}
  target="$base_dir/$relative"
  presence=absent
  checksum=
  if path_exists "$target"; then
    presence=present
    checksum=$(hash_path "$target" "$kind") || die 'cannot hash an existing managed target'
    copy_exact "$target" "$backup_dir/entries/$number"
  fi
  {
    printf 'entry_%s_path=%s\n' "$number" "$relative"
    printf 'entry_%s_kind=%s\n' "$number" "$kind"
    printf 'entry_%s_presence=%s\n' "$number" "$presence"
    printf 'entry_%s_sha256=%s\n' "$number" "$checksum"
  } >>"$manifest_tmp"
done

config_target="$codex_dir/config.toml"
if path_exists "$config_target"; then
  assert_plain "$config_target" file
  config_hash=$(sha256_file "$config_target") || die 'cannot hash config.toml'
  copy_exact "$config_target" "$backup_dir/config.toml"
  printf 'config_presence=present\nconfig_sha256=%s\n' "$config_hash" >>"$manifest_tmp"
else
  printf 'config_presence=absent\nconfig_sha256=\n' >>"$manifest_tmp"
fi
mv "$manifest_tmp" "$backup_dir/manifest"

transaction_dir=$(mktemp -d "$state_root/.transaction.XXXXXX") || die 'cannot create a transaction directory'
mkdir "$transaction_dir/stage" "$transaction_dir/old" "$transaction_dir/failed"
copy_exact "$canonical_skill_source" "$transaction_dir/stage/codex-prove"
copy_exact "$compat_skill_source" "$transaction_dir/stage/sol-control"
copy_exact "$controller_source" "$transaction_dir/stage/prove-controller.toml"
copy_exact "$complex_source" "$transaction_dir/stage/prove-complex-worker.toml"
copy_exact "$efficient_source" "$transaction_dir/stage/prove-efficient-worker.toml"

rollback() {
  local status=$?
  trap - EXIT INT TERM
  for (( index=${#known_relatives[@]} - 1; index>=0; index-- )); do
    target="$base_dir/${known_relatives[index]}"
    if path_exists "$target"; then
      mkdir -p "$transaction_dir/failed/$index"
      mv "$target" "$transaction_dir/failed/$index/current" 2>/dev/null || true
    fi
    if path_exists "$transaction_dir/old/$index"; then
      ensure_dir "${target%/*}"
      mv "$transaction_dir/old/$index" "$target" 2>/dev/null || true
    fi
  done
  rm -rf "$transaction_dir" 2>/dev/null || true
  cleanup_dirs
  exit "$status"
}
trap rollback EXIT INT TERM

for (( index=0; index<${#known_relatives[@]}; index++ )); do
  target="$base_dir/${known_relatives[index]}"
  if path_exists "$target"; then
    mv "$target" "$transaction_dir/old/$index"
  fi
done

mv "$transaction_dir/stage/codex-prove" "$base_dir/.agents/skills/codex-prove"
mv "$transaction_dir/stage/sol-control" "$base_dir/.agents/skills/sol-control"
mv "$transaction_dir/stage/prove-controller.toml" "$base_dir/.codex/agents/prove-controller.toml"
mv "$transaction_dir/stage/prove-complex-worker.toml" "$base_dir/.codex/agents/prove-complex-worker.toml"
mv "$transaction_dir/stage/prove-efficient-worker.toml" "$base_dir/.codex/agents/prove-efficient-worker.toml"

if [[ "${ORCHESTRATE_FAILPOINT:-}" == after-replace ]]; then
  die 'injected failure after replacement'
fi

skill_hash=$(sha256_tree "$base_dir/.agents/skills/codex-prove")
compat_hash=$(sha256_tree "$base_dir/.agents/skills/sol-control")
controller_hash=$(sha256_file "$base_dir/.codex/agents/prove-controller.toml")
complex_hash=$(sha256_file "$base_dir/.codex/agents/prove-complex-worker.toml")
efficient_hash=$(sha256_file "$base_dir/.codex/agents/prove-efficient-worker.toml")
for checksum in "$skill_hash" "$compat_hash" "$controller_hash" "$complex_hash" "$efficient_hash"; do
  valid_hash "$checksum" || die 'an installed checksum is invalid'
done

state_tmp=$(mktemp "$state_root/.install-state.XXXXXX") || die 'cannot create install state'
{
  printf 'version=5\n'
  printf 'backup_id=%s\n' "$backup_id"
  printf 'skill_sha256=%s\n' "$skill_hash"
  printf 'compat_skill_sha256=%s\n' "$compat_hash"
  printf 'controller_sha256=%s\n' "$controller_hash"
  printf 'complex_worker_sha256=%s\n' "$complex_hash"
  printf 'efficient_worker_sha256=%s\n' "$efficient_hash"
} >"$state_tmp"
mv "$state_tmp" "$state_root/install-state"

if [[ "${ORCHESTRATE_FAILPOINT:-}" == after-state ]]; then
  die 'injected failure after state'
fi

rm -rf "$transaction_dir"
transaction_dir=
trap - EXIT INT TERM

printf 'Install path: %s\n' "$base_dir/.agents/skills/codex-prove"
printf 'Compatibility path: %s\n' "$base_dir/.agents/skills/sol-control"
printf 'Agent path: %s\n' "$base_dir/.codex/agents/prove-controller.toml"
printf 'Agent path: %s\n' "$base_dir/.codex/agents/prove-complex-worker.toml"
printf 'Agent path: %s\n' "$base_dir/.codex/agents/prove-efficient-worker.toml"
printf 'Backup path: %s\n' "$backup_dir"
