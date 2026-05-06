# cc-statusline

A clean statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

It shows your current model, context usage, and rate-limit windows directly in the Claude Code statusline.

![Default cc-statusline output](./screenshot.png)

```text
Opus xhigh │ ctx        ⣿⣿⣿⣿⣿ 58% │ 5h          ⣿⣿ 76% 22:00 │ 7d    ⣿⣿⣿⣿⣿⣿⣿⣿ 29% May 06 02:00
```

## Install

### npm

Works on macOS, Linux, and Windows.

```bash
npm install -g cc-statusline-cli
cc-statusline install
```

The npm package uses the Node.js runtime and does not require Bash or `jq`. It does not run a `postinstall` script, which keeps npm lifecycle scripts disabled-friendly and avoids writing Claude Code settings during package installation. Run `cc-statusline install` after `npm install` to register the statusline in Claude Code.

On Windows, run the same commands from PowerShell or CMD. The installer writes to `%USERPROFILE%\.claude\settings.json`.

### Homebrew

Homebrew install is for macOS only. The formula auto-configures `~/.claude/settings.json`
during install; no extra step is needed.

```bash
brew tap tenondecrpc/tap
brew install cc-statusline-cli
```

After registration, restart Claude Code or open a new session. The statusline will appear automatically.

If you already have a custom statusline, the installer asks before replacing it and creates a backup first.
With npm, an existing custom statusline is kept during install. Replace it explicitly with `cc-statusline install --force`.

## Requirements

- npm install: Node.js 18+. Bash and `jq` are not required.
- Homebrew install: Bash 3.2+ and `jq` 1.6+
- `git` for repository status

`jq` is only needed by the Homebrew/Bash runtime. It is not included with macOS by default, but Homebrew installs it automatically as a dependency. The npm install does not need `jq`.

## Help

```bash
cc-statusline help
cc-statusline version
cc-statusline install --force
```

## Uninstall

Run `cc-statusline uninstall` to restore your previous `settings.json` backup and remove the npm package in one step:

```bash
cc-statusline uninstall
```

If you only want to clean the `statusLine` entry without removing the package:

```bash
cc-statusline uninstall --keep-package
```

Add `--purge` to also remove the user config directory (`~/.config/cc-statusline`):

```bash
cc-statusline uninstall --purge
```

For Homebrew, uninstall with `brew` and restore your previous `settings.json` from the backup the installer created:

```bash
brew uninstall cc-statusline-cli
# manually restore from ~/.claude/settings.json.bak.* if needed
```

## License

MIT
