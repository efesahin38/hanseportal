-- ============================================================
-- MITARBEITER DOKUMENTEN-VERWALTUNG
-- Çalışan Belge Yönetim Sistemi
-- Supabase SQL Editor'de çalıştırın
-- ============================================================

-- 1. Çalışan Belge Klasörleri Tablosu
CREATE TABLE IF NOT EXISTS employee_document_folders (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  folder_key    TEXT NOT NULL,       -- 'arbeitsvertrag', 'gehaltsabrechnung', vb.
  folder_name   TEXT NOT NULL,       -- Almanca UI etiketi
  folder_icon   TEXT,                -- Opsiyonel ikon adı
  sort_order    INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(employee_id, folder_key)
);

-- 2. Çalışan Belgeleri Tablosu
CREATE TABLE IF NOT EXISTS employee_documents (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  folder_id     UUID NOT NULL REFERENCES employee_document_folders(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  file_url      TEXT NOT NULL,
  file_name     TEXT,
  file_size_kb  INTEGER,
  file_mime     TEXT,
  uploaded_by   UUID REFERENCES users(id),
  notes         TEXT,
  uploaded_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Index'ler (performans)
CREATE INDEX IF NOT EXISTS idx_emp_doc_folders_employee ON employee_document_folders(employee_id);
CREATE INDEX IF NOT EXISTS idx_emp_documents_folder ON employee_documents(folder_id);
CREATE INDEX IF NOT EXISTS idx_emp_documents_employee ON employee_documents(employee_id);

-- ============================================================
-- 4. FONKSİYON: Çalışan için 10 standart klasör oluşturur
--    (Flutter tarafından çağrılır, ya da mevcut kullanıcılar için manuel çalıştırılır)
-- ============================================================
CREATE OR REPLACE FUNCTION create_employee_standard_folders(p_employee_id UUID)
RETURNS VOID AS $$
BEGIN
  INSERT INTO employee_document_folders (employee_id, folder_key, folder_name, sort_order)
  VALUES
    (p_employee_id, 'arbeitsvertrag',     'Arbeitsvertrag',                  1),
    (p_employee_id, 'gehaltsabrechnung',  'Gehaltsabrechnung',               2),
    (p_employee_id, 'personaldokumente',  'Personaldokumente',               3),
    (p_employee_id, 'krankenversicherung','Krankenversicherung',              4),
    (p_employee_id, 'steuerunterlagen',   'Steuerunterlagen',                5),
    (p_employee_id, 'bescheinigungen',    'Bescheinigungen',                 6),
    (p_employee_id, 'fuehrerschein',      'Führerschein / Qualifikationen',  7),
    (p_employee_id, 'arbeitszeit_urlaub', 'Arbeitszeit & Urlaub',            8),
    (p_employee_id, 'abmahnungen',        'Abmahnungen / Disziplin',         9),
    (p_employee_id, 'sonstige',           'Sonstige Dokumente',              10)
  ON CONFLICT (employee_id, folder_key) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 5. TRIGGER: Yeni kullanıcı eklendiğinde otomatik klasör oluşturur
-- ============================================================
CREATE OR REPLACE FUNCTION trigger_create_employee_folders()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM create_employee_standard_folders(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_new_user_create_folders ON users;
CREATE TRIGGER on_new_user_create_folders
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION trigger_create_employee_folders();

-- ============================================================
-- 6. MEVCUT KULLANICILAR İÇİN: Tüm mevcut kullanıcılara klasör oluştur
--    (Bu script'i bir kez çalıştırın – mevcut çalışanlara klasör atar)
-- ============================================================
DO $$
DECLARE
  u RECORD;
BEGIN
  FOR u IN SELECT id FROM users LOOP
    PERFORM create_employee_standard_folders(u.id);
  END LOOP;
END;
$$;

-- ============================================================
-- KONTROL: Kaç klasör oluşturuldu?
-- ============================================================
SELECT 
  u.id,
  u.first_name || ' ' || u.last_name AS full_name,
  COUNT(f.id) AS klasor_sayisi
FROM users u
LEFT JOIN employee_document_folders f ON f.employee_id = u.id
GROUP BY u.id, full_name
ORDER BY full_name;
