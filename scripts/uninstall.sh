#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

die() {
  printf 'uninstall.sh: %s\n' "$1" >&2
  exit 1
}

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
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, length(wanted) + 2); found = 1 } END { if (!found) exit 1 }' "$file"
}

raw_home=${ORCHESTRATE_HOME:-${HOME:-}}
[[ -n "$raw_home" ]] || die 'ORCHESTRATE_HOME or HOME is required'
[[ "$raw_home" == /* ]] || die 'ORCHESTRATE_HOME must be an absolute path'
[[ "$raw_home" != / ]] || die 'refusing the filesystem root as ORCHESTRATE_HOME'
[[ -d "$raw_home" && ! -L "$raw_home" ]] || die 'ORCHESTRATE_HOME is not a safe directory'
base_dir=$(CDPATH= cd -- "$raw_home" && pwd -P) || die 'cannot resolve ORCHESTRATE_HOME'
[[ "$base_dir" != / ]] || die 'refusing the filesystem root as ORCHESTRATE_HOME'

case "${1:-}" in
  '')
    restore_latest=0
    ;;
  --restore-latest)
    restore_latest=1
    ;;
  *)
    die 'usage: uninstall.sh [--restore-latest]'
    ;;
esac
[[ "$#" -le 1 ]] || die 'usage: uninstall.sh [--restore-latest]'

skill_target="$base_dir/.agents/skills/orchestrate-sol-luna"
codex_dir="$base_dir/.codex"
agents_dir="$codex_dir/agents"
sol_target="$agents_dir/sol-planner.toml"
luna_target="$agents_dir/luna-max-worker.toml"
state_root="$codex_dir/orchestrate-sol-luna"
state_file="$state_root/install-state"
config_target="$codex_dir/config.toml"

for directory in "$base_dir/.agents" "$base_dir/.agents/skills" "$codex_dir" "$agents_dir" "$state_root" "$state_root/backups"; do
  if [[ -L "$directory" ]]; then
    die 'refusing a symbolic-link directory in the install path'
  fi
done
[[ -d "$state_root" && -d "$state_root/backups" ]] || die 'no installation state was found'
[[ -f "$state_file" && ! -L "$state_file" ]] || die 'no installation state was found'
[[ -f "$config_target" || ! -e "$config_target" ]] || die 'config.toml has an unsafe type'

recorded_backup=$(state_value "$state_file" backup_id) || die 'install state is incomplete'
[[ "$recorded_backup" =~ ^[A-Za-z0-9._-]+$ ]] || die 'install state contains an unsafe backup identifier'
backup_dir="$state_root/backups/$recorded_backup"
[[ -d "$backup_dir" && ! -L "$backup_dir" ]] || die 'recorded backup is unavailable'
[[ -f "$backup_dir/manifest" && ! -L "$backup_dir/manifest" ]] || die 'recorded backup manifest is unavailable'

recorded_skill=$(state_value "$state_file" skill_sha256) || die 'install state is incomplete'
recorded_sol=$(state_value "$state_file" sol_sha256) || die 'install state is incomplete'
recorded_luna=$(state_value "$state_file" luna_sha256) || die 'install state is incomplete'
[[ "$recorded_skill" =~ ^[0-9a-f]{64}$ ]] || die 'install state has an invalid skill checksum'
[[ "$recorded_sol" =~ ^[0-9a-f]{64}$ ]] || die 'install state has an invalid Sol checksum'
[[ "$recorded_luna" =~ ^[0-9a-f]{64}$ ]] || die 'install state has an invalid Luna checksum'

[[ -d "$skill_target" && ! -L "$skill_target" ]] || die 'installed skill is missing or unsafe'
[[ -f "$sol_target" && ! -L "$sol_target" ]] || die 'installed Sol agent is missing or unsafe'
[[ -f "$luna_target" && ! -L "$luna_target" ]] || die 'installed Luna agent is missing or unsafe'
[[ "$(sha256_tree "$skill_target")" == "$recorded_skill" ]] || die 'installed skill was modified; refusing to remove it'
[[ "$(sha256_file "$sol_target")" == "$recorded_sol" ]] || die 'installed Sol agent was modified; refusing to remove it'
[[ "$(sha256_file "$luna_target")" == "$recorded_luna" ]] || die 'installed Luna agent was modified; refusing to remove it'

manifest_value() {
  state_value "$backup_dir/manifest" "$1"
}

for key in skill_presence sol_presence luna_presence config_presence; do
  presence=$(manifest_value "$key") || die 'backup manifest is incomplete'
  [[ "$presence" == present || "$presence" == absent ]] || die 'backup manifest contains an invalid presence value'
done

verify_backup_entry() {
  local label="$1"
  local presence_key="$2"
  local checksum_key="$3"
  local artifact="$4"
  local presence checksum actual
  presence=$(manifest_value "$presence_key") || die 'backup manifest is incomplete'
  checksum=$(manifest_value "$checksum_key") || die 'backup manifest is incomplete'
  if [[ "$presence" == present ]]; then
    [[ -e "$artifact" && ! -L "$artifact" ]] || die 'recorded backup artifact is missing or unsafe'
    [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || die 'recorded backup checksum is invalid'
    if [[ -d "$artifact" ]]; then
      actual=$(sha256_tree "$artifact")
    else
      actual=$(sha256_file "$artifact")
    fi
    [[ "$actual" == "$checksum" ]] || die "recorded $label backup was modified"
  else
    [[ -z "$checksum" ]] || die 'absent backup has a checksum'
    [[ ! -e "$artifact" && ! -L "$artifact" ]] || die 'absent backup has an unexpected artifact'
  fi
}

verify_backup_entry skill skill_presence skill_sha256 "$backup_dir/skill"
verify_backup_entry Sol sol_presence sol_sha256 "$backup_dir/sol-planner.toml"
verify_backup_entry Luna luna_presence luna_sha256 "$backup_dir/luna-max-worker.toml"
verify_backup_entry config config_presence config_sha256 "$backup_dir/config.toml"

transaction_dir=$(mktemp -d "$state_root/.uninstall.XXXXXX") || die 'cannot create the uninstall transaction'
if (( restore_latest )); then
  mkdir "$transaction_dir/stage"
  skill_presence=$(manifest_value skill_presence)
  sol_presence=$(manifest_value sol_presence)
  luna_presence=$(manifest_value luna_presence)
  if [[ "$skill_presence" == present ]]; then cp -a "$backup_dir/skill" "$transaction_dir/stage/skill"; fi
  if [[ "$sol_presence" == present ]]; then cp -p "$backup_dir/sol-planner.toml" "$transaction_dir/stage/sol-planner.toml"; fi
  if [[ "$luna_presence" == present ]]; then cp -p "$backup_dir/luna-max-worker.toml" "$transaction_dir/stage/luna-max-worker.toml"; fi
fi

skill_had=0
skill_new=0
sol_had=0
sol_new=0
luna_had=0
luna_new=0
state_had=0

rollback_uninstall() {
  local status="$1"
  trap - EXIT INT TERM
  set +e

  if (( luna_new )); then rm -rf "$luna_target"; fi
  if (( luna_had )) && path_exists "$transaction_dir/old-luna"; then mv "$transaction_dir/old-luna" "$luna_target"; fi
  if (( sol_new )); then rm -rf "$sol_target"; fi
  if (( sol_had )) && path_exists "$transaction_dir/old-sol"; then mv "$transaction_dir/old-sol" "$sol_target"; fi
  if (( skill_new )); then rm -rf "$skill_target"; fi
  if (( skill_had )) && path_exists "$transaction_dir/old-skill"; then mv "$transaction_dir/old-skill" "$skill_target"; fi
  if (( state_had )) && path_exists "$transaction_dir/old-state"; then mv "$transaction_dir/old-state" "$state_file"; fi

  rm -rf "$transaction_dir"
  exit "$status"
}
trap 'rollback_uninstall "$?"' EXIT INT TERM

mv "$state_file" "$transaction_dir/old-state"
state_had=1

mv "$skill_target" "$transaction_dir/old-skill"
skill_had=1
if (( restore_latest )) && [[ "$skill_presence" == present ]]; then
  mv "$transaction_dir/stage/skill" "$skill_target"
  skill_new=1
fi

mv "$sol_target" "$transaction_dir/old-sol"
sol_had=1
if (( restore_latest )) && [[ "$sol_presence" == present ]]; then
  mv "$transaction_dir/stage/sol-planner.toml" "$sol_target"
  sol_new=1
fi

mv "$luna_target" "$transaction_dir/old-luna"
luna_had=1
if (( restore_latest )) && [[ "$luna_presence" == present ]]; then
  mv "$transaction_dir/stage/luna-max-worker.toml" "$luna_target"
  luna_new=1
fi

rm -rf "$transaction_dir" || die 'cannot finalize the uninstall transaction'
trap - EXIT INT TERM

printf 'Uninstall path: %s\n' "$skill_target"
printf 'Uninstall path: %s\n' "$sol_target"
printf 'Uninstall path: %s\n' "$luna_target"
if (( restore_latest )); then
  printf 'Restore path: %s\n' "$backup_dir"
fi
