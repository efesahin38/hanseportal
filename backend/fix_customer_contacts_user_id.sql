-- 1. customer_contacts tablosuna user_id ekle
-- Bu alan, bir iletişim kişisinin sistemde bir kullanıcı (örn: External Manager) olup olmadığını belirtir.

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'customer_contacts' AND column_name = 'user_id') THEN
        ALTER TABLE customer_contacts ADD COLUMN user_id UUID REFERENCES users(id);
    END IF;
END $$;

-- 2. Index ekleyelim (performans için)
CREATE INDEX IF NOT EXISTS idx_customer_contacts_user_id ON customer_contacts(user_id);

-- 3. RLS Politikası Güncelleme
-- External Manager'ların kendi kontak bilgilerini görebilmesi için (gerekirse)
ALTER TABLE customer_contacts ENABLE ROW LEVEL SECURITY;

-- Halihazırda admin/gs politikaları varsa onları bozmadan ekliyoruz
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'contacts_external_manager_view') THEN
        CREATE POLICY contacts_external_manager_view ON customer_contacts
        FOR SELECT USING (user_id = auth.uid());
    END IF;
END $$;
