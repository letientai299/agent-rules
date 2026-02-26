# Browser Interaction

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

## Tool Selection

SHOULD prefer Chrome DevTools MCP for headful work — it reuses the user's live
browser session, avoids focus stealing, and costs fewer tokens than Playwright's
accessibility-tree snapshots.

Use Playwright MCP when:

- Cross-browser testing is needed (Firefox, WebKit)
- Headless CI or isolated per-agent profiles are required

When either tool works, SHOULD prefer the one already configured in the session.

## Browser Channel

MUST use a non-default Chrome channel (canary or beta) so the agent does not
block the user from launching their default Chrome profile via Launchpad. Use
`--channel=canary` (preferred) or `--channel=beta`.

## Session & Auth

- MUST use a stable persistent profile so auth tokens, cookies, and
  customizations survive across sessions.
- MUST NOT launch throwaway/incognito contexts for auth-required sites.
- When sharing a session with the user, MUST attach to the existing browser
  instance — MUST NOT spawn a second browser window.

## Port Management

- MUST start browser MCP with a random CDP port (or let the tool auto-assign) to
  avoid conflicts with other agent instances.
- MUST NOT hardcode well-known ports (9222, 9229) unless explicitly instructed.

## Focus & Disruption

- MUST NOT let browser windows steal OS focus from the user.
  - Chrome DevTools MCP `--autoConnect`: attaches without spawning a new window.
  - Playwright MCP: use `--headless` for background work; for headful work, warn
    the user that focus stealing is unavoidable.
- When headful operation is required, SHOULD inform the user before launching.

## Screenshots & Artifacts

- MUST save screenshots to `.ai.dump/<topic>/` — MUST NOT save to repo root.
- SHOULD name files descriptively: `<step>-<description>.png` (e.g.,
  `01-login-form.png`, `02-dashboard-loaded.png`).

## Performance & Token Budget

- SHOULD use HTTP HEAD to smoke-test page size before fetching full content.
- For large pages, MUST dump content to a local file and reference it rather
  than passing the full content through the tool call.
- Playwright MCP: SHOULD use `--output-mode file` or snapshot-to-file to avoid
  context overflow from large accessibility trees.
- SHOULD prefer `evaluate` / script execution for repetitive operations instead
  of multiple individual tool calls.

## Common Pitfalls

- **Stale WebSocket URLs:** Playwright's `--cdp-endpoint` URL changes on browser
  restart. Prefer `--autoConnect` (CDP MCP) or the Playwright Bridge extension
  for stable connections.
- **Multi-agent tab conflicts:** each agent MUST use its own browser profile or
  isolated context — MUST NOT share tabs between agents.
- **Cookie/session expiry:** for long sessions, SHOULD check auth state before
  deep navigation. Re-login early rather than failing mid-workflow.
- **Large DOM snapshots:** Playwright's a11y tree can exceed 500 KB per page.
  Use file output mode or switch to CDP MCP for observation-heavy tasks.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
