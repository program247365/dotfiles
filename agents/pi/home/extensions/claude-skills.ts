/**
 * Claude Skills Extension
 *
 * Shares Claude Code's skills (~/.claude/skills) with pi. Many are identical
 * copies of skills pi already auto-discovers in ~/.agents/skills or
 * ~/.pi/agent/skills; adding those again only produces collision warnings,
 * so this adds just the ones pi doesn't have. Top level only: synced/ holds
 * claude.ai skills that depend on Claude-only tools.
 */

import { existsSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CLAUDE_SKILLS_DIR = join(homedir(), ".claude", "skills");
const PI_DISCOVERED_SKILL_DIRS = [join(homedir(), ".agents", "skills"), join(homedir(), ".pi", "agent", "skills")];

function skillNames(dir: string): string[] {
	if (!existsSync(dir)) return [];
	return readdirSync(dir).filter((name) => existsSync(join(dir, name, "SKILL.md")));
}

export default function claudeSkillsExtension(pi: ExtensionAPI) {
	pi.on("resources_discover", () => {
		const alreadyDiscovered = new Set(PI_DISCOVERED_SKILL_DIRS.flatMap(skillNames));
		return {
			skillPaths: skillNames(CLAUDE_SKILLS_DIR)
				.filter((name) => !alreadyDiscovered.has(name))
				.map((name) => join(CLAUDE_SKILLS_DIR, name, "SKILL.md")),
		};
	});
}
