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
export CCSL_CONFIG_DIR="$TMP_CONFIG"

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

run_developer_regressions() {
  local out
  printf '{ "preset": "developer" }\n' > "$TMP_CONFIG/config.json"
  out=$(NO_COLOR=1 "$STATUSLINE" < "$TESTS_DIR/fixtures/display_name_with_version.json" 2>&1)

  if [[ "$out" == *"4.7 4.7"* ]]; then
    printf '\033[31m✗\033[0m developer regression: duplicated model version\n'
    printf '%s\n' "$out" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  elif [[ "$out" == *"█"* || "$out" == *"░"* ]]; then
    printf '\033[31m✗\033[0m developer regression: non-default progress bar glyphs\n'
    printf '%s\n' "$out" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  elif [[ "$out" != *"⣿"* ]]; then
    printf '\033[31m✗\033[0m developer regression: missing default progress bar glyph\n'
    printf '%s\n' "$out" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  else
    printf '\033[32m✓\033[0m developer regressions\n'
    printf '%s\n' "$out" | sed 's/^/    /'
    PASS=$((PASS + 1))
  fi
  echo
}

run_npm_cli_regressions() {
  local out version settings_file
  printf '{ "preset": "default" }\n' > "$TMP_CONFIG/config.json"
  out=$(NO_COLOR=1 node "$ROOT_DIR/bin/cc-statusline.js" render < "$TESTS_DIR/fixtures/with_rate_limits.json" 2>&1)
  if [[ "$out" != *"Opus xhigh"* || "$out" != *"ctx"* || "$out" != *"5h"* || "$out" != *"7d"* ]]; then
    printf '\033[31m✗\033[0m npm cli regression: render output missing expected segments\n'
    printf '%s\n' "$out" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  else
    printf '\033[32m✓\033[0m npm cli render\n'
    printf '%s\n' "$out" | sed 's/^/    /'
    PASS=$((PASS + 1))
  fi

  version=$(node "$ROOT_DIR/bin/cc-statusline.js" version 2>&1)
  if [[ "$version" != v* ]]; then
    printf '\033[31m✗\033[0m npm cli regression: version output\n'
    printf '%s\n' "$version" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  else
    printf '\033[32m✓\033[0m npm cli version\n'
    printf '%s\n' "$version" | sed 's/^/    /'
    PASS=$((PASS + 1))
  fi

  if jq -e '
    (.scripts.postinstall? == null) and
    (((.files // []) | index("scripts/")) == null) and
    (((.files // []) | index("lib/")) == null) and
    (((.files // []) | index("statusline.sh")) == null) and
    (((.files // []) | index("install.sh")) == null) and
    (((.files // []) | index("uninstall.sh")) == null) and
    (((.files // []) | index("bin/")) != null) and
    (((.files // []) | index("presets/")) != null)
  ' "$ROOT_DIR/package.json" >/dev/null 2>&1; then
    printf '\033[32m✓\033[0m npm package is Node-only\n'
    PASS=$((PASS + 1))
  else
    printf '\033[31m✗\033[0m npm package regression: package should stay Node-only\n'
    FAIL=$((FAIL + 1))
  fi

  settings_file="$TMP_CONFIG/npm-settings.json"
  if CCSL_CONFIG_DIR="$TMP_CONFIG/npm-config" CCSL_SETTINGS_FILE="$settings_file" \
      node "$ROOT_DIR/bin/cc-statusline.js" install --force >/dev/null 2>&1 &&
      jq -e '.statusLine.command | contains("cc-statusline.js")' "$settings_file" >/dev/null 2>&1; then
    printf '\033[32m✓\033[0m npm cli install\n'
    PASS=$((PASS + 1))
  else
    printf '\033[31m✗\033[0m npm cli regression: install settings\n'
    [ -f "$settings_file" ] && sed 's/^/    /' "$settings_file"
    FAIL=$((FAIL + 1))
  fi
  echo
}

for fx in min with_rate_limits with_worktree vim_mode; do
  for ps in minimal default developer; do
    run_case "${fx}.json" "$ps"
  done
done

run_developer_regressions
run_npm_cli_regressions

printf '\nPass: %d, Fail: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
