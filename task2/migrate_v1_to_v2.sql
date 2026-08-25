-- NimbusTech PostgreSQL v1 -> v2 migration
-- Safe to run repeatedly. Run with a role that can ALTER TABLE and CREATE INDEX.
-- Recommended: execute against a restored staging clone before production.

BEGIN;

-- Pre-validation: row counts must not change because this migration is schema/data-backfill only.
CREATE TEMP TABLE IF NOT EXISTS nimbus_migration_precheck AS
SELECT
  (SELECT count(*) FROM users)  AS users_count,
  (SELECT count(*) FROM orders) AS orders_count;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS user_tier VARCHAR DEFAULT 'free';

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP NULL;

-- IF NOT EXISTS makes this idempotent. A normal CREATE INDEX is used so the whole DDL can be transactional.
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders (created_at);

-- Backfill only missing values so a rerun does not overwrite an existing processed_at value.
UPDATE orders
SET processed_at = created_at + INTERVAL '2 hours'
WHERE status = 'completed'
  AND processed_at IS NULL;

-- Post-validation: columns and index must exist, and row counts must be unchanged.
DO $$
DECLARE
  users_before bigint;
  orders_before bigint;
  users_after bigint;
  orders_after bigint;
  completed_missing bigint;
  idx_count bigint;
  user_tier_exists boolean;
  processed_at_exists boolean;
BEGIN
  SELECT users_count, orders_count
    INTO users_before, orders_before
    FROM nimbus_migration_precheck;

  SELECT count(*) INTO users_after FROM users;
  SELECT count(*) INTO orders_after FROM orders;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = current_schema()
      AND table_name = 'users'
      AND column_name = 'user_tier'
  ) INTO user_tier_exists;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = current_schema()
      AND table_name = 'orders'
      AND column_name = 'processed_at'
  ) INTO processed_at_exists;

  SELECT count(*) INTO idx_count
  FROM pg_indexes
  WHERE schemaname = current_schema()
    AND tablename = 'orders'
    AND indexname = 'idx_orders_created_at';

  SELECT count(*) INTO completed_missing
  FROM orders
  WHERE status = 'completed'
    AND processed_at IS NULL;

  IF users_before <> users_after OR orders_before <> orders_after THEN
    RAISE EXCEPTION 'Row-count validation failed: users %, orders % -> users %, orders %',
      users_before, orders_before, users_after, orders_after;
  END IF;

  IF NOT user_tier_exists OR NOT processed_at_exists OR idx_count <> 1 THEN
    RAISE EXCEPTION 'Schema validation failed: user_tier=%, processed_at=%, index_count=%',
      user_tier_exists, processed_at_exists, idx_count;
  END IF;

  IF completed_missing <> 0 THEN
    RAISE EXCEPTION 'Backfill validation failed: % completed orders still have NULL processed_at', completed_missing;
  END IF;

  RAISE NOTICE 'Migration validation passed. users=% orders=% index=% completed_missing=%',
    users_after, orders_after, idx_count, completed_missing;
END $$;

COMMIT;
