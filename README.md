# claude-statusline

Configurable, multi-line statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).
Bash + `jq`. No runtime to install. No TUI to learn. One-command install with safe backups.

Default after first install:

![Default claude-statusline output](./screenshot.png)

```
Opus xhigh │ ctx        ⣿⣿⣿⣿⣿ 58% │ 5h          ⣿⣿ 76% 22:00 │ 7d    ⣿⣿⣿⣿⣿⣿⣿⣿ 29% May 06 02:00
```

Model + effort, context bar with %, and rate-limit bars with reset times. The basic install matches `statusline-command.sh`: 12-cell bars, `│` separators, yellow model text, dim effort/reset text, and green/yellow/red thresholds.

## Platform support

Current support: macOS and Linux.

Windows support is on the roadmap. For now, use WSL on Windows.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tenondecrpc/claude-statusline/main/install.sh | bash
```

The installer:

- detects `jq` (and tells you how to install it if missing),
- drops files in `~/.local/share/claude-statusline/`,
- creates `~/.config/claude-statusline/config.json` (only if it doesn't exist),
- **detects an existing statusline** and asks before replacing — see [What happens if I already have a statusline?](#what-happens-if-i-already-have-a-statusline),
- **backs up** `~/.claude/settings.json` and the previous script before any change.

After install, the `statusLine` field in your `~/.claude/settings.json` points to our script. Your next interaction with Claude Code shows the new line.

### Install via Homebrew

```bash
brew tap tenondecrpc/tap
brew install claude-statusline
```

`brew install` wires up `~/.claude/settings.json` automatically. If a custom `statusLine` is already configured, it is kept; replace it later with:

```bash
claude-statusline configure --force
```

Update and uninstall via Homebrew:

```bash
brew upgrade claude-statusline
brew uninstall claude-statusline
```

Before `brew uninstall`, restore your previous statusLine from `~/.claude/settings.json.bak.*` (or delete the `statusLine` entry manually), otherwise Claude Code will reference a missing script.

## Customize

Edit `~/.config/claude-statusline/config.json`:

```json
{ "preset": "developer" }
```

Available presets:

| Preset | Layout |
|---|---|
| `minimal` | one line: `model · directory · git` |
| `default` | one line matching the basic `statusline-command.sh` format |
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

Each `lines` entry becomes a row. Most modules return empty when their data is absent (e.g. `rate_limit` outside Pro/Max, `worktree` outside a worktree session) so they don't leave dangling separators. The default `basic_statusline` module intentionally shows empty 5h/7d bars when rate-limit data is absent, matching the basic install script.

## Modules

| Name | Shows |
|---|---|
| `basic_statusline` | one-piece default line matching `statusline-command.sh`: model, effort, ctx, 5h, 7d |
| `model` | display name; with `with_version`/`with_effort` becomes `Opus 4.7 xhigh` |
| `effort` | reasoning effort level alone (`low`/`medium`/`high`/`xhigh`/`max`) |
| `directory` | current dir (tilde-collapsed, truncated) |
| `git` | branch + status counts (`+staged !unstaged ?untracked`) + ahead/behind |
| `context_bar` | `ctx` + the default 12-cell progress bar + percentage |
| `context_pct` | percentage only, threshold-colored |
| `rate_5h` | `5h` + the default 12-cell progress bar + percentage + reset time (`HH:MM` today / `Mon DD HH:MM` other day) |
| `rate_7d` | `7d` + the default 12-cell progress bar + percentage + reset time |
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

If you run the installer in a normal terminal and it finds another statusline, it asks:

```text
Detected an existing statusLine in ~/.claude/settings.json:
  command: bash /Users/you/.claude/statusline-command.sh
  source : custom

What do you want to do?
  [r] Replace it with claude-statusline (your current setup will be backed up)
  [k] Keep your current statusline (script still installed for manual use)
  [c] Cancel (no changes)
```

In every replace path, the installer creates timestamped backups:

- `~/.claude/settings.json.bak.<timestamp>`
- the previous script (e.g. `~/.claude/statusline.sh.bak.<timestamp>`) if the command pointed to a local file
- the previous inline command saved as `~/.claude/statusline.previous.<timestamp>.txt` if it was inline

`uninstall.sh` restores the latest backup → you go back to whatever you had before.

### When should I use `--force`?

Use `--force` only when you already want `~/.claude/settings.json` to point to `claude-statusline`, replacing whatever `statusLine` is currently there. It still creates backups first.

Typical cases:

- you saw `Existing statusLine state: custom` and want to replace that custom command,
- you are upgrading/reinstalling from a script, CI job, IDE task, or any place where the installer cannot prompt,
- you are migrating from another statusline package and do not need to review the prompt.

Do not use `--force` if you only want to install the files for manual testing. Use `--keep-existing` instead.

With the one-line installer, pass flags after `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/tenondecrpc/claude-statusline/main/install.sh | bash -s -- --force
```

To install the files but keep your current `statusLine`:

```bash
curl -fsSL https://raw.githubusercontent.com/tenondecrpc/claude-statusline/main/install.sh | bash -s -- --keep-existing
```

### Non-interactive flags

| Flag | Effect |
|---|---|
| `--force` | replace any existing statusLine without asking (still backs up) |
| `--keep-existing` | install files, but don't touch `settings.json` if a statusLine is set |
| `--abort-if-exists` | exit non-zero if any statusLine is set (CI-friendly, no changes) |
| `--dry-run` | print the intended actions; write nothing |
| `--non-interactive` | fail closed when a prompt would be needed |

## Update

```bash
claude-statusline update
```

Downloads the latest `install.sh` from the repository and re-runs it with `--force`. Your config file (`~/.config/claude-statusline/config.json`) is never overwritten during an update.

```bash
claude-statusline version   # show installed version
```

## Uninstall

```bash
claude-statusline uninstall
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
