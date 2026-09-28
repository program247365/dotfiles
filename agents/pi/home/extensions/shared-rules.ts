/**
 * Shared Rules Extension
 *
 * Appends the same global instructions Claude Code loads (CLAUDE.md, the
 * engineering philosophy, and agents/claude/rules/*.md) to pi's system
 * prompt, so both harnesses read one source of truth from dotfiles.
 */

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const AGENTS_DIR = join(homedir(), ".dotfiles", "agents");
const RULES_DIR = join(AGENTS_DIR, "claude", "rules");

// tool-use.md names Claude Code tools (Grep, Glob, Task) that pi doesn't have.
const CLAUDE_ONLY_RULES = new Set(["tool-use.md"]);

function readSharedRules(): string {
	const files = [
		join(AGENTS_DIR, "claude", "home", "CLAUDE.md"),
		join(AGENTS_DIR, "philosophy", "SOFTWARE_ENGINEERING.md"),
	];
	if (existsSync(RULES_DIR)) {
		for (const name of readdirSync(RULES_DIR).sort()) {
			if (name.endsWith(".md") && !CLAUDE_ONLY_RULES.has(name)) {
				files.push(join(RULES_DIR, name));
			}
		}
	}
	return files
		.filter((file) => existsSync(file))
		.map((file) => readFileSync(file, "utf-8").trim())
		.join("\n\n");
}

export default function sharedRulesExtension(pi: ExtensionAPI) {
	let sharedRules = "";

	pi.on("session_start", async () => {
		sharedRules = readSharedRules();
	});

	pi.on("before_agent_start", async (event) => {
		if (!sharedRules) return;
		event.systemPromptOptions.sections = {
			...event.systemPromptOptions.sections,
			"shared-global-instructions": sharedRules,
		};
	});
}
