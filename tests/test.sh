#!/usr/bin/env bash
# Smoke tests: pipe each fixture through statusline.sh with each preset.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
STATUSLINE="$ROOT_DIR/statusline.sh"

PASS=0
FAIL=0

TMP_CONFIG="$(mktemp -d)"
trap 'rm -rf "$TMP_CONFIG"' EXIT
export CSL_CONFIG_DIR="$TMP_CONFIG"

run_case() {
  local fixture="$1" preset="$2"
  printf '{ "preset": "%s" }\n' "$preset" > "$TMP_CONFIG/config.json"
  local out rc
  out=$(NO_COLOR=1 "$STATUSLINE" < "$TESTS_DIR/fixtures/$fixture" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
    printf '\033[32m✓\033[0m %s + %s\n' "$fixture" "$preset"
    printf '%s\n' "$out" | sed 's/^/    /'
    PASS=$((PASS + 1))
  else
    printf '\033[31m✗\033[0m %s + %s (exit %d)\n' "$fixture" "$preset" "$rc"
    printf '%s\n' "$out" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
  echo
}

for fx in min with_rate_limits with_worktree vim_mode; do
  for ps in minimal default developer; do
    run_case "${fx}.json" "$ps"
  done
done

printf '\nPass: %d, Fail: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
