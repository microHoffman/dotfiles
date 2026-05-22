#!/usr/bin/env node

import { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync } from "node:fs";
import { dirname } from "node:path";

const [, , targetPath, fragmentPath] = process.argv;

if (!targetPath || !fragmentPath) {
  console.error("Usage: merge-settings.mjs <target-settings.json> <fragment-settings.json>");
  process.exit(2);
}

function stripJsonc(input) {
  let output = "";
  let inString = false;
  let inLineComment = false;
  let inBlockComment = false;
  let escaped = false;

  for (let i = 0; i < input.length; i += 1) {
    const current = input[i];
    const next = input[i + 1];

    if (inLineComment) {
      if (current === "\n" || current === "\r") {
        inLineComment = false;
        output += current;
      }
      continue;
    }

    if (inBlockComment) {
      if (current === "*" && next === "/") {
        inBlockComment = false;
        i += 1;
      } else if (current === "\n" || current === "\r") {
        output += current;
      }
      continue;
    }

    if (inString) {
      output += current;

      if (escaped) {
        escaped = false;
      } else if (current === "\\") {
        escaped = true;
      } else if (current === "\"") {
        inString = false;
      }

      continue;
    }

    if (current === "\"") {
      inString = true;
      output += current;
      continue;
    }

    if (current === "/" && next === "/") {
      inLineComment = true;
      i += 1;
      continue;
    }

    if (current === "/" && next === "*") {
      inBlockComment = true;
      i += 1;
      continue;
    }

    output += current;
  }

  return stripTrailingCommas(output);
}

function stripTrailingCommas(input) {
  let output = "";
  let inString = false;
  let escaped = false;

  for (let i = 0; i < input.length; i += 1) {
    const current = input[i];

    if (inString) {
      output += current;

      if (escaped) {
        escaped = false;
      } else if (current === "\\") {
        escaped = true;
      } else if (current === "\"") {
        inString = false;
      }

      continue;
    }

    if (current === "\"") {
      inString = true;
      output += current;
      continue;
    }

    if (current === ",") {
      let j = i + 1;
      while (j < input.length && /\s/.test(input[j])) {
        j += 1;
      }

      if (input[j] === "}" || input[j] === "]") {
        continue;
      }
    }

    output += current;
  }

  return output;
}

function readSettings(path, fallback) {
  if (!existsSync(path)) {
    return fallback;
  }

  const raw = readFileSync(path, "utf8").replace(/^\uFEFF/, "");
  const trimmed = raw.trim();

  if (trimmed === "") {
    return fallback;
  }

  return JSON.parse(stripJsonc(trimmed));
}

function isPlainObject(value) {
  return Object.prototype.toString.call(value) === "[object Object]";
}

function mergeDeep(base, patch) {
  const result = { ...base };

  for (const [key, value] of Object.entries(patch)) {
    if (isPlainObject(result[key]) && isPlainObject(value)) {
      result[key] = mergeDeep(result[key], value);
    } else {
      result[key] = value;
    }
  }

  return result;
}

const existing = readSettings(targetPath, {});
const fragment = readSettings(fragmentPath, {});
const merged = mergeDeep(existing, fragment);
const nextContent = `${JSON.stringify(merged, null, 2)}\n`;
const currentContent = existsSync(targetPath) ? readFileSync(targetPath, "utf8") : "";

mkdirSync(dirname(targetPath), { recursive: true });

if (currentContent !== nextContent && existsSync(targetPath)) {
  const timestamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*$/, "Z");
  copyFileSync(targetPath, `${targetPath}.backup-${timestamp}`);
}

writeFileSync(targetPath, nextContent);
