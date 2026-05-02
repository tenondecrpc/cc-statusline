# claude-statusline

Configurable, multi-line statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).
Bash + `jq`. No runtime to install. No TUI to learn. One-command install with safe backups.

Default after first install:

```
Opus 4.7 xhigh | ctx █████░░░░░ 58% | 5h ███████░░░ 76% 22:00 | 7d ██░░░░░░░░ 29% May 06 02:00
```

Model + version + effort, context bar with %, and rate-limit bars with reset times — all colored by threshold.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/claude-statusline/main/install.sh | bash
```

The installer:

- detects `jq` (and tells you how to install it if missing),
- drops files in `~/.local/share/claude-statusline/`,
- creates `~/.config/claude-statusline/config.json` (only if it doesn't exist),
- **detects an existing statusline** and asks before replacing — see [What happens if I already have a statusline?](#what-happens-if-i-already-have-a-statusline),
- **backs up** `~/.claude/settings.json` and the previous script before any change.

After install, the `statusLine` field in your `~/.claude/settings.json` points to our script. Your next interaction with Claude Code shows the new line.

## Customize

Edit `~/.config/claude-statusline/config.json`:

```json
{ "preset": "developer" }
```

Available presets:

| Preset | Layout |
|---|---|
| `minimal` | one line: `model · directory · git` |
| `default` | one line: `model+version+effort | ctx-bar | 5h-bar+reset | 7d-bar+reset` |
| `developer` | two lines: identity row + metrics row with bars, cost, timer |

Override any module while keeping a preset:

```json
{
  "preset": "developer",
  "modules": {
    "directory": { "truncate": 50 },
    "context_bar": { "width": 30, "thresholds_pct": [40, 75] },
    "cost": { "format": "USD %.3f", "hide_below": 0.10 }
  },
  "colors": { "model": "#7aa2f7" }
}
```

Or define your own layout:

```json
{
  "lines": [
    ["model", "directory", "git", "worktree"],
    ["context_bar", "cost", "rate_limit", "vim_mode"]
  ],
  "separator": " · "
}
```

Each `lines` entry becomes a row. Modules return empty when their data is absent (e.g. `rate_limit` outside Pro/Max, `worktree` outside a worktree session) so they don't leave dangling separators.

## Modules

| Name | Shows |
|---|---|
| `model` | display name; with `with_version`/`with_effort` becomes `Opus 4.7 xhigh` |
| `effort` | reasoning effort level alone (`low`/`medium`/`high`/`xhigh`/`max`) |
| `directory` | current dir (tilde-collapsed, truncated) |
| `git` | branch + status counts (`+staged !unstaged ?untracked`) + ahead/behind |
| `context_bar` | `ctx █░ NN%`, threshold-colored |
| `context_pct` | percentage only, threshold-colored |
| `rate_5h` | `5h █░ NN%` + reset time (`HH:MM` today / `Mon DD HH:MM` other day) |
| `rate_7d` | `7d █░ NN%` + reset time |
| `cost` | session cost (`$0.42`); hides under `hide_below` |
| `session_timer` | wall-clock duration (`1h23m` / `45m` / `12s`) |
| `lines_changed` | `+added -removed` |
| `vim_mode` | current vim mode when enabled |
| `worktree` | active worktree name when in one |
| `agent` | agent name when running with `--agent` |

## What happens if I already have a statusline?

The installer classifies the current state and acts accordingly:

| Detected | Action |
|---|---|
| no `statusLine` set | install cleanly |
| **our** statusline (re-run / upgrade) | idempotent, no prompt |
| `ccstatusline`, `felipeelias/claude-statusline`, `nilbuild/claude-statusline` | prompt: **Replace / Keep / Cancel** |
| custom user script or inline command | prompt with preview of the current command |
| project-level `./.claude/settings.json` overrides user settings | warn, leave it alone |

In every replace path, the installer creates timestamped backups:

- `~/.claude/settings.json.bak.<timestamp>`
- the previous script (e.g. `~/.claude/statusline.sh.bak.<timestamp>`) if the command pointed to a local file
- the previous inline command saved as `~/.claude/statusline.previous.<timestamp>.txt` if it was inline

`uninstall.sh` restores the latest backup → you go back to whatever you had before.

### Non-interactive flags

| Flag | Effect |
|---|---|
| `--force` | replace any existing statusLine without asking (still backs up) |
| `--keep-existing` | install files, but don't touch `settings.json` if a statusLine is set |
| `--abort-if-exists` | exit non-zero if any statusLine is set (CI-friendly, no changes) |
| `--dry-run` | print the intended actions; write nothing |
| `--non-interactive` | fail closed when a prompt would be needed |

## Uninstall

```bash
~/.local/share/claude-statusline/uninstall.sh
```

Restores the latest backup of `~/.claude/settings.json` (so the previous statusline, ours or anyone else's, comes back), removes the install dir, and keeps your config (use `--purge` to wipe it).

## Requirements

- Bash 3.2+
- `jq` 1.6+
- `git` (for the `git` module; other modules work without it)

## Local development

```bash
# run smoke tests
bash tests/test.sh

# render once with a fixture
NO_COLOR=1 ./statusline.sh < tests/fixtures/with_rate_limits.json

# install from this checkout (sandboxed)
CSL_INSTALL_DIR=/tmp/csl-install \
CSL_CONFIG_DIR=/tmp/csl-config \
CSL_SETTINGS_FILE=/tmp/csl-settings.json \
  ./install.sh --force
```

## License

MIT
