# PostgreSQL Reference

A reference for AI agents working with PostgreSQL. Covers Postgres-specific
features relevant to schema design and query writing.

**Version baseline:** PG 14 (minimum supported by major cloud providers as of
2026). Features available in PG 14 and below are unmarked. Newer features are
tagged with their version.

For general SQL rules, see [`shared/langs/sql.md`][sql-rules]. For antipatterns,
see [`sql-antipatterns.md`][antipatterns].

---

# Data Types

## Prefer TEXT over VARCHAR(n)

`TEXT` and `VARCHAR(n)` have identical performance in Postgres. `VARCHAR(n)`
adds a length check on every write with no storage benefit. Use `TEXT` by
default. Add a `CHECK (length(col) <= n)` only when the limit is a domain rule.

```sql
-- Avoid
name VARCHAR(255)

-- Prefer
name TEXT NOT NULL
-- or, when a domain limit matters:
name TEXT NOT NULL CHECK (length(name) <= 100)
```

## TIMESTAMPTZ, Not TIMESTAMP

Always use `TIMESTAMPTZ` for points in time. `TIMESTAMP` (without time zone)
stores the literal wall-clock value with no time zone context — it means
different instants depending on the reader's `timezone` setting.

```sql
-- Avoid
created_at TIMESTAMP DEFAULT now()

-- Prefer
created_at TIMESTAMPTZ NOT NULL DEFAULT now()
```

## UUID

Native 128-bit type. Use `gen_random_uuid()` (core since PG 13) for random
UUIDs. No extension needed.

```sql
CREATE TABLE users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT NOT NULL UNIQUE
);
```

## Range Types

Model continuous ranges (`int4range`, `daterange`, `tstzrange`, etc.) natively.
Support overlap (`&&`), containment (`@>`), and adjacency (`-|-`) operators.
Pair with exclusion constraints to prevent overlaps.

```sql
CREATE TABLE bookings (
  room_id INT NOT NULL REFERENCES rooms(id),
  during DATERANGE NOT NULL,
  EXCLUDE USING GIST (room_id WITH =, during WITH &&)
);

-- Find bookings overlapping a date range
SELECT * FROM bookings WHERE during && '[2024-06-01, 2024-06-07)';
```

## Multirange Types (PG 14)

A sorted set of non-overlapping ranges as a single value. Useful for
availability windows, schedules, and gaps.

```sql
SELECT '{[09:00, 12:00), [13:00, 17:00)}'::tsmultirange;
SELECT * FROM schedules WHERE free_slots @> '10:30'::time;
```

## Arrays

Any base type can be an array. GIN-indexable. Use for small, opaque lists where
the values are not FK-referenced. For queryable many-to-many relationships, use
a junction table instead.

```sql
CREATE TABLE articles (tags TEXT[]);
CREATE INDEX ON articles USING GIN (tags);
SELECT * FROM articles WHERE tags @> ARRAY['postgres'];
```

## Domain Types

Named alias over a base type with enforced CHECK constraints. Useful for domain
primitives (email, positive integer, currency code).

```sql
CREATE DOMAIN positive_int AS INT CHECK (VALUE > 0);
CREATE DOMAIN currency_code AS CHAR(3) CHECK (VALUE ~ '^[A-Z]{3}$');

CREATE TABLE products (
  price NUMERIC(12, 2) NOT NULL,
  qty positive_int NOT NULL,
  currency currency_code NOT NULL
);
```

## JSONB vs JSON

`JSONB` is binary, decomposed, and indexable (GIN). `JSON` stores raw text and
must be reparsed on every access. Always use `JSONB` unless you need to preserve
key order or whitespace (rare).

```sql
CREATE TABLE events (
  id SERIAL PRIMARY KEY,
  payload JSONB NOT NULL
);
CREATE INDEX ON events USING GIN (payload);

-- Containment query (uses GIN index)
SELECT * FROM events WHERE payload @> '{"type": "order.created"}';
```

### JSONB Subscript Syntax (PG 14)

Direct read/write access to nested keys without function calls.

```sql
-- Read
SELECT payload['customer']['email'] FROM events;

-- Write
UPDATE events SET payload['status'] = '"closed"' WHERE id = 1;
```

### SQL/JSON Path Language

Declarative queries inside JSON documents using SQL/JSON path expressions.

```sql
SELECT * FROM events
WHERE jsonb_path_exists(payload, '$.items[*] ? (@.price > 100)');
```

### JSON_TABLE (PG 17)

Shred a JSON document into rows and columns in a single declarative query.

```sql
SELECT jt.*
FROM orders,
  JSON_TABLE(line_items, '$[*]' COLUMNS (
    sku  TEXT PATH '$.sku',
    qty  INT  PATH '$.qty',
    price NUMERIC PATH '$.price'
  )) AS jt;
```

### SQL/JSON Constructors (PG 16)

Standard SQL syntax for constructing JSON values. Replaces `jsonb_build_object`
/ `jsonb_build_array` in new code.

```sql
SELECT JSON_OBJECT('id': id, 'name': name) FROM users;
SELECT JSON_ARRAYAGG(JSON_OBJECT('id': id, 'name': name)) FROM users;
```

### SQL/JSON Query Functions (PG 15)

Standard SQL functions for extracting values from JSON.

```sql
SELECT JSON_VALUE(payload, '$.status') FROM events;
SELECT JSON_QUERY(payload, '$.items') FROM events;
SELECT JSON_EXISTS(payload, '$.items[*] ? (@.price > 100)') FROM events;
```

---

# Constraints and Indexes

## Partial Indexes

Index only rows matching a WHERE predicate. Dramatically smaller and faster for
queries that filter on the same predicate.

```sql
-- Only index pending orders (the ones you query most)
CREATE INDEX ON orders (created_at) WHERE status = 'pending';

-- Enforce uniqueness only for non-deleted rows
CREATE UNIQUE INDEX ON users (email) WHERE deleted_at IS NULL;
```

## Expression Indexes

Index on a computed expression. Enables index scans on transformed columns.

```sql
CREATE INDEX ON users (lower(email));
SELECT * FROM users WHERE lower(email) = 'alice@example.com';
```

## Exclusion Constraints

Generalized unique constraints using arbitrary operators. Essential for range
types (preventing overlapping bookings, schedules, etc.).

```sql
-- Requires btree_gist extension for combining = with &&
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE reservations (
  room_id INT NOT NULL,
  during TSTZRANGE NOT NULL,
  EXCLUDE USING GIST (room_id WITH =, during WITH &&)
);
```

## INCLUDE Columns

Add non-key columns to a B-tree index for index-only scans without widening the
key. Verify with `EXPLAIN` (look for "Index Only Scan").

```sql
CREATE INDEX ON orders (customer_id, created_at) INCLUDE (status, total);
-- Covers: SELECT status, total FROM orders WHERE customer_id = ? ORDER BY created_at
```

## GIN Indexes

Inverted index for multi-valued types: arrays, JSONB, tsvector, pg_trgm
trigrams. Fast for containment queries (`@>`, `@@`).

```sql
CREATE INDEX ON events USING GIN (payload);         -- JSONB
CREATE INDEX ON articles USING GIN (tags);           -- array
CREATE INDEX ON docs USING GIN (search_vector);      -- tsvector
CREATE INDEX ON products USING GIN (name gin_trgm_ops);  -- trigram
```

## GiST Indexes

Generalized Search Tree for ranges, geometry, ltree, and full-text search.
Supports exclusion constraints.

```sql
CREATE INDEX ON bookings USING GIST (during);        -- range type
CREATE INDEX ON categories USING GIST (path);         -- ltree
```

---

# DDL Features

## Identity Columns

SQL-standard auto-increment. Replaces `SERIAL`. The sequence is owned by the
column and drops with it.

```sql
CREATE TABLE items (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL
);
-- Use GENERATED BY DEFAULT for cases needing explicit ID insertion (e.g., data migration)
```

## Generated Columns

Stored computed columns. The value is always derived from other columns.

```sql
CREATE TABLE products (
  price NUMERIC(12, 2) NOT NULL,
  tax_rate NUMERIC(4, 3) NOT NULL DEFAULT 0.1,
  tax NUMERIC(12, 2) GENERATED ALWAYS AS (price * tax_rate) STORED
);
```

## Declarative Partitioning

Native range, list, and hash partitioning. No triggers needed. Partition pruning
is automatic.

```sql
CREATE TABLE logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  ts TIMESTAMPTZ NOT NULL,
  msg TEXT NOT NULL
) PARTITION BY RANGE (ts);

CREATE TABLE logs_2024 PARTITION OF logs
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE logs_2025 PARTITION OF logs
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Default partition catches rows that don't match any range
CREATE TABLE logs_default PARTITION OF logs DEFAULT;
```

## MERGE (PG 15)

Single statement that conditionally INSERTs, UPDATEs, or DELETEs based on a
source table join. More expressive than `ON CONFLICT` for complex upsert logic.

```sql
MERGE INTO inventory AS t
USING incoming AS s ON t.sku = s.sku
WHEN MATCHED AND s.qty = 0 THEN DELETE
WHEN MATCHED THEN UPDATE SET qty = t.qty + s.qty
WHEN NOT MATCHED THEN INSERT (sku, qty) VALUES (s.sku, s.qty);
```

## INSERT ... ON CONFLICT (UPSERT)

Atomic upsert for simple conflict resolution on a unique constraint.

```sql
INSERT INTO counters (key, val) VALUES ('hits', 1)
ON CONFLICT (key) DO UPDATE SET val = counters.val + EXCLUDED.val;

-- DO NOTHING variant (skip duplicates silently)
INSERT INTO tags (name) VALUES ('postgres')
ON CONFLICT (name) DO NOTHING;
```

---

# Full-Text Search

Postgres has built-in full-text search. No extension needed.

```sql
-- Add a generated tsvector column
ALTER TABLE articles ADD COLUMN search_vector TSVECTOR
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
  ) STORED;

-- GIN index for fast search
CREATE INDEX ON articles USING GIN (search_vector);

-- Query with ranking
SELECT title, ts_rank(search_vector, query) AS rank
FROM articles, to_tsquery('english', 'postgres & performance') query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

For fuzzy/typo-tolerant search, combine with `pg_trgm`. For faceted search,
autocomplete, or multi-language needs, use a dedicated search engine
([Meilisearch][meilisearch], Typesense, Elasticsearch).

---

# Row-Level Security

Per-row access control enforced inside the database engine. Useful for
multi-tenant applications.

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Tenants see only their own rows
CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.tenant_id')::INT);

-- Application sets the tenant context per connection
SET app.tenant_id = '42';
SELECT * FROM orders;  -- only sees tenant 42's orders
```

RLS policies are enforced even for direct SQL access, making them a defense
layer beyond application code. Table owners bypass RLS by default — use
`FORCE ROW LEVEL SECURITY` to enforce on owners too.

---

# Advisory Locks

Application-managed cooperative locks. Two flavors: session-scoped (held until
explicitly released or session ends) and transaction-scoped (released at
commit/rollback).

```sql
-- Session-scoped (non-blocking attempt)
SELECT pg_try_advisory_lock(hashtext('process-payments'));
-- ... critical section ...
SELECT pg_advisory_unlock(hashtext('process-payments'));

-- Transaction-scoped (auto-released at commit)
SELECT pg_advisory_xact_lock(hashtext('import-batch-42'));
```

Use case: distributed cron (ensure only one worker runs a job), idempotent event
processing, rate limiting.

---

# LISTEN / NOTIFY

Lightweight pub/sub over a database connection. Payload support allows passing
structured data.

```sql
-- Publisher (in a trigger or application)
NOTIFY job_queue, '{"job_id": 99, "type": "email"}';

-- Subscriber (separate connection)
LISTEN job_queue;
-- Application calls connection.poll() or equivalent to receive notifications
```

Use for light fan-out (job queues, cache invalidation). For high-throughput
messaging, use a dedicated message broker (NATS, RabbitMQ).

---

# Extensions

## pgcrypto

Cryptographic functions. Use for password hashing and random token generation.

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- bcrypt hash (for password storage)
SELECT crypt('user_password', gen_salt('bf'));

-- Verify password
SELECT crypt('user_input', stored_hash) = stored_hash;

-- Random hex token
SELECT encode(gen_random_bytes(32), 'hex');
```

## pg_trgm

Trigram-based similarity search. Enables fast `LIKE`/`ILIKE` queries and fuzzy
matching via GIN or GiST indexes.

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX ON products USING GIN (name gin_trgm_ops);

-- Fast ILIKE (uses the GIN index)
SELECT * FROM products WHERE name ILIKE '%postg%';

-- Similarity search
SELECT name, similarity(name, 'postgress') AS sim
FROM products WHERE name % 'postgress'
ORDER BY sim DESC;
```

## ltree

Hierarchical label paths with fast ancestor/descendant queries. Alternative to
adjacency list for tree structures.

```sql
CREATE EXTENSION IF NOT EXISTS ltree;

CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  path LTREE NOT NULL
);
CREATE INDEX ON categories USING GIST (path);

INSERT INTO categories (path) VALUES
  ('electronics'),
  ('electronics.computers'),
  ('electronics.computers.laptops');

-- All descendants of electronics
SELECT * FROM categories WHERE path <@ 'electronics';

-- Direct children only
SELECT * FROM categories WHERE path ~ 'electronics.*{1}';
```

## citext

Case-insensitive text type. Comparisons and uniqueness are case-insensitive
without needing expression indexes or `lower()` calls.

```sql
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  email CITEXT NOT NULL UNIQUE
);

INSERT INTO users (email) VALUES ('Alice@Example.com');
SELECT * FROM users WHERE email = 'alice@example.com';  -- matches
```

## btree_gist

Adds B-tree-equivalent operator classes to GiST. Required for exclusion
constraints that combine equality (`=`) with range overlap (`&&`).

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Now you can use = in a GiST exclusion constraint
EXCLUDE USING GIST (room_id WITH =, during WITH &&)
```

---

# Version Reference

Features introduced after the PG 14 baseline, for quick lookup.

| Feature                   | Version |
| ------------------------- | ------- |
| `MERGE` statement         | PG 15   |
| SQL/JSON query functions  | PG 15   |
| SQL/JSON constructors     | PG 16   |
| `IS JSON` predicate       | PG 16   |
| `JSON_TABLE`              | PG 17   |
| Virtual generated columns | PG 18   |
| Async I/O (`io_uring`)    | PG 18   |

[sql-rules]: ../../shared/langs/sql.md
[antipatterns]: ./sql-antipatterns.md
[meilisearch]: https://www.meilisearch.com/
