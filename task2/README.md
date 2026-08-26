# Task 2 – Database Migration

## Overview

This task migrates the NimbusTech PostgreSQL database from **schema v1 to schema v2**.

The migration makes the following changes:

1. Adds a `user_tier` column to the `users` table.
2. Adds a `processed_at` column to the `orders` table.
3. Creates an index on `orders.created_at`.
4. Backfills `processed_at` for completed orders using `created_at + 2 hours`.

The migration is written using simple PostgreSQL SQL so it is easy to understand and review.

---

## Files

```text
task2-database-migration/
|
|-- migration_v1_to_v2.sql
|-- rollback_v2_to_v1.sql
|-- README.md
```

### `migration_v1_to_v2.sql`

This script performs the database migration and validation checks.

### `rollback_v2_to_v1.sqlsql`

This script removes the changes made by the migration.

---

## Changes Made

### 1. `users` table

Adds:

```sql
user_tier VARCHAR(50) DEFAULT 'free'
```

Existing users will have the default value:

```text
free
```

### 2. `orders` table

Adds:

```sql
processed_at TIMESTAMP NULL
```

This column is nullable because orders that are not completed may not have a processing time.

### 3. Index

Creates:

```text
idx_orders_created_at
```

on:

```text
orders(created_at)
```

### 4. Backfill

For completed orders:

```sql
processed_at = created_at + 2 hours
```

Only rows where `processed_at` is currently NULL are updated.

This makes the backfill safe to run again.

---

## Idempotency

The migration is designed to be safe to run more than once.

For example:

```sql
ADD COLUMN IF NOT EXISTS
```

prevents an error if the column already exists.

Similarly:

```sql
CREATE INDEX IF NOT EXISTS
```

prevents an error if the index already exists.

The backfill uses:

```sql
WHERE status = 'completed'
AND processed_at IS NULL
```

so already-processed rows are not updated again.

---

## How to Run

### Option 1 – Using `psql`

Set the database connection variables:

```bash
export PGHOST=<database-host>
export PGPORT=5432
export PGDATABASE=<database-name>
export PGUSER=<database-user>
export PGPASSWORD=<database-password>
```

Run the migration:

```bash
psql -f migration_v1_to_v2.sql
```

---

## Required Environment Variables

| Variable     | Description                      |
| ------------ | -------------------------------- |
| `PGHOST`     | PostgreSQL database hostname     |
| `PGPORT`     | PostgreSQL port, normally `5432` |
| `PGDATABASE` | Database name                    |
| `PGUSER`     | Database username                |
| `PGPASSWORD` | Database password                |

---

## Validation

The migration script includes basic validation checks.

It checks:

* `users.user_tier` exists
* `orders.processed_at` exists
* `idx_orders_created_at` exists
* Completed orders have been backfilled
* User row count
* Order row count

Example:

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name = 'user_tier';
```

---

## Rollback

If the migration needs to be reverted:

```bash
psql -f rollback.sql
```

The rollback removes:

* `users.user_tier`
* `orders.processed_at`
* `idx_orders_created_at`

The rollback script also performs validation checks.

### Important

The rollback removes the newly added columns and therefore removes the data stored in those columns.

The original `users` and `orders` data is not deleted.

---

## Estimated Runtime for 1 Million Orders

For a table containing approximately **1 million orders**, the migration should normally take **seconds to a few minutes**, depending on:

* Number of completed orders
* RDS instance size
* Existing database workload
* Disk performance
* Index creation time

I would test the migration against a production-sized copy of the database before running it in production.

For a large production database, I would also monitor locks, CPU, memory, I/O and transaction duration during the migration.

---

## Production Considerations

Before running the migration in production, I would:

1. Take/verify a recent RDS backup or snapshot.
2. Test the migration in a staging environment.
3. Check the number of completed orders that need backfilling.
4. Run the migration during a suitable maintenance window.
5. Monitor database CPU, memory, storage and connections.
6. Run the validation queries after completion.
7. Keep the rollback script available.

---

## Assumptions

* PostgreSQL is being used.
* The `users` table already exists.
* The `orders` table already exists.
* `orders` contains `created_at` and `status`.
* Existing `user_tier` values do not need to be migrated because this is a new column.
* `processed_at` should only be populated for completed orders.
