-- ============================================================
-- ADD 'passive' TO ENUMS FOR SOFT DELETE
-- ============================================================

-- 'passive' statüsü, uygulamada "kalıcı olarak gizlenen / silinen" 
-- kayıtlar için kullanılıyor. ENUM tiplerinde eksik olduğu için 
-- sisteme ekliyoruz.

ALTER TYPE customer_status ADD VALUE IF NOT EXISTS 'passive';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'passive';
ALTER TYPE company_status ADD VALUE IF NOT EXISTS 'passive';
ALTER TYPE user_status ADD VALUE IF NOT EXISTS 'passive';
