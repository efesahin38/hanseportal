-- ============================================================
-- HANSE KOLLEKTIV – Personnel Visibility Fix
-- Each manager can see all employees in their company to allow assignment
-- ============================================================

-- First, drop the existing view policy if it's too restrictive or if we want to replace it
-- Note: users_admin already exists for ALL access, we just need a broader SELECT access.

DROP POLICY IF EXISTS users_view_company ON users;
CREATE POLICY users_view_company ON users
  FOR SELECT USING (
    -- Management roles can see everyone in their company
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
      AND u.role IN ('geschaeftsfuehrer', 'betriebsleiter', 'system_admin', 'bereichsleiter', 'backoffice', 'buchhaltung')
      AND u.status = 'active'
    )
    AND (company_id = current_user_company_id())
  );

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
