-- ============================================
-- NimbusTech Database Rollback
-- Version: v2 -> v1
-- ============================================


-- Remove the index
DROP INDEX IF EXISTS idx_orders_created_at;


-- Remove processed_at column
ALTER TABLE orders
DROP COLUMN IF EXISTS processed_at;


-- Remove user_tier column
ALTER TABLE users
DROP COLUMN IF EXISTS user_tier;


-- Check that columns were removed
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name = 'user_tier';

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'orders'
AND column_name = 'processed_at';


-- Check that index was removed
SELECT indexname
FROM pg_indexes
WHERE tablename = 'orders'
AND indexname = 'idx_orders_created_at';