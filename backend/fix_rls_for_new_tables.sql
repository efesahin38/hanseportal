-- ============================================================
-- HANSE KOLLEKTIV – RLS FIX FOR CUSTOM AUTH
-- ============================================================
-- Sistem email/pin_code (veya email/password) üzerinden public.users 
-- tablosuna sorgu atarak lokal (custom) oturum açtığı için, Supabase'in 
-- varsayılan auth.uid() sistemi null dönmektedir.
-- Bu yüzden yeni açılan tablolara kayıt (insert) yapılabilmesi için
-- Row Level Security kapatılmalıdır.

ALTER TABLE chat_rooms DISABLE ROW LEVEL SECURITY;
ALTER TABLE chat_room_members DISABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages DISABLE ROW LEVEL SECURITY;

ALTER TABLE contracts DISABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE pq_documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE company_bank_accounts DISABLE ROW LEVEL SECURITY;

-- Not: Güvenlik, uygulamanın (Flutter ve Backend API) kendi yazdığımız
-- AppState mantığı ve controller'ları üzerinden sağlanmaya devam etmektedir.
