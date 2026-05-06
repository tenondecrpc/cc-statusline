# Loads the active config: deep-merges a preset with the user's overrides.

CCSL_CONFIG_DIR="${CCSL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/cc-statusline}"
CCSL_USER_CONFIG="$CCSL_CONFIG_DIR/config.json"
CCSL_PRESETS_DIR="$SCRIPT_DIR/presets"

# After load_config, $CCSL_CONFIG holds the merged JSON.
load_config() {
  local user_cfg="{}"
  if [ -f "$CCSL_USER_CONFIG" ]; then
    user_cfg="$(cat "$CCSL_USER_CONFIG" 2>/dev/null || echo '{}')"
    # If user config is invalid JSON, fall back to empty.
    if ! printf '%s' "$user_cfg" | jq -e . >/dev/null 2>&1; then
      user_cfg="{}"
    fi
  fi

  local preset_name
  preset_name=$(printf '%s' "$user_cfg" | jq -r '.preset // "default"')

  local preset_path="$CCSL_PRESETS_DIR/${preset_name}.json"
  if [ ! -f "$preset_path" ]; then
    preset_path="$CCSL_PRESETS_DIR/default.json"
  fi
  local preset_cfg
  preset_cfg="$(cat "$preset_path")"

  # Deep merge with jq: `*` recursively merges objects; arrays are replaced.
  CCSL_CONFIG="$(jq -n --argjson p "$preset_cfg" --argjson u "$user_cfg" '$p * $u')"
  export CCSL_CONFIG
}

cfg() {
  printf '%s' "$CCSL_CONFIG" | jq -r "$1"
}

cfg_raw() {
  printf '%s' "$CCSL_CONFIG" | jq -c "$1"
}
