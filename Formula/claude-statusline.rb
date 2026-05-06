class ClaudeStatusline < Formula
  desc "Configurable statusline command for Claude Code"
  homepage "https://github.com/tenondecrpc/claude-statusline"
  url "https://github.com/tenondecrpc/claude-statusline/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "fbda7ea16ad79dcf02459babf84fbec316482eb32f82ae14b92635cb54e062f4"
  license "MIT"

  depends_on "jq"

  def install
    libexec.install "statusline.sh", "install.sh", "uninstall.sh", "VERSION", "lib", "presets"

    (bin/"claude-statusline").write <<~SCRIPT
      #!/usr/bin/env bash
      set -uo pipefail

      LIBEXEC="#{libexec}"

      cmd="${1:-help}"
      shift 2>/dev/null || true

      case "$cmd" in
        version)
          if [ -f "$LIBEXEC/VERSION" ]; then
            cat "$LIBEXEC/VERSION"
          else
            printf 'unknown\\n'
          fi
          ;;
        configure)
          CSL_INSTALL_DIR="$LIBEXEC" CSL_SKIP_WRAPPER=1 bash "$LIBEXEC/install.sh" "$@"
          ;;
        update)
          printf 'Use Homebrew to update:\\n  brew update && brew upgrade claude-statusline\\n' >&2
          exit 1
          ;;
        uninstall)
          printf 'Use Homebrew to uninstall:\\n  brew uninstall claude-statusline\\n' >&2
          printf 'Restore the previous statusLine from ~/.claude/settings.json.bak.* or remove the entry manually before uninstalling.\\n' >&2
          exit 1
          ;;
        help|--help|-h|"")
          cat <<'HELP'
      Usage: claude-statusline <command> [args]

      Commands:
        configure   wire up ~/.claude/settings.json (forwards args to install.sh)
        version     show the installed version
        update      points you at 'brew upgrade claude-statusline'
        uninstall   points you at 'brew uninstall claude-statusline'
        help        show this help

      Examples:
        claude-statusline configure --force
        claude-statusline configure --keep-existing
      HELP
          ;;
        *)
          printf 'Unknown command: %s\\n' "$cmd" >&2
          printf "Run 'claude-statusline help' for usage.\\n" >&2
          exit 1
          ;;
      esac
    SCRIPT
    chmod 0755, bin/"claude-statusline"
  end

  def post_install
    # Wire up ~/.claude/settings.json automatically. Use --keep-existing so a user's
    # custom statusLine is preserved; they can replace it with `claude-statusline
    # configure --force`. CSL_SKIP_WRAPPER=1 prevents install.sh from creating its own
    # ~/.local/bin/claude-statusline shim, since brew already owns bin/claude-statusline.
    with_env CSL_INSTALL_DIR: libexec.to_s, CSL_SKIP_WRAPPER: "1" do
      system "bash", libexec/"install.sh", "--keep-existing", "--non-interactive"
    end
  end

  def caveats
    <<~EOS
      claude-statusline has been wired up automatically. ~/.claude/settings.json
      now points at:
        #{libexec}/statusline.sh

      If you already had a custom statusLine, it was kept. Replace it with:
        claude-statusline configure --force

      Edit your preset:
        ~/.config/claude-statusline/config.json

      Before `brew uninstall`, restore your previous statusLine from
      ~/.claude/settings.json.bak.* or delete the statusLine entry manually,
      otherwise Claude Code will reference a missing script.
    EOS
  end

  test do
    payload = {
      model:          { display_name: "Sonnet" },
      workspace:      { current_dir: "." },
      context_window: { used_percentage: 42 },
      cost:           {
        total_cost_usd:      0.12,
        total_duration_ms:   60_000,
        total_lines_added:   0,
        total_lines_removed: 0,
      },
    }.to_json
    output = pipe_output("#{libexec}/statusline.sh", payload, 0)
    assert_match "Sonnet", output
  end
end
