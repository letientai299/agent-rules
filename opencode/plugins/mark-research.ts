// Mark when web research happens so check-research can verify it.

import type { Plugin } from "@opencode-ai/plugin";
import { existsSync, mkdirSync, writeFileSync } from "fs";
import { join } from "path";

const researchTools = new Set(["webfetch", "websearch", "grep"]);
const marked = new Set<string>();

export const MarkResearch: Plugin = async () => ({
  "tool.execute.after": async (input) => {
    if (!researchTools.has(input.tool)) return;

    const sid = ((input as Record<string, unknown>).sessionID ||
      (input as Record<string, unknown>).session_id) as string | undefined;
    if (!sid || marked.has(sid)) return;

    marked.add(sid);
    const dir = "/tmp/opencode-hooks";
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, `research-${sid}`), "", "utf-8");
  },
});
