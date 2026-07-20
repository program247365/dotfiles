#!/usr/bin/env bun
/**
 * Mirror Bear notes into ~/.local/share/qmd-bear as {uuid}.md files for
 * qmd to index as a plain filesystem collection.
 *
 * Incremental: only notes whose modified timestamp changed since the last
 * run are rewritten. Wired in as the qmd collection's update command, so
 * `qmd update` always syncs first.
 */
import { execFileSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const MIRROR = join(homedir(), ".local/share/qmd-bear");
const MANIFEST = join(MIRROR, ".manifest.json");
// Above this many changed notes, one bulk content dump (~8s for 6k notes)
// beats spawning bearcli per note.
const BULK_THRESHOLD = 50;

function bearcli(args: string[]): string {
  return execFileSync("bearcli", args, {
    encoding: "utf8",
    maxBuffer: 512 * 1024 * 1024,
  });
}

mkdirSync(MIRROR, { recursive: true });

type Meta = { id: string; modified: string; locked: string; location: string };
const all: Meta[] = JSON.parse(
  bearcli(["list", "--location", "all", "--format", "json", "--fields", "id,modified,locked,location"])
);
// Locked note content is not accessible through bearcli.
const notes = all.filter((n) => n.location !== "trash" && n.locked !== "yes");

let manifest: Record<string, string> = {};
if (existsSync(MANIFEST)) {
  try {
    manifest = JSON.parse(readFileSync(MANIFEST, "utf8"));
  } catch {}
}

const changed = notes.filter((n) => manifest[n.id] !== n.modified);

const contentById = new Map<string, string>();
if (changed.length > BULK_THRESHOLD) {
  const dump: { id: string; content?: string }[] = JSON.parse(
    bearcli(["list", "--location", "all", "--format", "json", "--fields", "id,content"])
  );
  for (const d of dump) {
    if (d.content !== undefined) contentById.set(d.id, d.content);
  }
}

for (const n of changed) {
  let content = contentById.get(n.id);
  if (content === undefined) {
    content = JSON.parse(bearcli(["cat", n.id, "--format", "json"])).content;
  }
  writeFileSync(join(MIRROR, `${n.id}.md`), content!);
}

const keep = new Set(notes.map((n) => `${n.id}.md`));
let removed = 0;
for (const f of readdirSync(MIRROR)) {
  if (f.endsWith(".md") && !keep.has(f)) {
    unlinkSync(join(MIRROR, f));
    removed++;
  }
}

const next: Record<string, string> = {};
for (const n of notes) next[n.id] = n.modified;
writeFileSync(MANIFEST + ".tmp", JSON.stringify(next));
renameSync(MANIFEST + ".tmp", MANIFEST);

console.log(`bear-sync: ${changed.length} updated, ${removed} removed, ${notes.length} total`);
