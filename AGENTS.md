# AGENTS.md

Guidelines for coding agents operating in this repository.

## Instruction Source

`AGENTS.md` is the authoritative repository instruction file for this project.

`CLAUDE.md` is a thin bootstrap that defers to `AGENTS.md` and must not duplicate repository rules.

Keep product usage docs in `README.md`. Keep this file focused on how agents should work in the repository.

## Project

This repository contains `cc-statusline`, a configurable statusline command for Claude Code.

The current stack is:

- Bash 3.2+ for runtime and installer scripts.
- `jq` 1.6+ for JSON parsing and config merging.
- JSON presets under `presets/`.
- Shell smoke tests under `tests/`.
- macOS and Linux support. Windows support is through WSL unless native support is added later.

Current repository shape:

- `statusline.sh`: Claude Code statusline entrypoint. Reads session JSON from stdin and prints one or more statusline rows.
- `lib/colors.sh`: ANSI color capability detection and color helpers.
- `lib/config.sh`: user config and preset loading.
- `lib/git.sh`: bounded git helpers used by statusline modules.
- `lib/modules.sh`: statusline module implementations.
- `lib/render.sh`: layout renderer that dispatches configured modules.
- `presets/*.json`: built-in layouts and default module settings.
- `install.sh`: installer that copies files, writes user config, updates Claude settings, and creates backups.
- `uninstall.sh`: uninstaller and backup restore flow.
- `tests/test.sh`: fixture-based smoke and regression tests.
- `tests/fixtures/*.json`: representative Claude Code session payloads.

## Language And Writing

All repository artifacts should be written in English unless the user explicitly asks otherwise.

Use ASCII punctuation by default. Do not use em dashes or en dashes in prose, comments, commit messages, plans, or documentation. Use the ASCII hyphen instead.

Unicode glyphs are allowed when they are part of the product output, screenshots, fixture expectations, or README examples for the statusline itself.

Use clear product terms: `statusline`, `module`, `preset`, `fixture`, `config`, `installer`, `uninstaller`, `settings`, `backup`, `workspace`, `context`, and `rate limit`.

## Documentation Lookup

Use Context7 MCP whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service. This includes Bash-adjacent tooling when current syntax or behavior matters, such as `jq`, `git`, shellcheck, packaging tools, or Claude Code configuration if available through documentation sources.

Workflow:

1. Resolve the library ID first unless the user provides an exact `/org/project` Context7 ID.
2. Query the selected documentation with the user's actual question.
3. Base the answer or implementation on the fetched documentation.

Do not use Context7 for ordinary refactors, project-specific shell debugging, code review, or business logic that can be answered from the local code.

## Core Design

Keep the runtime simple and predictable:

- `statusline.sh` reads exactly one JSON payload from stdin.
- Runtime code should render quickly and avoid network calls.
- Modules should return empty output when data is absent so separators do not dangle.
- Configuration should come from JSON presets plus user overrides.
- Presets should remain small, readable, and safe to merge with `jq`.
- The installer must be idempotent and must protect existing user configuration.

The statusline is a command-line rendering tool, not a TUI, daemon, service, or package manager. Do not add long-running processes or hidden background behavior.

## Shell Coding Rules

Prefer portable Bash that works with Bash 3.2 on macOS.

- Use `#!/usr/bin/env bash` for executable shell scripts.
- Keep `set -uo pipefail` unless a specific script needs a documented exception.
- Quote variable expansions unless word splitting is intentional.
- Prefer functions with narrow responsibilities over large inline blocks.
- Keep global variables namespaced with `CCSL_` when they are shared across files.
- Avoid Bash features unavailable in Bash 3.2.
- Avoid GNU-only command flags unless a macOS-compatible fallback exists.
- When formatting dates, keep both BSD/macOS `date -r` and GNU/Linux `date -d` behavior in mind.
- Do not use Python, Node, or another runtime for product code unless the project deliberately changes scope.

For JSON, use `jq` instead of ad hoc string parsing.

For git status, keep commands bounded and quiet. Git integration must not fail the whole statusline when the current directory is not a repository or git is unavailable.

## Module Rules

Modules live in `lib/modules.sh` as `mod_<name>` functions.

Module expectations:

- Read from `INPUT_JSON`.
- Read configuration through `cfg` or `cfg_raw`.
- Print only the rendered module text to stdout.
- Return success with empty output when the module should be hidden.
- Never print diagnostics to stdout.
- Handle missing, null, or partial Claude Code fields gracefully.
- Keep expensive or external operations out of modules unless they are bounded and optional.

When adding a module:

1. Add `mod_<name>` in `lib/modules.sh`.
2. Add default config only where needed in the relevant preset.
3. Document the module in `README.md`.
4. Add or update a fixture if the module depends on new payload fields.
5. Run `bash tests/test.sh`.

## Preset And Config Rules

Built-in presets are JSON files in `presets/`.

- Keep preset JSON valid and human-readable.
- Preserve the merge model in `lib/config.sh`: preset config is deep-merged with user config, and arrays are replaced.
- Keep module names in `lines` aligned with `mod_<name>` functions.
- Do not require every user config to specify every module option.
- Prefer backwards-compatible defaults when changing preset structure.
- Avoid changing the default preset output casually, because it is the first-run experience and is shown in the README.

## Installer Rules

The installer modifies user files, so treat it as high risk.

Installer changes must preserve:

- Detection of `jq` with useful install guidance.
- Local checkout install and remote tarball install flows.
- Safe backups before replacing Claude settings or previous scripts.
- Idempotent re-runs when this statusline is already configured.
- Respect for `--force`, `--keep-existing`, `--abort-if-exists`, `--dry-run`, and `--non-interactive`.
- Clear behavior when another statusline or custom command already exists.
- Support for `CCSL_INSTALL_DIR`, `CCSL_CONFIG_DIR`, `CCSL_SETTINGS_FILE`, and `CCSL_REPO_URL`.

Do not write to real user config paths during tests or local verification unless the user explicitly asks. Use temporary directories and the `CCSL_*` environment variables.

## Security And Privacy

The statusline receives Claude Code session JSON. Treat it as potentially sensitive.

- Do not log raw input payloads by default.
- Do not send payloads over the network.
- Do not add telemetry, analytics, or update checks without explicit user request and documentation.
- Do not persist session JSON outside tests.
- Avoid printing secrets, tokens, full prompts, or credentials if future Claude Code payloads expose them.
- Installer backups should copy only the existing settings or referenced statusline command needed for restore.

## Development Workflow

For new work:

1. Read `README.md`, `statusline.sh`, and the relevant files under `lib/`.
2. Identify whether the change affects rendering, config, presets, installer behavior, uninstall behavior, docs, or tests.
3. Keep changes scoped to the relevant surface.
4. Update fixtures and smoke tests when behavior changes.
5. Update `README.md` when commands, configuration, presets, modules, install behavior, or platform support changes.
6. Avoid broad rewrites unless the user explicitly asks for a refactor.

Use existing project scripts directly. There is no package install step for normal development.

## Verification

Minimum checks:

- Documentation-only changes: validate headings, terminology, ASCII punctuation, and consistency with current files.
- Runtime or module changes: run `bash tests/test.sh`.
- Preset changes: run `bash tests/test.sh` and render at least one fixture with `NO_COLOR=1 ./statusline.sh < tests/fixtures/with_rate_limits.json`.
- Installer changes: test with temporary paths using `CCSL_INSTALL_DIR`, `CCSL_CONFIG_DIR`, and `CCSL_SETTINGS_FILE`.
- Uninstaller changes: test against a temporary install and settings file.

Useful local checks:

```bash
bash tests/test.sh
NO_COLOR=1 ./statusline.sh < tests/fixtures/with_rate_limits.json
CCSL_INSTALL_DIR=/tmp/ccsl-install \
CCSL_CONFIG_DIR=/tmp/ccsl-config \
CCSL_SETTINGS_FILE=/tmp/ccsl-settings.json \
  ./install.sh --force
```

Use real `~/.claude/settings.json` only when the task specifically requires it.

## Pull Request Checklist

Every PR should answer:

- What changed?
- Which statusline module, preset, installer path, or documentation area does it affect?
- What tests or smoke checks ran?
- What user configuration or migration impact exists?
- How does the change behave on macOS and Linux?
- How are existing statuslines, backups, and uninstall paths preserved if installer behavior changed?
- Are privacy and local-only behavior preserved?

## Cutting a Release

Two repositories are involved on every release:

- `tenondecrpc/cc-statusline` (this repo): source, `package.json`, GitHub release, tarball.
- `tenondecrpc/homebrew-tap`: the `Formula/cc-statusline.rb` brew users consume.

The Homebrew formula does not live in this repo. Keeping a copy here causes the two checkouts to drift on every release, so the tap is the single source of truth for the formula.

### New source release (typical case)

1. Confirm `bash tests/test.sh` passes.
2. Bump `package.json` version (no leading `v`, e.g. `0.1.2`).
3. Commit on `main` and tag the commit:
   ```bash
   git commit -am "feat: ..."
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```
   Always tag the commit that bumps `package.json`, never an earlier commit. `cc-statusline version` reads the installed `package.json`.
4. Create the GitHub release:
   ```bash
   gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."
   ```
5. Compute the tarball SHA256:
   ```bash
   curl -fsSL "https://github.com/tenondecrpc/cc-statusline/archive/refs/tags/vX.Y.Z.tar.gz" \
     | shasum -a 256
   ```
6. In a checkout of `tenondecrpc/homebrew-tap`, edit `Formula/cc-statusline.rb`:
   - update `url` to the new tag tarball,
   - update `sha256` to the new hash,
   - remove any `revision N` line if present (a new source version resets it).
7. Validate, commit, push the tap:
   ```bash
   brew style Formula/cc-statusline.rb
   git add Formula/cc-statusline.rb
   git commit -m "chore: bump cc-statusline to vX.Y.Z"
   git push origin main
   ```
8. Verify end to end:
   ```bash
   brew update
   brew upgrade cc-statusline
   cc-statusline version
   ```

### Formula-only fix (no source change)

When only the formula needs to change (wrong `opt_libexec` usage, missing dependency, caveats text), do not cut a new source release. In the tap:

1. Add or increment `revision N` after `license` in `Formula/cc-statusline.rb`.
2. Apply the formula fix.
3. `brew style`, commit, push.

`brew upgrade cc-statusline` picks up the new revision for existing installs.

### Path stability

The wrapper and `post_install` must use `opt_libexec`, not `libexec`. `libexec` resolves to a version-pinned `Cellar/cc-statusline/X.Y.Z[_R]` directory that disappears on the next install, breaking `~/.claude/settings.json`. `opt_libexec` is the symlink Homebrew updates atomically.

## References

- Repository bootstrap: `CLAUDE.md`
- Product documentation: `README.md`
- Runtime entrypoint: `statusline.sh`
- Installer: `install.sh`
- Uninstaller: `uninstall.sh`
- Smoke tests: `tests/test.sh`
