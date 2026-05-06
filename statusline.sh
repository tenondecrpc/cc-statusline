#!/usr/bin/env bash
# cc-statusline managed script https://github.com/tenondecrpc/cc-statusline
# Reads Claude Code session JSON from stdin, prints a configurable status line.

set -uo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  case "$SOURCE" in /*) ;; *) SOURCE="$DIR/$SOURCE" ;; esac
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
export SCRIPT_DIR

# shellcheck source=lib/colors.sh
. "$SCRIPT_DIR/lib/colors.sh"
# shellcheck source=lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/git.sh
. "$SCRIPT_DIR/lib/git.sh"
# shellcheck source=lib/modules.sh
. "$SCRIPT_DIR/lib/modules.sh"
# shellcheck source=lib/render.sh
. "$SCRIPT_DIR/lib/render.sh"

INPUT_JSON="$(cat)"
export INPUT_JSON

load_config
init_colors
render_statusline
