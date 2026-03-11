# SQL / Relational Schema Rules

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

These rules apply to relational schema design and query patterns
(Postgres-focused, mostly portable). For in-code type design, see
[`shared/data-modeling.md`][dm]. When rules here conflict with the `ref/db/`
reference docs, these rules take precedence.

Primary reference: [SQL Antipatterns][karwin-vol1] and [More SQL
Antipatterns][karwin-vol2] by Bill Karwin. For detailed examples and rationale,
see [`ref/db/sql-antipatterns.md`][ref]. For best practices with examples, see
[`ref/db/schema-design.md`][design-ref]. For Postgres-specific features, see
[`ref/db/postgres.md`][pg-ref].

---

# Schema Design

## Normalize by Default

MUST normalize for OLTP. Denormalize only when profiling proves a JOIN
bottleneck and you have a plan to keep the redundant copy consistent (trigger,
materialized view, or event). Premature denormalization trades a future query
problem for a definite consistency problem.

```
Bad:  orders(id, user_id, user_email, ...)   -- stale when email changes
Good: orders(id, user_id, ...)               -- JOIN users to get email
```

See [normalization vs denormalization trade-offs][celerdata-norm].

## Separate Concerns into Tables

MUST give each table a single concept. Nullable column groups that apply only to
certain rows signal a missing table. This is normalization applied to entity
design.

```
Bad:  users(id, email, stripe_id, kyc_verified_at, company_name, company_vat)
Good: users(id, email) + user_payments(user_id, stripe_id) + companies(...)
```

See [the God Table anti-pattern][god-table].

## Make Invalid Data Unrepresentable

MUST use cross-column CHECK constraints and separate tables so illegal states
cannot exist in the database. Prefer a single status column over boolean flags
that can conflict. Use separate tables when nullable column groups must be
all-null or all-non-null.

See also the [in-code counterpart][dm] of this rule.

## Text + CHECK over Enum Types

MUST use `TEXT` with a `CHECK` constraint instead of `CREATE TYPE ... AS ENUM`
for value sets that may evolve. Postgres enum values cannot be removed; adding
one requires DDL and the new value cannot be used in the same transaction. A
CHECK constraint swap is a lightweight `ALTER TABLE DROP/ADD CONSTRAINT`.

```sql
-- Bad
CREATE TYPE order_status AS ENUM ('pending', 'shipped');

-- Good
status TEXT NOT NULL CHECK (status IN ('pending', 'shipped'))
```

See [native enums or CHECK constraints][close-enums] (Close.com).

## Closed vs Open Value Sets

Not all text discriminator columns deserve a CHECK. Distinguish between:

- **Closed sets (CHECK):** values the DB or a worker acts on. State machines,
  status columns, role columns. Adding a value changes system behavior. DDL is
  justified.
- **Open sets (no CHECK):** values the app interprets as routing keys.
  Notification channels, platform identifiers, provider names, plugin types.
  Adding a value means a new adapter or config, not new DB behavior. MUST NOT
  use CHECK constraints on open sets. SHOULD validate open-set values against a
  registry (config file, enum in code, or lookup table) at the application
  boundary.

MUST NOT require DDL to extend an existing feature. If a new value in a column
means "write a new adapter + config" (not "change DB/worker behavior"), the
column is an open set.

When an open set has per-value metadata with varying shapes (e.g., each push
platform needs different credentials), MUST use a single JSONB column for the
variable part instead of adding nullable columns per value. The DB never queries
inside it. Each adapter reads the blob as a whole.

```sql
-- Bad: closed CHECK on an open set (every new channel needs DDL)
channel TEXT NOT NULL CHECK (channel IN ('sms', 'push', 'email'))

-- Bad: nullable columns per variant (multicolumn-attributes anti-pattern)
p256dh_key TEXT,  -- web push only
auth_key   TEXT,  -- web push only
oauth_token TEXT, -- zalo only

-- Good: open set + JSONB for per-variant metadata
channel  TEXT NOT NULL,          -- sms, push, email, zalo, ...
platform TEXT NOT NULL,          -- ios, android, web, ...
metadata JSONB,                  -- platform-specific credentials/config
```

## Status Column over Boolean Flags

MUST use a single status column (text + CHECK) for mutually exclusive states.
Multiple booleans allow impossible combinations. Use timestamps (`published_at`,
`cancelled_at`) when you need both state and temporal context.

```sql
-- Bad
is_pending BOOLEAN, is_approved BOOLEAN, is_rejected BOOLEAN

-- Good
status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected'))
```

## Named CHECK Constraints

MUST add a named `CHECK` constraint for every domain invariant expressible as a
boolean: positive prices, valid ranges, cross-column relationships
(`end_date >= start_date`). The database is the first line of defense;
application validation is the second.

```sql
-- Bad
price NUMERIC                                       -- app-only validation

-- Good
price NUMERIC NOT NULL CONSTRAINT price_positive CHECK (price > 0)
```

See [PostgreSQL constraints docs][pg-constraints].

## No Comma-Separated Lists

MUST NOT store multi-valued attributes as delimited strings in a single column.
Use a junction table for many-to-many. Use array/JSONB only when the values are
opaque to queries (no filtering, no joining).

```sql
-- Bad
tags TEXT  -- 'python,sql,go'

-- Good
item_tags(item_id FK, tag_id FK)  -- junction table
```

## No Entity-Attribute-Value (EAV)

MUST NOT use generic `(entity_id, attr_name, attr_value)` tables for variable
attributes. EAV loses type safety, constraints, and makes aggregation painful.
Use table-per-subtype, class table inheritance, or JSONB with validation.

```sql
-- Bad
properties(entity_id, key TEXT, value TEXT)

-- Good
products(id, name, weight NUMERIC) + books(product_id FK, isbn, page_count)
```

## No Polymorphic Associations

MUST NOT use a `(target_id, target_type)` FK pattern. The database cannot
enforce referential integrity. Use exclusive arc (multiple nullable FKs with a
CHECK ensuring exactly one is non-null), a shared parent table, or separate
association tables.

```sql
-- Bad
comments(id, commentable_id INT, commentable_type TEXT)

-- Good (exclusive arc)
comments(id, post_id FK NULL, photo_id FK NULL,
  CHECK (num_nonnulls(post_id, photo_id) = 1))
```

## No Multicolumn Attributes

MUST NOT create numbered columns for repeated data (`phone1`, `phone2`,
`phone3`). Use a dependent table with a FK back to the parent.

## NUMERIC for Money, Not FLOAT

MUST use `NUMERIC(p, s)` or integer minor units for monetary values. MUST NOT
use `FLOAT` or `DOUBLE`. IEEE 754 binary floating-point accumulates rounding
errors invisible in small test data.

```sql
-- Bad
price FLOAT

-- Good
price NUMERIC(12, 2) NOT NULL CONSTRAINT price_positive CHECK (price > 0)
```

## Surrogate Keys Only When Needed

SHOULD use composite primary keys for junction tables. SHOULD use natural keys
when they are stable and compact (ISO codes, currency codes). MUST NOT add a
surrogate `id` to every table reflexively.

```sql
-- Bad
user_roles(id SERIAL PK, user_id FK, role_id FK, UNIQUE(user_id, role_id))

-- Good
user_roles(user_id FK, role_id FK, PRIMARY KEY(user_id, role_id))
```

## Hierarchical Data: Choose the Right Tree Model

SHOULD choose the tree model that fits the read/write pattern instead of
defaulting to adjacency list (`parent_id`). Options: [closure table][closure]
(most versatile), materialized path (read-heavy), nested sets (rarely modified),
recursive CTEs (shallow trees). Adjacency list + recursive CTEs is fine for most
cases. The rule is about knowing the trade-offs.

## JSONB: Structured Data Belongs in Columns

MUST NOT store queryable, structured data in JSONB to avoid schema design. JSONB
is for genuinely schemaless or opaque data. For opaque per-variant metadata in
open sets, see [Closed vs Open Value Sets](#closed-vs-open-value-sets). If you
query a JSON field regularly, it should be a column. If JSON arrays are joined
against, they should be a table.

```sql
-- Bad
settings JSONB  -- then WHERE settings->>'theme' = 'dark' everywhere

-- Good
theme TEXT NOT NULL DEFAULT 'light'  -- if queried/filtered regularly
metadata JSONB                       -- genuinely opaque plugin data
```

## Triggers for Bookkeeping Only

MUST limit triggers to mechanical bookkeeping: `updated_at`, audit logs, version
counters. MUST NOT put business logic in triggers (state transitions, emails,
external API calls). Business logic in triggers is invisible to the application,
untestable in isolation, and fires on bulk imports.

See [Postgres triggers best practices][opensourcedb-triggers].

## DB Owns Data Definition, Not Business Logic

CHECKs enforce _structural_ integrity: valid value sets, column relationships
that define what the data _means_. State machine transitions, workflow rules,
conditional validation belong in application code.

## DDL Stability

The schema MUST be stable against feature evolution. Extending an existing
feature's _value space_ (new adapter, new variant, new integration) MUST NOT
require a migration. DDL changes are reserved for genuinely new data domains: new tables,
new structural columns, new relationships.

Test: "If a product manager asks to support a new X, do I need a migration?"

- **New notification channel** (Zalo, Telegram) → no. New adapter + config.
- **New push platform** (Huawei HMS) → no. New adapter + token metadata.
- **New payment provider** (Stripe → PayPal) → no. New adapter + credentials.
- **Rider profiles with saved addresses** → yes. New table, new data domain.
- **Notification preferences per user** → yes. New table, new relationship.

See [Closed vs Open Value Sets](#closed-vs-open-value-sets) above.

## Soft Delete: Know the Trade-offs

SHOULD prefer hard delete with an archive table (JSON snapshot on delete) over
`deleted_at` columns. Soft delete breaks FK integrity, requires
`WHERE deleted_at IS NULL` on every query, and conflicts with unique
constraints. If soft delete is required, MUST use partial unique indexes:

```sql
CREATE UNIQUE INDEX users_email_active ON users (email) WHERE deleted_at IS NULL;
```

See [Soft Deletion Probably Isn't Worth It][brandur-soft-delete].

## Comments

MUST include rationale comments in sql files explaining _why_ a table is
structured the way it is. Link to docs for extensions or non-obvious features.

---

# Query Patterns

## No SELECT \*

MUST NOT use `SELECT *` in application queries. List columns explicitly. `*`
prevents covering-index optimizations, transfers excess data, and breaks when
columns change.

## Sargable Predicates

MUST NOT wrap indexed columns in functions in WHERE clauses. Rewrite as range
predicates or create expression indexes.

```sql
-- Bad (full table scan)
WHERE YEAR(created_at) = 2024

-- Good (index-friendly)
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'
```

## No N+1 Queries

MUST NOT fetch parent rows then loop to fetch children one at a time. Use a JOIN
or batch `IN (...)` query.

## UNION ALL by Default

SHOULD use `UNION ALL` unless deduplication is specifically needed. `UNION`
sorts the full result set to remove duplicates.

## No DISTINCT to Mask Bad Joins

MUST NOT add `DISTINCT` to suppress duplicates from incorrect joins. Fix the
join conditions. If duplicates remain after correct joins, investigate the data
model.

## Set-Based Operations over Cursors

SHOULD express bulk operations as single set-based statements (`UPDATE` with
subquery, `INSERT ... SELECT`) instead of row-by-row loops or cursors.

## Full-Text Search over LIKE

SHOULD use full-text search (`tsvector`/`tsquery` in Postgres, `FULLTEXT` in
MySQL) instead of `LIKE '%term%'` for user-facing search. `LIKE` with a leading
wildcard cannot use standard indexes.

---

# Process

## Verification

When designing a schema, MUST verify that invalid data is non-representable.
Write ad-hoc SQL INSERT statements that attempt to create illegal states and
confirm the database rejects them. Include the verification script or output in
the task artifact.

## Diagrams

SHOULD produce a [Mermaid][mermaid], [D2][d2], or [DBML][dbml] entity
relationship diagram in markdown when the schema has more than 3 tables. Place
the diagram in the artifact file (`.ai.dump/<topic>/`). The user's reviewing
tool renders fenced diagram blocks.

[dm]: ../data-modeling.md
[ref]: ../../ref/db/sql-antipatterns.md
[pg-ref]: ../../ref/db/postgres.md
[design-ref]: ../../ref/db/schema-design.md
[karwin-vol1]: https://pragprog.com/titles/bksap1/sql-antipatterns-volume-1/
[karwin-vol2]: https://pragprog.com/titles/bksap2/more-sql-antipatterns/
[celerdata-norm]:
  https://celerdata.com/glossary/normalization-vs-denormalization-the-trade-offs-you-need-to-know
[god-table]: https://wiki.c2.com/?GodTable
[close-enums]:
  https://making.close.com/posts/native-enums-or-check-constraints-in-postgresql/
[pg-constraints]: https://www.postgresql.org/docs/current/ddl-constraints.html
[closure]:
  https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/sql-server-closure-tables/
[opensourcedb-triggers]:
  https://opensource-db.com/postgres-triggers-best-practices-pgsql-phriday-007/
[brandur-soft-delete]: https://brandur.org/soft-deletion
[mermaid]: https://mermaid.js.org/
[d2]: https://d2lang.com/
[dbml]: https://dbml.dbdiagram.io/
[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
