// PostToolUse hook: format markdown files after Write operations.

import type { Plugin } from "@opencode-ai/plugin";
import { exec } from "node:child_process";
import { promisify } from "node:util";

const execAsync = promisify(exec);

export const FormatMd: Plugin = async () => ({
  "tool.execute.after": async (input, _output) => {
    if (input.tool !== "write") {
      return;
    }

    const filePath = (input.args as Record<string, unknown>)?.filePath as
      | string
      | undefined;
    if (!filePath || !filePath.endsWith(".md")) {
      return;
    }

    try {
      await execAsync(`prettier --write "${filePath}"`);
    } catch {
      // Silently ignore prettier errors
    }
  },
});