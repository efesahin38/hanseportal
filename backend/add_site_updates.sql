-- ============================================================
-- SAHA LİDERİ ANLIK RAPORLAMA (SİTE UPDATES)
-- ============================================================

-- 1. Site Updates Tablosu
CREATE TABLE IF NOT EXISTS site_updates (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_plan_id UUID REFERENCES operation_plans(id) ON DELETE CASCADE,
  order_id          UUID REFERENCES orders(id) ON DELETE CASCADE,
  user_id           UUID REFERENCES users(id), -- Raporu gönderen lider
  description       TEXT,                      -- Açıklama
  photo_url         TEXT,                      -- Sıkıştırılmış fotoğraf URL
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. İndeksler
CREATE INDEX IF NOT EXISTS idx_site_updates_plan ON site_updates(operation_plan_id);
CREATE INDEX IF NOT EXISTS idx_site_updates_order ON site_updates(order_id);

-- 3. RLS Politikaları
-- Uygulama kuralına göre RLS kapalıysa (kendi auth akışınızda olduğu gibi) veya açık tutulacaksa:
-- ALTER TABLE site_updates DISABLE ROW LEVEL SECURITY;
