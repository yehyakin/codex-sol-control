#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

restore_latest=0
if (( $# > 1 )); then
  printf 'Usage: uninstall.sh [--restore-latest]\n' >&2
  exit 1
fi
if (( $# == 1 )); then
  [[ "$1" == --restore-latest ]] || { printf 'Usage: uninstall.sh [--restore-latest]\n' >&2; exit 1; }
  restore_latest=1
fi

die() {
  printf 'uninstall.sh: %s\n' "$1" >&2
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
  if [[ "$2" == directory ]]; then sha256_tree "$1"; else sha256_file "$1"; fi
}

state_value() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, length(wanted) + 2); found = 1 } END { if (!found) exit 1 }' "$file"
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
  if [[ -d "$1" ]]; then cp -a "$1" "$2"; else cp -p "$1" "$2"; fi
}

for command_name in find awk sort mktemp cp mv mkdir rm; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is unavailable: $command_name"
done
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  die 'a SHA-256 utility is unavailable'
fi

raw_home=${ORCHESTRATE_HOME:-${HOME:-}}
[[ -n "$raw_home" && "$raw_home" == /* && "$raw_home" != / ]] || die 'ORCHESTRATE_HOME must be a non-root absolute path'
[[ ! -L "$raw_home" && -d "$raw_home" ]] || die 'ORCHESTRATE_HOME is missing or unsafe'
base_dir=$(CDPATH= cd -- "${raw_home%/}" && pwd -P) || die 'cannot resolve ORCHESTRATE_HOME'

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

state_root="$base_dir/.codex/codex-prove"
state_file="$state_root/install-state"
backup_root="$state_root/backups"
path_exists "$state_file" || die 'Codex PROVE install state is missing'
assert_plain "$state_file" file
[[ "$(state_value "$state_file" version)" == 5 ]] || die 'unsupported Codex PROVE install state'

backup_id=$(state_value "$state_file" backup_id) || die 'install state is incomplete'
[[ "$backup_id" =~ ^[A-Za-z0-9._-]+$ ]] || die 'install state has an unsafe backup identifier'

managed_indexes=(0 1 4 5 6)
managed_keys=(skill_sha256 compat_skill_sha256 controller_sha256 complex_worker_sha256 efficient_worker_sha256)
for (( item=0; item<${#managed_indexes[@]}; item++ )); do
  index=${managed_indexes[item]}
  target="$base_dir/${known_relatives[index]}"
  expected=$(state_value "$state_file" "${managed_keys[item]}") || die 'install state is incomplete'
  valid_hash "$expected" || die 'install state contains an invalid checksum'
  path_exists "$target" || die 'an installed Codex PROVE target is missing'
  assert_plain "$target" "${known_kinds[index]}"
  [[ "$(hash_path "$target" "${known_kinds[index]}")" == "$expected" ]] || die 'an installed Codex PROVE target was modified; refusing to remove it'
done

backup_dir="$backup_root/$backup_id"
manifest="$backup_dir/manifest"
if (( restore_latest )); then
  [[ -d "$backup_dir" && ! -L "$backup_dir" ]] || die 'latest backup directory is missing or unsafe'
  [[ -f "$manifest" && ! -L "$manifest" ]] || die 'latest backup manifest is missing or unsafe'
  [[ "$(state_value "$manifest" version)" == 5 ]] || die 'latest backup manifest has an unsupported version'
  [[ "$(state_value "$manifest" entry_count)" == "${#known_relatives[@]}" ]] || die 'latest backup manifest has the wrong entry count'
fi

transaction_dir=$(mktemp -d "$state_root/.uninstall.XXXXXX") || die 'cannot create uninstall transaction'
mkdir "$transaction_dir/current" "$transaction_dir/stage" "$transaction_dir/failed"

rollback() {
  local status=$?
  trap - EXIT INT TERM
  for (( index=${#known_relatives[@]} - 1; index>=0; index-- )); do
    target="$base_dir/${known_relatives[index]}"
    if path_exists "$target"; then
      mkdir -p "$transaction_dir/failed/$index"
      mv "$target" "$transaction_dir/failed/$index/current" 2>/dev/null || true
    fi
    if path_exists "$transaction_dir/current/$index"; then
      mkdir -p "${target%/*}"
      mv "$transaction_dir/current/$index" "$target" 2>/dev/null || true
    fi
  done
  rm -rf "$transaction_dir" 2>/dev/null || true
  exit "$status"
}
trap rollback EXIT INT TERM

if (( restore_latest )); then
  for (( index=0; index<${#known_relatives[@]}; index++ )); do
    number=$((index + 1))
    recorded_path=$(state_value "$manifest" "entry_${number}_path") || die 'backup manifest is incomplete'
    recorded_kind=$(state_value "$manifest" "entry_${number}_kind") || die 'backup manifest is incomplete'
    presence=$(state_value "$manifest" "entry_${number}_presence") || die 'backup manifest is incomplete'
    checksum=$(state_value "$manifest" "entry_${number}_sha256") || die 'backup manifest is incomplete'
    [[ "$recorded_path" == "${known_relatives[index]}" ]] || die 'backup manifest contains an unsafe path'
    [[ "$recorded_kind" == "${known_kinds[index]}" ]] || die 'backup manifest contains an invalid target type'
    [[ "$presence" == present || "$presence" == absent ]] || die 'backup manifest contains an invalid presence value'
    source="$backup_dir/entries/$number"
    if [[ "$presence" == present ]]; then
      valid_hash "$checksum" || die 'backup manifest contains an invalid checksum'
      path_exists "$source" || die 'a backup entry is missing'
      assert_plain "$source" "$recorded_kind"
      [[ "$(hash_path "$source" "$recorded_kind")" == "$checksum" ]] || die 'a backup entry checksum does not match'
      copy_exact "$source" "$transaction_dir/stage/$index"
    else
      [[ -z "$checksum" ]] || die 'an absent backup entry has a checksum'
      ! path_exists "$source" || die 'an absent backup entry has unexpected data'
    fi
  done
fi

for index in "${managed_indexes[@]}" 11; do
  target="$base_dir/${known_relatives[index]}"
  mv "$target" "$transaction_dir/current/$index"
done

if (( restore_latest )); then
  for (( index=0; index<${#known_relatives[@]}; index++ )); do
    if path_exists "$transaction_dir/stage/$index"; then
      target="$base_dir/${known_relatives[index]}"
      ! path_exists "$target" || die 'a restore target unexpectedly exists'
      mkdir -p "${target%/*}"
      mv "$transaction_dir/stage/$index" "$target"
    fi
  done
fi

if [[ "${ORCHESTRATE_FAILPOINT:-}" == after-remove ]]; then
  die 'injected failure after removal'
fi

rm -rf "$transaction_dir"
transaction_dir=
trap - EXIT INT TERM

printf 'Removed path: %s\n' "$base_dir/.agents/skills/codex-prove"
printf 'Removed path: %s\n' "$base_dir/.agents/skills/sol-control"
printf 'Removed path: %s\n' "$base_dir/.codex/agents/prove-controller.toml"
printf 'Removed path: %s\n' "$base_dir/.codex/agents/prove-complex-worker.toml"
printf 'Removed path: %s\n' "$base_dir/.codex/agents/prove-efficient-worker.toml"
if (( restore_latest )); then
  printf 'Restored backup: %s\n' "$backup_dir"
fi
