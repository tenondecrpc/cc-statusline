# cc-statusline

A clean statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

It shows your current model, context usage, and rate-limit windows directly in the Claude Code statusline.

![Default cc-statusline output](./screenshot.png)

```text
Opus xhigh │ ctx        ⣿⣿⣿⣿⣿ 58% │ 5h          ⣿⣿ 76% 22:00 │ 7d    ⣿⣿⣿⣿⣿⣿⣿⣿ 29% May 06 02:00
```

## Install

### npm

```bash
npm install -g cc-statusline-cli
```

### Homebrew

Homebrew install is for macOS only.

```bash
brew tap tenondecrpc/tap
brew install cc-statusline-cli
```

After installation, restart Claude Code or open a new session. The statusline will appear automatically.

If you already have a custom statusline, the installer asks before replacing it and creates a backup first.
With npm, an existing custom statusline is kept during install. Replace it explicitly with `cc-statusline install --force`.

## Requirements

- Bash 3.2+
- `jq` 1.6+
- `git` for repository status

## Help

```bash
cc-statusline help
cc-statusline version
cc-statusline install --force
```

Update or remove the package with the same tool you used to install it:

```bash
npm update -g cc-statusline-cli
npm uninstall -g cc-statusline-cli
```

```bash
brew upgrade cc-statusline-cli
brew uninstall cc-statusline-cli
```

## License

MIT
