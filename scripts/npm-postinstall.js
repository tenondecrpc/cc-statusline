#!/usr/bin/env node
"use strict";

const childProcess = require("node:child_process");
const path = require("node:path");

const cli = path.join(__dirname, "..", "bin", "cc-statusline.js");

try {
  childProcess.execFileSync(process.execPath, [cli, "install", "--keep-existing", "--non-interactive"], {
    stdio: "inherit",
  });
} catch (error) {
  console.warn("cc-statusline: automatic npm setup did not complete.");
  console.warn("cc-statusline: run 'cc-statusline install' after installing to configure Claude Code.");
  if (error && error.message) console.warn(`cc-statusline: ${error.message}`);
}
