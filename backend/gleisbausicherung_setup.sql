-- ============================================================
-- DB-GLEISBAUSICHERUNG MODULE SETUP v19.8.1
-- HansePortal — Run this ONCE in Supabase SQL Editor
-- ============================================================

-- 1. Add DB-Gleisbausicherung role field to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS db_gleisbau_role TEXT;
-- Possible values: 'sakra','sipo','buep','sesi','sas','hib',
--                  'bahnerder','sbahn_kurzschliess','bediener_monteur',
--                  'raeumer','planer_pruefer'

-- ============================================================
-- 2. Gleisbau extended order data
-- ============================================================
CREATE TABLE IF NOT EXISTS gleisbau_order_details (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE UNIQUE NOT NULL,
  -- Einsatzort
  arbeitsstelle_typ TEXT,
  strecke TEXT,
  betriebsstelle TEXT,
  gleisbezeichnung TEXT,
  km_von TEXT,
  km_bis TEXT,
  arbeitsbereich_beschreibung TEXT,
  oertliche_besonderheiten TEXT,
  -- Zeitliche Daten
  meldezeit TIME,
  vorbereitungszeit_min INT,
  -- Sicherungsrelevant
  sicherungsplan_vorhanden BOOLEAN DEFAULT false,
  sicherungsplan_nummer TEXT,
  betra_vorhanden BOOLEAN DEFAULT false,
  betra_nummer TEXT,
  arbeiten_im_gleis BOOLEAN DEFAULT false,
  arbeiten_neben_gleis BOOLEAN DEFAULT false,
  arbeiten_nachbargleis BOOLEAN DEFAULT false,
  maschinen_einsatz BOOLEAN DEFAULT false,
  oberleitungsbezug BOOLEAN DEFAULT false,
  schaltbedarf BOOLEAN DEFAULT false,
  warnsystem TEXT,
  raeumzeit_min INT,
  -- Logistik
  zugang TEXT,
  eintrittsstelle TEXT,
  sammelpunkt TEXT,
  sicherheitsraum TEXT,
  rettungsweg TEXT,
  logistik_hinweise TEXT,
  -- Flags
  dokumente_vollstaendig BOOLEAN DEFAULT false,
  unterweisung_abgeschlossen BOOLEAN DEFAULT false,
  checkliste_abgeschlossen BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. Rollenbedarf per Auftrag
-- ============================================================
CREATE TABLE IF NOT EXISTS gleisbau_rollenbedarf (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  rolle TEXT NOT NULL,
  anzahl INT DEFAULT 1,
  besetzt INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (order_id, rolle)
);

-- ============================================================
-- 4. Personal-Planung pro Einsatz
-- ============================================================
CREATE TABLE IF NOT EXISTS gleisbau_personal_planung (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  gleisbau_rolle TEXT NOT NULL,
  anwesenheit_bestaetigt BOOLEAN DEFAULT false,
  unterweisung_bestaetigt BOOLEAN DEFAULT false,
  einsatz_bestaetigt BOOLEAN DEFAULT false,
  einsatz_ende_bestaetigt BOOLEAN DEFAULT false,
  assigned_by UUID REFERENCES users(id),
  assigned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (order_id, user_id)
);

-- ============================================================
-- 5. SAKRA Pflichtcheckliste
-- ============================================================
CREATE TABLE IF NOT EXISTS gleisbau_sakra_checkliste (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE UNIQUE NOT NULL,
  sakra_user_id UUID REFERENCES users(id),
  sicherungsplan_geprueft BOOLEAN DEFAULT false,
  dokumente_vollstaendig BOOLEAN DEFAULT false,
  team_vollstaendig BOOLEAN DEFAULT false,
  qualifikationen_plausibel BOOLEAN DEFAULT false,
  maschinen_geprueft BOOLEAN DEFAULT false,
  geraete_geprueft BOOLEAN DEFAULT false,
  warnmittel_geprueft BOOLEAN DEFAULT false,
  psa_geprueft BOOLEAN DEFAULT false,
  kommunikation_geprueft BOOLEAN DEFAULT false,
  zugang_klar BOOLEAN DEFAULT false,
  sicherheitsraeume_bekannt BOOLEAN DEFAULT false,
  unterweisung_durchgefuehrt BOOLEAN DEFAULT false,
  bestaetigung_vollstaendig BOOLEAN DEFAULT false,
  notizen TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 6. Unterweisungsmodul
-- ============================================================
CREATE TABLE IF NOT EXISTS gleisbau_unterweisungen (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE UNIQUE NOT NULL,
  unterweisender_user_id UUID REFERENCES users(id),
  datum DATE,
  uhrzeit TIME,
  ort TEXT,
  inhalt_arbeitsstelle BOOLEAN DEFAULT false,
  inhalt_gefahren BOOLEAN DEFAULT false,
  inhalt_sicherungsmassnahmen BOOLEAN DEFAULT false,
  inhalt_sicherheitsraeume BOOLEAN DEFAULT false,
  inhalt_warnmittel BOOLEAN DEFAULT false,
  inhalt_zustaendigkeiten BOOLEAN DEFAULT false,
  inhalt_ereignisfall BOOLEAN DEFAULT false,
  inhalt_besonderheiten BOOLEAN DEFAULT false,
  inhalt_maschinen BOOLEAN DEFAULT false,
  freitext_inhalte TEXT,
  abgeschlossen BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Teilnehmer-Bestaetigung (one row per user per Unterweisung)
CREATE TABLE IF NOT EXISTS gleisbau_unterweisung_bestaetigung (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unterweisung_id UUID REFERENCES gleisbau_unterweisungen(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) NOT NULL,
  bestaetigt BOOLEAN DEFAULT false,
  bestaetigt_at TIMESTAMPTZ,
  rueckfragen TEXT,
  UNIQUE (unterweisung_id, user_id)
);

-- ============================================================
-- 7. Ereignisse (Einsatzverlauf)
-- ============================================================
CREATE TABLE IF NOT EXISTS gleisbau_ereignisse (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  ereignis_typ TEXT NOT NULL,
  -- 'einsatz_begonnen','einsatz_unterbrochen','einsatz_fortgesetzt',
  -- 'problem_gemeldet','behinderung','personal_abweichung',
  -- 'geraete_abweichung','sicherheitsrelevant','einsatz_beendet'
  datum DATE,
  uhrzeit TEXT,  -- stored as text HH:mm to avoid timezone issues
  meldende_person_id UUID REFERENCES users(id),
  kurzbeschreibung TEXT,
  dringlichkeit TEXT DEFAULT 'normal',  -- 'normal','hoch','kritisch'
  eskalation_erforderlich BOOLEAN DEFAULT false,
  bild_url TEXT,
  ferngespräch_id UUID,  -- optional link to Ferngesprach
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 8. Digitales Ferngesprächsbuch (ASCII column names!)
-- ============================================================
CREATE TABLE IF NOT EXISTS gleisbau_ferngespraeche (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  datum DATE NOT NULL,
  uhrzeit TEXT NOT NULL,  -- HH:mm as text
  gespraech_fuehrender_user_id UUID REFERENCES users(id),  -- ASCII column name!
  gegenstelle_name TEXT NOT NULL,
  gegenstelle_funktion TEXT,
  kategorie TEXT NOT NULL,
  -- 'arbeitsbeginn','arbeitsende','unterbrechung','sicherheit',
  -- 'personal','geraet','schalt','einsatzaenderung','stoerfall','notfall','organisatorisch'
  kurzbetreff TEXT NOT NULL,
  gespraechsinhalt TEXT NOT NULL,
  ergebnis_massnahme TEXT,
  ergebnis_typ TEXT,
  -- 'nur_dokumentiert','anweisung','rueckruf','massnahme','eskalation','abschluss'
  dauer_min INT,
  dringlichkeit TEXT DEFAULT 'normal',
  sicherheitsrelevant BOOLEAN DEFAULT false,
  abrechnungsrelevant BOOLEAN DEFAULT false,
  folgeaktion_erforderlich BOOLEAN DEFAULT false,
  folgeaktion_bis DATE,
  anhang_url TEXT,
  ereignis_id UUID REFERENCES gleisbau_ereignisse(id),
  erstellt_von UUID REFERENCES users(id),
  geaendert_von UUID REFERENCES users(id),
  geaendert_am TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 9. SAKRA interne Notizen
-- ============================================================
CREATE TABLE IF NOT EXISTS gleisbau_notizen (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id),
  inhalt TEXT NOT NULL,
  medien_url TEXT,
  medien_typ TEXT,  -- 'bild','pdf','dokument'
  ist_sicherheitsrelevant BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- RLS: Enable & Allow authenticated users full access
-- (App-layer RBAC handles restrictions via AppState roles)
-- ============================================================
ALTER TABLE gleisbau_order_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_rollenbedarf ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_personal_planung ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_sakra_checkliste ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_unterweisungen ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_unterweisung_bestaetigung ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_ereignisse ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_ferngespraeche ENABLE ROW LEVEL SECURITY;
ALTER TABLE gleisbau_notizen ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  -- gleisbau_order_details
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gleisbau_order_details' AND policyname = 'gleisbau_order_details_auth') THEN
    CREATE POLICY "gleisbau_order_details_auth" ON gleisbau_order_details FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  -- gleisbau_rollenbedarf
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gleisbau_rollenbedarf' AND policyname = 'gleisbau_rollenbedarf_auth') THEN
    CREATE POLICY "gleisbau_rollenbedarf_auth" ON gleisbau_rollenbedarf FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  -- gleisbau_personal_planung
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gleisbau_personal_planung' AND policyname = 'gleisbau_personal_planung_auth') THEN
    CREATE POLICY "gleisbau_personal_planung_auth" ON gleisbau_personal_planung FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  -- gleisbau_sakra_checkliste
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gleisbau_sakra_checkliste' AND policyname = 'gleisbau_sakra_checkliste_auth') THEN
    CREATE POLICY "gleisbau_sakra_checkliste_auth" ON gleisbau_sakra_checkliste FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  -- gleisbau_unterweisungen
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gleisbau_unterweisungen' AND policyname = 'gleisbau_unterweisungen_auth') THEN
    CREATE POLICY "gleisbau_unterweisungen_auth" ON gleisbau_unterweisungen FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  -- gleisbau_unterweisung_bestaetigung
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gleisbau_unterweisung_bestaetigung' AND policyname = 'gleisbau_unterweisung_bestaetigung_auth') THEN
    CREATE POLICY "gleisbau_unterweisung_bestaetigung_auth" ON gleisbau_unterweisung_bestaetigung FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  -- gleisbau_ereignisse
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gleisbau_ereignisse' AND policyname = 'gleisbau_ereignisse_auth') THEN
    CREATE POLICY "gleisbau_ereignisse_auth" ON gleisbau_ereignisse FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  -- gleisbau_ferngespraeche
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gleisbau_ferngespraeche' AND policyname = 'gleisbau_ferngespraeche_auth') THEN
    CREATE POLICY "gleisbau_ferngespraeche_auth" ON gleisbau_ferngespraeche FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  -- gleisbau_notizen
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gleisbau_notizen' AND policyname = 'gleisbau_notizen_auth') THEN
    CREATE POLICY "gleisbau_notizen_auth" ON gleisbau_notizen FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ============================================================
-- TEST USERS — 1 per Gleisbausicherung role (for testing)
-- ============================================================
-- Step 1: Get your company UUID: SELECT id, name FROM companies;
-- Step 2: Uncomment and run the block below, replacing YOUR_COMPANY_UUID
--
/*
INSERT INTO users (id, first_name, last_name, email, role, db_gleisbau_role, status, company_id, password)
VALUES
  (gen_random_uuid(), 'Klaus',  'Müller',   'sakra@test.hanse.de',    'vorarbeiter',    'sakra',              'active', 'YOUR_COMPANY_UUID', '1234'),
  (gen_random_uuid(), 'Peter',  'Schmidt',  'sipo@test.hanse.de',     'mitarbeiter',    'sipo',               'active', 'YOUR_COMPANY_UUID', '1234'),
  (gen_random_uuid(), 'Hans',   'Weber',    'buep@test.hanse.de',     'mitarbeiter',    'buep',               'active', 'YOUR_COMPANY_UUID', '1234'),
  (gen_random_uuid(), 'Anna',   'Fischer',  'sesi@test.hanse.de',     'mitarbeiter',    'sesi',               'active', 'YOUR_COMPANY_UUID', '1234'),
  (gen_random_uuid(), 'Martin', 'Bauer',    'sas@test.hanse.de',      'vorarbeiter',    'sas',                'active', 'YOUR_COMPANY_UUID', '1234'),
  (gen_random_uuid(), 'Lukas',  'Koch',     'hib@test.hanse.de',      'mitarbeiter',    'hib',                'active', 'YOUR_COMPANY_UUID', '1234'),
  (gen_random_uuid(), 'Erik',   'Richter',  'bahnerder@test.hanse.de','mitarbeiter',    'bahnerder',          'active', 'YOUR_COMPANY_UUID', '1234'),
  (gen_random_uuid(), 'Stefan', 'Hoffmann', 'raeumer@test.hanse.de',  'mitarbeiter',    'raeumer',            'active', 'YOUR_COMPANY_UUID', '1234'),
  (gen_random_uuid(), 'Julia',  'Schäfer',  'planer@test.hanse.de',   'bereichsleiter', 'planer_pruefer',     'active', 'YOUR_COMPANY_UUID', '1234'),
  (gen_random_uuid(), 'Max',    'Wagner',   'monteur@test.hanse.de',  'mitarbeiter',    'bediener_monteur',   'active', 'YOUR_COMPANY_UUID', '1234');
*/

SELECT 'DB-Gleisbausicherung v19.8.1 tables ready!' AS status;
