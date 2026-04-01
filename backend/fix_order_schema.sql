-- ============================================================
-- EKREM APP: GİRİŞ VE TÜM ŞEMA HATALARINI TEMİZLEYEN DÜZELTME
-- ============================================================
-- Supabase SQL Editor üzerinden kopyalayıp RUN butonuna basın.

-- 1. Users Tablosu Güncellemesi: Şifre alanı ve Küçük Harf E-posta
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS password VARCHAR(100);

-- Tüm e-postaları küçük harfe zorla (Giriş için kritiktir)
UPDATE public.users SET email = LOWER(email);

-- Tüm kullanıcıların şifresini '1111' yap (Test girişleri için)
UPDATE public.users SET password = '1111';

-- 2. Kadir Adlı Kullanıcıyı Ekle (Eğer yoksa)
-- Not: Bu bölüm, screenshot'taki 'kadir@hanse.de' ile girebilmeniz için eklenmiştir.
INSERT INTO public.users (
  first_name, last_name, email, role, company_id, password, status
)
SELECT 'Kadir', 'Test', 'kadir@hanse.de', 'system_admin', 
       (SELECT id FROM companies LIMIT 1), '1111', 'active'
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE email = 'kadir@hanse.de');

-- 3. Orders Tablosundaki Eksik Alanlar (material_notes vb.)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS material_notes TEXT,
ADD COLUMN IF NOT EXISTS minimum_billable_hours NUMERIC(6,2) DEFAULT 4.0;

-- 4. RLS (Row Level Security) TAMAMEN KAPATMA
-- (Daha önce yapıldıysa bile tekrar çalışması zararsızdır)
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.companies DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.operation_plans DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.operation_plan_personnel DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.extra_works DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_drafts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_draft_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_events DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_status_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.archive_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_areas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_service_areas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_service_areas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_contacts DISABLE ROW LEVEL SECURITY;

-- 5. Mesaj: İşlem Tamamlandı. Lütfen kadir@hanse.de / 1111 ile giriş yapın.
