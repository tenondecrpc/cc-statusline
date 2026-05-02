# Renders the configured lines by dispatching each module name to its mod_<name> function.

call_module() {
  local name="$1"
  if declare -F "mod_$name" >/dev/null 2>&1; then
    "mod_$name" 2>/dev/null || true
  fi
}

render_statusline() {
  local separator lines_count modules_count i j mod_name rendered out
  separator=$(cfg '.separator // " | "')
  lines_count=$(cfg_raw '.lines | length')

  i=0
  while [ "$i" -lt "$lines_count" ]; do
    modules_count=$(cfg_raw ".lines[$i] | length")
    out=""
    j=0
    while [ "$j" -lt "$modules_count" ]; do
      mod_name=$(cfg ".lines[$i][$j]")
      rendered=$(call_module "$mod_name")
      if [ -n "$rendered" ]; then
        if [ -z "$out" ]; then
          out="$rendered"
        else
          out="${out}${separator}${rendered}"
        fi
      fi
      j=$((j + 1))
    done
    printf '%s\n' "$out"
    i=$((i + 1))
  done
}
