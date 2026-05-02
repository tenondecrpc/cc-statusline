# PLAN - claude-statusline

A Claude Code statusline that any developer can install with **one command**,
use with **no configuration**, and customize by **editing a file**.

---

## 1. Goal And Differentiation

We are targeting the gap left by the 4 projects analyzed (see the table in
`README.md` / the author's message):

- More configurable than `nilbuild/claude-statusline`, which is for "personal use".
- Lighter and simpler than `sirmalloc/ccstatusline` in the render path, with no Node process on every render. The future TUI runs only for configuration.
- Easier to install than `felipeelias/claude-statusline`, with no Go compilation and no mandatory Homebrew.
- Includes defaults and presets, unlike the DIY approach in the official docs.

**Internal slogan:** *"git clone -> one command -> you have a statusline. Edit JSON if you want more."*

---

## 2. Design Principles

1. **Zero-config first.** After installation, it works with useful data without touching anything.
2. **One command to install.** `curl | bash` (or `npx`) and done.
3. **No heavy runtime.** The render script is Bash + `jq`. No Node/Go startup on every update, since the statusline may run every few seconds.
4. **TUI by default, file always editable.** When the TUI exists, it will be the recommended flow for configuring presets, modules, and colors. Even then, it must always create and persist `~/.config/claude-statusline/config.json` as a versionable source of truth that can be copied across machines and edited manually later.
5. **Multiline out of the box.** This is one of Claude Code's most useful features, and half of the competitors do not support it.
6. **Safe and idempotent installation.** Back up `settings.json`, merge with `jq`, and provide an uninstall flow that restores.
7. **Progressive customization:** preset -> module tweaks -> custom modules (shell command).

---

## 3. Technical Stack

| Decision | Choice | Reason |
|---|---|---|
| Script language | **Bash** (POSIX where possible) | No extra runtime, ubiquitous, immediate startup. |
| Input JSON parser | **`jq`** | Only external dependency, already standard among developers. |
| Config format | **JSON** | `jq` is already a dependency, so there are no new parsers. Familiar for developers. |
| Distribution | **`curl \| bash` + Homebrew tap + optional npx wrapper** | Covers macOS, Linux, and Windows (WSL). |
| `settings.json` modification | **`jq` with `--argjson` + atomic write** | Safe merge without overwriting unrelated keys. |
| Color capability detection | `$COLORTERM`, `$TERM`, `$NO_COLOR` | Standard. |

**User dependencies:** `bash`, `jq`. The installer detects them and offers installation guidance (`brew`, `apt`, `dnf`, `pacman`).

### 3.1 Platform Support

| Platform | Status | Notes |
|---|---|---|
| macOS | Currently supported | Main installation path through `curl | bash`; Homebrew tap on the roadmap. |
| Linux | Currently supported | Main installation path through `curl | bash`; `jq` through `apt`, `dnf`, or `pacman`. |
| Windows (WSL) | Planned | Document WSL as the recommended path for Windows users before native support. |
| Native Windows | Planned | Cross-platform `npx` wrapper and PowerShell port in v0.4+. |

---

## 4. Distribution And Installation

### Main Command

```bash
curl -fsSL https://raw.githubusercontent.com/tenondecrpc/claude-statusline/main/install.sh | bash
```

Equivalents:
- `brew install <tap>/claude-statusline` (future)
- `npx @<scope>/claude-statusline install` (lightweight wrapper)

### Installer Flow (`install.sh`)

1. Detect `jq`. If it is missing, offer to install it (`brew`/`apt`/`dnf`) or abort with clear instructions.
2. Create `~/.local/share/claude-statusline/` and copy `statusline.sh` + `lib/`.
3. Create `~/.config/claude-statusline/config.json` **only if it does not exist** (default preset).
4. **Detect any pre-existing statusline** in `~/.claude/settings.json` (see section 4.1).
5. Back up `~/.claude/settings.json` to `~/.claude/settings.json.bak.<timestamp>`.
6. Merge with `jq` only if the user confirms it (or if it was already set by us):
   ```bash
   jq '.statusLine = {
     "type": "command",
     "command": "~/.local/share/claude-statusline/statusline.sh",
     "padding": 1
   }' settings.json > settings.json.tmp && mv settings.json.tmp settings.json
   ```
7. Print a summary: where the config is, how to change the preset, and how to uninstall.

### 4.1 Handling An Existing `statusLine`

Before touching `~/.claude/settings.json`, the installer classifies the current state and behaves differently for each case:

| Case | How it is detected | Default action |
|---|---|---|
| **A. No `statusLine`** | `jq -e '.statusLine' settings.json` fails | Clean installation, no prompts. |
| **B. It is ours** (reinstall / upgrade) | The `command` points to `~/.local/share/claude-statusline/statusline.sh` **or** the script has the marker `# claude-statusline:vX.Y.Z` | Idempotent: update the script, leave `config.json` intact, and do not mutate `settings.json` unless the path changed. No prompts. |
| **C. It belongs to another known project** | Match by path/command: `npx ccstatusline*`, `claude-statusline prompt` (felipeelias), `~/.claude/statusline.sh` with a nilbuild header | Interactive prompt: **Replace / Keep / Cancel**. Show which tool it came from (`"Detected: ccstatusline"`). |
| **D. It is a custom user script** | Any other `command` | More cautious interactive prompt: print the current `command` and the first 3 lines of the script if it is a file. **Replace / Keep / Cancel**, default = `Cancel`. |
| **E. `settings.json` does not exist or is empty** | Missing file | Create a minimal `~/.claude/settings.json` with only `statusLine`. |

**Unified prompt (cases C and D):**

```text
Detected an existing statusLine in ~/.claude/settings.json:
  command: <current command>
  source : <ccstatusline | felipeelias | nilbuild | custom script | inline>

What do you want to do?
  [r] Replace it with claude-statusline (your current setup will be backed up)
  [k] Keep your current statusline and exit  (we'll still drop our script for manual use)
  [c] Cancel (no changes)

> 
```

**Backup in all C/D cases:**

- `~/.claude/settings.json` -> `~/.claude/settings.json.bak.<timestamp>`
- If the `command` points to a local script, such as `~/.claude/statusline.sh`, also copy that file to `~/.claude/statusline.sh.bak.<timestamp>` before any change. If the `command` is inline, save it as `~/.claude/statusline.previous.<timestamp>.txt` so the uninstall flow can show it.

**Identification marker.** Our `statusline.sh` always carries this as its second line:

```bash
#!/usr/bin/env bash
# claude-statusline:vX.Y.Z https://github.com/tenondecrpc/claude-statusline
```

This makes case B detection robust even if the user moved the script to another path.

**Project-level override.** If `<cwd>/.claude/settings.json` exists with a different `statusLine`, **we do not touch it** and we warn: *"Project-level statusLine in `./.claude/settings.json` will override the user-level one. Edit that file if you want claude-statusline to apply here."*

**Non-interactive flags** (for CI / dotfiles):

| Flag | Effect |
|---|---|
| `--force` | Always replace, without prompting. Still creates a backup. |
| `--keep-existing` | If a `statusLine` already exists, install the files but do not touch `settings.json`. Exit with code 0. |
| `--abort-if-exists` | If a `statusLine` already exists (case C or D), exit with a non-zero code without touching anything. |
| `--dry-run` | Print the plan, including what would go into `settings.json` and which backup would be created, without writing. |

Default with no flags: interactive prompt in C/D, idempotent in B, clean in A/E.

### Uninstaller Flow (`uninstall.sh`)

1. If there is a `.bak` for `settings.json`, restore the most recent one, preserving the previous statusline no matter whose it was.
2. Otherwise, remove the `statusLine` key with `jq 'del(.statusLine)'`.
3. If `~/.claude/statusline.sh.bak.<timestamp>` exists, offer to restore it to `~/.claude/statusline.sh`.
4. Delete `~/.local/share/claude-statusline/`, and ask before deleting `~/.config/claude-statusline/config.json`.
5. Flags: `--purge` (delete config without asking), `--keep-backups` (do not delete `.bak` files).

---

## 5. Configuration Model

`~/.config/claude-statusline/config.json`:

```json
{
  "preset": "developer",
  "separator": " | ",
  "lines": [
    ["model", "directory", "git"],
    ["context_bar", "cost", "rate_limit"]
  ],
  "modules": {
    "directory": { "truncate": 30, "tilde": true },
    "git":       { "show_status": true, "show_ahead_behind": true },
    "context_bar": { "width": 20, "thresholds_pct": [50, 80] },
    "cost":      { "format": "$%.2f", "hide_below": 0.01 },
    "rate_limit":{ "show": ["five_hour", "seven_day"] }
  },
  "colors": {
    "model": "cyan",
    "git_clean": "green",
    "git_dirty": "yellow",
    "context_warn": "yellow",
    "context_crit": "red"
  }
}
```

**Rules:**
- If `preset` is set, the following fields override it module by module, in the style of Starship/felipeelias.
- `lines` is an array of arrays. Each subarray is one line. A single line = `[[...]]`.
- If a key does not exist, use the default from the loaded preset.

---

## 6. Modules (MVP)

| Module | Claude Code JSON data | Notes |
|---|---|---|
| `model` | `model.display_name` | Accepts `short` for abbreviation. |
| `directory` | `workspace.current_dir` | Tilde collapse + truncation. |
| `git` | (runs `git`) | Branch + counts (staged/unstaged/untracked) + ahead/behind. |
| `context_bar` | `context_window.used_percentage` | Default N-character bar + %. |
| `context_pct` | same | Percentage only. |
| `cost` | `cost.total_cost_usd` | Optional hide-when-zero behavior. |
| `rate_limit` | `rate_limits.five_hour.*`, `seven_day.*` | Skip when absent (non-Pro). |
| `session_timer` | `cost.total_duration_ms` | Format `1h23m`. |
| `lines_changed` | `cost.total_lines_added/removed` | `+12 -3`. |
| `vim_mode` | `vim.mode` | Only if present. |
| `worktree` | `worktree.name`/`branch` | Only if present. |
| `agent` | `agent.name` | Only if present. |
| `custom` | shell command | Execute and insert stdout (with timeout). |

All modules respect **hide-when-empty** and **timeout** so the statusline does not hang.

---

## 7. Presets (MVP)

| Preset | Layout | Audience |
|---|---|---|
| `minimal` | one line: `model . dir . branch` | users who want the minimum |
| `default` | one line: `model | dir | git | context% | cost` | general use |
| `developer` | two lines: `[model, dir, git]` / `[context_bar, cost, rate_limit]` | serious work |
| `powerline` | one line with Powerline arrows (Nerd Font) | users with a polished terminal |

All presets are stored as JSON in `presets/` and embedded in the script.

---

## 8. Repo Structure

```text
claude-statusline/
├── README.md                  # quickstart + screenshot + preset table
├── PLAN.md                    # this file
├── LICENSE                    # MIT
├── install.sh                 # one-liner installer
├── uninstall.sh               # uninstaller
├── statusline.sh              # entrypoint: reads stdin, dispatcher
├── lib/
│   ├── modules.sh             # implementation of each module
│   ├── git.sh                 # git helpers
│   ├── colors.sh              # ANSI + capability detection
│   ├── render.sh              # line and separator assembly
│   └── config.sh              # config + preset loading and merge
├── presets/
│   ├── minimal.json
│   ├── default.json
│   ├── developer.json
│   └── powerline.json
├── tests/
│   ├── fixtures/              # sample JSON files (with/without worktree, no rate_limits, etc.)
│   ├── snapshots/             # expected output (without ANSI)
│   └── test.bats              # bats-core
├── docs/
│   ├── modules.md
│   ├── customizing.md
│   └── troubleshooting.md
└── .github/workflows/
    └── ci.yml                 # macOS + Ubuntu, multiple jq versions
```

---

## 9. Testing

- **Fixtures**: 1 JSON file per scenario (`min.json`, `with_worktree.json`, `no_rate_limits.json`, `vim.json`, `cost_high.json`, etc.).
- **Snapshots**: run `statusline.sh < fixture.json | strip-ansi > out.txt` and compare with `expected.txt`.
- **`bats`** for unit tests of `lib/` functions.
- **CI** on macOS and Ubuntu with `jq` 1.6 and 1.7.
- Installer test: copy a fake `settings.json`, run `install.sh`, and verify the merge with `jq`.

---

## 10. Roadmap

### v0.1 - MVP
- [ ] `statusline.sh` + modules: `model`, `directory`, `git`, `context_bar`, `cost`, `rate_limit`.
- [ ] Multiline support.
- [ ] Presets `minimal`, `default`, `developer`.
- [ ] `install.sh` with backup and `jq` merge.
- [ ] `uninstall.sh` with restore.
- [ ] README with screenshot + preset table.
- [ ] CI with snapshot tests.

### v0.2 - UX And Polish
- [ ] `powerline` preset with Nerd Font detection + fallback.
- [ ] OSC 8 (clickable branches and dirs).
- [ ] Modules `worktree`, `vim_mode`, `session_timer`, `lines_changed`.
- [ ] Subcommands: `claude-statusline test` (mock data) and `claude-statusline themes`.
- [ ] Homebrew tap.

### v0.3 - Extensibility
- [ ] `custom` module with timeout and caching.
- [ ] Plugin folder: `~/.config/claude-statusline/modules/<name>.sh`.
- [ ] Smart truncation when the terminal is narrow.

### v0.4+
- [ ] Wrapper `npx @<scope>/claude-statusline` for Windows/cross-platform.
- [ ] PowerShell port for native Windows.
- [ ] Theme builder: command that generates an interactive preset.
- [ ] `ccstatusline`-style TUI as the default configuration flow for presets, modules, colors, and preview. The UX decision for non-technical users is **editing a file < clicking menus**, but the TUI must create and save everything in `config.json` to allow later manual editing.

---

## 11. Non-Goals (What We **Will Not** Do)

- TUI in the render path, resident daemon, or opaque configuration that cannot be edited manually. The TUI can be the default flow, but it must run outside rendering and persist everything in `config.json`.
- Reimplement token tracking. We use what Claude Code sends through stdin.
- Support features that require starting a daemon or server.
- Telemetry / analytics of any kind.
- Official pre-1.0 support for terminals without ANSI (Windows cmd.exe without ANSI).

---

## 12. Risks And Mitigations

| Risk | Mitigation |
|---|---|
| `jq` is not installed | Detection + OS-specific instructions in the installer. |
| `settings.json` already has a different `statusLine` | Timestamped backup before touching it. |
| Slow render from `git status` in large repos | Per-process cache + lightweight flags (`git status --porcelain=v1 -uno` by default). |
| Claude Code JSON changes | Tests with fixed fixtures + missing-field handling with `// empty`. |
| Developers on Windows | Document WSL as the main path; PowerShell port on the roadmap. |

---

## 13. Success Metrics

- Install from scratch to visible statusline in **< 30 seconds**.
- Switch to another preset in **< 10 seconds** by editing one field.
- Statusline render time **< 50 ms** in typical repos.
- A new developer can read the README top to bottom in **< 3 minutes** and know how to customize.
