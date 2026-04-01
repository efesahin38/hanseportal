-- ============================================================
-- HANSE KOLLEKTIV GmbH – DİJİTAL YÖNETİM SİSTEMİ
-- Tam Supabase SQL Şeması – Tüm 16 Modül
-- Supabase SQL Editor'de çalıştırın
-- ============================================================

-- Mevcut tabloları temizle (cascade ile bağlı olanlar da silinir)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS archive_records CASCADE;
DROP TABLE IF EXISTS invoice_draft_items CASCADE;
DROP TABLE IF EXISTS invoice_drafts CASCADE;
DROP TABLE IF EXISTS work_reports CASCADE;
DROP TABLE IF EXISTS extra_works CASCADE;
DROP TABLE IF EXISTS work_sessions CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS operation_plan_personnel CASCADE;
DROP TABLE IF EXISTS operation_plans CASCADE;
DROP TABLE IF EXISTS calendar_events CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS order_status_history CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customer_contacts CASCADE;
DROP TABLE IF EXISTS customer_service_areas CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS user_service_areas CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS companies CASCADE;
DROP TABLE IF EXISTS service_areas CASCADE;

-- Enum tiplerini temizle
DROP TYPE IF EXISTS company_type CASCADE;
DROP TYPE IF EXISTS company_status CASCADE;
DROP TYPE IF EXISTS company_relation CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS user_status CASCADE;
DROP TYPE IF EXISTS customer_type CASCADE;
DROP TYPE IF EXISTS customer_status CASCADE;
DROP TYPE IF EXISTS order_status CASCADE;
DROP TYPE IF EXISTS order_priority CASCADE;
DROP TYPE IF EXISTS document_type CASCADE;
DROP TYPE IF EXISTS operation_plan_status CASCADE;
DROP TYPE IF EXISTS work_session_status CASCADE;
DROP TYPE IF EXISTS extra_work_status CASCADE;
DROP TYPE IF EXISTS invoice_draft_status CASCADE;
DROP TYPE IF EXISTS notification_type CASCADE;
DROP TYPE IF EXISTS archive_status CASCADE;

-- ============================================================
-- ENUM TİPLERİ
-- ============================================================

CREATE TYPE company_type AS ENUM ('GmbH', 'UG', 'KG', 'GbR', 'Einzelunternehmen', 'AG', 'other');
CREATE TYPE company_status AS ENUM ('active', 'inactive');
CREATE TYPE company_relation AS ENUM ('parent', 'subsidiary', 'affiliate');

CREATE TYPE user_role AS ENUM (
  'geschaeftsfuehrer',   -- Patronun tam erişim rolü
  'betriebsleiter',      -- Operasyon müdürü
  'bereichsleiter',      -- Bölüm sorumlusu
  'vorarbeiter',         -- Ustabaşı / saha sorumlusu
  'mitarbeiter',         -- Saha çalışanı
  'buchhaltung',         -- Muhasebe
  'backoffice',          -- Ofis / Verwaltung
  'system_admin'         -- Sistem yöneticisi
);

CREATE TYPE user_status AS ENUM ('active', 'inactive');
CREATE TYPE customer_type AS ENUM ('company', 'public_institution', 'individual', 'other');
CREATE TYPE customer_status AS ENUM ('active', 'inactive', 'potential', 'archived');

CREATE TYPE order_status AS ENUM (
  'draft',         -- Taslak
  'created',       -- Oluşturuldu
  'pending_approval', -- Onay Bekliyor
  'approved',      -- Onaylandı
  'planning',      -- Planlamada
  'in_progress',   -- Uygulamada
  'completed',     -- Tamamlandı
  'invoiced',      -- Faturalandı
  'archived'       -- Arşivlendi
);

CREATE TYPE order_priority AS ENUM ('low', 'normal', 'high', 'urgent');
CREATE TYPE document_type AS ENUM (
  'offer', 'approved_offer', 'contract', 'addendum', 'technical_spec',
  'work_order', 'scope_list', 'excel', 'photo', 'video', 'client_note',
  'delivery_form', 'pre_invoice', 'final_invoice', 'other'
);
CREATE TYPE operation_plan_status AS ENUM ('draft', 'sent', 'confirmed', 'updated', 'cancelled');
CREATE TYPE work_session_status AS ENUM ('started', 'completed', 'adjusted');
CREATE TYPE extra_work_status AS ENUM ('recorded', 'pending_approval', 'approved', 'not_billable', 'invoiced');
CREATE TYPE invoice_draft_status AS ENUM ('auto_generated', 'under_review', 'correction_needed', 'approved', 'invoiced', 'cancelled');
CREATE TYPE notification_type AS ENUM ('task_assignment', 'task_update', 'task_cancelled', 'reminder', 'system');
CREATE TYPE archive_status AS ENUM ('active', 'archived', 'deleted');

-- ============================================================
-- 1. HİZMET ALANLARI (BRANŞLAR)
-- ============================================================
CREATE TABLE service_areas (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code         VARCHAR(50) UNIQUE NOT NULL,  -- 'gebaeudereinigung', 'gleisbausicherung' vb.
  name         VARCHAR(100) NOT NULL,        -- 'Gebäudereinigung'
  description  TEXT,
  color        VARCHAR(20),                  -- UI renk kodu
  is_active    BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO service_areas (code, name, color) VALUES
  ('gebaeudereinigung',     'Gebäudereinigung',     '#2196F3'),
  ('gleisbausicherung',     'Gleisbausicherung',     '#FF5722'),
  ('hotelservice',          'Hotelservice',          '#9C27B0'),
  ('personalueberlassung',  'Personalüberlassung',   '#4CAF50'),
  ('verwaltung',            'Verwaltung',            '#607D8B'),
  ('other',                 'Diğer',                '#9E9E9E');

-- ============================================================
-- 2. ŞİRKETLER (BÖLÜM 1)
-- ============================================================
CREATE TABLE companies (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Temel Bilgiler
  name                  VARCHAR(200) NOT NULL,           -- Tam ticari unvan
  short_name            VARCHAR(50),                     -- Kısa / sistem içi ad
  company_type          company_type NOT NULL DEFAULT 'GmbH',
  status                company_status NOT NULL DEFAULT 'active',
  relation_type         company_relation NOT NULL DEFAULT 'subsidiary',
  parent_company_id     UUID REFERENCES companies(id),   -- Ana şirket
  -- Adres
  address               TEXT,
  postal_code           VARCHAR(20),
  city                  VARCHAR(100),
  country               VARCHAR(100) NOT NULL DEFAULT 'Deutschland',
  -- İletişim
  phone                 VARCHAR(50),
  email                 VARCHAR(150),
  website               VARCHAR(200),
  -- Vergi & Hukuki
  tax_number            VARCHAR(50),
  vat_number            VARCHAR(50),
  trade_register_number VARCHAR(50),
  trade_register_court  VARCHAR(100),
  -- Banka
  bank_name             VARCHAR(100),
  iban                  VARCHAR(50),
  bic                   VARCHAR(20),
  -- Faaliyet
  service_description   TEXT,
  -- Logo & Belgeler
  logo_url              TEXT,
  -- Meta
  notes                 TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Hanse Kollektiv – Ana Şirket
INSERT INTO companies (name, short_name, company_type, relation_type, city, country)
VALUES ('Hanse Kollektiv GmbH', 'Hanse Kollektiv', 'GmbH', 'parent', 'Hamburg', 'Deutschland');

-- ============================================================
-- 3. BÖLÜMLER (Departments)
-- ============================================================
CREATE TABLE departments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES companies(id),
  name         VARCHAR(100) NOT NULL,
  code         VARCHAR(50),
  description  TEXT,
  parent_dept_id UUID REFERENCES departments(id),
  is_active    BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 4. KULLANICILAR / PERSONEL (BÖLÜM 2)
-- ============================================================
CREATE TABLE users (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Auth (Supabase Auth id ile eşleşir)
  auth_id               UUID UNIQUE,   -- Supabase auth.users.id
  -- Kimlik
  first_name            VARCHAR(100) NOT NULL,
  last_name             VARCHAR(100) NOT NULL,
  email                 VARCHAR(150) UNIQUE NOT NULL,
  phone                 VARCHAR(50),
  -- Organizasyon
  company_id            UUID NOT NULL REFERENCES companies(id),
  department_id         UUID REFERENCES departments(id),
  role                  user_role NOT NULL DEFAULT 'mitarbeiter',
  position_title        VARCHAR(100),   -- Görev / pozisyon adı (serbest metin)
  manager_id            UUID REFERENCES users(id), -- Üst yönetici
  -- Durum
  status                user_status NOT NULL DEFAULT 'active',
  start_date            DATE,
  -- Çalışma Modeli
  weekly_hours          NUMERIC(5,2),  -- Sözleşmesel haftalık çalışma saati
  employment_type       VARCHAR(50),   -- Vollzeit, Teilzeit, Minijob, vb.
  -- PIN (eski sistem uyumluluğu için)
  pin_code              VARCHAR(20),
  -- Push Notification
  fcm_token             TEXT,
  -- Opsiyonel Bilgiler
  birth_date            DATE,
  address               TEXT,
  emergency_contact     TEXT,
  bank_iban             VARCHAR(50),
  driving_license       VARCHAR(50),
  employee_number       VARCHAR(50) UNIQUE,
  photo_url             TEXT,
  notes                 TEXT,
  -- Meta
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 5. PERSONEL – HİZMET ALANI UYGUNLUĞU
-- ============================================================
CREATE TABLE user_service_areas (
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  service_area_id UUID NOT NULL REFERENCES service_areas(id),
  is_qualified    BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY (user_id, service_area_id)
);

-- ============================================================
-- 6. MÜŞTERİLER / İŞVERENLER (BÖLÜM 3)
-- ============================================================
CREATE TABLE customers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Temel
  name                VARCHAR(200) NOT NULL,
  customer_type       customer_type NOT NULL DEFAULT 'company',
  status              customer_status NOT NULL DEFAULT 'active',
  customer_class      VARCHAR(10),   -- A, B, C iç sınıflandırma
  tags                TEXT[],        -- ['büyük müşteri', 'stratejik']
  -- Adres
  address             TEXT,
  postal_code         VARCHAR(20),
  city                VARCHAR(100),
  country             VARCHAR(100) DEFAULT 'Deutschland',
  -- Fatura Adresi (farklıysa)
  billing_address     TEXT,
  billing_postal_code VARCHAR(20),
  billing_city        VARCHAR(100),
  -- Saha Adresi (farklıysa)
  site_address        TEXT,
  -- İletişim
  phone               VARCHAR(50),
  email               VARCHAR(150),
  website             VARCHAR(200),
  -- Vergi
  tax_number          VARCHAR(50),
  vat_number          VARCHAR(50),
  -- Ödeme
  payment_terms       VARCHAR(100),  -- '30 Tage netto' vb.
  -- Bağlı şirket (hangi şirketimiz üzerinden çalışıyor)
  company_id          UUID REFERENCES companies(id),
  -- Notlar
  notes               TEXT,
  special_access_info TEXT,   -- Özel saha erişim bilgileri
  -- Meta
  created_by          UUID REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 7. MÜŞTERİ – HİZMET ALANI İLİŞKİSİ
-- ============================================================
CREATE TABLE customer_service_areas (
  customer_id     UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  service_area_id UUID NOT NULL REFERENCES service_areas(id),
  PRIMARY KEY (customer_id, service_area_id)
);

-- ============================================================
-- 8. MÜŞTERİ MUHATAPLARI (İletişim Kişileri)
-- ============================================================
CREATE TABLE customer_contacts (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id      UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  name             VARCHAR(100) NOT NULL,
  role             VARCHAR(100),   -- Bauleiter, Einkauf, Buchhaltung vb.
  phone            VARCHAR(50),
  email            VARCHAR(150),
  is_primary       BOOLEAN NOT NULL DEFAULT false,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 9. İŞLER / SİPARİŞLER (BÖLÜM 4)
-- ============================================================
CREATE TABLE orders (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Otomatik numara
  order_number         VARCHAR(50) UNIQUE NOT NULL DEFAULT 'ORD-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(FLOOR(RANDOM()*99999)::TEXT, 5, '0'),
  -- İlişkiler
  company_id           UUID NOT NULL REFERENCES companies(id),
  customer_id          UUID NOT NULL REFERENCES customers(id),
  department_id        UUID REFERENCES departments(id),
  responsible_user_id  UUID REFERENCES users(id),  -- Bereichsleiter
  service_area_id      UUID NOT NULL REFERENCES service_areas(id),
  -- İş Bilgisi
  title                VARCHAR(200) NOT NULL,
  short_description    TEXT,
  detailed_description TEXT,
  -- Adres
  site_address         TEXT,
  -- Müşteri Muhatabı
  customer_contact_id  UUID REFERENCES customer_contacts(id),
  -- Tarihler
  planned_start_date   DATE,
  planned_end_date     DATE,
  -- Durum & Öncelik
  status               order_status NOT NULL DEFAULT 'draft',
  priority             order_priority NOT NULL DEFAULT 'normal',
  -- Referanslar
  customer_ref_number  VARCHAR(100),   -- Müşterinin iş numarası
  offer_number         VARCHAR(100),
  contract_number      VARCHAR(100),
  internal_code        VARCHAR(100),
  -- Tekrar eden iş
  is_recurring         BOOLEAN NOT NULL DEFAULT false,
  recurring_info       TEXT,
  -- Ek
  notes                TEXT,
  material_notes       TEXT,
  minimum_billable_hours NUMERIC(6,2),
  -- Meta
  created_by           UUID REFERENCES users(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 10. İŞ DURUM GEÇMİŞİ (Log)
-- ============================================================
CREATE TABLE order_status_history (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  old_status   order_status,
  new_status   order_status NOT NULL,
  changed_by   UUID REFERENCES users(id),
  note         TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 11. BELGELER VE DOSYALAR (BÖLÜM 5)
-- ============================================================
CREATE TABLE documents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- İlişki (en az biri dolu olmalı)
  company_id      UUID REFERENCES companies(id),
  customer_id     UUID REFERENCES customers(id),
  order_id        UUID REFERENCES orders(id),
  user_id         UUID REFERENCES users(id),   -- Personel belgesi
  -- Belge Bilgisi
  document_type   document_type NOT NULL DEFAULT 'other',
  title           VARCHAR(200) NOT NULL,
  description     TEXT,
  file_url        TEXT NOT NULL,     -- Supabase Storage URL
  file_name       VARCHAR(300),
  file_size_kb    INTEGER,
  file_mime       VARCHAR(100),
  -- Versiyon
  version         INTEGER NOT NULL DEFAULT 1,
  is_current      BOOLEAN NOT NULL DEFAULT true,
  previous_doc_id UUID REFERENCES documents(id),
  -- Görünürlük
  visibility_roles user_role[] DEFAULT ARRAY['geschaeftsfuehrer'::user_role, 'betriebsleiter'::user_role],
  -- Meta
  uploaded_by     UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 12. TAKVİM VE TERMİNLER (BÖLÜM 6)
-- ============================================================
CREATE TABLE calendar_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id        UUID REFERENCES orders(id) ON DELETE CASCADE,
  company_id      UUID REFERENCES companies(id),
  department_id   UUID REFERENCES departments(id),
  responsible_user_id UUID REFERENCES users(id),
  title           VARCHAR(200) NOT NULL,
  description     TEXT,
  event_date      DATE NOT NULL,
  start_time      TIME,
  end_time        TIME,
  all_day         BOOLEAN NOT NULL DEFAULT false,
  is_recurring    BOOLEAN NOT NULL DEFAULT false,
  recurrence_rule TEXT,      -- RRULE formatı
  reminder_hours  INTEGER DEFAULT 24,  -- Kaç saat önceden hatırlatma
  created_by      UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 13. OPERASYON VE PERSONEL PLANLAMA (BÖLÜM 7)
-- ============================================================
CREATE TABLE operation_plans (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  -- Planlama Bilgisi
  plan_date             DATE NOT NULL,
  start_time            TIME NOT NULL,
  end_time              TIME,
  estimated_duration_h  NUMERIC(6,2),
  -- Sorumluluk
  site_supervisor_id    UUID REFERENCES users(id),   -- Saha sorumlusu
  planned_by            UUID REFERENCES users(id),   -- Planlayan kullanıcı
  -- Durum
  status                operation_plan_status NOT NULL DEFAULT 'draft',
  -- Sahadaki Özel Bilgiler
  site_instructions     TEXT,     -- Saha talimatları
  equipment_notes       TEXT,     -- Gerekli ekipman notları
  material_notes        TEXT,     -- Malzeme notları
  -- Bildirim
  notification_sent     BOOLEAN NOT NULL DEFAULT false,
  notification_sent_at  TIMESTAMPTZ,
  -- Meta
  notes                 TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 14. PERSONEL ATAMA (Plana hangi personel atandı)
-- ============================================================
CREATE TABLE operation_plan_personnel (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_plan_id UUID NOT NULL REFERENCES operation_plans(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES users(id),
  is_supervisor     BOOLEAN NOT NULL DEFAULT false,   -- Bu kişi saha sorumlusu mu?
  assigned_by       UUID REFERENCES users(id),
  assigned_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (operation_plan_id, user_id)
);

-- ============================================================
-- 15. BİLDİRİMLER VE GÖREV İLETİMİ (BÖLÜM 8)
-- ============================================================
CREATE TABLE notifications (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Alıcı
  recipient_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- İçerik
  notification_type   notification_type NOT NULL DEFAULT 'task_assignment',
  title               VARCHAR(200) NOT NULL,
  body                TEXT,
  -- İlişki
  order_id            UUID REFERENCES orders(id),
  operation_plan_id   UUID REFERENCES operation_plans(id),
  -- Durum
  is_read             BOOLEAN NOT NULL DEFAULT false,
  read_at             TIMESTAMPTZ,
  -- Push
  push_sent           BOOLEAN NOT NULL DEFAULT false,
  push_sent_at        TIMESTAMPTZ,
  -- Meta
  sent_by             UUID REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 16. SAHA ÇALIŞMA KAYITLARI / MOBİL SAHA (BÖLÜM 9 & 10)
-- ============================================================
CREATE TABLE work_sessions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_plan_id     UUID REFERENCES operation_plans(id),
  order_id              UUID NOT NULL REFERENCES orders(id),
  user_id               UUID NOT NULL REFERENCES users(id),
  -- Gerçekleşen Süreler
  actual_start          TIMESTAMPTZ,
  actual_end            TIMESTAMPTZ,
  actual_duration_h     NUMERIC(6,2) GENERATED ALWAYS AS (
    CASE WHEN actual_start IS NOT NULL AND actual_end IS NOT NULL
    THEN EXTRACT(EPOCH FROM (actual_end - actual_start)) / 3600.0
    ELSE NULL END
  ) STORED,
  -- Sözleşme / Minimum Süreler
  minimum_hours         NUMERIC(6,2),   -- Anlaşılan minimum
  billable_hours        NUMERIC(6,2),   -- Faturalanabilir (min ya da actual, hangisi büyükse)
  extra_hours           NUMERIC(6,2),   -- Fazla süre
  -- Durum
  status                work_session_status NOT NULL DEFAULT 'started',
  -- Konum (opsiyonel, ileri aşama)
  start_latitude        DOUBLE PRECISION,
  start_longitude       DOUBLE PRECISION,
  end_latitude          DOUBLE PRECISION,
  end_longitude         DOUBLE PRECISION,
  -- Notlar
  note                  TEXT,
  -- Manuel Düzeltme
  is_manually_adjusted  BOOLEAN NOT NULL DEFAULT false,
  adjusted_by           UUID REFERENCES users(id),
  adjustment_reason     TEXT,
  -- Meta
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 17. EK İŞ / EK HİZMET (BÖLÜM 11)
-- ============================================================
CREATE TABLE extra_works (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  operation_plan_id     UUID REFERENCES operation_plans(id),
  -- Ek İş Bilgisi
  title                 VARCHAR(200) NOT NULL,
  description           TEXT,
  work_date             DATE NOT NULL,
  duration_h            NUMERIC(6,2),
  -- Maliyet & Faturalama
  is_billable           BOOLEAN,   -- null = değerlendirmede
  estimated_material_cost NUMERIC(12,2),
  estimated_labor_cost  NUMERIC(12,2),
  -- Onay
  status                extra_work_status NOT NULL DEFAULT 'recorded',
  approved_by           UUID REFERENCES users(id),
  approved_at           TIMESTAMPTZ,
  customer_approved     BOOLEAN,
  customer_approved_by  VARCHAR(100),
  -- Meta
  recorded_by           UUID NOT NULL REFERENCES users(id),
  notes                 TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 18. İŞ SONU RAPORLAMA (BÖLÜM 12)
-- ============================================================
CREATE TABLE work_reports (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID NOT NULL UNIQUE REFERENCES orders(id),
  -- Özet Veriler (Otomatik derleme)
  total_personnel       INTEGER DEFAULT 0,
  total_actual_hours    NUMERIC(8,2) DEFAULT 0,
  total_billable_hours  NUMERIC(8,2) DEFAULT 0,
  total_extra_hours     NUMERIC(8,2) DEFAULT 0,
  total_extra_works     INTEGER DEFAULT 0,
  -- Maliyet & Gelir (Tahmini)
  estimated_labor_cost  NUMERIC(12,2),
  estimated_material_cost NUMERIC(12,2),
  estimated_total_cost  NUMERIC(12,2),
  total_revenue         NUMERIC(12,2),
  estimated_margin      NUMERIC(12,2),
  -- Notlar
  summary_note          TEXT,
  quality_note          TEXT,
  customer_feedback     TEXT,
  -- Durum
  is_finalized          BOOLEAN NOT NULL DEFAULT false,
  finalized_by          UUID REFERENCES users(id),
  finalized_at          TIMESTAMPTZ,
  -- Meta
  created_by            UUID REFERENCES users(id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 19. ÖN FATURA TASLAĞI (BÖLÜM 13)
-- ============================================================
CREATE TABLE invoice_drafts (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID NOT NULL REFERENCES orders(id),
  work_report_id        UUID REFERENCES work_reports(id),
  -- Fatura Bilgisi
  draft_number          VARCHAR(50) UNIQUE NOT NULL DEFAULT 'INV-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(FLOOR(RANDOM()*99999)::TEXT, 5, '0'),
  -- Şirket Bilgisi (Kim kesiyor)
  issuing_company_id    UUID NOT NULL REFERENCES companies(id),
  -- Müşteri Fatura Bilgisi
  customer_id           UUID NOT NULL REFERENCES customers(id),
  billing_name          VARCHAR(200),
  billing_address       TEXT,
  billing_tax_number    VARCHAR(50),
  -- Hizmet Adresi
  site_address          TEXT,
  -- Muhatap
  contact_name          VARCHAR(100),
  -- Tarihler
  service_date_from     DATE,
  service_date_to       DATE,
  -- Vergi
  tax_rate              NUMERIC(5,2) NOT NULL DEFAULT 19.00,  -- KDV %19
  -- Toplamlar (otomatik hesaplanır)
  subtotal              NUMERIC(12,2) DEFAULT 0,
  tax_amount            NUMERIC(12,2) DEFAULT 0,
  total_amount          NUMERIC(12,2) DEFAULT 0,
  -- Durum
  status                invoice_draft_status NOT NULL DEFAULT 'auto_generated',
  -- Notlar
  notes                 TEXT,
  accounting_note       TEXT,
  payment_terms         VARCHAR(100),
  -- Meta
  created_by            UUID REFERENCES users(id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 20. FATURA TASLAĞI KALEMLERİ
-- ============================================================
CREATE TABLE invoice_draft_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_draft_id  UUID NOT NULL REFERENCES invoice_drafts(id) ON DELETE CASCADE,
  -- Kalem Türü
  item_type         VARCHAR(50) NOT NULL DEFAULT 'main',   -- 'main' | 'extra'
  description       VARCHAR(500) NOT NULL,
  quantity          NUMERIC(10,2) NOT NULL DEFAULT 1,
  unit              VARCHAR(50) DEFAULT 'Std.',   -- Stunde, Stück, pauschal
  unit_price        NUMERIC(12,2),
  total_price       NUMERIC(12,2),
  extra_work_id     UUID REFERENCES extra_works(id),
  sort_order        INTEGER DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 21. DİJİTAL ARŞİV (BÖLÜM 14)
-- ============================================================
CREATE TABLE archive_records (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id            UUID NOT NULL REFERENCES orders(id),
  -- Arşiv Bilgisi
  archive_folder_path TEXT,       -- OneDrive klasör yolu
  onedrive_folder_id  TEXT,       -- OneDrive klasör ID (entegrasyon sonrası)
  -- İçerik Özeti
  archived_documents  INTEGER DEFAULT 0,
  archived_at         TIMESTAMPTZ,
  -- Durum
  status              archive_status NOT NULL DEFAULT 'active',
  -- Meta
  created_by          UUID REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 22. DENETİM LOGLARI (her modül için izlenebilirlik)
-- ============================================================
CREATE TABLE audit_logs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id),
  action       VARCHAR(100) NOT NULL,   -- 'create', 'update', 'delete', 'status_change', vb.
  table_name   VARCHAR(100) NOT NULL,
  record_id    UUID,
  old_value    JSONB,
  new_value    JSONB,
  ip_address   VARCHAR(50),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- İNDEKSLER (Performans)
-- ============================================================
CREATE INDEX idx_users_company ON users(company_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_auth_id ON users(auth_id);
CREATE INDEX idx_customers_company ON customers(company_id);
CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_orders_company ON orders(company_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_service_area ON orders(service_area_id);
CREATE INDEX idx_orders_responsible ON orders(responsible_user_id);
CREATE INDEX idx_documents_order ON documents(order_id);
CREATE INDEX idx_documents_customer ON documents(customer_id);
CREATE INDEX idx_documents_company ON documents(company_id);
CREATE INDEX idx_operation_plans_order ON operation_plans(order_id);
CREATE INDEX idx_operation_plans_date ON operation_plans(plan_date);
CREATE INDEX idx_operation_plan_personnel_user ON operation_plan_personnel(user_id);
CREATE INDEX idx_work_sessions_order ON work_sessions(order_id);
CREATE INDEX idx_work_sessions_user ON work_sessions(user_id);
CREATE INDEX idx_notifications_recipient ON notifications(recipient_id);
CREATE INDEX idx_notifications_read ON notifications(recipient_id, is_read);
CREATE INDEX idx_extra_works_order ON extra_works(order_id);
CREATE INDEX idx_audit_logs_table ON audit_logs(table_name, record_id);

-- ============================================================
-- UPDATED_AT TRIGGER (otomatik güncelleme tarihi)
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_companies_updated BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_customers_updated BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_documents_updated BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_operation_plans_updated BEFORE UPDATE ON operation_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_work_sessions_updated BEFORE UPDATE ON work_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_extra_works_updated BEFORE UPDATE ON extra_works FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_work_reports_updated BEFORE UPDATE ON work_reports FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_invoice_drafts_updated BEFORE UPDATE ON invoice_drafts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_archive_records_updated BEFORE UPDATE ON archive_records FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- FATURA TOPLAMI OTOMATİK HESAPLAMA TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION recalculate_invoice_totals()
RETURNS TRIGGER AS $$
DECLARE
  v_subtotal NUMERIC(12,2);
  v_tax_rate NUMERIC(5,2);
BEGIN
  SELECT COALESCE(SUM(total_price), 0) INTO v_subtotal
  FROM invoice_draft_items
  WHERE invoice_draft_id = COALESCE(NEW.invoice_draft_id, OLD.invoice_draft_id);

  SELECT tax_rate INTO v_tax_rate FROM invoice_drafts
  WHERE id = COALESCE(NEW.invoice_draft_id, OLD.invoice_draft_id);

  UPDATE invoice_drafts SET
    subtotal     = v_subtotal,
    tax_amount   = ROUND(v_subtotal * v_tax_rate / 100, 2),
    total_amount = ROUND(v_subtotal * (1 + v_tax_rate / 100), 2)
  WHERE id = COALESCE(NEW.invoice_draft_id, OLD.invoice_draft_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_invoice_item_recalc
AFTER INSERT OR UPDATE OR DELETE ON invoice_draft_items
FOR EACH ROW EXECUTE FUNCTION recalculate_invoice_totals();

-- ============================================================
-- ÇALIŞMA SÜRESİ HESAPLAMA: billable_hours (min ya da actual)
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_billable_hours()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.actual_duration_h IS NOT NULL THEN
    IF NEW.minimum_hours IS NOT NULL AND NEW.actual_duration_h < NEW.minimum_hours THEN
      NEW.billable_hours := NEW.minimum_hours;
      NEW.extra_hours    := 0;
    ELSE
      NEW.billable_hours := NEW.actual_duration_h;
      NEW.extra_hours    := GREATEST(0, COALESCE(NEW.actual_duration_h, 0) - COALESCE(NEW.minimum_hours, 0));
    END IF;
    NEW.status := 'completed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_work_session_billable
BEFORE INSERT OR UPDATE ON work_sessions
FOR EACH ROW EXECUTE FUNCTION calculate_billable_hours();

-- ============================================================
-- ROW LEVEL SECURITY (RLS) – Temel Güvenlik
-- ============================================================

-- Users tablosu: Kullanıcı kendi kaydını görebilir, admin/geschaeftsfuehrer hepsini görebilir
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_own ON users
  FOR SELECT USING (auth_id = auth.uid());
CREATE POLICY users_admin ON users
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
      AND u.role IN ('geschaeftsfuehrer', 'betriebsleiter', 'system_admin')
    )
  );

-- Companies tablosu RLS
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
CREATE POLICY companies_view ON companies
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
  );
CREATE POLICY companies_manage ON companies
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE auth_id = auth.uid()
      AND role IN ('geschaeftsfuehrer', 'system_admin')
    )
  );

-- Orders tablosu RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY orders_view ON orders
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
  );
CREATE POLICY orders_manage ON orders
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE auth_id = auth.uid()
      AND role IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'backoffice', 'system_admin')
    )
  );

-- Notifications RLS: Sadece kendi bildirimleri
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY notifications_own ON notifications
  FOR ALL USING (
    recipient_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM users WHERE auth_id = auth.uid()
      AND role IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
    )
  );

-- Work Sessions RLS
ALTER TABLE work_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY work_sessions_own ON work_sessions
  FOR SELECT USING (
    user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM users WHERE auth_id = auth.uid()
      AND role IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'buchhaltung', 'system_admin')
    )
  );
CREATE POLICY work_sessions_insert ON work_sessions
  FOR INSERT WITH CHECK (
    user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  );

-- ============================================================
-- ÖRNEK VERİ: Kullanıcılar (auth_id sonradan güncellenecek)
-- Supabase Auth'dan kullanıcı oluşturduktan sonra auth_id güncellenecek
-- ============================================================

-- Önce Hanse Kollektiv şirketini bul
DO $$
DECLARE v_company_id UUID;
BEGIN
  SELECT id INTO v_company_id FROM companies WHERE short_name = 'Hanse Kollektiv';

  -- Sistem Yöneticisi / Geschäftsführer
  INSERT INTO users (first_name, last_name, email, company_id, role, pin_code)
  VALUES ('Ekrem', 'Şahin', 'ekrem@hansekollektiv.de', v_company_id, 'geschaeftsfuehrer', '0000')
  ON CONFLICT (email) DO NOTHING;

END $$;

-- ============================================================
-- SONUÇ
-- ============================================================
-- ✅ 22 Tablo oluşturuldu
-- ✅ 6 Tür ENUM tanımlandı
-- ✅ Tüm indeksler oluşturuldu
-- ✅ Auto-updated_at trigger'ları eklendi
-- ✅ Fatura toplam hesaplama trigger'ı eklendi
-- ✅ Billable hours hesaplama trigger'ı eklendi
-- ✅ Temel RLS politikaları eklendi
-- ✅ Hanse Kollektiv GmbH ana şirketi eklendi
-- ✅ 6 hizmet alanı tanımlandı
