-- Hanse Kollektiv GmbH - Kapsamlı Veri Kurtarma ve Senkronizasyon Betiği
-- Bu betik, yabancı anahtar (FK) hatalarını giderir, eksik sütunları ekler ve ID'leri standartlaştırır.
-- Supabase SQL Editor üzerinden TEK SEFERDE çalıştırın.

BEGIN; -- İşlemi (Transaction) başlat

-- 1. Müşteri Tablosu Şema Düzeltmesi (Eksik Sütunların Eklenmesi)
ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS bank_name TEXT,
ADD COLUMN IF NOT EXISTS iban TEXT,
ADD COLUMN IF NOT EXISTS bic TEXT,
ADD COLUMN IF NOT EXISTS secondary_contact_name TEXT,
ADD COLUMN IF NOT EXISTS secondary_contact_phone TEXT;

-- 2. Yeni Standart Departmanların Eklenmesi (Eğer yoklarsa)
-- Company ID'yi dinamik olarak bul
DO $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT id INTO v_company_id FROM companies WHERE (name = 'Hanse Kollektiv GmbH' OR short_name = 'Hanse Kollektiv') LIMIT 1;
    
    -- Eğer şirket bulunamazsa hata verir, lütfen şirket adını teyit edin.
    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'Şirket (Hanse Kollektiv) bulunamadı! Lütfen önce şirket kaydını kontrol edin.';
    END IF;

    -- Standart Departmanları Ekle (Conflict durumunda güncelle)
    INSERT INTO departments (id, company_id, name, code)
    VALUES 
        ('dddddddd-1111-1111-1111-111111111111', v_company_id, 'Gebäudereinigung', 'GR'),
        ('dddddddd-2222-2222-2222-222222222222', v_company_id, 'Gleisbausicherung', 'GBS'),
        ('dddddddd-3333-3333-3333-333333333333', v_company_id, 'Hotelservice', 'HS'),
        ('dddddddd-4444-4444-4444-444444444444', v_company_id, 'Buchhaltung', 'BUCH'),
        ('dddddddd-5555-5555-5555-555555555555', v_company_id, 'Verwaltung', 'BO')
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, code = EXCLUDED.code;

    -- 3. Mevcut Kullanıcıları ve İşleri Yeni ID'lere Bağla (İnce Ayar)
    -- Temizlik (GR)
    UPDATE users SET department_id = 'dddddddd-1111-1111-1111-111111111111' 
    WHERE department_id IN (SELECT id FROM departments WHERE code = 'GR' AND id != 'dddddddd-1111-1111-1111-111111111111');
    
    UPDATE orders SET department_id = 'dddddddd-1111-1111-1111-111111111111' 
    WHERE department_id IN (SELECT id FROM departments WHERE code = 'GR' AND id != 'dddddddd-1111-1111-1111-111111111111');

    -- Ray Servis (GBS)
    UPDATE users SET department_id = 'dddddddd-2222-2222-2222-222222222222' 
    WHERE department_id IN (SELECT id FROM departments WHERE code = 'GBS' AND id != 'dddddddd-2222-2222-2222-222222222222');
    
    UPDATE orders SET department_id = 'dddddddd-2222-2222-2222-222222222222' 
    WHERE department_id IN (SELECT id FROM departments WHERE code = 'GBS' AND id != 'dddddddd-2222-2222-2222-222222222222');

    -- Otel Servis (HS)
    UPDATE users SET department_id = 'dddddddd-3333-3333-3333-333333333333' 
    WHERE department_id IN (SELECT id FROM departments WHERE code = 'HS' AND id != 'dddddddd-3333-3333-3333-333333333333');
    
    UPDATE orders SET department_id = 'dddddddd-3333-3333-3333-333333333333' 
    WHERE department_id IN (SELECT id FROM departments WHERE code = 'HS' AND id != 'dddddddd-3333-3333-3333-333333333333');

    -- 4. Temizlik - Yeni ID'lere aktarılmış ama eski ID'si duran departmanları sil
    DELETE FROM departments 
    WHERE id NOT IN (
        'dddddddd-1111-1111-1111-111111111111',
        'dddddddd-2222-2222-2222-222222222222',
        'dddddddd-3333-3333-3333-333333333333',
        'dddddddd-4444-4444-4444-444444444444',
        'dddddddd-5555-5555-5555-555555555555'
    );

END $$;

COMMIT; -- İşlemi tamamla
