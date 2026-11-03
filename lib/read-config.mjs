// Parse the plugin's config.jsonc, treating a missing file as all defaults.
// Strips comments and trailing commas without touching `//` inside strings, such as URLs.
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

// Read the config at configPath, or config.jsonc in the plugin folder; exit on a parse error
export function readConfig(configPath) {
  const pluginDir = join(dirname(fileURLToPath(import.meta.url)), "..");
  const path = configPath || join(pluginDir, "config.jsonc");
  if (!existsSync(path)) {
    return {};
  }
  try {
    return JSON.parse(stripTrailingCommas(stripComments(readFileSync(path, "utf8"))));
  } catch (error) {
    console.error(`backlog-md: can't parse ${path}: ${error.message}`);
    process.exit(1);
  }
}
