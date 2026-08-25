# Task 2 — Database Migration

## Changes

1. `users.user_tier VARCHAR DEFAULT 'free'`
2. `orders.processed_at TIMESTAMP NULL`
3. `idx_orders_created_at` on `orders(created_at)`
4. Backfill `processed_at = created_at + 2 hours` for completed orders where the new column is NULL.

The scripts use `IF NOT EXISTS` / `IF EXISTS`, so repeating the migration or rollback is safe. The backfill deliberately updates only NULL values so a rerun does not overwrite an existing value.

## Run

```bash
export PGHOST='your-rds-endpoint'
export PGPORT='5432'
export PGDATABASE='nimbus'
export PGUSER='migration_user'
export PGPASSWORD='use-a-secret-manager-or-secure-shell'

psql "sslmode=require" -f migrate_v1_to_v2.sql
# If an approved rollback is required:
psql "sslmode=require" -f rollback_v2_to_v1.sql
```

Do not commit credentials. In a production pipeline, retrieve the password from Secrets Manager or another approved secret store.

## Validation

The migration records users/orders row counts before the change, verifies both columns and the index exist, and verifies that every completed order has a non-NULL `processed_at` after the backfill. The rollback verifies that the v2 columns/index no longer exist.

## Runtime estimate for 1M orders

For 1M rows, a reasonable planning estimate is **1–5 minutes** on a healthy `db.t3.medium`-class environment, but this is not a guarantee. The index build, table bloat, storage performance, concurrent traffic, row width, and percentage of completed orders can materially change the runtime. Measure the migration on a production-like clone and use the result for the change window.

For a busy production table, I would consider `CREATE INDEX CONCURRENTLY` (which requires running outside the transaction), batch the backfill, monitor locks/CPU/IOPS, and define a rollback/change-failure threshold before the change window.
