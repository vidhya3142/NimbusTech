-- NimbusTech PostgreSQL v2 -> v1 rollback.
-- This intentionally removes the v2 columns and index. Data stored only in processed_at is lost.
-- Take/verify a backup before rollback in production.

BEGIN;

ALTER TABLE orders
  DROP COLUMN IF EXISTS processed_at;

ALTER TABLE users
  DROP COLUMN IF EXISTS user_tier;

DROP INDEX IF EXISTS idx_orders_created_at;

DO $$
DECLARE
  user_tier_exists boolean;
  processed_at_exists boolean;
  idx_count bigint;
BEGIN
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

  IF user_tier_exists OR processed_at_exists OR idx_count <> 0 THEN
    RAISE EXCEPTION 'Rollback validation failed: user_tier=%, processed_at=%, index_count=%',
      user_tier_exists, processed_at_exists, idx_count;
  END IF;

  RAISE NOTICE 'Rollback validation passed.';
END $$;

COMMIT;
