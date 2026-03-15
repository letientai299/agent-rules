// Save session ID for artifact attribution (## Authors sections).
// Sets OPENCODE_SESSION_ID env var in shell sessions and writes a
// fallback file at /tmp/.opencode-sid-<ppid>.

import type { Plugin } from "@opencode-ai/plugin";
import { writeFileSync } from "fs";

let sessionId: string | undefined;

export const SaveSessionId: Plugin = async () => ({
  event: async ({ event }) => {
    if (event.type === "session.created") {
      const e = event as Record<string, unknown>;
      sessionId = (e.session_id || e.sessionID) as string | undefined;
      if (sessionId) {
        writeFileSync(
          `/tmp/.opencode-sid-${process.ppid || "unknown"}`,
          sessionId,
          "utf-8"
        );
      }
    }
  },

  "shell.env": async (_input, output) => {
    if (sessionId) {
      output.env.OPENCODE_SESSION_ID = sessionId;
    }
  },
});
