# TypeScript Rules

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

- SHOULD keep most logic in `.ts` files (testable without UI runtime).
- SHOULD keep functions short, single responsibility, minimal arguments.
- SHOULD use modern DOM, JavaScript, TypeScript, CSS features.
- MUST colocate test files next to source (e.g., `foo.test.ts` beside `foo.ts`).
- MUST use `__tests__/` directories for shared test setup and utilities.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
