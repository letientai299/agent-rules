# agent-rules

Opinionated rules and workflows for [Claude Code][claude]. Agents produce
auditable artifacts (Q&A files, structured reviews, research notes) instead of
burying decisions in chat history.

## Why

### Bad discussion UX

CLI coding agents are great for keyboard-driven UX and better integration with
other CLIs. However, the chatting UX has friction:

- Due to limited terminal space, they typically don't show enough useful info.
- No shortcut to scroll up. Using a mouse to scroll in a terminal feels weird.
- It's very annoying to have to keep selecting "Chat about this" and refining
  the proposed plan.
- There's no auditable trail of discussions and decisions. Session history
  exists, but it's hard to search and impossible to carry to other sessions.
- Can't read the agent's output when writing a prompt in vim via
  [`ctrl-g`][keybindings].
- Can't edit the plan in-place.
- The limited context length forces us to either compress (lossy) existing
  context, or export data and restart the prompt.

**My solution**: move the discussion out of the prompt, into files.

Agents write questions, proposals, reference info, and trade-offs to
`.ai.dump/<topic>-q<num>.md`. I open the file in my editor, answer inline, check
reference links, adjust the design, add my own questions. When done, I tell the
agent. It reads the file and prepares `q<num+1>` for follow-up questions, or
finalizes the plan when no more blockers.

This works well enough that I use the same pattern for [code
reviews][code-review], research, data modeling, API design, etc. Working this
way feels like an ongoing discussion with a collaborator. Prompting feels like
running a non-deterministic program.

<details>
<summary>Example Q&A file (<code>.ai.dump/git-worktree-rules-q1.md</code>). <code>Answer</code> are my responses to claude</summary>

```markdown
# Git Worktree & Linear History — Rule Gaps

## Context

Your current rules cover multi-agent in a **shared worktree** well (file
ownership, hunk staging, conflict retry). But they're silent on:

- Agents working in **separate worktrees** (auto-created or manual)
- Your preference for **linear history** (rebase, fast-forward)

Below are the gaps I found, grouped into topics. Each has a suggested rule
direction and an **Answer:** placeholder for your call.

---

## 1. Linear History Policy

Your `general.md` says `git pull --rebase` before committing, which implies
rebase preference, but never explicitly states the merge strategy.

**Suggestion:** Add to Git Safety in `general.md`:

- MUST use `--ff-only` when merging branches into main.
- MUST rebase feature branches onto `origin/main` before merging.
- MUST NOT use `git merge` without `--ff-only` on the main branch.

**Answer:** "MUST" is too strict. `--ff-only` is my preference, not mandatory by
some of my team. Consider refining this.

---

## 2. Stash Ban in Worktrees

Stash is global across all worktrees (`refs/stash` is shared). A `git stash pop`
in worktree B consumes stashes from worktree A.

**Suggestion:** MUST NOT use `git stash` — stash is global across worktrees. Use
WIP commits instead.

**Answer:** ok

---

## 3. Port Conflicts

> truncated...

---

_Written by claude (claude-opus-4-6)_
```

</details>

### No safety guardrails

Agents take shortcuts when unsupervised, hallucinate, and often produce
undesired code quality.

- Suppress lint warnings instead of fixing them.
- Try to use non-existent APIs, libraries.
- Multiple agents in the same repo overwrite each other's work.

**My solution**: [comprehensive rules](./shared), covering git operations, code
quality standard, validated claims, ...

Claude Code [hooks][hooks] enforce critical rules at runtime: `safe-git.sh`
blocks `git add -A` before it reaches the repo, and `check-research.sh` requires
the agent to verify technical claims against official docs before finishing. The
rest is prompt-level rules with [RFC 2119][rfc2119] severity
(`MUST`/`SHOULD`/`MAY`) so the agent knows what it can bend and what it can't.

## Install

Clone this repo, then

```sh
$ make claude
```

That command will backup your global `claude` config into `.ai.dump/backup`,
then make symlinks from the repo dir to correct place recognized `claude`.

Run `make codex`, `make copilot`, or `make all` for all 3 agents. Codex and
Copilot don't have the same level of support for runtime enforcements (via shell
script hooks), auto-discovering `rules/`, and following symlinks like Claude
does, so their compliance isn't as good. I mostly use Claude and add support for
other agents to get a similar UX when I need them.

## Rules

Rules are split into small files to save tokens. The agent loads only what's
relevant. `shared/general.md` is loaded every session, language files based on
project type, workflow files when the task triggers them.

### General (`shared/general.md`)

Loaded every session. Code style, [git safety][git-safety] (hunk-level staging,
no `git add -A`), [artifact conventions][artifacts], [research
verification][research], [toolchain detection][tooling]. Agents may push back on
your decisions, backed by evidence, not vibes.

All artifacts go to `.ai.dump/`. Agents scan this dir automatically, no need to
type full filenames.

### Workflows (`shared/workflows/`)

Loaded when the task triggers them.

- **[Q&A-driven discussion][qa]**: questions in `.ai.dump/<topic>-q<num>.md`
  with `**Answer:**` placeholders you fill in.
- **[Code reviews][code-review]**: severity-ranked findings, status tracking.
- **[Browser interaction][browser]**: Chrome DevTools MCP vs Playwright, session
  persistence, focus-stealing prevention.
- **[Writing conventions][writing]**: reference-style links, artifact
  attribution.
- **[Multi-agent coordination][multi-agent]**: file ownership, per-hunk staging,
  conflict retry.

### Languages (`shared/langs/`)

Auto-loaded based on project files. Currently contains Go, TypeScript, and
React.

### Customization

To add a language, create a file in `shared/langs/` and add a detection entry in
[Language Rules][lang-rules].

To add a workflow, create a file in `shared/workflows/` with a descriptive
`# heading` (e.g., `# Data modeling session`) and re-run `make`. Claude Code
picks up the file automatically via symlinks. Codex and Copilot use the heading
as a routing label in their generated instructions file, so the agent reads it
only when the task matches.

For per-project rules, add `AGENTS.md` at any directory level. Agents load all
of them from the project root down to the working directory. Closer files take
higher precedence. Personal overrides go in `agents.local.md` beside the
corresponding `AGENTS.md`. Those should be gitignored.

`local/` is git-tracked but its content is gitignored. Only the directory itself
needs to exist so the installer can symlink it. Put machine-specific rules here.

## Contributing

PRs welcome. However, the repo is deliberately small. Even workflow files that
don't load still requires defined, always-on routing conditions. More files,
more false triggers. Fork this and make it your own instead.

[claude]: https://docs.anthropic.com/en/docs/claude-code
[codex]: https://github.com/openai/codex
[copilot]: https://github.com/features/copilot
[code-review]: ./shared/workflows/code-review.md
[qa]: ./shared/workflows/qa.md
[browser]: ./shared/workflows/browser.md
[writing]: ./shared/workflows/writing.md
[multi-agent]: ./shared/workflows/multi-agent.md
[general]: ./shared/general.md
[lang-rules]: ./shared/general.md#language-rules
[git-safety]: ./shared/general.md#git-safety
[artifacts]: ./shared/general.md#artifacts
[research]: ./shared/general.md#research-verification
[tooling]: ./shared/general.md#tooling-detection
[hooks]: https://code.claude.com/docs/en/hooks
[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
[keybindings]: https://code.claude.com/docs/en/keybindings
