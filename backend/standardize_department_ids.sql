-- Hanse Kollektiv GmbH - Departman ID'lerinin Standardizasyonu
-- Supabase SQL Editor'da çalıştırın.

-- Önce mevcut departmanları silelim (veya ID'lerini güncelleyelim - silme daha temiz seed için)
DELETE FROM departments;

-- Sabit ID'li departmanlar (Flutter tarafı ile uyumlu)
-- Temizlik (dddddddd-1111-1111-1111-111111111111)
-- Ray Servis (dddddddd-2222-2222-2222-222222222222)
-- İnşaat Servis (dddddddd-3333-3333-3333-333333333333)
-- Muhasebe (dddddddd-4444-4444-4444-444444444444)
-- Otel Servis (dddddddd-5555-5555-5555-555555555555)

INSERT INTO departments (id, company_id, name, code) VALUES
  ('dddddddd-1111-1111-1111-111111111111', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' OR short_name = 'Hanse Kollektiv' LIMIT 1), 'Gebäudereinigung', 'GR'),
  ('dddddddd-2222-2222-2222-222222222222', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' OR short_name = 'Hanse Kollektiv' LIMIT 1), 'Gleisbausicherung', 'GBS'),
  ('dddddddd-3333-3333-3333-333333333333', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' OR short_name = 'Hanse Kollektiv' LIMIT 1), 'Hotelservice', 'HS'),
  ('dddddddd-4444-4444-4444-444444444444', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' OR short_name = 'Hanse Kollektiv' LIMIT 1), 'Buchhaltung', 'BUCH'),
  ('dddddddd-5555-5555-5555-555555555555', (SELECT id FROM companies WHERE name = 'Hanse Kollektiv GmbH' OR short_name = 'Hanse Kollektiv' LIMIT 1), 'Verwaltung', 'BO');

-- NOT: Eğer bu departmanlara bağlı 'orders' veya 'users' varsa, onların department_id alanlarını da güncellemeniz gerekir.
