# Running dev servers (especially in worktrees)

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

Avoid port collisions across worktrees by deriving offsets from the directory
name.

## Algorithm

MUST derive port offsets deterministically. Main branch → offset 0; others →
hash `basename $PWD` via `cksum`, `offset = (hash % 100) * 10` (100 slots of 10
ports each). MUST discover the correct port variable name from the project's
code or task runner.

```sh
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$branch" = "main" ]; then
  offset=0
else
  dir=$(basename "$PWD")
  hash=$(printf '%s' "$dir" | cksum | cut -d' ' -f1)
  offset=$(( (hash % 100) * 10 ))
fi

export DEV_PORT=$(( 3000 + offset ))
# Add more base ports as needed:
# export DEV_API_PORT=$(( 4000 + offset ))
```

## Integration

SHOULD inject port variables via the project's task runner so all scripts pick
them up automatically (e.g., `_.source` in `mise.toml`, `.envrc` for direnv,
`$PORT` in `package.json` scripts).

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
