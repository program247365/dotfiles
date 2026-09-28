/**
 * Confirm Irreversible Extension
 *
 * pi runs bash without asking. This gates the commands the global rules say
 * to confirm first: pushes, deletions, hard resets, forced branch deletes.
 * Without a UI (print/JSON mode) they are blocked outright.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const IRREVERSIBLE_COMMANDS: Array<{ pattern: RegExp; label: string }> = [
	{ pattern: /\bgit\b[^;&|]*\bpush\b/, label: "git push" },
	{ pattern: /\bgit\b[^;&|]*\breset\b[^;&|]*--hard\b/, label: "git reset --hard" },
	{ pattern: /\bgit\b[^;&|]*\bbranch\b[^;&|]*\s-D\b/, label: "git branch -D" },
	{ pattern: /\bgit\b[^;&|]*\bclean\b[^;&|]*\s-\w*f/, label: "git clean -f" },
	{ pattern: /(^|[\s;&|(])rm\s/, label: "rm" },
	{ pattern: /\bsudo\b/, label: "sudo" },
];

export default function confirmIrreversibleExtension(pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return undefined;

		const command = event.input.command as string;
		const match = IRREVERSIBLE_COMMANDS.find(({ pattern }) => pattern.test(command));
		if (!match) return undefined;

		if (!ctx.hasUI) {
			return { block: true, reason: `${match.label} blocked: no UI to confirm` };
		}

		const choice = await ctx.ui.select(`Irreversible command (${match.label}):\n\n  ${command}\n\nAllow?`, [
			"No",
			"Yes",
		]);
		if (choice !== "Yes") {
			return { block: true, reason: `${match.label} blocked by user` };
		}
		return undefined;
	});
}
