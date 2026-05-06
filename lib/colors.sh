# ANSI color helpers + capability detection.
# 0=none, 1=16color, 2=256color, 3=truecolor

CCSL_COLOR_LEVEL=0

init_colors() {
  if [ -n "${NO_COLOR:-}" ]; then
    CCSL_COLOR_LEVEL=0
    return
  fi
  case "${COLORTERM:-}" in
    truecolor|24bit) CCSL_COLOR_LEVEL=3; return ;;
  esac
  case "${TERM:-}" in
    *-256color|*-truecolor|alacritty|xterm-kitty) CCSL_COLOR_LEVEL=2; return ;;
    xterm*|screen*|tmux*|linux|rxvt*) CCSL_COLOR_LEVEL=1; return ;;
    dumb|"") CCSL_COLOR_LEVEL=0; return ;;
  esac
  CCSL_COLOR_LEVEL=1
}

ccsl_fg() {
  [ "$CCSL_COLOR_LEVEL" -eq 0 ] && return 0
  local name="$1"
  case "$name" in
    black)         printf '\033[30m' ;;
    red)           printf '\033[31m' ;;
    green)         printf '\033[32m' ;;
    yellow)        printf '\033[33m' ;;
    blue)          printf '\033[34m' ;;
    magenta)       printf '\033[35m' ;;
    cyan)          printf '\033[36m' ;;
    white)         printf '\033[37m' ;;
    gray|grey)     printf '\033[90m' ;;
    bright_red)    printf '\033[91m' ;;
    bright_green)  printf '\033[92m' ;;
    bright_yellow) printf '\033[93m' ;;
    bright_blue)   printf '\033[94m' ;;
    bright_magenta)printf '\033[95m' ;;
    bright_cyan)   printf '\033[96m' ;;
    bright_white)  printf '\033[97m' ;;
    "") return 0 ;;
    *)
      if [[ "$name" =~ ^#([0-9a-fA-F]{6})$ ]]; then
        if [ "$CCSL_COLOR_LEVEL" -ge 3 ]; then
          local hex="${BASH_REMATCH[1]}"
          printf '\033[38;2;%d;%d;%dm' \
            $((16#${hex:0:2})) $((16#${hex:2:2})) $((16#${hex:4:2}))
        fi
      fi
      ;;
  esac
}

ccsl_reset() {
  [ "$CCSL_COLOR_LEVEL" -eq 0 ] && return 0
  printf '\033[0m'
}

ccsl_wrap() {
  local color="$1" text="$2"
  if [ "$CCSL_COLOR_LEVEL" -eq 0 ] || [ -z "$color" ]; then
    printf '%s' "$text"
  else
    printf '%s%s%s' "$(ccsl_fg "$color")" "$text" "$(ccsl_reset)"
  fi
}
