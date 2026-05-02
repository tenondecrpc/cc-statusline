#!/usr/bin/env bash
# claude-statusline uninstaller.
# Usage:
#   ./uninstall.sh                  default: restore latest backup, keep config & remove install dir
#   ./uninstall.sh --purge          also remove user config dir
#   ./uninstall.sh --keep-backups   don't delete .bak files

set -uo pipefail

INSTALL_DIR="${CSL_INSTALL_DIR:-$HOME/.local/share/claude-statusline}"
CONFIG_DIR="${CSL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude-statusline}"
SETTINGS_FILE="${CSL_SETTINGS_FILE:-$HOME/.claude/settings.json}"

PURGE=0
KEEP_BACKUPS=0

info() { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }

for arg in "$@"; do
  case "$arg" in
    --purge)         PURGE=1 ;;
    --keep-backups)  KEEP_BACKUPS=1 ;;
    -h|--help)
      sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) printf 'unknown flag: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

restore_settings() {
  local latest_bak
  latest_bak=$(ls -1 "${SETTINGS_FILE}".bak.* 2>/dev/null | sort -r | head -1)
  if [ -n "$latest_bak" ]; then
    cp "$latest_bak" "$SETTINGS_FILE"
    ok "Restored settings.json from $latest_bak"
    return
  fi
  if [ -f "$SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
    if jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
      local tmp
      tmp=$(mktemp)
      jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp"
      mv "$tmp" "$SETTINGS_FILE"
      ok "Removed statusLine from $SETTINGS_FILE (no backup found)"
    fi
  fi
}

restore_user_script() {
  local latest
  latest=$(ls -1 "$HOME"/.claude/statusline.sh.bak.* 2>/dev/null | sort -r | head -1)
  if [ -n "$latest" ] && [ ! -e "$HOME/.claude/statusline.sh" ]; then
    cp "$latest" "$HOME/.claude/statusline.sh"
    chmod +x "$HOME/.claude/statusline.sh"
    ok "Restored previous user script → $HOME/.claude/statusline.sh"
  fi
}

cleanup_install_dir() {
  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    ok "Removed $INSTALL_DIR"
  fi
}

cleanup_config() {
  if [ "$PURGE" -eq 1 ]; then
    if [ -d "$CONFIG_DIR" ]; then
      rm -rf "$CONFIG_DIR"
      ok "Removed $CONFIG_DIR"
    fi
  else
    info "Kept user config at $CONFIG_DIR (use --purge to remove)"
  fi
}

cleanup_backups() {
  [ "$KEEP_BACKUPS" -eq 1 ] && return
  rm -f "${SETTINGS_FILE}".bak.*                      2>/dev/null || true
  rm -f "$HOME"/.claude/statusline.sh.bak.*           2>/dev/null || true
  rm -f "$HOME"/.claude/statusline.previous.*.txt     2>/dev/null || true
}

restore_settings
restore_user_script
cleanup_install_dir
cleanup_config
cleanup_backups
ok "Uninstall complete."
