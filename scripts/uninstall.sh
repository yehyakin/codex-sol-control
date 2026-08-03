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

state_optional_value_file() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, length(wanted) + 2); found = 1 } END { if (!found) exit 0 }' "$file"
}

state_has_key() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '$1 == wanted { found = 1 } END { exit !found }' "$file"
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

assert_target() {
  local path="$1"
  local kind="$2"
  if ! path_exists "$path"; then
    return 0
  fi
  [[ ! -L "$path" ]] || die 'symbolic links are not allowed in an uninstall target'
  if [[ "$kind" == directory ]]; then
    [[ -d "$path" ]] || die 'an existing directory target has the wrong type'
  else
    [[ -f "$path" ]] || die 'an existing file target has the wrong type'
  fi
  assert_plain_tree "$path"
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

for command_name in find awk sort mktemp cp mv rm rmdir; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is unavailable: $command_name"
done
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  die 'a SHA-256 utility is unavailable'
fi

raw_home=${ORCHESTRATE_HOME:-${HOME:-}}
[[ -n "$raw_home" ]] || die 'ORCHESTRATE_HOME or HOME is required'
[[ "$raw_home" == /* ]] || die 'ORCHESTRATE_HOME must be an absolute path'
[[ "$raw_home" != / ]] || die 'refusing the filesystem root as ORCHESTRATE_HOME'
[[ -d "$raw_home" && ! -L "$raw_home" ]] || die 'ORCHESTRATE_HOME is not a safe directory'
base_dir=$(CDPATH= cd -- "$raw_home" && pwd -P) || die 'cannot resolve ORCHESTRATE_HOME'
[[ "$base_dir" != / ]] || die 'refusing the filesystem root as ORCHESTRATE_HOME'

new_skill_target="$base_dir/.agents/skills/sol-luna"
new_sol_target="$base_dir/.codex/agents/sol-controller.toml"
luna_target="$base_dir/.codex/agents/luna-max-worker.toml"
terra_target="$base_dir/.codex/agents/terra-high-worker.toml"
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
    [[ ! -L "$directory" && -d "$directory" ]] || die 'an uninstall parent is unsafe'
  fi
done

[[ -d "$state_root" && ! -L "$state_root" ]] || die 'no v0.2 installation state was found'
[[ -f "$state_file" && ! -L "$state_file" ]] || die 'no v0.2 installation state was found'
if path_exists "$config_target"; then
  assert_target "$config_target" file
fi
assert_target "$state_file" file
assert_target "$new_skill_target" directory
assert_target "$new_sol_target" file
assert_target "$luna_target" file
assert_target "$terra_target" file
assert_target "$legacy_skill_target" directory
assert_target "$legacy_sol_target" file
if path_exists "$legacy_state_file"; then assert_target "$legacy_state_file" file; fi

[[ "$(state_value_file "$state_file" version)" == 2 ]] || die 'install state is not v0.2'
backup_id=$(state_value_file "$state_file" backup_id) || die 'install state is incomplete'
[[ "$backup_id" =~ ^[A-Za-z0-9._-]+$ && "$backup_id" != . && "$backup_id" != .. ]] || die 'install state contains an unsafe backup identifier'
backup_dir="$backup_root/$backup_id"
[[ -d "$backup_dir" && ! -L "$backup_dir" ]] || die 'recorded backup is unavailable'
[[ -f "$backup_dir/manifest" && ! -L "$backup_dir/manifest" ]] || die 'recorded backup manifest is unavailable'

recorded_skill=$(state_value_file "$state_file" skill_sha256) || die 'install state is incomplete'
recorded_sol=$(state_value_file "$state_file" sol_sha256) || die 'install state is incomplete'
recorded_luna=$(state_value_file "$state_file" luna_sha256) || die 'install state is incomplete'
recorded_terra=$(state_optional_value_file "$state_file" terra_sha256)
valid_hash "$recorded_skill" || die 'install state has an invalid skill checksum'
valid_hash "$recorded_sol" || die 'install state has an invalid Sol checksum'
valid_hash "$recorded_luna" || die 'install state has an invalid Luna checksum'
if [[ -n "$recorded_terra" ]]; then valid_hash "$recorded_terra" || die 'install state has an invalid Terra checksum'; fi
[[ -d "$new_skill_target" && ! -L "$new_skill_target" ]] || die 'installed v0.2 skill is missing or unsafe'
[[ -f "$new_sol_target" && ! -L "$new_sol_target" ]] || die 'installed v0.2 Sol controller is missing or unsafe'
[[ -f "$luna_target" && ! -L "$luna_target" ]] || die 'installed v0.2 Luna agent is missing or unsafe'
[[ "$(sha256_tree "$new_skill_target")" == "$recorded_skill" ]] || die 'installed v0.2 skill was modified; refusing to remove it'
[[ "$(sha256_file "$new_sol_target")" == "$recorded_sol" ]] || die 'installed v0.2 Sol controller was modified; refusing to remove it'
[[ "$(sha256_file "$luna_target")" == "$recorded_luna" ]] || die 'installed v0.2 Luna agent was modified; refusing to remove it'
if [[ -n "$recorded_terra" ]]; then
  [[ -f "$terra_target" && ! -L "$terra_target" ]] || die 'installed v0.2 Terra agent is missing or unsafe'
  [[ "$(sha256_file "$terra_target")" == "$recorded_terra" ]] || die 'installed v0.2 Terra agent was modified; refusing to remove it'
fi

manifest_value() {
  state_value_file "$backup_dir/manifest" "$1"
}

[[ "$(manifest_value version)" == 2 ]] || die 'backup manifest is not v0.2'

verify_backup_entry() {
  local label="$1"
  local presence_key="$2"
  local checksum_key="$3"
  local artifact="$4"
  local kind="$5"
  local presence checksum actual
  presence=$(manifest_value "$presence_key") || die 'backup manifest is incomplete'
  checksum=$(manifest_value "$checksum_key") || die 'backup manifest is incomplete'
  [[ "$presence" == present || "$presence" == absent ]] || die 'backup manifest has an invalid presence value'
  if [[ "$presence" == present ]]; then
    valid_hash "$checksum" || die 'backup manifest has an invalid checksum'
    [[ -e "$artifact" && ! -L "$artifact" ]] || die "recorded $label backup is missing or unsafe"
    if [[ "$kind" == directory ]]; then
      [[ -d "$artifact" ]] || die "recorded $label backup has the wrong type"
      assert_plain_tree "$artifact"
      actual=$(sha256_tree "$artifact")
    else
      [[ -f "$artifact" ]] || die "recorded $label backup has the wrong type"
      actual=$(sha256_file "$artifact")
    fi
    [[ "$actual" == "$checksum" ]] || die "recorded $label backup was modified"
  else
    [[ -z "$checksum" ]] || die 'absent backup has a checksum'
    [[ ! -e "$artifact" && ! -L "$artifact" ]] || die 'absent backup has an unexpected artifact'
  fi
}

assert_target "$backup_dir" directory
assert_target "$backup_dir/legacy" directory
assert_target "$backup_dir/v020" directory
verify_backup_entry legacy-skill legacy_skill_presence legacy_skill_sha256 "$backup_dir/legacy/skill" directory
verify_backup_entry legacy-Sol legacy_sol_presence legacy_sol_sha256 "$backup_dir/legacy/sol-planner.toml" file
verify_backup_entry legacy-Luna legacy_luna_presence legacy_luna_sha256 "$backup_dir/legacy/luna-max-worker.toml" file
legacy_state_presence_key=0
legacy_state_sha256_key=0
if state_has_key "$backup_dir/manifest" legacy_state_presence; then legacy_state_presence_key=1; fi
if state_has_key "$backup_dir/manifest" legacy_state_sha256; then legacy_state_sha256_key=1; fi
if (( legacy_state_presence_key && legacy_state_sha256_key )); then
  verify_backup_entry legacy-install-state legacy_state_presence legacy_state_sha256 "$backup_dir/legacy/install-state" file
  legacy_state_presence=$(manifest_value legacy_state_presence)
elif (( legacy_state_presence_key || legacy_state_sha256_key )); then
  die 'backup manifest is incomplete'
else
  legacy_state_presence=absent
fi
verify_backup_entry v020-skill v020_skill_presence v020_skill_sha256 "$backup_dir/v020/skill" directory
verify_backup_entry v020-Sol v020_sol_presence v020_sol_sha256 "$backup_dir/v020/sol-controller.toml" file
verify_backup_entry v020-Luna v020_luna_presence v020_luna_sha256 "$backup_dir/v020/luna-max-worker.toml" file
if [[ -n "$recorded_terra" ]]; then
  verify_backup_entry v020-Terra v020_terra_presence v020_terra_sha256 "$backup_dir/v020/terra-high-worker.toml" file
fi

config_presence=$(manifest_value config_presence) || die 'backup manifest is incomplete'
config_sha256=$(manifest_value config_sha256) || die 'backup manifest is incomplete'
[[ "$config_presence" == present || "$config_presence" == absent ]] || die 'backup manifest has an invalid config presence'
if [[ "$config_presence" == present ]]; then
  valid_hash "$config_sha256" || die 'backup manifest has an invalid config checksum'
else
  [[ -z "$config_sha256" ]] || die 'absent config backup has a checksum'
fi

legacy_skill_presence=$(manifest_value legacy_skill_presence)
legacy_sol_presence=$(manifest_value legacy_sol_presence)
legacy_luna_presence=$(manifest_value legacy_luna_presence)
v020_skill_presence=$(manifest_value v020_skill_presence)
v020_sol_presence=$(manifest_value v020_sol_presence)
v020_luna_presence=$(manifest_value v020_luna_presence)
v020_terra_presence=absent
if [[ -n "$recorded_terra" ]]; then v020_terra_presence=$(manifest_value v020_terra_presence); fi

restore_legacy_skill=0
restore_legacy_sol=0
restore_legacy_state=0
restore_v020_skill=0
restore_v020_sol=0
restore_luna=0
restore_terra=0
if (( restore_latest )); then
  if [[ "$legacy_state_presence" == present ]]; then
    ! path_exists "$legacy_state_file" || die 'legacy install state already exists; refusing to overwrite it'
    restore_legacy_state=1
  fi
  if [[ "$legacy_skill_presence" == present ]] && ! path_exists "$legacy_skill_target"; then
    restore_legacy_skill=1
  fi
  if [[ "$legacy_sol_presence" == present ]] && ! path_exists "$legacy_sol_target"; then
    restore_legacy_sol=1
  fi
  if [[ "$v020_skill_presence" == present ]]; then
    restore_v020_skill=1
  fi
  if [[ "$v020_sol_presence" == present ]]; then
    restore_v020_sol=1
  fi
  if [[ "$legacy_luna_presence" == present ]]; then
    restore_luna=1
    luna_restore_source="$backup_dir/legacy/luna-max-worker.toml"
  elif [[ "$v020_luna_presence" == present ]]; then
    restore_luna=1
    luna_restore_source="$backup_dir/v020/luna-max-worker.toml"
  else
    luna_restore_source=
  fi
  if [[ "$v020_terra_presence" == present ]]; then restore_terra=1; fi
fi

transaction_dir=$(mktemp -d "$state_root/.uninstall.XXXXXX") || die 'cannot create the uninstall transaction'
mkdir "$transaction_dir/stage"
if (( restore_legacy_skill )); then copy_exact "$backup_dir/legacy/skill" "$transaction_dir/stage/legacy-skill"; fi
if (( restore_legacy_sol )); then copy_exact "$backup_dir/legacy/sol-planner.toml" "$transaction_dir/stage/legacy-sol.toml"; fi
if (( restore_legacy_state )); then copy_exact "$backup_dir/legacy/install-state" "$transaction_dir/stage/legacy-install-state"; fi
if (( restore_v020_skill )); then copy_exact "$backup_dir/v020/skill" "$transaction_dir/stage/v020-skill"; fi
if (( restore_v020_sol )); then copy_exact "$backup_dir/v020/sol-controller.toml" "$transaction_dir/stage/v020-sol.toml"; fi
if (( restore_luna )); then copy_exact "$luna_restore_source" "$transaction_dir/stage/luna.toml"; fi
if (( restore_terra )); then copy_exact "$backup_dir/v020/terra-high-worker.toml" "$transaction_dir/stage/terra.toml"; fi

state_old=0
skill_old=0
sol_old=0
luna_old=0
terra_old=0
legacy_skill_new=0
legacy_sol_new=0
legacy_state_new=0
legacy_state_root_new=0
v020_skill_new=0
v020_sol_new=0
luna_new=0
terra_new=0

rollback_uninstall() {
  local status="$1"
  trap - EXIT INT TERM
  set +e

  if (( luna_new )); then rm -f "$luna_target"; fi
  if (( luna_old )) && path_exists "$transaction_dir/old-luna"; then mv "$transaction_dir/old-luna" "$luna_target"; fi
  if (( terra_new )); then rm -f "$terra_target"; fi
  if (( terra_old )) && path_exists "$transaction_dir/old-terra"; then mv "$transaction_dir/old-terra" "$terra_target"; fi
  if (( v020_sol_new )); then rm -f "$new_sol_target"; fi
  if (( sol_old )) && path_exists "$transaction_dir/old-v020-sol"; then mv "$transaction_dir/old-v020-sol" "$new_sol_target"; fi
  if (( v020_skill_new )); then rm -rf "$new_skill_target"; fi
  if (( skill_old )) && path_exists "$transaction_dir/old-v020-skill"; then mv "$transaction_dir/old-v020-skill" "$new_skill_target"; fi
  if (( legacy_sol_new )); then rm -f "$legacy_sol_target"; fi
  if (( legacy_skill_new )); then rm -rf "$legacy_skill_target"; fi
  if (( legacy_state_new )); then rm -f "$legacy_state_file"; fi
  if (( legacy_state_root_new )); then rmdir "$legacy_state_root" 2>/dev/null || true; fi
  if (( state_old )) && path_exists "$transaction_dir/old-state"; then mv "$transaction_dir/old-state" "$state_file"; fi

  rm -rf "$transaction_dir"
  exit "$status"
}
trap 'rollback_uninstall "$?"' EXIT INT TERM

mv "$state_file" "$transaction_dir/old-state"
state_old=1

mv "$new_skill_target" "$transaction_dir/old-v020-skill"
skill_old=1
if (( restore_v020_skill )); then
  mv "$transaction_dir/stage/v020-skill" "$new_skill_target"
  v020_skill_new=1
fi

mv "$new_sol_target" "$transaction_dir/old-v020-sol"
sol_old=1
if (( restore_v020_sol )); then
  mv "$transaction_dir/stage/v020-sol.toml" "$new_sol_target"
  v020_sol_new=1
fi

mv "$luna_target" "$transaction_dir/old-luna"
luna_old=1
if (( restore_luna )); then
  mv "$transaction_dir/stage/luna.toml" "$luna_target"
  luna_new=1
fi

if [[ -n "$recorded_terra" ]]; then
  mv "$terra_target" "$transaction_dir/old-terra"
  terra_old=1
  if (( restore_terra )); then
    mv "$transaction_dir/stage/terra.toml" "$terra_target"
    terra_new=1
  fi
fi

if (( restore_legacy_skill )); then
  mv "$transaction_dir/stage/legacy-skill" "$legacy_skill_target"
  legacy_skill_new=1
fi
if (( restore_legacy_sol )); then
  mv "$transaction_dir/stage/legacy-sol.toml" "$legacy_sol_target"
  legacy_sol_new=1
fi
if (( restore_legacy_state )); then
  if ! path_exists "$legacy_state_root"; then
    mkdir "$legacy_state_root"
    legacy_state_root_new=1
  fi
  mv "$transaction_dir/stage/legacy-install-state" "$legacy_state_file"
  legacy_state_new=1
fi

rm -rf "$transaction_dir" || die 'cannot finalize the uninstall transaction'
transaction_dir=
trap - EXIT INT TERM

rm -rf "$backup_dir" 2>/dev/null || true
rmdir "$backup_root" 2>/dev/null || true
rmdir "$state_root" 2>/dev/null || true

printf 'Uninstall path: %s\n' "$new_skill_target"
printf 'Uninstall path: %s\n' "$new_sol_target"
printf 'Uninstall path: %s\n' "$luna_target"
if [[ -n "$recorded_terra" ]]; then printf 'Uninstall path: %s\n' "$terra_target"; fi
if (( restore_latest )); then
  printf 'Restore path: %s\n' "$legacy_skill_target"
  printf 'Restore path: %s\n' "$legacy_sol_target"
  if (( restore_legacy_state )); then printf 'Restore path: %s\n' "$legacy_state_file"; fi
fi
