#!/usr/bin/env node
import { createHash, createPrivateKey, sign } from "node:crypto";
import { mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";

const options = Object.fromEntries(process.argv.slice(2).map((item) => {
  const [key, value] = item.split("=", 2);
  return [key.replace(/^--/, ""), value];
}));
for (const key of ["version", "base-url", "private-key", "linux", "windows", "out"]) {
  if (!options[key]) throw new Error(`Falta --${key}=...`);
}
function artifact(file) {
  const data = readFileSync(file);
  return { url: `${options["base-url"].replace(/\/$/, "")}/${options.version}/${basename(file)}`, sha256: createHash("sha256").update(data).digest("hex"), size: statSync(file).size };
}
const manifest = { version: options.version, artifacts: { "linux-x86_64": artifact(resolve(options.linux)), "windows-x86_64": artifact(resolve(options.windows)) } };
const out = resolve(options.out);
mkdirSync(out, { recursive: true });
const bytes = Buffer.from(JSON.stringify(manifest, null, 2) + "\n");
const signature = sign(null, bytes, createPrivateKey(readFileSync(resolve(options["private-key"])))) .toString("base64") + "\n";
writeFileSync(`${out}/manifest.json`, bytes);
writeFileSync(`${out}/manifest.json.sig`, signature);
console.log(`Manifiesto firmado en ${out}`);
