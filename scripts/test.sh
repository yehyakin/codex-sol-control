#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)

python_bin=
for candidate in \
  "/opt/homebrew/opt/python@3.14/bin/python3.14" \
  "/opt/homebrew/bin/python3.14" \
  "python3.14" \
  "/opt/homebrew/opt/python@3.13/bin/python3.13" \
  "/opt/homebrew/bin/python3.13" \
  "python3.13" \
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
  if [[ -n "$candidate_path" ]] &&
    "$candidate_path" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' >/dev/null 2>&1; then
    python_bin="$candidate_path"
    break
  fi
done

if [[ -z "$python_bin" ]]; then
  printf 'scripts/test.sh: Python 3.11 or newer is required\n' >&2
  exit 1
fi

cd "$ROOT_DIR"
exec "$python_bin" -m unittest discover -s tests -q "$@"
