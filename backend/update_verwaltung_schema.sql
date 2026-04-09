-- ============================================================
-- HANSEPORTAL - VERWALTUNG & BUCKETS SCHEMA UPDATE
-- Supabase SQL Editor'de çalıştırın
-- ============================================================

BEGIN;

-- 1. ADD DEPARTMENT COLUMN TO VERWALTUNG TABLES
-- This enables department-based filtering for these modules
ALTER TABLE pq_documents ADD COLUMN IF NOT EXISTS department VARCHAR(200);
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS department VARCHAR(200);
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS department VARCHAR(200);

-- Update existing records to 'Allgemein (Genel)' or null if preferred
-- (Leaving them as NULL will make them visible to all admins, which is fine)

-- 2. CREATE MISSING STORAGE BUCKETS
INSERT INTO storage.buckets (id, name, public) VALUES ('pq-documents', 'pq-documents', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('chat-files', 'chat-files', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('site-updates', 'site-updates', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('employee-documents', 'employee-documents', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('document', 'document', true) ON CONFLICT DO NOTHING;

-- 3. SETUP STORAGE POLICIES
-- pq-documents
CREATE POLICY "Public Access for pq-documents" ON storage.objects FOR SELECT USING (bucket_id = 'pq-documents');
CREATE POLICY "Auth Upload for pq-documents" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'pq-documents' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Update for pq-documents" ON storage.objects FOR UPDATE USING (bucket_id = 'pq-documents' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete for pq-documents" ON storage.objects FOR DELETE USING (bucket_id = 'pq-documents' AND auth.role() = 'authenticated');

-- chat-files
CREATE POLICY "Public Access for chat-files" ON storage.objects FOR SELECT USING (bucket_id = 'chat-files');
CREATE POLICY "Auth Upload for chat-files" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'chat-files' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Update for chat-files" ON storage.objects FOR UPDATE USING (bucket_id = 'chat-files' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete for chat-files" ON storage.objects FOR DELETE USING (bucket_id = 'chat-files' AND auth.role() = 'authenticated');

-- site-updates
CREATE POLICY "Public Access for site-updates" ON storage.objects FOR SELECT USING (bucket_id = 'site-updates');
CREATE POLICY "Auth Upload for site-updates" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'site-updates' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Update for site-updates" ON storage.objects FOR UPDATE USING (bucket_id = 'site-updates' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete for site-updates" ON storage.objects FOR DELETE USING (bucket_id = 'site-updates' AND auth.role() = 'authenticated');

-- employee-documents
CREATE POLICY "Public Access for employee-documents" ON storage.objects FOR SELECT USING (bucket_id = 'employee-documents');
CREATE POLICY "Auth Upload for employee-documents" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'employee-documents' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Update for employee-documents" ON storage.objects FOR UPDATE USING (bucket_id = 'employee-documents' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete for employee-documents" ON storage.objects FOR DELETE USING (bucket_id = 'employee-documents' AND auth.role() = 'authenticated');

-- document
CREATE POLICY "Public Access for document" ON storage.objects FOR SELECT USING (bucket_id = 'document');
CREATE POLICY "Auth Upload for document" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'document' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Update for document" ON storage.objects FOR UPDATE USING (bucket_id = 'document' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete for document" ON storage.objects FOR DELETE USING (bucket_id = 'document' AND auth.role() = 'authenticated');

COMMIT;
