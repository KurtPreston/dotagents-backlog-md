// Read the plugin's config.jsonc and print its settings as shell assignments for `eval`.
// Usage: node lib/config.mjs [CONFIG_PATH]   (default: config.jsonc in the plugin folder)
import { readConfig } from "./read-config.mjs";

// Quote a value for safe use in a POSIX shell assignment
function shellQuote(value) {
  return `'${String(value).replaceAll("'", `'\\''`)}'`;
}

const config = readConfig(process.argv[2]);

// Print the sync settings with their defaults
const sync = config.sync ?? {};
console.log(`SYNC_ENABLED=${shellQuote(sync.enabled === true)}`);
console.log(`SYNC_REMOTE=${shellQuote(sync.remote ?? "")}`);
console.log(`SYNC_BRANCH=${shellQuote(sync.branch || "main")}`);

// Print the web board settings with their defaults
const browser = config.browser ?? {};
console.log(`BROWSER_ENABLED=${shellQuote(browser.enabled !== false)}`);
console.log(`BROWSER_PORT=${shellQuote(Number(browser.port) || 6420)}`);
