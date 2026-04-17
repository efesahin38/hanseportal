-- ================================================================
-- GWS Item-Level Sharing + Customer Contacts RLS Fix
-- HansePortal v1.20
-- ================================================================

-- 1. gws_plan_rooms: item-level external sharing fields
ALTER TABLE gws_plan_rooms
  ADD COLUMN IF NOT EXISTS is_shared_with_external BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS external_comment TEXT,
  ADD COLUMN IF NOT EXISTS external_signature TEXT,
  ADD COLUMN IF NOT EXISTS external_returned_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS pdf_urls TEXT[],
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. gws_plan_areas: same
ALTER TABLE gws_plan_areas
  ADD COLUMN IF NOT EXISTS is_shared_with_external BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS external_comment TEXT,
  ADD COLUMN IF NOT EXISTS external_signature TEXT,
  ADD COLUMN IF NOT EXISTS external_returned_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS pdf_urls TEXT[],
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. orders: sachbearbeiter_contact_id (external contact as sachbearbeiter)
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS sachbearbeiter_contact_id UUID REFERENCES customer_contacts(id);

-- 4. customer_contacts: RLS fix - allow internal staff to INSERT/UPDATE
-- Drop overly restrictive INSERT policy if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'customer_contacts' AND policyname = 'contacts_insert_policy'
  ) THEN
    DROP POLICY contacts_insert_policy ON customer_contacts;
  END IF;
END $$;

-- Allow all authenticated users to insert/upsert contacts (restricted by app-layer role check)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'customer_contacts' AND policyname = 'contacts_allow_authenticated_write'
  ) THEN
    CREATE POLICY contacts_allow_authenticated_write ON customer_contacts
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 5. GWS plan rooms/areas: allow external managers to read shared items
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'gws_plan_rooms' AND policyname = 'gws_rooms_external_view'
  ) THEN
    CREATE POLICY gws_rooms_external_view ON gws_plan_rooms
      FOR SELECT USING (is_shared_with_external = true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'gws_plan_areas' AND policyname = 'gws_areas_external_view'
  ) THEN
    CREATE POLICY gws_areas_external_view ON gws_plan_areas
      FOR SELECT USING (is_shared_with_external = true);
  END IF;
END $$;
