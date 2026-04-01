-- ============================================================
-- WORK SESSION APPROVAL SYSTEM UPDATE
-- ============================================================

-- 1. Create Enum for Approval Status
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'work_session_approval_status') THEN
        CREATE TYPE work_session_approval_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
END $$;

-- 2. Update work_sessions Table
ALTER TABLE work_sessions 
ADD COLUMN IF NOT EXISTS approval_status work_session_approval_status NOT NULL DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS approved_billable_hours NUMERIC(6,2),
ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 3. Update invoice_draft_items to link back to sessions
ALTER TABLE invoice_draft_items 
ADD COLUMN IF NOT EXISTS work_session_id UUID REFERENCES work_sessions(id);
