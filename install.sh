#!/usr/bin/env bash
# cc-statusline installer.
# Usage:
#   ./install.sh                     interactive (default)
#   ./install.sh --force             replace any existing statusLine without asking
#   ./install.sh --keep-existing     install files but don't touch settings.json if statusLine exists
#   ./install.sh --abort-if-exists   exit non-zero if statusLine already exists (CI-friendly)
#   ./install.sh --dry-run           print what would happen without writing
#   ./install.sh --non-interactive   don't prompt; fail if a decision is needed

set -uo pipefail

REPO_URL="${CCSL_REPO_URL:-https://github.com/tenondecrpc/cc-statusline}"
INSTALL_DIR="${CCSL_INSTALL_DIR:-$HOME/.local/share/cc-statusline}"
CONFIG_DIR="${CCSL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/cc-statusline}"
CONFIG_FILE="$CONFIG_DIR/config.json"
SETTINGS_FILE="${CCSL_SETTINGS_FILE:-$HOME/.claude/settings.json}"
WRAPPER_DIR="${CCSL_WRAPPER_DIR:-$HOME/.local/bin}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

FORCE=0
KEEP_EXISTING=0
ABORT_IF_EXISTS=0
DRY_RUN=0
NON_INTERACTIVE=0

info() { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
err()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --force)            FORCE=1 ;;
      --keep-existing)    KEEP_EXISTING=1 ;;
      --abort-if-exists)  ABORT_IF_EXISTS=1 ;;
      --dry-run)          DRY_RUN=1 ;;
      --non-interactive)  NON_INTERACTIVE=1 ;;
      -h|--help)          usage; exit 0 ;;
      *) err "unknown flag: $arg"; usage; exit 1 ;;
    esac
  done
  if [ ! -t 0 ] && [ ! -e /dev/tty ]; then
    NON_INTERACTIVE=1
  fi
}

require_jq() {
  if command -v jq >/dev/null 2>&1; then
    return
  fi
  err "jq is required but not installed."
  if   command -v brew    >/dev/null 2>&1; then info "Run: brew install jq"
  elif command -v apt-get >/dev/null 2>&1; then info "Run: sudo apt-get install -y jq"
  elif command -v dnf     >/dev/null 2>&1; then info "Run: sudo dnf install -y jq"
  elif command -v pacman  >/dev/null 2>&1; then info "Run: sudo pacman -S jq"
  else                                          info "See https://jqlang.github.io/jq/download/"
  fi
  exit 1
}

# Source files: prefer local repo if install.sh is run from inside it; otherwise download.
SOURCE_DIR=""
detect_source() {
  local script_source script_dir
  script_source="${BASH_SOURCE[0]-}"

  if [ -n "$script_source" ] && [ -f "$script_source" ]; then
    script_dir="$(cd "$(dirname "$script_source")" && pwd)"
  else
    script_dir="$(pwd -P)"
  fi

  if [ -f "$script_dir/statusline.sh" ] && [ -d "$script_dir/lib" ] && [ -d "$script_dir/presets" ]; then
    SOURCE_DIR="$script_dir"
    info "Source: local repo at $SOURCE_DIR"
    return
  fi
  SOURCE_DIR="$(mktemp -d)"
  info "Source: downloading from $REPO_URL"
  if ! curl -fsSL "${REPO_URL}/archive/refs/heads/main.tar.gz" \
      | tar -xz -C "$SOURCE_DIR" --strip-components=1; then
    err "Download failed. Set CCSL_REPO_URL to a working repo or clone manually."
    exit 1
  fi
}

copy_files() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "DRY RUN: would copy files to $INSTALL_DIR"
    return
  fi
  local src_resolved dst_resolved
  src_resolved="$(cd "$SOURCE_DIR" 2>/dev/null && pwd -P || echo "$SOURCE_DIR")"
  dst_resolved="$(cd "$INSTALL_DIR" 2>/dev/null && pwd -P || echo "$INSTALL_DIR")"
  if [ "$SOURCE_DIR" = "$INSTALL_DIR" ] || [ "$src_resolved" = "$dst_resolved" ]; then
    info "Already at $INSTALL_DIR, skipping copy"
    return
  fi
  mkdir -p "$INSTALL_DIR"
  cp -f "$SOURCE_DIR/statusline.sh" "$INSTALL_DIR/"
  rm -rf "$INSTALL_DIR/lib" "$INSTALL_DIR/presets"
  cp -rf "$SOURCE_DIR/lib"     "$INSTALL_DIR/"
  cp -rf "$SOURCE_DIR/presets" "$INSTALL_DIR/"
  if [ -f "$SOURCE_DIR/uninstall.sh" ]; then
    cp -f "$SOURCE_DIR/uninstall.sh" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/uninstall.sh"
  fi
  if [ -f "$SOURCE_DIR/package.json" ]; then
    cp -f "$SOURCE_DIR/package.json" "$INSTALL_DIR/"
  fi
  chmod +x "$INSTALL_DIR/statusline.sh"
  ok "Installed files → $INSTALL_DIR"
}

install_cli_wrapper() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "DRY RUN: would install CLI wrapper to $WRAPPER_DIR/cc-statusline"
    return
  fi
  mkdir -p "$WRAPPER_DIR"
  cat > "$WRAPPER_DIR/cc-statusline" <<'WRAPPER_EOF'
#!/usr/bin/env bash
# cc-statusline CLI wrapper - managed by install.sh, do not edit directly

INSTALL_DIR="${CCSL_INSTALL_DIR:-$HOME/.local/share/cc-statusline}"
REPO_URL="${CCSL_REPO_URL:-https://github.com/tenondecrpc/cc-statusline}"

info() { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
err()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }

cmd="${1:-help}"
shift 2>/dev/null || true

# Forward to npm-installed binary when it exists, so commands like `install`,
# `render`, and `configure` work regardless of which cc-statusline is on PATH.
forward_to_npm() {
  local npm_global
  npm_global="$(npm config get prefix 2>/dev/null || true)"
  if [ -z "$npm_global" ] && command -v node >/dev/null 2>&1; then
    npm_global="$(node -e "console.log(process.env.npm_config_prefix || path.resolve(process.execPath, '../../lib/node_modules'))" 2>/dev/null || true)"
  fi
  if [ -n "$npm_global" ]; then
    local js_bin="${npm_global}/lib/node_modules/cc-statusline-cli/bin/cc-statusline.js"
    if [ -f "$js_bin" ]; then
      exec node "$js_bin" "$cmd" "$@"
    fi
  fi
}

case "$cmd" in
  update)
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    info "Downloading latest installer from $REPO_URL ..."
    if curl -fsSL "${REPO_URL}/raw/refs/heads/main/install.sh" -o "$tmp/install.sh"; then
      bash "$tmp/install.sh" --force "$@"
    else
      err "Download failed. Check your connection or set CCSL_REPO_URL."
      exit 1
    fi
    ;;
  install|configure)
    forward_to_npm
    # fallback: run installer directly
    if [ -f "$INSTALL_DIR/install.sh" ]; then
      bash "$INSTALL_DIR/install.sh" --force --non-interactive "$@"
    else
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      info "Downloading installer..."
      if curl -fsSL "${REPO_URL}/raw/refs/heads/main/install.sh" -o "$tmp/install.sh"; then
        bash "$tmp/install.sh" --force "$@"
      else
        err "Download failed. Check your connection or set CCSL_REPO_URL."
        exit 1
      fi
    fi
    ;;
  render)
    forward_to_npm
    if [ -f "$INSTALL_DIR/statusline.sh" ]; then
      exec bash "$INSTALL_DIR/statusline.sh" </dev/stdin
    fi
    err "statusline.sh not found. Run 'cc-statusline update' first."
    exit 1
    ;;
  version)
    if [ -f "$INSTALL_DIR/package.json" ] && command -v jq >/dev/null 2>&1; then
      jq -r '"v" + .version' "$INSTALL_DIR/package.json"
    else
      printf 'unknown\n'
    fi
    ;;
  uninstall)
    forward_to_npm
    if [ -f "$INSTALL_DIR/uninstall.sh" ]; then
      bash "$INSTALL_DIR/uninstall.sh" "$@"
    else
      err "Uninstaller not found at $INSTALL_DIR/uninstall.sh"
      exit 1
    fi
    ;;
  help|--help|-h)
    cat <<'HELP_EOF'
Usage: cc-statusline <command> [options]

Commands:
  install     configure Claude Code to use cc-statusline
  configure   alias for install
  render      read Claude Code session JSON from stdin and render the statusline
  update      download and re-install the latest version
  version     show the installed version
  uninstall   remove cc-statusline
  help        show this help

With no command and piped stdin, cc-statusline renders the statusline.

Environment variables:
  CCSL_INSTALL_DIR   override install directory (default: ~/.local/share/cc-statusline)
  CCSL_REPO_URL      override repository URL
HELP_EOF
    ;;
  *)
    forward_to_npm
    err "Unknown command: $cmd"
    printf 'Run '\''cc-statusline help'\'' for usage.\n' >&2
    exit 1
    ;;
esac
WRAPPER_EOF
  chmod +x "$WRAPPER_DIR/cc-statusline"
  ok "CLI wrapper → $WRAPPER_DIR/cc-statusline"
  if ! printf '%s' ":${PATH}:" | grep -q ":${WRAPPER_DIR}:"; then
    warn "$WRAPPER_DIR is not in your PATH."
    info "Add this to your shell profile (~/.zshrc or ~/.bashrc):"
    info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
}

ensure_user_config() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "DRY RUN: would ensure config at $CONFIG_FILE"
    return
  fi
  mkdir -p "$CONFIG_DIR"
  if [ ! -f "$CONFIG_FILE" ]; then
    printf '{ "preset": "default" }\n' > "$CONFIG_FILE"
    ok "Created default config → $CONFIG_FILE"
  else
    info "Kept existing config → $CONFIG_FILE"
  fi
}

# Expand a leading ~ in a path.
expand_tilde() {
  local p="$1"
  case "$p" in
    "~"|"~/"*) printf '%s' "${p/#\~/$HOME}" ;;
    *) printf '%s' "$p" ;;
  esac
}

# Echoes one of: absent | none | ours | ccstatusline | felipeelias | nilbuild | custom
classify_existing() {
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "absent"
    return
  fi
  if ! jq -e . "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo "absent"
    return
  fi
  if ! jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo "none"
    return
  fi

  local cmd expanded
  cmd=$(jq -r '.statusLine.command // ""' "$SETTINGS_FILE")
  expanded=$(expand_tilde "$cmd")

  case "$cmd" in
    *"cc-statusline/statusline.sh"*) echo "ours"; return ;;
    *ccstatusline*)                       echo "ccstatusline"; return ;;
    *"cc-statusline prompt"*)         echo "felipeelias"; return ;;
  esac

  if [ -f "$expanded" ]; then
    if grep -q "cc-statusline managed script\\|cc-statusline:v" "$expanded" 2>/dev/null; then
      echo "ours"; return
    fi
    if head -10 "$expanded" 2>/dev/null | grep -qiE "kamranahmedse|nilbuild"; then
      echo "nilbuild"; return
    fi
  fi

  echo "custom"
}

prompt_action() {
  local cmd="$1" source="$2" choice

  show_prompt() {
    printf '\nDetected an existing statusLine in %s:\n' "$SETTINGS_FILE"
    printf '  command: %s\n'   "$cmd"
    printf '  source : %s\n\n' "$source"
    printf 'What do you want to do?\n'
    printf '  [r] Replace it with cc-statusline (your current setup will be backed up)\n'
    printf '  [k] Keep your current statusline (script still installed for manual use)\n'
    printf '  [c] Cancel (no changes)\n\n'
  }

  if ! { show_prompt >/dev/tty; } 2>/dev/null; then
    show_prompt >&2
  fi

  while true; do
    if { printf '> ' >/dev/tty && read -r choice </dev/tty; } 2>/dev/null; then
      :
    elif [ -t 0 ]; then
      printf '> ' >&2
      if ! read -r choice; then
        echo "unavailable"
        return
      fi
    else
      echo "unavailable"
      return
    fi

    choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')
    case "$choice" in
      r|replace) echo "replace"; return ;;
      k|keep)    echo "keep"; return ;;
      c|cancel|"") echo "cancel"; return ;;
    esac
  done
}

backup_settings_and_script() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "DRY RUN: would back up $SETTINGS_FILE and any referenced script"
    return
  fi
  if [ -f "$SETTINGS_FILE" ]; then
    cp -f "$SETTINGS_FILE" "${SETTINGS_FILE}.bak.${TIMESTAMP}"
    ok "Backed up settings.json → ${SETTINGS_FILE}.bak.${TIMESTAMP}"
  fi
  local cmd expanded
  cmd=$(jq -r '.statusLine.command // ""' "$SETTINGS_FILE" 2>/dev/null || true)
  [ -z "$cmd" ] && return
  expanded=$(expand_tilde "$cmd")
  if [ -f "$expanded" ] && [ "$expanded" != "$INSTALL_DIR/statusline.sh" ]; then
    cp -f "$expanded" "${expanded}.bak.${TIMESTAMP}"
    ok "Backed up previous script → ${expanded}.bak.${TIMESTAMP}"
  elif [ -n "$cmd" ] && [ ! -f "$expanded" ]; then
    mkdir -p "$HOME/.claude"
    printf '%s\n' "$cmd" > "$HOME/.claude/statusline.previous.${TIMESTAMP}.txt"
    ok "Saved previous inline command → $HOME/.claude/statusline.previous.${TIMESTAMP}.txt"
  fi
}

write_settings() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "DRY RUN: would write statusLine to $SETTINGS_FILE pointing at $INSTALL_DIR/statusline.sh"
    return
  fi
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  if [ ! -f "$SETTINGS_FILE" ] || ! jq -e . "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo '{}' > "$SETTINGS_FILE"
  fi
  local tmp
  tmp="$(mktemp "${SETTINGS_FILE}.tmp.XXXXXX")"
  jq --arg cmd "$INSTALL_DIR/statusline.sh" \
     '.statusLine = { "type": "command", "command": $cmd, "padding": 1 }' \
     "$SETTINGS_FILE" > "$tmp"
  mv -f "$tmp" "$SETTINGS_FILE"
  ok "Wrote statusLine → $SETTINGS_FILE"
}

warn_project_override() {
  local proj="./.claude/settings.json"
  if [ -f "$proj" ] && jq -e '.statusLine' "$proj" >/dev/null 2>&1; then
    warn "Project-level statusLine in $proj will override the user-level one in this directory."
  fi
}

print_summary() {
  cat <<EOF

$(ok "cc-statusline ready")

  Script    : $INSTALL_DIR/statusline.sh
  Config    : $CONFIG_FILE
  Settings  : $SETTINGS_FILE

  Try it locally:
    echo '{"model":{"display_name":"Sonnet"},"workspace":{"current_dir":"'\$PWD'"},"context_window":{"used_percentage":42},"cost":{"total_cost_usd":0.12,"total_duration_ms":60000,"total_lines_added":0,"total_lines_removed":0}}' \\
      | $INSTALL_DIR/statusline.sh

  Change preset:
    edit $CONFIG_FILE → set "preset" to "minimal", "default", or "developer"

  Update to latest:
    cc-statusline update

  Uninstall:
    cc-statusline uninstall
EOF
}

main() {
  parse_args "$@"
  require_jq
  detect_source
  copy_files
  if [ "${CCSL_SKIP_WRAPPER:-0}" != "1" ]; then
    install_cli_wrapper
  fi
  ensure_user_config
  warn_project_override

  local state
  state=$(classify_existing)
  info "Existing statusLine state: $state"

  case "$state" in
    absent|none)
      backup_settings_and_script
      write_settings
      ;;
    ours)
      ok "cc-statusline already configured. Idempotent re-run, settings unchanged."
      ;;
    ccstatusline|felipeelias|nilbuild|custom)
      local cmd
      cmd=$(jq -r '.statusLine.command // ""' "$SETTINGS_FILE")

      if [ "$ABORT_IF_EXISTS" -eq 1 ]; then
        err "Existing statusLine detected ($state). Aborting (--abort-if-exists)."
        exit 2
      fi
      if [ "$KEEP_EXISTING" -eq 1 ]; then
        warn "Existing statusLine detected ($state). Keeping it; script available at $INSTALL_DIR/statusline.sh."
        print_summary
        return
      fi

      local action
      if [ "$FORCE" -eq 1 ]; then
        action="replace"
      elif [ "$NON_INTERACTIVE" -eq 1 ]; then
        warn "Existing statusLine detected ($state); keeping it because no prompt is available."
        info "Run with --force to replace it, or --keep-existing to keep it explicitly."
        exit 3
      else
        action=$(prompt_action "$cmd" "$state")
      fi

      case "$action" in
        replace)
          backup_settings_and_script
          write_settings
          ;;
        keep)
          warn "Kept your existing statusline. Our script is at $INSTALL_DIR/statusline.sh for manual use."
          ;;
        cancel)
          info "Cancelled. No changes made to $SETTINGS_FILE."
          exit 0
          ;;
        unavailable)
          warn "Existing statusLine detected ($state); keeping it because no prompt is available."
          info "Run with --force to replace it, or --keep-existing to keep it explicitly."
          exit 3
          ;;
        *)
          err "Unexpected installer choice: $action"
          exit 4
          ;;
      esac
      ;;
  esac

  print_summary
}

main "$@"
