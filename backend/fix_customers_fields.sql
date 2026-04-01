-- Hanse Kollektiv GmbH - Müşteri Finansal ve İletişim Verileri Güncellemesi
-- Supabase SQL Editor'da çalıştırın.

ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS bank_name TEXT,
ADD COLUMN IF NOT EXISTS iban TEXT,
ADD COLUMN IF NOT EXISTS bic TEXT,
ADD COLUMN IF NOT EXISTS secondary_contact_name TEXT,
ADD COLUMN IF NOT EXISTS secondary_contact_phone TEXT;

-- Gerekli yetkilerin verildiğinden emin olun (RLS politikaları gereği)
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
-- (Not: Mevcut politikalarınızın bu yeni sütunları da kapsadığını teyit edin)
