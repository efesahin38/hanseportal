-- ============================================================
-- EKREM PDKS - Güncellenmiş Tam Sistem SQL
-- Supabase SQL Editor'de çalıştırın (RUN)
-- ============================================================

DROP TABLE IF EXISTS shift_assignments CASCADE;
DROP TABLE IF EXISTS shift_plans CASCADE;
DROP TABLE IF EXISTS monthly_summaries CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS companies CASCADE;

-- 1. Şirketler
CREATE TABLE companies (
  id   VARCHAR(50) PRIMARY KEY,
  name VARCHAR(100) NOT NULL
);

-- 2. Kullanıcılar (3 rol: super_admin | manager | worker)
CREATE TABLE users (
  id           VARCHAR(50) PRIMARY KEY,
  name         VARCHAR(100) NOT NULL,
  pin_code     VARCHAR(20)  NOT NULL,
  role         VARCHAR(20)  NOT NULL DEFAULT 'worker',
  company_id   VARCHAR(50)  REFERENCES companies(id),
  email        VARCHAR(150),
  fcm_token    TEXT,
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Vardiya Planları
CREATE TABLE shift_plans (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id      VARCHAR(50) NOT NULL REFERENCES companies(id),
  created_by      VARCHAR(50) NOT NULL REFERENCES users(id),
  work_date       DATE        NOT NULL,
  start_time      TIME        NOT NULL,
  end_time        TIME        NOT NULL,
  status          VARCHAR(20) NOT NULL DEFAULT 'pending',
  rejection_note  TEXT,
  notes           TEXT,
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Vardiya Atamaları
CREATE TABLE shift_assignments (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shift_plan_id   UUID        NOT NULL REFERENCES shift_plans(id) ON DELETE CASCADE,
  worker_id       VARCHAR(50) NOT NULL REFERENCES users(id),
  worker_name     VARCHAR(100) NOT NULL,
  role_in_shift   VARCHAR(20) NOT NULL DEFAULT 'worker',
  actual_start    TIMESTAMP WITH TIME ZONE,
  actual_end      TIMESTAMP WITH TIME ZONE,
  total_hours     NUMERIC(6,2),
  shift_status    VARCHAR(20) NOT NULL DEFAULT 'assigned',
  exit_note       TEXT
);

-- 5. Aylık Özetler
CREATE TABLE monthly_summaries (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id    VARCHAR(50) REFERENCES users(id),
  employee_name  VARCHAR(100) NOT NULL,
  report_year    INTEGER NOT NULL,
  report_month   INTEGER NOT NULL,
  total_hours    NUMERIC(7,2) DEFAULT 0,
  total_sessions INTEGER DEFAULT 0,
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(employee_id, report_year, report_month)
);

-- ============================================================
-- ŞİRKETLER
-- ============================================================
INSERT INTO companies (id, name) VALUES
  ('A_GMBH', 'A GMBH'),
  ('B_GMBH', 'B GMBH'),
  ('C_GMBH', 'C GMBH');

-- ============================================================
-- KULLANICILAR
-- ============================================================

-- Süper Admin
INSERT INTO users (id, name, pin_code, role) VALUES
  ('ekrem', 'Ekrem Şahin', '0000', 'super_admin');

-- Şirket Yöneticileri
INSERT INTO users (id, name, pin_code, role, company_id) VALUES
  ('ali_y',    'Ali Yönetici',    '1111', 'manager', 'A_GMBH'),
  ('mehmet_y', 'Mehmet Yönetici', '2222', 'manager', 'B_GMBH'),
  ('veli_y',   'Veli Yönetici',   '3333', 'manager', 'C_GMBH');

-- 40 Çalışan (Herhangi bir şirkete gönderilebilir)
INSERT INTO users (id, name, pin_code, role) VALUES
  ('1001', 'Ahmet Yılmaz',    '1234', 'worker'),
  ('1002', 'Mehmet Demir',    '1234', 'worker'),
  ('1003', 'Ali Kaya',        '1234', 'worker'),
  ('1004', 'Fatma Çelik',     '1234', 'worker'),
  ('1005', 'Ayşe Kurt',       '1234', 'worker'),
  ('1006', 'Hasan Öztürk',    '1234', 'worker'),
  ('1007', 'Hüseyin Şahin',   '1234', 'worker'),
  ('1008', 'İbrahim Aydın',   '1234', 'worker'),
  ('1009', 'Mustafa Arslan',  '1234', 'worker'),
  ('1010', 'Ömer Doğan',      '1234', 'worker'),
  ('1011', 'Abdullah Kılıç',  '1234', 'worker'),
  ('1012', 'Kadir Taş',       '1234', 'worker'),
  ('1013', 'Ramazan Güneş',   '1234', 'worker'),
  ('1014', 'Serdar Çetin',    '1234', 'worker'),
  ('1015', 'Kemal Aktaş',     '1234', 'worker'),
  ('1016', 'Erdoğan Polat',   '1234', 'worker'),
  ('1017', 'Yaşar Koç',       '1234', 'worker'),
  ('1018', 'Cengiz Bulut',    '1234', 'worker'),
  ('1019', 'Talat Yıldız',    '1234', 'worker'),
  ('1020', 'Necdet Özdemir',  '1234', 'worker'),
  ('1021', 'Zeynep Aksoy',    '1234', 'worker'),
  ('1022', 'Hatice Bozkurt',  '1234', 'worker'),
  ('1023', 'Emine Yavuz',     '1234', 'worker'),
  ('1024', 'Gülşen Ateş',     '1234', 'worker'),
  ('1025', 'Semra Çelik',     '1234', 'worker'),
  ('1026', 'Leyla Şimşek',    '1234', 'worker'),
  ('1027', 'Nurcan Keskin',   '1234', 'worker'),
  ('1028', 'Sevim Acar',      '1234', 'worker'),
  ('1029', 'Yıldız Ünal',     '1234', 'worker'),
  ('1030', 'Özlem Güler',     '1234', 'worker'),
  ('1031', 'Bülent Kara',     '1234', 'worker'),
  ('1032', 'Ufuk Çakır',      '1234', 'worker'),
  ('1033', 'Gökhan Eraslan',  '1234', 'worker'),
  ('1034', 'Tolga Saygın',    '1234', 'worker'),
  ('1035', 'Murat Toprak',    '1234', 'worker'),
  ('1036', 'Emre Yüksel',     '1234', 'worker'),
  ('1037', 'Okan Duman',      '1234', 'worker'),
  ('1038', 'Taner Avcı',      '1234', 'worker'),
  ('1039', 'Sinan Kocaman',   '1234', 'worker'),
  ('1040', 'Burak Demirci',   '1234', 'worker');
