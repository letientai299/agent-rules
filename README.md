# agent-rules

A starter kit for managing AI coding agents. I built this for my own workflow
and use it daily — fork it, gut what you don't need, make it yours.

## The Problem

AI agents left to defaults will `git add -A` your `.env`, amend shared history,
skip research, and scatter screenshots across the repo root. The default
interaction model — pick one of three options in a TUI combobox — doesn't give
you enough information to make good decisions.

I wanted agents that produce detailed, auditable artifacts I can read before
deciding anything. Q&A files with design trade-offs. Code reviews with severity
levels and tracking. Research verification before shipping. All of it written to
files I can review at my own pace, not ephemeral chat bubbles.

## What This Gets You

**Workflows that produce artifacts, not just code.** The rules in `shared/`
define how agents should work, not just what code style to follow:

- **Q&A-driven design** — agents auto-create `.ai.dump/<topic>-q1.md` when a
  task is ambiguous. Each question gets an `**Answer:**` placeholder you fill
  in. The agent reads your answers and creates follow-up files. Decisions are
  documented, not lost in chat.
- **Structured code reviews** — reviews go to `.ai.dump/review-<topic>.md`,
  organized by severity (Critical → Important → Minor). Each finding has a
  status (Open, Fixed, Won't fix, Deferred) that gets updated as work
  progresses.
- **Research verification** — agents must verify technical decisions against
  official docs before finishing. Claude Code hooks enforce this at runtime;
  other agents follow it as a prompt-level rule.
- **Git safety** — `git add <file>` only, never `-A`. Pull before commit.
  Claude Code hooks block dangerous commands at runtime; other agents get the
  same rules via prompt.
- **Browser interaction** — tool selection (Chrome DevTools MCP vs Playwright),
  session persistence, focus-stealing prevention, token budget management.
- **Writing conventions** — reference-style links, artifact attribution,
  no stale directory trees in docs.
- **Hierarchical overrides** — global shared rules, machine-local overrides,
  per-project `AGENTS.md`, and per-directory `agents.local.md` that stack from
  farthest to closest.

**Multi-agent coordination** is included but isn't the main point — I added it
so multiple agents can work on the same codebase without stepping on each other.

Only Claude Code is fully supported (rules + runtime hooks). Codex and Copilot
install targets exist to test the rule-syncing mechanics, but those agents have
no hook system — the rules are prompt-level suggestions with no enforcement.

**Language-specific rules** auto-load based on what's in the project (`go.mod` →
`go.md`, `tsconfig.json` → `typescript.md`). RFC 2119 keywords (MUST/SHOULD/MAY)
make rule severity unambiguous.

## How This Compares

This repo is an opinionated _workflow template_ — it defines how agents should
behave, not just what code style to follow. Most other tools in this space solve
a different problem: syncing rules across agents, or collecting reusable style
templates.

|                              | agent-rules    | [Ruler][ruler] | [rulesync][rulesync] | [ai-rulez][airulez] | [awesome-cursorrules][awesome-cr] |
| ---------------------------- | -------------- | -------------- | -------------------- | ------------------- | --------------------------------- |
| Category                     | Workflow rules | Sync CLI       | Sync CLI             | Sync CLI            | Template collection               |
| Stars                        | —              | ~2.3k          | ~800                 | ~30                 | ~37k                              |
| Agents supported             | 1 (Claude Code)| 34+            | 26+                  | 18+                 | 1 (Cursor)                        |
| Workflow rules (Q&A, review) | Yes            | No             | No                   | No                  | No                                |
| Runtime enforcement (hooks)  | Claude Code    | No             | No                   | No                  | No                                |
| Research verification        | Yes            | No             | No                   | No                  | No                                |
| Artifact management          | Yes            | No             | No                   | No                  | No                                |
| Multi-agent coordination     | Yes            | No             | No                   | No                  | No                                |
| Auto-sync across agents      | No             | Yes            | Yes                  | Yes                 | No                                |
| MCP config propagation       | No             | Yes            | Yes                  | Yes                 | No                                |
| Context compression          | No             | No             | No                   | Yes                 | No                                |
| Remote includes              | No             | No             | No                   | Yes                 | No                                |
| Community template library   | No             | No             | Via registry         | No                  | 163+ rules                        |

**Where sync tools win.** If you use 5+ agents and want identical rules
everywhere, a sync CLI is the right tool. [Ruler][ruler] has the widest agent
support (34+). [rulesync][rulesync] has the most features (import/export,
skills, commands, subagents). [ai-rulez][airulez] has unique capabilities like
context compression and remote includes. These tools do one thing well: keep
configs in sync.

**Where template collections win.** If you want a quick starting point for
Cursor, [awesome-cursorrules][awesome-cr] has 163+ community-contributed rule
files organized by framework. Browse, copy, done.

**Where agent-rules wins.** None of the above define _how agents should work_ —
they define what rules agents should read. agent-rules is the workflow layer:
Q&A-driven design discussions, structured code reviews with severity tracking,
research verification gates, multi-agent file ownership and staging protocols.
Claude Code hooks enforce critical rules at runtime rather than relying on prompt
compliance alone. The trade-off is deliberate: depth of control over breadth of
agent support.

These approaches are complementary. You could use a sync tool to distribute
agent-rules' shared rules to more agents if needed.

## Getting Started

```sh
make claude
```

Codex and Copilot targets also exist (`make codex`, `make copilot`) but only
sync prompt-level rules — no runtime enforcement.

This symlinks rules into each agent's config directory. Existing files are
backed up to `.ai.dump/backup/`.

Browse the `shared/` directory — start with `general.md`, then look at the
workflows and language rules. Delete what doesn't apply, add what's missing for
your stack.

### Local overrides

`local/agents.md` is for machine-specific rules (gitignored). Per-project
overrides go in `agents.local.md` next to any `AGENTS.md` — also gitignored.

Rules are read from farthest to closest. Closer files win.

## The E2E Stress Test

The `e2e/` directory has a test that validates multi-agent coordination:
scaffold a Go project, launch 3 agents into overlapping file edits via tmux,
grade whether they followed the protocol. See [`e2e/README.md`][e2e] for the
grading rubric.

## License

MIT

[claude]: https://docs.anthropic.com/en/docs/claude-code
[codex]: https://github.com/openai/codex
[copilot]: https://github.com/features/copilot
[e2e]: e2e/README.md
[ruler]: https://github.com/intellectronica/ruler
[rulesync]: https://github.com/dyoshikawa/rulesync
[airulez]: https://github.com/Goldziher/ai-rulez
[awesome-cr]: https://github.com/PatrickJS/awesome-cursorrules
