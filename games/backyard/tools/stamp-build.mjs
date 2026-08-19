// Stamps dist/index.html with what was built and where it is going.
//
// Both staging instances deploy from whatever is sitting in dist/ at the
// moment you run fly deploy — there is no branch tracking and nothing on the
// page says which build it is. With two URLs that is a trap: you compare A
// against B and have no way to confirm A is the build you think it is.
//
// The stamp is an HTML comment, so it costs nothing visually and can be read
// from outside with:  curl -s <url> | grep 'ygteev-build'
//
// Usage: node tools/stamp-build.mjs <target-name>

import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

const target = process.argv[2] || "unknown";
const git = (cmd, fallback) => {
  try {
    return execSync(`git ${cmd}`, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return fallback;
  }
};

const sha = git("rev-parse --short HEAD", "nogit");
const branch = git("rev-parse --abbrev-ref HEAD", "nobranch");
// Uncommitted work is the norm here, and it is exactly what makes two
// instances hard to tell apart — so say so explicitly rather than implying
// the sha is the whole truth.
const dirty = git("status --porcelain -- .", "") ? " +local-changes" : "";
const built = new Date().toISOString().replace(/\.\d+Z$/, "Z");

const file = "dist/index.html";
const html = readFileSync(file, "utf8");
const stamp = `<!-- ygteev-build target=${target} branch=${branch} sha=${sha}${dirty} built=${built} -->\n`;

writeFileSync(file, stamp + html.replace(/^<!-- ygteev-build [^>]*-->\n/, ""));
console.log(`stamped ${target}: ${branch}@${sha}${dirty} ${built}`);
