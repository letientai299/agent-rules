# Interactive CLI/TUI via tmux

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

## When to Use

When a command requires sustained keyboard interaction or uses the alternate
screen buffer (e.g., `vim`, `less`, `fzf`, `htop`, `mysql`, `psql`, REPLs), and
the Bash tool cannot drive it directly.

MUST NOT use this for ordinary CLI commands that accept arguments and exit
(`grep`, `curl`, `git`, `jq`, etc.).

## Session Lifecycle

1. **Create** a dedicated session with a unique name to avoid conflicts with
   other agents or the user's sessions:

   ```sh
   tmux new-session -d -s "ai-<topic>-$$" '<command>'
   ```

2. **Interact** by sending keys and reading screen state:

   ```sh
   tmux send-keys -t "ai-<topic>-$$" '<keys>' Enter
   sleep 0.3  # wait for TUI to render
   tmux capture-pane -t "ai-<topic>-$$" -p
   ```

3. **Clean up** when done — MUST kill the session to avoid leaks:

   ```sh
   tmux kill-session -t "ai-<topic>-$$"
   ```

## Guidelines

- MUST prefix session names with `ai-` so they are identifiable and won't
  collide with the user's sessions.
- SHOULD wait for expected text in the captured pane before proceeding rather
  than using fixed sleep durations. Poll with short intervals (0.2–0.5s) and a
  timeout.
- SHOULD capture the pane with `-e` flag when ANSI styling is needed for
  parsing (e.g., detecting highlighted selections in `fzf`).
- MUST NOT leave sessions running after the task is complete.
- When multiple agents work in the same worktree, each agent MUST use a distinct
  session name (include PID or agent ID).

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
