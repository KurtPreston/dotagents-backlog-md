// Give tasks created on this machine that share an ID with a task already on the remote the next free ID.
// Two machines that create tasks while offline can both pick TASK-N; the rebase succeeds because the
// filenames differ, leaving two files with one ID. The remote's copy keeps its ID. The local copy gets a
// new filename and `id:`, and local-only tasks that referred to it in their frontmatter follow it.
// Prints "OLD NEW" for each renumbered task. Run from the board's root after rebasing.
// Usage: node lib/renumber.mjs REMOTE_REF
import { execFileSync } from "node:child_process";
import { readFileSync, renameSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";

const remoteRef = process.argv[2];
const git = (...args) => execFileSync("git", args, { encoding: "utf8" });
const lines = (text) => text.split("\n").filter(Boolean);
const idPattern = /^id:\s*['"]?([A-Za-z]+-\d+(?:\.\d+)*)['"]?\s*$/m;

// Split a task file into its frontmatter block and the rest
function splitFrontmatter(text) {
  const match = text.match(/^---\n[\s\S]*?\n---\n?/);
  return match ? [match[0], text.slice(match[0].length)] : ["", text];
}

// Read the ID from a task file's frontmatter, or null for non-task files
function taskId(text) {
  const [frontmatter] = splitFrontmatter(text);
  return frontmatter.match(idPattern)?.[1].toUpperCase() ?? null;
}

// List task files here and on the remote, with each local file's ID
const remoteFiles = new Set(lines(git("ls-tree", "-r", "--name-only", remoteRef, "--", "backlog")));
const localFiles = lines(git("ls-files", "--", "backlog")).filter((file) => file.endsWith(".md"));
const tasks = localFiles
  .map((file) => ({ file, id: taskId(readFileSync(file, "utf8")), remote: remoteFiles.has(file) }))
  .filter((task) => task.id);

// Find the highest top-level number used here or on the remote, to number new IDs past it
let highest = 0;
for (const name of [...remoteFiles, ...localFiles].map((file) => basename(file))) {
  const number = Number(name.match(/^[A-Za-z]+-(\d+)[ .]/)?.[1] ?? 0);
  highest = Math.max(highest, number);
}

// Pick local copies of IDs that a remote task already uses; subtask IDs are left alone with a warning
const byId = Map.groupBy(tasks, (task) => task.id);
const renames = [];
for (const [id, group] of byId) {
  if (group.length < 2 || !group.some((task) => task.remote)) {
    continue;
  }
  for (const task of group.filter((candidate) => !candidate.remote)) {
    if (id.includes(".")) {
      console.error(`backlog-md-sync: duplicate subtask ID ${id} in ${task.file}; renumber it by hand`);
      continue;
    }
    highest += 1;
    renames.push({ ...task, newId: id.replace(/\d+$/, String(highest)) });
  }
}

// Move each renamed task to its new filename and rewrite its frontmatter ID
for (const { file, id, newId } of renames) {
  const newNumber = newId.split("-")[1];
  const newFile = join(dirname(file), basename(file).replace(/^([A-Za-z]+-)\d+/, `$1${newNumber}`));
  const [frontmatter, body] = splitFrontmatter(readFileSync(file, "utf8"));
  writeFileSync(file, frontmatter.replace(idPattern, `id: ${newId}`) + body);
  renameSync(file, newFile);
  console.log(`${id} ${newId}`);
}

// Point frontmatter references in local-only tasks, such as dependencies, at the new IDs
const renamedFiles = new Set(renames.map((task) => task.file));
for (const { file } of tasks.filter((task) => !task.remote && !renamedFiles.has(task.file))) {
  const [frontmatter, body] = splitFrontmatter(readFileSync(file, "utf8"));
  let updated = frontmatter;
  for (const { id, newId } of renames) {
    updated = updated.replace(new RegExp(`(?<![\\w.-])${id}(?![\\w.])`, "gi"), newId);
  }
  if (updated !== frontmatter) {
    writeFileSync(file, updated + body);
  }
}
