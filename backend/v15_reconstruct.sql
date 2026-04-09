-- ============================================================
-- HANSEPORTAL v15.0 - RECONSTRUCTION SCRIPT
-- 1. Reset Chat History (Clean Start)
-- 2. Setup Exactly 5 Companies
-- 3. Map Departments to New Structure
-- ============================================================

BEGIN;

-- 1. RESET CHAT & PURGE LEGACY DATA
TRUNCATE TABLE chat_messages CASCADE;
TRUNCATE TABLE chat_room_members CASCADE;
TRUNCATE TABLE chat_rooms CASCADE;

-- Legacy Şirketleri Sil (Sicherung KG ve Arşiv)
DELETE FROM companies WHERE name ILIKE '%Arşiv%' OR name ILIKE '%Sicherung KG%';

-- 2. UPSERT COMPANIES (Tam 5 Şirket)
-- Hanse Kollektiv GmbH (Parent)
UPDATE companies 
SET name = 'Hanse Kollektiv GmbH', 
    short_name = 'Kollektiv',
    status = 'active'
WHERE id = 'df273582-8308-478e-95b2-88387d9629bc' OR name = 'Hanse Kollektiv GmbH';

-- Diğer 4 Alt Şirket
INSERT INTO companies (id, name, short_name, status, relation_type, parent_company_id)
VALUES 
    ('aaaaaaaa-1111-1111-1111-c00000000001', 'Hanse Gebäudedienstleistungen GmbH', 'Gebäudedienstleistungen', 'active', 'subsidiary', 'df273582-8308-478e-95b2-88387d9629bc'),
    ('aaaaaaaa-1111-1111-1111-c00000000002', 'Hanse Rail Service GmbH', 'Rail Service', 'active', 'subsidiary', 'df273582-8308-478e-95b2-88387d9629bc'),
    ('aaaaaaaa-1111-1111-1111-c00000000003', 'Hanse Gastwirtschaftsservice GmbH', 'Gastwirtschaftsservice', 'active', 'subsidiary', 'df273582-8308-478e-95b2-88387d9629bc'),
    ('aaaaaaaa-1111-1111-1111-c00000000004', 'Hanse Personalüberlassung GmbH', 'Personalüberlassung', 'active', 'subsidiary', 'df273582-8308-478e-95b2-88387d9629bc')
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name, 
    short_name = EXCLUDED.short_name,
    status = 'active';

-- 3. DEPARTMANLARI YENİ ŞİRKETLERE BAĞLA
-- Gebäudedienstleistungen (Sandra)
UPDATE departments SET company_id = 'aaaaaaaa-1111-1111-1111-c00000000001' WHERE code = 'GR';

-- Rail Service (Peter)
UPDATE departments SET company_id = 'aaaaaaaa-1111-1111-1111-c00000000002' WHERE code = 'GBS';

-- Gastwirtschaftsservice (Fatma) - Eski Hotelservice (HS) kodunu burada kullanıyoruz
UPDATE departments SET company_id = 'aaaaaaaa-1111-1111-1111-c00000000003', name = 'Gastwirtschaftsservice' WHERE code = 'HS';

-- 4. KULLANICILARI ŞİRKETLERE SENKRONİZE ET
-- Her kullanıcının bağlı olduğu departmanın şirket ID'sini kullanıcının kendi company_id alanına yaz
UPDATE users u
SET company_id = d.company_id
FROM departments d
WHERE u.department_id = d.id;

-- Hanse Kollektiv Adminleri için manuel eşleme (Eğer departmanları yoksa)
UPDATE users 
SET company_id = 'df273582-8308-478e-95b2-88387d9629bc' 
WHERE role IN ('system_admin', 'geschaeftsfuehrer', 'buchhaltung') 
  AND company_id IS NULL;

COMMIT;
