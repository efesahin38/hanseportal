-- ============================================================
-- HANSE KOLLEKTIV – Boss Requirements Migration
-- Supabase SQL Editor'de çalıştırın
-- ============================================================

-- ============================================================
-- 1. USERS TABLOSU GENİŞLETME (Personal Stammdaten)
-- ============================================================

-- Persönliche Daten
ALTER TABLE users ADD COLUMN IF NOT EXISTS nationality VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS street VARCHAR(200);
ALTER TABLE users ADD COLUMN IF NOT EXISTS house_number VARCHAR(20);
ALTER TABLE users ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20);
ALTER TABLE users ADD COLUMN IF NOT EXISTS city VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS work_permit BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS work_permit_doc TEXT; -- 'Ausweis' oder 'Reisepass'
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_type VARCHAR(50); -- Ausweis / Reisepass
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_number VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_issue_date DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_valid_until DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS marital_status BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS has_children BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS children_count INTEGER DEFAULT 0;

-- Versicherung & Finanzen
ALTER TABLE users ADD COLUMN IF NOT EXISTS social_security_number VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS tax_id VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS bank_name VARCHAR(200);
-- bank_iban already exists as bank_iban
ALTER TABLE users ADD COLUMN IF NOT EXISTS bank_bic VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS health_insurance_name VARCHAR(200);
ALTER TABLE users ADD COLUMN IF NOT EXISTS health_insurance_number VARCHAR(100);

-- Vertragsdaten
ALTER TABLE users ADD COLUMN IF NOT EXISTS contract_type VARCHAR(50); -- Vollzeit/Teilzeit/Aushilfe
ALTER TABLE users ADD COLUMN IF NOT EXISTS trial_period_until DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS compensation_type VARCHAR(50); -- Festlohn/Stundenlohn
ALTER TABLE users ADD COLUMN IF NOT EXISTS position_as VARCHAR(200); -- Anstellung als
ALTER TABLE users ADD COLUMN IF NOT EXISTS activities TEXT; -- Tätigkeiten

-- Führerschein & Qualifikationen
ALTER TABLE users ADD COLUMN IF NOT EXISTS has_driving_license BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS driving_license_class VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS driving_license_since DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS has_qualifications BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS qualifications TEXT;

-- Arbeitsbeginn (entry_date already exists as start_date, add alias)
ALTER TABLE users ADD COLUMN IF NOT EXISTS entry_date DATE;

-- ============================================================
-- 2. COMPANY BANK ACCOUNTS (Mehrere Bankverbindungen)
-- ============================================================

CREATE TABLE IF NOT EXISTS company_bank_accounts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  bank_name    VARCHAR(200) NOT NULL,
  iban         VARCHAR(50) NOT NULL,
  bic          VARCHAR(20),
  is_primary   BOOLEAN DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. GESCHÄFTSFÜHRER-DATEN (in companies Tabelle)
-- ============================================================

ALTER TABLE companies ADD COLUMN IF NOT EXISTS ceo_first_name VARCHAR(100);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS ceo_last_name VARCHAR(100);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS ceo_address TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS ceo_phone VARCHAR(50);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS ceo_email VARCHAR(150);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS street VARCHAR(200);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS house_number VARCHAR(20);

-- ============================================================
-- 4. ORDERS TABLOSU GENİŞLETME
-- ============================================================

ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_type VARCHAR(100);  -- Auftragsart
ALTER TABLE orders ADD COLUMN IF NOT EXISTS negotiation_type VARCHAR(100); -- Verhandlungsart
ALTER TABLE orders ADD COLUMN IF NOT EXISTS net_amount NUMERIC(12,2); -- Summe netto
ALTER TABLE orders ADD COLUMN IF NOT EXISTS personnel_need INTEGER; -- Personalbedarf
ALTER TABLE orders ADD COLUMN IF NOT EXISTS material_need TEXT; -- Materialbedarf
ALTER TABLE orders ADD COLUMN IF NOT EXISTS street VARCHAR(200);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS house_number VARCHAR(20);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS city VARCHAR(100);

-- ============================================================
-- 5. CONTRACTS (Vertragsmanagement)
-- ============================================================

CREATE TABLE IF NOT EXISTS contracts (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id           UUID NOT NULL REFERENCES companies(id),
  title                VARCHAR(200) NOT NULL,
  partner              VARCHAR(200),
  contract_type        VARCHAR(100), -- Miedvertrag, Abonnement, Mitgliedschaft, etc.
  start_date           DATE,
  end_date             DATE,
  renewal_date         DATE,
  cancellation_period  VARCHAR(100),
  monthly_cost         NUMERIC(12,2),
  notes                TEXT,
  status               VARCHAR(50) DEFAULT 'active', -- active, expiring, expired, cancelled
  reminder_sent        BOOLEAN DEFAULT false,
  created_by           UUID REFERENCES users(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_contracts_updated BEFORE UPDATE ON contracts FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 6. VEHICLES (Fuhrpark)
-- ============================================================

CREATE TABLE IF NOT EXISTS vehicles (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id                UUID NOT NULL REFERENCES companies(id),
  license_plate             VARCHAR(20) NOT NULL,
  driver_first_name         VARCHAR(100),
  driver_last_name          VARCHAR(100),
  vehicle_ident_number      VARCHAR(50),
  first_registration_date   DATE,
  company_registration_date DATE,
  tuev_date                 DATE,
  last_service_date         DATE,
  last_service_details      TEXT,
  next_tire_change_date     DATE, -- Reifenwechsel
  license_check_date        DATE, -- Führerscheinkontrolle
  notes                     TEXT,
  status                    VARCHAR(50) DEFAULT 'active',
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_vehicles_updated BEFORE UPDATE ON vehicles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 7. INTERNE PQ DOCUMENTS (Firmenunterlagen)
-- ============================================================

CREATE TABLE IF NOT EXISTS pq_documents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES companies(id),
  category     VARCHAR(100) NOT NULL, -- Gewerbeschein, Handelsregister, etc.
  title        VARCHAR(200) NOT NULL,
  file_url     TEXT NOT NULL,
  file_name    VARCHAR(300),
  file_size_kb INTEGER,
  notes        TEXT,
  valid_until  DATE,
  uploaded_by  UUID REFERENCES users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 8. CHAT SYSTEM (Basis)
-- ============================================================

CREATE TABLE IF NOT EXISTS chat_rooms (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            VARCHAR(200),
  room_type       VARCHAR(50) NOT NULL DEFAULT 'direct', -- direct, group, department, order
  order_id        UUID REFERENCES orders(id),
  department_id   UUID REFERENCES departments(id),
  created_by      UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_room_members (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id      UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(room_id, user_id)
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id      UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id    UUID NOT NULL REFERENCES users(id),
  message      TEXT,
  file_url     TEXT,
  file_name    VARCHAR(300),
  is_read      BOOLEAN DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indizes
CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_room_members_user ON chat_room_members(user_id);
CREATE INDEX IF NOT EXISTS idx_contracts_company ON contracts(company_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_company ON vehicles(company_id);
CREATE INDEX IF NOT EXISTS idx_pq_documents_company ON pq_documents(company_id);
CREATE INDEX IF NOT EXISTS idx_company_bank_accounts_company ON company_bank_accounts(company_id);

-- RLS für neue Tabellen
ALTER TABLE contracts ENABLE ROW LEVEL SECURITY;
CREATE POLICY contracts_all ON contracts FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);

ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
CREATE POLICY vehicles_all ON vehicles FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);

ALTER TABLE pq_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY pq_documents_all ON pq_documents FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);

ALTER TABLE company_bank_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY company_bank_accounts_all ON company_bank_accounts FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);

ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY chat_rooms_all ON chat_rooms FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);

ALTER TABLE chat_room_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY chat_room_members_all ON chat_room_members FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY chat_messages_all ON chat_messages FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);

-- ============================================================
-- ERGEBNIS
-- ============================================================
-- ✅ users: ~25 neue Spalten für erweiterte Stammdaten
-- ✅ companies: GF-Daten + Adresse aufgeteilt
-- ✅ orders: Auftragsart, Verhandlungsart, Adresse aufgeteilt
-- ✅ company_bank_accounts: Mehrere Bankverbindungen
-- ✅ contracts: Vertragsmanagement mit Fristen
-- ✅ vehicles: Fuhrparkverwaltung
-- ✅ pq_documents: Interne PQ Dokumentenablage
-- ✅ chat_rooms, chat_room_members, chat_messages: Chat-System
