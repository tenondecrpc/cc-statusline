# Module implementations. Each `mod_<name>` writes the rendered (colored) text to stdout.
# Empty output = "hide this module".

mod_model() {
  local name id version version_re short with_version with_effort effort out
  name=$(printf '%s' "$INPUT_JSON" | jq -r '.model.display_name // empty')
  [ -z "$name" ] && return 0

  short=$(cfg '.modules.model.short // false')
  if [ "$short" = "true" ]; then
    name=$(printf '%s' "$name" | awk '{print $1}')
  fi

  with_version=$(cfg '.modules.model.with_version // false')
  if [ "$with_version" = "true" ]; then
    id=$(printf '%s' "$INPUT_JSON" | jq -r '.model.id // empty')
    if [ -n "$id" ]; then
      version=$(printf '%s' "$id" | sed -E 's/.*-([0-9]+)-([0-9]+)(-[0-9]{6,})?$/\1.\2/')
      if [ "$version" != "$id" ]; then
        version_re="${version//./\\.}"
        if [[ ! "$name" =~ (^|[^0-9])${version_re}([^0-9]|$) ]]; then
          name="$name $version"
        fi
      fi
    fi
  fi

  out=$(ccsl_wrap "$(cfg '.colors.model // "white"')" "$name")

  with_effort=$(cfg '.modules.model.with_effort // false')
  if [ "$with_effort" = "true" ]; then
    effort=$(printf '%s' "$INPUT_JSON" | jq -r '.effort.level // empty')
    if [ -n "$effort" ]; then
      out="$out $(ccsl_wrap "$(cfg '.colors.effort // "gray"')" "$effort")"
    fi
  fi
  printf '%s' "$out"
}

mod_effort() {
  local level
  level=$(printf '%s' "$INPUT_JSON" | jq -r '.effort.level // empty')
  [ -z "$level" ] && return 0
  ccsl_wrap "$(cfg '.colors.effort // "gray"')" "$level"
}

ccsl_format_tokens() {
  awk -v n="${1:-0}" 'BEGIN {
    if (n+0 <= 0) exit
    if (n >= 1000000) {
      v = n / 1000000
      if (v == int(v)) printf "%dm", v; else printf "%.1fm", v
    } else if (n >= 1000) {
      v = n / 1000
      if (v == int(v)) printf "%dk", v; else printf "%.1fk", v
    } else {
      printf "%d", n
    }
  }'
}

ccsl_context_size_label() {
  local label tokens
  tokens=$(printf '%s' "$INPUT_JSON" | jq -r '.context_window.context_window_size // empty')
  if [ -n "$tokens" ] && [ "$tokens" != "null" ]; then
    label=$(ccsl_format_tokens "$tokens")
    if [ -n "$label" ]; then
      printf '%s' "$label"
      return 0
    fi
  fi
  cfg '.modules.context_bar.default_size // "200k"'
}

basic_bg_color_for() {
  local pct="$1"
  if awk "BEGIN {exit !($pct >= 80)}"; then
    printf '\033[48;5;196m'
  elif awk "BEGIN {exit !($pct >= 60)}"; then
    printf '\033[48;5;220m'
  else
    printf '\033[48;5;154m'
  fi
}

basic_fg_color_for() {
  local pct="$1"
  if awk "BEGIN {exit !($pct >= 80)}"; then
    printf '\033[38;5;196m'
  elif awk "BEGIN {exit !($pct >= 60)}"; then
    printf '\033[38;5;220m'
  else
    printf '\033[38;5;154m'
  fi
}

basic_make_bar() {
  local pct="$1" bg="$2" fg="$3" width="${4:-12}" filled empty i
  filled=$(awk "BEGIN {printf \"%d\", int($pct / 100 * $width + 0.5)}")
  [ "$filled" -lt 0 ] && filled=0
  [ "$filled" -gt "$width" ] && filled="$width"
  empty=$((width - filled))
  local filled_str="" empty_str=""
  for ((i=0; i<filled; i++)); do filled_str+=" "; done
  for ((i=0; i<empty; i++)); do empty_str+="⣿"; done
  printf "${bg}%s\033[0m\033[2m${fg}%s\033[0m" "$filled_str" "$empty_str"
}

basic_make_empty_bar() {
  local width="${1:-12}" i empty_str=""
  for ((i=0; i<width; i++)); do empty_str+="⣿"; done
  printf "\033[2m\033[38;5;245m%s\033[0m" "$empty_str"
}

basic_render_progress() {
  local pct="$1" width="${2:-12}" bg fg pct_label reset='\033[0m'
  bg=$(basic_bg_color_for "$pct")
  fg=$(basic_fg_color_for "$pct")
  pct_label=$(awk -v v="$pct" 'BEGIN {printf "%.0f", v+0}')
  printf "%s ${fg}%s%%${reset}" "$(basic_make_bar "$pct" "$bg" "$fg" "$width")" "$pct_label"
}

basic_format_time() {
  local epoch="$1" format="$2"
  date -r "$epoch" "$format" 2>/dev/null || date -d "@$epoch" "$format" 2>/dev/null || true
}

mod_basic_statusline() {
  local model effort used five_hour seven_day five_reset seven_reset size_label
  model=$(printf '%s' "$INPUT_JSON" | jq -r '.model.display_name // empty')
  effort=$(printf '%s' "$INPUT_JSON" | jq -r '.effort.level // empty')
  used=$(printf '%s' "$INPUT_JSON" | jq -r '.context_window.used_percentage // empty')
  five_hour=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  seven_day=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  five_reset=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.five_hour.resets_at // empty')
  seven_reset=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.seven_day.resets_at // empty')
  size_label=$(ccsl_context_size_label)

  local reset='\033[0m' yellow='\033[33m' dim='\033[2m' sep=' │ '
  local part_model="" part_ctx part_5h part_7d t dt ctx_label

  if [ -n "$model" ]; then
    part_model="$(printf "${yellow}%s${reset}" "$model")"
    [ -n "$effort" ] && part_model+="$(printf " ${dim}%s${reset}" "$effort")"
  fi

  if [ -n "$size_label" ]; then
    ctx_label="ctx(${size_label})"
  else
    ctx_label="ctx"
  fi

  if [ -n "$used" ]; then
    part_ctx="$(printf "%s %s" "$ctx_label" "$(basic_render_progress "$used")")"
  else
    part_ctx="$(printf "%s %s ${dim}--${reset}" "$ctx_label" "$(basic_make_empty_bar)")"
  fi

  if [ -n "$five_hour" ]; then
    part_5h="$(printf "5h %s" "$(basic_render_progress "$five_hour")")"
    if [ -n "$five_reset" ]; then
      t=$(basic_format_time "$five_reset" "+%H:%M")
      [ -n "$t" ] && part_5h+="$(printf " ${dim}%s${reset}" "$t")"
    fi
  else
    part_5h="$(printf "5h %s ${dim}--${reset}" "$(basic_make_empty_bar)")"
  fi

  if [ -n "$seven_day" ]; then
    part_7d="$(printf "7d %s" "$(basic_render_progress "$seven_day")")"
    if [ -n "$seven_reset" ]; then
      dt=$(basic_format_time "$seven_reset" "+%b %d %H:%M")
      [ -n "$dt" ] && part_7d+="$(printf " ${dim}%s${reset}" "$dt")"
    fi
  else
    part_7d="$(printf "7d %s ${dim}--${reset}" "$(basic_make_empty_bar)")"
  fi

  local parts=("$part_model" "$part_ctx" "$part_5h" "$part_7d")
  local out="" i
  for i in "${!parts[@]}"; do
    [ -z "${parts[$i]}" ] && continue
    [ -n "$out" ] && out+="$sep"
    out+="${parts[$i]}"
  done

  printf '%s' "$out"
}

mod_directory() {
  local dir tilde truncate
  dir=$(printf '%s' "$INPUT_JSON" | jq -r '.workspace.current_dir // .cwd // empty')
  [ -z "$dir" ] && return 0
  tilde=$(cfg '.modules.directory.tilde // true')
  truncate=$(cfg '.modules.directory.truncate // 30')
  if [ "$tilde" = "true" ]; then
    dir="${dir/#$HOME/~}"
  fi
  if [ "${#dir}" -gt "$truncate" ]; then
    local keep=$((truncate - 1))
    dir="…${dir: -$keep}"
  fi
  ccsl_wrap "$(cfg '.colors.directory // "blue"')" "$dir"
}

mod_git() {
  git_in_repo || return 0
  local branch staged=0 unstaged=0 untracked=0 ahead=0 behind=0 total=0
  branch=$(git_branch_name)
  [ -z "$branch" ] && return 0

  local show_status show_ahead_behind out
  show_status=$(cfg '.modules.git.show_status // true')
  show_ahead_behind=$(cfg '.modules.git.show_ahead_behind // true')
  out="$branch"

  if [ "$show_status" = "true" ]; then
    read -r staged unstaged untracked <<< "$(git_status_counts)"
    total=$((staged + unstaged + untracked))
    if [ "$total" -gt 0 ]; then
      out+=" ●"
      [ "$staged" -gt 0 ]    && out+=" +$staged"
      [ "$unstaged" -gt 0 ]  && out+=" !$unstaged"
      [ "$untracked" -gt 0 ] && out+=" ?$untracked"
    fi
  fi

  if [ "$show_ahead_behind" = "true" ]; then
    read -r ahead behind <<< "$(git_ahead_behind)"
    [ "$ahead" -gt 0 ]  && out+=" ↑$ahead"
    [ "$behind" -gt 0 ] && out+=" ↓$behind"
  fi

  local color
  if [ "$total" -gt 0 ]; then
    color=$(cfg '.colors.git_dirty // "yellow"')
  else
    color=$(cfg '.colors.git_clean // "green"')
  fi
  ccsl_wrap "$color" "$out"
}

threshold_color() {
  local pct="$1" warn="$2" crit="$3" ok_key="$4" warn_key="$5" crit_key="$6"
  if [ "$pct" -ge "$crit" ]; then
    cfg ".colors.${crit_key} // \"red\""
  elif [ "$pct" -ge "$warn" ]; then
    cfg ".colors.${warn_key} // \"yellow\""
  else
    cfg ".colors.${ok_key} // \"green\""
  fi
}

# Format epoch seconds as "HH:MM" (today) or "Mon DD HH:MM" (other day).
format_reset_time() {
  local epoch="$1" today reset_day
  [ -z "$epoch" ] || [ "$epoch" = "null" ] && return 0
  today=$(date +"%Y-%m-%d" 2>/dev/null) || return 0
  if reset_day=$(date -r "$epoch" +"%Y-%m-%d" 2>/dev/null); then
    if [ "$today" = "$reset_day" ]; then
      date -r "$epoch" +"%H:%M"
    else
      date -r "$epoch" +"%b %d %H:%M"
    fi
  elif reset_day=$(date -d "@$epoch" +"%Y-%m-%d" 2>/dev/null); then
    if [ "$today" = "$reset_day" ]; then
      date -d "@$epoch" +"%H:%M"
    else
      date -d "@$epoch" +"%b %d %H:%M"
    fi
  fi
}

mod_context_bar() {
  local pct width label size_label
  pct=$(printf '%s' "$INPUT_JSON" | jq -r '.context_window.used_percentage // 0')
  width=$(cfg '.modules.context_bar.width // 12')
  label=$(cfg '.modules.context_bar.label // "ctx"')
  size_label=$(ccsl_context_size_label)

  if [ -n "$label" ] && [ "$label" != "null" ]; then
    if [ -n "$size_label" ]; then
      printf '%s(%s) ' "$label" "$size_label"
    else
      printf '%s ' "$label"
    fi
  fi
  basic_render_progress "$pct" "$width"
}

mod_context_pct() {
  local pct warn_at crit_at color
  pct=$(printf '%s' "$INPUT_JSON" | jq -r '.context_window.used_percentage // 0' | awk '{printf "%d", $1}')
  warn_at=$(cfg '.modules.context_bar.thresholds_pct[0] // 70')
  crit_at=$(cfg '.modules.context_bar.thresholds_pct[1] // 90')
  color=$(threshold_color "$pct" "$warn_at" "$crit_at" "context_ok" "context_warn" "context_crit")
  ccsl_wrap "$color" "ctx ${pct}%"
}

render_rate_segment() {
  local label="$1" pct="$2" resets="$3"
  local width reset_str
  width=$(cfg '.modules.rate_limit.bar_width // 12')

  printf '%s ' "$label"
  basic_render_progress "$pct" "$width"

  if [ -n "$resets" ] && [ "$resets" != "null" ]; then
    reset_str=$(format_reset_time "$resets")
    if [ -n "$reset_str" ]; then
      printf ' '
      ccsl_wrap "$(cfg '.colors.rate_reset // "gray"')" "$reset_str"
    fi
  fi
}

mod_rate_5h() {
  local pct resets
  pct=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  [ -z "$pct" ] && return 0
  resets=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.five_hour.resets_at // empty')
  render_rate_segment "5h" "$pct" "$resets"
}

mod_rate_7d() {
  local pct resets
  pct=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  [ -z "$pct" ] && return 0
  resets=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.seven_day.resets_at // empty')
  render_rate_segment "7d" "$pct" "$resets"
}

mod_cost() {
  local cost hide_below format skip formatted
  cost=$(printf '%s' "$INPUT_JSON" | jq -r '.cost.total_cost_usd // 0')
  hide_below=$(cfg '.modules.cost.hide_below // 0')
  format=$(cfg '.modules.cost.format // "$%.2f"')

  skip=$(awk -v c="$cost" -v h="$hide_below" 'BEGIN { print (c+0 < h+0) ? "1" : "0" }')
  [ "$skip" = "1" ] && return 0

  formatted=$(awk -v c="$cost" -v f="$format" 'BEGIN { printf f, c+0 }')
  ccsl_wrap "$(cfg '.colors.cost // "magenta"')" "$formatted"
}

mod_rate_limit() {
  local five seven text=""
  five=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  seven=$(printf '%s' "$INPUT_JSON" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  if [ -n "$five" ]; then
    text="5h $(awk -v v="$five" 'BEGIN{printf "%.0f", v+0}')%"
  fi
  if [ -n "$seven" ]; then
    [ -n "$text" ] && text+=" "
    text+="7d $(awk -v v="$seven" 'BEGIN{printf "%.0f", v+0}')%"
  fi
  [ -z "$text" ] && return 0
  ccsl_wrap "$(cfg '.colors.rate_limit // "gray"')" "$text"
}

mod_session_timer() {
  local ms s h m out
  ms=$(printf '%s' "$INPUT_JSON" | jq -r '.cost.total_duration_ms // empty')
  [ -z "$ms" ] || [ "$ms" = "0" ] && return 0
  s=$((ms / 1000))
  h=$((s / 3600))
  m=$(( (s % 3600) / 60 ))
  if [ "$h" -gt 0 ]; then
    out="${h}h${m}m"
  elif [ "$m" -gt 0 ]; then
    out="${m}m"
  else
    out="${s}s"
  fi
  ccsl_wrap "$(cfg '.colors.session_timer // "gray"')" "$out"
}

mod_lines_changed() {
  local added removed
  added=$(printf '%s' "$INPUT_JSON" | jq -r '.cost.total_lines_added // 0')
  removed=$(printf '%s' "$INPUT_JSON" | jq -r '.cost.total_lines_removed // 0')
  if [ "$added" -eq 0 ] && [ "$removed" -eq 0 ]; then return 0; fi
  ccsl_wrap "$(cfg '.colors.lines_changed // "gray"')" "+${added} -${removed}"
}

mod_vim_mode() {
  local mode
  mode=$(printf '%s' "$INPUT_JSON" | jq -r '.vim.mode // empty')
  [ -z "$mode" ] && return 0
  ccsl_wrap "$(cfg '.colors.vim_mode // "magenta"')" "[$mode]"
}

mod_worktree() {
  local name
  name=$(printf '%s' "$INPUT_JSON" | jq -r '.worktree.name // .workspace.git_worktree // empty')
  [ -z "$name" ] && return 0
  ccsl_wrap "$(cfg '.colors.worktree // "blue"')" "wt:$name"
}

mod_agent() {
  local name
  name=$(printf '%s' "$INPUT_JSON" | jq -r '.agent.name // empty')
  [ -z "$name" ] && return 0
  ccsl_wrap "$(cfg '.colors.agent // "magenta"')" "@$name"
}
