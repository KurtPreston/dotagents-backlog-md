// Read the plugin's config.jsonc and print its sync settings as shell assignments for `eval`.
// Strips comments and trailing commas without touching `//` inside strings, such as URLs.
// Usage: node lib/config.mjs [CONFIG_PATH]   (default: config.jsonc in the plugin folder)
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// Remove // and /* */ comments outside of strings
function stripComments(text) {
  let out = "";
  let inString = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    const next = text[i + 1];
    if (inString) {
      out += ch;
      if (ch === "\\") {
        out += next ?? "";
        i++;
      } else if (ch === '"') {
        inString = false;
      }
    } else if (ch === '"') {
      inString = true;
      out += ch;
    } else if (ch === "/" && next === "/") {
      while (i < text.length && text[i] !== "\n") {
        i++;
      }
      out += "\n";
    } else if (ch === "/" && next === "*") {
      i = text.indexOf("*/", i + 2);
      if (i === -1) {
        throw new Error("unterminated block comment");
      }
      i++;
    } else {
      out += ch;
    }
  }
  return out;
}

// Remove commas that directly precede a closing brace or bracket, outside of strings
function stripTrailingCommas(text) {
  return text.replace(/("(?:[^"\\]|\\.)*")|,(\s*[}\]])/g, (match, str, close) => str ?? close);
}

// Quote a value for safe use in a POSIX shell assignment
function shellQuote(value) {
  return `'${String(value).replaceAll("'", `'\\''`)}'`;
}

// Load the config, treating a missing file as all defaults
const pluginDir = join(dirname(fileURLToPath(import.meta.url)), "..");
const configPath = process.argv[2] || join(pluginDir, "config.jsonc");
let config = {};
if (existsSync(configPath)) {
  try {
    config = JSON.parse(stripTrailingCommas(stripComments(readFileSync(configPath, "utf8"))));
  } catch (error) {
    console.error(`backlog-md: can't parse ${configPath}: ${error.message}`);
    process.exit(1);
  }
}

// Print the sync settings with their defaults
const sync = config.sync ?? {};
console.log(`SYNC_ENABLED=${shellQuote(sync.enabled === true)}`);
console.log(`SYNC_REMOTE=${shellQuote(sync.remote ?? "")}`);
console.log(`SYNC_BRANCH=${shellQuote(sync.branch || "main")}`);
