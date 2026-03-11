# Data Modeling

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

These rules apply to in-code type/struct design. For relational schema rules,
see [`shared/langs/sql.md`][sql].

## Make Invalid States Unrepresentable

MUST structure types so illegal combinations cannot compile. Prefer
restructuring the type over adding runtime validation.

```
Bad:  { connected: bool, socket: Socket | null, error: string | null }
Good: Disconnected | Connected { socket } | Failed { error }
```

See [Make Illegal States Unrepresentable][corrode] for a detailed walkthrough.

## Discriminated Unions over Boolean Flags

MUST model mutually exclusive states as a discriminated union (tagged union, sum
type), not as separate booleans or nullable fields.

```
Bad:  { loading: bool, data: T | null, error: Error | null }
Good: Loading | Success { data: T } | Failure { error: Error }
```

Language-specific syntax: TS [discriminated unions][ts-du], Go interface + type
switch, C# abstract record hierarchy, Rust enum.

## Status Field over Boolean Flags

MUST use a single status field for states that will likely grow beyond two
values. `isActive` becomes active/suspended/deactivated/archived later.

```
Bad:  isActive: bool, isSuspended: bool
Good: status: "active" | "suspended" | "deactivated"
```

Only use booleans when the data is truly binary (e.g., a feature flag toggle).

## Newtype / Branded Types for Domain IDs

MUST NOT use interchangeable raw primitives for distinct domain identifiers.
Wrap in a newtype or branded type. Parse at the boundary, carry the proof in the
type.

```
Bad:  getUser(id: number)         — caller can pass any number
Good: getUser(id: UserId)         — type-safe, requires construction
```

See [Parse, Don't Validate][parse-dont-validate] and the [Rust newtype
pattern][rust-newtype].

## Value Objects

SHOULD make value objects (Money, Address, DateRange) immutable with structural
equality. They represent values, not identities. No ID field.

```
Bad:  class Address { id: string; street: string; city: string }
Good: class Address { readonly street: string; readonly city: string }
```

See [Value Object][fowler-vo] (Martin Fowler).

## Verification

When designing types for a domain model, MUST verify that invalid states are
non-representable. Write a short ad-hoc test or script that attempts to
construct illegal states and confirm they fail at compile time (or, for dynamic
languages, at construction time). Include the verification in the PR or task
artifact.

## Diagrams

SHOULD produce a [Mermaid][mermaid] or [D2][d2] class/entity diagram in markdown
when the model has more than 3 interrelated types. Place the diagram in the
artifact file (`.ai.dump/<topic>/`), not in source code. The user's reviewing
tool renders fenced diagram blocks.

[corrode]: https://corrode.dev/blog/illegal-state/
[ts-du]:
  https://www.typescriptlang.org/docs/handbook/2/narrowing.html#discriminated-unions
[parse-dont-validate]:
  https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/
[rust-newtype]:
  https://rust-unofficial.github.io/patterns/patterns/behavioural/newtype.html
[fowler-vo]: https://martinfowler.com/bliki/ValueObject.html
[mermaid]: https://mermaid.js.org/
[d2]: https://d2lang.com/
[sql]: ./langs/sql.md
[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
