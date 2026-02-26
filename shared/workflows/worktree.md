# Working in a git worktree

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

## Stash Ban

MUST NOT use `git stash` — stash is global across all worktrees (`refs/stash` is
shared). A `git stash pop` in one worktree consumes stashes created in another.
Use WIP commits instead:

```sh
git commit -m "wip: ..."      # save work
git reset HEAD~1               # undo later
```

## Port Conflicts

MUST use unique ports per worktree when running dev servers. See
[dev-ports.md][dev-ports] for a deterministic hashing pattern that assigns
stable, collision-resistant ports based on the worktree directory name.

## Shared vs Per-Worktree State

Not all git state is isolated. This table summarizes what's shared:

| State             | Scope        | Notes                                      |
| ----------------- | ------------ | ------------------------------------------ |
| HEAD, index       | Per-worktree | Each worktree has its own branch and stage |
| Working directory | Per-worktree | Independent file trees                     |
| Stash             | Shared       | Why `git stash` is banned — see above      |
| Refs / branches   | Shared       | All worktrees see the same branches        |
| Hooks             | Shared       | `.git/hooks/` is common to all worktrees   |
| Config            | Shared       | `.git/config` is common to all worktrees   |

[dev-ports]: ./dev-ports.md
[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
