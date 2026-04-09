-- ═══════════════════════════════════════════════════════════════
-- HansePortal: Formulare v2.0 — with approval system
-- Run this in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- Drop and recreate to add missing columns
CREATE TABLE IF NOT EXISTS order_forms (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id         UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  form_type        TEXT NOT NULL CHECK (form_type IN (
                     'bereichsfreigabe',
                     'qualitaetskontrolle',
                     'stundenlohn',
                     'maengelliste',
                     'tagesrapport'
                   )),
  status           TEXT NOT NULL DEFAULT 'nicht_begonnen'
                     CHECK (status IN ('nicht_begonnen','in_bearbeitung','fertig')),
  data             JSONB NOT NULL DEFAULT '{}',
  -- Approval
  is_approved      BOOLEAN NOT NULL DEFAULT false,
  approved_by      UUID REFERENCES users(id),
  approved_at      TIMESTAMPTZ,
  -- Audit
  created_by       UUID REFERENCES users(id),
  updated_by       UUID REFERENCES users(id),
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  UNIQUE (order_id, form_type)
);

-- Add approval columns if table already exists
ALTER TABLE order_forms ADD COLUMN IF NOT EXISTS is_approved BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE order_forms ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id);
ALTER TABLE order_forms ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_order_forms_order_id ON order_forms(order_id);

CREATE OR REPLACE FUNCTION update_order_forms_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_forms_updated_at ON order_forms;
CREATE TRIGGER trg_order_forms_updated_at
  BEFORE UPDATE ON order_forms
  FOR EACH ROW EXECUTE FUNCTION update_order_forms_updated_at();

ALTER TABLE order_forms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "order_forms_all" ON order_forms;
CREATE POLICY "order_forms_all" ON order_forms FOR ALL USING (true) WITH CHECK (true);
