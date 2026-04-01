-- Migration: Work session delay tracking
-- Adds delay_minutes column to work_sessions to persist calculated delay at start time

ALTER TABLE work_sessions
ADD COLUMN IF NOT EXISTS delay_minutes INTEGER DEFAULT 0;

COMMENT ON COLUMN work_sessions.delay_minutes IS
  'Kaç dakika geç başlandı (planlanan başlangıç saatine göre). 0 = zamanında veya erken.';
