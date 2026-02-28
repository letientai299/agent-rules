# C# Rules

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

## Async

- MUST suffix async methods with `Async` ([VSTHRD200][]).
- MUST NOT use `.GetAwaiter().GetResult()` or `.Result` ([VSTHRD002][]). Use
  async lazy initialization (`Lazy<Task<T>>` or `AsyncLazy<T>`) when startup
  code needs deferred async work.

## Performance

- MUST use `GeneratedRegex` (`[GeneratedRegex(...)]`) instead of `new Regex` or
  `Regex.IsMatch` with string patterns.
- SHOULD use `TryGetValue` / `TryAdd` on dictionaries instead of `ContainsKey`
  followed by indexer access.
- SHOULD prefer `Stopwatch` over `DateTimeOffset.UtcNow` for measuring elapsed
  time.
- SHOULD use static arrays or `FrozenSet<T>` for fixed lookup collections to
  reduce allocations.

## Error Handling

- MUST throw typed exceptions (e.g., `LockException`) instead of bare
  `Exception`. Callers should not need to parse message strings.
- MUST use `ArgumentException.ThrowIfNullOrEmpty` and similar guard methods
  instead of manual null checks with `throw`.

## Testing

- MUST NOT assert on exception message strings. Messages are not public API.

## Comments

- MUST use correct XML doc tags (`<summary>`, `<param>`, `<returns>`). MUST NOT
  leave misleading or outdated comments.

[VSTHRD002]: https://microsoft.github.io/vs-threading/analyzers/VSTHRD002.html
[VSTHRD200]: https://microsoft.github.io/vs-threading/analyzers/VSTHRD200.html
[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
