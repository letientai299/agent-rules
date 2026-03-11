# SQL Antipatterns Reference

A reference for AI agents working on relational schema design and SQL queries.
Based on [SQL Antipatterns][vol1] and [More SQL Antipatterns][vol2] by Bill
Karwin, plus community sources.

For the enforceable rules derived from this reference, see
[`shared/langs/sql.md`][sql-rules].

---

# Schema Design

## 1. Jaywalking (Comma-Separated Lists)

Storing multi-valued attributes as delimited strings. Prevents joins, indexing,
referential integrity, and accurate counting.

```sql
-- Antipattern
CREATE TABLE articles (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  tags TEXT  -- 'python,sql,go'
);

-- Querying is painful and error-prone
SELECT * FROM articles WHERE tags LIKE '%sql%';
-- Matches 'nosql', 'mysql', etc.

-- Correct: junction table
CREATE TABLE tags (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE article_tags (
  article_id INT NOT NULL REFERENCES articles(id),
  tag_id INT NOT NULL REFERENCES tags(id),
  PRIMARY KEY (article_id, tag_id)
);

-- Clean query
SELECT a.* FROM articles a
  JOIN article_tags at ON a.id = at.article_id
  JOIN tags t ON at.tag_id = t.id
WHERE t.name = 'sql';
```

Use Postgres arrays or JSONB only when the values are opaque to queries — no
filtering, no joining, no referential integrity needed.

## 2. Entity-Attribute-Value (EAV)

A generic three-column table (`entity_id`, `attribute_name`, `attribute_value`)
for variable attributes. Loses type safety (everything is text), referential
integrity, and makes aggregation queries painful.

```sql
-- Antipattern
CREATE TABLE properties (
  entity_id INT NOT NULL,
  attr_name TEXT NOT NULL,
  attr_value TEXT,  -- everything is text: dates, numbers, booleans
  PRIMARY KEY (entity_id, attr_name)
);

-- Querying requires pivot/crosstab:
SELECT entity_id,
  MAX(CASE WHEN attr_name = 'weight' THEN attr_value END) AS weight,
  MAX(CASE WHEN attr_name = 'color' THEN attr_value END) AS color
FROM properties GROUP BY entity_id;

-- Correct: class table inheritance
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  price NUMERIC(12, 2) NOT NULL
);

CREATE TABLE books (
  product_id INT PRIMARY KEY REFERENCES products(id),
  isbn TEXT NOT NULL UNIQUE,
  page_count INT NOT NULL CHECK (page_count > 0)
);

CREATE TABLE electronics (
  product_id INT PRIMARY KEY REFERENCES products(id),
  wattage NUMERIC NOT NULL,
  voltage NUMERIC NOT NULL
);
```

EAV is acceptable only for genuinely user-defined attributes where the schema
cannot be known at design time (e.g., custom form fields). Even then, JSONB with
validation is usually better.

## 3. Polymorphic Associations

A foreign key column that references different parent tables depending on a
companion `type` column. The database cannot enforce referential integrity — the
FK can point to a nonexistent row in the wrong table.

```sql
-- Antipattern (Rails/Django convention)
CREATE TABLE comments (
  id SERIAL PRIMARY KEY,
  body TEXT NOT NULL,
  commentable_id INT NOT NULL,
  commentable_type TEXT NOT NULL  -- 'Post', 'Photo', 'Video'
);
-- No FK constraint possible — commentable_id could be anything

-- Correct: exclusive arc
CREATE TABLE comments (
  id SERIAL PRIMARY KEY,
  body TEXT NOT NULL,
  post_id INT REFERENCES posts(id) ON DELETE CASCADE,
  photo_id INT REFERENCES photos(id) ON DELETE CASCADE,
  video_id INT REFERENCES videos(id) ON DELETE CASCADE,
  CHECK (num_nonnulls(post_id, photo_id, video_id) = 1)
);

-- Alternative: shared parent table
CREATE TABLE commentables (
  id SERIAL PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('post', 'photo', 'video'))
);
-- posts, photos, videos each have commentable_id FK to commentables
-- comments has commentable_id FK to commentables
```

The exclusive arc pattern scales to ~5 targets. Beyond that, use a shared parent
table or separate association tables per target type.

## 4. Multicolumn Attributes

Numbered columns for the same concept. Adding a fourth value requires a schema
migration. Querying "any value matching X" requires ORing across all columns.

```sql
-- Antipattern
CREATE TABLE contacts (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  phone1 TEXT,
  phone2 TEXT,
  phone3 TEXT
);

-- Querying is verbose and fragile
SELECT * FROM contacts
WHERE phone1 = '555-1234' OR phone2 = '555-1234' OR phone3 = '555-1234';

-- Correct: dependent table
CREATE TABLE contact_phones (
  contact_id INT NOT NULL REFERENCES contacts(id),
  phone TEXT NOT NULL,
  label TEXT NOT NULL CHECK (label IN ('home', 'work', 'mobile')),
  PRIMARY KEY (contact_id, phone)
);
```

## 5. Metadata Tribbles (Clone Tables)

Per-partition tables or columns for scalability (`orders_2024`, `orders_2025`).
Queries spanning partitions require UNION ALL. Constraints and indexes must be
duplicated across every clone.

```sql
-- Antipattern
CREATE TABLE orders_2024 ( ... );
CREATE TABLE orders_2025 ( ... );
-- Every query needs UNION ALL, every index is duplicated

-- Correct: native partitioning
CREATE TABLE orders (
  id SERIAL,
  created_at TIMESTAMPTZ NOT NULL,
  ...
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024 PARTITION OF orders
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE orders_2025 PARTITION OF orders
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
```

## 6. Naive Trees (Adjacency List Only)

Modeling hierarchical data with only `parent_id`. Querying ancestors,
descendants, or depth requires recursive CTEs or multiple round trips.

```sql
-- Adjacency list (simple but limited)
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  parent_id INT REFERENCES categories(id)
);

-- Getting all descendants requires recursive CTE
WITH RECURSIVE tree AS (
  SELECT id, name, 0 AS depth FROM categories WHERE id = 1
  UNION ALL
  SELECT c.id, c.name, t.depth + 1
  FROM categories c JOIN tree t ON c.parent_id = t.id
)
SELECT * FROM tree;
```

**Alternatives by use case:**

| Model                          | Strengths                         | Weaknesses                     |
| ------------------------------ | --------------------------------- | ------------------------------ |
| Adjacency list                 | Simple writes, easy to understand | Recursive reads, depth is O(n) |
| [Closure table][closure-table] | Fast reads, supports DAGs         | Extra table, O(n^2) space      |
| Materialized path              | Fast subtree queries, sortable    | Fragile on moves, string ops   |
| Nested sets                    | Fast reads, no recursion          | Expensive writes, renumbering  |

Adjacency list + recursive CTEs is fine for shallow trees (depth < 10) with
infrequent subtree queries. For deep or frequently-queried hierarchies, evaluate
the alternatives.

## 7. ID Required (Surrogate Key Everywhere)

Adding `id SERIAL PRIMARY KEY` to every table, including junction tables and
tables with natural keys.

```sql
-- Antipattern: useless surrogate on junction table
CREATE TABLE user_roles (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id),
  role_id INT NOT NULL REFERENCES roles(id),
  UNIQUE (user_id, role_id)  -- the real key
);

-- Correct: composite PK
CREATE TABLE user_roles (
  user_id INT NOT NULL REFERENCES users(id),
  role_id INT NOT NULL REFERENCES roles(id),
  PRIMARY KEY (user_id, role_id)
);

-- Natural key example
CREATE TABLE currencies (
  code CHAR(3) PRIMARY KEY,  -- 'USD', 'EUR' — stable, compact, meaningful
  name TEXT NOT NULL
);
```

Use composite PKs for junction tables. Use natural keys when stable and compact
(ISO codes, currency codes, language tags). Reserve surrogates for entities with
no stable natural identifier.

## 8. Keyless Entry (Missing Constraints)

Omitting foreign keys, CHECK constraints, NOT NULL, and unique constraints.
Referential integrity is "enforced" only by application code.

```sql
-- Antipattern: no constraints
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INT,        -- nullable, no FK
  status TEXT,        -- no CHECK
  amount NUMERIC      -- could be negative, null
);

-- Correct: constrained
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id),
  status TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'shipped')),
  amount NUMERIC(12, 2) NOT NULL CONSTRAINT amount_positive CHECK (amount > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Every relationship gets a FK. Every domain invariant expressible as a boolean
gets a CHECK. Every required column gets NOT NULL.

## 9. FLOAT for Money

IEEE 754 binary floating-point cannot represent decimal fractions exactly.
`0.1 + 0.2 = 0.30000000000000004`. Rounding errors accumulate in aggregations.

```sql
-- Antipattern
price FLOAT NOT NULL  -- 19.99 + 20.01 might not equal 40.00

-- Correct: exact decimal
price NUMERIC(12, 2) NOT NULL

-- Alternative: integer minor units
price_cents INT NOT NULL  -- 1999 = $19.99
```

## 10. Text + CHECK over Enum Types

Postgres `CREATE TYPE ... AS ENUM` values cannot be removed. Adding a value
requires `ALTER TYPE ... ADD VALUE`, and the new value cannot be used in the
same transaction. Renaming requires dropping and recreating.

```sql
-- Antipattern
CREATE TYPE order_status AS ENUM ('pending', 'shipped', 'delivered');
-- Can never remove 'shipped'. Adding requires DDL on the enum type
-- and the new value cannot be used in the same transaction.

-- Correct: text + CHECK
status TEXT NOT NULL CHECK (status IN ('pending', 'shipped', 'delivered'))
-- Adding: ALTER TABLE DROP CONSTRAINT ...; ALTER TABLE ADD CONSTRAINT ...;
-- Lightweight, no table rewrite.
```

Use enums only for sets that are small (< 25 values), permanently stable, and
where deletion will never be needed.

## 11. Boolean Flags for Mutually Exclusive States

Multiple booleans allow impossible combinations and hide state transitions.

```sql
-- Antipattern
is_pending BOOLEAN DEFAULT true,
is_approved BOOLEAN DEFAULT false,
is_rejected BOOLEAN DEFAULT false
-- What does is_pending=true, is_approved=true mean?

-- Correct: single status column
status TEXT NOT NULL DEFAULT 'pending'
  CHECK (status IN ('pending', 'approved', 'rejected'))

-- When you need temporal context:
approved_at TIMESTAMPTZ,
rejected_at TIMESTAMPTZ,
CHECK (num_nonnulls(approved_at, rejected_at) <= 1)
```

## 12. JSONB as Schema Avoidance

Storing queryable, structured data in JSONB to avoid schema design effort.

```sql
-- Antipattern
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  data JSONB NOT NULL  -- everything in one blob
);
-- WHERE data->>'email' = ? — no type safety, no FK, no unique constraint

-- Correct: columns for structured data, JSONB for opaque data
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  preferences JSONB  -- genuinely schemaless: UI settings, feature flags
);
```

Rule of thumb: if you query or filter on a JSON field regularly, it should be a
column. If JSON contains arrays you join against, they should be a table.

## 13. Soft Delete Without Mitigation

`deleted_at` columns break FK integrity, require `WHERE deleted_at IS NULL` on
every query, and conflict with unique constraints.

```sql
-- Antipattern: naive soft delete
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;
-- Unique email constraint now allows duplicate emails if one is "deleted"
-- FKs from orders still reference soft-deleted users
-- Every query must filter: WHERE deleted_at IS NULL

-- If soft delete is required, mitigate:
CREATE UNIQUE INDEX users_email_active
  ON users (email) WHERE deleted_at IS NULL;

-- Preferred: hard delete + archive
CREATE TABLE deleted_records (
  id SERIAL PRIMARY KEY,
  table_name TEXT NOT NULL,
  record_id INT NOT NULL,
  data JSONB NOT NULL,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 14. Premature Denormalization

Duplicating data across tables "for performance" before proving a JOIN is the
bottleneck.

```sql
-- Antipattern: denormalized for "speed"
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id),
  user_email TEXT NOT NULL,  -- copied from users
  user_name TEXT NOT NULL    -- copied from users
);
-- When user updates email, orders table is stale.

-- Correct: JOIN when needed
SELECT o.*, u.email, u.name
FROM orders o JOIN users u ON o.user_id = u.id;
```

Denormalize only when profiling under realistic load proves a specific JOIN is
the bottleneck. Document the trade-off and the consistency mechanism (trigger,
materialized view, or application-level sync).

---

# Query Patterns

## 15. SELECT \*

Returns unnecessary columns, prevents covering-index optimizations, breaks when
columns are added/removed, transfers excess data.

```sql
-- Antipattern
SELECT * FROM users WHERE id = 1;

-- Correct
SELECT id, email, name, created_at FROM users WHERE id = 1;
```

`SELECT *` is fine in ad-hoc/interactive queries. In application code, always
list columns explicitly.

## 16. Non-Sargable Predicates

Wrapping indexed columns in functions. The optimizer cannot use the index.

```sql
-- Antipattern (full table scan even with index on created_at)
WHERE YEAR(created_at) = 2024
WHERE LOWER(email) = 'user@example.com'
WHERE amount + tax > 100

-- Correct: range predicate (uses index)
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'

-- Correct: expression index (if the function is unavoidable)
CREATE INDEX idx_users_email_lower ON users (LOWER(email));
WHERE LOWER(email) = 'user@example.com'  -- now uses the index

-- Correct: isolate the column
WHERE amount > 100 - tax
```

**Sargable** = Search ARGument ABLE. A predicate is sargable when the indexed
column stands alone on one side of the comparison operator.

## 17. Implicit Type Coercion

Comparing columns against values of a different type. The database casts the
column (not the literal), preventing index usage.

```sql
-- Antipattern (varchar column compared to integer)
WHERE phone_number = 5551234
-- DB casts every row: CAST(phone_number AS INTEGER) = 5551234 → full scan

-- Correct: match the type
WHERE phone_number = '5551234'
```

## 18. N+1 Queries

Fetching parent rows, then issuing one query per row for related children.

```python
# Antipattern (pseudocode)
users = db.query("SELECT * FROM users LIMIT 100")
for user in users:
    orders = db.query("SELECT * FROM orders WHERE user_id = ?", user.id)
# 1 + 100 = 101 queries

# Correct: single JOIN
results = db.query("""
  SELECT u.id, u.name, o.id AS order_id, o.total
  FROM users u LEFT JOIN orders o ON u.id = o.user_id
  LIMIT 100
""")

# Alternative: batch IN
user_ids = [u.id for u in users]
orders = db.query("SELECT * FROM orders WHERE user_id = ANY(?)", user_ids)
```

## 19. Spaghetti Query

One massive query with many JOINs, subqueries, and CASE expressions for
unrelated aggregations. Produces accidental Cartesian products.

```sql
-- Antipattern: one query for the entire dashboard
SELECT
  COUNT(DISTINCT o.id) AS total_orders,
  SUM(o.amount) AS revenue,
  COUNT(DISTINCT u.id) AS active_users,
  AVG(r.rating) AS avg_rating,
  ...
FROM orders o
  JOIN users u ON ...
  JOIN reviews r ON ...
  JOIN products p ON ...
WHERE ...;
-- Cartesian product between unrelated aggregations → wrong numbers

-- Correct: separate focused queries
SELECT COUNT(*) AS total_orders, SUM(amount) AS revenue FROM orders WHERE ...;
SELECT COUNT(DISTINCT user_id) AS active_users FROM orders WHERE ...;
SELECT AVG(rating) AS avg_rating FROM reviews WHERE ...;
```

## 20. DISTINCT to Mask Bad Joins

Adding DISTINCT to suppress duplicates caused by incorrect or missing join
conditions.

```sql
-- Antipattern: DISTINCT hides the real problem
SELECT DISTINCT u.id, u.name
FROM users u
  JOIN orders o ON u.id = o.user_id
  JOIN order_items oi ON o.id = oi.order_id;
-- Duplicates because the JOIN is 1:many — DISTINCT papers over it

-- Correct: fix the query to return what you actually need
SELECT u.id, u.name
FROM users u
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);
```

If a query needs DISTINCT, first verify the join conditions are correct.
DISTINCT is a code smell in application queries.

## 21. UNION Instead of UNION ALL

`UNION` deduplicates via sort. `UNION ALL` skips the sort.

```sql
-- Antipattern: unnecessary deduplication
SELECT id, name FROM active_products
UNION
SELECT id, name FROM archived_products;
-- Sorts the full result set to remove duplicates that cannot exist

-- Correct: skip the sort
SELECT id, name FROM active_products
UNION ALL
SELECT id, name FROM archived_products;
```

Default to `UNION ALL`. Use `UNION` only when you specifically need
deduplication and understand the sort cost.

## 22. Scalar Subqueries per Row

A correlated subquery in the SELECT list executes once per row of the outer
query.

```sql
-- Antipattern
SELECT
  o.id,
  o.total,
  (SELECT name FROM users WHERE id = o.user_id) AS user_name,
  (SELECT COUNT(*) FROM order_items WHERE order_id = o.id) AS item_count
FROM orders o;
-- 2 subqueries × N rows = 2N extra queries

-- Correct: JOIN + aggregate
SELECT o.id, o.total, u.name AS user_name, COUNT(oi.id) AS item_count
FROM orders o
  JOIN users u ON o.user_id = u.id
  LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.total, u.name;
```

## 23. Row-by-Row Processing (Cursors)

Using database cursors or application-side loops for bulk operations.

```sql
-- Antipattern (PL/pgSQL)
FOR rec IN SELECT id FROM orders WHERE status = 'pending' LOOP
  UPDATE orders SET status = 'expired'
    WHERE id = rec.id AND created_at < now() - interval '30 days';
END LOOP;

-- Correct: single set-based UPDATE
UPDATE orders SET status = 'expired'
WHERE status = 'pending' AND created_at < now() - interval '30 days';
```

## 24. LIKE '%term%' for Search

Leading wildcard prevents index usage. No ranking, stemming, or tokenization.

```sql
-- Antipattern (full table scan, no ranking)
SELECT * FROM articles WHERE body LIKE '%database%';

-- Correct: Postgres full-text search
ALTER TABLE articles ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (to_tsvector('english', title || ' ' || body)) STORED;

CREATE INDEX idx_articles_search ON articles USING GIN (search_vector);

SELECT *, ts_rank(search_vector, query) AS rank
FROM articles, to_tsquery('english', 'database') query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

For complex search (facets, typo tolerance, multi-language), use a dedicated
search engine ([Meilisearch][meilisearch], Typesense, Elasticsearch).

---

# Indexing

## 25. Index Shotgun (No Strategy)

Either no indexes beyond the PK, or indexes on every column "just in case."
Missing indexes cause slow reads. Excess indexes slow writes, waste storage, and
confuse the planner.

```sql
-- Antipattern: one index per column
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_name ON users (name);
CREATE INDEX idx_users_created ON users (created_at);
CREATE INDEX idx_users_status ON users (status);
-- A query filtering on (status, created_at) cannot use separate indexes well

-- Correct: index based on query patterns
CREATE INDEX idx_users_status_created ON users (status, created_at);
```

Use `EXPLAIN ANALYZE` to verify index usage. Remove unused indexes periodically
(`pg_stat_user_indexes.idx_scan = 0`).

## 26. Wrong Composite Index Column Order

An index on `(A, B, C)` serves queries on `A`, `A+B`, or `A+B+C`, but not
queries on `B` or `C` alone (leftmost prefix rule).

```sql
-- Antipattern: index matches table order, not query order
CREATE INDEX idx ON orders (id, status, created_at);
-- Cannot serve: WHERE status = 'pending' AND created_at > '2024-01-01'

-- Correct: equality columns first, then range
CREATE INDEX idx ON orders (status, created_at);
-- Serves: WHERE status = 'pending' AND created_at > '2024-01-01'
```

**Column order rule:** equality columns first (highest cardinality first among
equals), then range/sort columns last.

## 27. Missing Covering Indexes

The query uses an index to find rows, then performs a heap fetch for additional
columns (table lookup).

```sql
-- Query
SELECT email, name FROM users WHERE status = 'active' ORDER BY created_at;

-- Index that requires heap fetch
CREATE INDEX idx ON users (status, created_at);
-- Finds rows fast, but must visit the table for email and name

-- Covering index: index-only scan
CREATE INDEX idx ON users (status, created_at) INCLUDE (email, name);
-- All data comes from the index — no heap fetch
```

Use covering indexes for frequently-executed, read-heavy queries. Verify with
`EXPLAIN` (look for "Index Only Scan").

---

# Application Layer

## 28. NULL Mishandling (Three-Valued Logic)

SQL uses three-valued logic: TRUE, FALSE, NULL. Any comparison with NULL yields
NULL (not TRUE or FALSE).

```sql
-- Antipattern: assumes two-valued logic
SELECT * FROM users WHERE status != 'active';
-- Silently EXCLUDES rows where status IS NULL

-- Correct: explicit NULL handling
SELECT * FROM users WHERE status != 'active' OR status IS NULL;
-- Or: SELECT * FROM users WHERE status IS DISTINCT FROM 'active';

-- Common pitfalls:
NULL = NULL   → NULL (not TRUE)
NULL != NULL  → NULL (not TRUE)
NULL AND TRUE → NULL
NULL OR TRUE  → TRUE
'hello' || NULL → NULL (in standard SQL; Postgres follows this)
```

Use `IS NULL` / `IS NOT NULL` for null checks. Use `COALESCE` for defaults.
Apply `NOT NULL` on columns that must always have a value.

## 29. Ambiguous GROUP BY

Selecting non-aggregated columns not in GROUP BY. MySQL permissive mode returns
arbitrary values. Postgres rejects it.

```sql
-- Antipattern (works in MySQL permissive mode, fails in Postgres)
SELECT user_id, email, COUNT(*) AS order_count
FROM orders JOIN users ON orders.user_id = users.id
GROUP BY user_id;
-- email is not in GROUP BY and not aggregated

-- Correct
SELECT u.id, u.email, COUNT(*) AS order_count
FROM orders o JOIN users u ON o.user_id = u.id
GROUP BY u.id, u.email;
```

Every column in SELECT must be in GROUP BY or wrapped in an aggregate function.

## 30. Long Transactions

Opening a transaction, waiting for user input or external API calls, then
committing. Holds locks for the entire duration.

```python
# Antipattern
with db.transaction():
    order = db.query("SELECT * FROM orders WHERE id = ? FOR UPDATE", order_id)
    payment = stripe.charge(order.amount)  # External API call — seconds/minutes
    db.execute("UPDATE orders SET status = 'paid' WHERE id = ?", order_id)
# Lock held during the entire Stripe call

# Correct: minimize transaction scope
order = db.query("SELECT * FROM orders WHERE id = ?", order_id)
payment = stripe.charge(order.amount)  # Outside transaction
with db.transaction():
    db.execute("""
      UPDATE orders SET status = 'paid', version = version + 1
      WHERE id = ? AND version = ?
    """, order_id, order.version)  # Optimistic concurrency
```

## 31. Polling Instead of Notification

Repeatedly querying for changes instead of using event-driven mechanisms.

```python
# Antipattern
while True:
    new_rows = db.query("SELECT * FROM jobs WHERE status = 'pending'")
    for row in new_rows:
        process(row)
    time.sleep(1)  # Wasted queries when no new data

# Correct: PostgreSQL LISTEN/NOTIFY
db.execute("LISTEN new_job")
while True:
    if db.wait_for_notify(timeout=30):
        # Process only when notified
        new_rows = db.query("SELECT * FROM jobs WHERE status = 'pending'")
```

For higher throughput, use a message queue (NATS, RabbitMQ) or change data
capture (Debezium).

---

# Sources

- [SQL Antipatterns, Volume 1][vol1] — Bill Karwin, Pragmatic Programmers
  (2010). Covers Jaywalking, EAV, Polymorphic Associations, Multicolumn
  Attributes, Metadata Tribbles, Naive Trees, ID Required, Keyless Entry, FLOAT
  for Money, Readable Passwords, SQL Injection, Pseudokey Neat-Freak, Diplomatic
  Immunity, Ambiguous GROUP BY, HAVING misuse, and more.
- [More SQL Antipatterns][vol2] — Bill Karwin, Pragmatic Programmers (2026).
  Covers Fear of JOINs, Premature Denormalization, JSON Matryoshka Dolls,
  Polling, Poor Man's Search Engine, and 9 additional patterns.
- [SQL Anti-Patterns summary][github-boralp] — community cheat sheet
- [SQL Anti-Patterns and How to Fix Them][slicker] — concise examples
- [MENTOR mnemonic for indexing][mentor] — Measure, Explain, Nominate, Test,
  Optimize, Rebuild

[vol1]: https://pragprog.com/titles/bksap1/sql-antipatterns-volume-1/
[vol2]: https://pragprog.com/titles/bksap2/more-sql-antipatterns/
[closure-table]:
  https://en.wikipedia.org/wiki/Closure_table
[mentor]:
  https://www.oreilly.com/library/view/sql-antipatterns-volume/9798888650011/f_0096.xhtml
[github-boralp]: https://github.com/boralp/sql-anti-patterns
[slicker]: https://slicker.me/sql/antipatterns.htm
[meilisearch]: https://www.meilisearch.com/
[sql-rules]: ../../shared/langs/sql.md
