-- GWS Tagesplan ve Form Geliştirmeleri (v2)

-- 1. gws_daily_plans Tablosunu Sipariş (Auftrag) ile Bağla
ALTER TABLE gws_daily_plans ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES orders(id);
ALTER TABLE gws_daily_plans ADD COLUMN IF NOT EXISTS is_shared_with_customer BOOLEAN DEFAULT FALSE;
ALTER TABLE gws_daily_plans ADD COLUMN IF NOT EXISTS customer_comment TEXT;
ALTER TABLE gws_daily_plans ADD COLUMN IF NOT EXISTS customer_signature TEXT; -- Base64 Signature
ALTER TABLE gws_daily_plans ADD COLUMN IF NOT EXISTS signed_at TIMESTAMP WITH TIME ZONE;

-- 2. Odalar ve Alanlar için Form Verisi Sütunları
ALTER TABLE gws_plan_rooms ADD COLUMN IF NOT EXISTS checklist_data JSONB DEFAULT '{}'::jsonb;
ALTER TABLE gws_plan_rooms ADD COLUMN IF NOT EXISTS worker_notes TEXT;
ALTER TABLE gws_plan_rooms ADD COLUMN IF NOT EXISTS photos TEXT[]; -- Storage URL'leri
ALTER TABLE gws_plan_rooms ADD COLUMN IF NOT EXISTS checker_status TEXT DEFAULT 'pending'; -- 'ok', 'fehler'
ALTER TABLE gws_plan_rooms ADD COLUMN IF NOT EXISTS checker_notes TEXT;

ALTER TABLE gws_plan_areas ADD COLUMN IF NOT EXISTS checklist_data JSONB DEFAULT '{}'::jsonb;
ALTER TABLE gws_plan_areas ADD COLUMN IF NOT EXISTS worker_notes TEXT;
ALTER TABLE gws_plan_areas ADD COLUMN IF NOT EXISTS photos TEXT[];
ALTER TABLE gws_plan_areas ADD COLUMN IF NOT EXISTS checker_status TEXT DEFAULT 'pending';
ALTER TABLE gws_plan_areas ADD COLUMN IF NOT EXISTS checker_notes TEXT;

-- 3. Yetki Kuralları (RLS Önerileri)
-- Sadece ilgili personelin ve yöneticilerin tagesplan görmesini sağlayacak mantık Supabase Service katmanında da filtrelenecektir.
