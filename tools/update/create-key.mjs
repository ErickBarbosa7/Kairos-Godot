#!/usr/bin/env node
import { generateKeyPairSync } from "node:crypto";
import { mkdirSync, existsSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const target = process.argv[2];
if (!target) throw new Error("Uso: node tools/update/create-key.mjs <ruta-base-sin-extension>");
const base = resolve(target);
const privatePath = `${base}.private.pem`;
const publicPath = `${base}.public.b64`;
if (existsSync(privatePath) || existsSync(publicPath)) throw new Error("Ya existe una llave en esa ruta");
mkdirSync(dirname(base), { recursive: true });
const { privateKey, publicKey } = generateKeyPairSync("ed25519");
const spki = publicKey.export({ type: "spki", format: "der" });
writeFileSync(privatePath, privateKey.export({ type: "pkcs8", format: "pem" }), { mode: 0o600 });
writeFileSync(publicPath, spki.subarray(-32).toString("base64") + "\n");
console.log(`Llave privada: ${privatePath}`);
console.log(`Clave pública para launcher.json: ${publicPath}`);
