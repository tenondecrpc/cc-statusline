#!/usr/bin/env node
"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const packageDir = path.resolve(__dirname, "..");
const packageJsonPath = path.join(packageDir, "package.json");

function readPackageJson() {
  return JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
}

function usage() {
  console.log(`Usage: cc-statusline <command> [options]

Commands:
  render      read Claude Code session JSON from stdin and render the statusline
  install     configure Claude Code to use cc-statusline
  configure   alias for install
  uninstall   restore settings.json backup and uninstall the npm package
  version     show the packaged version
  help        show this help

Install options:
  --force             replace any existing statusLine
  --keep-existing     install files but don't touch existing statusLine
  --abort-if-exists   exit non-zero if statusLine already exists
  --dry-run           print what would happen without writing

Uninstall options:
  --purge             also remove user config directory
  --keep-package      don't run npm uninstall -g

With no command and piped stdin, cc-statusline renders the statusline.`);
}

function timestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return [
    d.getFullYear(),
    pad(d.getMonth() + 1),
    pad(d.getDate()),
    "-",
    pad(d.getHours()),
    pad(d.getMinutes()),
    pad(d.getSeconds()),
  ].join("");
}

function userConfigDir() {
  if (process.env.CCSL_CONFIG_DIR) return process.env.CCSL_CONFIG_DIR;
  if (process.platform === "win32") {
    return path.join(process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming"), "cc-statusline");
  }
  return path.join(process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config"), "cc-statusline");
}

function settingsPath() {
  return process.env.CCSL_SETTINGS_FILE || path.join(os.homedir(), ".claude", "settings.json");
}

function readJsonFile(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return fallback;
  }
}

function writeJsonFile(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function deepMerge(base, override) {
  if (!override || typeof override !== "object" || Array.isArray(override)) return override;
  const out = { ...(base && typeof base === "object" && !Array.isArray(base) ? base : {}) };
  for (const [key, value] of Object.entries(override)) {
    if (value && typeof value === "object" && !Array.isArray(value)) {
      out[key] = deepMerge(out[key], value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

function loadConfig() {
  const configDir = userConfigDir();
  const userConfigPath = path.join(configDir, "config.json");
  const userConfig = readJsonFile(userConfigPath, {});
  const presetName = typeof userConfig.preset === "string" ? userConfig.preset : "default";
  let presetPath = path.join(packageDir, "presets", `${presetName}.json`);
  if (!fs.existsSync(presetPath)) presetPath = path.join(packageDir, "presets", "default.json");
  const preset = readJsonFile(presetPath, {});
  return deepMerge(preset, userConfig);
}

function ensureUserConfig() {
  const configDir = userConfigDir();
  const file = path.join(configDir, "config.json");
  fs.mkdirSync(configDir, { recursive: true });
  if (!fs.existsSync(file)) writeJsonFile(file, { preset: "default" });
  return file;
}

function get(obj, dotted, fallback = undefined) {
  let cur = obj;
  for (const part of dotted.split(".")) {
    if (cur == null || typeof cur !== "object" || !(part in cur)) return fallback;
    cur = cur[part];
  }
  return cur == null ? fallback : cur;
}

function colorLevel() {
  if (process.env.NO_COLOR) return 0;
  if (process.env.COLORTERM === "truecolor" || process.env.COLORTERM === "24bit") return 3;
  const term = process.env.TERM || "";
  if (term.includes("256color") || term.includes("truecolor") || term === "alacritty" || term === "xterm-kitty") return 2;
  if (/^(xterm|screen|tmux|linux|rxvt)/.test(term)) return 1;
  if (!term || term === "dumb") return 0;
  return process.platform === "win32" ? 1 : 1;
}

const colors = {
  black: 30,
  red: 31,
  green: 32,
  yellow: 33,
  blue: 34,
  magenta: 35,
  cyan: 36,
  white: 37,
  gray: 90,
  grey: 90,
  bright_red: 91,
  bright_green: 92,
  bright_yellow: 93,
  bright_blue: 94,
  bright_magenta: 95,
  bright_cyan: 96,
  bright_white: 97,
};

function wrap(config, color, text) {
  if (!text) return "";
  if (!color || colorLevel() === 0) return text;
  if (colors[color]) return `\x1b[${colors[color]}m${text}\x1b[0m`;
  const hex = /^#([0-9a-fA-F]{6})$/.exec(color);
  if (hex && colorLevel() >= 3) {
    const r = parseInt(hex[1].slice(0, 2), 16);
    const g = parseInt(hex[1].slice(2, 4), 16);
    const b = parseInt(hex[1].slice(4, 6), 16);
    return `\x1b[38;2;${r};${g};${b}m${text}\x1b[0m`;
  }
  return text;
}

function bgColorFor(pct) {
  if (pct >= 80) return "\x1b[48;5;196m";
  if (pct >= 60) return "\x1b[48;5;220m";
  return "\x1b[48;5;154m";
}

function fgColorFor(pct) {
  if (pct >= 80) return "\x1b[38;5;196m";
  if (pct >= 60) return "\x1b[38;5;220m";
  return "\x1b[38;5;154m";
}

function makeBar(pct, width = 12) {
  const n = Number(pct) || 0;
  const filled = Math.max(0, Math.min(width, Math.round((n / 100) * width)));
  const empty = width - filled;
  if (colorLevel() === 0) return `${" ".repeat(filled)}${"⣿".repeat(empty)}`;
  return `${bgColorFor(n)}${" ".repeat(filled)}\x1b[0m\x1b[2m${fgColorFor(n)}${"⣿".repeat(empty)}\x1b[0m`;
}

function emptyBar(width = 12) {
  const bar = "⣿".repeat(width);
  return colorLevel() === 0 ? bar : `\x1b[2m\x1b[38;5;245m${bar}\x1b[0m`;
}

function progress(pct, width = 12) {
  const n = Number(pct) || 0;
  const label = `${Math.round(n)}%`;
  if (colorLevel() === 0) return `${makeBar(n, width)} ${label}`;
  return `${makeBar(n, width)} ${fgColorFor(n)}${label}\x1b[0m`;
}

function formatReset(epoch, alwaysDate = false) {
  if (epoch == null || epoch === "") return "";
  const d = new Date(Number(epoch) * 1000);
  if (Number.isNaN(d.getTime())) return "";
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  const time = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  if (!alwaysDate && sameDay) return time;
  const month = d.toLocaleString("en-US", { month: "short" });
  return `${month} ${String(d.getDate()).padStart(2, "0")} ${time}`;
}

function formatTime(epoch) {
  if (epoch == null || epoch === "") return "";
  const d = new Date(Number(epoch) * 1000);
  if (Number.isNaN(d.getTime())) return "";
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

function moduleModel(input, config) {
  let name = get(input, "model.display_name", "");
  if (!name) return "";
  if (get(config, "modules.model.short", false)) name = String(name).split(/\s+/)[0];
  if (get(config, "modules.model.with_version", false)) {
    const id = get(input, "model.id", "");
    const match = /.*-([0-9]+)-([0-9]+)(-[0-9]{6,})?$/.exec(id);
    if (match) {
      const version = `${match[1]}.${match[2]}`;
      if (!new RegExp(`(^|[^0-9])${version.replace(".", "\\.")}([^0-9]|$)`).test(name)) name += ` ${version}`;
    }
  }
  let out = wrap(config, get(config, "colors.model", "white"), name);
  if (get(config, "modules.model.with_effort", false)) {
    const effort = get(input, "effort.level", "");
    if (effort) out += ` ${wrap(config, get(config, "colors.effort", "gray"), effort)}`;
  }
  return out;
}

function moduleEffort(input, config) {
  const level = get(input, "effort.level", "");
  return level ? wrap(config, get(config, "colors.effort", "gray"), level) : "";
}

function moduleBasicStatusline(input) {
  const reset = "\x1b[0m";
  const yellow = "\x1b[33m";
  const dim = "\x1b[2m";
  const color = colorLevel() !== 0;
  const model = get(input, "model.display_name", "");
  const effort = get(input, "effort.level", "");
  const used = get(input, "context_window.used_percentage", "");
  const five = get(input, "rate_limits.five_hour.used_percentage", "");
  const seven = get(input, "rate_limits.seven_day.used_percentage", "");
  const fiveReset = get(input, "rate_limits.five_hour.resets_at", "");
  const sevenReset = get(input, "rate_limits.seven_day.resets_at", "");
  const parts = [];
  if (model) parts.push(color ? `${yellow}${model}${reset}${effort ? ` ${dim}${effort}${reset}` : ""}` : `${model}${effort ? ` ${effort}` : ""}`);
  parts.push(used !== "" ? `ctx ${progress(used)}` : `ctx ${emptyBar()} ${color ? `${dim}--${reset}` : "--"}`);
  let fivePart = five !== "" ? `5h ${progress(five)}` : `5h ${emptyBar()} ${color ? `${dim}--${reset}` : "--"}`;
  if (five !== "" && fiveReset) fivePart += ` ${color ? `${dim}${formatTime(fiveReset)}${reset}` : formatTime(fiveReset)}`;
  parts.push(fivePart);
  let sevenPart = seven !== "" ? `7d ${progress(seven)}` : `7d ${emptyBar()} ${color ? `${dim}--${reset}` : "--"}`;
  if (seven !== "" && sevenReset) sevenPart += ` ${color ? `${dim}${formatReset(sevenReset, true)}${reset}` : formatReset(sevenReset, true)}`;
  parts.push(sevenPart);
  return parts.filter(Boolean).join(" │ ");
}

function moduleDirectory(input, config) {
  let dir = get(input, "workspace.current_dir", get(input, "cwd", ""));
  if (!dir) return "";
  if (get(config, "modules.directory.tilde", true) && dir.startsWith(os.homedir())) {
    dir = `~${dir.slice(os.homedir().length)}`;
  }
  const truncate = Number(get(config, "modules.directory.truncate", 30));
  if (truncate > 1 && dir.length > truncate) dir = `…${dir.slice(-(truncate - 1))}`;
  return wrap(config, get(config, "colors.directory", "blue"), dir);
}

function runGit(args, cwd) {
  try {
    return childProcess.execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], timeout: 500 }).trim();
  } catch {
    return "";
  }
}

function moduleGit(input, config) {
  const cwd = get(input, "workspace.current_dir", get(input, "cwd", process.cwd()));
  if (!runGit(["rev-parse", "--is-inside-work-tree"], cwd)) return "";
  const branch = runGit(["branch", "--show-current"], cwd) || runGit(["rev-parse", "--short", "HEAD"], cwd);
  if (!branch) return "";
  let out = branch;
  let dirty = false;
  if (get(config, "modules.git.show_status", true)) {
    const status = runGit(["status", "--porcelain=v1"], cwd).split(/\r?\n/).filter(Boolean);
    const staged = status.filter((line) => line[0] !== " " && line[0] !== "?").length;
    const unstaged = status.filter((line) => line[1] !== " " && line[0] !== "?").length;
    const untracked = status.filter((line) => line.startsWith("??")).length;
    dirty = staged + unstaged + untracked > 0;
    if (dirty) {
      out += " ●";
      if (staged) out += ` +${staged}`;
      if (unstaged) out += ` !${unstaged}`;
      if (untracked) out += ` ?${untracked}`;
    }
  }
  return wrap(config, get(config, dirty ? "colors.git_dirty" : "colors.git_clean", dirty ? "yellow" : "green"), out);
}

function moduleContextBar(input, config) {
  const pct = get(input, "context_window.used_percentage", 0);
  const width = Number(get(config, "modules.context_bar.width", 12));
  const label = get(config, "modules.context_bar.label", "ctx");
  return `${label ? `${label} ` : ""}${progress(pct, width)}`;
}

function thresholdColor(config, pct, ok, warn, crit) {
  const warnAt = Number(get(config, "modules.context_bar.thresholds_pct.0", 70));
  const critAt = Number(get(config, "modules.context_bar.thresholds_pct.1", 90));
  if (pct >= critAt) return get(config, `colors.${crit}`, "red");
  if (pct >= warnAt) return get(config, `colors.${warn}`, "yellow");
  return get(config, `colors.${ok}`, "green");
}

function moduleContextPct(input, config) {
  const pct = Math.round(Number(get(input, "context_window.used_percentage", 0)));
  return wrap(config, thresholdColor(config, pct, "context_ok", "context_warn", "context_crit"), `ctx ${pct}%`);
}

function rateSegment(input, config, key, label) {
  const pct = get(input, `rate_limits.${key}.used_percentage`, "");
  if (pct === "") return "";
  const reset = get(input, `rate_limits.${key}.resets_at`, "");
  const width = Number(get(config, "modules.rate_limit.bar_width", 12));
  const resetText = reset ? ` ${wrap(config, get(config, "colors.rate_reset", "gray"), formatReset(reset))}` : "";
  return `${label} ${progress(pct, width)}${resetText}`;
}

function moduleRateLimit(input, config) {
  const parts = [];
  const five = get(input, "rate_limits.five_hour.used_percentage", "");
  const seven = get(input, "rate_limits.seven_day.used_percentage", "");
  if (five !== "") parts.push(`5h ${Math.round(Number(five))}%`);
  if (seven !== "") parts.push(`7d ${Math.round(Number(seven))}%`);
  return parts.length ? wrap(config, get(config, "colors.rate_limit", "gray"), parts.join(" ")) : "";
}

function moduleCost(input, config) {
  const cost = Number(get(input, "cost.total_cost_usd", 0));
  if (cost < Number(get(config, "modules.cost.hide_below", 0))) return "";
  const format = get(config, "modules.cost.format", "$%.2f");
  const text = format.replace(/%\.([0-9]+)f/, (_, p) => cost.toFixed(Number(p))).replace("%f", String(cost));
  return wrap(config, get(config, "colors.cost", "magenta"), text);
}

function moduleSessionTimer(input, config) {
  const ms = Number(get(input, "cost.total_duration_ms", 0));
  if (!ms) return "";
  const s = Math.floor(ms / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const text = h > 0 ? `${h}h${m}m` : m > 0 ? `${m}m` : `${s}s`;
  return wrap(config, get(config, "colors.session_timer", "gray"), text);
}

function moduleLinesChanged(input, config) {
  const added = Number(get(input, "cost.total_lines_added", 0));
  const removed = Number(get(input, "cost.total_lines_removed", 0));
  return added || removed ? wrap(config, get(config, "colors.lines_changed", "gray"), `+${added} -${removed}`) : "";
}

const modules = {
  basic_statusline: moduleBasicStatusline,
  model: moduleModel,
  effort: moduleEffort,
  directory: moduleDirectory,
  git: moduleGit,
  context_bar: moduleContextBar,
  context_pct: moduleContextPct,
  rate_5h: (input, config) => rateSegment(input, config, "five_hour", "5h"),
  rate_7d: (input, config) => rateSegment(input, config, "seven_day", "7d"),
  rate_limit: moduleRateLimit,
  cost: moduleCost,
  session_timer: moduleSessionTimer,
  lines_changed: moduleLinesChanged,
  vim_mode: (input, config) => {
    const mode = get(input, "vim.mode", "");
    return mode ? wrap(config, get(config, "colors.vim_mode", "magenta"), `[${mode}]`) : "";
  },
  worktree: (input, config) => {
    const name = get(input, "worktree.name", get(input, "workspace.git_worktree", ""));
    return name ? wrap(config, get(config, "colors.worktree", "blue"), `wt:${name}`) : "";
  },
  agent: (input, config) => {
    const name = get(input, "agent.name", "");
    return name ? wrap(config, get(config, "colors.agent", "magenta"), `@${name}`) : "";
  },
};

function renderJson(raw) {
  const input = JSON.parse(raw || "{}");
  const config = loadConfig();
  const separator = config.separator || " | ";
  const lines = Array.isArray(config.lines) ? config.lines : [["basic_statusline"]];
  return lines
    .map((line) =>
      (Array.isArray(line) ? line : [])
        .map((name) => (modules[name] ? modules[name](input, config) : ""))
        .filter(Boolean)
        .join(separator),
    )
    .join("\n");
}

function readStdin() {
  return new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      data += chunk;
    });
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", reject);
  });
}

function quoteCommandArg(value) {
  return `"${String(value).replace(/"/g, '\\"')}"`;
}

function statuslineCommand() {
  return `node ${quoteCommandArg(__filename)} render`;
}

function classifyExisting(settings) {
  const cmd = get(settings, "statusLine.command", "");
  if (!cmd) return "none";
  if (cmd.includes("cc-statusline") || cmd.includes("cc-statusline-cli")) return "ours";
  return "custom";
}

function install(args) {
  const force = args.includes("--force");
  const keepExisting = args.includes("--keep-existing");
  const abortIfExists = args.includes("--abort-if-exists");
  const dryRun = args.includes("--dry-run");
  const configFile = ensureUserConfig();
  const settingsFile = settingsPath();
  const settings = readJsonFile(settingsFile, {});
  const state = classifyExisting(settings);

  if (state === "custom") {
    if (abortIfExists) {
      console.error("Existing statusLine detected. Aborting.");
      process.exitCode = 2;
      return;
    }
    if (keepExisting || !force) {
      console.log(`Kept existing statusLine. Run 'cc-statusline install --force' to replace it.`);
      console.log(`Config: ${configFile}`);
      return;
    }
  }

  if (dryRun) {
    console.log(`DRY RUN: would write statusLine to ${settingsFile}`);
    return;
  }

  if (fs.existsSync(settingsFile)) {
    fs.copyFileSync(settingsFile, `${settingsFile}.bak.${timestamp()}`);
  }
  settings.statusLine = { type: "command", command: statuslineCommand(), padding: 1 };
  writeJsonFile(settingsFile, settings);
  console.log(`cc-statusline ready`);
  console.log(`Config: ${configFile}`);
  console.log(`Settings: ${settingsFile}`);
}

function uninstall(args) {
  const purge = args.includes("--purge");
  const keepPkg = args.includes("--keep-package");
  const settingsFile = settingsPath();
  const configDir = userConfigDir();
  const configFile = path.join(configDir, "config.json");

  if (!fs.existsSync(settingsFile)) {
    console.log("No Claude Code settings found. Nothing to uninstall.");
    return;
  }
  const settings = readJsonFile(settingsFile, {});
  const cmd = get(settings, "statusLine.command", "");
  if (!cmd || (!cmd.includes("cc-statusline") && !cmd.includes("cc-statusline-cli"))) {
    console.log("statusLine is not managed by cc-statusline. Nothing to remove.");
    return;
  }

  const backupFiles = fs.readdirSync(path.dirname(settingsFile))
    .filter((f) => f.startsWith("settings.json.bak."))
    .sort()
    .reverse();
  if (backupFiles.length > 0) {
    const latestBackup = path.join(path.dirname(settingsFile), backupFiles[0]);
    fs.copyFileSync(latestBackup, settingsFile);
    console.log(`Restored settings from ${latestBackup}`);
  } else {
    delete settings.statusLine;
    writeJsonFile(settingsFile, settings);
    console.log("Removed statusLine from settings (no backup found).");
  }

  if (purge && fs.existsSync(configDir)) {
    fs.rmSync(configDir, { recursive: true });
    console.log(`Removed config directory: ${configDir}`);
  } else if (fs.existsSync(configFile)) {
    console.log(`Kept config at ${configFile} (use --purge to remove).`);
  }

  if (!keepPkg) {
    console.log("Removing npm package...");
    try {
      childProcess.execFileSync("npm", ["uninstall", "-g", "cc-statusline-cli"], { stdio: "inherit" });
    } catch {
      console.log("npm uninstall failed (package may already be removed).");
    }
  }
}

async function main() {
  const [cmd = ""] = process.argv.slice(2);
  if (!cmd && !process.stdin.isTTY) {
    console.log(renderJson(await readStdin()));
    return;
  }
  switch (cmd) {
    case "":
    case "help":
    case "--help":
    case "-h":
      usage();
      break;
    case "render":
      console.log(renderJson(await readStdin()));
      break;
    case "install":
    case "configure":
      install(process.argv.slice(3));
      break;
    case "uninstall":
      uninstall(process.argv.slice(3));
      break;
    case "version":
      console.log(`v${readPackageJson().version}`);
      break;
    default:
      console.error(`cc-statusline: unknown command: ${cmd}`);
      process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(`cc-statusline: ${error.message}`);
  process.exitCode = 1;
});
