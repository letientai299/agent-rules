// Warn once if no web research was done before the session stops.
// First stop without research: block. Second stop: allow (agent justified it).

import type { Plugin } from "@opencode-ai/plugin";
import { existsSync, mkdirSync, writeFileSync } from "fs";
import { join } from "path";

export const CheckResearch: Plugin = async () => ({
  stop: async (input) => {
    const sid = ((input as Record<string, unknown>).sessionID ||
      (input as Record<string, unknown>).session_id) as string | undefined;
    if (!sid) return;

    const dir = "/tmp/opencode-hooks";
    const marker = join(dir, `research-${sid}`);
    const warned = join(dir, `research-warned-${sid}`);

    if (existsSync(marker)) return;
    if (existsSync(warned)) return;

    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
    writeFileSync(warned, "", "utf-8");

    throw new Error(
      "Use WebSearch to verify technical decisions against official docs, or explain why it's unnecessary"
    );
  },
});
