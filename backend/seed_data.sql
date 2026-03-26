-- ============================================================
-- HANSE KOLLEKTIV GmbH – TEST / SEED VERİSİ
-- schema_new.sql çalıştırıldıktan SONRA bu dosyayı çalıştırın
-- Tarih: Mart 2026
-- ============================================================

-- ============================================================
-- 0. YARDIMCI MAKROLAR – Sabit UUID'ler (kolay referans için)
-- ============================================================
-- Şirketler
-- c_hanse     = 'aaaaaaaa-0000-0000-0000-000000000001'  (Hanse Kollektiv GmbH - zaten var)
-- c_hanse_s   = 'aaaaaaaa-0000-0000-0000-000000000002'  (Hanse Service UG)
-- c_hanse_r   = 'aaaaaaaa-0000-0000-0000-000000000003'  (Hanse Rail KG)

-- Kullanıcılar
-- u_patron    = 'bbbbbbbb-0000-0000-0000-000000000001'  (geschaeftsfuehrer)
-- u_ops1      = 'bbbbbbbb-0000-0000-0000-000000000002'  (betriebsleiter)
-- u_ops2      = 'bbbbbbbb-0000-0000-0000-000000000003'  (betriebsleiter)
-- u_bl1       = 'bbbbbbbb-0000-0000-0000-000000000004'  (bereichsleiter)
-- u_bl2       = 'bbbbbbbb-0000-0000-0000-000000000005'  (bereichsleiter)
-- u_bl3       = 'bbbbbbbb-0000-0000-0000-000000000006'  (bereichsleiter)
-- u_va1 .. u_va3  (vorarbeiter)
-- u_ma1 .. u_ma4  (mitarbeiter)
-- u_buch1..3  (buchhaltung)
-- u_bo1..3    (backoffice)
-- u_sa1       (system_admin)

-- ============================================================
-- 1. EK ŞİRKETLER
-- ============================================================
INSERT INTO companies (
  id, name, short_name, company_type, relation_type, parent_company_id,
  address, postal_code, city, country,
  phone, email, website,
  tax_number, vat_number, trade_register_number, trade_register_court,
  bank_name, iban, bic,
  service_description, status
) VALUES
(
  'aaaaaaaa-0000-0000-0000-000000000002',
  'Hanse Service UG',
  'Hanse Service',
  'UG',
  'subsidiary',
  (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' LIMIT 1),
  'Reeperbahn 55', '20359', 'Hamburg', 'Deutschland',
  '+49 40 123456-20', 'service@hanse-kollektiv.de', 'https://hanse-service.de',
  '123/456/78901', 'DE123456789', 'HRB 98765', 'Amtsgericht Hamburg',
  'Deutsche Bank', 'DE89370400440000123456', 'COBADEFFXXX',
  'Gebäudereinigung, Hotelservice ve Personalüberlassung hizmetleri',
  'active'
),
(
  'aaaaaaaa-0000-0000-0000-000000000003',
  'Hanse Rail Sicherung KG',
  'Hanse Rail',
  'KG',
  'subsidiary',
  (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' LIMIT 1),
  'Bahnhofstr. 12', '20095', 'Hamburg', 'Deutschland',
  '+49 40 123456-30', 'rail@hanse-kollektiv.de', 'https://hanse-rail.de',
  '123/456/78902', 'DE234567890', 'HRB 98766', 'Amtsgericht Hamburg',
  'Commerzbank', 'DE27200400300000345678', 'DRESDEFF200',
  'Gleisbausicherung ve tren yolu güvenliği hizmetleri',
  'active'
);

-- ============================================================
-- 2. BÖLÜMLER
-- ============================================================
INSERT INTO departments (company_id, name, code) VALUES
  ((SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'), 'Geschäftsführung',     'GF'),
  ((SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'), 'Buchhaltung',          'BUCH'),
  ((SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'), 'Backoffice',           'BO'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'Gebäudereinigung',    'GR'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'Hotelservice',        'HS'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'Gleisbausicherung',   'GBS');

-- ============================================================
-- 3. KULLANICILAR – Tüm 8 Rol
-- ============================================================

-- Geschäftsführer (Patron) – 1 kişi
INSERT INTO users (id, first_name, last_name, email, phone, company_id, role, position_title, status, employment_type, pin_code)
VALUES
('bbbbbbbb-0000-0000-0000-000000000001', 'Mehmet', 'Yıldırım', 'mehmet.yildirim@hanse-kollektiv.de', '+49 170 1234567',
  (SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'),
  'geschaeftsfuehrer', 'Geschäftsführer', 'active', 'Vollzeit', '0001');

-- Betriebsleiter (Operasyon Müdürü) – 2 kişi
INSERT INTO users (id, first_name, last_name, email, phone, company_id, role, position_title, status, employment_type, manager_id, pin_code)
VALUES
('bbbbbbbb-0000-0000-0000-000000000002', 'Klaus', 'Bauer', 'k.bauer@hanse-kollektiv.de', '+49 171 2345678',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'betriebsleiter', 'Betriebsleiter Reinigung', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000001', '0002'),

('bbbbbbbb-0000-0000-0000-000000000003', 'Thomas', 'Müller', 't.mueller@hanse-kollektiv.de', '+49 171 3456789',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'betriebsleiter', 'Betriebsleiter Rail', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000001', '0003');

-- Bereichsleiter (Bölüm Sorumlusu) – 3 kişi
INSERT INTO users (id, first_name, last_name, email, phone, company_id, role, position_title, status, employment_type, manager_id, pin_code)
VALUES
('bbbbbbbb-0000-0000-0000-000000000004', 'Sandra', 'Hoffmann', 's.hoffmann@hanse-service.de', '+49 172 4567890',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'bereichsleiter', 'Bereichsleiter Gebäudereinigung', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000002', '0004'),

('bbbbbbbb-0000-0000-0000-000000000005', 'Fatma', 'Yılmaz', 'f.yilmaz@hanse-service.de', '+49 172 5678901',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'bereichsleiter', 'Bereichsleiter Hotelservice', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000002', '0005'),

('bbbbbbbb-0000-0000-0000-000000000006', 'Peter', 'Schmidt', 'p.schmidt@hanse-rail.de', '+49 172 6789012',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'bereichsleiter', 'Bereichsleiter Gleisbausicherung', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000003', '0006');

-- Vorarbeiter (Ustabaşı / Saha Sorumlusu) – 3 kişi
INSERT INTO users (id, first_name, last_name, email, phone, company_id, role, position_title, status, employment_type, manager_id, pin_code)
VALUES
('bbbbbbbb-0000-0000-0000-000000000007', 'Hasan', 'Demir', 'h.demir@hanse-service.de', '+49 176 7890123',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'vorarbeiter', 'Vorarbeiter Reinigung', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000004', '0007'),

('bbbbbbbb-0000-0000-0000-000000000008', 'İbrahim', 'Kaya', 'i.kaya@hanse-service.de', '+49 176 8901234',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'vorarbeiter', 'Vorarbeiter Hotel', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000005', '0008'),

('bbbbbbbb-0000-0000-0000-000000000009', 'Markus', 'Weber', 'm.weber@hanse-rail.de', '+49 176 9012345',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'vorarbeiter', 'Vorarbeiter Rail', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000006', '0009');

-- Mitarbeiter (Saha Çalışanı) – 4 kişi
INSERT INTO users (id, first_name, last_name, email, phone, company_id, role, position_title, status, employment_type, manager_id, pin_code)
VALUES
('bbbbbbbb-0000-0000-0000-000000000010', 'Ali', 'Çelik', 'a.celik@hanse-service.de', '+49 177 0123456',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'mitarbeiter', 'Reinigungskraft', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000007', '1010'),

('bbbbbbbb-0000-0000-0000-000000000011', 'Ayşe', 'Arslan', 'a.arslan@hanse-service.de', '+49 177 1234567',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'mitarbeiter', 'Reinigungskraft', 'active', 'Teilzeit',
  'bbbbbbbb-0000-0000-0000-000000000007', '1011'),

('bbbbbbbb-0000-0000-0000-000000000012', 'Mehmet', 'Kurt', 'm.kurt@hanse-service.de', '+49 177 2345678',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'mitarbeiter', 'Hoteldiener', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000008', '1012'),

('bbbbbbbb-0000-0000-0000-000000000013', 'Sabine', 'Becker', 's.becker@hanse-rail.de', '+49 177 3456789',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'mitarbeiter', 'Sicherungsposten', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000009', '1013');

-- Buchhaltung (Muhasebe) – 3 kişi
INSERT INTO users (id, first_name, last_name, email, phone, company_id, role, position_title, status, employment_type, manager_id, pin_code)
VALUES
('bbbbbbbb-0000-0000-0000-000000000014', 'Gisela', 'Koch', 'g.koch@hanse-kollektiv.de', '+49 178 4567890',
  (SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'),
  'buchhaltung', 'Leiterin Buchhaltung', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000001', '1414'),

('bbbbbbbb-0000-0000-0000-000000000015', 'Ursula', 'Braun', 'u.braun@hanse-kollektiv.de', '+49 178 5678901',
  (SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'),
  'buchhaltung', 'Buchhalter', 'active', 'Teilzeit',
  'bbbbbbbb-0000-0000-0000-000000000014', '1515'),

('bbbbbbbb-0000-0000-0000-000000000016', 'Emre', 'Şahin', 'e.sahin@hanse-kollektiv.de', '+49 178 6789012',
  (SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'),
  'buchhaltung', 'Buchhalter', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000014', '1616');

-- Backoffice (Büro / Verwaltung) – 3 kişi
INSERT INTO users (id, first_name, last_name, email, phone, company_id, role, position_title, status, employment_type, manager_id, pin_code)
VALUES
('bbbbbbbb-0000-0000-0000-000000000017', 'Martina', 'Schulz', 'm.schulz@hanse-kollektiv.de', '+49 179 7890123',
  (SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'),
  'backoffice', 'Verwaltungsleiterin', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000001', '1717'),

('bbbbbbbb-0000-0000-0000-000000000018', 'Lisa', 'Wagner', 'l.wagner@hanse-kollektiv.de', '+49 179 8901234',
  (SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'),
  'backoffice', 'Sachbearbeiterin', 'active', 'Teilzeit',
  'bbbbbbbb-0000-0000-0000-000000000017', '1818'),

('bbbbbbbb-0000-0000-0000-000000000019', 'Zeynep', 'Öztürk', 'z.ozturk@hanse-kollektiv.de', '+49 179 9012345',
  (SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'),
  'backoffice', 'Sachbearbeiterin', 'active', 'Vollzeit',
  'bbbbbbbb-0000-0000-0000-000000000017', '1919');

-- System Admin – 1 kişi
INSERT INTO users (id, first_name, last_name, email, company_id, role, position_title, status, employment_type, pin_code)
VALUES
('bbbbbbbb-0000-0000-0000-000000000020', 'Admin', 'System', 'admin@hanse-kollektiv.de',
  (SELECT id FROM companies WHERE short_name = 'Hanse Kollektiv'),
  'system_admin', 'IT / System Administrator', 'active', 'Vollzeit', '9999');

-- ============================================================
-- 4. PERSONEL – HİZMET ALANI YETKİNLİKLERİ
-- ============================================================
INSERT INTO user_service_areas (user_id, service_area_id)
SELECT u.id, sa.id
FROM users u, service_areas sa
WHERE u.id = 'bbbbbbbb-0000-0000-0000-000000000007' -- Hasan Demir (Vorarbeiter Reinigung)
  AND sa.code IN ('gebaeudereinigung','personalueberlassung');

INSERT INTO user_service_areas (user_id, service_area_id)
SELECT u.id, sa.id
FROM users u, service_areas sa
WHERE u.id = 'bbbbbbbb-0000-0000-0000-000000000008' -- İbrahim Kaya (Vorarbeiter Hotel)
  AND sa.code IN ('hotelservice','personalueberlassung');

INSERT INTO user_service_areas (user_id, service_area_id)
SELECT u.id, sa.id
FROM users u, service_areas sa
WHERE u.id = 'bbbbbbbb-0000-0000-0000-000000000009' -- Markus Weber (Vorarbeiter Rail)
  AND sa.code IN ('gleisbausicherung');

INSERT INTO user_service_areas (user_id, service_area_id)
SELECT u.id, sa.id
FROM users u, service_areas sa
WHERE u.id IN ('bbbbbbbb-0000-0000-0000-000000000010','bbbbbbbb-0000-0000-0000-000000000011')
  AND sa.code = 'gebaeudereinigung';

INSERT INTO user_service_areas (user_id, service_area_id)
SELECT u.id, sa.id
FROM users u, service_areas sa
WHERE u.id = 'bbbbbbbb-0000-0000-0000-000000000012'
  AND sa.code = 'hotelservice';

INSERT INTO user_service_areas (user_id, service_area_id)
SELECT u.id, sa.id
FROM users u, service_areas sa
WHERE u.id = 'bbbbbbbb-0000-0000-0000-000000000013'
  AND sa.code = 'gleisbausicherung';

-- ============================================================
-- 5. MÜŞTERİLER / İŞVERENLER
-- ============================================================
INSERT INTO customers (id, name, customer_type, status, customer_class, address, postal_code, city,
  phone, email, tax_number, payment_terms, company_id, notes)
VALUES
('cccccccc-0000-0000-0000-000000000001',
  'Hamburg Hauptbahnhof – DB Station & Service AG',
  'public_institution', 'active', 'A',
  'Hachmannplatz 10', '20099', 'Hamburg',
  '+49 40 3918-0', 'service@hamburg-hbf.de', '200/123/45678',
  '30 Tage netto',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'Gleisbausicherung ana müşterisi. Haftatda 3 gün ekip gerekli.'),

('cccccccc-0000-0000-0000-000000000002',
  'Maritim Hotel Hamburg',
  'company', 'active', 'A',
  'Holzdamm 4', '20099', 'Hamburg',
  '+49 40 24833-0', 'info@maritim-hamburg.de', '200/234/56789',
  '14 Tage netto',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'Günlük temizlik ve zaman zaman ekstra ekip talebi gelir.'),

('cccccccc-0000-0000-0000-000000000003',
  'Elbe Einkaufszentrum GmbH',
  'company', 'active', 'B',
  'Osterstraße 120', '22769', 'Hamburg',
  '+49 40 800070-0', 'facility@elbe-einkaufszentrum.de', '200/345/67890',
  '30 Tage netto',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'AVM genel temizlik ve güvenlik hizmetleri.'),

('cccccccc-0000-0000-0000-000000000004',
  'Altonaer Krankenhaus GmbH',
  'public_institution', 'active', 'A',
  'Paul-Ehrlich-Str. 1', '22763', 'Hamburg',
  '+49 40 88908-0', 'facility@altonaer-kh.de', '200/456/78901',
  '45 Tage netto',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'Hastane temizliği – yüksek hijyen standardı zorunlu.'),

('cccccccc-0000-0000-0000-000000000005',
  'HHLA – Hamburger Hafen und Logistik AG',
  'company', 'potential', 'B',
  'Bei St. Annen 1', '20457', 'Hamburg',
  '+49 40 3088-0', 'info@hhla.de', '200/567/89012',
  '30 Tage netto',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'Potansiyel müşteri – teklif aşamasında.');

-- ============================================================
-- 6. MÜŞTERİ MUHATAPLARİ
-- ============================================================
INSERT INTO customer_contacts (customer_id, name, role, phone, email, is_primary) VALUES
  ('cccccccc-0000-0000-0000-000000000001', 'Karl Heinz Richter',   'Bauleiter',         '+49 160 1111111', 'richter@db-station.de',       true),
  ('cccccccc-0000-0000-0000-000000000001', 'Anna Müller',          'Projektkoordinator','+49 160 2222222', 'a.mueller@db-station.de',     false),
  ('cccccccc-0000-0000-0000-000000000002', 'Petra Schmitz',        'Housekeeping-Chef', '+49 160 3333333', 'p.schmitz@maritim.de',        true),
  ('cccccccc-0000-0000-0000-000000000002', 'Günter Lang',          'Einkauf',           '+49 160 4444444', 'g.lang@maritim.de',           false),
  ('cccccccc-0000-0000-0000-000000000003', 'Bernd Wolf',           'Facility Manager',  '+49 160 5555555', 'b.wolf@elbe-einkauf.de',      true),
  ('cccccccc-0000-0000-0000-000000000004', 'Dr. Inge Fischer',     'Verwaltungsleiterin','+49 160 6666666','i.fischer@altonaer-kh.de',   true),
  ('cccccccc-0000-0000-0000-000000000005', 'Steffen Krause',       'Einkauf & Vergabe', '+49 160 7777777', 's.krause@hhla.de',            true);

-- ============================================================
-- 7. MÜŞTERİ – HİZMET ALANI BAĞLANTILARI
-- ============================================================
INSERT INTO customer_service_areas (customer_id, service_area_id)
SELECT 'cccccccc-0000-0000-0000-000000000001', id FROM service_areas WHERE code = 'gleisbausicherung';
INSERT INTO customer_service_areas (customer_id, service_area_id)
SELECT 'cccccccc-0000-0000-0000-000000000002', id FROM service_areas WHERE code IN ('hotelservice','gebaeudereinigung');
INSERT INTO customer_service_areas (customer_id, service_area_id)
SELECT 'cccccccc-0000-0000-0000-000000000003', id FROM service_areas WHERE code = 'gebaeudereinigung';
INSERT INTO customer_service_areas (customer_id, service_area_id)
SELECT 'cccccccc-0000-0000-0000-000000000004', id FROM service_areas WHERE code = 'gebaeudereinigung';
INSERT INTO customer_service_areas (customer_id, service_area_id)
SELECT 'cccccccc-0000-0000-0000-000000000005', id FROM service_areas WHERE code = 'gleisbausicherung';

-- ============================================================
-- 8. İŞLER / SİPARİŞLER
-- ============================================================
INSERT INTO orders (id, order_number, company_id, customer_id, service_area_id,
  title, short_description, site_address, status, priority,
  planned_start_date, planned_end_date, created_by)
VALUES
-- Tamamlanmış iş
('dddddddd-0000-0000-0000-000000000001',
  'ORD-2026-00001',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'cccccccc-0000-0000-0000-000000000001',
  (SELECT id FROM service_areas WHERE code='gleisbausicherung'),
  'HH Hauptbahnhof – Gleis 3/4 Sicherung Wochenende',
  'Hafta sonu Gleis 3 ve 4 bakım çalışması sırasında gleisbausicherung hizmeti',
  'Hachmannplatz 10, 20099 Hamburg',
  'completed', 'high',
  '2026-03-14', '2026-03-15',
  'bbbbbbbb-0000-0000-0000-000000000002'),

-- Aktif iş (uygulamada)
('dddddddd-0000-0000-0000-000000000002',
  'ORD-2026-00002',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'cccccccc-0000-0000-0000-000000000002',
  (SELECT id FROM service_areas WHERE code='hotelservice'),
  'Maritim Hotel – Mart 2026 Günlük Hizmet',
  'Oda temizliği ve restoran servisi destek ekibi',
  'Holzdamm 4, 20099 Hamburg',
  'in_progress', 'normal',
  '2026-03-01', '2026-03-31',
  'bbbbbbbb-0000-0000-0000-000000000002'),

-- Planlamada olan iş
('dddddddd-0000-0000-0000-000000000003',
  'ORD-2026-00003',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'cccccccc-0000-0000-0000-000000000003',
  (SELECT id FROM service_areas WHERE code='gebaeudereinigung'),
  'Elbe Einkaufszentrum – Yıllık Genel Temizlik',
  'Pasaj ve ortak alanların derinlemesine yıllık temizliği',
  'Osterstraße 120, 22769 Hamburg',
  'planning', 'normal',
  '2026-04-05', '2026-04-06',
  'bbbbbbbb-0000-0000-0000-000000000002'),

-- Onaylandı, planlanmayı bekliyor
('dddddddd-0000-0000-0000-000000000004',
  'ORD-2026-00004',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'cccccccc-0000-0000-0000-000000000004',
  (SELECT id FROM service_areas WHERE code='gebaeudereinigung'),
  'Altonaer Krankenhaus – Haftalık Klinik Temizlik',
  'Ameliyathane koridoru ve yoğun bakım alanı haftalık temizlik',
  'Paul-Ehrlich-Str. 1, 22763 Hamburg',
  'approved', 'urgent',
  '2026-03-28', '2026-12-31',
  'bbbbbbbb-0000-0000-0000-000000000004'),

-- Taslak – yeni oluşturulmuş
('dddddddd-0000-0000-0000-000000000005',
  'ORD-2026-00005',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'cccccccc-0000-0000-0000-000000000001',
  (SELECT id FROM service_areas WHERE code='gleisbausicherung'),
  'DB – Nisan Bakım Çalışması Güvenlik',
  'Nisan ayı planlı bakım için Gleis 7-8 gleisbausicherung',
  'Hachmannplatz 10, 20099 Hamburg',
  'draft', 'normal',
  '2026-04-12', '2026-04-13',
  'bbbbbbbb-0000-0000-0000-000000000003'),

-- Faturalandı
('dddddddd-0000-0000-0000-000000000006',
  'ORD-2026-00006',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'cccccccc-0000-0000-0000-000000000002',
  (SELECT id FROM service_areas WHERE code='hotelservice'),
  'Maritim Hotel – Şubat 2026 Hizmet',
  'Şubat ayı oda servisi ve temizlik desteği',
  'Holzdamm 4, 20099 Hamburg',
  'invoiced', 'normal',
  '2026-02-01', '2026-02-28',
  'bbbbbbbb-0000-0000-0000-000000000002');

-- ============================================================
-- 9. İŞ DURUM GEÇMİŞİ
-- ============================================================
INSERT INTO order_status_history (order_id, old_status, new_status, changed_by, note) VALUES
  ('dddddddd-0000-0000-0000-000000000001', 'draft',       'created',      'bbbbbbbb-0000-0000-0000-000000000002', 'İş oluşturuldu'),
  ('dddddddd-0000-0000-0000-000000000001', 'created',     'approved',     'bbbbbbbb-0000-0000-0000-000000000001', 'Patron onayladı'),
  ('dddddddd-0000-0000-0000-000000000001', 'approved',    'planning',     'bbbbbbbb-0000-0000-0000-000000000004', 'Plan hazırlanıyor'),
  ('dddddddd-0000-0000-0000-000000000001', 'planning',    'in_progress',  'bbbbbbbb-0000-0000-0000-000000000007', 'Sabah ekip sahaya geçti'),
  ('dddddddd-0000-0000-0000-000000000001', 'in_progress', 'completed',    'bbbbbbbb-0000-0000-0000-000000000006', 'İş başarıyla tamamlandı'),
  ('dddddddd-0000-0000-0000-000000000002', 'draft',       'created',      'bbbbbbbb-0000-0000-0000-000000000002', 'Aylık hizmet başlatıldı'),
  ('dddddddd-0000-0000-0000-000000000002', 'created',     'in_progress',  'bbbbbbbb-0000-0000-0000-000000000005', 'Mart başında aktif'),
  ('dddddddd-0000-0000-0000-000000000006', 'completed',   'invoiced',     'bbbbbbbb-0000-0000-0000-000000000014', 'Fatura kesildi');

-- ============================================================
-- 10. OPERASYONPLANLARİ
-- ============================================================
INSERT INTO operation_plans (id, order_id, plan_date, start_time, end_time,
  estimated_duration_h, site_supervisor_id, planned_by, status,
  site_instructions, equipment_notes)
VALUES
-- ORD-001 için tamamlanmış plan (14 Mart 2026)
('eeeeeeee-0000-0000-0000-000000000001',
  'dddddddd-0000-0000-0000-000000000001',
  '2026-03-14', '06:00:00', '14:00:00', 8.0,
  'bbbbbbbb-0000-0000-0000-000000000009',  -- Markus Weber saha sorumlusu
  'bbbbbbbb-0000-0000-0000-000000000006',
  'confirmed',
  'Gleis 3 ve 4 tamamen kapatılmalı. Kırmızı bayrak ve levhalar yerleştirilecek. Güvenlik yelek zorunlu.',
  'Kırmızı bayrak x6, reflektif yelek x3, düdük x3'),

-- ORD-001 için tamamlanmış plan (15 Mart 2026)
('eeeeeeee-0000-0000-0000-000000000002',
  'dddddddd-0000-0000-0000-000000000001',
  '2026-03-15', '07:00:00', '13:00:00', 6.0,
  'bbbbbbbb-0000-0000-0000-000000000009',
  'bbbbbbbb-0000-0000-0000-000000000006',
  'confirmed',
  'Gleis 4 tek yönlü trafiğe açılacak. Tüm ekip yerleşimde olacak.',
  'Bayrak x4, yelek x3'),

-- ORD-002 için aktif plan (26 Mart 2026)
('eeeeeeee-0000-0000-0000-000000000003',
  'dddddddd-0000-0000-0000-000000000002',
  '2026-03-26', '08:00:00', '16:00:00', 8.0,
  'bbbbbbbb-0000-0000-0000-000000000008',  -- İbrahim Kaya saha sorumlusu
  'bbbbbbbb-0000-0000-0000-000000000004',
  'confirmed',
  'Kat 3, 4 ve 5 odaları öncelikli. VIP suit 301 ekstra özen. Kimyasal doz düşük tutulacak.',
  'Temizlik arabası x2, kimyasal set, oda levhası'),

-- ORD-002 için yarın planı (27 Mart 2026) – taslak
('eeeeeeee-0000-0000-0000-000000000004',
  'dddddddd-0000-0000-0000-000000000002',
  '2026-03-27', '08:00:00', '16:00:00', 8.0,
  'bbbbbbbb-0000-0000-0000-000000000008',
  'bbbbbbbb-0000-0000-0000-000000000004',
  'draft',
  'Tüm katlar standart temizlik. Toplantı salonu ekstra silme.',
  NULL);

-- ============================================================
-- 11. OPERASYONPLANİ – PERSONEL ATAMASI
-- ============================================================
INSERT INTO operation_plan_personnel (operation_plan_id, user_id, assigned_by, is_supervisor)
VALUES
  -- Plan 1 (Gleis 14 Mart) personeli
  ('eeeeeeee-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000006', true),
  ('eeeeeeee-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000013', 'bbbbbbbb-0000-0000-0000-000000000006', false),
  -- Plan 2 (Gleis 15 Mart)
  ('eeeeeeee-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000006', true),
  ('eeeeeeee-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000013', 'bbbbbbbb-0000-0000-0000-000000000006', false),
  -- Plan 3 (Hotel 26 Mart)
  ('eeeeeeee-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000004', true),
  ('eeeeeeee-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000004', false),
  ('eeeeeeee-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000004', false),
  -- Plan 4 (Hotel 27 Mart) – taslak
  ('eeeeeeee-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000004', true),
  ('eeeeeeee-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000004', false);

-- ============================================================
-- 12. ÇALIŞMA SEANSLARİ (work_sessions)
-- ============================================================
INSERT INTO work_sessions (order_id, operation_plan_id, user_id,
  actual_start, actual_end, billable_hours, extra_hours,
  status, note)
VALUES
-- ORD-001 – 14 Mart – Markus Weber
('dddddddd-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001',
  'bbbbbbbb-0000-0000-0000-000000000009',
  '2026-03-14 06:05:00+01', '2026-03-14 14:20:00+01', 8.0, 0.25,
  'completed', 'Normal akış, küçük gecikme tren dolayısıyla'),

-- ORD-001 – 14 Mart – Sabine Becker
('dddddddd-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001',
  'bbbbbbbb-0000-0000-0000-000000000013',
  '2026-03-14 06:00:00+01', '2026-03-14 14:00:00+01', 8.0, 0.0,
  'completed', NULL),

-- ORD-001 – 15 Mart – Markus Weber
('dddddddd-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002',
  'bbbbbbbb-0000-0000-0000-000000000009',
  '2026-03-15 07:00:00+01', '2026-03-15 13:10:00+01', 6.0, 0.17,
  'completed', NULL),

-- ORD-001 – 15 Mart – Sabine Becker
('dddddddd-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002',
  'bbbbbbbb-0000-0000-0000-000000000013',
  '2026-03-15 07:00:00+01', '2026-03-15 13:00:00+01', 6.0, 0.0,
  'completed', NULL),

-- ORD-002 – 26 Mart – İbrahim Kaya (aktif seans)
('dddddddd-0000-0000-0000-000000000002', 'eeeeeeee-0000-0000-0000-000000000003',
  'bbbbbbbb-0000-0000-0000-000000000008',
  '2026-03-26 08:02:00+01', NULL, NULL, NULL,
  'started', NULL),

-- ORD-002 – 26 Mart – Mehmet Kurt
('dddddddd-0000-0000-0000-000000000002', 'eeeeeeee-0000-0000-0000-000000000003',
  'bbbbbbbb-0000-0000-0000-000000000012',
  '2026-03-26 08:05:00+01', NULL, NULL, NULL,
  'started', NULL),

-- ORD-002 – 26 Mart – Ali Çelik
('dddddddd-0000-0000-0000-000000000002', 'eeeeeeee-0000-0000-0000-000000000003',
  'bbbbbbbb-0000-0000-0000-000000000010',
  '2026-03-26 08:00:00+01', NULL, NULL, NULL,
  'started', NULL);

-- ============================================================
-- 13. EK İŞLER
-- ============================================================
INSERT INTO extra_works (order_id, title, description, work_date,
  duration_h, is_billable, estimated_material_cost, estimated_labor_cost,
  status, recorded_by, notes)
VALUES
('dddddddd-0000-0000-0000-000000000001',
  'Acil Ek Güvenlik – Plansız Tren Geçişi',
  '14 Mart akşamı plansız bir yük treni geçişi oldu. 2 saat ek bekleme gerekti.',
  '2026-03-14',
  2.0, true, NULL, 120.0,
  'approved',
  'bbbbbbbb-0000-0000-0000-000000000009',
  'DB tarafından onaylandı. Faturalandırılacak.'),

('dddddddd-0000-0000-0000-000000000002',
  'VIP Suite Ekstra Hazırlık',
  'Suite 301 için çiçek düzenlemesi ve ekstra havlu seti kurulumu istendi.',
  '2026-03-20',
  1.0, true, 35.0, 45.0,
  'pending_approval',
  'bbbbbbbb-0000-0000-0000-000000000008',
  'Müşteri email olarak onay istedi.');

-- ============================================================
-- 14. İŞ SONU RAPORLARI
-- ============================================================
INSERT INTO work_reports (order_id, total_actual_hours, total_billable_hours,
  total_extra_hours, total_extra_works,
  summary_note, quality_note, customer_feedback,
  total_revenue, estimated_labor_cost,
  is_finalized, created_by)
VALUES
('dddddddd-0000-0000-0000-000000000001',
  28.42, 28.0, 0.42, 1,
  'Gleis 3/4 bakım güvenliği başarıyla tamamlandı. Ekip zamanında ve eksiksiz.',
  'Güvenlik protokolleri tam uygulandı. DB denetçisi memnuniyetini bildirdi.',
  'Sehr gut – DB Bauleiter K.H. Richter',
  3500.0, 1200.0,
  true, 'bbbbbbbb-0000-0000-0000-000000000006');

-- ============================================================
-- 15. ÖN FATURA TASLAKLARI
-- ============================================================
INSERT INTO invoice_drafts (id, order_id, issuing_company_id, customer_id,
  draft_number, status,
  billing_address,
  tax_rate, subtotal, tax_amount, total_amount,
  service_date_from, service_date_to, payment_terms,
  accounting_note)
VALUES
-- ORD-006 (Şubat Maritim – faturalandı)
('ffffffff-0000-0000-0000-000000000001',
  'dddddddd-0000-0000-0000-000000000006',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'cccccccc-0000-0000-0000-000000000002',
  'RE-2026-00001', 'invoiced',
  'Maritim Hotel Hamburg, Holzdamm 4, 20099 Hamburg',
  19.0, 4200.0, 798.0, 4998.0,
  '2026-02-01', '2026-02-28', '14 Tage netto',
  'Ödeme 15 Mart 2026''da alındı.'),

-- ORD-001 (Mart Gleis – onay bekliyor)
('ffffffff-0000-0000-0000-000000000002',
  'dddddddd-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'cccccccc-0000-0000-0000-000000000001',
  'RE-2026-00002', 'under_review',
  'DB Station & Service AG, Hachmannplatz 10, 20099 Hamburg',
  19.0, 3500.0, 665.0, 4165.0,
  '2026-03-14', '2026-03-15', '30 Tage netto',
  'Ek iş tutarı dahil edildi. Onay bekleniyor.');

-- Fatura Kalemler
INSERT INTO invoice_draft_items (invoice_draft_id, item_type, description,
  quantity, unit, unit_price, total_price, sort_order)
VALUES
-- RE-2026-00001 kalemleri
('ffffffff-0000-0000-0000-000000000001', 'main',
  'Februar 2026 – Täglicher Hotelservice (Oda Temizliği)', 29, 'Einsatz', 120.0, 3480.0, 1),
('ffffffff-0000-0000-0000-000000000001', 'main',
  'Februar 2026 – Personalüberlassung 3 Mitarbeiter', 4, 'Woche', 180.0, 720.0, 2),

-- RE-2026-00002 kalemleri
('ffffffff-0000-0000-0000-000000000002', 'main',
  '14.03.2026 – Gleisbausicherung Gleis 3/4 (8 Std.)', 2, 'Person/Tag', 850.0, 1700.0, 1),
('ffffffff-0000-0000-0000-000000000002', 'main',
  '15.03.2026 – Gleisbausicherung Gleis 4 (6 Std.)', 2, 'Person/Tag', 780.0, 1560.0, 2),
('ffffffff-0000-0000-0000-000000000002', 'extra',
  'Ek: Plansız Tren Geçişi Güvenlik (2 Std.)', 1, 'Pauschale', 240.0, 240.0, 3);

-- ============================================================
-- 16. BİLDİRİMLER
-- ============================================================
INSERT INTO notifications (recipient_id, title, body, notification_type, is_read, order_id, operation_plan_id)
VALUES
  ('bbbbbbbb-0000-0000-0000-000000000007', '🔔 Yeni İş Atandı', 'Altonaer Krankenhaus temizliği için 28 Mart''tan itibaren görevlendirildiniz.', 'task_assignment', false,
    'dddddddd-0000-0000-0000-000000000004', NULL),
  ('bbbbbbbb-0000-0000-0000-000000000008', '📅 Yarın Plan Hazır', '27 Mart Maritim Hotel planı oluşturuldu. Lütfen inceleyin.', 'task_assignment', false,
    'dddddddd-0000-0000-0000-000000000002', 'eeeeeeee-0000-0000-0000-000000000004'),
  ('bbbbbbbb-0000-0000-0000-000000000009', '✅ Plan Onaylandı', '14 Mart Gleis 3/4 planınız onaylandı.', 'task_update', true,
    'dddddddd-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001'),
  ('bbbbbbbb-0000-0000-0000-000000000014', '💶 Onay Bekleyen Fatura', 'RE-2026-00002 numaralı taslak fatura inceleme bekliyor.', 'reminder', false,
    'dddddddd-0000-0000-0000-000000000001', NULL),
  ('bbbbbbbb-0000-0000-0000-000000000001', '⚠️ Acil İş', 'Altonaer Krankenhaus URGENT öncelikli atandı.', 'task_update', false,
    'dddddddd-0000-0000-0000-000000000004', NULL);

-- ============================================================
-- ÖZET
-- ============================================================
-- Şirket        : 3 (1 parent, 2 subsidiary)
-- Kullanıcı     : 20 (tüm 8 rol kapsandı)
-- Müşteri       : 5 (4 aktif, 1 potansiyel)
-- İş            : 6 (taslaktan faturalandıya tüm durumlar)
-- OperasyonPlan : 4
-- ÇalışmaSeans  : 7 (3 aktif, 4 tamamlanmış)
-- Ek İş         : 2
-- İş Raporu     : 1 (finalize edilmiş)
-- Ön Fatura     : 2 (biri faturalandı, biri incelemede)
-- Bildirim      : 5
-- ============================================================
