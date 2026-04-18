-- ============================================================
-- ÖZEL LOKAL GİRİŞ (CUSTOM AUTH) VE RLS İPTALİ
-- ============================================================
-- Supabase Auth devre dışı bırakılıp, direkt users tablosu üzerinden
-- şifre ve mail kontrolü yapılabilmesi için gereken veritabanı ayarları.

-- 1. Users tablosuna şifre sütunu ekle (Eğer yoksa)
ALTER TABLE users ADD COLUMN IF NOT EXISTS password VARCHAR(100);

-- 2. Herkesin şifresini '1111' yap
UPDATE users SET password = '1111';

-- 3. Supabase Row Level Security (RLS) kısıtlamalarını TAMAMEN devre dışı bırak
-- (Custom Auth kullandığımız için RLS sistemini tamamen kapatıyoruz)
ALTER TABLE audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE archive_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_draft_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_drafts DISABLE ROW LEVEL SECURITY;
ALTER TABLE work_reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE extra_works DISABLE ROW LEVEL SECURITY;
ALTER TABLE work_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE operation_plan_personnel DISABLE ROW LEVEL SECURITY;
ALTER TABLE operation_plans DISABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_events DISABLE ROW LEVEL SECURITY;
ALTER TABLE documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE customer_contacts DISABLE ROW LEVEL SECURITY;
ALTER TABLE customer_service_areas DISABLE ROW LEVEL SECURITY;
ALTER TABLE customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_service_areas DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE departments DISABLE ROW LEVEL SECURITY;
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;
ALTER TABLE service_areas DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_service_areas DISABLE ROW LEVEL SECURITY;
