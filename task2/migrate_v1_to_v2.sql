-- ============================================
-- NimbusTech Database Migration
-- Version: v1 -> v2
-- ============================================

-- Check current row counts
SELECT COUNT(*) AS users_count FROM users;
SELECT COUNT(*) AS orders_count FROM orders;


-- ============================================
-- 1. Add user_tier column to users
-- ============================================

ALTER TABLE users
ADD COLUMN IF NOT EXISTS user_tier VARCHAR(50) DEFAULT 'free';


-- ============================================
-- 2. Add processed_at column to orders
-- ============================================

ALTER TABLE orders
ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP NULL;


-- ============================================
-- 3. Create index on orders.created_at
-- ============================================

CREATE INDEX IF NOT EXISTS idx_orders_created_at
ON orders(created_at);


-- ============================================
-- 4. Backfill processed_at
-- Completed orders = created_at + 2 hours
-- ============================================

UPDATE orders
SET processed_at = created_at + INTERVAL '2 hours'
WHERE status = 'completed'
AND processed_at IS NULL;


-- ============================================
-- 5. Validation
-- ============================================

-- Check users column
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name = 'user_tier';


-- Check orders column
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'orders'
AND column_name = 'processed_at';


-- Check index
SELECT indexname
FROM pg_indexes
WHERE tablename = 'orders'
AND indexname = 'idx_orders_created_at';


-- Check completed orders that were backfilled
SELECT COUNT(*) AS processed_orders
FROM orders
WHERE status = 'completed'
AND processed_at IS NOT NULL;


-- Final row counts
SELECT COUNT(*) AS users_count FROM users;
SELECT COUNT(*) AS orders_count FROM orders;