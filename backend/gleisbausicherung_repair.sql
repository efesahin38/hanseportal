-- ============================================================
-- GLEISBAU NUCLEAR POLICY RESET
-- Bu SQL tüm gleisbau policy'lerini siler ve tazedan kurar
-- Supabase SQL Editor → Yeni Query → Çalıştır
-- ============================================================

-- Adım 1: Tüm gleisbau policy'lerini isim bilmeden sil
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename LIKE 'gleisbau_%'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, r.tablename);
    RAISE NOTICE 'Dropped: % on %', r.policyname, r.tablename;
  END LOOP;
END $$;

-- Adım 2: RLS aktif et
ALTER TABLE gleisbau_order_details             ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_rollenbedarf              ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_personal_planung          ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_sakra_checkliste          ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_unterweisungen            ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_unterweisung_bestaetigung ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_ereignisse                ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_ferngespraeche            ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_notizen                   ENABLE ROW LEVEL SECURITY;

-- Adım 3: Temiz policy'ler kur (hem authenticated hem anon)
CREATE POLICY "gb_order_details_open"     ON gleisbau_order_details             FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "gb_rollenbedarf_open"      ON gleisbau_rollenbedarf              FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "gb_personal_planung_open"  ON gleisbau_personal_planung          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "gb_sakra_checkliste_open"  ON gleisbau_sakra_checkliste          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "gb_unterweisungen_open"    ON gleisbau_unterweisungen            FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "gb_bestaetigung_open"      ON gleisbau_unterweisung_bestaetigung FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "gb_ereignisse_open"        ON gleisbau_ereignisse                FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "gb_ferngespraeche_open"    ON gleisbau_ferngespraeche            FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "gb_notizen_open"           ON gleisbau_notizen                   FOR ALL USING (true) WITH CHECK (true);

-- Adım 4: Sütun adını düzelt (ä → ASCII) — hata verirse zaten doğru demektir
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'gleisbau_ferngespraeche'
      AND column_name = 'gespraech_fuehrender_user_id'
  ) THEN
    RAISE NOTICE 'Column already renamed correctly.';
  ELSE
    EXECUTE 'ALTER TABLE gleisbau_ferngespraeche RENAME COLUMN "gespräch_fuehrende_person_id" TO gespraech_fuehrender_user_id';
    RAISE NOTICE 'Column renamed.';
  END IF;
END $$;

-- Adım 5: Diğer eksik kolonlar
ALTER TABLE gleisbau_ferngespraeche ADD COLUMN IF NOT EXISTS erstellt_von  UUID;
ALTER TABLE gleisbau_ferngespraeche ADD COLUMN IF NOT EXISTS geaendert_von UUID;
ALTER TABLE gleisbau_ferngespraeche ADD COLUMN IF NOT EXISTS updated_at    TIMESTAMPTZ DEFAULT now();
ALTER TABLE gleisbau_ereignisse ALTER COLUMN uhrzeit TYPE TEXT USING uhrzeit::TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS db_gleisbau_role TEXT;

-- SONUÇ: Her tabloda tam olarak 1 policy olmalı
SELECT tablename, policyname, cmd FROM pg_policies
WHERE tablename LIKE 'gleisbau_%'
ORDER BY tablename;
