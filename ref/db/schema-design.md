# Relational Schema Design: Best Practices

A reference for AI agents. Covers the "what to do" side of schema design. For
antipatterns ("what not to do"), see [`sql-antipatterns.md`][antipatterns]. For
Postgres-specific features, see [`postgres.md`][pg-ref]. For enforceable rules,
see [`shared/langs/sql.md`][sql-rules].

---

# Normalization

## Target BCNF

Aim for **BCNF** (Boyce-Codd Normal Form) for OLTP systems. The progression:

| Form | Rule                                                | Example violation                                                                   |
| ---- | --------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 1NF  | Atomic values. No repeating groups.                 | `tags TEXT` containing `'a,b,c'`                                                    |
| 2NF  | Every non-key column depends on the _entire_ PK.    | `order_items(order_id, product_id, product_name)` — name depends only on product_id |
| 3NF  | No transitive dependencies between non-key columns. | `users(zip, city)` — city derivable from zip                                        |
| BCNF | For every dependency `X → Y`, X is a superkey.      | Edge case where a non-candidate key determines part of a candidate key              |

Stop at BCNF. 4NF/5NF address multi-valued and join dependencies that rarely
appear in application databases. 6NF is relevant only for temporal data. See
C.J. Date's [Database Design and Relational Theory][date] for the full
treatment.

## When to Denormalize

Denormalization is a performance optimization applied to an already-normalized
model. Never denormalize a model that was never normalized.

**Justified when:**

- Read-heavy aggregations (dashboards, reports) join 5+ tables on every request.
  Precompute via materialized view or denormalized column.
- Latency-critical hot paths where a JOIN is a measured bottleneck.
- Data warehouses (star/snowflake schemas are intentionally denormalized).
- Caching derived values (e.g., `order_total` maintained by trigger).

**Not justified when:**

- "Joins are slow" without measurement.
- The schema is still evolving (denormalization locks you in).

**Evaluation checklist:**

1. Is there a measured performance problem?
2. Can an index, materialized view, or query rewrite solve it?
3. How will you keep the denormalized data consistent?
4. What is the write-to-read ratio? High writes make denormalization expensive.

---

# Key Selection

## Natural vs Surrogate Keys

| Approach    | Use when                                                        | Avoid when                                                   |
| ----------- | --------------------------------------------------------------- | ------------------------------------------------------------ |
| Natural key | Value is stable, unique, meaningful: ISO codes, stock tickers   | Value can change (email, username), is long, or multi-column |
| Surrogate   | Entity has no stable natural identifier, or natural key is wide | Lookup/reference tables where the code itself is the key     |

Use a surrogate PK for most entity tables. Enforce the natural key as a `UNIQUE`
constraint.

```sql
CREATE TABLE customers (
  id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email TEXT NOT NULL,
  CONSTRAINT customers_email_unique UNIQUE (email)
);
```

## UUID vs Identity

| Type                  | Size | Pros                                           | Cons                                                       |
| --------------------- | ---- | ---------------------------------------------- | ---------------------------------------------------------- |
| `BIGINT IDENTITY`     | 8 B  | Compact, sorted, fast inserts, cache-friendly  | Leaks ordering, single sequence (problematic for sharding) |
| UUID v4 (random)      | 16 B | No central coordinator, generate anywhere      | 2x storage, random inserts cause B-tree page splits        |
| UUID v7 (time-sorted) | 16 B | Sorted + globally unique, good B-tree locality | PG 18+; before that, generate in app layer                 |

**Decision depends on the domain:**

- **Single-database OLTP:** `BIGINT IDENTITY`. ~3x faster inserts than UUID v4.
- **Distributed systems or public APIs:** UUID v7 (when available). Never expose
  sequential IDs in public APIs — use a separate `public_id` column.
- **Multi-tenant SaaS with potential sharding:** UUID v7 from the start to avoid
  future migration pain.

```sql
-- Internal entity
CREATE TABLE orders (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

-- Public-facing entity
CREATE TABLE orders (
  id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT orders_public_id_unique UNIQUE (public_id)
);
```

## Composite Keys

Use for **junction tables** and **weak entities** where the combination is the
natural identifier:

```sql
CREATE TABLE course_enrollments (
  student_id BIGINT NOT NULL REFERENCES students(id),
  course_id  BIGINT NOT NULL REFERENCES courses(id),
  enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (student_id, course_id)
);
```

Avoid composite keys when the table will be heavily referenced as a FK from
other tables — composite FKs add complexity at every referencing table.

---

# Constraint Strategy

## NOT NULL by Default

Every column should be `NOT NULL` unless there is an explicit reason for nulls.
Nulls introduce three-valued logic and hide data integrity bugs.

**Legitimate nullable columns:**

- Genuinely optional values (middle name, notes)
- Values not yet known at insert time with no sensible default
- Optional FK relationships (`manager_id` where the CEO has no manager)

## Foreign Key Actions

| Action        | Use when                                                    | Example                                |
| ------------- | ----------------------------------------------------------- | -------------------------------------- |
| `RESTRICT`    | **Default.** Child has independent value.                   | `orders` → `customers`                 |
| `CASCADE`     | Child is a component that cannot exist without parent.      | `order_items` → `orders`               |
| `SET NULL`    | Child should survive parent deletion, lose the association. | `posts.author_id` when user is deleted |
| `SET DEFAULT` | Rare. Reassign orphaned records to a sentinel value.        | Reassign to a "system" user            |

```sql
CREATE TABLE order_items (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id   BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT
);
```

**For large tables:** add FKs with `NOT VALID` + separate `VALIDATE CONSTRAINT`
to avoid blocking writes during migration:

```sql
ALTER TABLE order_items
  ADD CONSTRAINT order_items_order_fkey
  FOREIGN KEY (order_id) REFERENCES orders(id) NOT VALID;

ALTER TABLE order_items VALIDATE CONSTRAINT order_items_order_fkey;
```

## CHECK Constraints

Encode invariants that are **always true** regardless of business logic:

```sql
CHECK (price > 0)
CHECK (end_date > start_date)
CHECK (status IN ('pending', 'confirmed', 'shipped'))
CHECK (email ~* '^.+@.+\..+$')
```

Leave to application code: rules that change frequently, rules requiring
cross-table lookups, rules with complex temporal logic.

## Unique Constraints

- **Simple:** `UNIQUE (email)` on a user table
- **Partial:** uniqueness on a subset of rows (e.g., soft-delete):

  ```sql
  CREATE UNIQUE INDEX users_email_active ON users (email) WHERE deleted_at IS NULL;
  ```

- **Expression:** case-insensitive uniqueness:

  ```sql
  CREATE UNIQUE INDEX users_email_ci ON users (lower(email));
  ```

---

# Table Design Patterns

## One Table per Concept

Each table represents one entity. Signs you need to split:

- Groups of columns that are always NULL together (optional sub-entity)
- A "type" column that changes which other columns are relevant
- Two unrelated query patterns hitting the same table for different column sets

## Inheritance Strategies

**The right strategy depends on the domain:**

| Strategy       | How it works                                        | Best for                                                    | Drawbacks                                    |
| -------------- | --------------------------------------------------- | ----------------------------------------------------------- | -------------------------------------------- |
| Single Table   | One table, discriminator column, nullable type-cols | Few subtypes, mostly shared attributes, polymorphic queries | Nullable columns, wasted space               |
| Class Table    | Base table + subtype tables joined via shared PK    | Many type-specific attributes, strong data integrity        | Joins on every query, complex inserts        |
| Concrete Table | Separate table per subtype, no shared base          | Subtypes nearly independent, rarely queried together        | Duplicated shared columns, no polymorphic FK |

**Example — Class Table Inheritance (most common for strong data models):**

```sql
-- Base
CREATE TABLE vehicles (
  id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('car', 'truck', 'motorcycle')),
  make TEXT NOT NULL,
  year INT NOT NULL CHECK (year > 1885)
);

-- Subtypes
CREATE TABLE cars (
  vehicle_id  BIGINT PRIMARY KEY REFERENCES vehicles(id),
  door_count  INT NOT NULL CHECK (door_count BETWEEN 2 AND 5),
  trunk_liters NUMERIC
);

CREATE TABLE trucks (
  vehicle_id    BIGINT PRIMARY KEY REFERENCES vehicles(id),
  payload_kg    NUMERIC NOT NULL CHECK (payload_kg > 0),
  axle_count    INT NOT NULL CHECK (axle_count >= 2)
);
```

**Example — Single Table (when subtypes share most attributes):**

```sql
CREATE TABLE notifications (
  id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  type    TEXT NOT NULL CHECK (type IN ('email', 'sms', 'push')),
  user_id BIGINT NOT NULL REFERENCES users(id),
  body    TEXT NOT NULL,
  -- Type-specific (nullable)
  email_subject  TEXT,  -- only for email
  phone_number   TEXT,  -- only for sms
  device_token   TEXT,  -- only for push
  CHECK (
    CASE type
      WHEN 'email' THEN email_subject IS NOT NULL
      WHEN 'sms'   THEN phone_number IS NOT NULL
      WHEN 'push'  THEN device_token IS NOT NULL
    END
  )
);
```

## Junction Tables

Always use an explicit junction table for many-to-many. Add columns when the
relationship itself has attributes:

```sql
CREATE TABLE project_members (
  project_id BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role       TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (project_id, user_id)
);
```

## Lookup Tables vs CHECK Constraints

| Approach     | Use when                                                                          |
| ------------ | --------------------------------------------------------------------------------- |
| CHECK        | Small, stable set of values that rarely changes (status codes, priorities)        |
| Lookup table | Values change frequently, need metadata (labels, sort order), or are user-managed |

```sql
-- CHECK: simple, no join
status TEXT NOT NULL CHECK (status IN ('draft', 'published', 'archived'))

-- Lookup: when metadata is needed
CREATE TABLE categories (
  code       TEXT PRIMARY KEY,
  label      TEXT NOT NULL,
  sort_order INT NOT NULL
);
```

## Audit Tables

Trigger-based audit log using JSONB for old/new values. Handles schema changes
without modifying the audit infrastructure.

```sql
CREATE TABLE audit_log (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name TEXT NOT NULL,
  record_id  BIGINT NOT NULL,
  action     TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_values JSONB,
  new_values JSONB,
  changed_by TEXT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION audit_trigger_fn() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES (
    TG_TABLE_NAME,
    coalesce(NEW.id, OLD.id),  -- assumes single `id` PK; adapt for composite PKs
    TG_OP,
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END,
    current_setting('app.current_user', true)
  );
  RETURN coalesce(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Attach to any table
CREATE TRIGGER orders_audit
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();
```

For high-write tables, consider [pgAudit][pgaudit] (extension-based,
statement-level) to reduce per-row overhead.

## Temporal Data

Three flavors, depending on the domain:

| Type             | Tracks                                | Use case                                          |
| ---------------- | ------------------------------------- | ------------------------------------------------- |
| Valid-time       | When a fact is true in the real world | Price history, insurance policies, employee roles |
| Transaction-time | When the DB recorded the fact         | Regulatory audit trails, compliance               |
| Bi-temporal      | Both dimensions                       | Financial systems, legal records                  |

```sql
-- Valid-time: price history with no overlapping periods
CREATE TABLE product_prices (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES products(id),
  price      NUMERIC(12, 2) NOT NULL CHECK (price > 0),
  valid_from TIMESTAMPTZ NOT NULL,
  valid_to   TIMESTAMPTZ NOT NULL DEFAULT 'infinity',
  CHECK (valid_to > valid_from),
  EXCLUDE USING GIST (
    product_id WITH =,
    tstzrange(valid_from, valid_to) WITH &&
  )
);
```

Use `[closed, open)` intervals by convention. The GiST exclusion constraint
prevents overlapping periods at the database level.

---

# Indexing Strategy

## Composite Index Column Ordering (ESR Rule)

1. **Equality** columns first (`WHERE status = 'active'`)
2. **Sort** columns next (`ORDER BY created_at DESC`)
3. **Range** columns last (`WHERE created_at > '2025-01-01'`)

```sql
-- Query: WHERE tenant_id = ? AND status = 'active' ORDER BY created_at DESC
CREATE INDEX idx_orders_tenant_status_created
  ON orders (tenant_id, status, created_at DESC);
```

The index serves any **prefix** of its columns: `(a)`, `(a, b)`, `(a, b, c)` —
but not `(b)` or `(c)` alone.

See [use-the-index-luke.com][idx-luke] for the full treatment.

## Partial Indexes

Index only the rows that matter. Smaller, faster, less bloat.

```sql
-- 2% of orders are unshipped but 90% of queries target them
CREATE INDEX idx_orders_unshipped
  ON orders (created_at) WHERE status IN ('pending', 'confirmed');
```

The query's WHERE clause must match or imply the index predicate.

## When NOT to Index

- **Low-cardinality standalone** (boolean, gender). The planner prefers a
  sequential scan. Use as part of a composite or partial index instead.
- **Write-heavy tables with minimal reads.** Every index adds overhead to
  INSERT, UPDATE, DELETE.
- **Rarely queried columns.** Monitor `pg_stat_user_indexes.idx_scan`. Zero
  scans over months → drop it.

## Index Maintenance

- **Bloat source:** under MVCC, updates create dead index entries.
- **Prevention:** `fillfactor = 80-90` on high-update tables for HOT updates.
- **Monitoring:** `pg_stat_user_indexes` for usage, [pgstattuple][pgstattuple]
  for bloat measurement.
- **Remediation:** `REINDEX CONCURRENTLY` rebuilds without blocking.
- **Production safety:** always use `CREATE INDEX CONCURRENTLY` and
  `DROP INDEX CONCURRENTLY`.

---

# Data Type Selection

## Text

Use `TEXT` as the default. `TEXT` and `VARCHAR(n)` have identical performance in
Postgres. Add a `CHECK (length(col) <= n)` when the limit is a domain rule.
Never use `CHAR(n)` — it pads with spaces.

## Numeric

| Type                        | Use for                          |
| --------------------------- | -------------------------------- |
| `INTEGER` / `BIGINT`        | Whole numbers, counts, IDs       |
| `NUMERIC(p, s)`             | Exact decimals: money, financial |
| `REAL` / `DOUBLE PRECISION` | Scientific/statistical data only |

Never use FLOAT for money. `0.1 + 0.2 ≠ 0.3` in IEEE 754.

## Timestamps

Always `TIMESTAMPTZ`. The `TIMESTAMP` type (without time zone) silently produces
wrong results when the server or session timezone changes. Never use `TIMETZ`
([PostgreSQL wiki advises against it][pg-dont]).

## Domain Types

Create domain types for repeated validation patterns:

```sql
CREATE DOMAIN positive_amount AS NUMERIC(12, 2) CHECK (VALUE > 0);
CREATE DOMAIN email AS TEXT CHECK (VALUE ~* '^[^@]+@[^@]+\.[^@]+$');
```

## JSONB and Arrays

**JSONB is appropriate when:**

- Schema is genuinely variable (user preferences, plugin config, external API
  responses)
- The JSON structure is queried but not joined against

**JSONB is not appropriate when:**

- Structure is known and stable → use proper columns
- You frequently filter on `payload->>'field'` → that field should be a column
- You need referential integrity on values inside the JSON

**Arrays** (`TEXT[]`, `INT[]`) are for small, ordered lists of scalars that
belong to the row and don't need their own identity. Not a replacement for
junction tables.

---

# Schema Evolution

## Expand-Contract Pattern

Split every breaking change into two deployments:

1. **Expand:** add the new structure alongside the old. Both old and new code
   work.
2. **Migrate data:** backfill the new structure.
3. **Contract:** remove the old structure after all code uses the new one.

```sql
-- Renaming a column: expand
ALTER TABLE users ADD COLUMN full_name TEXT;
UPDATE users SET full_name = name;  -- batch in chunks for large tables
ALTER TABLE users ALTER COLUMN full_name SET NOT NULL;

-- (deploy code that reads/writes both columns)

-- Contract (after rollout)
ALTER TABLE users DROP COLUMN name;
```

## Safe Changes (No Expand-Contract Needed)

- `ADD COLUMN` with no `NOT NULL` (or with a `DEFAULT`)
- `CREATE INDEX CONCURRENTLY`
- `ADD CONSTRAINT ... NOT VALID` + later `VALIDATE CONSTRAINT`
- Creating new tables, views, functions

## Breaking Changes (Require Expand-Contract)

- Removing or renaming a column
- Changing a column's type
- Adding `NOT NULL` to an existing column without a default
- Dropping a table or constraint that existing code relies on

## When to Split or Merge Tables

**Split when:**

- A group of columns is nullable together (optional sub-entity)
- Different query patterns access disjoint column sets
- A table exceeds ~50 columns with clear logical boundaries

**Merge when:**

- Two tables are always queried together (1:1 with no independent access)
- The join cost is measurable and the combined table is reasonable width

---

# Concurrency

## Optimistic vs Pessimistic Locking

**The choice depends on the domain:**

| Approach    | How it works                                         | Best for                                              |
| ----------- | ---------------------------------------------------- | ----------------------------------------------------- |
| Optimistic  | Read version, check at write time, retry on conflict | Most web/API workloads. Low contention.               |
| Pessimistic | `SELECT ... FOR UPDATE` locks until commit           | Financial transactions, inventory, seat reservations. |

**Optimistic (version column):**

```sql
ALTER TABLE accounts ADD COLUMN version INT NOT NULL DEFAULT 0;

-- Read
SELECT id, balance, version FROM accounts WHERE id = 1;  -- version = 5

-- Update (retry if 0 rows affected)
UPDATE accounts
SET balance = balance - 100, version = version + 1
WHERE id = 1 AND version = 5;
```

**Pessimistic (row lock):**

```sql
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
COMMIT;
```

**Work-queue pattern** — grab an unlocked row without waiting:

```sql
SELECT * FROM jobs
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;
```

## Transaction Isolation Levels

| Level           | Sees concurrent commits? | Use when                                                    |
| --------------- | ------------------------ | ----------------------------------------------------------- |
| Read Committed  | Yes (per-statement)      | **Default.** Most OLTP workloads.                           |
| Repeatable Read | No                       | Reports and batch jobs needing a consistent snapshot.       |
| Serializable    | No                       | When correctness requires sequential execution. Must retry. |

Stick with **Read Committed** unless you have a specific reason. Serializable
adds 3-20% overhead versus Read Committed on typical workloads (higher under
heavy write contention). Must retry on serialization failures.

## MVCC Implications

- Readers never block writers, writers never block readers.
- Updates create new row versions. Dead tuples accumulate until VACUUM.
- Long-running transactions hold back vacuum. Keep transactions short.

---

# Naming Conventions

| Element      | Convention                           | Example                        |
| ------------ | ------------------------------------ | ------------------------------ |
| Tables       | Plural, snake_case                   | `order_items`, `user_accounts` |
| Columns      | snake_case, descriptive              | `created_at`, `total_amount`   |
| Primary keys | `id` (surrogate) or natural key name | `id`, `code`                   |
| Foreign keys | `<table_singular>_id`                | `order_id`, `customer_id`      |
| Constraints  | `<table>_<columns>_<type>`           | `orders_status_check`          |
| Indexes      | `idx_<table>_<columns>`              | `idx_orders_customer_id`       |

---

# Sources

- [Database Design for Mere Mortals][hernandez] — design methodology, entity
  design process, field specifications
- [Database Design and Relational Theory][date] — normalization theory, BCNF as
  practical target
- [The Art of PostgreSQL][fontaine] — practical Postgres schema patterns
- [Joe Celko's SQL for Smarties][celko] — advanced SQL patterns, normalization
- [Grokking Relational Database Design][grokking] — modern fundamentals
- [Brandur — postgres-practices][brandur] — NOT NULL by default, RESTRICT FKs,
  bigint IDs
- [use-the-index-luke.com][idx-luke] — composite index ordering (ESR rule)
- [PostgreSQL Wiki — Don't Do This][pg-dont] — data type recommendations
- [PostgreSQL Docs — Constraints][pg-constraints]
- [PostgreSQL Docs — Transaction Isolation][pg-iso]

[antipatterns]: ./sql-antipatterns.md
[pg-ref]: ./postgres.md
[sql-rules]: ../../shared/langs/sql.md
[hernandez]:
  https://www.oreilly.com/library/view/database-design-for/9780133122282/
[date]: https://link.springer.com/book/10.1007/978-1-4842-5540-7
[fontaine]: https://theartofpostgresql.com/
[celko]: https://www.oreilly.com/library/view/joe-celkos-sql/9780128007617/
[grokking]: https://www.manning.com/books/grokking-relational-database-design
[brandur]:
  https://github.com/brandur/postgres-practices/blob/master/practices.md
[idx-luke]:
  https://use-the-index-luke.com/sql/where-clause/the-equals-operator/concatenated-keys
[pg-dont]: https://wiki.postgresql.org/wiki/Don't_Do_This
[pg-constraints]: https://www.postgresql.org/docs/current/ddl-constraints.html
[pg-iso]: https://www.postgresql.org/docs/current/transaction-iso.html
[pgaudit]: https://www.pgaudit.org/
[pgstattuple]: https://www.postgresql.org/docs/current/pgstattuple.html
