-- ============================================================
-- HANSE KOLLEKTIV – EKSİK RLS POLİTİKALARI VE TRIGGER'LAR
-- Supabase SQL Editor'de çalıştırın
-- ============================================================

-- Yardımcı fonksiyon: mevcut kullanıcının rolünü döner
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS user_role AS $$
  SELECT role FROM users WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Yardımcı fonksiyon: mevcut kullanıcının ID'sini döner
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
  SELECT id FROM users WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Yardımcı fonksiyon: mevcut kullanıcının şirket ID'sini döner
CREATE OR REPLACE FUNCTION current_user_company_id()
RETURNS UUID AS $$
  SELECT company_id FROM users WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Yardımcı fonksiyon: mevcut kullanıcının bölüm ID'sini döner
CREATE OR REPLACE FUNCTION current_user_department_id()
RETURNS UUID AS $$
  SELECT department_id FROM users WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ============================================================
-- CUSTOMERS – RLS
-- ============================================================
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Görüntüleme: tüm aktif kullanıcılar
DROP POLICY IF EXISTS customers_view ON customers;
CREATE POLICY customers_view ON customers
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
  );

-- Mitarbeiter ve Vorarbeiter sadece kendi şirketinin müşterilerini görür
DROP POLICY IF EXISTS customers_company_filter ON customers;
CREATE POLICY customers_company_filter ON customers
  FOR SELECT USING (
    current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'system_admin', 'bereichsleiter', 'buchhaltung', 'backoffice')
    OR (company_id = current_user_company_id())
  );

-- Oluşturma/Güncelleme: yönetim rolleri
DROP POLICY IF EXISTS customers_manage ON customers;
CREATE POLICY customers_manage ON customers
  FOR ALL USING (
    current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'backoffice', 'system_admin')
  );

-- ============================================================
-- CUSTOMER_CONTACTS – RLS
-- ============================================================
ALTER TABLE customer_contacts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS customer_contacts_view ON customer_contacts;
CREATE POLICY customer_contacts_view ON customer_contacts
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
  );
DROP POLICY IF EXISTS customer_contacts_manage ON customer_contacts;
CREATE POLICY customer_contacts_manage ON customer_contacts
  FOR ALL USING (
    current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'backoffice', 'system_admin')
  );

-- ============================================================
-- CUSTOMER_SERVICE_AREAS – RLS
-- ============================================================
ALTER TABLE customer_service_areas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS csa_view ON customer_service_areas;
CREATE POLICY csa_view ON customer_service_areas FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);
DROP POLICY IF EXISTS csa_manage ON customer_service_areas;
CREATE POLICY csa_manage ON customer_service_areas FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'backoffice', 'system_admin')
);

-- ============================================================
-- DEPARTMENTS – RLS
-- ============================================================
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS departments_view ON departments;
CREATE POLICY departments_view ON departments FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);
DROP POLICY IF EXISTS departments_manage ON departments;
CREATE POLICY departments_manage ON departments FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'system_admin')
);

-- ============================================================
-- SERVICE_AREAS – RLS
-- ============================================================
ALTER TABLE service_areas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS service_areas_view ON service_areas;
CREATE POLICY service_areas_view ON service_areas FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);
DROP POLICY IF EXISTS service_areas_manage ON service_areas;
CREATE POLICY service_areas_manage ON service_areas FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'system_admin')
);

-- ============================================================
-- USER_SERVICE_AREAS – RLS
-- ============================================================
ALTER TABLE user_service_areas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS usa_view ON user_service_areas;
CREATE POLICY usa_view ON user_service_areas FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);
DROP POLICY IF EXISTS usa_manage ON user_service_areas;
CREATE POLICY usa_manage ON user_service_areas FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
);

-- ============================================================
-- OPERATION_PLANS – RLS (Bölüm bazlı kısıtlama!)
-- ============================================================
ALTER TABLE operation_plans ENABLE ROW LEVEL SECURITY;

-- Görüntüleme: Bereichsleiter ve üstü kendi bölümünü, Mitarbeiter sadece kendi atamasını
DROP POLICY IF EXISTS operation_plans_view ON operation_plans;
CREATE POLICY operation_plans_view ON operation_plans
  FOR SELECT USING (
    -- Üst yönetim hepsini görür
    current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'system_admin')
    -- Bereichsleiter kendi bölümünü görür
    OR (current_user_role() = 'bereichsleiter' AND EXISTS (
      SELECT 1 FROM orders o WHERE o.id = order_id AND o.department_id = current_user_department_id()
    ))
    -- Vorarbeiter ilgili planı görür (saha sorumlusuysa)
    OR (current_user_role() = 'vorarbeiter' AND site_supervisor_id = current_user_id())
    -- Mitarbeiter kendine atanmış planı görür
    OR EXISTS (
      SELECT 1 FROM operation_plan_personnel opp
      WHERE opp.operation_plan_id = id AND opp.user_id = current_user_id()
    )
    -- Buchhaltung ve backoffice görür
    OR current_user_role() IN ('buchhaltung', 'backoffice')
  );

DROP POLICY IF EXISTS operation_plans_manage ON operation_plans;
CREATE POLICY operation_plans_manage ON operation_plans
  FOR ALL USING (
    current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
  );

-- ============================================================
-- OPERATION_PLAN_PERSONNEL – RLS
-- ============================================================
ALTER TABLE operation_plan_personnel ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS opp_view ON operation_plan_personnel;
CREATE POLICY opp_view ON operation_plan_personnel FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);
DROP POLICY IF EXISTS opp_manage ON operation_plan_personnel;
CREATE POLICY opp_manage ON operation_plan_personnel FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
);

-- ============================================================
-- WORK_SESSIONS – RLS
-- ============================================================
ALTER TABLE work_sessions ENABLE ROW LEVEL SECURITY;

-- Çalışan kendi seansını görür, yöneticiler tümünü
DROP POLICY IF EXISTS work_sessions_view ON work_sessions;
CREATE POLICY work_sessions_view ON work_sessions
  FOR SELECT USING (
    current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin', 'buchhaltung')
    OR user_id = current_user_id()
    OR (current_user_role() = 'vorarbeiter' AND EXISTS (
      SELECT 1 FROM operation_plan_personnel opp
      JOIN operation_plans op ON op.id = opp.operation_plan_id
      WHERE op.id = operation_plan_id AND op.site_supervisor_id = current_user_id()
    ))
  );

-- Mitarbeiter kendi seansını başlatıp bitirebilir
DROP POLICY IF EXISTS work_sessions_own_insert ON work_sessions;
CREATE POLICY work_sessions_own_insert ON work_sessions
  FOR INSERT WITH CHECK (user_id = current_user_id());

DROP POLICY IF EXISTS work_sessions_own_update ON work_sessions;
CREATE POLICY work_sessions_own_update ON work_sessions
  FOR UPDATE USING (
    user_id = current_user_id()
    OR current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
  );

-- ============================================================
-- EXTRA_WORKS – RLS
-- ============================================================
ALTER TABLE extra_works ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS extra_works_view ON extra_works;
CREATE POLICY extra_works_view ON extra_works FOR SELECT USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'vorarbeiter', 'buchhaltung', 'system_admin')
  OR recorded_by = current_user_id()
);
DROP POLICY IF EXISTS extra_works_manage ON extra_works;
CREATE POLICY extra_works_manage ON extra_works FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
  OR recorded_by = current_user_id()
);

-- ============================================================
-- WORK_REPORTS – RLS
-- ============================================================
ALTER TABLE work_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS work_reports_view ON work_reports;
CREATE POLICY work_reports_view ON work_reports FOR SELECT USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'buchhaltung', 'system_admin')
);
DROP POLICY IF EXISTS work_reports_manage ON work_reports;
CREATE POLICY work_reports_manage ON work_reports FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
);

-- ============================================================
-- INVOICE_DRAFTS – RLS
-- ============================================================
ALTER TABLE invoice_drafts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS invoice_drafts_view ON invoice_drafts;
CREATE POLICY invoice_drafts_view ON invoice_drafts FOR SELECT USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'buchhaltung', 'system_admin')
);
DROP POLICY IF EXISTS invoice_drafts_manage ON invoice_drafts;
CREATE POLICY invoice_drafts_manage ON invoice_drafts FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'buchhaltung', 'system_admin')
);

-- ============================================================
-- INVOICE_DRAFT_ITEMS – RLS
-- ============================================================
ALTER TABLE invoice_draft_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS invoice_items_view ON invoice_draft_items;
CREATE POLICY invoice_items_view ON invoice_draft_items FOR SELECT USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'buchhaltung', 'system_admin')
);
DROP POLICY IF EXISTS invoice_items_manage ON invoice_draft_items;
CREATE POLICY invoice_items_manage ON invoice_draft_items FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'buchhaltung', 'system_admin')
);

-- ============================================================
-- CALENDAR_EVENTS – RLS
-- ============================================================
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS calendar_view ON calendar_events;
CREATE POLICY calendar_view ON calendar_events FOR SELECT USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'system_admin')
  OR responsible_user_id = current_user_id()
  OR EXISTS (
    SELECT 1 FROM users WHERE auth_id = auth.uid()
    AND department_id = (SELECT department_id FROM calendar_events ce WHERE ce.id = id LIMIT 1)
  )
  OR current_user_role() IN ('bereichsleiter', 'vorarbeiter', 'buchhaltung', 'backoffice')
);
DROP POLICY IF EXISTS calendar_manage ON calendar_events;
CREATE POLICY calendar_manage ON calendar_events FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
);

-- ============================================================
-- DOCUMENTS – RLS
-- ============================================================
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
-- Rol bazlı görünürlük (visibility_roles alanına göre)
DROP POLICY IF EXISTS documents_view ON documents;
CREATE POLICY documents_view ON documents FOR SELECT USING (
  current_user_role() = ANY(visibility_roles)
  OR current_user_role() IN ('geschaeftsfuehrer', 'system_admin')
);
DROP POLICY IF EXISTS documents_manage ON documents;
CREATE POLICY documents_manage ON documents FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'backoffice', 'system_admin')
);

-- ============================================================
-- ARCHIVE_RECORDS – RLS
-- ============================================================
ALTER TABLE archive_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS archive_view ON archive_records;
CREATE POLICY archive_view ON archive_records FOR SELECT USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'system_admin', 'buchhaltung')
);
DROP POLICY IF EXISTS archive_manage ON archive_records;
CREATE POLICY archive_manage ON archive_records FOR ALL USING (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'system_admin')
);

-- ============================================================
-- NOTIFICATIONS – RLS
-- ============================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
-- Herkes kendi bildirimini görür
DROP POLICY IF EXISTS notifications_own ON notifications;
CREATE POLICY notifications_own ON notifications FOR SELECT USING (
  recipient_id = current_user_id()
  OR current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'system_admin')
);
DROP POLICY IF EXISTS notifications_update ON notifications;
CREATE POLICY notifications_update ON notifications FOR UPDATE USING (
  recipient_id = current_user_id()
);
DROP POLICY IF EXISTS notifications_insert ON notifications;
CREATE POLICY notifications_insert ON notifications FOR INSERT WITH CHECK (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
);

-- ============================================================
-- ORDER_STATUS_HISTORY – RLS
-- ============================================================
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS osh_view ON order_status_history;
CREATE POLICY osh_view ON order_status_history FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);
DROP POLICY IF EXISTS osh_insert ON order_status_history;
CREATE POLICY osh_insert ON order_status_history FOR INSERT WITH CHECK (
  current_user_role() IN ('geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin')
);

-- ============================================================
-- AUDIT_LOGS – RLS
-- ============================================================
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS audit_view ON audit_logs;
CREATE POLICY audit_view ON audit_logs FOR SELECT USING (
  current_user_role() IN ('geschaeftsfuehrer', 'system_admin')
);
DROP POLICY IF EXISTS audit_insert ON audit_logs;
CREATE POLICY audit_insert ON audit_logs FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND status = 'active')
);

-- ============================================================
-- TRIGGER: İş COMPLETED → Otomatik invoice_drafts oluştur
-- ============================================================
CREATE OR REPLACE FUNCTION auto_create_invoice_draft()
RETURNS TRIGGER AS $$
DECLARE
  v_customer RECORD;
  v_order    RECORD;
  v_draft_id UUID;
BEGIN
  -- Sadece 'completed' durumuna geçişte çalış
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Zaten taslak var mı kontrol et
    IF NOT EXISTS (SELECT 1 FROM invoice_drafts WHERE order_id = NEW.id) THEN
      -- Müşteri fatura bilgilerini al
      SELECT * INTO v_customer FROM customers WHERE id = NEW.customer_id;
      SELECT * INTO v_order FROM orders WHERE id = NEW.id;

      INSERT INTO invoice_drafts (
        order_id,
        issuing_company_id,
        customer_id,
        billing_name,
        billing_address,
        billing_tax_number,
        site_address,
        service_date_from,
        service_date_to,
        status,
        notes
      ) VALUES (
        NEW.id,
        NEW.company_id,
        NEW.customer_id,
        v_customer.name,
        COALESCE(v_customer.billing_address, v_customer.address),
        v_customer.tax_number,
        NEW.site_address,
        NEW.planned_start_date,
        NEW.planned_end_date,
        'auto_generated',
        'Otomatik oluşturuldu – lütfen kalemleri düzenleyin.'
      )
      RETURNING id INTO v_draft_id;

      -- Ana hizmet kalemini ekle (placeholder)
      INSERT INTO invoice_draft_items (invoice_draft_id, item_type, description, quantity, unit)
      VALUES (v_draft_id, 'main', v_order.title, 1, 'Pausch.');
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_invoice ON orders;
CREATE TRIGGER trg_auto_invoice
AFTER UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION auto_create_invoice_draft();

-- ============================================================
-- TRIGGER: İş COMPLETED → Otomatik work_reports derle
-- ============================================================
CREATE OR REPLACE FUNCTION auto_compile_work_report()
RETURNS TRIGGER AS $$
DECLARE
  v_total_personnel   INTEGER;
  v_total_actual_h    NUMERIC;
  v_total_billable_h  NUMERIC;
  v_total_extra_h     NUMERIC;
  v_total_extra_works INTEGER;
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Personel sayısı
    SELECT COUNT(DISTINCT user_id) INTO v_total_personnel
    FROM work_sessions WHERE order_id = NEW.id AND status = 'completed';

    -- Süreler
    SELECT
      COALESCE(SUM(actual_duration_h), 0),
      COALESCE(SUM(billable_hours), 0),
      COALESCE(SUM(extra_hours), 0)
    INTO v_total_actual_h, v_total_billable_h, v_total_extra_h
    FROM work_sessions WHERE order_id = NEW.id AND status = 'completed';

    -- Ek işler
    SELECT COUNT(*) INTO v_total_extra_works
    FROM extra_works WHERE order_id = NEW.id;

    -- Raporu upsert et
    INSERT INTO work_reports (
      order_id,
      total_personnel,
      total_actual_hours,
      total_billable_hours,
      total_extra_hours,
      total_extra_works,
      created_by
    ) VALUES (
      NEW.id,
      v_total_personnel,
      v_total_actual_h,
      v_total_billable_h,
      v_total_extra_h,
      v_total_extra_works,
      NEW.responsible_user_id
    )
    ON CONFLICT (order_id) DO UPDATE SET
      total_personnel      = EXCLUDED.total_personnel,
      total_actual_hours   = EXCLUDED.total_actual_hours,
      total_billable_hours = EXCLUDED.total_billable_hours,
      total_extra_hours    = EXCLUDED.total_extra_hours,
      total_extra_works    = EXCLUDED.total_extra_works,
      updated_at           = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_work_report ON orders;
CREATE TRIGGER trg_auto_work_report
AFTER UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION auto_compile_work_report();

-- ============================================================
-- TRIGGER: Operasyon planı SENT → Notifications tablosuna kayıt + takvim
-- ============================================================
CREATE OR REPLACE FUNCTION auto_notify_plan_personnel()
RETURNS TRIGGER AS $$
DECLARE
  v_plan RECORD;
  v_order RECORD;
  v_uid UUID;
BEGIN
  IF NEW.status = 'sent' AND OLD.status IN ('draft', 'confirmed') THEN
    SELECT * INTO v_plan FROM operation_plans WHERE id = NEW.id;
    SELECT * INTO v_order FROM orders WHERE id = v_plan.order_id;

    -- Plan'a atanmış her personele bildirim ekle
    FOR v_uid IN (
      SELECT user_id FROM operation_plan_personnel WHERE operation_plan_id = NEW.id
    ) LOOP
      INSERT INTO notifications (
        recipient_id,
        notification_type,
        title,
        body,
        order_id,
        operation_plan_id,
        sent_by
      ) VALUES (
        v_uid,
        'task_assignment',
        '📋 Yeni Görev Atandı',
        v_order.title || ' – ' || v_plan.plan_date::TEXT || ' ' || v_plan.start_time::TEXT,
        v_order.id,
        NEW.id,
        NEW.planned_by
      );
    END LOOP;

    -- Takvim event'i oluştur (yoksa)
    IF NOT EXISTS (SELECT 1 FROM calendar_events WHERE order_id = v_plan.order_id AND event_date = v_plan.plan_date) THEN
      INSERT INTO calendar_events (
        order_id,
        company_id,
        department_id,
        responsible_user_id,
        title,
        event_date,
        start_time,
        end_time,
        created_by
      )
      SELECT
        v_plan.order_id,
        o.company_id,
        o.department_id,
        v_plan.site_supervisor_id,
        o.title,
        v_plan.plan_date,
        v_plan.start_time,
        v_plan.end_time,
        v_plan.planned_by
      FROM orders o WHERE o.id = v_plan.order_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notify_plan ON operation_plans;
CREATE TRIGGER trg_notify_plan
AFTER UPDATE ON operation_plans
FOR EACH ROW EXECUTE FUNCTION auto_notify_plan_personnel();
