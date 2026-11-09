import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root = process.cwd();
const htmlFiles = fs.readdirSync(root).filter(name => name.endsWith(".html"));
const errors = [];
const warnings = [];

for (const file of htmlFiles) {
  const source = fs.readFileSync(path.join(root, file), "utf8");
  const ids = [...source.matchAll(/\bid=["']([^"']+)["']/g)].map(match => match[1]);
  const seen = new Set();
  for (const id of ids) {
    if (seen.has(id)) errors.push(file + ': duplicate id="' + id + '"');
    seen.add(id);
  }

  if (source.includes("\\n<")) errors.push(file + ": literal backslash-n before an HTML tag");
  if (!/<meta[^>]+name=["']description["']/i.test(source)) warnings.push(file + ": missing meta description");
  if (!/<link[^>]+rel=["']icon["']/i.test(source)) warnings.push(file + ": missing favicon link");

  const scripts = [...source.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
  scripts.forEach((match, index) => {
    if (/\bsrc=/i.test(match[1]) || /\btype=["\']application\/ld\+json["\']/i.test(match[1]) || !match[2].trim()) return;
    try {
      new vm.Script(match[2], { filename: file + " inline script " + (index + 1) });
    } catch (error) {
      errors.push(file + " inline script " + (index + 1) + ": " + error.message);
    }
  });

  const localRefs = [...source.matchAll(/\b(?:href|src)=["']([^"']+)["']/gi)].map(match => match[1]);
  for (const ref of localRefs) {
    if (!ref || ref.startsWith("#") || /^(?:https?:|mailto:|tel:|data:|javascript:)/i.test(ref)) continue;
    const clean = decodeURIComponent(ref.split(/[?#]/)[0]);
    if (!clean) continue;
    const target = path.resolve(root, clean);
    if (!target.startsWith(root + path.sep) && target !== root) {
      errors.push(file + ": local reference escapes repository: " + ref);
    } else if (!fs.existsSync(target)) {
      errors.push(file + ": missing local file " + ref);
    }
  }
}

if (warnings.length) {
  console.log("Warnings:");
  warnings.forEach(item => console.log(" - " + item));
}
if (errors.length) {
  console.error("Site quality checks failed:");
  errors.forEach(item => console.error(" - " + item));
  process.exit(1);
}
console.log("GabriPlay QA passed: " + htmlFiles.length + " HTML pages checked, inline JavaScript parses, IDs are unique and local assets exist.");
