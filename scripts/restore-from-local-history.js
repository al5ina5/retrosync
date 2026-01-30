#!/usr/bin/env node
/**
 * Restore retrosync project files from Cursor/VS Code Local History
 * to the state from approximately N hours ago.
 *
 * Usage: node scripts/restore-from-local-history.js [hoursAgo]
 * Default: 1 hour ago
 *
 * Cursor History: ~/Library/Application Support/Cursor/User/History/
 * Each subdir = one file's history. entries.json has resource (file URI) and entries (id, timestamp).
 * Content is in files named by entry.id.
 */

const fs = require("fs");
const path = require("path");

const WORKSPACE = path.resolve(__dirname, "..");
const isMac = process.platform === "darwin";
const historyRoot = isMac
  ? path.join(process.env.HOME, "Library/Application Support/Cursor/User/History")
  : path.join(process.env.APPDATA || "", "Code/User/History");

const hoursAgo = parseInt(process.argv[2] || "1", 10);
const targetTimeMs = Date.now() - hoursAgo * 60 * 60 * 1000;

if (!fs.existsSync(historyRoot)) {
  console.error("History folder not found:", historyRoot);
  process.exit(1);
}

const subdirs = fs.readdirSync(historyRoot);
const retrosyncEntries = []; // { workspacePath, historyDir, entries: [{ id, timestamp }] }

for (const subdir of subdirs) {
  const dirPath = path.join(historyRoot, subdir);
  if (!fs.statSync(dirPath).isDirectory()) continue;
  const entriesPath = path.join(dirPath, "entries.json");
  if (!fs.existsSync(entriesPath)) continue;
  let data;
  try {
    data = JSON.parse(fs.readFileSync(entriesPath, "utf8"));
  } catch (_) {
    continue;
  }
  const resource = data.resource;
  if (!resource || !resource.includes("retrosync")) continue;
  // file:///Users/.../retrosync/... -> /Users/.../retrosync/...
  let absPath = resource.replace(/^file:\/\//, "");
  if (!path.isAbsolute(absPath)) continue;
  if (!absPath.startsWith(WORKSPACE)) continue;
  const relativePath = path.relative(WORKSPACE, absPath);
  retrosyncEntries.push({
    workspacePath: path.join(WORKSPACE, relativePath),
    relativePath,
    historyDir: dirPath,
    entries: (data.entries || []).map((e) => ({ id: e.id, timestamp: e.timestamp || 0 })),
  });
}

let restored = 0;
let skipped = 0;
let errors = 0;

for (const item of retrosyncEntries) {
  const { workspacePath, relativePath, historyDir, entries } = item;
  if (entries.length === 0) {
    skipped++;
    continue;
  }
  // Pick entry with largest timestamp <= targetTimeMs (closest to "1 hour ago")
  // If none, pick smallest timestamp (oldest snapshot)
  const beforeTarget = entries.filter((e) => e.timestamp <= targetTimeMs);
  const chosen = beforeTarget.length
    ? beforeTarget.reduce((a, b) => (a.timestamp >= b.timestamp ? a : b))
    : entries.reduce((a, b) => (a.timestamp <= b.timestamp ? a : b));

  const contentPath = path.join(historyDir, chosen.id);
  if (!fs.existsSync(contentPath)) {
    errors++;
    continue;
  }

  const content = fs.readFileSync(contentPath, "utf8");
  const dir = path.dirname(workspacePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.writeFileSync(workspacePath, content, "utf8");
  restored++;
  const age = Math.round((Date.now() - chosen.timestamp) / 60000);
  console.log("Restored:", relativePath, "(snapshot from ~" + age + " min ago)");
}

console.log("\nDone. Restored:", restored, "Skipped (no entries):", skipped, "Errors:", errors);
