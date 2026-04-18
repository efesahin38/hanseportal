-- 1. Yabancı Anahtar Kısıtlamalarını Aşmak İçin Bağlantıları Temizle
-- NOT NULL kısıtlamasını geçici olarak kaldıralım
ALTER TABLE orders ALTER COLUMN service_area_id DROP NOT NULL;
ALTER TABLE orders ALTER COLUMN department_id DROP NOT NULL;

UPDATE users SET department_id = NULL;
UPDATE orders SET department_id = NULL, service_area_id = NULL;
DELETE FROM user_service_areas;
DELETE FROM customer_service_areas;

-- 2. Yapısal Hazırlık
-- service_areas tablosuna departman bağlantısını ekleyelim (Eğer yoksa)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='service_areas' AND column_name='department_id') THEN
        ALTER TABLE service_areas ADD COLUMN department_id UUID REFERENCES departments(id);
    END IF;
END $$;

DELETE FROM service_areas;

-- Departmanları temizleyelim
DELETE FROM departments WHERE code IN ('GR', 'GBS', 'VERW', 'PERS', 'HS');

-- Eğer UNIQUE kısıtlaması yoksa ekleyelim
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'departments_code_key') THEN
        ALTER TABLE departments ADD CONSTRAINT departments_code_key UNIQUE (code);
    END IF;
END $$;

-- 3. Departmanları Güncelle (Hanse Kollektiv GmbH Altında)
INSERT INTO departments (id, company_id, name, code) VALUES
('11111111-0000-0000-0000-000000000001', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' LIMIT 1), 'Gebäudereinigung', 'GR'),
('22222222-0000-0000-0000-000000000001', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' LIMIT 1), 'Gleisbausicherung', 'GBS'),
('33333333-0000-0000-0000-000000000001', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' LIMIT 1), 'Verwaltung', 'VERW'),
('44444444-0000-0000-0000-000000000001', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' LIMIT 1), 'Personalüberlassung', 'PERS'),
('55555555-0000-0000-0000-000000000001', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' LIMIT 1), 'Hotelservice', 'HS');

-- 4. Hizmet Alanlarını Oluştur
INSERT INTO service_areas (id, department_id, name, code, description) VALUES
('11112222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Gebäudereinigung', 'gebaeudereinigung', 'Bina temizlik hizmetleri'),
('11112222-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000001', 'Gleisbausicherung', 'gleisbausicherung', 'Ray iş güvenliği hizmetleri'),
('11112222-0000-0000-0000-000000000003', '33333333-0000-0000-0000-000000000001', 'Verwaltung', 'verwaltung', 'Ofis ve yönetim hizmetleri'),
('11112222-0000-0000-0000-000000000004', '44444444-0000-0000-0000-000000000001', 'Personalüberlassung', 'personalueberlassung', 'Personel temin hizmetleri'),
('11112222-0000-0000-0000-000000000005', '55555555-0000-0000-0000-000000000001', 'Hotelservice', 'hotelservice', 'Otel destek hizmetleri');

-- 5. Kullanıcı Sorumluluk Atamaları
UPDATE users SET department_id = '11111111-0000-0000-0000-000000000001' WHERE id = 'bbbbbbbb-0000-0000-0000-000000000004'; -- Sandra
UPDATE users SET department_id = '22222222-0000-0000-0000-000000000001' WHERE id = 'bbbbbbbb-0000-0000-0000-000000000006'; -- Peter
UPDATE users SET department_id = '33333333-0000-0000-0000-000000000001' WHERE id = 'bbbbbbbb-0000-0000-0000-000000000017'; -- Martina
UPDATE users SET department_id = '44444444-0000-0000-0000-000000000001' WHERE id = 'bbbbbbbb-0000-0000-0000-000000000002'; -- Klaus
UPDATE users SET department_id = '55555555-0000-0000-0000-000000000001' WHERE id = 'bbbbbbbb-0000-0000-0000-000000000005'; -- Fatma

-- 6. İşleri Varsayılan Olarak 'Diğer/Temizlik' Branşına Atayalım (Veri kaybını önlemek için)
UPDATE orders SET service_area_id = '11112222-0000-0000-0000-000000000001' WHERE service_area_id IS NULL;
UPDATE orders SET department_id = '11111111-0000-0000-0000-000000000001' WHERE department_id IS NULL;

-- Kısıtlamaları geri ekleyelim
ALTER TABLE orders ALTER COLUMN service_area_id SET NOT NULL;
ALTER TABLE orders ALTER COLUMN department_id SET NOT NULL;

-- 7. Mevcut İşleri Yeni Hizmet Alanlarına Bağla (Opsiyonel)
UPDATE orders SET service_area_id = '11112222-0000-0000-0000-000000000001' WHERE service_area_id IN (SELECT id FROM service_areas WHERE code = 'gebaeudereinigung');
-- ...diğerleri için de benzeri yapılabilir.
