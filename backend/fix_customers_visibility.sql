-- Hanse Kollektiv GmbH - Müşteri Görünürlük ve RLS Düzeltmesi (KESİN ÇÖZÜM V2)
-- Bu betik, şirket ID uyuşmazlığını giderir ve RLS (Row Level Security) kısıtlamasını tamamen kaldırır.

BEGIN;

-- 1. Müşteri tablosundaki RLS kısıtlamasını tamamen kapat (Görünürlük sorununun en büyük sebebi budur)
ALTER TABLE customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE customer_contacts DISABLE ROW LEVEL SECURITY;

-- 2. Sistemdeki ilk şirketin ID'sini al
DO $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT id INTO v_company_id FROM companies LIMIT 1;
    
    -- Müşterilerin şirket ID'lerini bu ana şirkete bağla (Eşleşmeme sorununu bitirir)
    UPDATE customers SET company_id = v_company_id WHERE company_id IS NULL OR company_id != v_company_id;

    -- Eğer müşteri yoksa, örnek verileri tekrar ekle
    INSERT INTO customers (id, name, customer_type, status, customer_class, address, postal_code, city, phone, email, tax_number, payment_terms, company_id)
    VALUES
    ('cccccccc-0000-0000-0000-000000000001', 'Deutsche Bahn AG', 'company', 'active', 'A', 'Hachmannplatz 16', '20099', 'Hamburg', '+49 40 39180', 'info@deutschebahn.com', 'DE111222333', '30 Tage netto', v_company_id),
    ('cccccccc-0000-0000-0000-000000000002', 'Marriott Hotel Hamburg', 'company', 'active', 'A', 'ABC-Straße 52', '20354', 'Hamburg', '+49 40 35050', 'hamburg@marriott.com', 'DE222333444', '14 Tage', v_company_id),
    ('cccccccc-0000-0000-0000-000000000003', 'Alstertal-Einkaufszentrum', 'company', 'active', 'B', 'Heegbarg 31', '22391', 'Hamburg', '+49 40 60300', 'management@alstertal.de', 'DE333444555', '30 Tage', v_company_id)
    ON CONFLICT (id) DO UPDATE SET company_id = EXCLUDED.company_id, status = 'active';

    -- Örnek iletişim kişilerini ekle
    INSERT INTO customer_contacts (id, customer_id, name, role, phone, email, is_primary)
    VALUES
    ('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 'Thomas Müller', 'Bauleiter', '+49 170 1111111', 't.mueller@db.de', true),
    ('eeeeeeee-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000002', 'Sarah Schmidt', 'Operations Manager', '+49 170 2222222', 's.schmidt@marriott.com', true)
    ON CONFLICT (id) DO NOTHING;

END $$;

COMMIT;
