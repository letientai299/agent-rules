// Block broad git staging commands.
// Multi-agent safety: always stage specific files.

import type { Plugin } from "@opencode-ai/plugin";

export const SafeGit: Plugin = async () => ({
  "tool.execute.before": async (input, output) => {
    if (input.tool === "bash") {
      const cmd = output.args?.command || "";
      if (/git\s+add\s+(-A|--all|\.)\s*(?:\s|$)/.test(cmd)) {
        throw new Error(
          "Blocked: use 'git add <specific-files>', not 'git add -A' or 'git add .'"
        );
      }
    }
  },
});
